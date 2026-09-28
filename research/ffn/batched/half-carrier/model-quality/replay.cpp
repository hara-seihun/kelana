// Close the one-layer transfer gap between the in-model phase and the standalone candidate.
//
// Two questions, deliberately separated, because the in-model phase uses the deployed
// `prep_chunk_r` producer and the deployed SiLU phase while the candidate has its own:
//
//   projection agreement   given *identical* quantised activations, does the half carrier produce
//                          the same projection as an FP32 accumulation of the same integers? This
//                          is measured entirely inside the capture, between configurations that
//                          share their activation codes, so no producer difference can enter it.
//   residual agreement     replayed through the standalone candidate on the captured FFN input,
//                          does the whole FFN land in the same place? This one does include every
//                          producer and consumer association difference, and it is the number that
//                          says whether the model-quality result describes the winning kernel.
//
// It also measures the reverse-order FP32 perturbation on identical inputs rather than asserting a
// magnitude for it.
#include "../../api.hpp"
#include "../../bench/batch_dataset.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

#define CHECK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) \
    throw std::runtime_error(std::string("hip: ") + hipGetErrorString(e_)); } while (0)

namespace {

struct Capture {
    int rows = 0, D = 0, FF = 0, carrier = 0, scale_rne = 0, layer = 0;
    std::vector<float> x_in, xs_in, gate_up, xs_hidden, x_out;
    std::vector<int8_t> xq_in, xq_hidden;
};

Capture load(const std::string &path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) throw std::runtime_error("cannot read " + path);
    int dims[6];
    f.read((char *) dims, sizeof dims);
    Capture c;
    c.rows = dims[0]; c.D = dims[1]; c.FF = dims[2];
    c.carrier = dims[3]; c.scale_rne = dims[4]; c.layer = dims[5];
    auto get = [&](auto &v, size_t n) { v.resize(n); f.read((char *) v.data(), std::streamsize(n * sizeof(v[0]))); };
    get(c.x_in, size_t(c.rows) * c.D);
    get(c.xq_in, size_t(c.rows) * c.D);
    get(c.xs_in, size_t(c.rows) * (c.D / 128));
    get(c.gate_up, 2 * size_t(c.rows) * c.FF);
    get(c.xq_hidden, size_t(c.rows) * c.FF);
    get(c.xs_hidden, size_t(c.rows) * (c.FF / 128));
    get(c.x_out, size_t(c.rows) * c.D);
    if (!f) throw std::runtime_error("short read on " + path);
    return c;
}

struct Stats { double rel_rms = 0, bias = 0, max_abs = 0, worst_row = 0; long long differing = 0; size_t n = 0; };

template <class T>
Stats diff(const std::vector<T> &a, const std::vector<T> &b, int rows) {
    if (a.size() != b.size()) throw std::runtime_error("shape mismatch");
    const size_t w = a.size() / size_t(rows);
    Stats s; s.n = a.size();
    double se = 0, sr = 0, sb = 0;
    for (int r = 0; r < rows; ++r) {
        double rse = 0, rsr = 0;
        for (size_t c = 0; c < w; ++c) {
            const size_t i = size_t(r) * w + c;
            const double d = double(a[i]) - double(b[i]);
            if (a[i] != b[i]) ++s.differing;
            rse += d * d; rsr += double(b[i]) * double(b[i]);
            sb += d;
            s.max_abs = std::max(s.max_abs, std::fabs(d));
        }
        se += rse; sr += rsr;
        if (rsr > 0) s.worst_row = std::max(s.worst_row, std::sqrt(rse / rsr));
    }
    s.rel_rms = sr > 0 ? std::sqrt(se / sr) : 0;
    s.bias = sb / double(a.size());
    return s;
}

std::string real(double v) { char b[64]; std::snprintf(b, sizeof b, "%.17g", v); return b; }
std::string json_of(const Stats &s) {
    return "{ \"rel_rms\": " + real(s.rel_rms) + ", \"bias\": " + real(s.bias) +
           ", \"max_abs\": " + real(s.max_abs) + ", \"worst_row_rel_rms\": " + real(s.worst_row) +
           ", \"differing\": " + std::to_string(s.differing) + ", \"elements\": " + std::to_string(s.n) + " }";
}
void report(const char *what, const Stats &s) {
    std::fprintf(stderr, "%-58s rel_rms %.4e  bias %+.3e  max|d| %.3e  worst_row %.4e  differing %lld/%zu\n",
                 what, s.rel_rms, s.bias, s.max_abs, s.worst_row, s.differing, s.n);
}

} // namespace

