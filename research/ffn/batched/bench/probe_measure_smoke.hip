#include "probe_measure.hpp"
#include <fstream>

__global__ void write_indices(unsigned* out) {
    unsigned i=blockIdx.x*blockDim.x+threadIdx.x;
    out[i]=i^0x5a;
}
int main(int argc,char** argv) {
    if(argc!=2){std::fprintf(stderr,"Usage: probe-measure-smoke OUTPUT.json\n");return 2;}
    unsigned* out=nullptr;kbprobe::checked(hipMalloc(&out,1024*sizeof(unsigned)));
    auto launch=[=](hipStream_t s){write_indices<<<4,256,0,s>>>(out);};
    std::vector<kbprobe::Case> cases{{"copy-a",1024,launch},{"copy-b",1024,launch}};
    kbprobe::Config config;config.work_unit="stores";
    config.scope="Measurement-format smoke test with identical kernels. Not a kernel speed claim.";
    config.input_description="No input buffer. Each kernel writes index XOR 0x5a to 1024 outputs.";
    config.source_files={__FILE__,"probe_measure.hpp","timing.hpp","telemetry.hpp","sha256.hpp"};
    const auto result=kbprobe::measure(cases,config);
    std::vector<unsigned> got(1024);
    kbprobe::checked(hipMemcpy(got.data(),out,got.size()*sizeof(unsigned),hipMemcpyDeviceToHost));
    kbprobe::checked(hipFree(out));
    for(unsigned i=0;i<got.size();++i)if(got[i]!=(i^0x5a)){std::fprintf(stderr,"Wrong output at %u\n",i);return 1;}
    std::ofstream f(argv[1]);f<<result<<'\n';
    if(!f){std::fprintf(stderr,"Cannot write %s\n",argv[1]);return 1;}
}
