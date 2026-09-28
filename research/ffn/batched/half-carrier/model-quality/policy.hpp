#pragma once
#include <cstdint>
#include <hip/hip_runtime.h>
#include <vector>

// What the interposed kernel is allowed to change, per configuration.
//
//   bits < 8            replaces the FFN activation quantiser with the batched candidate's direct
//                       symmetric quantiser at amax/(2^(bits-1)-1), on layers in `layers`.
//   carrier_gu          runs the gate/up projection through the packed-half block carrier.
//   carrier_down        the same at the down projection.
//   scale_rne           rounds the per-block activation scale to nearest when converting it to
//                       binary16, rather than truncating toward zero.
//   scale_shift         dyadic row gauge target: 2^e * max_block_scale lands in
//                       [2^-(shift+1), 2^-shift).
struct CarrierPolicy {
    uint64_t layers;        // layers whose FFN activation quantiser changes
    uint64_t carrier;       // layers whose FFN projections use the half carrier
    int bits;
    int direct;
    int down;               // also requantise the hidden activation
    int carrier_gu;
    int carrier_down;
    int scale_rne;
    int scale_shift;
    int capture_layer;      // -1 off; otherwise the layer whose FFN operands are captured
    int carrier_fp32;       // 1 = FP32 running sum, same schedule and gauge; 2 = FP32 with the
                            // blocks summed in reverse, which is the same real number and a pure
                            // FP32 reassociation of the FP32 control
};

// Per-layer evidence that the intervention ran where it was asked to and nowhere else.
struct CarrierCounts {
    unsigned quant[64];     // 1024-element chunks requantised
    unsigned gate_up[64];   // gate/up tile groups through the half carrier
    unsigned down[64];      // down tile groups through the half carrier
    unsigned declined[64];  // FFN projections the carrier was asked for and did not take
};

void set_carrier_policy(CarrierPolicy);
void reset_carrier_counts();
void read_carrier_counts(CarrierCounts &);

// One 8-row forward pass worth of FFN operands at the captured layer, in the order the FFN uses
// them. Separating projection agreement from residual agreement needs the quantised activations,
// not only the endpoints.
struct Capture {
    std::vector<float> x_in, xs_in, gate_up, xs_hidden, x_out;
    std::vector<int8_t> xq_in, xq_hidden;
};
void read_capture(Capture &);
