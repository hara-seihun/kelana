// Runs a complete residual-to-residual FFN candidate over the real layer dataset and reports every
// timing sample, the in-kernel stage profile and the error against the engine's own output.
//
// The timed interval is one candidate launch. The input residual is restored from an immutable
// device copy before each interval, outside it, so repetitions never iterate the FFN.
#include "ffn_harness.h"
#include "build-info.h"
#include <hip/hip_runtime.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

#define CHECK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) throw std::runtime_error(std::string(#x) + ": " + hipGetErrorString(e_)); } while (0)

namespace {

struct Err { double max_abs = 0, max_rel = 0, rms = 0, ref_rms = 0; size_t bit_mismatches = 0; };

Err compare(const std::vector<float> & got, const std::vector<float> & ref) {
    Err e;
    double se = 0, sr = 0;
    for (size_t i = 0; i < ref.size(); i++) {
        if (!std::isfinite(got[i]) || !std::isfinite(ref[i])) throw std::runtime_error("nonfinite comparison value at " + std::to_string(i));
        e.bit_mismatches += std::memcmp(&got[i], &ref[i], sizeof(float)) != 0;
        const double a = got[i], b = ref[i], d = std::fabs(a - b);
        e.max_abs = std::max(e.max_abs, d);
        const double den = std::fabs(b);
        if (den > 1e-6) e.max_rel = std::max(e.max_rel, d / den);
        se += d * d;
        sr += b * b;
    }
    e.rms = std::sqrt(se / (double) ref.size());
    e.ref_rms = std::sqrt(sr / (double) ref.size());
    return e;
}

double median(std::vector<double> v) {
    if (v.empty()) return 0;
    std::sort(v.begin(), v.end());
    const size_t n = v.size();
    return n % 2 ? v[n / 2] : 0.5 * (v[n / 2 - 1] + v[n / 2]);
}
double quantile(std::vector<double> v, double q) {
    if (v.empty()) return 0;
    std::sort(v.begin(), v.end());
    return v[std::min(v.size() - 1, (size_t) (q * (double) (v.size() - 1) + 0.5))];
}

std::string json_escape(const std::string & s) {
    std::string o;
    for (char c : s) { if (c == '"' || c == '\\') o += '\\'; if (c == '\n') { o += "\\n"; continue; } o += c; }
    return o;
}

size_t halo_bytes(int N, int K) { return (size_t) (N / 32) * (K / 128) * 896; }
std::string real(double v) { char b[64]; snprintf(b,sizeof(b),"%.17g",v); return b; }
std::string error_json(const Err &e) {
    return "{ \"max_abs\": " + real(e.max_abs) + ", \"max_rel\": " + real(e.max_rel)
        + ", \"rms\": " + real(e.rms) + ", \"ref_rms\": " + real(e.ref_rms)
        + ", \"bit_mismatches\": " + std::to_string(e.bit_mismatches) + " }";
}

} // namespace

