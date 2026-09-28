// Difference between two candidates' outputs, not between each candidate and the engine.
//
// An error against the deployed engine is dominated by the four-bit activation quantiser that every
// candidate in this directory shares. Two candidates can therefore land within 2e-5 of each other
// on that metric while differing from each other by far more, because a small change reroutes the
// coarse quantisation noise rather than adding to it. That is exactly what main's full-model runs
// showed for the consumer boundary, and it means "0.9625% against 0.9647%" measures nothing about
// the half carrier.
//
// This tool runs each candidate once per batch size, keeps the output vectors, and reports each
// candidate minus a chosen reference candidate, alongside the same statistics against the engine.
// It links the bench directory's dataset loader and registry unchanged; it adds no shared file and
// changes no measurement protocol. Timing is not its business: one correctness pass per point.
#include "../api.hpp"
#include "../bench/batch_dataset.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

#define CHECK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) \
    throw std::runtime_error(std::string("hip: ") + hipGetErrorString(e_)); } while (0)

namespace {

struct Stats {
    double rel_rms = 0, rms = 0, ref_rms = 0, bias = 0, max_abs = 0, worst_row_rel_rms = 0;
    long long differing = 0;
};

// got - ref over [rows][D], with the row-wise worst case and the mean signed difference kept
// separately: a difference that is unbiased overall can still concentrate or shift a row.
Stats compare(const std::vector<float> &got, const std::vector<float> &ref, int rows, int D) {
    Stats s;
    double se = 0, sr = 0, sb = 0;
    for (int r = 0; r < rows; ++r) {
        double rse = 0, rsr = 0;
        for (int c = 0; c < D; ++c) {
            const size_t i = size_t(r) * D + c;
            const double d = double(got[i]) - double(ref[i]);
            if (got[i] != ref[i]) ++s.differing;
            rse += d * d; rsr += double(ref[i]) * double(ref[i]);
            sb += d;
            s.max_abs = std::max(s.max_abs, std::fabs(d));
        }
        se += rse; sr += rsr;
        if (rsr > 0) s.worst_row_rel_rms = std::max(s.worst_row_rel_rms, std::sqrt(rse / rsr));
    }
    const size_t n = size_t(rows) * D;
    s.rms = std::sqrt(se / double(n));
    s.ref_rms = std::sqrt(sr / double(n));
    s.bias = sb / double(n);
    s.rel_rms = s.ref_rms > 0 ? s.rms / s.ref_rms : 0;
    return s;
}

std::string real(double v) { char b[64]; std::snprintf(b, sizeof b, "%.17g", v); return b; }
std::string stats_json(const Stats &s) {
    return "{ \"rel_rms\": " + real(s.rel_rms) + ", \"rms\": " + real(s.rms)
         + ", \"reference_rms\": " + real(s.ref_rms) + ", \"bias\": " + real(s.bias)
         + ", \"max_abs\": " + real(s.max_abs) + ", \"worst_row_rel_rms\": " + real(s.worst_row_rel_rms)
         + ", \"differing_elements\": " + std::to_string(s.differing) + " }";
}

} // namespace

