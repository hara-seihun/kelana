// Complete 16Q/8KV chronological reader. Mode0 control, mode1 stable slots.
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cmath>
#include "state.hip"

__device__ __forceinline__ float bf16(const unsigned short *p) {
  return __uint_as_float(((unsigned)*p)<<16);
}
__device__ __forceinline__ unsigned code2(const unsigned char *p,int i) {
  return (p[i>>2]>>(2*(i&3)))&3;
}
// A CTA handles two Q heads for one KV head, then all 1024 O coordinates.
// Both arms dereference their paid resident state directly.
template<int mode> __global__ void query_group(const stable::Cache *s,const stable::Control *c,int t,
                  const float *q,const unsigned short *o,float *partial) {
  int lane=threadIdx.x,group=blockIdx.x;
  int nchunk=(t-1)/32,nk=nchunk*32,nkr=t-nk;
  int nv=t>33?t-33:0,nvr=t-nv;
  if(group>=8 || t<1 || t>256 || (mode==1 && (s->t!=t || s->phase!=0 || s->error))) return;
  const unsigned char *state=mode==1?s->key[group]:c->key[group];
  const unsigned short *recent_k=(const unsigned short *)(state+nchunk*1536);
  __shared__ float score[2][256],prob[2][256],mixed[2][128],reduce[128];
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
    int coord=lane,vg=coord/32;float value=0.f;
    for(int token=0;token<nv;token++) {
      const unsigned char *part=mode==1?s->quant[s->qref[token]]+group*48:c->quant[group]+token*48;
      unsigned digit=code2(part,coord);
      const unsigned short *field=(const unsigned short *)(part+32+4*vg);
      float origin=__half2float(*((const __half *)field));
      float step=__half2float(*((const __half *)(field+1)));
      value=fmaf(prob[h][token],fmaf(step,float(digit),origin),value);
    }
    for(int token=0;token<nvr;token++) {
      int ring=(t-nvr+token)%33;
      const unsigned char *rec=mode==1?s->recent[s->rref[ring]]+group*256:c->recent[group]+ring*256;
      value=fmaf(prob[h][nv+token],bf16((const unsigned short *)rec+coord),value);
    }
    mixed[h][coord]=value;
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
extern "C" void launch_stable(const stable::Cache* s,const stable::Control* c,int t,
  const float* q,const unsigned short* o,float* partial,float* y) {
  hipLaunchKernelGGL((query_group<1>),dim3(8),dim3(128),0,0,s,c,t,q,o,partial);
  hipLaunchKernelGGL((finish_o),dim3(8),dim3(128),0,0,partial,y);
}
extern "C" void launch_control(const stable::Cache* s,const stable::Control* c,int t,
  const float* q,const unsigned short* o,float* partial,float* y) {
  hipLaunchKernelGGL((query_group<0>),dim3(8),dim3(128),0,0,s,c,t,q,o,partial);
  hipLaunchKernelGGL((finish_o),dim3(8),dim3(128),0,0,partial,y);
}
