#define RESIDENT_HOST_REPLAY
#include "state.hip"
#include <cstdio>
#include <vector>
#include <cstdlib>

static void snapshot(FILE* out,int mode,int t,int phase,const unsigned char* cache) {
  int chunks=phase?t/32:(t-1)/32,kr=t-32*chunks;
  int vq=t>(phase?32:33)?t-(phase?32:33):0,vr=t-vq;
  int head=chunks*1536+vq*48+kr*256+vr*256;
  int n=mode?5+8*(chunks*1536+kr*256)+cache[3]*384+vq+cache[4]*2048+vr:8*head;
  unsigned char header[8]={static_cast<unsigned char>(mode),static_cast<unsigned char>(phase),
    static_cast<unsigned char>(t),static_cast<unsigned char>(t>>8),
    static_cast<unsigned char>(n),static_cast<unsigned char>(n>>8),
    static_cast<unsigned char>(n>>16),static_cast<unsigned char>(n>>24)};
  if(std::fwrite(header,1,8,out)!=8)std::abort();
  if(mode){if(std::fwrite(cache,1,n,out)!=static_cast<size_t>(n))std::abort();}
  else for(int h=0;h<8;h++)if(std::fwrite(cache+h*38096,1,head,out)!=static_cast<size_t>(head))std::abort();
}
int main(int argc,char**argv) {
  if(argc!=3)return 2;
  FILE* in=std::fopen(argv[1],"rb"),*out=std::fopen(argv[2],"wb");
  if(!in||!out)return 3;
  for(int mode=0;mode<2;mode++) {
    std::rewind(in);
    std::vector<unsigned char> cache(mode?resident::DICT_CAP:resident::CONTROL_CAP);
    std::vector<unsigned char> work(mode?resident::WORK_CAP:resident::CONTROL_WORK);
    if(mode)cache[2]=1;
    int status=0;
    for(int t=1;t<=256;t++) {
      unsigned char arrival[4098];
      if(std::fread(arrival,1,4098,in)!=4098 || int(arrival[0])+(int(arrival[1])<<8)!=t)return 4;
      if(mode)resident::append_dictionary(cache.data(),work.data(),arrival+2,t,&status);
      else resident::append_control(cache.data(),work.data(),arrival+2,t,&status);
      if(status){std::fprintf(stderr,"append mode=%d t=%d code=%d\n",mode,t,status);return 5;}
      snapshot(out,mode,t,0,cache.data());
      if(mode)resident::flush_dictionary(cache.data(),work.data(),&status);
      else resident::flush_control(cache.data(),work.data(),t,&status);
      if(status){std::fprintf(stderr,"flush mode=%d t=%d code=%d\n",mode,t,status);return 6;}
      snapshot(out,mode,t,1,cache.data());
    }
    if(std::fgetc(in)!=EOF)return 7;
  }
  std::fclose(in);return std::fclose(out)==0?0:8;
}