int main(int argc, char **argv) try {
    std::string dir, reference = "hc-control-iu4-a4", want = "all", out_path;
    std::vector<int> rows_list;
    for (int i = 1; i < argc; ++i) {
        const std::string a = argv[i];
        auto next = [&]() { if (i + 1 >= argc) throw std::runtime_error("missing value for " + a); return std::string(argv[++i]); };
        if (a == "--dataset") dir = next();
        else if (a == "--reference") reference = next();
        else if (a == "--candidate") want = next();
        else if (a == "--json") out_path = next();
        else if (a == "--rows") { const std::string v = next(); size_t p = 0;
            while (p < v.size()) { const size_t q = v.find(',', p);
                rows_list.push_back(std::stoi(v.substr(p, q == std::string::npos ? q : q - p)));
                if (q == std::string::npos) break; p = q + 1; } }
        else throw std::runtime_error("unknown argument " + a);
    }
    if (dir.empty()) throw std::runtime_error(
        "usage: paired-error --dataset DIR [--reference NAME] [--candidate NAME,NAME|all] "
        "[--rows 32,64,128,256] [--json FILE]");
    if (!std::getenv("KELANA_GPU_RESEARCH_LOCK"))
        throw std::runtime_error("Run GPU work through ../hardware-run to serialize research jobs");
    if (rows_list.empty()) rows_list = {32, 64, 128, 256};

    auto &reg = kelana_batch::registry();
    std::vector<const kelana_batch::Candidate *> run_list;
    std::vector<std::string> names;
    if (want != "all") { size_t p = 0; while (p < want.size()) { const size_t q = want.find(',', p);
        names.push_back(want.substr(p, q == std::string::npos ? q : q - p));
        if (q == std::string::npos) break; p = q + 1; } }
    for (const auto &c : reg)
        if (want == "all" || std::find(names.begin(), names.end(), c.name) != names.end()) run_list.push_back(&c);
    if (std::none_of(run_list.begin(), run_list.end(),
                     [&](const kelana_batch::Candidate *c) { return reference == c->name; }))
        throw std::runtime_error("reference " + reference + " is not among the selected candidates");

    kbatch::Dataset ds = kbatch::load(dir);
    const int D = ds.D;
    const int max_rows = *std::max_element(rows_list.begin(), rows_list.end());
    if (max_rows > ds.max_rows())
        throw std::runtime_error("dataset holds " + std::to_string(ds.max_rows()) + " rows");

    hipStream_t st;
    CHECK(hipStreamCreateWithFlags(&st, hipStreamNonBlocking));
    float *in_dev = nullptr, *out_dev = nullptr;
    CHECK(hipMalloc(&in_dev, size_t(max_rows) * D * 4));
    CHECK(hipMalloc(&out_dev, size_t(max_rows) * D * 4));
    CHECK(hipMemset(in_dev, 0x7f, size_t(max_rows) * D * 4));
    CHECK(hipMemset(out_dev, 0x7f, size_t(max_rows) * D * 4));

    const kelana_batch::Weights w = ds.weights();
    std::vector<void *> states(run_list.size(), nullptr);
    for (size_t i = 0; i < run_list.size(); ++i)
        states[i] = run_list[i]->prepare ? run_list[i]->prepare(w, max_rows) : nullptr;
    CHECK(hipStreamSynchronize(nullptr));

    std::string json = "{\n  \"format\": \"kelana-half-carrier-paired-error/1\",\n";
    json += "  \"purpose\": \"candidate minus reference candidate, alongside candidate minus engine\",\n";
    json += "  \"dataset\": \"" + dir + "\", \"layer\": " + std::to_string(ds.layer) + ",\n";
    json += "  \"reference_candidate\": \"" + reference + "\",\n  \"points\": [\n";
    bool first = true;

    for (int rows : rows_list) {
        std::vector<float> x_in, x_ref;
        ds.batch(rows, x_in, x_ref);
        CHECK(hipMemcpy(in_dev, x_in.data(), x_in.size() * 4, hipMemcpyHostToDevice));
        std::vector<std::vector<float>> outputs(run_list.size());
        for (size_t i = 0; i < run_list.size(); ++i) {
            CHECK(hipMemset(out_dev, 0x7f, size_t(rows) * D * 4));
            run_list[i]->run(states[i], rows, in_dev, out_dev, st);
            CHECK(hipStreamSynchronize(st));
            CHECK(hipGetLastError());
            outputs[i].resize(size_t(rows) * D);
            CHECK(hipMemcpy(outputs[i].data(), out_dev, outputs[i].size() * 4, hipMemcpyDeviceToHost));
        }
        size_t ri = 0;
        for (size_t i = 0; i < run_list.size(); ++i) if (reference == run_list[i]->name) ri = i;
        for (size_t i = 0; i < run_list.size(); ++i) {
            const Stats vs_ref = compare(outputs[i], outputs[ri], rows, D);
            const Stats vs_engine = compare(outputs[i], x_ref, rows, D);
            if (!first) json += ",\n";
            first = false;
            json += "    { \"candidate\": \"" + std::string(run_list[i]->name) + "\", \"rows\": " + std::to_string(rows)
                  + ",\n      \"vs_reference_candidate\": " + stats_json(vs_ref)
                  + ",\n      \"vs_engine\": " + stats_json(vs_engine) + " }";
            std::fprintf(stderr, "%-32s rows=%-4d  vs %-22s rel_rms %.4e  bias %+.3e  worst_row %.4e  max|d| %.3e"
                                 "   |  vs engine rel_rms %.4e\n",
                         run_list[i]->name, rows, reference.c_str(), vs_ref.rel_rms, vs_ref.bias,
                         vs_ref.worst_row_rel_rms, vs_ref.max_abs, vs_engine.rel_rms);
        }
    }
    json += "\n  ]\n}\n";
    for (size_t i = 0; i < run_list.size(); ++i) if (run_list[i]->release) run_list[i]->release(states[i]);
    if (!out_path.empty()) {
        FILE *f = std::fopen(out_path.c_str(), "w");
        if (!f) throw std::runtime_error("cannot write " + out_path);
        std::fwrite(json.data(), 1, json.size(), f);
        std::fclose(f);
        std::fprintf(stderr, "wrote %s\n", out_path.c_str());
    } else {
        std::fwrite(json.data(), 1, json.size(), stdout);
    }
    return 0;
} catch (const std::exception &e) {
    std::fprintf(stderr, "paired-error: %s\n", e.what());
    return 1;
}
