#pragma once
#include <hip/hip_runtime.h>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace kelana_batch {
struct Weights {
    int width, hidden, layer;
    const uint8_t *gate_host, *up_host, *down_host;
    const uint8_t *gate_device, *up_device, *down_device;
    const float *norm_host, *signs_host;
    const float *norm_device, *signs_device;
    size_t gate_bytes, up_bytes, down_bytes;
};

enum class Claim { exact_reference, approximate };

// Preparation receives no activations. It may transform the weights and allocate
// scratch. Every input-dependent operation belongs inside run, including packing.
// Input and output are separate row-major FP32 [rows][width] matrices.
struct Candidate {
    const char *name;
    Claim claim;
    const char *description;
    void *(*prepare)(const Weights &, int maximum_batch);
    void (*run)(void *, int rows, const float *input, float *output, hipStream_t);
    void (*release)(void *);
    size_t (*resident_bytes)(void *);
};
std::vector<Candidate> &registry();
#define KELANA_BATCH_REGISTER(factory) namespace { const bool register_##factory = \
    (::kelana_batch::registry().push_back(factory()),true); }
}
