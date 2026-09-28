#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cstdint>
#include <cmath>
#include "../kivi-resident-cache/step_bits.hpp"
#include "threshold_core.hpp"

namespace alphabet {
constexpr int KC=18944, VQ=224*48, VR=33*256;
struct Cache { unsigned char key[8][KC], quant[8][VQ], recent[8][VR]; int error; };
static_assert(sizeof(Cache)==305156);
__device__ __forceinline__ float bf(const unsigned char* p) {
  return __uint_as_float((unsigned(p[0])|(unsigned(p[1])<<8))<<16);
}
__device__ __forceinline__ void half_float(unsigned char* p,float v) {
  unsigned b=__half_as_ushort(__float2half_rn(v));p[0]=b;p[1]=b>>8;
}
__device__ __forceinline__ void half_step(unsigned char* p,double v) {
  unsigned b=resident::step_bits(static_cast<unsigned long long>(__double_as_longlong(v)));
  p[0]=b;p[1]=b>>8;
}
__device__ void quant32(const unsigned char* source,int stride,unsigned char* digits,unsigned char* field) {
  float x[32];float lo=INFINITY,hi=-INFINITY;
  for(int i=0;i<32;i++){x[i]=bf(source+2*i*stride);lo=fminf(lo,x[i]);hi=fmaxf(hi,x[i]);}
  double step=(double(hi)-double(lo))/3.0;float divisor=float(step);
  for(int i=0;i<32;i++) {
    float q=step==0.?0.f:nearbyintf((x[i]-lo)/divisor);
    digits[i]=static_cast<unsigned char>(fminf(3.f,fmaxf(0.f,q)));
  }
  half_float(field,lo);half_step(field+2,step);
}
__global__ void append_key(Cache* c,const unsigned char* arrival,int t) {
  int h=blockIdx.x,lane=threadIdx.x;if(h>=8||lane>=128)return;
  int n=(t-1)/32,kr=(t-1)%32;
  if(n*1536+(kr+1)*256>KC){if(lane==0)c->error=1;return;}
  for(int i=lane;i<256;i+=128)c->key[h][n*1536+kr*256+i]=arrival[h*256+i];
}
__global__ void append_recent(Cache* c,const unsigned char* arrival,int t) {
  int h=blockIdx.x,lane=threadIdx.x;if(h>=8||lane>=128)return;
  for(int i=lane;i<256;i+=128)c->recent[h][((t-1)%33)*256+i]=arrival[2048+h*256+i];
}
__global__ void flush_key(Cache* c,int t) {
  int h=blockIdx.x,lane=threadIdx.x;if(h>=8||lane>=128)return;
  __shared__ unsigned char digits[4096],fields[512];
  unsigned char* key=c->key[h];int n=t/32-1;const unsigned char* src=key+n*1536;
  unsigned char local[32],field[4];quant32(src+lane*2,128,local,field);
  for(int i=0;i<32;i++)digits[i*128+lane]=local[i];
  for(int i=0;i<4;i++)fields[4*lane+i]=field[i];
  __syncthreads();
  for(int i=lane;i<1024;i+=128)
    key[n*1536+i]=digits[4*i]|(digits[4*i+1]<<2)|(digits[4*i+2]<<4)|(digits[4*i+3]<<6);
  for(int i=lane;i<512;i+=128)key[n*1536+1024+i]=fields[i];
}
// One group-owning lane computes the original BF16 extrema and FP16 fields.
// Control codes retain the original conventional encoder; candidate distances
// use the actual separately rounded four FP32 field/table decodes.
__global__ void flush_value(Cache* c,const float* table,int t,int mode) {
  int h=blockIdx.x,lane=threadIdx.x;if(h>=8||lane>=128||lane&31)return;
  int group=lane>>5;
  const unsigned char* src=c->recent[h]+((t-33)%33)*256+group*64;
  unsigned char* out=c->quant[h]+(t-33)*48;
  float x[32];float lo=INFINITY,hi=-INFINITY;
  for(int i=0;i<32;i++){x[i]=bf(src+2*i);lo=fminf(lo,x[i]);hi=fmaxf(hi,x[i]);}
  double step=(double(hi)-double(lo))/3.0;float divisor=float(step);
  unsigned lowbits=__half_as_ushort(__float2half_rn(lo));
  unsigned stepbits=resident::step_bits(static_cast<unsigned long long>(__double_as_longlong(step)));
  out[32+group*4]=lowbits;out[33+group*4]=lowbits>>8;
  out[34+group*4]=stepbits;out[35+group*4]=stepbits>>8;
  threshold::Plan plan{};
  if(mode) {
    float a=__half2float(__ushort_as_half(lowbits));
    float b=__half2float(__ushort_as_half(stepbits));
    plan=threshold::prepare(a,b,table);
  }
  for(int j=0;j<8;j++) {
    unsigned packed=0;
    for(int k=0;k<4;k++) {
      int i=j*4+k;unsigned digit=0;
      if(mode) digit=threshold::select(x[i],plan);
      else {
        float q=step==0.?0.f:nearbyintf((x[i]-lo)/divisor);
        digit=unsigned(fminf(3.f,fmaxf(0.f,q)));
      }
      packed|=digit<<(2*k);
    }
    out[group*8+j]=packed;
  }
}
}
