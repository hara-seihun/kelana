// Compile-only complete 1024->128 readers: old root-table vs newly fitted bitmask/root.
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>

__device__ void transform1024(float *x,int lane) {
  for(int width=1;width<1024;width<<=1) {
    float left[8],right[8];
    #pragma unroll
    for(int k=0;k<8;k++) {
      int slot=lane+128*k;
      left[k]=x[slot&~width];right[k]=x[(slot&~width)|width];
    }
    __syncthreads();
    #pragma unroll
    for(int k=0;k<8;k++)x[lane+128*k]=(lane+128*k&width)?left[k]-right[k]:left[k]+right[k];
    __syncthreads();
  }
  #pragma unroll
  for(int k=0;k<8;k++)x[lane+128*k]*=0.03125f;
  __syncthreads();
}
__device__ void transform128(float *y,int lane) {
  for(int width=1;width<128;width<<=1) {
    float left=y[lane&~width],right=y[(lane&~width)|width];
    __syncthreads();y[lane]=(lane&width)?left-right:left+right;__syncthreads();
  }
  y[lane]*=0.08838834764831844f;
  __syncthreads();
}

template<int mode> __global__ void quip(const float *input,float *output,const unsigned char *image) {
  int row=threadIdx.x,batch=blockIdx.x;
  __shared__ float x[1024],y[128];
  const unsigned short *code=(const unsigned short *)image;
  const unsigned *abs_grid=(const unsigned *)(image+49298);
  unsigned char vs=image[49280+row/8];
  #pragma unroll
  for(int t=0;t<8;t++) {
    int col=row+128*t;
    x[col]=input[batch*1024+col]*((image[49152+col/8]>>(col%8)&1)?-1.f:1.f);
  }
  __syncthreads();transform1024(x,row);
  float all=0.f;
  for(int part=0;part<(mode==0?1:4);part++) {
    float base=0.f,resid=0.f;
    for(int g=0;g<(mode==0?128:32);g++) {
      int group=part*(mode==0?128:32)+g;
      unsigned c=code[row*128+group],sign=c&255,parity=__popc(sign)&1;
      sign^=parity;
      unsigned r=image[32768+row*128+group];
      unsigned packed=0;
      if constexpr(mode==0)packed=abs_grid[c>>8];
      #pragma unroll
      for(int k=0;k<8;k++) {
        int j=(k/2)+4*(k%2);
        float a;
        if constexpr(mode==0)a=((int)((packed>>(4*j))&15)-8)*.5f;
        else a=((c>>(8+j))&1)?1.5f:.5f;
        if((sign>>j)&1)a=-a;
        a+=(parity?-.25f:.25f);
        base=fmaf(a,x[group*8+k],base);
      }
      if(r<128) {
        if(r!=127) {
          int i=r&7,j=(r>>3)&7;
          float a=x[group*8+i],b=x[group*8+j];
          resid+=((r>>6)&1)?-(a+(i<=j?b:-b)):(a+(i<=j?b:-b));
        }
      } else {
        unsigned s=r&127;float dot=0.f;
        #pragma unroll
        for(int k=0;k<7;k++)dot+=((s>>k)&1)?-x[group*8+k]:x[group*8+k];
        dot+=(__popc(s)&1)?-x[group*8+7]:x[group*8+7];
        resid+=dot*.5f;
      }
    }
    if constexpr(mode==0)all=base+resid/2.04f;
    else {
      float gain=__half2float(*((const __half*)(image+49298+2*(row*4+part))));
      all=fmaf(gain,base+resid/2.04f,all);
    }
  }
  float scale=__half2float(*((const __half*)(image+49296)));
  y[row]=all*scale;
  __syncthreads();transform128(y,row);
  output[batch*128+row]=y[row]*((vs>>(row%8)&1)?-1.f:1.f);
}
extern "C" void launch_original(const float *x,float *y,const unsigned char *image,unsigned n) {
  hipLaunchKernelGGL((quip<0>),dim3(n),dim3(128),0,0,x,y,image);
}
extern "C" void launch_bitmask(const float *x,float *y,const unsigned char *image,unsigned n) {
  hipLaunchKernelGGL((quip<1>),dim3(n),dim3(128),0,0,x,y,image);
}
