#include "reader.hip"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
#define HIP(call) do {hipError_t e=(call);if(e!=hipSuccess)throw std::runtime_error(std::string(#call)+": "+hipGetErrorString(e));} while(0)
static std::vector<unsigned char> read(const std::string& name) {
  std::ifstream f(name,std::ios::binary);if(!f)throw std::runtime_error("missing "+name);
  return {std::istreambuf_iterator<char>(f),{}};
}
static void snapshot(std::ofstream& out,void* d,size_t n,int mode,int t,int phase) {
  std::vector<unsigned char> bytes(n);HIP(hipMemcpy(bytes.data(),d,n,hipMemcpyDeviceToHost));
  unsigned char head[8]={static_cast<unsigned char>(mode),static_cast<unsigned char>(phase),
    static_cast<unsigned char>(t),static_cast<unsigned char>(t>>8),
    static_cast<unsigned char>(n),static_cast<unsigned char>(n>>8),static_cast<unsigned char>(n>>16),static_cast<unsigned char>(n>>24)};
  out.write(reinterpret_cast<const char*>(head),8);out.write(reinterpret_cast<const char*>(bytes.data()),n);
  if(!out)throw std::runtime_error("audit snapshot write");
}
int main(int argc,char** argv) {
  try {
    if(argc!=5)throw std::runtime_error("usage: native held-N ARRIVALS.bin SNAPSHOTS.bin accept|timing");
    std::string tag=argv[1],pass=argv[4];
    if(pass!="accept"&&pass!="timing")throw std::runtime_error("pass");
    if(pass=="timing"&&!std::ifstream("acceptance.ready"))throw std::runtime_error("acceptance gate missing");
    auto events=read(argv[2]);if(events.size()!=256*4098)throw std::runtime_error("arrival shape");
    const std::string root="../kivi-two-bit-dot-native/";
    auto o=read(root+"original-o.bf16");if(o.size()!=4194304)throw std::runtime_error("O shape");
    std::ofstream snapshots;
    if(pass=="accept") {snapshots.open(argv[3],std::ios::binary|std::ios::trunc);if(!snapshots)throw std::runtime_error("audit output");}
    unsigned char *arrival=nullptr;float *q=nullptr,*part=nullptr,*y=nullptr;unsigned short *weight=nullptr;
    HIP(hipMalloc(&arrival,4096));HIP(hipMalloc(&q,8192));HIP(hipMalloc(&part,32768));
    HIP(hipMalloc(&y,4096));HIP(hipMalloc(&weight,4194304));
    HIP(hipMemcpy(weight,o.data(),o.size(),hipMemcpyHostToDevice));
    hipEvent_t start,input,end;HIP(hipEventCreate(&start));HIP(hipEventCreate(&input));HIP(hipEventCreate(&end));
    for(int mode=0;mode<2;mode++) {
      stable::Cache* s=nullptr;stable::Control* c=nullptr;stable::Scratch* work=nullptr;
      if(mode){HIP(hipMalloc(&s,sizeof(stable::Cache)));HIP(hipMemset(s,0,sizeof(stable::Cache)));}
      else {HIP(hipMalloc(&c,sizeof(stable::Control)));HIP(hipMemset(c,0,sizeof(stable::Control)));}
      HIP(hipMalloc(&work,sizeof(stable::Scratch)));
      if(mode) {
        // The empty cache is post-flush at t=0.
        stable::Cache init{};init.phase=1;HIP(hipMemcpy(s,&init,sizeof(init),hipMemcpyHostToDevice));
      }
      for(int t=1;t<=256;t++) {
        const unsigned char* event=events.data()+(t-1)*4098;
        if(int(event[0])+(int(event[1])<<8)!=t)throw std::runtime_error("arrival chronology");
        bool measured=t==128||t==256;
        std::vector<unsigned char> qbytes,expected;
        if(measured){
          auto prefix=root+tag+"-t"+std::to_string(t);
          qbytes=read(prefix+"-q.f32");expected=read(prefix+"-conventional-cpu.f32");
          if(qbytes.size()!=8192||expected.size()!=4096)throw std::runtime_error("Q/reference shape");
        }
        auto wall=std::chrono::steady_clock::now();
        HIP(hipEventRecord(start));
        HIP(hipMemcpy(arrival,event+2,4096,hipMemcpyHostToDevice));
        if(measured)HIP(hipMemcpy(q,qbytes.data(),8192,hipMemcpyHostToDevice));
        HIP(hipEventRecord(input));
        stable::append_key<<<8,128>>>(s,c,arrival,t,mode);
        stable::append_recent<<<mode?1:8,128>>>(s,c,arrival,t,mode);
        HIP(hipGetLastError());
        if(pass=="accept")snapshot(snapshots,mode?static_cast<void*>(s):static_cast<void*>(c),mode?sizeof(*s):sizeof(*c),mode,t,0);
        if(measured){if(mode)launch_stable(s,c,t,q,weight,part,y);else launch_control(s,c,t,q,weight,part,y);HIP(hipGetLastError());}
        if(t%32==0)stable::flush_key<<<8,128>>>(s,c,t,mode);
        if(t>=33){stable::flush_value<<<8,128>>>(s,c,work,t,mode);if(mode)stable::finish_value<<<1,128>>>(s,work,t);}
        else if(mode)stable::finish_early<<<1,1>>>(s,t);
        HIP(hipGetLastError());HIP(hipEventRecord(end));HIP(hipEventSynchronize(end));
        auto finish=std::chrono::steady_clock::now();
        int error=0;
        if(mode)HIP(hipMemcpy(&error,reinterpret_cast<char*>(s)+offsetof(stable::Cache,error),4,hipMemcpyDeviceToHost));
        else HIP(hipMemcpy(&error,reinterpret_cast<char*>(c)+offsetof(stable::Control,error),4,hipMemcpyDeviceToHost));
        if(error)throw std::runtime_error("transition error mode="+std::to_string(mode)+" t="+std::to_string(t)+" code="+std::to_string(error));
        if(pass=="accept")snapshot(snapshots,mode?static_cast<void*>(s):static_cast<void*>(c),mode?sizeof(*s):sizeof(*c),mode,t,1);
        if(measured){
          std::vector<float> result(1024);HIP(hipMemcpy(result.data(),y,4096,hipMemcpyDeviceToHost));
          if(pass=="accept") {
            std::ofstream actual(tag+"-t"+std::to_string(t)+"-mode"+std::to_string(mode)+"-actual.f32",std::ios::binary);
            actual.write(reinterpret_cast<const char*>(result.data()),4096);
            if(!actual)throw std::runtime_error("actual output write");
          }
          std::vector<float> reference_values(1024);
          std::memcpy(reference_values.data(),expected.data(),4096);
          const float* ref=reference_values.data();
          double maxabs=0,sse=0,den=0;
          for(int i=0;i<1024;i++) {
            if(!std::isfinite(result[i])||!std::isfinite(ref[i]))throw std::runtime_error("nonfinite output");
            double diff=double(result[i])-double(ref[i]);maxabs=std::max(maxabs,std::abs(diff));sse+=diff*diff;den+=double(ref[i])*ref[i];
          }
          if(!(den>0)||!std::isfinite(den)||!std::isfinite(sse))throw std::runtime_error("invalid reference/error norm");
          float total=0,transfer=0,compute=0;
          HIP(hipEventElapsedTime(&total,start,end));HIP(hipEventElapsedTime(&transfer,start,input));HIP(hipEventElapsedTime(&compute,input,end));
          printf("{\"pass\":\"%s\",\"mode\":%d,\"window\":\"%s\",\"t\":%d,\"max_abs\":%.9g,\"relative_l2\":%.9g,\"step_event_us\":%.9g,\"input_span_us\":%.9g,\"compute_span_us\":%.9g,\"step_wall_us\":%.9g}\n",
            pass.c_str(),mode,tag.c_str(),t,maxabs,std::sqrt(sse/den),total*1000,transfer*1000,compute*1000,std::chrono::duration<double,std::micro>(finish-wall).count());fflush(stdout);
          if(maxabs>.005||std::sqrt(sse/den)>.005)throw std::runtime_error("full-output guard");
        }
      }
      HIP(hipFree(work));if(mode)HIP(hipFree(s));else HIP(hipFree(c));
    }
    HIP(hipEventDestroy(start));HIP(hipEventDestroy(input));HIP(hipEventDestroy(end));
    HIP(hipFree(arrival));HIP(hipFree(q));HIP(hipFree(part));HIP(hipFree(y));HIP(hipFree(weight));
    return 0;
  } catch(const std::exception& ex){fprintf(stderr,"stable-resident: %s\n",ex.what());return 1;}
}
