// Foreground native acceptance/timing for frozen adjacent query kernels; no kernel edits.
#include "../kivi-two-bit-dot-query/consumer.hip"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
#define CHECK(x) do{auto status=(x);if(status!=hipSuccess){fprintf(stderr,"HIP %s:%d %s\n",__FILE__,__LINE__,hipGetErrorString(status));return 1;}}while(0)

std::vector<unsigned char> read_bytes(const std::string&file) {
  std::ifstream f(file,std::ios::binary);
  if(!f)throw std::runtime_error("missing "+file);
  return {std::istreambuf_iterator<char>(f),{}};
}
std::vector<float> read_float(const std::string&file,size_t count) {
  auto b=read_bytes(file);if(b.size()!=count*4)throw std::runtime_error("bad size "+file);
  std::vector<float> v(count);std::memcpy(v.data(),b.data(),b.size());return v;
}
int main(int argc,char**argv) {
  if(argc!=2){fprintf(stderr,"usage: native PREPARED_DIRECTORY\n");return 2;}
  const std::string base=argv[1];
  auto original_o=read_bytes(base+"/original-o.bf16");
  if(original_o.size()!=1024*2048*2)throw std::runtime_error("original O shape");
  unsigned short *d_o=nullptr;float *d_q=nullptr,*d_partial=nullptr,*d_output=nullptr;
  unsigned char *d_state[8]={};const unsigned char **d_addresses=nullptr;
  CHECK(hipMalloc(&d_o,original_o.size()));CHECK(hipMemcpy(d_o,original_o.data(),original_o.size(),hipMemcpyHostToDevice));
  CHECK(hipMalloc(&d_q,16*128*4));CHECK(hipMalloc(&d_partial,8*1024*4));
  CHECK(hipMalloc(&d_output,1024*4));
  for(int h=0;h<8;h++)CHECK(hipMalloc(&d_state[h],38096));
  CHECK(hipMalloc(&d_addresses,8*sizeof(unsigned char*)));
  CHECK(hipMemcpy(d_addresses,d_state,8*sizeof(unsigned char*),hipMemcpyHostToDevice));
  hipEvent_t start,finish;CHECK(hipEventCreate(&start));CHECK(hipEventCreate(&finish));
  auto launch=[&](int mode,int nchunk,int nv){
    if(mode==0)launch_conventional(d_addresses,d_q,d_o,d_partial,d_output,nchunk,nv,32,33);
    else launch_byte_dot(d_addresses,d_q,d_o,d_partial,d_output,nchunk,nv,32,33);
  };
  for(int phase=0;phase<2;phase++) for(int idx=0;idx<8;idx++) {
    int window=idx/2,t=(idx%2)?256:128;
    int nchunk=t/32-1,nv=t-33;
    std::string tag=base+"/held-"+std::to_string(window)+"-t"+std::to_string(t);
    for(int h=0;h<8;h++) {
      auto state=read_bytes(tag+"-kv"+std::to_string(h)+".bin");
      if(state.size()!=(t==128?25808:38096))throw std::runtime_error("cache size "+tag);
      CHECK(hipMemcpy(d_state[h],state.data(),state.size(),hipMemcpyHostToDevice));
    }
    auto query=read_float(tag+"-q.f32",16*128);
    CHECK(hipMemcpy(d_q,query.data(),query.size()*4,hipMemcpyHostToDevice));
    auto teacher=read_float(tag+"-teacher.f32",1024);
    if(phase==0) {
    for(int mode=0;mode<2;mode++) {
      auto expected=read_float(tag+(mode?"-byte-cpu.f32":"-conventional-cpu.f32"),1024);
      launch(mode,nchunk,nv);CHECK(hipGetLastError());CHECK(hipDeviceSynchronize());
      std::vector<float> actual(1024);
      CHECK(hipMemcpy(actual.data(),d_output,actual.size()*4,hipMemcpyDeviceToHost));
      double max_abs=0,sse=0,den=0,vs_teacher=0,teacher_sq=0;
      for(int i=0;i<1024;i++) {
        if(!std::isfinite(actual[i]) || !std::isfinite(expected[i]) || !std::isfinite(teacher[i])) {
          fprintf(stderr,"nonfinite numerical value window=%d t=%d mode=%d coordinate=%d\n",window,t,mode,i);
          return 1;
        }
        double e=(double)actual[i]-(double)expected[i];max_abs=std::max(max_abs,std::abs(e));sse+=e*e;den+=(double)expected[i]*expected[i];
        double d=(double)actual[i]-(double)teacher[i];vs_teacher+=d*d;teacher_sq+=(double)teacher[i]*teacher[i];
      }
      if(!(den>0) || !(teacher_sq>0) || !std::isfinite(sse) || !std::isfinite(vs_teacher)) {
        fprintf(stderr,"invalid numerical norm window=%d t=%d mode=%d\n",window,t,mode);
        return 1;
      }
      double relative_l2=std::sqrt(sse/den);
      printf("{\"type\":\"numerical\",\"window\":%d,\"t\":%d,\"mode\":%d,\"max_abs\":%.10g,\"relative_l2\":%.10g,\"native_vs_teacher_rel_sq\":%.10g}\n",window,t,mode,max_abs,relative_l2,vs_teacher/teacher_sq);
      fflush(stdout);
      // Guard fixed before any native launch: fail without timing on either mode.
      if(max_abs>0.005 || relative_l2>0.005) {
        fprintf(stderr,"native numerical contract FAILED window=%d t=%d mode=%d max=%.9g relL2=%.9g\n",window,t,mode,max_abs,relative_l2);
        return 1;
      }
    }
    continue;
    }
    // Every state and arm passes phase zero before any timing begins.
    // Small fixed common warmup; no work padding inside the timed kernels.
    for(int n=0;n<4;n++)for(int mode=0;mode<2;mode++)launch(mode,nchunk,nv);
    CHECK(hipGetLastError());CHECK(hipDeviceSynchronize());
    for(int round=0;round<4;round++)for(int order=0;order<2;order++) {
      int mode=(idx+round+order)&1;
      auto wall_start=std::chrono::steady_clock::now();
      CHECK(hipEventRecord(start));
      launch(mode,nchunk,nv);
      CHECK(hipGetLastError());CHECK(hipEventRecord(finish));CHECK(hipEventSynchronize(finish));
      auto wall_end=std::chrono::steady_clock::now();
      float ms=0;CHECK(hipEventElapsedTime(&ms,start,finish));
      double wall_us=std::chrono::duration<double,std::micro>(wall_end-wall_start).count();
      printf("{\"type\":\"sample\",\"window\":%d,\"t\":%d,\"round\":%d,\"order\":%d,\"mode\":%d,\"event_us\":%.9g,\"wall_us\":%.9g}\n",window,t,round,order,mode,ms*1000.,wall_us);
    }
    fflush(stdout);
  }
  CHECK(hipEventDestroy(start));CHECK(hipEventDestroy(finish));
  CHECK(hipFree(d_addresses));for(auto p:d_state)CHECK(hipFree(p));
  CHECK(hipFree(d_q));CHECK(hipFree(d_o));CHECK(hipFree(d_partial));CHECK(hipFree(d_output));
  return 0;
}