int main(int argc, char ** argv) try {
    std::string dir, cand_name = "baseline", out_path;
    std::vector<int> rows;
    int iters = 200, warmup = 20;
    for (int i = 1; i < argc; i++) {
        const std::string a = argv[i];
        auto next = [&]() { if (i + 1 >= argc) throw std::runtime_error("missing value for " + a); return std::string(argv[++i]); };
        if (a == "--dataset") dir = next();
        else if (a == "--candidate") cand_name = next();
        else if (a == "--iters") iters = std::stoi(next());
        else if (a == "--warmup") warmup = std::stoi(next());
        else if (a == "--json") out_path = next();
        else if (a == "--rows") { std::string v = next(); size_t p = 0; while (p < v.size()) { size_t q = v.find(',', p); rows.push_back(std::stoi(v.substr(p, q == std::string::npos ? q : q - p))); if (q == std::string::npos) break; p = q + 1; } }
        else if (a == "--list") { for (const auto & c : kffn::registry()) printf("%s\n", c.name); return 0; }
        else throw std::runtime_error("unknown argument " + a);
    }
    if (dir.empty()) throw std::runtime_error("usage: ffn-bench --dataset DIR [--candidate NAME] [--rows 1,8] [--iters N] [--warmup N] [--json FILE]");

    const kffn::Candidate * cand = nullptr;
    for (const auto & c : kffn::registry()) if (cand_name == c.name) cand = &c;
    if (!cand) {
        std::string have;
        for (const auto & c : kffn::registry()) { have += " "; have += c.name; }
        throw std::runtime_error("no candidate named " + cand_name + "; registered:" + have);
    }

    kffn::Dataset ds = kffn::load_dataset(dir);
    const int D = ds.shape.D, FF = ds.shape.FF, RMAX = ds.shape.rmax;

    hipDeviceProp_t prop{};
    CHECK(hipGetDeviceProperties(&prop, 0));

    kffn::Work w{};
    CHECK(hipMalloc(&w.x, (size_t) RMAX * D * 4));
    CHECK(hipMalloc(&w.xq, (size_t) RMAX * FF));
    CHECK(hipMalloc(&w.xs, (size_t) RMAX * (FF / 128) * 4));
    CHECK(hipMalloc(&w.xsum, (size_t) RMAX * (FF / 128) * 4));
    CHECK(hipMalloc(&w.gu, (size_t) 2 * RMAX * FF * 4));
    w.scratch_bytes = (size_t) 64 << 20;
    CHECK(hipMalloc(&w.scratch, w.scratch_bytes));
    CHECK(hipMemset(w.scratch, 0, w.scratch_bytes));

    const int slots = iters + warmup + 2;
    const int BAR_STRIDE = 16, WORK_STRIDE = 64, PROF_STRIDE = 16;
    unsigned * bar_ring = nullptr, * work_ring = nullptr;
    unsigned long long * prof_ring = nullptr;
    CHECK(hipMalloc(&bar_ring, (size_t) slots * BAR_STRIDE * 4));
    CHECK(hipMalloc(&work_ring, (size_t) slots * WORK_STRIDE * 4));
    CHECK(hipMalloc(&prof_ring, (size_t) slots * PROF_STRIDE * 8));
    CHECK(hipMemset(bar_ring, 0, (size_t) slots * BAR_STRIDE * 4));
    CHECK(hipMemset(work_ring, 0, (size_t) slots * WORK_STRIDE * 4));
    CHECK(hipMemset(prof_ring, 0, (size_t) slots * PROF_STRIDE * 8));

    float * x_in_dev = nullptr;
    CHECK(hipMalloc(&x_in_dev, (size_t) RMAX * D * 4));

    hipStream_t st;
    CHECK(hipStreamCreateWithFlags(&st, hipStreamNonBlocking));
    hipEvent_t ev0, ev1;
    CHECK(hipEventCreate(&ev0));
    CHECK(hipEventCreate(&ev1));

    void * state = cand->prepare ? cand->prepare(ds.shape, ds.w) : nullptr;

    std::string json = "{\n";
    json += "  \"candidate\": \"" + std::string(cand->name) + "\",\n";
    json += "  \"source_sha256\": \"" KFFN_SOURCE_SHA256 "\",\n";
    json += "  \"source_revision\": \"" KFFN_SOURCE_REVISION "\",\n";
    json += "  \"compiler\": \"" + json_escape(KFFN_COMPILER) + "\",\n";
    json += "  \"dataset\": \"" + json_escape(dir) + "\",\n";
    json += "  \"model\": \"" + json_escape(ds.model) + "\",\n";
    json += "  \"bonsai_commit\": \"" + json_escape(ds.source_commit) + "\",\n";
    json += "  \"layer\": " + std::to_string(ds.shape.layer) + ",\n";
    json += "  \"gpu\": \"" + std::string(prop.gcnArchName) + "\",\n";
    json += "  \"cus\": " + std::to_string(prop.multiProcessorCount) + ",\n";
    json += "  \"iters\": " + std::to_string(iters) + ", \"warmup\": " + std::to_string(warmup) + ",\n";
    json += "  \"cases\": [\n";

    bool first_case = true;
    for (const kffn::Case & c : ds.cases) {
        if (!rows.empty() && std::find(rows.begin(), rows.end(), c.nrows) == rows.end()) continue;
        const int nrows = c.nrows;
        w.grid = cand->grid ? cand->grid(nrows) : 0;
        w.prof_slots = cand->nstages + 1;

        CHECK(hipMemcpy(x_in_dev, c.x_in.data(), (size_t) nrows * D * 4, hipMemcpyHostToDevice));
        // every launch consumes one barrier/work slot; a reused non-zero slot would let grid_sync
        // pass without synchronising, so the ring is zeroed again for each case
        CHECK(hipMemset(bar_ring, 0, (size_t) slots * BAR_STRIDE * 4));
        CHECK(hipMemset(work_ring, 0, (size_t) slots * WORK_STRIDE * 4));
        CHECK(hipMemset(prof_ring, 0, (size_t) slots * PROF_STRIDE * 8));

        auto slot = [&](int i) {
            kffn::Work k = w;
            k.bar = bar_ring + (size_t) i * BAR_STRIDE;
            k.work = work_ring + (size_t) i * WORK_STRIDE;
            k.prof = prof_ring + (size_t) i * PROF_STRIDE;
            return k;
        };
        auto one = [&](int i) {
            CHECK(hipMemcpyAsync(w.x, x_in_dev, (size_t) nrows * D * 4, hipMemcpyDeviceToDevice, st));
            const kffn::Work k = slot(i);
            cand->run(state, ds.shape, ds.w, k, nrows, st);
        };

        for (int i = 0; i < warmup; i++) one(i);
        CHECK(hipStreamSynchronize(st));
        CHECK(hipGetLastError());

        // one clean pass for the numeric comparison and the intermediates
        one(slots - 1);
        CHECK(hipStreamSynchronize(st));
        std::vector<float> got((size_t) nrows * D);
        CHECK(hipMemcpy(got.data(), w.x, (size_t) nrows * D * 4, hipMemcpyDeviceToHost));
        const Err err = compare(got, c.x_ref);
        Err gate_err{}, up_err{};
        bool have_gu = false;
        long ff_quant_mismatch = -1, ff_sum_mismatch = -1;
        Err ff_scale_err{};
        if (cand->emits_ff_quant && !c.xq_ff.empty()) {
            std::vector<int8_t> q((size_t) RMAX * FF);
            CHECK(hipMemcpy(q.data(), w.xq, q.size(), hipMemcpyDeviceToHost));
            ff_quant_mismatch = 0;
            for (int r = 0; r < nrows; r++)
                for (int i = 0; i < FF; i++)
                    if (q[(size_t) r * FF + i] != c.xq_ff[(size_t) r * FF + i]) ff_quant_mismatch++;
            std::vector<float> scales(size_t(nrows)*(FF/128));
            std::vector<int> sums(scales.size());
            CHECK(hipMemcpy(scales.data(),w.xs,scales.size()*4,hipMemcpyDeviceToHost));
            CHECK(hipMemcpy(sums.data(),w.xsum,sums.size()*4,hipMemcpyDeviceToHost));
            ff_scale_err=compare(scales,c.xs_ff);
            ff_sum_mismatch=0;
            for(size_t i=0;i<sums.size();++i) ff_sum_mismatch += sums[i]!=c.xsum_ff[i];
        }
        if (cand->emits_gate_up && !c.gate_ref.empty()) {
            std::vector<float> gu((size_t) 2 * RMAX * FF);
            CHECK(hipMemcpy(gu.data(), w.gu, gu.size() * 4, hipMemcpyDeviceToHost));
            std::vector<float> g((size_t) nrows * FF), u((size_t) nrows * FF);
            for (int r = 0; r < nrows; r++) {
                memcpy(&g[(size_t) r * FF], &gu[(size_t) r * FF], FF * 4);
                memcpy(&u[(size_t) r * FF], &gu[(size_t) RMAX * FF + (size_t) r * FF], FF * 4);
            }
            gate_err = compare(g, c.gate_ref);
            up_err = compare(u, c.up_ref);
            have_gu = true;
        }

        // The repetitions are enqueued back to back with the restore between them, so the device
        // never idles inside a burst: an idling GPU drops its memory clock and a bandwidth-bound
        // kernel then measures the idle clock instead of the deployed one. Every interval is still
        // bracketed by its own event pair and every sample is kept.
        std::vector<double> ms;
        std::vector<std::vector<double>> stage_us((size_t) cand->nstages);
        std::vector<hipEvent_t> e0((size_t) iters), e1((size_t) iters);
        for (int i = 0; i < iters; i++) { CHECK(hipEventCreate(&e0[(size_t) i])); CHECK(hipEventCreate(&e1[(size_t) i])); }
        const auto burst0 = std::chrono::steady_clock::now();
        for (int i = 0; i < iters; i++) {
            const int s = warmup + i;
            CHECK(hipMemcpyAsync(w.x, x_in_dev, (size_t) nrows * D * 4, hipMemcpyDeviceToDevice, st));
            CHECK(hipEventRecord(e0[(size_t) i], st));
            cand->run(state, ds.shape, ds.w, slot(s), nrows, st);
            CHECK(hipEventRecord(e1[(size_t) i], st));
        }
        CHECK(hipStreamSynchronize(st));
        const double burst_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - burst0).count();
        std::vector<unsigned long long> pall((size_t) iters * PROF_STRIDE);
        CHECK(hipMemcpy(pall.data(), prof_ring + (size_t) warmup * PROF_STRIDE, pall.size() * 8, hipMemcpyDeviceToHost));
        for (int i = 0; i < iters; i++) {
            float el = 0;
            CHECK(hipEventElapsedTime(&el, e0[(size_t) i], e1[(size_t) i]));
            ms.push_back(el);
            const unsigned long long * p = &pall[(size_t) i * PROF_STRIDE];
            for (int t = 0; t < cand->nstages; t++)
                stage_us[(size_t) t].push_back(p[t + 1] > p[t] ? (double) (p[t + 1] - p[t]) / 100.0 : 0.0); // s_memrealtime, 100 MHz
            CHECK(hipEventDestroy(e0[(size_t) i]));
            CHECK(hipEventDestroy(e1[(size_t) i]));
        }
        const std::vector<double> wall_ms { burst_ms / (double) iters };

        const double med = median(ms);
        const size_t wbytes = cand->weight_bytes ? cand->weight_bytes(ds.shape,nrows) : 2 * halo_bytes(FF, D) + halo_bytes(D, FF);
        const double gbs = (double) wbytes / (med * 1e-3) / 1e9;

        if (!first_case) json += ",\n";
        first_case = false;
        json += "    {\n";
        json += "      \"nrows\": " + std::to_string(nrows) + ",\n";
        json += "      \"input_kind\": \"" + json_escape(c.input_kind) + "\",\n";
        json += "      \"tokens\": [";
        for (size_t i = 0; i < c.tokens.size(); i++) json += (i ? ", " : "") + std::to_string(c.tokens[i]);
        json += "],\n";
        json += "      \"grid\": " + std::to_string(w.grid) + ", \"workgroup\": 256,\n";
        const std::string instr = cand->instruction ? cand->instruction(nrows) : "unspecified";
        json += "      \"matvec_instruction\": \"" + instr + "\",\n";
        json += "      \"ms_median\": " + std::to_string(med) + ",\n";
        json += "      \"ms_min\": " + std::to_string(*std::min_element(ms.begin(), ms.end())) + ",\n";
        json += "      \"ms_max\": " + std::to_string(*std::max_element(ms.begin(), ms.end())) + ",\n";
        json += "      \"ms_p90\": " + std::to_string(quantile(ms, 0.9)) + ",\n";
        json += "      \"ms_end_to_end_per_ffn\": " + std::to_string(wall_ms[0]) + ",\n";
        json += "      \"weight_bytes\": " + std::to_string(wbytes) + ",\n";
        json += "      \"weight_gbps_at_median\": " + std::to_string(gbs) + ",\n";
        json += "      \"error_vs_engine\": " + error_json(err) + ",\n";
        if (have_gu) {
            json += "      \"gate_error\": " + error_json(gate_err) + ",\n";
            json += "      \"up_error\": " + error_json(up_err) + ",\n";
        }
        if (ff_quant_mismatch >= 0) {
            json += "      \"hidden_int8_mismatches\": " + std::to_string(ff_quant_mismatch)
                  + ", \"hidden_int8_elements\": " + std::to_string((long) nrows * FF) + ",\n";
            json += "      \"hidden_scale_error\": " + error_json(ff_scale_err) + ",\n";
            json += "      \"hidden_sum_mismatches\": " + std::to_string(ff_sum_mismatch) + ",\n";
        }
        json += "      \"stages_us_median\": {";
        for (int t = 0; t < cand->nstages; t++)
            json += std::string(t ? ", " : "") + "\"" + cand->stages[t] + "\": " + std::to_string(median(stage_us[(size_t) t]));
        json += "},\n";
        json += "      \"stages_us\": {";
        for (int t = 0; t < cand->nstages; t++) {
            json += std::string(t ? ", " : "") + "\"" + cand->stages[t] + "\": [";
            for (size_t i = 0; i < stage_us[(size_t) t].size(); i++) json += (i ? "," : "") + std::to_string(stage_us[(size_t) t][i]);
            json += "]";
        }
        json += "},\n";
        json += "      \"ms_samples\": [";
        for (size_t i = 0; i < ms.size(); i++) json += (i ? "," : "") + std::to_string(ms[i]);
        json += "],\n";
        json += "      \"burst_wall_ms\": " + std::to_string(wall_ms[0] * (double) iters) + "\n    }";

        fprintf(stderr, "%s rows=%-2d grid=%-4d %-24s median %.3f ms  min %.3f  max %.3f  p90 %.3f  weights %.1f GB/s  max|err| %.3e (ref rms %.3e)\n",
                cand->name, nrows, w.grid, instr.c_str(), med, *std::min_element(ms.begin(), ms.end()),
                *std::max_element(ms.begin(), ms.end()), quantile(ms, 0.9), gbs, err.max_abs, err.ref_rms);
        for (int t = 0; t < cand->nstages; t++)
            fprintf(stderr, "    %-16s %8.1f us  %5.1f%%\n", cand->stages[t], median(stage_us[(size_t) t]),
                    100.0 * median(stage_us[(size_t) t]) / (med * 1000.0));
    }
    json += "\n  ]\n}\n";

    if (cand->release) cand->release(state);
    if (!out_path.empty()) {
        FILE * f = fopen(out_path.c_str(), "w");
        if (!f) throw std::runtime_error("cannot write " + out_path);
        fwrite(json.data(), 1, json.size(), f);
        fclose(f);
        fprintf(stderr, "wrote %s\n", out_path.c_str());
    } else {
        fwrite(json.data(), 1, json.size(), stdout);
    }
    return 0;
} catch (const std::exception & e) {
    fprintf(stderr, "ffn-bench: %s\n", e.what());
    return 1;
}
