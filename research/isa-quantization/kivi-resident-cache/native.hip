#include "state.hip"
#include "grouped-generated.hip"
#define query_group conventional_query_group
#define finish_o conventional_finish_o
#define bf16 conventional_bf16
#define code2 conventional_code2
#include "control-generated.hip"
#undef query_group
#undef finish_o
#undef bf16
#undef code2
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
#define HIP(call) do { hipError_t s=(call);if(s!=hipSuccess)throw std::runtime_error(std::string(#call)+": "+hipGetErrorString(s)); } while(0)
static std::vector<unsigned char> read(const std::string& path) {
  std::ifstream f(path,std::ios::binary);if(!f)throw std::runtime_error("missing "+path);
  return {std::istreambuf_iterator<char>(f),{}};
}
static void put(std::ofstream& f,const void* p,size_t n){f.write(reinterpret_cast<const char*>(p),n);if(!f)throw std::runtime_error("snapshot write");}
static void snapshot(std::ofstream& f,int mode,int t,int phase,unsigned char* cache,int n) {
  std::vector<unsigned char> bytes(n);
  if(mode)HIP(hipMemcpy(bytes.data(),cache,n,hipMemcpyDeviceToHost));
  else {
    if(n%8)throw std::runtime_error("control snapshot shape");
    const int used=n/8;
    for(int h=0;h<8;h++)HIP(hipMemcpy(bytes.data()+h*used,cache+h*38096,used,hipMemcpyDeviceToHost));
  }
  unsigned char header[8]={static_cast<unsigned char>(mode),static_cast<unsigned char>(phase),
    static_cast<unsigned char>(t),static_cast<unsigned char>(t>>8),
    static_cast<unsigned char>(n),static_cast<unsigned char>(n>>8),static_cast<unsigned char>(n>>16),static_cast<unsigned char>(n>>24)};
  put(f,header,8);put(f,bytes.data(),bytes.size());
}
static int dict_size(int t,int phase,const std::vector<unsigned char>& bytes) {
  int chunks=phase?t/32:(t-1)/32;
  int recent=t-32*chunks,quant=t>(phase?32:33)?t-(phase?32:33):0;
  return 5+8*(chunks*1536+recent*256)+bytes[3]*384+quant+bytes[4]*2048+t-quant;
}
int main(int argc,char**argv) {
  try {
    if(argc!=5)throw std::runtime_error("usage: native held-N EVENTS.bin SNAPSHOTS.bin accept|timing");
    std::string tag=argv[1],events=argv[2],out=argv[3];
    int pass=std::string(argv[4])=="accept"?0:std::string(argv[4])=="timing"?1:-1;
    if(pass<0)throw std::runtime_error("unknown pass");
    if(pass && !std::ifstream("acceptance.ready"))throw std::runtime_error("run-stage.sh acceptance gate is required before timing");
    auto arrivals=read(events);
    if(arrivals.size()!=256*4098)throw std::runtime_error("arrival stream size");
    const std::string reference="../kivi-two-bit-dot-native/";
    auto original_o=read(reference+"original-o.bf16");
    if(original_o.size()!=4194304)throw std::runtime_error("O size");
    std::ofstream record;
    if(!pass){record.open(out,std::ios::binary|std::ios::trunc);if(!record)throw std::runtime_error("snapshot output");}
    unsigned char *d_cache=nullptr,*d_work=nullptr,*d_arrival=nullptr;
    unsigned short *d_o=nullptr;float *d_q=nullptr,*d_partial=nullptr,*d_y=nullptr;
    int *d_error=nullptr;
    const unsigned char**d_addresses=nullptr;
    HIP(hipMalloc(&d_arrival,4096));HIP(hipMalloc(&d_o,original_o.size()));
    HIP(hipMalloc(&d_q,8192));HIP(hipMalloc(&d_partial,32768));HIP(hipMalloc(&d_y,4096));
    HIP(hipMalloc(&d_error,4));
    HIP(hipMemcpy(d_o,original_o.data(),original_o.size(),hipMemcpyHostToDevice));
    hipEvent_t start,ready,end;HIP(hipEventCreate(&start));HIP(hipEventCreate(&ready));HIP(hipEventCreate(&end));
    for(int mode=0;mode<2;mode++) {
      if(d_cache)HIP(hipFree(d_cache));if(d_work)HIP(hipFree(d_work));
      if(d_addresses){HIP(hipFree(d_addresses));d_addresses=nullptr;}
      HIP(hipMalloc(&d_cache,mode?resident::DICT_CAP:resident::CONTROL_CAP));
      HIP(hipMalloc(&d_work,mode?resident::WORK_CAP:resident::CONTROL_WORK));
      HIP(hipMemset(d_cache,0,mode?resident::DICT_CAP:resident::CONTROL_CAP));HIP(hipMemset(d_error,0,4));
      if(mode==1){const unsigned char empty[5]={0,0,1,0,0};HIP(hipMemcpy(d_cache,empty,5,hipMemcpyHostToDevice));}
      else {
        HIP(hipMalloc(&d_addresses,64));
        const unsigned char* addresses[8];
        for(int h=0;h<8;h++)addresses[h]=d_cache+h*38096;
        HIP(hipMemcpy(d_addresses,addresses,64,hipMemcpyHostToDevice));
      }
      HIP(hipDeviceSynchronize());
      for(int t=1;t<=256;t++) {
        const unsigned char* event=arrivals.data()+(t-1)*4098;
        if(event[0]!=(t&255)||event[1]!=(t>>8))throw std::runtime_error("arrival chronology");
        int measured=(t==128||t==256),nchunks=(t-1)/32,quant=t>33?t-33:0;
        std::vector<unsigned char> qbytes;
        std::vector<unsigned char> expected;
        if(measured) {
          std::string input=reference+tag+"-t"+std::to_string(t);
          qbytes=read(input+"-q.f32");expected=read(input+"-conventional-cpu.f32");
          if(qbytes.size()!=8192||expected.size()!=4096)throw std::runtime_error("Q/output shape");
        }
        auto wall=std::chrono::steady_clock::now();
        HIP(hipEventRecord(start));
        HIP(hipMemcpy(d_arrival,event+2,4096,hipMemcpyHostToDevice));
        if(measured)HIP(hipMemcpy(d_q,qbytes.data(),8192,hipMemcpyHostToDevice));
        HIP(hipEventRecord(ready));
        if(mode)resident::append_dictionary<<<1,1>>>(d_cache,d_work,d_arrival,t,d_error);
        else resident::append_control<<<1,1>>>(d_cache,d_work,d_arrival,t,d_error);
        HIP(hipGetLastError());
        if(!pass) {
          int pre=0;
          if(mode) {
            unsigned char header[5];HIP(hipMemcpy(header,d_cache,5,hipMemcpyDeviceToHost));
            pre=dict_size(t,0,std::vector<unsigned char>(header,header+5));
          } else pre=8*(nchunks*1536+quant*48+(t-nchunks*32)*256+(t-quant)*256);
          snapshot(record,mode,t,0,d_cache,pre);
        }
        if(measured) {
          if(mode)launch_grouped(d_cache,d_q,d_o,d_partial,d_y);
          else launch_conventional(d_addresses,d_q,d_o,d_partial,d_y,nchunks,quant,t-nchunks*32,t-quant);
          HIP(hipGetLastError());
        }
        if(mode)resident::flush_dictionary<<<1,1>>>(d_cache,d_work,d_error);
        else resident::flush_control<<<1,1>>>(d_cache,d_work,t,d_error);
        HIP(hipGetLastError());HIP(hipEventRecord(end));HIP(hipEventSynchronize(end));
        auto done=std::chrono::steady_clock::now();
        int err=0;HIP(hipMemcpy(&err,d_error,4,hipMemcpyDeviceToHost));
        if(err)throw std::runtime_error("device transition failure mode="+std::to_string(mode)+" t="+std::to_string(t)+" code="+std::to_string(err));
        // Full pre-query state is retained by an audit probe separately below; post is copied here.
        int post=0;
        if(mode) {
          unsigned char header[5];HIP(hipMemcpy(header,d_cache,5,hipMemcpyDeviceToHost));
          post=5+8*((t/32)*1536+(t%32)*256)+header[3]*384+(t>32?t-32:0)+header[4]*2048+(t<32?t:32);
        } else post=8*((t/32)*1536+(t>32?t-32:0)*48+(t%32)*256+(t<32?t:32)*256);
        if(!pass)snapshot(record,mode,t,1,d_cache,post);
        if(measured) {
          std::vector<float> y(1024);HIP(hipMemcpy(y.data(),d_y,4096,hipMemcpyDeviceToHost));
          if(!pass){
            std::ofstream actual(tag+"-t"+std::to_string(t)+"-mode"+std::to_string(mode)+"-actual.f32",std::ios::binary);
            put(actual,y.data(),4096);
          }
          std::vector<float> reference_values(1024);
          std::memcpy(reference_values.data(),expected.data(),4096);
          const float* ref=reference_values.data();
          double sse=0,den=0,mx=0;
          for(int i=0;i<1024;i++){
            if(!std::isfinite(y[i])||!std::isfinite(ref[i]))throw std::runtime_error("nonfinite output or target");
            double a=double(y[i])-double(ref[i]);sse+=a*a;den+=double(ref[i])*ref[i];mx=std::max(mx,std::abs(a));
          }
          if(!(den>0)||!std::isfinite(den)||!std::isfinite(sse))throw std::runtime_error("invalid output norm");
          double rel=std::sqrt(sse/den);
          float ms=0,transfer=0,compute=0;
          HIP(hipEventElapsedTime(&ms,start,end));HIP(hipEventElapsedTime(&transfer,start,ready));HIP(hipEventElapsedTime(&compute,ready,end));
          printf("{\"pass\":\"%s\",\"mode\":%d,\"window\":\"%s\",\"t\":%d,\"max_abs\":%.9g,\"relative_l2\":%.9g,\"step_event_us\":%.9g,\"input_span_us\":%.9g,\"compute_span_us\":%.9g,\"step_wall_us\":%.9g}\n",
            pass?"timing":"acceptance",mode,tag.c_str(),t,mx,rel,ms*1000.,transfer*1000.,compute*1000.,std::chrono::duration<double,std::micro>(done-wall).count());fflush(stdout);
          if(!(mx<=.005&&rel<=.005))throw std::runtime_error("frozen output correspondence FAILED");
        }
      }
    }
    HIP(hipEventDestroy(start));HIP(hipEventDestroy(ready));HIP(hipEventDestroy(end));
    if(d_addresses)HIP(hipFree(d_addresses));HIP(hipFree(d_error));HIP(hipFree(d_y));HIP(hipFree(d_partial));
    HIP(hipFree(d_q));HIP(hipFree(d_o));HIP(hipFree(d_arrival));HIP(hipFree(d_work));HIP(hipFree(d_cache));
    return 0;
  } catch(const std::exception& e){fprintf(stderr,"resident: %s\n",e.what());return 1;}
}
