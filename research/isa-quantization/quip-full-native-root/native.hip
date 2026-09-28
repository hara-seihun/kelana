#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
#define HIP(x) do { auto e=(x); if(e!=hipSuccess){fprintf(stderr,"HIP %s:%d: %s\n",__FILE__,__LINE__,hipGetErrorString(e));exit(1);} } while(0)

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

// Mode 0: original FP16 residual table. Mode 1: byte-labelled root with no residual table.
template<int mode> __global__ void quip(const float *input,float *output,const unsigned char *image,const __half *old_residual) {
  int row=threadIdx.x,batch=blockIdx.x;
  __shared__ float x[1024],y[128];
  const unsigned short *code=(const unsigned short *)image;
  const unsigned *abs_grid=(const unsigned *)(image+49298);
  unsigned char us=image[49152+row/8],vs=image[49280+row/8];
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
    unsigned packed=abs_grid[c>>8];
    unsigned r=image[32768+row*128+group];
    #pragma unroll
    for(int k=0;k<8;k++) {
      int j=(k/2)+4*(k%2);
      float a=((int)((packed>>(4*j))&15)-8)*0.5f;
      if((sign>>j)&1)a=-a;
      a+=(parity?-.25f:.25f);
      base=fmaf(a,x[group*8+k],base);
    }
    if constexpr(mode==0) {
      #pragma unroll
      for(int k=0;k<8;k++)resid=fmaf(__half2float(old_residual[r*8+k]),x[group*8+k],resid);
    } else {
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
  }
  float scale=__half2float(*((const __half*)(image+49296)));
  y[row]=(base+resid/2.04f)*scale;
  __syncthreads();transform128(y,row);
  output[batch*128+row]=y[row]*((vs>>(row%8)&1)?-1.f:1.f);
}

__global__ void scalar(const float *input,float *output,const unsigned char *image) {
  int row=threadIdx.x,batch=blockIdx.x,preceding=0;
  const unsigned *mask=(const unsigned *)image;
  for(int i=0;i<32;i++) {
    unsigned m=mask[i];int bit=row*8;
    if(i<bit/32)preceding+=__popc(m);
    else if(i==bit/32)preceding+=__popc(m&((1u<<(bit%32))-1));
  }
  int offset=128+row*416-16*preceding;
  float sum=0.f;
  for(int g=0;g<8;g++) {
    int bit=row*8+g,bits=((image[bit/8]>>(bit%8))&1)?2:3;
    int nbytes=16*bits;
    float scale=__half2float(*((const __half*)(image+offset+nbytes)));
    float origin=__half2float(*((const __half*)(image+offset+nbytes+2)));
    float codesum=0.f,xsum=0.f;
    for(int k=0;k<128;k++) {
      int b=k*bits,pos=b/8,shift=b%8;
      unsigned digit=image[offset+pos]>>shift;
      if(shift+bits>8)digit|=(unsigned)image[offset+pos+1]<<(8-shift);
      digit&=(1u<<bits)-1;
      float v=input[batch*1024+g*128+k];
      codesum=fmaf((float)digit,v,codesum);xsum+=v;
    }
    sum+=scale*codesum+origin*xsum;
    offset+=nbytes+4;
  }
  output[batch*128+row]=sum;
}

