#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cstdint>
#include <cmath>
#include "../kivi-resident-cache/step_bits.hpp"

namespace stable {
constexpr int KC=18944, QC=148, RC=33, VQ=224*48, VR=33*256;
struct Cache {
  unsigned char key[8][KC];
  unsigned char quant[QC][384], recent[RC][2048];
  unsigned char qref[224], rref[RC], qcount[QC], rcount[RC];
  int t, phase, nq, nr, error;
};
struct Control { unsigned char key[8][KC], quant[8][VQ], recent[8][VR]; int error; };
struct Scratch { unsigned char value[384]; };
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
// Shared quantizer for both arms; per-channel K32 and per-group V33 placement.
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
__global__ void append_key(Cache* s,Control* c,const unsigned char* arrival,int t,int mode) {
  int h=blockIdx.x,lane=threadIdx.x;
  if(h>=8||lane>=128)return;
  int n=(t-1)/32,kr=(t-1)%32;
  unsigned char* dest=mode?s->key[h]:c->key[h];
  if(n*1536+(kr+1)*256>KC){if(lane==0){if(mode)s->error=1;else c->error=1;}return;}
  for(int i=lane;i<256;i+=128)dest[n*1536+kr*256+i]=arrival[h*256+i];
}
__global__ void append_recent(Cache* s,Control* c,const unsigned char* arrival,int t,int mode) {
  int lane=threadIdx.x;
  if(!mode) {
    if(blockIdx.x>=8||lane>=128)return;
    unsigned char* dest=c->recent[blockIdx.x]+((t-1)%33)*256;
    const unsigned char* src=arrival+2048+blockIdx.x*256;
    for(int i=lane;i<256;i+=128)dest[i]=src[i];
    return;
  }
  if(blockIdx.x||lane>=128)return;
  __shared__ unsigned char match[RC];__shared__ int selected, fresh;
  if(lane<RC) {
    bool same=s->rcount[lane]!=0;
    for(int i=0;i<2048&&same;i++)same=s->recent[lane][i]==arrival[2048+i];
    match[lane]=same;
  }
  __syncthreads();
  if(lane==0) {
    int first=-1,free=-1;
    for(int i=0;i<RC;i++){if(match[i]&&first<0)first=i;if(!s->rcount[i]&&free<0)free=i;}
    selected=first>=0?first:free;fresh=first<0;
    if(selected<0 || s->t!=t-1 || s->phase!=1){s->error=2;selected=-1;}
    else {
      s->rref[(t-1)%33]=selected;s->rcount[selected]++;
      s->t=t;s->phase=0;s->nr=t<33?t:33;
    }
  }
  __syncthreads();
  if(selected>=0&&fresh)for(int i=lane;i<2048;i+=128)s->recent[selected][i]=arrival[2048+i];
}
__global__ void flush_key(Cache* s,Control* c,int t,int mode) {
  int h=blockIdx.x,lane=threadIdx.x;if(h>=8||lane>=128)return;
  __shared__ unsigned char digits[4096],fields[512];
  unsigned char* key=mode?s->key[h]:c->key[h];
  int n=t/32-1;const unsigned char* src=key+n*1536;
  unsigned char local[32];unsigned char field[4];
  quant32(src+lane*2,128,local,field);
  for(int i=0;i<32;i++)digits[i*128+lane]=local[i];
  for(int i=0;i<4;i++)fields[4*lane+i]=field[i];
  __syncthreads();
  for(int i=lane;i<1024;i+=128)
    key[n*1536+i]=digits[4*i]|(digits[4*i+1]<<2)|(digits[4*i+2]<<4)|(digits[4*i+3]<<6);
  for(int i=lane;i<512;i+=128)key[n*1536+1024+i]=fields[i];
}
__global__ void flush_value(Cache* s,Control* c,Scratch* work,int t,int mode) {
  int h=blockIdx.x,lane=threadIdx.x;if(h>=8||lane>=128)return;
  __shared__ unsigned char digits[128],fields[16];
  const unsigned char* src=mode?s->recent[s->rref[(t-33)%33]]+h*256:c->recent[h]+((t-33)%33)*256;
  if((lane&31)==0) {
    unsigned char local[32],field[4];int group=lane/32;
    quant32(src+group*64,1,local,field);
    for(int i=0;i<32;i++)digits[group*32+i]=local[i];
    for(int i=0;i<4;i++)fields[group*4+i]=field[i];
  }
  __syncthreads();
  unsigned char* out=mode?work->value+h*48:c->quant[h]+(t-33)*48;
  if(lane<32)out[lane]=digits[lane*4]|(digits[lane*4+1]<<2)|(digits[lane*4+2]<<4)|(digits[lane*4+3]<<6);
  if(lane<16)out[32+lane]=fields[lane];
}
__global__ void finish_value(Cache* s,Scratch* work,int t) {
  int lane=threadIdx.x;if(blockIdx.x||lane>=128)return;
  __shared__ unsigned char match[QC];__shared__ int selected,fresh;
  for(int slot=lane;slot<QC;slot+=128){
    bool same=s->qcount[slot]!=0;
    for(int i=0;i<384&&same;i++)same=s->quant[slot][i]==work->value[i];
    match[slot]=same;
  }
  __syncthreads();
  if(lane==0) {
    int first=-1,free=-1;
    for(int i=0;i<QC;i++){if(match[i]&&first<0)first=i;if(!s->qcount[i]&&free<0)free=i;}
    selected=first>=0?first:free;fresh=first<0;
    if(selected<0||s->phase!=0||s->nq!=t-33){s->error=3;selected=-1;}
    else {
      int oldest=s->rref[(t-33)%33];
      if(!s->rcount[oldest]){s->error=4;selected=-1;}
      else {
        s->qref[s->nq++]=selected;s->qcount[selected]++;
        s->rcount[oldest]--;s->nr=32;s->phase=1;
      }
    }
  }
  __syncthreads();
  if(selected>=0&&fresh)for(int i=lane;i<384;i+=128)s->quant[selected][i]=work->value[i];
}
__global__ void finish_early(Cache* s,int t) {if(blockIdx.x==0&&threadIdx.x==0&&s->t==t&&s->phase==0)s->phase=1;}
}
