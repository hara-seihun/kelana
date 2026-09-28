#pragma once
#include <cstdint>
#include <hip/hip_runtime.h>
struct QuantPolicy { uint64_t layers; unsigned seed, sample; int bits, stochastic, direct, down, consumer; };
void set_quant_policy(QuantPolicy);
void reset_quant_counts();
void read_quant_counts(unsigned (&counts)[64]);
void read_consumer_counts(unsigned (&counts)[64]);
