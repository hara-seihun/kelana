// Teacher-forced full-model scoring for the half carrier.
//
// Every configuration is scored twice: against the original model, and against the matched control
// that shares its activation quantiser and differs only in the carrier. The second reference is the
// one that measures the carrier. Main's earlier runs showed why: a change that reroutes coarse
// quantisation noise can score *better* against the original than the control it perturbs, and the
// same trap appeared at one FFN, where the carrier looked free against the engine and costs 0.127%
// against its own control.
//
// Adapted from research/ffn/batched/lossy/quality.cpp, which owns the activation-quantiser
// intervention; the scoring, prompts and engine driving are unchanged.
#include "policy.hpp"
#include "engine.h"
#include "tokenizer.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace halo;

struct Observation { int prompt, position, target; std::vector<float> logits; };
struct Config { int bits, layers, carrier; };
struct Metrics { double kl = 0, tv = 0, nll_delta = 0, max_logit = 0, entropy = 0; bool changed = false; };

Metrics compare(const Observation &a, const Observation &b) {
    if (a.logits.size() != b.logits.size()) throw std::runtime_error("logit shape mismatch");
    double ma = *std::max_element(a.logits.begin(), a.logits.end());
    double mb = *std::max_element(b.logits.begin(), b.logits.end());
    double za = 0, zb = 0;
    for (size_t i = 0; i < a.logits.size(); ++i) {
        if (!std::isfinite(a.logits[i]) || !std::isfinite(b.logits[i])) throw std::runtime_error("nonfinite logit");
        za += std::exp(double(a.logits[i]) - ma); zb += std::exp(double(b.logits[i]) - mb);
    }
    za = ma + std::log(za); zb = mb + std::log(zb);
    Metrics m;
    for (size_t i = 0; i < a.logits.size(); ++i) {
        const double la = a.logits[i] - za, lb = b.logits[i] - zb, p = std::exp(la), q = std::exp(lb);
        m.kl += p * (la - lb); m.tv += std::fabs(p - q) / 2; m.entropy -= p * la;
        m.max_logit = std::max(m.max_logit, std::fabs(double(a.logits[i]) - b.logits[i]));
    }
    m.nll_delta = (zb - b.logits[a.target]) - (za - a.logits[a.target]);
    m.changed = std::max_element(a.logits.begin(), a.logits.end()) - a.logits.begin() !=
                std::max_element(b.logits.begin(), b.logits.end()) - b.logits.begin();
    return m;
}

int g_scale_shift = 5, g_scale_rne = 1;

// carrier: 0 off, 1 gate/up half, 2 both half, 3 both FP32, 4 both FP32 reverse order,
// 5 gate/up FP32. Mode 5 exists so mode 1 has a control that changes the same projections it does:
// comparing gate/up-half against a control that also moved the down projection's schedule mixes two
// changes, which is what mode 3 would do for it.
CarrierPolicy policy_for(Config c, uint64_t mask, uint64_t cmask, int capture_layer) {
    CarrierPolicy p{};
    p.layers = mask; p.carrier = cmask; p.bits = c.bits; p.direct = 1; p.down = 1;
    p.carrier_gu = c.carrier >= 1;
    p.carrier_down = c.carrier == 2 || c.carrier == 3 || c.carrier == 4;
    p.scale_rne = g_scale_rne; p.scale_shift = g_scale_shift;
    p.capture_layer = capture_layer;
    p.carrier_fp32 = (c.carrier == 3 || c.carrier == 5) ? 1 : c.carrier == 4 ? 2 : 0;
    return p;
}

struct Summary { double kl = 0, max_kl = 0, tv = 0, nll = 0; int changed = 0; };
Summary summarize(const std::vector<Observation> &ref, const std::vector<Observation> &got) {
    Summary s;
    for (size_t i = 0; i < ref.size(); ++i) {
        const Metrics m = compare(ref[i], got[i]);
        s.kl += m.kl; s.tv += m.tv; s.nll += m.nll_delta; s.changed += m.changed;
        s.max_kl = std::max(s.max_kl, m.kl);
    }
    const double n = double(ref.size());
    s.kl /= n; s.tv /= n; s.nll /= n;
    return s;
}

std::string counts_json(const unsigned (&v)[64]) {
    std::string out = "[";
    for (int i = 0; i < 64; ++i) { if (i) out += ','; out += std::to_string(v[i]); }
    return out + "]";
}

