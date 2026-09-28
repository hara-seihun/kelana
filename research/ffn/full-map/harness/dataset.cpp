#include "ffn_harness.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <stdexcept>
#include <map>
#include <memory>

namespace kffn {
namespace {

// Minimal JSON reader for the manifest this harness writes: objects, arrays, strings, numbers.
struct Json {
    enum Kind { Num, Str, Arr, Obj } kind = Num;
    double num = 0;
    std::string str;
    std::vector<Json> arr;
    std::map<std::string, Json> obj;

    const Json & at(const std::string & k) const {
        auto it = obj.find(k);
        if (it == obj.end()) throw std::runtime_error("manifest: missing key " + k);
        return it->second;
    }
    bool has(const std::string & k) const { return obj.count(k) != 0; }
    int as_int() const { return (int) num; }
    const std::string & as_str() const { return str; }
};

struct Parser {
    const char * p;
    void ws() { while (*p == ' ' || *p == '\n' || *p == '\t' || *p == '\r' || *p == ',') p++; }
    void expect(char c) { ws(); if (*p != c) throw std::runtime_error(std::string("manifest: expected ") + c); p++; }
    Json value() {
        ws();
        Json v;
        if (*p == '"') { v.kind = Json::Str; v.str = string(); }
        else if (*p == '{') {
            v.kind = Json::Obj; p++;
            for (ws(); *p != '}'; ws()) { std::string k = string(); expect(':'); v.obj[k] = value(); }
            p++;
        } else if (*p == '[') {
            v.kind = Json::Arr; p++;
            for (ws(); *p != ']'; ws()) v.arr.push_back(value());
            p++;
        } else if (!strncmp(p, "true", 4)) { v.num = 1; p += 4; }
        else if (!strncmp(p, "false", 5)) { v.num = 0; p += 5; }
        else if (!strncmp(p, "null", 4)) { p += 4; }
        else { char * e = nullptr; v.num = strtod(p, &e); if (e == p) throw std::runtime_error("manifest: bad number"); p = e; }
        return v;
    }
    std::string string() {
        ws();
        if (*p != '"') throw std::runtime_error("manifest: expected string");
        p++;
        std::string s;
        while (*p && *p != '"') { if (*p == '\\') { p++; s += *p == 'n' ? '\n' : *p; } else s += *p; p++; }
        p++;
        return s;
    }
};

std::string slurp(const std::string & path) {
    FILE * f = fopen(path.c_str(), "rb");
    if (!f) throw std::runtime_error("cannot open " + path);
    std::string s;
    char buf[65536];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, f)) > 0) s.append(buf, n);
    fclose(f);
    return s;
}

std::vector<uint8_t> read_bytes(const std::string & path, size_t expect) {
    FILE * f = fopen(path.c_str(), "rb");
    if (!f) throw std::runtime_error("cannot open " + path);
    fseek(f, 0, SEEK_END);
    const size_t n = (size_t) ftell(f);
    fseek(f, 0, SEEK_SET);
    if (expect && n != expect)
        throw std::runtime_error(path + ": expected " + std::to_string(expect) + " bytes, found " + std::to_string(n));
    std::vector<uint8_t> v(n);
    if (fread(v.data(), 1, n, f) != n) throw std::runtime_error("short read on " + path);
    fclose(f);
    return v;
}

std::vector<float> read_f32(const std::string & path, size_t n) {
    std::vector<uint8_t> b = read_bytes(path, n * 4);
    std::vector<float> v(n);
    memcpy(v.data(), b.data(), n * 4);
    return v;
}

void * upload(const void * src, size_t bytes) {
    void * d = nullptr;
    hipError_t e = hipMalloc(&d, bytes);
    if (e != hipSuccess) throw std::runtime_error(std::string("hipMalloc: ") + hipGetErrorString(e));
    e = hipMemcpy(d, src, bytes, hipMemcpyHostToDevice);
    if (e != hipSuccess) throw std::runtime_error(std::string("hipMemcpy: ") + hipGetErrorString(e));
    return d;
}

size_t halo_bytes(int N, int K) { return (size_t) (N / 32) * (K / 128) * 896; }

} // namespace