std::vector<unsigned char> read(const std::string&p){std::ifstream f(p,std::ios::binary);if(!f)throw std::runtime_error("missing "+p);return {std::istreambuf_iterator<char>(f),{}};}
template<class T> T*device(const std::vector<unsigned char>&v){T*p;HIP(hipMalloc(&p,v.size()));HIP(hipMemcpy(p,v.data(),v.size(),hipMemcpyHostToDevice));return p;}
int main(int argc,char**argv){
  if(argc!=3){fprintf(stderr,"usage: native ISA_QUANTIZATION_DIR PREPARED_DIR\n");return 2;}
  std::string root=argv[1],prep=argv[2];
  auto old=read(root+"/quip-full-row-slab/quip-rvq3-standalone.bin"),fresh=read(root+"/e8-root-program/quip-root-standalone.bin"),grid=read(root+"/quip-e8p-local/e81b-grid.bin"),ctl=read(root+"/quip-root-matched-scalar/refit-group-q2q3-50320.bin"),x=read(prep+"/input.f32");
  if(old.size()!=54418||fresh.size()!=50322||grid.size()!=4096||ctl.size()!=50320||x.size()!=8*1024*4)throw std::runtime_error("unexpected stored-image/input size");
  auto *dold=device<unsigned char>(old),*dnew=device<unsigned char>(fresh),*dctl=device<unsigned char>(ctl);
  auto *dx=device<float>(x);auto *dgrid=device<__half>(grid);float *dy;HIP(hipMalloc(&dy,8*128*4));
  printf("gfx1151 complete full-row native, bytes root=%zu old=%zu scalar=%zu; old generic residual=%zu, root=0, included absolute=1024 each; no expanded weight\n",fresh.size(),old.size(),ctl.size(),grid.size());
  for(int batch:{1,8}) {
    auto launch=[&](int mode){if(mode==0)hipLaunchKernelGGL((quip<0>),dim3(batch),dim3(128),0,0,dx,dy,dold,dgrid);
                          else if(mode==1)hipLaunchKernelGGL((quip<1>),dim3(batch),dim3(128),0,0,dx,dy,dnew,dgrid);
                          else hipLaunchKernelGGL(scalar,dim3(batch),dim3(128),0,0,dx,dy,dctl);};
    double maxdiff[3],quality[3];
    auto teacher=read(prep+"/teacher-target.f32");
    for(int mode=0;mode<3;mode++) {
      std::string label=mode==0?"old":mode==1?"root":"scalar";
      auto target=read(prep+"/"+label+"-target.f32");
      launch(mode);HIP(hipGetLastError());HIP(hipDeviceSynchronize());
      std::vector<float> result(batch*128);HIP(hipMemcpy(result.data(),dy,result.size()*4,hipMemcpyDeviceToHost));
      const float*t=(const float*)target.data(),*w=(const float*)teacher.data();double sse=0,energy=0;maxdiff[mode]=0;
      for(size_t i=0;i<result.size();i++){maxdiff[mode]=std::max(maxdiff[mode],(double)fabs(result[i]-t[i]));sse+=pow((double)result[i]-w[i],2);energy+=pow((double)w[i],2);}
      quality[mode]=sse/energy;
      if(maxdiff[mode]>5e-5){fprintf(stderr,"%s batch%d mismatch %.9g first %.9g expected %.9g\n",label.c_str(),batch,maxdiff[mode],result[0],t[0]);return 1;}
      for(int k=0;k<16;k++)launch(mode);
      HIP(hipDeviceSynchronize());
    }
    hipEvent_t start,stop;HIP(hipEventCreate(&start));HIP(hipEventCreate(&stop));
    std::vector<double> events[3],walls[3];
    for(int round=0;round<16;round++)for(int k=0;k<3;k++)for(int n=0;n<3;n++) {
      int mode=(k+round)%3;
      auto before=std::chrono::steady_clock::now();HIP(hipEventRecord(start));launch(mode);HIP(hipEventRecord(stop));HIP(hipEventSynchronize(stop));
      auto after=std::chrono::steady_clock::now();float ms;HIP(hipEventElapsedTime(&ms,start,stop));events[mode].push_back(ms*1000);walls[mode].push_back(std::chrono::duration<double,std::micro>(after-before).count());
    }
    auto median=[](std::vector<double>a){std::sort(a.begin(),a.end());return a[a.size()/2];};
    for(int mode=0;mode<3;mode++) {
      const char *label=mode==0?"old":mode==1?"root":"scalar";
      printf("%s batch=%d max_abs_vs_stored=%.9g relative_squared_vs_teacher=%.9g event_us_median=%.3f wall_us_median=%.3f event_us=[",label,batch,maxdiff[mode],quality[mode],median(events[mode]),median(walls[mode]));
      for(double v:events[mode])printf("%.3f,",v);printf("] wall_us=[");for(double v:walls[mode])printf("%.3f,",v);printf("]\n");
    }
    HIP(hipEventDestroy(start));HIP(hipEventDestroy(stop));
  }
  HIP(hipFree(dold));HIP(hipFree(dnew));HIP(hipFree(dctl));HIP(hipFree(dgrid));HIP(hipFree(dx));HIP(hipFree(dy));
}
