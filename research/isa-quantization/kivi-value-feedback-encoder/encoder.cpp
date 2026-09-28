#include <cstdint>
#include <cstring>
#include <cmath>
#include <algorithm>
#include "../kivi-resident-cache/step_bits.hpp"

static float bf(const unsigned char* p) {
  uint32_t bits=(uint32_t(p[0])|uint32_t(p[1])<<8)<<16;
  float f; std::memcpy(&f,&bits,4); return f;
}
static float half(unsigned char a,unsigned char b) {
  uint16_t bits=uint16_t(a)|uint16_t(b)<<8;
  _Float16 h;std::memcpy(&h,&bits,2);return float(h);
}
static void put16(unsigned char* p,uint16_t bits){p[0]=bits;p[1]=bits>>8;}
// One source V, one packed 48-byte record, one 128-float persistent residual.
// arm=0 is the conventional source encoder; arm=1 consumes and updates residual.
extern "C" void encode(const unsigned char* source,const float* residual,
                        unsigned char* record,float* next,int arm) {
  std::memset(record,0,48);
  for(int group=0;group<4;group++) {
    float lo=INFINITY,hi=-INFINITY;
    for(int i=0;i<32;i++) {float v=bf(source+group*64+i*2);lo=std::fmin(lo,v);hi=std::fmax(hi,v);}
    double step=(double(hi)-double(lo))/3.0;
    _Float16 low16=(_Float16)lo;uint16_t lb;std::memcpy(&lb,&low16,2);
    double tmp=step;uint64_t bits;std::memcpy(&bits,&tmp,8);
    put16(record+32+group*4,lb);put16(record+34+group*4,resident::step_bits(bits));
    float decoded_lo=half(record[32+group*4],record[33+group*4]);
    float decoded_step=half(record[34+group*4],record[35+group*4]);
    for(int i=0;i<32;i++) {
      int idx=group*32+i;
      float v=bf(source+2*idx);
      float target=arm?float(v+residual[idx]):v;
      float q=step==0.?0.f:std::nearbyint(float(target-lo)/float(step));
      unsigned digit=static_cast<unsigned>(std::fmin(3.f,std::fmax(0.f,q)));
      record[idx/4]|=digit<<((idx%4)*2);
      float product=decoded_step*float(digit);
      float decoded=decoded_lo+product;
      next[idx]=arm?float(target-decoded):0.f;
    }
  }
}
