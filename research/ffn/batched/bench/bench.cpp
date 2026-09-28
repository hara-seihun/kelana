// Batched FFN comparison driver.
//
// One prepare per candidate for the whole run, with the largest requested batch as the maximum and
// the input buffer still poisoned, so a candidate cannot specialise its preparation on activation
// values or on one batch size. One timed interval is one `run` call over a batch of real contextual
// rows; every sample is kept. Errors are measured against the residual the deployed engine itself
// produced for those rows.
#include "batch_dataset.h"
#include "sha256.hpp"
#include "build-info.h"
#include "../geometry.hpp"
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

#include "timing.hpp"

namespace {

struct Err {
    double max_abs = 0, max_rel = 0, rms = 0, ref_rms = 0, rel_rms = 0, bias = 0;
    double worst_row_rel_rms = 0;
    size_t bit_mismatches = 0, nonfinite = 0;
};

Err compare(const std::vector<float> & got, const std::vector<float> & ref, int rows, int width) {
    Err e;
    double se = 0, sr = 0, sb = 0;
    for (int r = 0; r < rows; r++) {
        double rse = 0, rsr = 0;
        for (int i = 0; i < width; i++) {
            const size_t k = (size_t) r * width + i;
            const double a = got[k], b = ref[k];
            if (!std::isfinite(a)) { e.nonfinite++; continue; }
            e.bit_mismatches += std::memcmp(&got[k], &ref[k], sizeof(float)) != 0;
            const double dd = a - b, d = std::fabs(dd);
            e.max_abs = std::max(e.max_abs, d);
            if (std::fabs(b) > 1e-6) e.max_rel = std::max(e.max_rel, d / std::fabs(b));
            se += d * d; sr += b * b; sb += dd;
            rse += d * d; rsr += b * b;
        }
        if (rsr > 0) e.worst_row_rel_rms = std::max(e.worst_row_rel_rms, std::sqrt(rse / rsr));
    }
    const double n = (double) rows * width;
    e.rms = std::sqrt(se / n);
    e.ref_rms = std::sqrt(sr / n);
    e.rel_rms = e.ref_rms > 0 ? e.rms / e.ref_rms : 0;
    e.bias = sb / n;
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
    for (char c : s) {
        if (c == '"' || c == '\\') { o += '\\'; o += c; continue; }
        if (c == '\n') { o += "\\n"; continue; }
        o += c;
    }
    return o;
}
std::string real(double v) { char b[64]; snprintf(b, sizeof b, "%.17g", v); return b; }
std::string error_json(const Err & e) {
    return "{ \"max_abs\": " + real(e.max_abs) + ", \"max_rel\": " + real(e.max_rel)
         + ", \"rms\": " + real(e.rms) + ", \"ref_rms\": " + real(e.ref_rms)
         + ", \"rel_rms\": " + real(e.rel_rms) + ", \"bias\": " + real(e.bias)
         + ", \"worst_row_rel_rms\": " + real(e.worst_row_rel_rms)
         + ", \"bit_mismatches\": " + std::to_string(e.bit_mismatches)
         + ", \"nonfinite\": " + std::to_string(e.nonfinite) + " }";
}
const char * claim_name(kelana_batch::Claim c) {
    return c == kelana_batch::Claim::exact_reference ? "exact_reference" : "approximate";
}

} // namespace