Dataset load_dataset(const std::string & dir) {
    const std::string text = slurp(dir + "/manifest.json");
    Parser ps { text.c_str() };
    const Json m = ps.value();

    Dataset d;
    d.dir = dir;
    d.model = m.at("model").as_str();
    d.halo_cache = m.at("halo_cache").as_str();
    d.source_commit = m.at("bonsai_commit").as_str();
    d.built_at = m.at("built_at").as_str();
    d.prompt = m.has("prompt") ? m.at("prompt").as_str() : "";
    d.shape.layer = m.at("layer").as_int();
    d.shape.D = m.at("D").as_int();
    d.shape.FF = m.at("FF").as_int();
    d.shape.rmax = m.at("rmax").as_int();
    const int D = d.shape.D, FF = d.shape.FF;

    const Json & w = m.at("weights");
    auto path = [&](const Json & j, const char * k) { return dir + "/" + j.at(k).as_str(); };
    {
        d.gate_host = read_bytes(path(w, "gate"), halo_bytes(FF, D));
        d.w.gate = (const uint8_t *) upload(d.gate_host.data(), d.gate_host.size());
        d.up_host = read_bytes(path(w, "up"), halo_bytes(FF, D));
        d.w.up = (const uint8_t *) upload(d.up_host.data(), d.up_host.size());
        d.down_host = read_bytes(path(w, "down"), halo_bytes(D, FF));
        d.w.down = (const uint8_t *) upload(d.down_host.data(), d.down_host.size());
        d.w.gate_host = d.gate_host.data(); d.w.up_host = d.up_host.data(); d.w.down_host = d.down_host.data();
    }
    {
        d.post_norm_s_host = read_f32(path(w, "post_norm_s"), D);
        std::vector<float> v = d.post_norm_s_host;
        d.w.post_norm_s = (const float *) upload(v.data(), D * 4);
        d.w.post_norm_s_host = d.post_norm_s_host.data();
        d.post_norm_host = read_f32(path(w, "post_norm"), D);
        d.w.post_norm = (const float *) upload(d.post_norm_host.data(), D * 4);
        v = read_f32(path(w, "signs_d"), D);
        d.w.signs_d = (const float *) upload(v.data(), D * 4);
        d.signs_ff_host = read_f32(path(w, "signs_ff"), FF);
        d.w.signs_ff = (const float *) upload(d.signs_ff_host.data(), FF * 4);
        d.w.signs_ff_host = d.signs_ff_host.data();
    }

    for (const Json & c : m.at("cases").arr) {
        Case k;
        k.nrows = c.at("nrows").as_int();
        k.input_kind = c.at("input_kind").as_str();
        for (const Json & t : c.at("tokens").arr) k.tokens.push_back((int) t.num);
        k.x_in = read_f32(dir + "/" + c.at("x_in").as_str(), (size_t) k.nrows * D);
        k.x_ref = read_f32(dir + "/" + c.at("x_out").as_str(), (size_t) k.nrows * D);
        if (c.has("gate")) k.gate_ref = read_f32(dir + "/" + c.at("gate").as_str(), (size_t) k.nrows * FF);
        if (c.has("up")) k.up_ref = read_f32(dir + "/" + c.at("up").as_str(), (size_t) k.nrows * FF);
        if (c.has("xq_ff")) {
            std::vector<uint8_t> q = read_bytes(dir + "/" + c.at("xq_ff").as_str(), (size_t) k.nrows * FF);
            k.xq_ff.assign((const int8_t *) q.data(), (const int8_t *) q.data() + q.size());
            k.xs_ff = read_f32(dir + "/" + c.at("xs_ff").as_str(), (size_t) k.nrows * (FF / 128));
            std::vector<uint8_t> s = read_bytes(dir + "/" + c.at("xsum_ff").as_str(), (size_t) k.nrows * (FF / 128) * 4);
            k.xsum_ff.resize((size_t) k.nrows * (FF / 128));
            memcpy(k.xsum_ff.data(), s.data(), s.size());
        }
        d.cases.push_back(std::move(k));
    }
    return d;
}

std::vector<Candidate> & registry() {
    static std::vector<Candidate> r;
    return r;
}

} // namespace kffn
