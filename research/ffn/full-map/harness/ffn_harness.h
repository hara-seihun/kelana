// Callable interface for a complete residual-to-residual Bonsai FFN on one layer.
//
// A candidate owns nothing but its own static preparation: the harness allocates every activation
// buffer, restores the input residual before each timed interval, and reads the result back. The
// timed interval is exactly one `run` call, so everything recurring (prep, quantisation, weight
// traffic, nonlinearity, residual write) is inside it and every static weight transformation
// belongs in `prepare`.
#pragma once
#include <hip/hip_runtime.h>
#include <cstdint>
#include <string>
#include <vector>

namespace kffn {

struct Shape {
    int D = 5120;
    int FF = 17408;
    int rmax = 8;      // row stride of the activation buffers
    int layer = 0;
};

// The layer's deployed weights. Device pointers hold exactly what the engine uploads; the `_host`
// members are the same bytes on the host, so a candidate's untimed prepare can repack them into any
// layout it wants. HALO tile bytes decode with halo::decode_block (bonsai-halo src/halo_format.h).
struct Weights {
    const uint8_t * gate = nullptr;   // HALO tiles [FF][D]
    const uint8_t * up = nullptr;     // HALO tiles [FF][D]
    const uint8_t * down = nullptr;   // HALO tiles [D][FF]
    const float * post_norm_s = nullptr; // post_attention_norm.weight * sign vector, [D]
    const float * signs_ff = nullptr;    // Hadamard sign vector, [FF]
    const float * post_norm = nullptr;   // raw norm weight, [D]
    const float * signs_d = nullptr;     // Hadamard sign vector, [D]
    const uint8_t * gate_host = nullptr, * up_host = nullptr, * down_host = nullptr;
    const float * post_norm_s_host = nullptr, * signs_ff_host = nullptr;
};

// Harness-owned scratch. x carries the residual in and out (the deployed down projection
// accumulates into it). bar/work/prof point at this iteration's private slice, pre-zeroed, so a
// candidate never pays a reset inside the timed interval.
struct Work {
    float * x = nullptr;        // [rmax][D]
    int8_t * xq = nullptr;      // [rmax][FF]
    float * xs = nullptr;       // [rmax][FF/128]
    int * xsum = nullptr;       // [rmax][FF/128]
    float * gu = nullptr;       // [2][rmax][FF]
    void * scratch = nullptr;   // [scratch_bytes], candidate's own use
    size_t scratch_bytes = 0;
    unsigned * bar = nullptr;   // >= 16 uints, zeroed
    unsigned * work = nullptr;  // >= 64 uints, zeroed
    unsigned long long * prof = nullptr; // >= prof_slots stamps, or null
    int prof_slots = 0;
    int grid = 0;               // cooperative grid the harness resolved for this candidate
};

struct Candidate {
    const char * name;
    // Set when the candidate leaves the deployed intermediates in Work, so the harness checks them
    // against the engine's capture: the gate and up projections in gu, and the quantised hidden
    // activations in xq/xs/xsum. A fused candidate that never materialises them leaves these false.
    bool emits_gate_up;
    bool emits_ff_quant;
    // Stage labels matching the profile stamps the kernel writes (prof[i+1] - prof[i]).
    const char * const * stages;
    int nstages;
    // Cooperative grid size for this row count, or 0 to let the harness use its default.
    int (*grid)(int nrows);
    // Matvec instruction the candidate selects at this row count, for the report.
    const char * (*instruction)(int nrows);
    void * (*prepare)(const Shape &, const Weights &);
    void (*run)(void * state, const Shape &, const Weights &, const Work &, int nrows, hipStream_t);
    void (*release)(void * state);
    size_t (*weight_bytes)(const Shape &, int nrows); // null means the deployed HALO layout
};

std::vector<Candidate> & registry();
#define KFFN_REGISTER(c) namespace { const bool kffn_reg_##c = (::kffn::registry().push_back(c()), true); }

// ---------------------------------------------------------------------------------------------
// Dataset produced by build_dataset (real PTQ1_0 weights and real activations of one layer).

struct Case {
    int nrows = 0;
    std::vector<int> tokens;
    std::string input_kind;      // "native-prefill" or an explicit synthetic label
    std::vector<float> x_in;     // [nrows][D]
    std::vector<float> x_ref;    // [nrows][D] after the layer's FFN
    std::vector<float> gate_ref; // [nrows][FF]
    std::vector<float> up_ref;   // [nrows][FF]
    std::vector<int8_t> xq_ff;   // [nrows][FF] quantised SiLU(gate)*up*sign
    std::vector<float> xs_ff;    // [nrows][FF/128] block scales
    std::vector<int> xsum_ff;    // [nrows][FF/128] block sums
};

struct Dataset {
    std::string dir;
    std::string model, halo_cache, source_commit, built_at, prompt;
    Shape shape;
    Weights w;            // device
    std::vector<Case> cases;
    std::vector<float> post_norm_host, signs_ff_host, post_norm_s_host;
    std::vector<uint8_t> gate_host, up_host, down_host;
};

// Loads the manifest, uploads the weights, and returns the dataset. Throws std::runtime_error.
Dataset load_dataset(const std::string & dir);

} // namespace kffn
