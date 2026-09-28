// Captures a batched FFN dataset of real contextual token rows from the deployed Bonsai engine.
//
// The deployed multi-row kernel carries at most RMAX = 8 rows per pass, so a 256-row batch cannot
// come from one pass. It does not have to: once the incoming residual of a layer is captured, the
// FFN is row-independent, so rows captured in separate passes of the same document form the same
// larger batch. This tool prefills one real document in RMAX-row chunks and captures, for every
// chunk, the residual entering the layer's FFN and the residual the engine leaves after it. Row i
// of chunk c is token c*RMAX + i of the document at its own position, with the attention and
// recurrent state of every preceding token. No token is repeated and no input is synthetic.
//
// Chunk c's capture needs the sequence state as of chunk c-1, and a pass stopped at a debug barrier
// has already advanced part of that state, so each capture replays the document from reset up to
// chunk c and then runs chunk c stopped at the barrier. That is quadratic in the chunk count, which
// is why --chunks selects a range and existing chunk directories are skipped: a capture can be run
// in several bounded invocations and resumed.
//
// Barrier arithmetic of kernels/halo_rows.hip: 2 barriers before the layer loop and 10 per layer,
// so layer L's FFN input is live after barrier 8 + 10L and its output after 12 + 10L.
#include "engine.h"
#include "tokenizer.h"
#include "sha256.hpp"
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

bool exists(const std::string & path) { struct stat sb{}; return stat(path.c_str(), &sb) == 0; }

void mkpath(const std::string & p) {
    for (size_t i = 1; i <= p.size(); i++) if (i == p.size() || p[i] == '/') mkdir(p.substr(0, i).c_str(), 0700);
}

std::string read_file(const std::string & path) {
    FILE * f = fopen(path.c_str(), "rb");
    if (!f) throw std::runtime_error("cannot read " + path);
    std::string s;
    char b[4096];
    size_t r;
    while ((r = fread(b, 1, sizeof b, f)) > 0) s.append(b, r);
    fclose(f);
    return s;
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

std::string json_escape(const std::string & s) {
    std::string o;
    for (char c : s) {
        if (c == '"' || c == '\\') { o += '\\'; o += c; continue; }
        if (c == '\n') { o += "\\n"; continue; }
        if (c == '\r') { o += "\\r"; continue; }
        if (c == '\t') { o += "\\t"; continue; }
        o += c;
    }
    return o;
}

} // namespace

