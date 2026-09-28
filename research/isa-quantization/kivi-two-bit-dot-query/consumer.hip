// Compile-only gfx1151 full 16Q/8KV single-query KIVI2 reader. No launch/timing.
// Mode0: conventional packed on-the-fly FP32 dequant-dot.
// Mode1: one frozen int8 folded-query/unsigned2 existing-key-code dot map.
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cmath>

__device__ __forceinline__ float bf16(const unsigned short *p) {
  return __uint_as_float(((unsigned)*p)<<16);
}
__device__ __forceinline__ unsigned code2(const unsigned char *p,int i) {
  return (p[i>>2]>>(2*(i&3)))&3;
}
__device__ __forceinline__ unsigned expand2(unsigned c) {
  unsigned u=(c|(c<<12))&0x000F000Fu;
  return (u|(u<<6))&0x03030303u;
}
// One CTA per KV head: its two Q heads, complete causal K scores/softmax/V,
// and full O partial 1024-vector. A second kernel sums eight KV contributions.
// All states are immutable existing paid pre-query-flush images. Current Q is
// already source-normalized+rotated; source K/V insertion and flush are common.
template<int mode> __global__ void query_group(const unsigned char *const *states,
                  const float *q,const unsigned short *o,float *partial,
                  int nchunk,int nv,int nkr,int nvr) {
  int lane=threadIdx.x,group=blockIdx.x,nk=nchunk*32,t=nk+nkr;
  if(group>=8 || t!=nv+nvr || t>256 || nchunk>8 || nkr>32 || nvr>33) return;
  const unsigned char *state=states[group];
  const unsigned char *vbytes=state+nchunk*1536;
  const unsigned short *recent_k=(const unsigned short *)(vbytes+nv*48);
  const unsigned short *recent_v=recent_k+nkr*128;
  __shared__ float score[2][256],prob[2][256],mixed[2][128],reduce[128];
  __shared__ float factors[128], scales[8][2][4], bias[8][2];
  __shared__ signed char query_bytes[8][2][128];
  if constexpr(mode==1) {
    for(int c=0;c<nchunk;c++) for(int h=0;h<2;h++) {
      int d=lane;
      const unsigned short *field=(const unsigned short *)(state+c*1536+1024+4*d);
      float qq=q[(group*2+h)*128+d];
      float step=__half2float(*((const __half *)(field+1)));
      factors[d]=qq*step;
      reduce[d]=qq*__half2float(*((const __half *)field));
      __syncthreads();
      if(lane<4) {
        float maximum=0.f;
        for(int j=0;j<32;j++)maximum=fmaxf(maximum,fabsf(factors[32*lane+j]));
        scales[c][h][lane]=maximum>0.f?maximum/127.f:1.f;
      }
      if(lane==0) {
        float sum=0.f;
        for(int j=0;j<128;j++)sum+=reduce[j];
        bias[c][h]=sum;
      }
      __syncthreads();
      float ratio=factors[d]/scales[c][h][d/32];
      int z=__float2int_rn(ratio);
      query_bytes[c][h][d]=(signed char)(z<-127?-127:(z>127?127:z));
      __syncthreads();
    }
  }
  for(int h=0;h<2;h++) {
    for(int e=0;e<2;e++) {
      int token=lane+128*e;
      if(token<t) {
        float sum=0.f;
        if(token<nk) {
          int c=token/32,inside=token%32;
          const unsigned char *part=state+c*1536;
          if constexpr(mode==1) {
            sum=bias[c][h];
            for(int g=0;g<4;g++) {
              int dot=0;
              for(int j=0;j<8;j++) {
                unsigned byte=part[inside*32+g*8+j];
                unsigned word=expand2(byte);
                int qword=*((const int *)(query_bytes[c][h]+g*32+4*j));
                dot=__builtin_amdgcn_sudot4(true,qword,false,int(word),dot,false);
              }
              sum=fmaf(scales[c][h][g],float(dot),sum);
            }
          } else {
            for(int d=0;d<128;d++) {
              unsigned digit=code2(part,inside*128+d);
              const unsigned short *field=(const unsigned short *)(part+1024+4*d);
              float origin=__half2float(*((const __half *)field));
              float step=__half2float(*((const __half *)(field+1)));
              float decoded=fmaf(step,float(digit),origin);
              sum=fmaf(q[(group*2+h)*128+d],decoded,sum);
            }
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
      const unsigned char *part=vbytes+token*48;
      unsigned digit=code2(part,coord);
      const unsigned short *field=(const unsigned short *)(part+32+4*vg);
      float origin=__half2float(*((const __half *)field));
      float step=__half2float(*((const __half *)(field+1)));
      value=fmaf(prob[h][token],fmaf(step,float(digit),origin),value);
    }
    for(int token=0;token<nvr;token++)
      value=fmaf(prob[h][nv+token],bf16(recent_v+token*128+coord),value);
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
extern "C" void launch_conventional(const unsigned char *const *s,const float *q,
                 const unsigned short *o,float *scratch,float *y,
                 int nchunk,int nv,int nkr,int nvr) {
  hipLaunchKernelGGL((query_group<0>),dim3(8),dim3(128),0,0,s,q,o,scratch,nchunk,nv,nkr,nvr);
  hipLaunchKernelGGL((finish_o),dim3(8),dim3(128),0,0,scratch,y);
}
extern "C" void launch_byte_dot(const unsigned char *const *s,const float *q,
                 const unsigned short *o,float *scratch,float *y,
                 int nchunk,int nv,int nkr,int nvr) {
  hipLaunchKernelGGL((query_group<1>),dim3(8),dim3(128),0,0,s,q,o,scratch,nchunk,nv,nkr,nvr);
  hipLaunchKernelGGL((finish_o),dim3(8),dim3(128),0,0,scratch,y);
}