int main(int argc, char ** argv) try {
    std::string dir, want = "all", out_path, reference_candidate;
    std::vector<int> rows_list;
    int iters = 100, warmup = 20, rounds = 10, ramp_ms = 2000;
    unsigned seed = 812735;
    bool list_only = false;
    for (int i = 1; i < argc; i++) {
        const std::string a = argv[i];
        auto next = [&]() { if (i + 1 >= argc) throw std::runtime_error("missing value for " + a); return std::string(argv[++i]); };
        if (a == "--dataset") dir = next();
        else if (a == "--candidate") want = next();
        else if (a == "--reference-candidate") reference_candidate = next();
        else if (a == "--iters") iters = std::stoi(next());
        else if (a == "--warmup") warmup = std::stoi(next());
        else if (a == "--ramp-ms") ramp_ms = std::stoi(next());
        else if (a == "--rounds") rounds = std::stoi(next());
        else if (a == "--seed") seed = unsigned(std::stoul(next()));
        else if (a == "--json") out_path = next();
        else if (a == "--list") list_only = true;
        else if (a == "--rows") { const std::string v = next(); size_t p = 0;
            while (p < v.size()) { const size_t q = v.find(',', p); rows_list.push_back(std::stoi(v.substr(p, q == std::string::npos ? q : q - p))); if (q == std::string::npos) break; p = q + 1; } }
        else throw std::runtime_error("unknown argument " + a);
    }
    auto & reg = kelana_batch::registry();
    if (list_only) {
        for (const auto & c : reg) printf("%-24s %-16s %s\n", c.name, claim_name(c.claim), c.description ? c.description : "");
        return 0;
    }
    if (!std::getenv("KELANA_GPU_RESEARCH_LOCK")) throw std::runtime_error("Run GPU benchmarks through ../hardware-run to serialize research jobs");
    if (dir.empty()) throw std::runtime_error(
        "usage: batch-bench --dataset DIR [--candidate NAME,NAME|all] [--rows 32,64,128,256] [--iters N] [--rounds N] [--seed N] [--warmup N] [--ramp-ms N] [--reference-candidate NAME] [--json FILE] [--list]");
    if (iters<1 || warmup<1 || rounds<1 || ramp_ms<0) throw std::runtime_error("iters, warmup and rounds must be positive; ramp-ms must be nonnegative");
    rounds=std::min(rounds,iters);
    if (rows_list.empty()) rows_list = { 32, 64, 128, 256 };
    for(int rows:rows_list)if(rows<1)throw std::runtime_error("rows must be positive");

    kbatch::Dataset ds = kbatch::load(dir);
    const int D = ds.D, FF = ds.FF;
    const int max_rows = *std::max_element(rows_list.begin(), rows_list.end());
    if (max_rows > ds.max_rows())
        throw std::runtime_error("dataset holds " + std::to_string(ds.max_rows()) + " rows, " + std::to_string(max_rows) + " requested");

    std::vector<const kelana_batch::Candidate *> run_list;
    std::vector<std::string> names;
    if(want!="all") {std::stringstream ss(want);std::string name;while(std::getline(ss,name,','))names.push_back(name);}
    for(const auto &name:names) {
        if(std::none_of(reg.begin(),reg.end(),[&](const auto &c){return name==c.name;}))
            throw std::runtime_error("unknown candidate "+name);
    }
    for (const auto & c : reg) if (want == "all" || std::find(names.begin(),names.end(),c.name)!=names.end()) run_list.push_back(&c);
    if (run_list.empty()) {
        std::string have;
        for (const auto & c : reg) { have += " "; have += c.name; }
        throw std::runtime_error("no candidate named " + want + "; registered:" + have);
    }

    size_t reference_index = run_list.size();
    if (!reference_candidate.empty()) {
        for (size_t i=0;i<run_list.size();++i)
            if (reference_candidate == run_list[i]->name) reference_index=i;
        if (reference_index == run_list.size())
            throw std::runtime_error("reference-candidate must be among selected candidates");
    }

    hipDeviceProp_t prop{};
    CHECK(hipGetDeviceProperties(&prop, 0));
    const auto geom=kelana_batch::geometry(prop);
    hipStream_t st;
    CHECK(hipStreamCreateWithFlags(&st, hipStreamNonBlocking));

    float * in_dev = nullptr, * out_dev = nullptr;
    CHECK(hipMalloc(&in_dev, (size_t) max_rows * D * 4));
    CHECK(hipMalloc(&out_dev, (size_t) max_rows * D * 4));
    // Poison both buffers before any prepare runs: a preparation that reads activations sees only
    // signalling garbage, and a candidate that forgets to write part of its output shows it.
    CHECK(hipMemset(in_dev, 0x7f, (size_t) max_rows * D * 4));
    CHECK(hipMemset(out_dev, 0x7f, (size_t) max_rows * D * 4));

    const kelana_batch::Weights w = ds.weights();
    std::vector<void *> states(run_list.size(), nullptr);
    std::vector<double> prepare_ms(run_list.size(), 0);
    for (size_t i = 0; i < run_list.size(); i++) {
        const auto t0 = std::chrono::steady_clock::now();
        states[i] = run_list[i]->prepare ? run_list[i]->prepare(w, max_rows) : nullptr;
        CHECK(hipStreamSynchronize(nullptr));
        prepare_ms[i] = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
    }

    const double macs_per_row = 3.0 * (double) D * (double) FF;   // gate, up, down
    std::string json = "{\n";
    json += "  \"format\": \"kelana-batch-bench/2\",\n";
    json += "  \"schedule\": \"randomized warmed candidate blocks within each round\",\n";
    json += "  \"gpu_clients_before\": "+kbtelemetry::client_snapshot()+",\n";
    json += "  \"rounds\": "+std::to_string(rounds)+", \"seed\": "+std::to_string(seed)+",\n";
    json += "  \"isolation\": \"Research lock coordinates participating workers only. Other GPU clients and host power competition are not excluded.\",\n";
    json += "  \"dataset\": \"" + json_escape(dir) + "\",\n";
    json += "  \"dataset_manifest_sha256\": \"" + kbsha::sha256_file(dir + "/manifest.json") + "\",\n";
    json += "  \"model\": \"" + json_escape(ds.model) + "\",\n";
    json += "  \"layer\": " + std::to_string(ds.layer) + ", \"D\": " + std::to_string(D) + ", \"FF\": " + std::to_string(FF) + ",\n";
    json += "  \"input_kind\": \"" + json_escape(ds.input_kind) + "\",\n";
    json += "  \"document\": \"" + json_escape(ds.document) + "\",\n";
    json += "  \"document_sha256\": \"" + ds.document_sha256 + "\",\n";
    json += "  \"tokens_sha256\": \"" + ds.tokens_sha256 + "\",\n";
    json += "  \"bonsai_commit_of_dataset\": \"" + ds.bonsai_commit + "\",\n";
    json += "  \"bonsai_revision_at_build\": \"" KB_BONSAI_REVISION "\",\n";
    json += "  \"kelana_revision\": \"" KB_KELANA_REVISION "\", \"kelana_dirty\": " + std::string(KB_KELANA_DIRTY ? "true" : "false") + ",\n";
    json += "  \"harness_sha256\": \"" KB_HARNESS_SHA256 "\",\n";
    json += "  \"candidate_sources\": \"" KB_CANDIDATE_SOURCES "\",\n";
    json += "  \"candidate_sources_sha256\": \"" KB_CANDIDATE_SHA256 "\",\n";
    json += "  \"compiler\": \"" + json_escape(KB_COMPILER) + "\",\n";
    json += "  \"gpu\": \"" + std::string(prop.gcnArchName) + "\", \"hip_multiprocessor_count\": " + std::to_string(geom.hip_processors)
          + ", \"wgps\": "+std::to_string(geom.wgps)+", \"cus\": "+std::to_string(geom.cus)+", \"simd32_count\": "+std::to_string(geom.simds)+",\n";
    json += "  \"iters\": " + std::to_string(iters) + ", \"warmup\": " + std::to_string(warmup) + ", \"ramp_ms\": " + std::to_string(ramp_ms) + ",\n";
    json += "  \"prepare_max_batch\": " + std::to_string(max_rows) + ",\n";
    json += "  \"reference_candidate\": \"" + json_escape(reference_candidate) + "\",\n";
    json += "  \"runs\": [\n";
    bool first = true;
    std::string telemetry="[";
    bool first_telemetry=true;

    for (int rows : rows_list) {
        std::vector<float> x_in, x_ref;
        ds.batch(rows, x_in, x_ref);
        const std::string in_sha = kbsha::sha256_hex(x_in.data(), x_in.size() * 4);
        const std::string ref_sha = kbsha::sha256_hex(x_ref.data(), x_ref.size() * 4);
        CHECK(hipMemcpy(in_dev, x_in.data(), x_in.size() * 4, hipMemcpyHostToDevice));
        kbtelemetry::Recorder recorder(prop.pciDomainID,prop.pciBusID,prop.pciDeviceID);
        auto measurements=kbtiming::measure(run_list,states,rows,in_dev,out_dev,st,iters,rounds,warmup,seed+unsigned(rows),ramp_ms);
        if(!first_telemetry)telemetry+=",";
        first_telemetry=false;
        telemetry+="{\"rows\":"+std::to_string(rows)+",\"trace\":"+recorder.json()+"}";

        std::vector<float> candidate_reference;
        if (reference_index < run_list.size()) {
            CHECK(hipMemset(out_dev,0x7f,(size_t)rows*D*4));
            run_list[reference_index]->run(states[reference_index],rows,in_dev,out_dev,st);
            CHECK(hipStreamSynchronize(st));CHECK(hipGetLastError());
            candidate_reference.resize((size_t)rows*D);
            CHECK(hipMemcpy(candidate_reference.data(),out_dev,candidate_reference.size()*4,hipMemcpyDeviceToHost));
            if (std::any_of(candidate_reference.begin(),candidate_reference.end(),[](float x){return !std::isfinite(x);}))
                throw std::runtime_error("reference candidate produced nonfinite output");
        }
        for (size_t ci = 0; ci < run_list.size(); ci++) {
            const kelana_batch::Candidate * c = run_list[ci];
            CHECK(hipMemset(out_dev, 0x7f, (size_t) rows * D * 4));

            c->run(states[ci], rows, in_dev, out_dev, st);
            CHECK(hipStreamSynchronize(st));
            CHECK(hipGetLastError());

            std::vector<float> got((size_t) rows * D);
            CHECK(hipMemcpy(got.data(), out_dev, got.size() * 4, hipMemcpyDeviceToHost));
            const Err err = compare(got, x_ref, rows, D);

            const auto &measurement=measurements[ci];
            const auto &ms=measurement.ms;
            const double burst_ms=measurement.wall_ms;
            const double med = median(ms), lo = *std::min_element(ms.begin(), ms.end()), hi = *std::max_element(ms.begin(), ms.end());
            // The resident bonsai-halo server shares the GPU, so a minority of intervals land in a
            // much slower regime. Those samples are kept and counted rather than filtered away.
            size_t stalled = 0;
            for (double v : ms) if (v > 2.0 * med) stalled++;
            const size_t resident = c->resident_bytes ? c->resident_bytes(states[ci]) : 0;

            if (!first) json += ",\n";
            first = false;
            json += "    {\n";
            json += "      \"candidate\": \"" + std::string(c->name) + "\",\n";
            json += "      \"claim\": \"" + std::string(claim_name(c->claim)) + "\",\n";
            json += "      \"description\": \"" + json_escape(c->description ? c->description : "") + "\",\n";
            json += "      \"rows\": " + std::to_string(rows) + ",\n";
            json += "      \"input_sha256\": \"" + in_sha + "\", \"reference_sha256\": \"" + ref_sha + "\",\n";
            json += "      \"output_sha256\": \"" + kbsha::sha256_hex(got.data(), got.size() * 4) + "\",\n";
            json += "      \"prepare_ms\": " + real(prepare_ms[ci]) + ", \"resident_bytes\": " + std::to_string(resident) + ",\n";
            json += "      \"ms_median\": " + real(med) + ", \"ms_min\": " + real(lo) + ", \"ms_max\": " + real(hi) + ",\n";
            json += "      \"ms_p10\": " + real(quantile(ms, 0.10)) + ", \"ms_p90\": " + real(quantile(ms, 0.90)) + ",\n";
            json += "      \"stalled_samples_over_2x_median\": " + std::to_string(stalled) + ",\n";
            json += "      \"burst_wall_ms\": " + real(burst_ms) + ", \"ms_wall_per_call\": " + real(burst_ms / iters) + ",\n";
            json += "      \"rows_per_second_at_median\": " + real(rows / (med * 1e-3)) + ",\n";
            json += "      \"us_per_row_at_median\": " + real(med * 1000.0 / rows) + ",\n";
            json += "      \"mac_per_row\": " + real(macs_per_row) + ",\n";
            json += "      \"tops_at_median\": " + real(2.0 * macs_per_row * rows / (med * 1e-3) / 1e12) + ",\n";
            json += "      \"error_vs_engine\": " + error_json(err) + ",\n";
            if (!candidate_reference.empty()) {
                json += "      \"candidate_reference_sha256\": \"" + kbsha::sha256_hex(candidate_reference.data(),candidate_reference.size()*4) + "\",\n";
                json += "      \"error_vs_candidate\": " + error_json(compare(got,candidate_reference,rows,D)) + ",\n";
            }
            json += "      \"timing_blocks\": "+kbtiming::blocks_json(measurement)+",\n";
            json += "      \"ms_samples\": [";
            for (size_t i = 0; i < ms.size(); i++) json += (i ? "," : "") + real(ms[i]);
            json += "]\n    }";

            fprintf(stderr, "%-22s rows=%-4d median %8.3f ms  min %8.3f  p90 %8.3f  max %8.3f  %7.1f rows/s  %5.2f TOPS  rel_rms %.3e  max|err| %.3e  stalls %zu/%d\n",
                    c->name, rows, med, lo, quantile(ms, 0.90), hi, rows / (med * 1e-3),
                    2.0 * macs_per_row * rows / (med * 1e-3) / 1e12, err.rel_rms, err.max_abs, stalled, iters);
        }
    }
    json += "\n  ],\n  \"telemetry\": "+telemetry+"],\n  \"gpu_clients_after\": "+kbtelemetry::client_snapshot()+"\n}\n";

    for (size_t i = 0; i < run_list.size(); i++) if (run_list[i]->release) run_list[i]->release(states[i]);
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
    fprintf(stderr, "batch-bench: %s\n", e.what());
    return 1;
}
