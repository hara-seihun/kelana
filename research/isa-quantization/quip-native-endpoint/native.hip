#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <string>
#include <fstream>
#include <chrono>
#include <algorithm>
#include <numeric>
#include <stdexcept>

#define HIP(x) do { hipError_t e=(x); if(e!=hipSuccess) { fprintf(stderr,"HIP %s:%d %s\n",__FILE__,__LINE__,hipGetErrorString(e)); exit(1); } } while(0)

__device__ void fwht(float *a,int lane) {
  for(int width=1;width<128;width*=2) {
    float left=a[lane&~width], right=a[(lane&~width)|width];
    __syncthreads();
    a[lane]=(lane&width)?left-right:left+right;
    __syncthreads();
  }
  a[lane]*=0.08838834764831844f;
  __syncthreads();
}

__global__ void quip_reader(const float *x,float *y,const unsigned char *image,const unsigned *absolute,const __half *residual) {
  int row=threadIdx.x,batch=blockIdx.x;
  __shared__ float input[128],output[128];
  unsigned char sv=image[6160+row/8],su=image[6144+row/8];
  input[row]=x[batch*128+row]*((su>>(row%8)&1)?-1.f:1.f);
  __syncthreads();fwht(input,row);
  const unsigned short *code=(const unsigned short*)image;
  float sum=0.f,scale=__half2float(*((const __half*)(image+6176)));
  for(int group=0;group<16;group++) {
    unsigned c=code[row*16+group],sign=c&255;
    unsigned parity=__popc(sign)&1;
    sign^=parity;
    unsigned packed=absolute[c>>8];
    unsigned ridx=image[4096+row*16+group];
    #pragma unroll
    for(int k=0;k<8;k++) {
      int j=(k/2)+4*(k%2);
      float a=((int)((packed>>(4*j))&15)-8)*0.5f;
      if((sign>>j)&1) a=-a;
      a+=(parity?-0.25f:0.25f);
      float r=__half2float(residual[ridx*8+k]);
      sum=fmaf(a+r/2.04f,input[group*8+k],sum);
    }
  }
  output[row]=sum*scale;
  __syncthreads();fwht(output,row);
  y[batch*128+row]=output[row]*((sv>>(row%8)&1)?-1.f:1.f);
}

__global__ void scalar_reader(const float *x,float *y,const unsigned char *image) {
  int row=threadIdx.x,batch=blockIdx.x;
  int upgrades=0;
  const unsigned *mask=(const unsigned*)image;
  #pragma unroll
  for(int i=0;i<4;i++) {
    unsigned word=mask[i];
    if(i<row/32) upgrades+=__popc(word);
    else if(i==row/32) upgrades+=__popc(word&((1u<<(row%32))-1));
  }
  int bits=(image[row/8]>>(row%8)&1)?3:2;
  int offset=16+row*36+upgrades*16;
  int nbytes=bits*16;
  float scale=__half2float(*((const __half*)(image+offset+nbytes)));
  float origin=__half2float(*((const __half*)(image+offset+nbytes+2)));
  float sum=0.f,xsum=0.f;
  #pragma unroll 4
  for(int col=0;col<128;col++) {
    int bit=col*bits,p=bit/8,shift=bit%8;
    unsigned digit=(image[offset+p]>>shift);
    if(shift+bits>8) digit|=(unsigned)image[offset+p+1]<<(8-shift);
    digit&=(1u<<bits)-1;
    float v=x[batch*128+col];
    sum=fmaf((float)digit,v,sum);
    xsum+=v;
  }
  y[batch*128+row]=scale*sum+origin*xsum;
}

std::vector<unsigned char> read(const std::string &p) {
  std::ifstream f(p,std::ios::binary);if(!f)throw std::runtime_error("missing "+p);
  return {std::istreambuf_iterator<char>(f),std::istreambuf_iterator<char>()};
}

template<class T> T* device(const std::vector<unsigned char>& data) {
  T* p;HIP(hipMalloc(&p,data.size()));HIP(hipMemcpy(p,data.data(),data.size(),hipMemcpyHostToDevice));return p;
}

