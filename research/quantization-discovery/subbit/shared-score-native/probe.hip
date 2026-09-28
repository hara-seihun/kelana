#include <hip/hip_runtime.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

#define H(x) do { auto e=(x); if(e!=hipSuccess) throw std::runtime_error(std::string(#x)+": "+hipGetErrorString(e)); } while(0)
constexpr int G=8, C=32, MAX_T=1024, THREADS=256;
constexpr int Q=G*2*C;
struct Device {
    void* p;
    explicit Device(size_t n) { H(hipMalloc(&p,n)); }
    ~Device(){hipFree(p);}
    Device(const Device&)=delete;
};
// q is already the step-scaled query; this kernel charges dynamic maxima, rounding,
// difference formation, nibble packing and the base's two-digit split.
__global__ void prepare(const float* q, uint32_t* digits, float* scales, int streams, int shared) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i>=streams*G) return;
    float a[2][C]; float m[2]={0,0};
    for(int h=0;h<2;h++) for(int j=0;j<C;j++) {
        a[h][j]=q[(i*2+h)*C+j];
        m[h]=fmaxf(m[h],fabsf(a[h][j]));
    }
    float md=0;
    for(int j=0;j<C;j++) md=fmaxf(md,fabsf(a[1][j]-a[0][j]));
    scales[2*i]=m[0]/119.0f;
    scales[2*i+1]=shared?md/7.0f:m[1]/119.0f;
    // Layout per group: four dwords each for base low, base high, correction low,
    // correction high. The shared arm omits correction high's dot, but prepares
    // the same 16 words so both arms use identical allocation and write traffic.
    for(int part=0;part<4;part++) for(int w=0;w<4;w++) {
        uint32_t word=0;
        for(int r=0;r<8;r++) {
            int j=8*w+r;
            float x=part<2?a[0][j]:(shared?a[1][j]-a[0][j]:a[1][j]);
            float scale=part<2?m[0]/119.0f:(shared?md:m[1])/(part==2&&shared?7.0f:119.0f);
            int z=scale>0?__float2int_rn(x/scale):0;
            z=max(-119,min(119,z));
            int digit=part==0||part==2?((z+8)&15)-8:(z-(((z+8)&15)-8))/16;
            if(part==2&&shared) digit=max(-7,min(7,z));
            word|=(uint32_t(digit)&15u)<<(4*r);
        }
        digits[i*16+part*4+w]=word;
    }
}
__global__ void append(uint32_t* keys, int context, int streams, int iteration) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i>=streams*G) return;
    // A freshly produced packed K code, shared by both score arms. The preceding
    // paid binary K projection / norm / code selection is outside this boundary.
    for(int w=0;w<4;w++) keys[(i*context+(context-1))*4+w] =
        0x12345678u ^ (uint32_t(i*4919+w*919+iteration)*0x9e3779b9u);
}
__device__ inline int nibble_dot(uint32_t a,uint32_t b,int acc) {
    return __builtin_amdgcn_sudot8(true,int(a),true,int(b),acc,false);
}
__global__ void score_softmax(const uint32_t* keys,const uint32_t* digits,const float* scales,float* out,
                              int context,int shared,int streams) {
    int group=blockIdx.x, lane=threadIdx.x;
    if(group>=streams*G) return;
    const uint32_t* d=digits+group*16;
    __shared__ float scores[2][MAX_T];
    __shared__ float reduction[THREADS];
    for(int t=lane;t<context;t+=THREADS) {
        const uint32_t* k=keys+(group*context+t)*4;
        int base=0, hi=0, correction=0, correction_hi=0;
        #pragma unroll
        for(int w=0;w<4;w++) {
            uint32_t code=k[w];
            base=nibble_dot(code,d[w],base);
            hi=nibble_dot(code,d[4+w],hi);
            correction=nibble_dot(code,d[8+w],correction);
            if(!shared) correction_hi=nibble_dot(code,d[12+w],correction_hi);
        }
        scores[0][t]=float(base+16*hi)*scales[2*group];
        scores[1][t]=shared?scores[0][t]+float(correction)*scales[2*group+1]
                           :float(correction+16*correction_hi)*scales[2*group+1];
    }
    __syncthreads();
    for(int h=0;h<2;h++) {
        float local=-INFINITY;
        for(int t=lane;t<context;t+=THREADS) local=fmaxf(local,scores[h][t]);
        reduction[lane]=local;
        __syncthreads();
        for(int s=THREADS/2;s;s/=2) {
            if(lane<s) reduction[lane]=fmaxf(reduction[lane],reduction[lane+s]);
            __syncthreads();
        }
        float peak=reduction[0];
        float sum=0;
        for(int t=lane;t<context;t+=THREADS) sum+=expf((scores[h][t]-peak)*0.08838834765f);
        reduction[lane]=sum;
        __syncthreads();
        for(int s=THREADS/2;s;s/=2) {
            if(lane<s) reduction[lane]+=reduction[lane+s];
            __syncthreads();
        }
        float inv=1.0f/reduction[0];
        for(int t=lane;t<context;t+=THREADS)
            out[(group*2+h)*context+t]=expf((scores[h][t]-peak)*0.08838834765f)*inv;
        __syncthreads();
    }
}
int main(int argc,char** argv) try {
    if(argc!=2) throw std::runtime_error("usage: probe OUTPUT.json");
    constexpr int streams=32;
    std::mt19937 rng(60214); std::uniform_real_distribution<float> u(-1,1);
    std::vector<float> query(streams*Q);
    for(int i=0;i<streams*G;i++) for(int j=0;j<C;j++) {
        float v=u(rng);query[(i*2)*C+j]=v;
        query[(i*2+1)*C+j]=v+0.42f*u(rng);
    }
    Device dq(query.size()*4), dk(streams*G*MAX_T*16), dd(streams*G*16*4), ds(streams*G*2*4), dy(streams*G*2*MAX_T*4);
    H(hipMemcpy(dq.p,query.data(),query.size()*4,hipMemcpyHostToDevice));
    std::vector<uint32_t> key(streams*G*MAX_T*4);
    for(auto& v:key) v=rng();
    H(hipMemcpy(dk.p,key.data(),key.size()*4,hipMemcpyHostToDevice));
    hipEvent_t start,end;H(hipEventCreate(&start));H(hipEventCreate(&end));
    std::ofstream output(argv[1]); output<<"{\"device\":\"Radeon 8060S gfx1151\",\"streams\":32,\"samples\":[\n";
    bool first=true;
    for(int context:{256,1024}) for(int round=0;round<9;round++) for(int order=0;order<2;order++) {
        int shared=(round+order)&1;
        for(int complete=0;complete<2;complete++) {
            auto invoke=[&](int iteration){
                if(complete) {
                    append<<<1,THREADS>>>((uint32_t*)dk.p,context,streams,iteration);
                    prepare<<<1,THREADS>>>((const float*)dq.p,(uint32_t*)dd.p,(float*)ds.p,streams,shared);
                }
                score_softmax<<<streams*G,THREADS>>>((const uint32_t*)dk.p,(const uint32_t*)dd.p,(const float*)ds.p,
                    (float*)dy.p,context,shared,streams);
            };
            // Score-only uses the prepared query of its own arm, not the last arm.
            prepare<<<1,THREADS>>>((const float*)dq.p,(uint32_t*)dd.p,(float*)ds.p,streams,shared);
            for(int i=0;i<4;i++) invoke(i);
            H(hipDeviceSynchronize()); H(hipEventRecord(start));
            for(int i=0;i<24;i++) invoke(i);
            H(hipEventRecord(end));H(hipEventSynchronize(end));
            float ms;H(hipEventElapsedTime(&ms,start,end));
            double max_error=0;
            if(round==0&&context==256) {
                std::vector<uint32_t> packed(16), codes(context*4);
                float steps[2]; std::vector<float> gpu(2*context);
                H(hipMemcpy(packed.data(),dd.p,64,hipMemcpyDeviceToHost));
                H(hipMemcpy(codes.data(),dk.p,codes.size()*4,hipMemcpyDeviceToHost));
                H(hipMemcpy(steps,ds.p,8,hipMemcpyDeviceToHost));
                H(hipMemcpy(gpu.data(),dy.p,gpu.size()*4,hipMemcpyDeviceToHost));
                auto dot=[&](int t,int part){
                    int sum=0;
                    for(int j=0;j<32;j++) {
                        int a=(codes[t*4+j/8]>>(4*(j%8)))&15;
                        int b=(packed[part*4+j/8]>>(4*(j%8)))&15;
                        sum+=(a<8?a:a-16)*(b<8?b:b-16);
                    }
                    return sum;
                };
                for(int h=0;h<2;h++) {
                    std::vector<double> probability(context);double total=0;
                    for(int t=0;t<context;t++) {
                        double b=double(dot(t,0)+16*dot(t,1))*steps[0];
                        double value=h==0?b:shared?b+double(dot(t,2))*steps[1]
                                                 :double(dot(t,2)+16*dot(t,3))*steps[1];
                        probability[t]=std::exp(value*0.08838834765);total+=probability[t];
                    }
                    for(int t=0;t<context;t++) max_error=std::max(max_error,std::abs(probability[t]/total-gpu[h*context+t]));
                }
                if(max_error>3e-6) throw std::runtime_error("native scores disagree with packed-code CPU softmax");
            }
            if(!first)output<<",\n";first=false;
            output<<"{\"context\":"<<context<<",\"round\":"<<round
                  <<",\"arm\":\""<<(shared?"shared_three":"independent_four")
                  <<"\",\"boundary\":\""<<(complete?"append_prepare_score_softmax":"score_softmax")
                  <<"\",\"microseconds\":"<<(ms*1000/24)<<",\"max_cpu_probability_error\":"<<max_error<<"}";
        }
    }
    output<<"\n]}\n";
    H(hipEventDestroy(start));H(hipEventDestroy(end));
    std::cout<<"wrote "<<argv[1]<<"\n";
} catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}
