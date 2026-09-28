#include "batch_dataset.h"
#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <stdexcept>

#define CHECK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) throw std::runtime_error(std::string(#x) + ": " + hipGetErrorString(e_)); } while (0)

namespace kbatch {
namespace {

std::string read_text(const std::string & path) {
    FILE * f = fopen(path.c_str(), "rb");
    if (!f) throw std::runtime_error("cannot read " + path);
    std::string s;
    char b[4096];
    size_t r;
    while ((r = fread(b, 1, sizeof b, f)) > 0) s.append(b, r);
    fclose(f);
    return s;
}

std::vector<uint8_t> read_bin(const std::string & path, size_t expect = 0) {
    FILE * f = fopen(path.c_str(), "rb");
    if (!f) throw std::runtime_error("cannot read " + path);
    fseek(f, 0, SEEK_END);
    const long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    std::vector<uint8_t> v((size_t) n);
    if (n && fread(v.data(), 1, (size_t) n, f) != (size_t) n) { fclose(f); throw std::runtime_error("short read on " + path); }
    fclose(f);
    if (expect && v.size() != expect)
        throw std::runtime_error(path + ": " + std::to_string(v.size()) + " bytes, expected " + std::to_string(expect));
    return v;
}

std::vector<float> read_f32(const std::string & path, size_t n) {
    std::vector<uint8_t> b = read_bin(path, n * 4);
    std::vector<float> v(n);
    memcpy(v.data(), b.data(), n * 4);
    return v;
}

// Minimal scanning of the manifest this repository writes; it is not a general JSON parser.
size_t find_key(const std::string & j, const std::string & key, size_t from = 0) {
    const std::string pat = "\"" + key + "\"";
    const size_t k = j.find(pat, from);
    if (k == std::string::npos) throw std::runtime_error("manifest is missing " + pat);
    return j.find(':', k + pat.size()) + 1;
}
std::string str_of(const std::string & j, const std::string & key, size_t from = 0) {
    size_t p = find_key(j, key, from);
    while (p < j.size() && j[p] != '"') p++;
    std::string o;
    for (p++; p < j.size() && j[p] != '"'; p++) {
        if (j[p] == '\\' && p + 1 < j.size()) { p++; o += j[p] == 'n' ? '\n' : j[p]; continue; }
        o += j[p];
    }
    return o;
}
long num_of(const std::string & j, const std::string & key, size_t from = 0) {
    return strtol(j.c_str() + find_key(j, key, from), nullptr, 10);
}
bool bool_of(const std::string & j, const std::string & key) {
    const size_t p = find_key(j, key);
    return j.compare(j.find_first_not_of(" \t", p), 4, "true") == 0;
}

template <typename T> T * upload(const std::vector<T> & h) {
    if (h.empty()) return nullptr;
    T * d = nullptr;
    CHECK(hipMalloc(&d, h.size() * sizeof(T)));
    CHECK(hipMemcpy(d, h.data(), h.size() * sizeof(T), hipMemcpyHostToDevice));
    return d;
}

} // namespace

kelana_batch::Weights Dataset::weights() const {
    kelana_batch::Weights w{};
    w.width = D; w.hidden = FF; w.layer = layer;
    w.gate_host = gate_host.data(); w.up_host = up_host.data(); w.down_host = down_host.data();
    w.gate_device = gate_dev; w.up_device = up_dev; w.down_device = down_dev;
    w.norm_host = post_norm_s_host.data(); w.signs_host = signs_ff_host.data();
    w.norm_device = norm_dev; w.signs_device = signs_dev;
    w.gate_bytes = gate_host.size(); w.up_bytes = up_host.size(); w.down_bytes = down_host.size();
    return w;
}

void Dataset::batch(int rows, std::vector<float> & x_in, std::vector<float> & x_ref) const {
    if (rows <= 0 || rows % rmax) throw std::runtime_error("batch size must be a positive multiple of " + std::to_string(rmax));
    const int need = rows / rmax;
    if (need > (int) chunks.size())
        throw std::runtime_error("batch of " + std::to_string(rows) + " rows needs " + std::to_string(need) +
                                 " chunks, dataset has " + std::to_string(chunks.size()));
    x_in.resize((size_t) rows * D);
    x_ref.resize((size_t) rows * D);
    for (int c = 0; c < need; c++) {
        memcpy(&x_in[(size_t) c * rmax * D], chunks[c].x_in.data(), (size_t) rmax * D * 4);
        memcpy(&x_ref[(size_t) c * rmax * D], chunks[c].x_out.data(), (size_t) rmax * D * 4);
    }
}

std::vector<int> Dataset::batch_tokens(int rows) const {
    std::vector<int> t;
    for (int c = 0; c < rows / rmax && c < (int) chunks.size(); c++)
        t.insert(t.end(), chunks[c].tokens.begin(), chunks[c].tokens.end());
    return t;
}

Dataset load(const std::string & dir) {
    Dataset d;
    d.dir = dir;
    const std::string j = read_text(dir + "/manifest.json");
    d.format = str_of(j, "format");
    if (d.format != "kelana-ffn-batch/1") throw std::runtime_error("unexpected dataset format " + d.format);
    d.model = str_of(j, "model");
    d.bonsai_commit = str_of(j, "bonsai_commit");
    d.bonsai_dirty = bool_of(j, "bonsai_dirty");
    d.built_at = str_of(j, "built_at");
    d.document = str_of(j, "document");
    d.document_sha256 = str_of(j, "document_sha256");
    d.tokens_sha256 = str_of(j, "tokens_sha256");
    d.input_kind = str_of(j, "input_kind");
    d.layer = (int) num_of(j, "layer");
    d.D = (int) num_of(j, "D");
    d.FF = (int) num_of(j, "FF");
    d.rmax = (int) num_of(j, "rmax");

    d.gate_host = read_bin(dir + "/gate.halo");
    d.up_host = read_bin(dir + "/up.halo");
    d.down_host = read_bin(dir + "/down.halo");
    d.post_norm_host = read_f32(dir + "/post_norm.f32", (size_t) d.D);
    d.post_norm_s_host = read_f32(dir + "/post_norm_s.f32", (size_t) d.D);
    d.signs_d_host = read_f32(dir + "/signs_d.f32", (size_t) d.D);
    d.signs_ff_host = read_f32(dir + "/signs_ff.f32", (size_t) d.FF);
    d.gate_dev = upload(d.gate_host);
    d.up_dev = upload(d.up_host);
    d.down_dev = upload(d.down_host);
    d.norm_dev = upload(d.post_norm_s_host);
    d.signs_dev = upload(d.signs_ff_host);

    size_t p = j.find("\"chunks\"");
    if (p == std::string::npos) throw std::runtime_error("manifest has no chunks");
    for (;;) {
        const size_t o = j.find("{", p + 1);
        if (o == std::string::npos) break;
        const size_t e = j.find("}", o);
        const std::string ent = j.substr(o, e - o + 1);
        Chunk c;
        c.index = (int) num_of(ent, "index");
        c.rows = (int) num_of(ent, "rows");
        c.position0 = (int) num_of(ent, "position0");
        const std::string sub = str_of(ent, "dir");
        size_t q = ent.find('[', find_key(ent, "tokens")) + 1;
        while (q < ent.size() && ent[q] != ']') {
            while (q < ent.size() && (ent[q] == ' ' || ent[q] == ',')) q++;
            if (q >= ent.size() || ent[q] == ']') break;
            c.tokens.push_back((int) strtol(ent.c_str() + q, nullptr, 10));
            while (q < ent.size() && ent[q] != ',' && ent[q] != ']') q++;
        }
        c.x_in = read_f32(dir + "/" + sub + "/x_in.f32", (size_t) c.rows * d.D);
        c.x_out = read_f32(dir + "/" + sub + "/x_out.f32", (size_t) c.rows * d.D);
        d.chunks.push_back(std::move(c));
        p = e;
    }
    return d;
}

} // namespace kbatch
