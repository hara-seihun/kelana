#include <hip/hip_runtime.h>
#include <array>
#include <cstdio>
#include <cstdlib>
#include <cstdint>

#define HIP(call) do { hipError_t e=(call); if(e!=hipSuccess){std::fprintf(stderr,"%s\n",hipGetErrorString(e));return 1;} } while(0)

struct Table { unsigned lower, upper; };

__global__ void observer(const unsigned* input, const Table* tables, unsigned char* output, unsigned n) {
    const unsigned i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i>=n)return;
    const unsigned raw=input[i];
    const Table t=tables[i/9];
    unsigned selector, result;
    asm("v_bfe_u32 %0, 0x722c, %1, 4" : "=v"(selector) : "v"(raw));
    asm("v_perm_b32 %0, %1, %2, %3" : "=v"(result) : "v"(t.upper),"v"(t.lower),"v"(selector));
    output[i]=static_cast<unsigned char>(result);
}

int main() {
    if(!std::getenv("KELANA_GPU_RESEARCH_LOCK")){
        std::fprintf(stderr,"Use ../batched/hardware-run for GPU work\n");return 1;
    }
    constexpr unsigned nt=257,n=nt*9;
    std::array<unsigned,n> input{};
    std::array<unsigned char,n> expected{},got{};
    std::array<Table,nt> tables{};
    unsigned rng=816372;
    for(unsigned t=0;t<nt;++t){
        for(int x=-1,i=0;x<=1;++x)for(int y=-1;y<=1;++y,++i){
            const unsigned raw=(unsigned(x)&3u)|((unsigned(y)&3u)<<2);
            input[t*9+i]=raw;
            rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;
            const int toy[9]={8,0,-2,6,0,-4,2,0,-4};
            expected[t*9+i]=raw==0?0:static_cast<unsigned char>(t==0?toy[i]:int(rng&255));
        }
        // f[x+1][y+1], ordered by the proved selector permutation.
        const unsigned order[8]={0,8,5,6,2,1,7,3};
        for(unsigned b=0;b<8;++b){
            unsigned& word=b<4?tables[t].lower:tables[t].upper;
            word|=unsigned(expected[t*9+order[b]])<<(8*(b%4));
        }
    }
    unsigned* in=nullptr;Table* ts=nullptr;unsigned char* out=nullptr;
    HIP(hipMalloc(&in,sizeof input));HIP(hipMalloc(&ts,sizeof tables));HIP(hipMalloc(&out,sizeof got));
    HIP(hipMemcpy(in,input.data(),sizeof input,hipMemcpyHostToDevice));
    HIP(hipMemcpy(ts,tables.data(),sizeof tables,hipMemcpyHostToDevice));
    observer<<<(n+127)/128,128>>>(in,ts,out,n);
    HIP(hipGetLastError());HIP(hipDeviceSynchronize());
    HIP(hipMemcpy(got.data(),out,sizeof got,hipMemcpyDeviceToHost));
    unsigned mismatches=0;
    for(unsigned i=0;i<n;++i)mismatches+=got[i]!=expected[i];
    HIP(hipFree(in));HIP(hipFree(ts));HIP(hipFree(out));
    hipDeviceProp_t prop{};HIP(hipGetDeviceProperties(&prop,0));
    std::printf("{\"device\":\"%s\",\"functions\":%u,\"cases\":%u,\"mismatches\":%u,\"map_instructions\":2,\"output\":\"low byte\",\"timing_measured\":false}\n",prop.gcnArchName,nt,n,mismatches);
    return mismatches!=0;
}
