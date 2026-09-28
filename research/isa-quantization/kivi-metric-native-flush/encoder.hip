#include <hip/hip_runtime.h>
#include "encoder.h"

// One block handles one causal key-chunk flush. The source is already a
// completed BF16[32,128] slab; metric is immutable FP16[1152] per model group.
// One barrier makes the whole 4096-code/256-field LDS image visible to 32
// token owners. There is no cross-chunk dependency or offline key decoding.
template <bool Metric>
__global__ __launch_bounds__(128) void flush_key(const uint16_t* __restrict__ source,
                                                   const Half* __restrict__ metric,
                                                   uint8_t* __restrict__ output) {
  __shared__ uint8_t code[32*128];
  __shared__ Half field[128*2];
  int lane=threadIdx.x;
  initial_channel(source,lane,code,field);
  __syncthreads();
  if (lane<32) {
    if constexpr (Metric) metric_token(source,lane,code,field,metric);
    pack_token(code,lane,output);
  }
  pack_fields(field,lane,output);
}

// Explicit instantiations yield separately inspectable complete device bodies.
template __global__ void flush_key<false>(const uint16_t*,const Half*,uint8_t*);
template __global__ void flush_key<true>(const uint16_t*,const Half*,uint8_t*);
