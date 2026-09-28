#include <hip/hip_runtime.h>
#include <hipblas/hipblas.h>
#include <hip/hip_fp16.h>
#include <array>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#define H(call) do { auto err=(call); if(err!=hipSuccess) throw std::runtime_error(std::string(#call)+": "+hipGetErrorString(err)); } while(0)
#define B(call) do { auto err=(call); if(err!=HIPBLAS_STATUS_SUCCESS) throw std::runtime_error(std::string(#call)+": "+std::to_string(err)); } while(0)

std::vector<char> read(const std::string &p, size_t bytes) {
    std::ifstream f(p, std::ios::binary | std::ios::ate);
    if(!f || size_t(f.tellg())!=bytes) throw std::runtime_error("wrong size or missing: "+p);
    std::vector<char> b(bytes); f.seekg(0); f.read(b.data(), bytes); return b;
}
struct Buffer {
    void* ptr=nullptr;
    Buffer(const std::string &p, size_t bytes) { auto data=read(p,bytes); H(hipMalloc(&ptr,bytes)); H(hipMemcpy(ptr,data.data(),bytes,hipMemcpyHostToDevice)); }
    explicit Buffer(size_t bytes) { H(hipMalloc(&ptr,bytes)); }
    ~Buffer(){if(ptr) hipFree(ptr);}
    Buffer(const Buffer&)=delete;
    Buffer& operator=(const Buffer&)=delete;
};

// One wave reduces one output dot. The first and second factor stages both decode
// their own row/group scale inside the operation, without a weight preparation pass.
__global__ void packed_dot(const half* x, const uint8_t* codes, const half* scales,
                           float* y, int n, int k, int group, int batch, int x_is_float) {
    int row = blockIdx.x * 4 + threadIdx.x / 32;
    int lane = threadIdx.x % 32;
    int b = blockIdx.y;
    if (row >= n || b >= batch) return;
    float sum=0;
    for(int i=lane;i<k;i+=32) {
        uint8_t packed = codes[row*(k/2) + i/2];
        float v = float(int((i&1) ? packed>>4 : packed&15)*2-15) * float(scales[row*((k+group-1)/group)+i/group]);
        float a=x_is_float ? ((const float*)x)[b*k+i] : float(x[b*k+i]);
        sum=fmaf(a,v,sum);
    }
    for(int off=16;off;off>>=1) sum+=__shfl_down(sum,off);
    if(!lane) y[b*n+row]=sum;
}
__global__ void dense_half(const half* x, const half* weights, float* y, int n, int batch) {
    int row=blockIdx.x*4+threadIdx.x/32, lane=threadIdx.x%32, b=blockIdx.y;
    if(row>=n) return;
    float sum=0;
    for(int i=lane;i<1024;i+=32) sum=fmaf(float(x[b*1024+i]),float(weights[row*1024+i]),sum);
    for(int off=16;off;off>>=1) sum+=__shfl_down(sum,off);
    if(!lane) y[b*2048+row]=sum;
}
__global__ void dense_int4(const half* x, const uint8_t* codes, const half* scales,
                           float* y, int n, int batch) {
    int row=blockIdx.x*4+threadIdx.x/32, lane=threadIdx.x%32, b=blockIdx.y;
    if(row>=n) return;
    float sum=0;
    for(int i=lane;i<1024;i+=32) {
        uint8_t p=codes[row*512+i/2];
        float v=float(2*int((i&1)?p>>4:p&15)-15)*float(scales[row*8+i/128]);
        sum=fmaf(float(x[b*1024+i]),v,sum);
    }
    for(int off=16;off;off>>=1) sum+=__shfl_down(sum,off);
    if(!lane) y[b*2048+row]=sum;
}
__global__ void intermediate_half(const float* src, half* dst, int count) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i<count) dst[i]=half(src[i]);
}

