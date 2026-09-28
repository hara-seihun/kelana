// Extracts one layer's FFN dataset from the deployed engine: the real PTQ1_0 weights in their
// on-device HALO layout, the folded norm and sign vectors, and real incoming residuals produced by
// running real tokens through the deployed multi-row kernel up to the barrier that precedes the
// layer's FFN.
//
// The row-count cases are genuine passes: a 1-row case is a single-token pass over token 0, an
// 8-row case is an 8-token prefill pass of the same prompt, both from freshly reset state. No
// copies of one token, no noise.
//
// Barrier arithmetic of kernels/halo_rows.hip: 2 barriers before the layer loop, then 10 per layer
// (6 for the recurrent or attention half, 4 for the FFN), so for layer L the FFN input residual is
// live after barrier 8 + 10L and the FFN output after 12 + 10L.
#include "engine.h"
#include "tokenizer.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <ctime>
#include <string>
#include <vector>
#include <stdexcept>
#include <sys/stat.h>

using namespace halo;

namespace {

void write_bytes(const std::string & path, const void * p, size_t n) {
    FILE * f = fopen(path.c_str(), "wb");
    if (!f) throw std::runtime_error("cannot write " + path);
    if (fwrite(p, 1, n, f) != n) throw std::runtime_error("short write on " + path);
    fclose(f);
}

std::string now_iso() {
    char buf[64];
    const time_t t = time(nullptr);
    struct tm tm;
    gmtime_r(&t, &tm);
    strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%SZ", &tm);
    return buf;
}

std::string run_capture(const std::string & cmd) {
    FILE * p = popen(cmd.c_str(), "r");
    if (!p) return "";
    std::string s;
    char b[256];
    while (fgets(b, sizeof b, p)) s += b;
    pclose(p);
    while (!s.empty() && (s.back() == '\n' || s.back() == ' ')) s.pop_back();
    return s;
}

} // namespace

