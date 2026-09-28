#include <cmath>
#include <cstdint>
#include <cstring>
#include <algorithm>
#include <vector>
#include <cassert>

static float bf(const uint8_t *p) { uint32_t u=uint32_t(p[0]|(p[1]<<8))<<16;float f;std::memcpy(&f,&u,4);return f; }
static float half(const uint8_t *p) {
  uint16_t h=p[0]|(p[1]<<8); uint32_t s=(uint32_t(h&0x8000)<<16), e=(h>>10)&31, m=h&1023, u;
  if(e==31)u=s|0x7f800000|(m<<13);
  else if(e)u=s|((e+112)<<23)|(m<<13);
  else if(!m)u=s;
  else { int shift=0;while(!(m&1024)){m<<=1;++shift;}u=s|((113-shift)<<23)|((m&1023)<<13); }
  float f;std::memcpy(&f,&u,4);return f;
}
static unsigned digit(const uint8_t *p,int d){return (p[d/4]>>(2*(d%4)))&3;}
static float quant_v(const uint8_t *p,int d){int g=d/32;return std::fma(half(p+32+g*4+2),float(digit(p,d)),half(p+32+g*4));}
extern "C" int response(const uint8_t *im,size_t size,const float *q,float *ordered,float *grouped,
                         uint64_t *counts) {
  if(size<5 || im[2]!=0)return 1;
  int t=im[0]|(im[1]<<8),nq=im[3],nr=im[4],chunks=(t-1)/32,kr=t-32*chunks,nv=t-33>0?t-33:0,vr=t-nv;
  if(t<1||t>256||nq>nv||nr>vr)return 2;
  size_t keys=8*(chunks*1536+kr*256),base=5+keys,qi=base+size_t(nq)*384,rb=qi+nv,ri=rb+size_t(nr)*2048;
  if(ri+vr!=size)return 3;
  for(int j=0;j<nv;j++)if(im[qi+j]>=nq)return 4;
  for(int j=0;j<vr;j++)if(im[ri+j]>=nr)return 5;
  for(int kv=0;kv<8;kv++){
    const uint8_t *key=im+5+kv*(chunks*1536+kr*256),*recent=key+chunks*1536;
    for(int h=0;h<2;h++){
      int head=2*kv+h;float scores[256],prob[256],top=-INFINITY,sum=0;
      for(int token=0;token<t;token++){
        float v=0;
        if(token<chunks*32){const uint8_t *part=key+(token/32)*1536;int inside=token%32;
          for(int d=0;d<128;d++){
            float x=std::fma(half(part+1024+4*d+2),float(digit(part,inside*128+d)),half(part+1024+4*d));
            v=std::fma(q[head*128+d],x,v);
          }
        }else for(int d=0;d<128;d++)v=std::fma(q[head*128+d],bf(recent+(token-chunks*32)*256+2*d),v);
        scores[token]=v*0.08838834764831844f;top=std::max(top,scores[token]);
      }
      for(int token=0;token<t;token++){prob[token]=std::exp(scores[token]-top);sum+=prob[token];}
      for(int token=0;token<t;token++)prob[token]/=sum;
      float *a=ordered+head*128,*b=grouped+head*128;
      std::fill(a,a+128,0);std::fill(b,b+128,0);
      for(int token=0;token<nv;token++){
        const uint8_t *v=im+base+size_t(im[qi+token])*384+kv*48;
        for(int d=0;d<128;d++)a[d]=std::fma(prob[token],quant_v(v,d),a[d]);
      }
      for(int token=0;token<vr;token++){
        const uint8_t *v=im+rb+size_t(im[ri+token])*2048+kv*256;
        for(int d=0;d<128;d++)a[d]=std::fma(prob[nv+token],bf(v+2*d),a[d]);
      }
      float mq[224]={},mr[33]={};
      for(int token=0;token<nv;token++)mq[im[qi+token]]+=prob[token];
      for(int token=0;token<vr;token++)mr[im[ri+token]]+=prob[nv+token];
      for(int record=0;record<nq;record++){
        const uint8_t *v=im+base+size_t(record)*384+kv*48;
        for(int d=0;d<128;d++)b[d]=std::fma(mq[record],quant_v(v,d),b[d]);
      }
      for(int record=0;record<nr;record++){
        const uint8_t *v=im+rb+size_t(record)*2048+kv*256;
        for(int d=0;d<128;d++)b[d]=std::fma(mr[record],bf(v+2*d),b[d]);
      }
      counts[0]+=nv+vr; // per-head reference reads to accumulate masses
      counts[1]+=nq+nr; // per-head dictionary V records mixed
      counts[2]+=nv+vr; // control per-head reference reads
    }
  }
  return 0;
}
