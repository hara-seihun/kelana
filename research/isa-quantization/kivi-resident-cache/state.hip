// Frozen full-layer causal cache transition. One lane owns all mutable bytes.
// The deliberately serial transition prices rather than hides dictionary movement.
#ifdef RESIDENT_HOST_REPLAY
#include "host-shim.hpp"
#else
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#endif
#include <cmath>
#include <cstdint>
#include "step_bits.hpp"

namespace resident {
constexpr int DICT_CAP=266240, CONTROL_CAP=8*38096, WORK_CAP=20480, CONTROL_WORK=6656;
constexpr int CHUNK=0, SWAP=12288, CODES=14336, FIELDS=18432, VALUES=18944;
__device__ inline void copy(unsigned char* d,const unsigned char* s,int n) { for(int i=0;i<n;i++) d[i]=s[i]; }
__device__ inline bool equal(const unsigned char* a,const unsigned char* b,int n) {
  for(int i=0;i<n;i++)if(a[i]!=b[i])return false;return true;
}
__device__ inline float bf(const unsigned char* p) { return __uint_as_float((unsigned(p[0]) | (unsigned(p[1])<<8))<<16); }
__device__ inline void field(unsigned char* p,float v) {
  unsigned short bits=__half_as_ushort(__float2half_rn(v));p[0]=bits&255;p[1]=bits>>8;
}
__device__ inline void step_field(unsigned char* p,double v) {
  unsigned bits=step_bits(static_cast<unsigned long long>(__double_as_longlong(v)));
  p[0]=bits&255;p[1]=bits>>8;
}
__device__ inline void quant(const float* x,int n,unsigned char* code,unsigned char* fields) {
  float lo=x[0],hi=x[0];
  for(int i=1;i<n;i++){lo=fminf(lo,x[i]);hi=fmaxf(hi,x[i]);}
  double step=(double(hi)-double(lo))/3.0;
  float divisor=float(step);
  for(int i=0;i<n;i++) {
    float q=step==0.?0.f:nearbyintf((x[i]-lo)/divisor);
    code[i]=static_cast<unsigned char>(fminf(3.f,fmaxf(0.f,q)));
  }
  field(fields,lo);step_field(fields+2,step);
}
struct Dictionary {
  unsigned char *a,*w;int *error;
  int len,t,nk,nkr,nv,nvr;
  __device__ int qb() const {return 5+8*(nk*1536+nkr*256);}
  __device__ int qi() const {return qb()+a[3]*384;}
  __device__ int rb() const {return qi()+nv;}
  __device__ int ri() const {return rb()+a[4]*2048;}
  __device__ void shift(int pos,int n) {
    if(pos<0 || pos>len || len+n>DICT_CAP){*error=1;return;}
    for(int i=len-1;i>=pos;i--)a[i+n]=a[i];len+=n;
  }
  __device__ void erase(int pos,int n) {
    if(pos<0 || pos+n>len){*error=2;return;}
    for(int i=pos+n;i<len;i++)a[i-n]=a[i];len-=n;
  }
  __device__ void put(bool q,const unsigned char* record) {
    int width=q?384:2048,base=q?qb():rb(),count=a[q?3:4],refs=q?qi():ri();
    int found=count;
    for(int i=0;i<count;i++)if(equal(a+base+i*width,record,width)){found=i;break;}
    if(found==count){shift(refs,width);if(*error)return;copy(a+refs,record,width);a[q?3:4]++;}
    int end=q?qi()+nv:ri()+nvr;
    shift(end,1);if(*error)return;a[end]=found;
    if(q)nv++;else nvr++;
  }
  __device__ void append(int step,const unsigned char* arrival) {
    for(int h=7;h>=0;h--) {
      int end=5+(h+1)*(nk*1536+nkr*256);
      shift(end,256);if(*error)return;copy(a+end,arrival+h*256,256);
    }
    nkr++;
    put(false,arrival+2048);if(*error)return;
    a[0]=step&255;a[1]=step>>8;a[2]=0;t=step;
  }
  __device__ void flush_key() {
    float* values=reinterpret_cast<float*>(w+VALUES);
    unsigned char* codes=w+CODES;unsigned char* fields=w+FIELDS;
    for(int h=0;h<8;h++) {
      int start=5+h*(nk*1536+8192)+nk*1536;
      for(int c=0;c<128;c++) {
        for(int j=0;j<32;j++)values[j]=bf(a+start+2*(j*128+c));
        unsigned char digits[32];quant(values,32,digits,fields+c*4);
        for(int j=0;j<32;j++)codes[j*128+c]=digits[j];
      }
      for(int i=0;i<1024;i++)w[CHUNK+h*1536+i]=codes[4*i] | (codes[4*i+1]<<2) | (codes[4*i+2]<<4) | (codes[4*i+3]<<6);
      copy(w+CHUNK+h*1536+1024,fields,512);
    }
    for(int h=7;h>=0;h--) {
      int start=5+h*(nk*1536+8192)+nk*1536;
      erase(start,8192);shift(start,1536);if(*error)return;copy(a+start,w+CHUNK+h*1536,1536);
    }
    nk++;nkr=0;
  }
  __device__ void flush_value() {
    int base=rb(),ref=a[ri()];
    float* values=reinterpret_cast<float*>(w+VALUES);
    unsigned char* codes=w+CODES;unsigned char* fields=w+FIELDS;
    unsigned char* packed=w+CHUNK;
    for(int h=0;h<8;h++) {
      const unsigned char* source=a+base+ref*2048+h*256;
      for(int g=0;g<4;g++) {
        for(int i=0;i<32;i++)values[i]=bf(source+2*(g*32+i));
        quant(values,32,codes+g*32,fields+g*4);
      }
      for(int i=0;i<32;i++)packed[h*48+i]=codes[i*4] | (codes[i*4+1]<<2) | (codes[i*4+2]<<4) | (codes[i*4+3]<<6);
      copy(packed+h*48+32,fields,16);
    }
    put(true,packed);if(*error)return;
    erase(ri(),1);nvr--;
    int next=0;
    for(int p=0;p<nvr;p++) {
      int refs=ri(),index=a[refs+p];
      if(index<next)continue;
      if(index!=next) {
        base=rb();copy(w+SWAP,a+base+next*2048,2048);
        copy(a+base+next*2048,a+base+index*2048,2048);
        copy(a+base+index*2048,w+SWAP,2048);
        for(int j=0;j<nvr;j++) {
          unsigned char& x=a[refs+j];
          if(x==index)x=next;else if(x==next)x=index;
        }
      }
      next++;
    }
    if(next<a[4]){erase(rb()+next*2048,(a[4]-next)*2048);a[4]=next;}
  }
  __device__ void finish() {
    if(nkr==32)flush_key();if(*error)return;
    if(nvr==33)flush_value();if(*error)return;
    a[2]=1;
    if(len!=ri()+nvr || nk!=(t/32) || nv!=(t>32?t-32:0))*error=3;
  }
};
// Per-head conventional arrangement: [K chunks][quant V][recent K][recent V].
// Capacity 38,096 B/head; this is exactly the query control's packed layout.
__device__ void conventional(unsigned char* cache,unsigned char* work,int step,const unsigned char* arrival,bool do_flush,int* error) {
  int prior=step-1,old_chunks=prior/32,old_k=prior%32;
  int old_nv=prior>32?prior-32:0,old_r=prior-old_nv;
  int n_chunks=(step-1)/32,nkr=step-n_chunks*32;
  int nv=step>33?step-33:0,nvr=step-nv;
  float* values=reinterpret_cast<float*>(work+6144);
  unsigned char* codes=work+1536;unsigned char* fields=work+5632;
  for(int h=0;h<8;h++) {
    unsigned char* a=cache+h*38096;
    int old_v=old_chunks*1536,old_rk=old_v+old_nv*48,old_rv=old_rk+old_k*256;
    int new_v=old_v,new_rk=new_v+old_nv*48,new_rv=new_rk+(old_k+1)*256;
    int tail=old_r*256;
    if(!do_flush) {
      for(int i=tail-1;i>=0;i--)a[new_rv+i]=a[old_rv+i];
      copy(a+new_rk+old_k*256,arrival+h*256,256);
      copy(a+new_rv+tail,arrival+2048+h*256,256);
      continue;
    }
    if(step%32==0) {
      for(int c=0;c<128;c++) {
        for(int i=0;i<32;i++)values[i]=bf(a+new_rk+2*(i*128+c));
        unsigned char digits[32];quant(values,32,digits,fields+c*4);
        for(int i=0;i<32;i++)codes[i*128+c]=digits[i];
      }
      for(int i=0;i<1024;i++)work[i]=codes[4*i] | (codes[4*i+1]<<2) | (codes[4*i+2]<<4) | (codes[4*i+3]<<6);
      copy(work+1024,fields,512);
      // Recent V moves downward; copy forward before moving quantized V upward.
      int dest_v=(old_chunks+1)*1536;
      int dest_rv=dest_v+old_nv*48;
      for(int i=0;i<(old_r+1)*256;i++)a[dest_rv+i]=a[new_rv+i];
      for(int i=old_nv*48-1;i>=0;i--)a[dest_v+i]=a[new_v+i];
      copy(a+old_v,work,1536);
    }
    int chunks=step/32,kr=step%32;
    int rv=chunks*1536+old_nv*48+kr*256;
    if(step>=33) {
      // V oldest BF16 token is quantized, then recent FIFO loses it.
      for(int g=0;g<4;g++) {
        for(int i=0;i<32;i++)values[i]=bf(a+rv+2*(g*32+i));
        quant(values,32,codes+g*32,fields+g*4);
      }
      for(int i=0;i<32;i++)work[i]=codes[i*4] | (codes[i*4+1]<<2) | (codes[i*4+2]<<4) | (codes[i*4+3]<<6);
      copy(work+32,fields,16);
      int vpos=chunks*1536+old_nv*48;
      // Insertion before recent K (which may be nonempty); its new base follows V.
      int source_rk=vpos,source_rv=rv;
      for(int i=(kr*256+(old_r+1)*256)-1;i>=0;i--)a[source_rk+48+i]=a[source_rk+i];
      copy(a+vpos,work,48);
      for(int i=0;i<old_r*256;i++)a[source_rv+48+i]=a[source_rv+48+256+i];
    }
    int post_nv=step>32?step-32:0,post_vr=step-post_nv;
    int size=chunks*1536+post_nv*48+kr*256+post_vr*256;
    if(size>38096)*error=4;
  }
}
__global__ void append_dictionary(unsigned char* cache,unsigned char* work,const unsigned char* arrival,int step,int* error) {
  if(blockIdx.x||threadIdx.x)return;
  int t=int(cache[0])+(int(cache[1])<<8),chunks=t/32;
  int recent=t-chunks*32,quant=t>32?t-32:0,rv=t-quant;
  Dictionary d{cache,work,error,5+8*(chunks*1536+recent*256)+cache[3]*384+quant+cache[4]*2048+rv,
               t,chunks,recent,quant,rv};
  if(t+1!=step || cache[2]!=1){*error=5;return;}
  d.append(step,arrival);
}
__global__ void append_control(unsigned char* cache,unsigned char* work,const unsigned char* arrival,int step,int* error) {
  if(blockIdx.x||threadIdx.x)return;
  if(step<1 || step>256){*error=5;return;}
  conventional(cache,work,step,arrival,false,error);
}
__global__ void flush_control(unsigned char* cache,unsigned char* work,int step,int* error) {
  if(blockIdx.x||threadIdx.x)return;
  conventional(cache,work,step,nullptr,true,error);
}
__global__ void flush_dictionary(unsigned char* cache,unsigned char* work,int* error) {
  if(blockIdx.x||threadIdx.x)return;
  int t=int(cache[0])+(int(cache[1])<<8),chunks=(t-1)/32,recent=t-chunks*32;
  int quant=t>33?t-33:0,rv=t-quant;
  Dictionary d{cache,work,error,5+8*(chunks*1536+recent*256)+cache[3]*384+quant+cache[4]*2048+rv,
               t,chunks,recent,quant,rv};
  if(cache[2]!=0){*error=5;return;}d.finish();
}
}
