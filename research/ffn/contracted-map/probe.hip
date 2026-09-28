#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>

#define HIP(call) do { hipError_t e=(call); if(e!=hipSuccess){std::fprintf(stderr,"%s\n",hipGetErrorString(e));return 1;} } while(0)

__device__ unsigned feature_word(int x, int y) {
    const int t[7]={x,y,x*x,y*y,x*y,x*x*y,x*y*y};
    unsigned r=0;
    #pragma unroll
    for(int i=0;i<7;++i) r|=(unsigned(t[i])&15u)<<(4*i);
    return r;
}

__global__ void contracted(const unsigned* input, int* output) {
    const unsigned i=threadIdx.x;
    if(i>=9)return;
    const unsigned code=input[i];
    const int x=int(code<<30)>>30, y=int(code<<28)>>30;
    output[i]=__builtin_amdgcn_sudot8(true,0x0e1110b0,true,int(feature_word(x,y)),0,false);
}

int main() {
    if(!std::getenv("KELANA_GPU_RESEARCH_LOCK")){
        std::fprintf(stderr,"Use ../batched/hardware-run for GPU work\n");return 1;
    }
    unsigned input[9];
    for(int x=-1,i=0;x<=1;++x)for(int y=-1;y<=1;++y)
        input[i++]=(unsigned(x)&3u)|((unsigned(y)&3u)<<2);
    // Two times the 64-unit network output; the full network is in ContractedToy.lean.
    const int expected[9]={8,0,-2,6,0,-4,2,0,-4};
    unsigned* in=nullptr; int* out=nullptr;
    HIP(hipMalloc(&in,sizeof input));HIP(hipMalloc(&out,sizeof expected));
    HIP(hipMemcpy(in,input,sizeof input,hipMemcpyHostToDevice));
    contracted<<<1,32>>>(in,out);
    HIP(hipGetLastError());HIP(hipDeviceSynchronize());
    int got[9];HIP(hipMemcpy(got,out,sizeof got,hipMemcpyDeviceToHost));
    int mismatches=0;
    for(int i=0;i<9;++i)mismatches+=got[i]!=expected[i];
    HIP(hipFree(in));HIP(hipFree(out));
    std::printf("{\"cases\":9,\"mismatches\":%d,\"output\":\"2F\",\"input_feature_encoding_included\":true,\"timing_measured\":false}\n",mismatches);
    return mismatches!=0;
}