int main(int argc, char **argv) try {
    std::string dataset, prefix, out_path;
    int layer = 0;
    for (int i = 1; i < argc; ++i) {
        const std::string a = argv[i];
        auto next = [&] { if (i + 1 >= argc) throw std::runtime_error("missing value for " + a); return std::string(argv[++i]); };
        if (a == "--dataset") dataset = next();
        else if (a == "--prefix") prefix = next();
        else if (a == "--layer") layer = std::stoi(next());
        else if (a == "--json") out_path = next();
        else throw std::runtime_error("unknown argument " + a);
    }
    if (dataset.empty() || prefix.empty()) throw std::runtime_error("usage: replay --dataset DIR --prefix PREFIX [--layer N] [--json FILE]");
    if (!std::getenv("KELANA_GPU_RESEARCH_LOCK")) throw std::runtime_error("run through ../../hardware-run");

    const std::string base = prefix + "-layer" + std::to_string(layer) + "-carrier";
    const Capture half = load(base + "2.bin");     // both projections, binary16 carrier
    const Capture fp32 = load(base + "3.bin");     // same phase and gauge, FP32 running sum
    const Capture rev  = load(base + "4.bin");     // same, blocks summed in reverse
    const int rows = half.rows, D = half.D;

    std::string json = "{\n  \"format\": \"kelana-half-carrier-transfer/1\",\n";
    json += "  \"layer\": " + std::to_string(layer) + ", \"rows\": " + std::to_string(rows) + ",\n";
    json += "  \"capture\": \"one 8-row forward pass of the interposed engine, first eight tokens of prompt 0\",\n";

    // ---- the activation codes have to be identical before any projection claim means anything
    const Stats codes_in = diff(half.xq_in, fp32.xq_in, rows);
    const Stats scales_in = diff(half.xs_in, fp32.xs_in, rows);
    const Stats codes_in_rev = diff(rev.xq_in, fp32.xq_in, rows);
    report("input codes, half carrier vs FP32", codes_in);
    report("input codes, FP32 reverse vs FP32", codes_in_rev);
    json += "  \"identical_input_operands\": { \"codes_half_vs_fp32\": " + json_of(codes_in)
          + ", \"scales_half_vs_fp32\": " + json_of(scales_in)
          + ", \"codes_reverse_vs_fp32\": " + json_of(codes_in_rev) + " },\n";
    const bool same_inputs = codes_in.differing == 0 && scales_in.differing == 0 && codes_in_rev.differing == 0;

    // ---- projection agreement, on identical quantised activations
    const Stats gu_half = diff(half.gate_up, fp32.gate_up, rows * 2);
    const Stats gu_rev = diff(rev.gate_up, fp32.gate_up, rows * 2);
    report(same_inputs ? "gate/up projection, half carrier vs FP32 (same codes)"
                       : "gate/up projection, half carrier vs FP32 (CODES DIFFER)", gu_half);
    report("gate/up projection, FP32 reverse order vs FP32", gu_rev);
    json += "  \"projection_given_identical_operands\": { \"half_vs_fp32\": " + json_of(gu_half)
          + ", \"reverse_vs_fp32\": " + json_of(gu_rev) + " },\n";

    // ---- what that does to the hidden codes, which is the mechanism the model result rests on
    const Stats hid_half = diff(half.xq_hidden, fp32.xq_hidden, rows);
    const Stats hid_rev = diff(rev.xq_hidden, fp32.xq_hidden, rows);
    report("hidden activation codes, half carrier vs FP32", hid_half);
    report("hidden activation codes, FP32 reverse vs FP32", hid_rev);
    json += "  \"hidden_codes\": { \"half_vs_fp32\": " + json_of(hid_half)
          + ", \"reverse_vs_fp32\": " + json_of(hid_rev) + " },\n";

    // ---- full residual, still inside the model
    const Stats out_half = diff(half.x_out, fp32.x_out, rows);
    const Stats out_rev = diff(rev.x_out, fp32.x_out, rows);
    report("FFN output residual, half carrier vs FP32", out_half);
    report("FFN output residual, FP32 reverse order vs FP32", out_rev);
    json += "  \"residual_in_model\": { \"half_vs_fp32\": " + json_of(out_half)
          + ", \"reverse_vs_fp32\": " + json_of(out_rev) + " },\n";

    // ---- replay the captured FFN input through the standalone candidates
    kbatch::Dataset ds = kbatch::load(dataset);
    if (ds.D != D || ds.layer != layer) throw std::runtime_error("dataset is not this layer");
    hipStream_t st; CHECK(hipStreamCreateWithFlags(&st, hipStreamNonBlocking));
    float *in_dev = nullptr, *out_dev = nullptr;
    CHECK(hipMalloc(&in_dev, size_t(rows) * D * 4));
    CHECK(hipMalloc(&out_dev, size_t(rows) * D * 4));
    CHECK(hipMemset(in_dev, 0x7f, size_t(rows) * D * 4));
    CHECK(hipMemset(out_dev, 0x7f, size_t(rows) * D * 4));
    const kelana_batch::Weights w = ds.weights();

    const char *wanted[2] = {"hc-rowpair-a4-tt8-down1-rne", "hc-control-iu4-a4"};
    std::vector<float> replayed[2];
    for (int k = 0; k < 2; ++k) {
        const kelana_batch::Candidate *cand = nullptr;
        for (const auto &c : kelana_batch::registry()) if (!std::strcmp(c.name, wanted[k])) cand = &c;
        if (!cand) throw std::runtime_error(std::string("candidate not registered: ") + wanted[k]);
        void *state = cand->prepare(w, rows);
        CHECK(hipStreamSynchronize(nullptr));
        CHECK(hipMemcpy(in_dev, half.x_in.data(), size_t(rows) * D * 4, hipMemcpyHostToDevice));
        CHECK(hipMemset(out_dev, 0x7f, size_t(rows) * D * 4));
        cand->run(state, rows, in_dev, out_dev, st);
        CHECK(hipStreamSynchronize(st));
        CHECK(hipGetLastError());
        replayed[k].resize(size_t(rows) * D);
        CHECK(hipMemcpy(replayed[k].data(), out_dev, replayed[k].size() * 4, hipMemcpyDeviceToHost));
        cand->release(state);
    }

    const Stats in_same = diff(half.x_in, fp32.x_in, rows);
    const Stats transfer_half = diff(replayed[0], half.x_out, rows);
    const Stats transfer_fp32 = diff(replayed[1], fp32.x_out, rows);
    const Stats candidate_pair = diff(replayed[0], replayed[1], rows);
    report("captured FFN input, half vs FP32 configuration", in_same);
    report("TRANSFER: candidate -rne vs in-model half carrier", transfer_half);
    report("TRANSFER: candidate control vs in-model FP32 carrier", transfer_fp32);
    report("candidate -rne vs candidate control, these rows", candidate_pair);
    json += "  \"captured_input_identical_across_configurations\": " + json_of(in_same) + ",\n";
    json += "  \"transfer\": { \"candidate_rne_vs_model_half\": " + json_of(transfer_half)
          + ", \"candidate_control_vs_model_fp32\": " + json_of(transfer_fp32)
          + ", \"candidate_rne_vs_candidate_control\": " + json_of(candidate_pair) + " },\n";
    json += "  \"note\": \"The transfer rows include the producer and consumer association differences declared in the directory README; the projection and hidden-code rows above do not, because those configurations share their activation codes exactly.\"\n}\n";

    if (!out_path.empty()) {
        std::ofstream f(out_path);
        if (!f) throw std::runtime_error("cannot write " + out_path);
        f << json;
        std::fprintf(stderr, "wrote %s\n", out_path.c_str());
    } else {
        std::fputs(json.c_str(), stdout);
    }
    return 0;
} catch (const std::exception &e) {
    std::fprintf(stderr, "replay: %s\n", e.what());
    return 1;
}
