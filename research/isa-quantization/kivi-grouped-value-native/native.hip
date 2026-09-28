// Three frozen full-O readers in separate source units, no device-kernel edits.
#include <hip/hip_runtime.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
extern "C" void launch_original(const unsigned char *const*,const float*,const unsigned short*,float*,float*,int,int,int,int);
extern "C" void launch_direct(const unsigned char*,const float*,const unsigned short*,float*,float*);
extern "C" void launch_grouped(const unsigned char*,const float*,const unsigned short*,float*,float*);
#define CHECK(x) do { auto status=(x); if(status!=hipSuccess){fprintf(stderr,"HIP %s:%d %s\n",__FILE__,__LINE__,hipGetErrorString(status));return 1;} }while(0)
std::vector<unsigned char> bytes(const std::string&file){std::ifstream f(file,std::ios::binary);if(!f)throw std::runtime_error("missing "+file);return {std::istreambuf_iterator<char>(f),{}};}
std::vector<float> floats(const std::string&file,size_t n){auto b=bytes(file);if(b.size()!=n*4)throw std::runtime_error("bad size "+file);std::vector<float> v(n);std::memcpy(v.data(),b.data(),b.size());return v;}
int main(int argc,char**argv){
  if(argc!=3){fprintf(stderr,"usage: native PREPARED_DIR ORIGINAL_DIR\n");return 2;}
  std::string base=argv[1],orig=argv[2];auto O=bytes(orig+"/original-o.bf16");
  if(O.size()!=4194304)throw std::runtime_error("O shape");
  unsigned short *d_o=nullptr;float *d_q=nullptr,*d_partial=nullptr,*d_output=nullptr;
  unsigned char *d_state[8]={},*d_image=nullptr;const unsigned char **d_addresses=nullptr;
  CHECK(hipMalloc(&d_o,O.size()));CHECK(hipMemcpy(d_o,O.data(),O.size(),hipMemcpyHostToDevice));
  CHECK(hipMalloc(&d_q,8192));CHECK(hipMalloc(&d_partial,32768));CHECK(hipMalloc(&d_output,4096));
  for(auto &p:d_state)CHECK(hipMalloc(&p,38096));
  CHECK(hipMalloc(&d_addresses,64));CHECK(hipMemcpy(d_addresses,d_state,64,hipMemcpyHostToDevice));
  CHECK(hipMalloc(&d_image,263429));
  hipEvent_t start,finish;CHECK(hipEventCreate(&start));CHECK(hipEventCreate(&finish));
  auto launch=[&](int mode,int chunks,int nv){
    if(mode==0)launch_original(d_addresses,d_q,d_o,d_partial,d_output,chunks,nv,32,33);
    else if(mode==1)launch_direct(d_image,d_q,d_o,d_partial,d_output);
    else launch_grouped(d_image,d_q,d_o,d_partial,d_output);
  };
  for(int phase=0;phase<2;phase++)for(int idx=0;idx<8;idx++){
    int window=idx/2,t=idx%2?256:128,chunks=t/32-1,nv=t-33;
    std::string tag="held-"+std::to_string(window)+"-t"+std::to_string(t);
    auto image=bytes(base+"/"+tag+"-image.bin");if(image.size()>263429||image.size()<5)throw std::runtime_error("image shape");
    CHECK(hipMemcpy(d_image,image.data(),image.size(),hipMemcpyHostToDevice));
    for(int h=0;h<8;h++){auto state=bytes(orig+"/"+tag+"-kv"+std::to_string(h)+".bin");if(state.size()!=(t==128?25808:38096))throw std::runtime_error("state shape");CHECK(hipMemcpy(d_state[h],state.data(),state.size(),hipMemcpyHostToDevice));}
    auto q=floats(orig+"/"+tag+"-q.f32",2048);CHECK(hipMemcpy(d_q,q.data(),8192,hipMemcpyHostToDevice));
    if(phase==0){
      for(int mode=0;mode<3;mode++){
        auto expected=floats((mode==0?orig:base)+"/"+tag+(mode==0?"-conventional-cpu.f32":(mode==1?"-direct-cpu.f32":"-grouped-cpu.f32")),1024);
        launch(mode,chunks,nv);CHECK(hipGetLastError());CHECK(hipDeviceSynchronize());
        std::vector<float> actual(1024);CHECK(hipMemcpy(actual.data(),d_output,4096,hipMemcpyDeviceToHost));
        double maximum=0,sse=0,den=0;
        for(int i=0;i<1024;i++){
          if(!std::isfinite(actual[i])||!std::isfinite(expected[i])){fprintf(stderr,"nonfinite window=%d t=%d mode=%d coordinate=%d\n",window,t,mode,i);return 1;}
          double e=double(actual[i])-expected[i];maximum=std::max(maximum,std::abs(e));sse+=e*e;den+=double(expected[i])*expected[i];
        }
        if(!(den>0)||!std::isfinite(den)||!std::isfinite(sse)){fprintf(stderr,"invalid denominator window=%d t=%d mode=%d\n",window,t,mode);return 1;}
        double rel=std::sqrt(sse/den);
        printf("{\"type\":\"numerical\",\"window\":%d,\"t\":%d,\"mode\":%d,\"max_abs\":%.10g,\"relative_l2\":%.10g}\n",window,t,mode,maximum,rel);fflush(stdout);
        if(maximum>0.005||rel>0.005){fprintf(stderr,"FAILED frozen numerical guard window=%d t=%d mode=%d max=%.9g relL2=%.9g\n",window,t,mode,maximum,rel);return 1;}
      }
      continue;
    }
    for(int n=0;n<4;n++)for(int mode=0;mode<3;mode++)launch(mode,chunks,nv);
    CHECK(hipGetLastError());CHECK(hipDeviceSynchronize());
    for(int round=0;round<4;round++)for(int order=0;order<3;order++){
      int mode=(idx+round+order)%3;
      auto wall_start=std::chrono::steady_clock::now();CHECK(hipEventRecord(start));
      launch(mode,chunks,nv);CHECK(hipGetLastError());CHECK(hipEventRecord(finish));CHECK(hipEventSynchronize(finish));
      auto wall_end=std::chrono::steady_clock::now();float ms=0;CHECK(hipEventElapsedTime(&ms,start,finish));
      double us=std::chrono::duration<double,std::micro>(wall_end-wall_start).count();
      printf("{\"type\":\"sample\",\"window\":%d,\"t\":%d,\"round\":%d,\"order\":%d,\"mode\":%d,\"event_us\":%.9g,\"wall_us\":%.9g}\n",window,t,round,order,mode,ms*1000.,us);
    }
    fflush(stdout);
  }
  CHECK(hipEventDestroy(start));CHECK(hipEventDestroy(finish));CHECK(hipFree(d_image));CHECK(hipFree(d_addresses));
  for(auto p:d_state)CHECK(hipFree(p));CHECK(hipFree(d_q));CHECK(hipFree(d_o));CHECK(hipFree(d_partial));CHECK(hipFree(d_output));
  return 0;
}
