// Compile the existing, measured spectral consumer verbatim for the paired arm.
// Its main is renamed; the kernel and image parsing remain unchanged.
#define main spectral_probe_main
#include "probe.hip"
#undef main

__global__ void binary_dot(const half* x, const uint8_t* signs, const half* scales,
                           float* y, int n, int k, int batch, bool pre) {
    int row=blockIdx.x*4+threadIdx.x/32, lane=threadIdx.x%32, b=blockIdx.y;
    if(row>=n) return;
    float sum=0;
    for(int i=lane;i<k;i+=32) {
        int sign=(((signs[row*(k/8)+i/8]>>(i&7))&1)<<1)-1;
        float a=pre ? float(x[b*k+i])*float(scales[i]) : ((const float*)x)[b*k+i];
        sum=fmaf(a,float(sign),sum);
    }
    for(int off=16;off;off>>=1) sum+=__shfl_down(sum,off);
    if(!lane) y[b*n+row]=pre ? sum : sum*float(scales[row]);
}

int main(int argc,char**argv) try {
    if(argc!=3) throw std::runtime_error("usage: nano_probe INPUT_DIR OUT.json");
    const std::string d=argv[1]; auto file=[&](const std::string& n){return d+"/"+n+".bin";};
    Buffer x(file("x"),16*1024*2),lc(file("left_codes"),2048*44),ls(file("left_scales"),2048*2),
           rc(file("right_codes"),88*512),rs(file("right_scales"),88*8*2),
           u(file("nano_U"),2048*44),v(file("nano_V"),352*128),
           pre(file("nano_scale_pre"),1024*2),post(file("nano_scale_post"),2048*2),
           intermediate_s(16*88*4),intermediate_n(16*352*4),out(16*2048*4);
    auto reference_s=read(file("reference"),16*2048*4);
    auto reference_n=read(file("nano_reference"),16*2048*4);
    hipEvent_t start,end; H(hipEventCreate(&start)); H(hipEventCreate(&end));
    struct Sample {std::string arm;int batch,round;float us;double self_error,cross_error;};
    std::vector<Sample> samples;
    for(int batch:{1,16}) for(int round=0;round<11;round++) for(int order=0;order<2;order++) {
        bool nano=((round+order)&1);
        auto invoke=[&]() {
            if(nano) {
                binary_dot<<<dim3(88,batch),128>>>((half*)x.ptr,(uint8_t*)v.ptr,(half*)pre.ptr,
                                                  (float*)intermediate_n.ptr,352,1024,batch,true);
                binary_dot<<<dim3(512,batch),128>>>((half*)intermediate_n.ptr,(uint8_t*)u.ptr,(half*)post.ptr,
                                                   (float*)out.ptr,2048,352,batch,false);
            } else {
                packed_dot<<<dim3(22,batch),128>>>((half*)x.ptr,(uint8_t*)rc.ptr,(half*)rs.ptr,
                                                  (float*)intermediate_s.ptr,88,1024,128,batch,0);
                packed_dot<<<dim3(512,batch),128>>>((half*)intermediate_s.ptr,(uint8_t*)lc.ptr,(half*)ls.ptr,
                                                   (float*)out.ptr,2048,88,128,batch,1);
            }
        };
        for(int i=0;i<8;i++) invoke();
        H(hipDeviceSynchronize());
        H(hipEventRecord(start));
        for(int i=0;i<32;i++) invoke();
        H(hipEventRecord(end));H(hipEventSynchronize(end));
        float ms;H(hipEventElapsedTime(&ms,start,end));
        std::vector<float> result(batch*2048);H(hipMemcpy(result.data(),out.ptr,result.size()*4,hipMemcpyDeviceToHost));
        const float* own=(const float*)(nano?reference_n.data():reference_s.data());
        const float* other=(const float*)(nano?reference_s.data():reference_n.data());
        double num=0,den=0,cross=0,cross_den=0;
        for(size_t i=0;i<result.size();i++) {
            double e=result[i]-own[i],d=result[i]-other[i];num+=e*e;den+=double(own[i])*own[i];
            cross+=d*d;cross_den+=double(other[i])*other[i];
        }
        samples.push_back({nano?"nano_admm_binary":"spectral_int4_factors",batch,round,ms*1000/32,num/den,cross/cross_den});
    }
    H(hipEventDestroy(start));H(hipEventDestroy(end));
    hipDeviceProp_t prop;H(hipGetDeviceProperties(&prop,0));
    std::ofstream o(argv[2]);o<<"{\n \"device\": \""<<prop.name<<"\",\n";
    o<<" \"method\": \"paired rotated 11 rounds; HIP event spans 32 host-submitted complete two-stage invocations; 8 complete warmups per arm/round; FP16 input and scales, FP32 intermediates and outputs\",\n";
    o<<" \"samples\": [\n";
    for(size_t i=0;i<samples.size();i++){const auto& s=samples[i];o<<"  {\"arm\": \""<<s.arm<<"\", \"batch\": "<<s.batch<<", \"round\": "<<s.round<<", \"microseconds\": "<<s.us<<", \"relative_squared_error_vs_own_fp32_map\": "<<s.self_error<<", \"relative_squared_error_vs_other_fp32_map\": "<<s.cross_error<<"}"<<(i+1<samples.size()?',':' ')<<'\n';}
    o<<" ]\n}\n";std::cout<<"wrote "<<argv[2]<<" ("<<samples.size()<<" samples)\n";
} catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
