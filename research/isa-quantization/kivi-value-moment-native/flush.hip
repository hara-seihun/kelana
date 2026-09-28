#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cstdint>
#include <cmath>
#include "../kivi-resident-cache/step_bits.hpp"

// Both arms write exactly the original 48-byte V record; the moment arm
// also accumulates source minus actual stored-record decode at V33.
__device__ __forceinline__ float source_bf(const unsigned char* p) {
  return __uint_as_float((unsigned(p[0])|(unsigned(p[1])<<8))<<16);
}
__global__ void flush_v(const unsigned char* recent,unsigned char* quant,
                        float* moment,int t,int corrected) {
  int h=blockIdx.x,lane=threadIdx.x;
  if(h>=8||lane>=128||t<33||t>256)return;
  if(lane&31)return;
  int group=lane>>5;
  const unsigned char* src=recent+h*33*256+((t-33)%33)*256+group*64;
  unsigned char* out=quant+h*224*48+(t-33)*48;
  float* s=corrected ? moment+h*128+group*32 : nullptr;
  float x[32];float lo=INFINITY,hi=-INFINITY;
  for(int i=0;i<32;i++){
    x[i]=source_bf(src+i*2);
    lo=fminf(lo,x[i]);hi=fmaxf(hi,x[i]);
  }
  double step=(double(hi)-double(lo))/3.0;
  float divisor=float(step);
  unsigned low=__half_as_ushort(__float2half_rn(lo));
  unsigned stepbits=resident::step_bits(static_cast<unsigned long long>(__double_as_longlong(step)));
  out[32+group*4]=low;out[33+group*4]=low>>8;
  out[34+group*4]=stepbits;out[35+group*4]=stepbits>>8;
  float decoded_lo=__half2float(__ushort_as_half(low));
  float decoded_step=__half2float(__ushort_as_half(stepbits));
  for(int j=0;j<8;j++){
    unsigned byte=0;
    for(int k=0;k<4;k++){
      int i=j*4+k;
      float v=x[i];
      float q=step==0.?0.f:nearbyintf((v-lo)/divisor);
      unsigned digit=unsigned(fminf(3.f,fmaxf(0.f,q)));
      byte|=digit<<(2*k);
      if(corrected){
        float product=decoded_step*float(digit);
        float reconstructed=decoded_lo+product;
        float error=v-reconstructed;
        s[i]=s[i]+error;
      }
    }
    out[group*8+j]=byte;
  }
}