int main(int argc,char**argv) {
  if(argc!=3){fprintf(stderr,"usage: native SOURCE_DIR PREPARED_DIR\n");return 2;}
  std::string source=argv[1],prepared=argv[2];
  auto qi=read(source+"/quip-rvq3-r0.bin"),si=read(source+"/refit-mixed-q2q3-6176.bin");
  auto abs=read(source+"/e8p-abs-grid.bin"),res=read(source+"/e81b-grid.bin");
  auto x=read(prepared+"/inputs.f32");
  if(qi.size()!=6178||si.size()!=6176||abs.size()!=1024||res.size()!=4096||x.size()!=4096)throw std::runtime_error("unexpected image/input size");
  unsigned char *dq=device<unsigned char>(qi),*ds=device<unsigned char>(si);
  unsigned *da=device<unsigned>(abs);__half *dr=device<__half>(res);
  float *dx=device<float>(x),*dy;HIP(hipMalloc(&dy,4096));
  printf("gfx1151 native stored-image readers; image bytes QuIP=%zu scalar=%zu; shared generic QuIP tables=%zu; device input/output=4096 each; no expanded weight\n",qi.size(),si.size(),abs.size()+res.size());
  for(int batch: {1,8})for(int mode: {0,1}) {
    auto launch=[&](){if(mode==0)hipLaunchKernelGGL(quip_reader,dim3(batch),dim3(128),0,0,dx,dy,dq,da,dr);
                     else hipLaunchKernelGGL(scalar_reader,dim3(batch),dim3(128),0,0,dx,dy,ds);};
    auto target=read(prepared+(mode==0?"/quip-target.f32":"/scalar-target.f32"));
    auto teacher=read(prepared+"/teacher-target.f32");
    launch();HIP(hipGetLastError());HIP(hipDeviceSynchronize());
    std::vector<float> result(batch*128);HIP(hipMemcpy(result.data(),dy,result.size()*4,hipMemcpyDeviceToHost));
    float *t=(float*)target.data(),*w=(float*)teacher.data();double maxdiff=0,sse=0,energy=0;
    for(size_t k=0;k<result.size();k++){maxdiff=std::max(maxdiff,(double)std::abs(result[k]-t[k]));sse+=std::pow((double)result[k]-w[k],2);energy+=std::pow((double)w[k],2);}
    if(maxdiff>5e-7){fprintf(stderr,"%s batch %d maxdiff %.9g first native %.9g replay %.9g\n",mode?"scalar":"quip",batch,maxdiff,result[0],t[0]);throw std::runtime_error("stored-image replay mismatch");}
    for(int i=0;i<20;i++)launch();HIP(hipDeviceSynchronize());
    hipEvent_t start,stop;HIP(hipEventCreate(&start));HIP(hipEventCreate(&stop));
    std::vector<double> events,walls;
    for(int i=0;i<60;i++){
      auto before=std::chrono::steady_clock::now();
      HIP(hipEventRecord(start));launch();HIP(hipEventRecord(stop));HIP(hipEventSynchronize(stop));
      auto after=std::chrono::steady_clock::now();float ms=0;HIP(hipEventElapsedTime(&ms,start,stop));
      events.push_back(ms*1000);walls.push_back(std::chrono::duration<double,std::micro>(after-before).count());
    }
    auto median=[](std::vector<double> a){std::sort(a.begin(),a.end());return a[a.size()/2];};
    printf("%s batch=%d max_abs_vs_image=%.8g relative_squared_vs_teacher=%.9g event_us_median=%.3f wall_us_median=%.3f event_us=[",mode?"scalar":"quip",batch,maxdiff,sse/energy,median(events),median(walls));
    for(double v:events)printf("%.3f,",v);printf("] wall_us=[");for(double v:walls)printf("%.3f,",v);printf("]\n");
    HIP(hipEventDestroy(start));HIP(hipEventDestroy(stop));
  }
  HIP(hipFree(dq));HIP(hipFree(ds));HIP(hipFree(da));HIP(hipFree(dr));HIP(hipFree(dx));HIP(hipFree(dy));
}
