// Compile-only comparison of whole 1024->128 QuIP Q readers. No GPU launch in this study.
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cstdint>
#include "labels.hpp"

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

// mode 0: frozen original 1024B magnitude table; mode 1: direct 29B description;
// mode 2: once-prepared 1024B table indexed in the NEW label space.
template<int mode> __global__ void quip(const float *input,float *output,const unsigned char *image,const unsigned *prepared) {
  int row=threadIdx.x,batch=blockIdx.x;
  __shared__ float x[1024],y[128];
  const unsigned short *code=(const unsigned short *)image;
  const unsigned *abs_grid=mode==2?prepared:(const unsigned *)(image+49298);
  unsigned char vs=image[49280+row/8];
  #pragma unroll
  for(int t=0;t<8;t++) {
    int col=row+128*t;
    x[col]=input[batch*1024+col]*((image[49152+col/8]>>(col%8)&1)?-1.f:1.f);
  }
  __syncthreads();transform1024(x,row);
  float base=0.f,resid=0.f;
  for(int group=0;group<128;group++) {
    unsigned c=code[row*128+group],sign=c&255,parity=__popc(sign)&1;
    sign^=parity;
    unsigned r=image[32768+row*128+group];
    if constexpr(mode==1) {
      unsigned fives,threes=masks(c>>8,image+49298,fives);
      unsigned odd=__popc(threes)&1;
      float sum=0.f,main=0.f,slot7=0.f;
      #pragma unroll
      for(int k=0;k<8;k++) {
        int j=(k/2)+4*(k%2);
        float z=x[group*8+k];
        float term=((sign>>j)&1)?-z:z;
        sum+=z;
        main+=term*((threes>>j&1)?1.5f:.5f); // .5 base + 1 for each 3
        if(fives>>j&1)main+=2.f*term;
        if(j==7)slot7=term;
      }
      if(odd)main-=(1.f+2.f*(threes>>7&1)+4.f*(fives>>7&1))*slot7;
      base+=main+(parity?-.25f:.25f)*sum;
    } else {
      unsigned packed=abs_grid[c>>8];
      #pragma unroll
      for(int k=0;k<8;k++) {
        int j=(k/2)+4*(k%2);
        float a=((int)((packed>>(4*j))&15)-8)*0.5f;
        if((sign>>j)&1)a=-a;
        a+=(parity?-.25f:.25f);
        base=fmaf(a,x[group*8+k],base);
      }
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
  float scale=__half2float(*((const __half*)(image+49296)));
  y[row]=(base+resid/2.04f)*scale;
  __syncthreads();transform128(y,row);
  output[batch*128+row]=y[row]*((vs>>(row%8)&1)?-1.f:1.f);
}

// CPU one-time preparation. The 29 exception bytes stay in the stored image; output is
// a separate, live 1024B device allocation transferred once, reused by all launches.
extern "C" __attribute__((noinline)) void prepare_magnitudes(const unsigned char *image,unsigned *table) {
  for(unsigned c=0;c<256;c++) table[c]=packed_magnitude(c,image+49298);
}
extern "C" unsigned *prepare_device_magnitudes(const unsigned char *host_image) {
  unsigned table[256],*device_table=nullptr;
  prepare_magnitudes(host_image,table);
  if(hipMalloc(&device_table,sizeof(table))!=hipSuccess)return nullptr;
  if(hipMemcpy(device_table,table,sizeof(table),hipMemcpyHostToDevice)!=hipSuccess) {
    (void)hipFree(device_table);return nullptr;
  }
  return device_table;
}
extern "C" hipError_t release_device_magnitudes(unsigned *table) {return hipFree(table);}

// Keeping actual HIP launch descriptors/stubs in the object stops dead-stripping
// and exposes the complete three readers in the emitted gfx1151 device image.
extern "C" void launch_original(const float *x,float *y,const unsigned char *image,unsigned n) {
  hipLaunchKernelGGL((quip<0>),dim3(n),dim3(128),0,0,x,y,image,nullptr);
}
extern "C" void launch_direct(const float *x,float *y,const unsigned char *image,unsigned n) {
  hipLaunchKernelGGL((quip<1>),dim3(n),dim3(128),0,0,x,y,image,nullptr);
}
extern "C" void launch_prepared(const float *x,float *y,const unsigned char *image,const unsigned *table,unsigned n) {
  hipLaunchKernelGGL((quip<2>),dim3(n),dim3(128),0,0,x,y,image,table);
}