int main(int argc, char ** argv) try {
    std::string model = "/path/to/workspace/data/bonsai2/PTQ1_0.gguf";
    std::string out = "/path/to/workspace/data/kelana-ffn/ptq1_0/layer00";
    std::string prompt = "The quick brown fox jumps over the lazy dog, and the ternary weights stay exactly where they were.";
    std::string bonsai_dir = "/path/to/workspace/projects/bonsai-halo";
    int layer = 0, threads = 16;
    std::vector<int> rows { 1, 8 };
    for (int i = 1; i < argc; i++) {
        const std::string a = argv[i];
        auto next = [&]() { if (i + 1 >= argc) throw std::runtime_error("missing value for " + a); return std::string(argv[++i]); };
        if (a == "--model") model = next();
        else if (a == "--out") out = next();
        else if (a == "--layer") layer = std::stoi(next());
        else if (a == "--threads") threads = std::stoi(next());
        else if (a == "--prompt") prompt = next();
        else if (a == "--bonsai") bonsai_dir = next();
        else if (a == "--rows") { rows.clear(); std::string v = next(); size_t p = 0; while (p < v.size()) { size_t q = v.find(',', p); rows.push_back(std::stoi(v.substr(p, q == std::string::npos ? q : q - p))); if (q == std::string::npos) break; p = q + 1; } }
        else throw std::runtime_error("unknown argument " + a);
    }
    mkdir("/path/to/workspace/data/kelana-ffn", 0700);
    { std::string p; for (size_t i = 1; i <= out.size(); i++) if (i == out.size() || out[i] == '/') mkdir(out.substr(0, i).c_str(), 0700); }

    int nmax = 1;
    for (int r : rows) nmax = std::max(nmax, r);
    if (nmax > RMAX) throw std::runtime_error("row count exceeds RMAX");

    Tokenizer tk;
    tk.load(model);
    std::vector<int> toks = tk.encode(prompt, false);
    if ((int) toks.size() < nmax) throw std::runtime_error("prompt tokenises to fewer than " + std::to_string(nmax) + " tokens");
    toks.resize(nmax);
    fprintf(stderr, "tokens:");
    for (int t : toks) fprintf(stderr, " %d", t);
    fprintf(stderr, "\n");

    Engine e;
    e.load(model, threads, 1);

    const int b_in = 8 + 10 * layer, b_qd = 9 + 10 * layer, b_gu = 10 + 10 * layer, b_out = 12 + 10 * layer;

    auto run_to = [&](int stop, int nrows) {
        e.reset();
        setenv("HALO_STOP", std::to_string(stop).c_str(), 1);
        std::vector<Engine::Seq *> sv { &e.seq0 };
        std::vector<std::vector<int>> tv { std::vector<int>(toks.begin(), toks.begin() + nrows) };
        e.forward(sv, tv, false, nullptr);
        if (hipStreamSynchronize(e.stream) != hipSuccess) throw std::runtime_error("forward failed");
    };
    auto read_rows = [&](const float * dev, int nrows, int stride, int n) {
        std::vector<float> h = e.read(dev, (size_t) nrows * stride);
        std::vector<float> o((size_t) nrows * n);
        for (int r = 0; r < nrows; r++) memcpy(&o[(size_t) r * n], &h[(size_t) r * stride], (size_t) n * 4);
        return o;
    };

    // ---- weights, in exactly the bytes the engine uploads
    const std::string p = "blk." + std::to_string(layer) + ".";
    auto dump_halo = [&](const std::string & name, const std::string & file, int64_t N, int64_t K) {
        const HaloCacheEntry & en = e.cache.entry(name);
        if (en.N != N || en.K != K) throw std::runtime_error("shape mismatch for " + name);
        write_bytes(out + "/" + file, e.cache.data(en), en.bytes);
        return en.bytes;
    };
    const size_t gate_bytes = dump_halo(p + "ffn_gate.weight", "gate.halo", FF, D);
    dump_halo(p + "ffn_up.weight", "up.halo", FF, D);
    const size_t down_bytes = dump_halo(p + "ffn_down.weight", "down.halo", D, FF);

    const GgufTensor & pn = e.g.tensor(p + "post_attention_norm.weight");
    const float * pnw = (const float *) pn.data;
    write_bytes(out + "/post_norm.f32", pnw, (size_t) D * 4);
    {
        std::vector<float> folded(D);
        for (int i = 0; i < D; i++) folded[i] = pnw[i] * e.h_signs5120[i];
        write_bytes(out + "/post_norm_s.f32", folded.data(), (size_t) D * 4);
        write_bytes(out + "/signs_d.f32", e.h_signs5120.data(), (size_t) D * 4);
    }
    {
        auto widths = e.g.get("prism.hadamard.sign_widths").as_int_array();
        auto values = e.g.get("prism.hadamard.sign_values").as_int_array();
        size_t off = 0;
        std::vector<float> s17;
        for (int64_t wd : widths) {
            if (wd == FF) { s17.resize(FF); for (int64_t i = 0; i < wd; i++) s17[i] = (float) values.at(off + i); }
            off += wd;
        }
        if (s17.empty()) throw std::runtime_error("no sign vector of width FF");
        write_bytes(out + "/signs_ff.f32", s17.data(), (size_t) FF * 4);
    }

    // ---- activations
    std::string cases_json;
    for (size_t ci = 0; ci < rows.size(); ci++) {
        const int n = rows[ci];
        const std::string sub = "r" + std::to_string(n);
        mkdir((out + "/" + sub).c_str(), 0700);

        run_to(b_in, n);
        std::vector<float> x_in = read_rows(e.x, n, D, D);
        write_bytes(out + "/" + sub + "/x_in.f32", x_in.data(), x_in.size() * 4);

        run_to(b_gu, n);
        {
            std::vector<float> g = read_rows(e.gu, n, FF, FF);
            std::vector<float> u = read_rows(e.gu + (size_t) RMAX * FF, n, FF, FF);
            write_bytes(out + "/" + sub + "/gate.f32", g.data(), g.size() * 4);
            write_bytes(out + "/" + sub + "/up.f32", u.data(), u.size() * 4);
        }

        run_to(b_qd, n);  // quantised post-norm activations that feed the gate/up matvec
        {
            std::vector<char> q((size_t) n * D);
            if (hipMemcpy(q.data(), e.xq, q.size(), hipMemcpyDeviceToHost) != hipSuccess) throw std::runtime_error("xq read failed");
            write_bytes(out + "/" + sub + "/xq_d.i8", q.data(), q.size());
            std::vector<float> s = read_rows(e.xs, n, D / BLOCK, D / BLOCK);
            write_bytes(out + "/" + sub + "/xs_d.f32", s.data(), s.size() * 4);
            std::vector<int> sm((size_t) n * (D / BLOCK));
            if (hipMemcpy(sm.data(), e.xsum, sm.size() * 4, hipMemcpyDeviceToHost) != hipSuccess) throw std::runtime_error("xsum read failed");
            write_bytes(out + "/" + sub + "/xsum_d.i32", sm.data(), sm.size() * 4);
        }

        run_to(b_out, n);
        {
            std::vector<char> q((size_t) n * FF);
            if (hipMemcpy(q.data(), e.xq, q.size(), hipMemcpyDeviceToHost) != hipSuccess) throw std::runtime_error("xq read failed");
            write_bytes(out + "/" + sub + "/xq_ff.i8", q.data(), q.size());
            std::vector<float> s = read_rows(e.xs, n, FF / BLOCK, FF / BLOCK);
            write_bytes(out + "/" + sub + "/xs_ff.f32", s.data(), s.size() * 4);
            std::vector<int> sm((size_t) n * (FF / BLOCK));
            if (hipMemcpy(sm.data(), e.xsum, sm.size() * 4, hipMemcpyDeviceToHost) != hipSuccess) throw std::runtime_error("xsum read failed");
            write_bytes(out + "/" + sub + "/xsum_ff.i32", sm.data(), sm.size() * 4);
            std::vector<float> x_out = read_rows(e.x, n, D, D);
            write_bytes(out + "/" + sub + "/x_out.f32", x_out.data(), x_out.size() * 4);
        }

        std::string tj;
        for (int i = 0; i < n; i++) tj += (i ? ", " : "") + std::to_string(toks[i]);
        cases_json += std::string(ci ? ",\n" : "") +
            "    { \"nrows\": " + std::to_string(n) + ", \"input_kind\": \"native-prefill\", \"tokens\": [" + tj + "],\n"
            "      \"x_in\": \"" + sub + "/x_in.f32\", \"x_out\": \"" + sub + "/x_out.f32\",\n"
            "      \"gate\": \"" + sub + "/gate.f32\", \"up\": \"" + sub + "/up.f32\",\n"
            "      \"xq_d\": \"" + sub + "/xq_d.i8\", \"xs_d\": \"" + sub + "/xs_d.f32\", \"xsum_d\": \"" + sub + "/xsum_d.i32\",\n"
            "      \"xq_ff\": \"" + sub + "/xq_ff.i8\", \"xs_ff\": \"" + sub + "/xs_ff.f32\", \"xsum_ff\": \"" + sub + "/xsum_ff.i32\" }";
        fprintf(stderr, "case rows=%d written\n", n);
    }

    struct stat sb{};
    stat(model.c_str(), &sb);
    const std::string commit = run_capture("git -C " + bonsai_dir + " rev-parse HEAD 2>/dev/null");
    const std::string dirty = run_capture("git -C " + bonsai_dir + " status --porcelain 2>/dev/null | head -1");

    std::string m = "{\n";
    m += "  \"format\": \"kelana-ffn-dataset/1\",\n";
    m += "  \"built_at\": \"" + now_iso() + "\",\n";
    m += "  \"model\": \"" + model + "\",\n";
    m += "  \"model_bytes\": " + std::to_string((long long) sb.st_size) + ",\n";
    m += "  \"halo_cache\": \"" + model + ".halo\",\n";
    m += "  \"bonsai_commit\": \"" + commit + "\",\n";
    m += "  \"bonsai_dirty\": " + std::string(dirty.empty() ? "false" : "true") + ",\n";
    m += "  \"layer\": " + std::to_string(layer) + ",\n";
    m += "  \"D\": " + std::to_string(D) + ", \"FF\": " + std::to_string(FF) + ", \"rmax\": " + std::to_string(RMAX) + ",\n";
    m += "  \"block\": " + std::to_string(BLOCK) + ", \"tile_rows\": " + std::to_string(TILE_ROWS) + ", \"tile_block_bytes\": " + std::to_string(TILE_BLOCK_BYTES) + ",\n";
    m += "  \"halo_bytes\": { \"gate\": " + std::to_string(gate_bytes) + ", \"up\": " + std::to_string(gate_bytes) + ", \"down\": " + std::to_string(down_bytes) + " },\n";
    m += "  \"barriers\": { \"ffn_in\": " + std::to_string(b_in) + ", \"gate_up\": " + std::to_string(b_gu) + ", \"post_norm_quant\": " + std::to_string(b_qd) + ", \"ffn_out\": " + std::to_string(b_out) + " },\n";
    m += "  \"prompt\": \"" + prompt + "\",\n";
    m += "  \"weights\": { \"gate\": \"gate.halo\", \"up\": \"up.halo\", \"down\": \"down.halo\",\n";
    m += "                 \"post_norm\": \"post_norm.f32\", \"post_norm_s\": \"post_norm_s.f32\",\n";
    m += "                 \"signs_d\": \"signs_d.f32\", \"signs_ff\": \"signs_ff.f32\" },\n";
    m += "  \"cases\": [\n" + cases_json + "\n  ]\n}\n";
    write_bytes(out + "/manifest.json", m.data(), m.size());
    fprintf(stderr, "dataset written to %s\n", out.c_str());
    return 0;
} catch (const std::exception & ex) {
    fprintf(stderr, "build_dataset: %s\n", ex.what());
    return 1;
}
