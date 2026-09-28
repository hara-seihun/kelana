#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include "tables.h"

#define HIP(call) do { hipError_t e=(call); if(e!=hipSuccess) { fprintf(stderr,"%s: %s\n",#call,hipGetErrorString(e)); exit(1); } } while(0)

template<int Mode>
__global__ void cell_to_consumer(const uint8_t* __restrict__ x,
                                 const float* __restrict__ t,
                                 const __half* __restrict__ table,
                                 float* __restrict__ out, int n) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i>=n) return;
    unsigned v=x[i];
    unsigned q;
    if constexpr (Mode==0) q=(v*v)>>7;
    if constexpr (Mode==1) q=(31*v)>>7;
    if constexpr (Mode==2) q=v>>2;
    if constexpr (Mode==3) q=v;
    float z=t[i];
    float y0=__half2float(table[4*q]);
    float y1=__half2float(table[4*q+1]);
    float y2=__half2float(table[4*q+2]);
    out[i]=fmaf(y2,z*z,fmaf(y1,z,y0));
}

static float half_to_float(uint16_t bits) {
    unsigned sign=bits>>15, exponent=(bits>>10)&31, mantissa=bits&1023;
    if(exponent) return (sign?-1.f:1.f)*std::ldexp(float(1024+mantissa),int(exponent)-25);
    return (sign?-1.f:1.f)*std::ldexp(float(mantissa),-24);
}

int main(int argc,char** argv) {
    int n=1<<20, repeats=128, rounds=5;
    if(argc>1) n=std::atoi(argv[1]);
    if(argc>2) repeats=std::atoi(argv[2]);
    if(n<=0 || repeats<=0 || n>1<<22 || repeats>1000) return 2;
    constexpr std::array<const char*,4> names={"square8","affine8","uniform8","direct32"};
    const uint16_t* bits[4]={square_bits,affine_bits,uniform_bits,direct_bits};
    const size_t sizes[4]={sizeof(square_bits),sizeof(affine_bits),sizeof(uniform_bits),sizeof(direct_bits)};
    std::vector<uint8_t> hx(n);
    std::vector<float> ht(n),ho(n);
    constexpr float tv[4]={-1.f,-.25f,.5f,1.25f};
    for(int i=0;i<n;i++) { hx[i]=uint8_t((i*13+7)&31); ht[i]=tv[(i/32 + i/7)&3]; }
    uint8_t* dx; float *dt,*dout;
    HIP(hipMalloc(&dx,n)); HIP(hipMalloc(&dt,n*sizeof(float))); HIP(hipMalloc(&dout,n*sizeof(float)));
    HIP(hipMemcpy(dx,hx.data(),n,hipMemcpyHostToDevice));
    HIP(hipMemcpy(dt,ht.data(),n*sizeof(float),hipMemcpyHostToDevice));
    __half* tables[4];
    for(int m=0;m<4;m++) {HIP(hipMalloc(&tables[m],sizes[m])); HIP(hipMemcpy(tables[m],bits[m],sizes[m],hipMemcpyHostToDevice));}
    auto launch=[&](int mode) {
        switch(mode) {
        case 0: hipLaunchKernelGGL((cell_to_consumer<0>),dim3((n+255)/256),dim3(256),0,0,dx,dt,tables[0],dout,n); break;
        case 1: hipLaunchKernelGGL((cell_to_consumer<1>),dim3((n+255)/256),dim3(256),0,0,dx,dt,tables[1],dout,n); break;
        case 2: hipLaunchKernelGGL((cell_to_consumer<2>),dim3((n+255)/256),dim3(256),0,0,dx,dt,tables[2],dout,n); break;
        case 3: hipLaunchKernelGGL((cell_to_consumer<3>),dim3((n+255)/256),dim3(256),0,0,dx,dt,tables[3],dout,n); break;
        }
        HIP(hipGetLastError());
    };
    for(int m=0;m<4;m++) {
        launch(m); HIP(hipDeviceSynchronize()); HIP(hipMemcpy(ho.data(),dout,n*sizeof(float),hipMemcpyDeviceToHost));
        float maxdiff=0;
        for(int i=0;i<n;i++) {
            unsigned x=hx[i]; unsigned q=m==0 ? (x*x)>>7 : m==1 ? (31*x)>>7 : m==2 ? x>>2 : x;
            const uint16_t* row=bits[m]+4*q;
            float t=ht[i];
            float expected=std::fma(half_to_float(row[2]),t*t,std::fma(half_to_float(row[1]),t,half_to_float(row[0])));
            maxdiff=std::max(maxdiff,std::fabs(ho[i]-expected));
        }
        printf("verify %s max_abs=%.9g static_table_bytes=%zu\n",names[m],maxdiff,sizes[m]);
        if(maxdiff>0.00003f) return 3;
    }
    hipEvent_t start,end; HIP(hipEventCreate(&start)); HIP(hipEventCreate(&end));
    float times[4][5]{};
    for(int round=0;round<rounds;round++) for(int offset=0;offset<4;offset++) {
        int m=(round+offset)%4;
        launch(m); HIP(hipDeviceSynchronize());
        HIP(hipEventRecord(start));
        for(int k=0;k<repeats;k++) launch(m);
        HIP(hipEventRecord(end)); HIP(hipEventSynchronize(end));
        float ms; HIP(hipEventElapsedTime(&ms,start,end));
        times[m][round]=1000.f*ms/repeats;
    }
    for(int m=0;m<4;m++) {
        std::sort(times[m],times[m]+rounds);
        printf("timing %s n=%d replays=%d median_us=%.6f range_us=%.6f..%.6f\n",names[m],n,repeats,times[m][2],times[m][0],times[m][4]);
    }
    HIP(hipEventDestroy(start)); HIP(hipEventDestroy(end));
    for(auto p:tables) HIP(hipFree(p));
    HIP(hipFree(dx)); HIP(hipFree(dt)); HIP(hipFree(dout));
}