int main(int argc, char ** argv) try {
    std::string model = "/path/to/workspace/data/bonsai2/PTQ1_0.gguf";
    std::string out = "/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00";
    std::string text_file = "/path/to/workspace/projects/bonsai-halo/README.md";
    std::string bonsai_dir = "/path/to/workspace/projects/bonsai-halo";
    std::string input_kind = "native-prefill-chunked";
    int layer = 0, threads = 16, want_tokens = 256, c0 = 0, c1 = -1;
    bool weights_only = false;
    for (int i = 1; i < argc; i++) {
        const std::string a = argv[i];
        auto next = [&]() { if (i + 1 >= argc) throw std::runtime_error("missing value for " + a); return std::string(argv[++i]); };
        if (a == "--model") model = next();
        else if (a == "--out") out = next();
        else if (a == "--text") text_file = next();
        else if (a == "--layer") layer = std::stoi(next());
        else if (a == "--threads") threads = std::stoi(next());
        else if (a == "--tokens") want_tokens = std::stoi(next());
        else if (a == "--bonsai") bonsai_dir = next();
        else if (a == "--weights-only") weights_only = true;
        else if (a == "--chunks") { const std::string v = next(); const size_t d = v.find(':');
            if (d == std::string::npos) { c0 = c1 = std::stoi(v); } else { c0 = std::stoi(v.substr(0, d)); c1 = std::stoi(v.substr(d + 1)); } }
        else throw std::runtime_error("unknown argument " + a);
    }
    if (want_tokens % RMAX) throw std::runtime_error("--tokens must be a multiple of RMAX");
    const int nchunks = want_tokens / RMAX;
    if (c1 < 0) c1 = nchunks - 1;
    mkpath(out);

    const std::string text = read_file(text_file);
    const std::string text_sha = kbsha::sha256_hex(text.data(), text.size());

    Tokenizer tk;
    tk.load(model);
    std::vector<int> toks = tk.encode(text, true);
    if ((int) toks.size() < want_tokens)
        throw std::runtime_error(text_file + " tokenises to " + std::to_string(toks.size()) + " tokens, fewer than " + std::to_string(want_tokens));
    toks.resize(want_tokens);
    const std::string tok_sha = kbsha::sha256_hex(toks.data(), toks.size() * sizeof(int));
    fprintf(stderr, "document %s -> %d tokens (sha256 %s)\n", text_file.c_str(), want_tokens, tok_sha.substr(0, 16).c_str());

    Engine e;
    e.load(model, threads, 1);

    const int b_in = 8 + 10 * layer, b_out = 12 + 10 * layer;

    // ---- weights, exactly the bytes the engine uploads
    const std::string p = "blk." + std::to_string(layer) + ".";
    auto dump_halo = [&](const std::string & name, const std::string & file, int64_t N, int64_t K) {
        const HaloCacheEntry & en = e.cache.entry(name);
        if (en.N != N || en.K != K) throw std::runtime_error("shape mismatch for " + name);
        write_bytes(out + "/" + file, e.cache.data(en), en.bytes);
        return en.bytes;
    };
    const size_t gate_bytes = dump_halo(p + "ffn_gate.weight", "gate.halo", FF, D);
    const size_t up_bytes = dump_halo(p + "ffn_up.weight", "up.halo", FF, D);
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

    auto read_rows = [&](const float * dev, int nrows, int stride, int n) {
        std::vector<float> h = e.read(dev, (size_t) nrows * stride);
        std::vector<float> o((size_t) nrows * n);
        for (int r = 0; r < nrows; r++) memcpy(&o[(size_t) r * n], &h[(size_t) r * stride], (size_t) n * 4);
        return o;
    };
    // Replays the document from reset through chunk `upto` - 1, then runs chunk `upto` stopped at
    // `stop`. Every replayed pass is a normal pass, so chunk `upto` sees the real state of every
    // preceding token.
    auto run_chunk = [&](int upto, int stop) {
        e.reset();
        for (int c = 0; c <= upto; c++) {
            const int lo = c * RMAX, hi = lo + RMAX;
            setenv("HALO_STOP", c == upto ? std::to_string(stop).c_str() : "0", 1);
            std::vector<Engine::Seq *> sv { &e.seq0 };
            std::vector<std::vector<int>> tv { std::vector<int>(toks.begin() + lo, toks.begin() + hi) };
            e.forward(sv, tv, false, nullptr);
        }
        if (hipStreamSynchronize(e.stream) != hipSuccess) throw std::runtime_error("forward failed");
    };

    int captured = 0;
    if (!weights_only) for (int c = c0; c <= c1 && c < nchunks; c++) {
        const std::string sub = out + "/c" + (c < 10 ? "00" : c < 100 ? "0" : "") + std::to_string(c);
        if (exists(sub + "/x_out.f32")) { fprintf(stderr, "chunk %d already captured\n", c); continue; }
        mkpath(sub);
        run_chunk(c, b_in);
        std::vector<float> x_in = read_rows(e.x, RMAX, D, D);
        write_bytes(sub + "/x_in.f32", x_in.data(), x_in.size() * 4);
        run_chunk(c, b_out);
        std::vector<float> x_out = read_rows(e.x, RMAX, D, D);
        write_bytes(sub + "/x_out.f32", x_out.data(), x_out.size() * 4);
        const std::string digest = kbsha::sha256_hex(x_in.data(), x_in.size() * 4) + "  x_in.f32\n" +
                                   kbsha::sha256_hex(x_out.data(), x_out.size() * 4) + "  x_out.f32\n";
        write_bytes(sub + "/sha256.txt", digest.data(), digest.size());
        captured++;
        fprintf(stderr, "chunk %d captured (tokens %d..%d)\n", c, c * RMAX, c * RMAX + RMAX - 1);
    }

    // ---- manifest, rewritten on every invocation over whatever chunks exist
    int have = 0;
    std::string chunks_json;
    for (int c = 0; c < nchunks; c++) {
        const std::string name = "c" + std::string(c < 10 ? "00" : c < 100 ? "0" : "") + std::to_string(c);
        if (!exists(out + "/" + name + "/x_out.f32")) break;   // contiguous prefix only
        std::string tj;
        for (int i = 0; i < RMAX; i++) tj += (i ? ", " : "") + std::to_string(toks[c * RMAX + i]);
        chunks_json += std::string(have ? ",\n" : "") +
            "    { \"index\": " + std::to_string(c) + ", \"dir\": \"" + name + "\", \"rows\": " + std::to_string(RMAX) +
            ", \"position0\": " + std::to_string(c * RMAX) + ", \"tokens\": [" + tj + "] }";
        have++;
    }

    struct stat sb{};
    stat(model.c_str(), &sb);
    const std::string commit = run_capture("git -C " + bonsai_dir + " rev-parse HEAD 2>/dev/null");
    const std::string dirty = run_capture("git -C " + bonsai_dir + " status --porcelain 2>/dev/null | head -1");

    std::string m = "{\n";
    m += "  \"format\": \"kelana-ffn-batch/1\",\n";
    m += "  \"built_at\": \"" + now_iso() + "\",\n";
    m += "  \"model\": \"" + json_escape(model) + "\",\n";
    m += "  \"model_bytes\": " + std::to_string((long long) sb.st_size) + ",\n";
    m += "  \"bonsai_commit\": \"" + commit + "\",\n";
    m += "  \"bonsai_dirty\": " + std::string(dirty.empty() ? "false" : "true") + ",\n";
    m += "  \"layer\": " + std::to_string(layer) + ",\n";
    m += "  \"D\": " + std::to_string(D) + ", \"FF\": " + std::to_string(FF) + ", \"rmax\": " + std::to_string(RMAX) + ",\n";
    m += "  \"block\": " + std::to_string(BLOCK) + ", \"tile_rows\": " + std::to_string(TILE_ROWS) + ", \"tile_block_bytes\": " + std::to_string(TILE_BLOCK_BYTES) + ",\n";
    m += "  \"halo_bytes\": { \"gate\": " + std::to_string(gate_bytes) + ", \"up\": " + std::to_string(up_bytes) + ", \"down\": " + std::to_string(down_bytes) + " },\n";
    m += "  \"barriers\": { \"ffn_in\": " + std::to_string(b_in) + ", \"ffn_out\": " + std::to_string(b_out) + " },\n";
    m += "  \"input_kind\": \"" + input_kind + "\",\n";
    m += "  \"document\": \"" + json_escape(text_file) + "\",\n";
    m += "  \"document_sha256\": \"" + text_sha + "\",\n";
    m += "  \"document_bytes\": " + std::to_string((long long) text.size()) + ",\n";
    m += "  \"tokens_sha256\": \"" + tok_sha + "\",\n";
    m += "  \"tokens_total\": " + std::to_string(want_tokens) + ",\n";
    m += "  \"chunks_captured\": " + std::to_string(have) + ",\n";
    m += "  \"weights\": { \"gate\": \"gate.halo\", \"up\": \"up.halo\", \"down\": \"down.halo\",\n";
    m += "                 \"post_norm\": \"post_norm.f32\", \"post_norm_s\": \"post_norm_s.f32\",\n";
    m += "                 \"signs_d\": \"signs_d.f32\", \"signs_ff\": \"signs_ff.f32\" },\n";
    m += "  \"chunks\": [\n" + chunks_json + "\n  ]\n}\n";
    write_bytes(out + "/manifest.json", m.data(), m.size());
    fprintf(stderr, "captured %d chunk(s) this run; %d of %d present; manifest %s\n", captured, have, nchunks, (out + "/manifest.json").c_str());
    return 0;
} catch (const std::exception & ex) {
    fprintf(stderr, "build-batch-dataset: %s\n", ex.what());
    return 1;
}
