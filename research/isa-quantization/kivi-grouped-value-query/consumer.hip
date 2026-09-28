// Compile-only gfx1151 full16Q/8KV dictionary-image reader; no GPU launch.
// Mode0: direct positional V dictionary dereference.
// Mode1: per-Q-head typed-record probability-mass reduction then V mixing.
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cmath>

__device__ __forceinline__ float bf16(const unsigned short *p) {
  return __uint_as_float(((unsigned)*p)<<16);
}
__device__ __forceinline__ unsigned code2(const unsigned char *p,int i) {
  return (p[i>>2]>>(2*(i&3)))&3;
}
// A CTA handles two Q heads for one KV head, then all 1024 O coordinates.
// Input is the actual five-byte-header serialized image, not expanded KV.
template<int mode> __global__ void query_group(const unsigned char *image,
                  const float *q,const unsigned short *o,float *partial) {
  int lane=threadIdx.x,group=blockIdx.x;
  int t=int(image[0])+(int(image[1])<<8),phase=image[2];
  int nq=image[3],nr=image[4],nchunk=(t-1)/32,nk=nchunk*32,nkr=t-nk;
  int nv=t>33?t-33:0,nvr=t-nv;
  if(group>=8 || t<1 || t>256 || phase!=0 || nq>nv || nr>nvr) return;
  const unsigned char *state=image+5+group*(nchunk*1536+nkr*256);
  const unsigned short *recent_k=(const unsigned short *)(state+nchunk*1536);
  const unsigned char *qd=image+5+8*(nchunk*1536+nkr*256);
  const unsigned char *qi=qd+nq*384;
  const unsigned char *rd=qi+nv;
  const unsigned char *ri=rd+nr*2048;
  __shared__ float score[2][256],prob[2][256],mixed[2][128],reduce[128];
  __shared__ float qm[2][224],rm[2][33];
  for(int h=0;h<2;h++) {
    for(int e=0;e<2;e++) {
      int token=lane+128*e;
      if(token<t) {
        float sum=0.f;
        if(token<nk) {
          int c=token/32,inside=token%32;
          const unsigned char *part=state+c*1536;
          for(int d=0;d<128;d++) {
            unsigned digit=code2(part,inside*128+d);
            const unsigned short *field=(const unsigned short *)(part+1024+4*d);
            float origin=__half2float(*((const __half *)field));
            float step=__half2float(*((const __half *)(field+1)));
            float decoded=fmaf(step,float(digit),origin);
            sum=fmaf(q[(group*2+h)*128+d],decoded,sum);
          }
        } else {
          for(int d=0;d<128;d++)sum=fmaf(q[(group*2+h)*128+d],bf16(recent_k+(token-nk)*128+d),sum);
        }
        score[h][token]=sum*0.08838834764831844f;
      }
    }
    __syncthreads();
    float top=-INFINITY;
    if(lane<t)top=fmaxf(top,score[h][lane]);
    if(lane+128<t)top=fmaxf(top,score[h][lane+128]);
    reduce[lane]=top;__syncthreads();
    for(int stride=64;stride;stride>>=1) {
      if(lane<stride)reduce[lane]=fmaxf(reduce[lane],reduce[lane+stride]);
      __syncthreads();
    }
    top=reduce[0];float total=0.f;
    for(int e=0;e<2;e++) {
      int token=lane+128*e;
      if(token<t) {
        float p=expf(score[h][token]-top);
        prob[h][token]=p;total+=p;
      }
    }
    reduce[lane]=total;__syncthreads();
    for(int stride=64;stride;stride>>=1) {
      if(lane<stride)reduce[lane]+=reduce[lane+stride];
      __syncthreads();
    }
    float denominator=reduce[0];
    for(int e=0;e<2;e++) {
      int token=lane+128*e;
      if(token<t)prob[h][token]/=denominator;
    }
    __syncthreads();
  }
  for(int h=0;h<2;h++) {
    if constexpr(mode==1) {
      for(int record=lane;record<nq;record+=128) qm[h][record]=0.f;
      if(lane<nr)rm[h][lane]=0.f;
      __syncthreads();
      // One lane accumulates each Q head's masses deterministically in token order;
      // this pays a serial reduction and is not an assumed free histogram.
      if(lane==0) {
        for(int token=0;token<nv;token++)qm[h][qi[token]]+=prob[h][token];
        for(int token=0;token<nvr;token++)rm[h][ri[token]]+=prob[h][nv+token];
      }
      __syncthreads();
    }
    int coord=lane,vg=coord/32;float value=0.f;
    for(int token=0;token<(mode==1?nq:nv);token++) {
      int record=mode==1?token:int(qi[token]);
      const unsigned char *part=qd+record*384+group*48;
      unsigned digit=code2(part,coord);
      const unsigned short *field=(const unsigned short *)(part+32+4*vg);
      float origin=__half2float(*((const __half *)field));
      float step=__half2float(*((const __half *)(field+1)));
      float weight=mode==1?qm[h][token]:prob[h][token];
      value=fmaf(weight,fmaf(step,float(digit),origin),value);
    }
    for(int token=0;token<(mode==1?nr:nvr);token++) {
      int record=mode==1?token:int(ri[token]);
      float weight=mode==1?rm[h][token]:prob[h][nv+token];
      value=fmaf(weight,bf16((const unsigned short *)(rd+record*2048+group*256)+coord),value);
    }
    mixed[h][coord]=value;
    __syncthreads();
  }
  __syncthreads();
  for(int repeat=0;repeat<8;repeat++) {
    int out=lane+128*repeat;float y=0.f;
    for(int h=0;h<2;h++)for(int d=0;d<128;d++)
      y=fmaf(bf16(o+out*2048+(group*2+h)*128+d),mixed[h][d],y);
    partial[group*1024+out]=y;
  }
}
__global__ void finish_o(const float *partial,float *output) {
  int out=blockIdx.x*blockDim.x+threadIdx.x;
  if(out<1024) {
    float sum=0.f;
    for(int group=0;group<8;group++)sum+=partial[group*1024+out];
    output[out]=sum;
  }
}
extern "C" void launch_direct(const unsigned char *image,const float *q,
                 const unsigned short *o,float *scratch,float *y) {
  hipLaunchKernelGGL((query_group<0>),dim3(8),dim3(128),0,0,image,q,o,scratch);
  hipLaunchKernelGGL((finish_o),dim3(8),dim3(128),0,0,scratch,y);
}
extern "C" void launch_grouped(const unsigned char *image,const float *q,
                 const unsigned short *o,float *scratch,float *y) {
  hipLaunchKernelGGL((query_group<1>),dim3(8),dim3(128),0,0,image,q,o,scratch);
  hipLaunchKernelGGL((finish_o),dim3(8),dim3(128),0,0,scratch,y);
}