struct Sample {std::string arm; int batch; int round; float us; double error;};
int main(int argc,char**argv) try {
    if(argc!=3) throw std::runtime_error("usage: probe INPUT_DIR OUT.json");
    std::string d=argv[1]; auto file=[&](const char* n){return d+"/"+n+std::string(".bin");};
    Buffer x(file("x"),16*1024*2), lc(file("left_codes"),2048*44),ls(file("left_scales"),2048*2),
           rc(file("right_codes"),88*512),rs(file("right_scales"),88*8*2),
           lf(file("left_f16"),2048*88*2),rf(file("right_f16"),88*1024*2),
           expanded(file("expanded_f16"),2048*1024*2),ic(file("int4_codes"),2048*512),is(file("int4_scales"),2048*8*2),
           temp(16*88*4),temp_half(16*88*2),out(16*2048*4);
    auto reference=read(file("reference"),16*2048*4);
    hipblasHandle_t handle; B(hipblasCreate(&handle));
    float alpha=1,beta=0;
    auto gemm=[&](const Buffer& w, const half* input, int m,int k,int batch,void* result,hipDataType result_type) {
        B(hipblasGemmEx(handle,HIPBLAS_OP_T,HIPBLAS_OP_N,m,batch,k,&alpha,w.ptr,HIP_R_16F,k,
                        input,HIP_R_16F,k,&beta,result,result_type,m,HIPBLAS_COMPUTE_32F,HIPBLAS_GEMM_DEFAULT));
    };
    std::vector<Sample> samples;
    const std::array<std::string,5> arms={"packed_factors","expanded_factor_f16_blas","expanded_dense_f16_blas","expanded_dense_f16_wave","dense_int4"};
    hipEvent_t start,end; H(hipEventCreate(&start)); H(hipEventCreate(&end));
    for(int batch : {1,16}) {
        for(int round=0;round<9;round++) {
            for(int a=0;a<5;a++) {
                const std::string& arm=arms[(round+a)%5];
                auto invoke=[&]() {
                    if(arm=="packed_factors") {
                        packed_dot<<<dim3(22,batch),128>>>((half*)x.ptr,(uint8_t*)rc.ptr,(half*)rs.ptr,(float*)temp.ptr,88,1024,128,batch,0);
                        packed_dot<<<dim3(512,batch),128>>>((half*)temp.ptr,(uint8_t*)lc.ptr,(half*)ls.ptr,(float*)out.ptr,2048,88,128,batch,1);
                    } else if(arm=="expanded_factor_f16_blas") {
                        gemm(rf,(half*)x.ptr,88,1024,batch,temp_half.ptr,HIP_R_16F);
                        gemm(lf,(half*)temp_half.ptr,2048,88,batch,out.ptr,HIP_R_32F);
                    } else if(arm=="expanded_dense_f16_blas") {
                        gemm(expanded,(half*)x.ptr,2048,1024,batch,out.ptr,HIP_R_32F);
                    } else if(arm=="expanded_dense_f16_wave") {
                        dense_half<<<dim3(512,batch),128>>>((half*)x.ptr,(half*)expanded.ptr,(float*)out.ptr,2048,batch);
                    } else {
                        dense_int4<<<dim3(512,batch),128>>>((half*)x.ptr,(uint8_t*)ic.ptr,(half*)is.ptr,(float*)out.ptr,2048,batch);
                    }
                };
                for(int i=0;i<6;i++) invoke();
                H(hipDeviceSynchronize());
                H(hipEventRecord(start));
                for(int i=0;i<32;i++) invoke();
                H(hipEventRecord(end)); H(hipEventSynchronize(end));
                float ms; H(hipEventElapsedTime(&ms,start,end));
                std::vector<float> y(batch*2048); H(hipMemcpy(y.data(),out.ptr,y.size()*4,hipMemcpyDeviceToHost));
                auto* ref=(const float*)reference.data(); double numerator=0,denominator=0;
                for(size_t i=0;i<y.size();i++){double diff=y[i]-ref[i]; numerator+=diff*diff;denominator+=double(ref[i])*ref[i];}
                samples.push_back({arm,batch,round,ms*1000/32,numerator/denominator});
            }
        }
    }
    H(hipEventDestroy(start)); H(hipEventDestroy(end)); B(hipblasDestroy(handle));
    std::ofstream o(argv[2]); o<<"{\n  \"device\": \""; hipDeviceProp_t prop; H(hipGetDeviceProperties(&prop,0));o<<prop.name<<"\",\n";
    o<<"  \"method\": \"hip events, 32 consecutive host-submitted invocations/sample, 6 warmup invocations/arm/round, 9 rotated rounds; all operands device-resident; BLAS included\",\n";
    o<<"  \"samples\": [\n";
    for(size_t i=0;i<samples.size();i++){auto s=samples[i];o<<"    {\"arm\": \""<<s.arm<<"\", \"batch\": "<<s.batch<<", \"round\": "<<s.round<<", \"microseconds\": "<<s.us<<", \"relative_squared_error_vs_factor_fp32\": "<<s.error<<"}"<<(i+1==samples.size()?"":" ,")<<"\n";}
    o<<"  ]\n}\n";
    std::cout<<"wrote "<<argv[2]<<" ("<<samples.size()<<" samples)\n";
} catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
