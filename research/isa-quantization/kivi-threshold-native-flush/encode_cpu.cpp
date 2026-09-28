// Complete CPU-callable byte encoder using the same declared arithmetic as HIP.
#include "encoder.h"
#include <cstdio>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

template <typename T> std::vector<T> read(const char* path) {
  std::ifstream file(path,std::ios::binary);
  if (!file) throw std::runtime_error(std::string("missing input: ")+path);
  std::vector<char> raw((std::istreambuf_iterator<char>(file)),{});
  if (raw.size()%sizeof(T)) throw std::runtime_error("unaligned file");
  std::vector<T> result(raw.size()/sizeof(T));
  __builtin_memcpy(result.data(),raw.data(),raw.size());
  return result;
}
void save(const char* path,const std::vector<uint8_t>& data) {
  std::ofstream file(path,std::ios::binary);
  if (!file || !file.write(reinterpret_cast<const char*>(data.data()),data.size()))
    throw std::runtime_error("cannot write output");
}
int main(int argc,char** argv) {
  if(argc!=5) { std::fprintf(stderr,"usage: encode_cpu BF16_CHUNKS METRIC_FP16 BASE_OUT METRIC_OUT\n");return 2; }
  try {
    auto input=read<uint16_t>(argv[1]);auto metric=read<Half>(argv[2]);
    if(input.size()!=8*32*128 || metric.size()!=1152) throw std::runtime_error("wrong input dimensions");
    std::vector<uint8_t> base(8*2560),changed(8*2560);
    for(int chunk=0;chunk<8;++chunk) {
      const uint16_t* source=input.data()+chunk*32*128;
      uint8_t code[32*128];Half field[128*2];
      for(int d=0;d<128;++d) initial_channel(source,d,code,field);
      for(int token=0;token<32;++token) pack_token(code,token,base.data()+chunk*2560);
      for(int d=0;d<128;++d) pack_fields(field,d,base.data()+chunk*2560);
      for(int token=0;token<32;++token) metric_token(source,token,code,field,metric.data());
      for(int token=0;token<32;++token) pack_token(code,token,changed.data()+chunk*2560);
      for(int d=0;d<128;++d) pack_fields(field,d,changed.data()+chunk*2560);
    }
    save(argv[3],base);save(argv[4],changed);
  } catch(const std::exception& e) { std::fprintf(stderr,"%s\n",e.what());return 1; }
}
