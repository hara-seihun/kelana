// gfx1151 compile-only whole two-head KIVI query: conventional packed reader vs
// scaled-query/weighted-value direct packed-label map. Never launched here.
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cmath>

__device__ __forceinline__ float bf16(const unsigned short *p) {
  return __uint_as_float(((unsigned)(*p))<<16);
}
__device__ __forceinline__ int nibble(const unsigned char *p,int index) {
  unsigned v=p[index>>1];return index&1?int(v>>4):int(v&15);
}

// One block, 128 lanes, two 128D query heads sharing K/V; O has 1024 BF16 rows
// of 256 columns (head0 columns0..127, head1 columns128..255).
// Inputs are the CURRENT preflush byte state, already normalized/rotated dynamic
// queries, unchanged original O, and causal lengths. Quantization at insertion/
// flush is separately paid by the owner; these kernels do not synthesize it.
template<int mode> __global__ void query(const unsigned char *state,const float *q,
                                          const unsigned short *o,float *output,
                                          int nk,int nv,int nkr,int nvr) {
  int lane=threadIdx.x,t=nk+nkr;
  if(t!=nv+nvr || t>256 || nk%32) return;
  int nchunk=nk/32;
  const unsigned char *vbytes=state+nchunk*2560;
  const unsigned short *recent_k=(const unsigned short *)(vbytes+nv*80);
  const unsigned short *recent_v=recent_k+nkr*128;
  __shared__ float score[2][256],prob[2][256],mixed[2][128],reduce[128];
  __shared__ float kfactor[8][2][128],kbias[8][2];
  __shared__ float vfactor[2][256][4],vbias[2][4];
  if constexpr(mode==1) {
    // Prepare both query-specific scale products once PER CHUNK. The origin
    // contribution depends on the chunk and cannot be removed as a global
    // softmax row shift.
    for(int c=0;c<nchunk;c++) {
      const unsigned short *field=(const unsigned short *)(state+c*2560+2048+4*lane);
      for(int h=0;h<2;h++) {
        float qq=q[h*128+lane];
        kfactor[c][h][lane]=qq*__half2float(*((const __half *)(field+1)));
        reduce[lane]=qq*__half2float(*((const __half *)field));
        __syncthreads();
        if(lane==0) {
          float sum=0.f;
          for(int d=0;d<128;d++)sum+=reduce[d];
          kbias[c][h]=sum;
        }
        __syncthreads();
      }
    }
  }
  for(int h=0;h<2;h++) {
    for(int e=0;e<2;e++) {
      int token=lane+128*e;
      if(token<t) {
        float s=0.f;
        if(token<nk) {
          int c=token/32,inside=token%32;
          const unsigned char *part=state+c*2560;
          if constexpr(mode==1)s=kbias[c][h];
          for(int d=0;d<128;d++) {
            int digit=nibble(part,inside*128+d);
            if constexpr(mode==1)s=fmaf(kfactor[c][h][d],float(digit),s);
            else {
              const unsigned short *field=(const unsigned short *)(part+2048+4*d);
              float origin=__half2float(*((const __half *)field));
              float step=__half2float(*((const __half *)(field+1)));
              s=fmaf(q[h*128+d],fmaf(step,float(digit),origin),s);
            }
          }
        } else {
          for(int d=0;d<128;d++)s=fmaf(q[h*128+d],bf16(recent_k+(token-nk)*128+d),s);
        }
        score[h][token]=s*0.08838834764831844f;
      }
    }
    __syncthreads();
    float m=-INFINITY;
    if(lane<t)m=fmaxf(m,score[h][lane]);
    if(lane+128<t)m=fmaxf(m,score[h][lane+128]);
    reduce[lane]=m;__syncthreads();
    for(int stride=64;stride;stride>>=1) {
      if(lane<stride)reduce[lane]=fmaxf(reduce[lane],reduce[lane+stride]);
      __syncthreads();
    }
    float top=reduce[0],sum=0.f;
    for(int e=0;e<2;e++) {
      int token=lane+128*e;
      if(token<t) {
        float p=expf(score[h][token]-top);
        prob[h][token]=p;sum+=p;
      }
    }
    reduce[lane]=sum;__syncthreads();
    for(int stride=64;stride;stride>>=1) {
      if(lane<stride)reduce[lane]+=reduce[lane+stride];
      __syncthreads();
    }
    float denom=reduce[0];
    for(int e=0;e<2;e++) {
      int token=lane+128*e;
      if(token<t)prob[h][token]/=denom;
    }
    __syncthreads();
  }
  if constexpr(mode==1) {
    // Eight producer lanes compute each head/group's origin sum and store
    // p*step for every old token. Paid serial prep avoids duplicating scale
    // multiplications across 32 value-coordinate consumers per group.
    if(lane<8) {
      int h=lane/4,g=lane%4;float bias=0.f;
      for(int token=0;token<nv;token++) {
        const unsigned short *field=(const unsigned short *)(vbytes+token*80+64+4*g);
        float p=prob[h][token];
        bias=fmaf(p,__half2float(*((const __half *)field)),bias);
        vfactor[h][token][g]=p*__half2float(*((const __half *)(field+1)));
      }
      vbias[h][g]=bias;
    }
    __syncthreads();
  }
  for(int h=0;h<2;h++) {
    int group=lane/32;
    float val=0.f;
    if constexpr(mode==1)val=vbias[h][group];
    for(int token=0;token<nv;token++) {
      const unsigned char *part=vbytes+token*80;
      int digit=nibble(part,lane);
      if constexpr(mode==1)val=fmaf(vfactor[h][token][group],float(digit),val);
      else {
        const unsigned short *field=(const unsigned short *)(part+64+4*group);
        float origin=__half2float(*((const __half *)field));
        float step=__half2float(*((const __half *)(field+1)));
        val=fmaf(prob[h][token],fmaf(step,float(digit),origin),val);
      }
    }
    for(int token=0;token<nvr;token++)
      val=fmaf(prob[h][nv+token],bf16(recent_v+token*128+lane),val);
    mixed[h][lane]=val;
  }
  __syncthreads();
  for(int i=0;i<8;i++) {
    int out=lane+128*i;
    float result=0.f;
    for(int h=0;h<2;h++)for(int d=0;d<128;d++)
      result=fmaf(bf16(o+out*256+h*128+d),mixed[h][d],result);
    output[out]=result;
  }
}
extern "C" void launch_conventional(const unsigned char *s,const float *q,
                                      const unsigned short *o,float *y,int nk,int nv,int nkr,int nvr) {
  hipLaunchKernelGGL((query<0>),dim3(1),dim3(128),0,0,s,q,o,y,nk,nv,nkr,nvr);
}
extern "C" void launch_direct(const unsigned char *s,const float *q,
                                const unsigned short *o,float *y,int nk,int nv,int nkr,int nvr) {
  hipLaunchKernelGGL((query<1>),dim3(1),dim3(128),0,0,s,q,o,y,nk,nv,nkr,nvr);
}
