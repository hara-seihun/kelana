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
static void snapshot(std::ofstream& out,alphabet::Cache* c,int mode,int t,int phase) {
  size_t n=sizeof(alphabet::Cache);
  std::vector<unsigned char> bytes(n);
  HIP(hipMemcpy(bytes.data(),c,sizeof(alphabet::Cache),hipMemcpyDeviceToHost));
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
    auto events=read(argv[2]);if(events.size()!=256*4098)throw std::runtime_error("arrival shape");
    const std::string root="../kivi-two-bit-dot-native/";
    auto o=read(root+"original-o.bf16");if(o.size()!=4194304)throw std::runtime_error("O shape");
    std::ofstream snapshots;
    if(pass=="accept") {snapshots.open(argv[3],std::ios::binary|std::ios::trunc);if(!snapshots)throw std::runtime_error("audit output");}
    auto shared_begin=std::chrono::steady_clock::now();
    unsigned char *arrival=nullptr;float *q=nullptr,*part=nullptr,*y=nullptr;unsigned short *weight=nullptr;float* table=nullptr;
    HIP(hipMalloc(&arrival,4096));HIP(hipMalloc(&q,8192));HIP(hipMalloc(&part,32768));
    HIP(hipMalloc(&y,4096));HIP(hipMalloc(&weight,4194304));
    HIP(hipMemcpy(weight,o.data(),o.size(),hipMemcpyHostToDevice));
    auto table_bytes=read("../kivi-value-alphabet/layer0-alphabet.f32");
    if(table_bytes.size()!=16)throw std::runtime_error("alphabet shape");
    hipEvent_t start,input,end;HIP(hipEventCreate(&start));HIP(hipEventCreate(&input));HIP(hipEventCreate(&end));
    printf("{\"kind\":\"shared_setup\",\"wall_us\":%.9g,\"original_o_h2d_bytes\":4194304,\"allocated_bytes\":4243456}\n",
      std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-shared_begin).count());fflush(stdout);
    int window=tag.back()-'0';
    if(tag!="held-"+std::to_string(window)||window<0||window>3)throw std::runtime_error("window name");
    for(int round=0;round<(pass=="timing"?4:1);round++) for(int order=0;order<2;order++) {
      int first=pass=="timing"?(window+round)%2:0;
      int mode=order?1-first:first;
      auto arm_begin=std::chrono::steady_clock::now();
      alphabet::Cache* c=nullptr;
      HIP(hipMalloc(&c,sizeof(alphabet::Cache)));HIP(hipMemset(c,0,sizeof(alphabet::Cache)));
      if(mode){HIP(hipMalloc(&table,16));HIP(hipMemcpy(table,table_bytes.data(),16,hipMemcpyHostToDevice));}
      auto allocated=std::chrono::steady_clock::now();
      for(int t=1;t<=256;t++) {
        const unsigned char* event=events.data()+(t-1)*4098;
        if(int(event[0])+(int(event[1])<<8)!=t)throw std::runtime_error("arrival chronology");
        bool measured=t==128||t==256;
        std::vector<unsigned char> qbytes,expected;
        if(measured){
          auto prefix=root+tag+"-t"+std::to_string(t);
          qbytes=read(prefix+"-q.f32");
          expected=read(mode?tag+"-t"+std::to_string(t)+"-alphabet-cpu.f32":prefix+"-conventional-cpu.f32");
          if(qbytes.size()!=8192||expected.size()!=4096)throw std::runtime_error("Q/reference shape");
        }
        auto wall=std::chrono::steady_clock::now();
        HIP(hipEventRecord(start));
        HIP(hipMemcpy(arrival,event+2,4096,hipMemcpyHostToDevice));
        if(measured)HIP(hipMemcpy(q,qbytes.data(),8192,hipMemcpyHostToDevice));
        HIP(hipEventRecord(input));
        alphabet::append_key<<<8,128>>>(c,arrival,t);
        alphabet::append_recent<<<8,128>>>(c,arrival,t);
        HIP(hipGetLastError());
        if(pass=="accept")snapshot(snapshots,c,mode,t,0);
        if(measured){
          if(mode)launch_candidate(c,table,t,q,weight,part,y);
          else launch_control(c,table,t,q,weight,part,y);
          HIP(hipGetLastError());
        }
        if(t%32==0)alphabet::flush_key<<<8,128>>>(c,t);
        if(t>=33)alphabet::flush_value<<<8,128>>>(c,table,t,mode);
        HIP(hipGetLastError());HIP(hipEventRecord(end));HIP(hipEventSynchronize(end));
        int error=0;HIP(hipMemcpy(&error,reinterpret_cast<char*>(c)+offsetof(alphabet::Cache,error),4,hipMemcpyDeviceToHost));
        if(error)throw std::runtime_error("transition error mode="+std::to_string(mode)+" t="+std::to_string(t)+" code="+std::to_string(error));
        if(pass=="accept")snapshot(snapshots,c,mode,t,1);
        if(measured){
          std::vector<float> result(1024);HIP(hipMemcpy(result.data(),y,4096,hipMemcpyDeviceToHost));
          {
            std::string output_path=tag+"-t"+std::to_string(t)+"-mode"+std::to_string(mode);
            if(pass=="timing")output_path+="-round"+std::to_string(round);
            std::ofstream actual(output_path+"-actual.f32",std::ios::binary);
            actual.write(reinterpret_cast<const char*>(result.data()),4096);
            if(!actual)throw std::runtime_error("actual output write");
          }
          std::vector<float> reference_values(1024);std::memcpy(reference_values.data(),expected.data(),4096);
          double maxabs=0,sse=0,den=0;
          for(int i=0;i<1024;i++) {
            if(!std::isfinite(result[i])||!std::isfinite(reference_values[i]))throw std::runtime_error("nonfinite output");
            double diff=double(result[i])-double(reference_values[i]);maxabs=std::max(maxabs,std::abs(diff));sse+=diff*diff;den+=double(reference_values[i])*reference_values[i];
          }
          float total=0,transfer=0,compute=0;
          HIP(hipEventElapsedTime(&total,start,end));HIP(hipEventElapsedTime(&transfer,start,input));HIP(hipEventElapsedTime(&compute,input,end));
          printf("{\"kind\":\"step\",\"pass\":\"%s\",\"mode\":%d,\"window\":\"%s\",\"round\":%d,\"order\":%d,\"t\":%d,\"max_abs\":%.9g,\"relative_l2\":%.9g,\"step_event_us\":%.9g,\"input_span_us\":%.9g,\"compute_span_us\":%.9g,\"step_wall_us\":%.9g}\n",
            pass.c_str(),mode,tag.c_str(),round,order,t,maxabs,std::sqrt(sse/den),total*1000,transfer*1000,compute*1000,std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-wall).count());fflush(stdout);
          if(maxabs>.005||std::sqrt(sse/den)>.005)throw std::runtime_error("full-output guard mode="+std::to_string(mode));
        }
      }
      auto replay_end=std::chrono::steady_clock::now();
      HIP(hipFree(c));if(mode){HIP(hipFree(table));table=nullptr;}
      printf("{\"kind\":\"lifecycle\",\"pass\":\"%s\",\"mode\":%d,\"window\":\"%s\",\"round\":%d,\"order\":%d,\"arm_allocation_us\":%.9g,\"replay_256_wall_us\":%.9g,\"arm_teardown_us\":%.9g,\"arm_total_wall_us\":%.9g,\"arm_allocated_bytes\":%zu,\"arrival_h2d_bytes\":1048576,\"query_h2d_bytes\":16384}\n",
        pass.c_str(),mode,tag.c_str(),round,order,
        std::chrono::duration<double,std::micro>(allocated-arm_begin).count(),
        std::chrono::duration<double,std::micro>(replay_end-allocated).count(),
        std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-replay_end).count(),
        std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-arm_begin).count(),
        sizeof(alphabet::Cache)+(mode?16:0));fflush(stdout);
    }
    auto shared_teardown_begin=std::chrono::steady_clock::now();
    HIP(hipEventDestroy(start));HIP(hipEventDestroy(input));HIP(hipEventDestroy(end));
    HIP(hipFree(arrival));HIP(hipFree(q));HIP(hipFree(part));HIP(hipFree(y));HIP(hipFree(weight));
    printf("{\"kind\":\"shared_teardown\",\"wall_us\":%.9g}\n",
      std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-shared_teardown_begin).count());fflush(stdout);
    return 0;
  } catch(const std::exception& ex){fprintf(stderr,"alphabet-native: %s\n",ex.what());return 1;}
}