int main(int argc, char **argv) try {
    std::string model = "/path/to/workspace/data/bonsai2/PTQ1_0.gguf", out, capture_prefix;
    int tokens = 64, capture_layer = -1;
    std::string configuration = "8:0:0,4:64:0,4:64:1,4:64:2";
    for (int i = 1; i < argc; ++i) {
        const std::string a = argv[i];
        auto next = [&] { if (i + 1 >= argc) throw std::runtime_error("missing argument"); return std::string(argv[++i]); };
        if (a == "--out") out = next();
        else if (a == "--tokens") tokens = std::stoi(next());
        else if (a == "--configs") configuration = next();
        else if (a == "--scale-shift") g_scale_shift = std::stoi(next());
        else if (a == "--truncate-scale") g_scale_rne = 0;
        else if (a == "--capture") capture_layer = std::stoi(next());
        else if (a == "--capture-prefix") capture_prefix = next();
        else if (a == "--model") model = next();
        else throw std::runtime_error("unknown argument " + a);
    }
    if (tokens < 8 || tokens % 8) throw std::runtime_error("a token count divisible by 8 is required");
    if (out.empty() && capture_prefix.empty()) throw std::runtime_error("--out FILE, or --capture LAYER with --capture-prefix");

    std::vector<Config> configs;
    { std::stringstream cs(configuration); std::string entry;
      while (std::getline(cs, entry, ',')) {
          Config c{};
          if (std::sscanf(entry.c_str(), "%d:%d:%d", &c.bits, &c.layers, &c.carrier) != 3 ||
              c.bits < 2 || c.bits > 8 || c.layers < 0 || c.layers > 64 || c.carrier < 0 || c.carrier > 5)
              throw std::runtime_error("invalid config " + entry + "; want bits:layers:carrier with carrier 0 (off), 1 (gate/up), 2 (both), 3 (both, FP32), 4 (both, FP32 reverse order), 5 (gate/up, FP32)");
          if (c.carrier && c.bits != 4)
              throw std::runtime_error("the carrier is only defined for four-bit activations: a block dot of "
                                       "eight-bit codes reaches 16256 and binary16 stops being exact at 2048");
          configs.push_back(c);
      } }

    // Same two prompts as the lossy directory, so the scored positions are comparable.
    std::vector<std::string> prompts = {
        "A researcher is comparing two ways to multiply matrices. The first method performs every multiplication separately. The second method shares intermediate sums across many outputs. To make a fair comparison, she records the cost of preparing the inputs, reading the weights, and producing the final answers. She also checks that rounding errors do not accumulate when the same computation appears repeatedly in a larger system. Explain why a reduction in the number of arithmetic instructions does not necessarily imply a reduction in total running time, and give an example involving memory access.",
        "On Saturday morning, the train left the coastal town and climbed into the mountains. Maya had packed a notebook, a small camera, and enough food for the afternoon. At the next station she met an engineer who was travelling to inspect a bridge. They discussed the weather and the history of the railway before the conversation turned to the unusual rock formations outside the window. By noon, clouds had gathered over the highest peaks, but the valley below was still bright. Describe what they might notice as the train approaches the old stone viaduct."
    };
    Tokenizer tokenizer; tokenizer.load(model);
    std::vector<std::vector<int>> tokenized;
    for (auto &p : prompts) {
        auto t = tokenizer.encode(p, false);
        if (int(t.size()) < tokens + 1) throw std::runtime_error("prompt too short");
        t.resize(tokens + 1);
        tokenized.push_back(std::move(t));
    }
    unsetenv("HALO_STOP"); unsetenv("HALO_LAYERS"); unsetenv("HALO_DUMP");
    Engine engine; engine.load(model, 8, 1);

    const int passes = int(prompts.size()) * tokens / 8;
    const int gu_groups = 2 * (halo::FF / 32) / 8, down_groups = (halo::D / 32) / 8;

    auto evaluate = [&](Config c, CarrierCounts &counts) {
        std::vector<Observation> observations;
        reset_carrier_counts();
        const uint64_t mask = c.layers == 64 ? ~uint64_t(0) : ((uint64_t(1) << c.layers) - 1);
        const uint64_t cmask = c.carrier ? mask : 0;
        for (size_t p = 0; p < tokenized.size(); ++p) {
            engine.reset();
            for (int pos = 0; pos < tokens; pos += 8) {
                set_carrier_policy(policy_for(c, mask, cmask, capture_layer));
                std::vector<Engine::Seq *> sequences{&engine.seq0};
                std::vector<std::vector<int>> input{std::vector<int>(tokenized[p].begin() + pos, tokenized[p].begin() + pos + 8)};
                std::vector<int> argmax;
                engine.forward(sequences, input, true, &argmax);
                for (int row = 0; row < 8; ++row) {
                    Observation o{int(p), pos + row, tokenized[p][pos + row + 1], {}};
                    engine.get_logits(o.logits, row);
                    observations.push_back(std::move(o));
                }
            }
        }
        read_carrier_counts(counts);
        // The intervention has to have run on exactly the layers it was given and nowhere else.
        const unsigned quant_expected = unsigned(passes * 8 * ((halo::D + halo::FF) / 1024));
        for (int l = 0; l < 64; ++l) {
            const bool on = l < c.layers;
            const unsigned q = (c.bits < 8 && on) ? quant_expected : 0u;
            const bool down_on = c.carrier == 2 || c.carrier == 3 || c.carrier == 4;
            const unsigned g = (c.carrier >= 1 && on) ? unsigned(passes * gu_groups) : 0u;
            const unsigned d = (down_on && on) ? unsigned(passes * down_groups) : 0u;
            if (counts.quant[l] != q || counts.gate_up[l] != g || counts.down[l] != d || counts.declined[l] != 0)
                throw std::runtime_error("intervention count mismatch at layer " + std::to_string(l) +
                    ": quant " + std::to_string(counts.quant[l]) + "/" + std::to_string(q) +
                    ", gate_up " + std::to_string(counts.gate_up[l]) + "/" + std::to_string(g) +
                    ", down " + std::to_string(counts.down[l]) + "/" + std::to_string(d) +
                    ", declined " + std::to_string(counts.declined[l]));
        }
        return observations;
    };

    if (capture_layer >= 0) {
        if (capture_prefix.empty()) throw std::runtime_error("--capture needs --capture-prefix");
        for (auto c : configs) {
            const uint64_t mask = c.layers == 64 ? ~uint64_t(0) : ((uint64_t(1) << c.layers) - 1);
            reset_carrier_counts();
            engine.reset();
            set_carrier_policy(policy_for(c, mask, c.carrier ? mask : 0, capture_layer));
            std::vector<Engine::Seq *> sequences{&engine.seq0};
            std::vector<std::vector<int>> input{std::vector<int>(tokenized[0].begin(), tokenized[0].begin() + 8)};
            std::vector<int> argmax;
            engine.forward(sequences, input, true, &argmax);
            Capture cap; read_capture(cap);
            const std::string path = capture_prefix + "-layer" + std::to_string(capture_layer) +
                                     "-carrier" + std::to_string(c.carrier) + ".bin";
            std::ofstream f(path, std::ios::binary);
            if (!f) throw std::runtime_error("cannot write " + path);
            const int dims[6] = {8, halo::D, halo::FF, c.carrier, g_scale_rne, capture_layer};
            f.write((const char *) dims, sizeof dims);
            auto put = [&](const auto &v) { f.write((const char *) v.data(), std::streamsize(v.size() * sizeof(v[0]))); };
            put(cap.x_in); put(cap.xq_in); put(cap.xs_in); put(cap.gate_up);
            put(cap.xq_hidden); put(cap.xs_hidden); put(cap.x_out);
            std::fprintf(stderr, "captured %s\n", path.c_str());
        }
        return 0;
    }

    CarrierCounts counts{};
    const auto original = evaluate({8, 0, 0}, counts);

    std::vector<std::vector<Observation>> results;
    std::vector<CarrierCounts> all_counts;
    for (auto c : configs) { CarrierCounts k{}; results.push_back(evaluate(c, k)); all_counts.push_back(k); }

    std::ofstream file(out);
    if (!file) throw std::runtime_error("cannot open output");
    file << std::setprecision(17)
         << "{\n\"format\":\"kelana-half-carrier-model-quality/1\",\n\"tokens_per_prompt\":" << tokens
         << ",\n\"prompts\":2,\n\"scored_positions\":" << original.size()
         << ",\n\"activation_scale_rounding\":\"" << (g_scale_rne ? "round_to_nearest" : "truncate_toward_zero")
         << "\",\n\"dyadic_row_gauge_shift\":" << g_scale_shift
         << ",\n\"quantiser\":\"direct symmetric, amax/(2^(bits-1)-1), nearest, clamped, at the gate/up input and the hidden activation\""
         << ",\n\"carrier\":\"per-128-block integer dot converted exactly to binary16, scale product and accumulation in binary16, dyadic row gauge restored in binary16 at the consumer\""
         << ",\n\"consumer_boundary\":\"gate/up writes binary16 times the row gain as FP32; the deployed SiLU, product, Hadamard-sign and hidden quantiser phase is unchanged; the down projection adds its restored FP32 value onto the residual\""
         << ",\n\"scope\":\"Native full-model teacher-forced logits, all 64 layers available, attention and recurrent state unchanged. No throughput claim: this schedule gives up the deployed K split and is slower by construction.\""
         << ",\n\"token_ids\":[";
    for (size_t p = 0; p < tokenized.size(); ++p) {
        if (p) file << ',';
        file << '[';
        for (size_t j = 0; j < tokenized[p].size(); ++j) { if (j) file << ','; file << tokenized[p][j]; }
        file << ']';
    }
    file << "],\n\"configurations\":[\n";

    for (size_t i = 0; i < configs.size(); ++i) {
        const Config c = configs[i];
        // The matched control shares the quantiser and differs only in the carrier.
        int matched = -1, schedule = -1;
        for (size_t j = 0; j < configs.size(); ++j) {
            if (configs[j].bits == c.bits && configs[j].layers == c.layers && configs[j].carrier == 0) matched = int(j);
            const int want = c.carrier == 1 ? 5 : 3;
            if (configs[j].bits == c.bits && configs[j].layers == c.layers && configs[j].carrier == want) schedule = int(j);
        }
        const Summary vs_orig = summarize(original, results[i]);
        if (i) file << ",\n";
        file << "{\"bits\":" << c.bits << ",\"first_layers\":" << c.layers << ",\"carrier\":" << c.carrier
             << ",\"carrier_projections\":\"" << (c.carrier == 0 ? "none" : c.carrier == 1 ? "gate_up" : c.carrier == 2 ? "gate_up+down" : c.carrier == 3 ? "gate_up+down, FP32" : c.carrier == 4 ? "gate_up+down, FP32 reverse order" : "gate_up, FP32") << "\""
             << ",\"vs_original\":{\"mean_kl\":" << vs_orig.kl << ",\"max_kl\":" << vs_orig.max_kl
             << ",\"mean_total_variation\":" << vs_orig.tv << ",\"mean_target_nll_delta\":" << vs_orig.nll
             << ",\"top1_changed\":" << vs_orig.changed << "}";
        std::fprintf(stderr, "A%d first%-3d carrier%d  vs original KL %.6g TV %.6g top1 %d/%zu",
                     c.bits, c.layers, c.carrier, vs_orig.kl, vs_orig.tv, vs_orig.changed, original.size());
        if (matched >= 0 && matched != int(i)) {
            const Summary vs_ctl = summarize(results[matched], results[i]);
            file << ",\"matched_control\":\"bits " << c.bits << ", first_layers " << c.layers << ", carrier 0\""
                 << ",\"vs_matched_control\":{\"mean_kl\":" << vs_ctl.kl << ",\"max_kl\":" << vs_ctl.max_kl
                 << ",\"mean_total_variation\":" << vs_ctl.tv << ",\"mean_target_nll_delta\":" << vs_ctl.nll
                 << ",\"top1_changed\":" << vs_ctl.changed << "}";
            std::fprintf(stderr, "  |  vs A4 control KL %.6g TV %.6g top1 %d", vs_ctl.kl, vs_ctl.tv, vs_ctl.changed);
        }
        // The schedule control removes the confound: it runs this phase's unit decomposition,
        // sequential block order and dyadic gauge with an FP32 running sum, so the difference
        // against it is the carrier representation and nothing else.
        if (schedule >= 0 && schedule != int(i) && (c.carrier == 1 || c.carrier == 2 || c.carrier == 4)) {
            const Summary vs_sch = summarize(results[schedule], results[i]);
            file << ",\"schedule_control\":\"bits " << c.bits << ", first_layers " << c.layers << ", carrier " << (c.carrier == 1 ? 5 : 3) << "\""
                 << ",\"vs_schedule_control\":{\"mean_kl\":" << vs_sch.kl << ",\"max_kl\":" << vs_sch.max_kl
                 << ",\"mean_total_variation\":" << vs_sch.tv << ",\"mean_target_nll_delta\":" << vs_sch.nll
                 << ",\"top1_changed\":" << vs_sch.changed << "}";
            std::fprintf(stderr, "  |  vs schedule control KL %.6g TV %.6g top1 %d", vs_sch.kl, vs_sch.tv, vs_sch.changed);
        }
        std::fprintf(stderr, "\n");
        file << ",\"intervention_counts\":{\"requantised_chunks\":" << counts_json(all_counts[i].quant)
             << ",\"gate_up_tile_groups\":" << counts_json(all_counts[i].gate_up)
             << ",\"down_tile_groups\":" << counts_json(all_counts[i].down)
             << ",\"declined\":" << counts_json(all_counts[i].declined) << "}}";
        file.flush();
    }
    file << "\n]}\n";
    return 0;
} catch (const std::exception &e) {
    std::fprintf(stderr, "carrier-quality: %s\n", e.what());
    return 1;
}
