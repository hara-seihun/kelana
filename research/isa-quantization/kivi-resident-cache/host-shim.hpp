#pragma once
// Host execution of the same serial transition functions, with IEEE scalar
// operations corresponding to the device intrinsics. This is not GPU parity.
#include <cmath>
#include <cstring>
#define __host__
#define __device__
#define __global__
struct HostIndex { unsigned x=0; };
static constexpr HostIndex blockIdx{},threadIdx{};
inline float __uint_as_float(unsigned u) { float v;std::memcpy(&v,&u,4);return v; }
inline long long __double_as_longlong(double v) { long long u;std::memcpy(&u,&v,8);return u; }
inline _Float16 __float2half_rn(float v) { return static_cast<_Float16>(v); }
inline unsigned short __half_as_ushort(_Float16 h) { unsigned short u;std::memcpy(&u,&h,2);return u; }
