#pragma once
// Same finite arithmetic called by host reference and gfx1151 device kernels.
#include <cmath>
#include <cstdint>

#ifdef __HIPCC__
#define HD __host__ __device__
#else
#define HD
#endif

using Half = _Float16;

HD inline float key_float(uint16_t word) {
  return __builtin_bit_cast(float, static_cast<uint32_t>(word) << 16);
}
HD inline uint16_t half_bits(Half h) { return __builtin_bit_cast(uint16_t, h); }
HD inline Half half_from_bits(uint16_t bits) { return __builtin_bit_cast(Half, bits); }
HD inline float finite_round(float v) { return __builtin_rintf(v); }

// d is one of the 128 per-channel producers. Writes original KIVI nibble
// codes and actual FP16 origin/step; reads only this completed 32-key slab.
HD inline void initial_channel(const uint16_t* input, int d,
                               uint8_t* code, Half* field) {
  float minimum=key_float(input[d]), maximum=minimum;
  for (int t=1;t<32;++t) {
    float x=key_float(input[t*128+d]);
    if (x<minimum) minimum=x;
    if (x>maximum) maximum=x;
  }
  float step=(maximum-minimum)/15.0f;
  field[d*2]=static_cast<Half>(minimum);
  field[d*2+1]=static_cast<Half>(step);
  for (int t=0;t<32;++t) {
    float c=step>0 ? finite_round((key_float(input[t*128+d])-minimum)/step):0.0f;
    if (c<0) c=0;
    if (c>15) c=15;
    code[t*128+d]=static_cast<uint8_t>(c);
  }
}

// Ordered finite-grid threshold for the 16 existing KIVI codes. The first
// nonnegative adjacent difference selects a global quadratic minimum; exact
// zero chooses the even code. Expression order is pinned before parity:
// hb=a*step; twog=2*grad; T(j)=twog+hb*(2*(j-current)+1).
HD inline double boundary(double hb, double twog, int j, int current) {
  return twog+hb*static_cast<double>(2*(j-current)+1);
}
HD inline uint8_t threshold_code(double grad, double a, double step, int current) {
  double hb=a*step;
  double twog=2.0*grad;
  int lo=0,hi=15;
  while(lo<hi) {
    int mid=(lo+hi)/2;
    if(boundary(hb,twog,mid,current)<0.0) lo=mid+1;
    else hi=mid;
  }
  if(lo<15 && (lo&1) && boundary(hb,twog,lo,current)==0.0) ++lo;
  return static_cast<uint8_t>(lo);
}

// t is one of 32 independent token owners. The d loop is intentionally
// serial Gauss-Seidel; FP16 assets/fields become FP64 after loading.
HD inline void metric_token(const uint16_t* input, int t, uint8_t* code,
                            const Half* field, const Half* metric) {
  double s[8]={0,0,0,0,0,0,0,0};
  for (int d=0;d<128;++d) {
    double e=static_cast<double>(field[d*2])+static_cast<double>(code[t*128+d])*static_cast<double>(field[d*2+1])
             -static_cast<double>(key_float(input[t*128+d]));
    for (int r=0;r<8;++r) s[r]+=e*static_cast<double>(metric[d*8+r]);
  }
  for (int d=0;d<128;++d) {
    double step=static_cast<double>(field[d*2+1]);
    if (step==0) continue;
    double u2=0,us=0;
    for (int r=0;r<8;++r) {
      double u=static_cast<double>(metric[d*8+r]);
      us+=u*s[r];u2+=u*u;
    }
    double diag=static_cast<double>(metric[1024+d]);
    double error=static_cast<double>(field[d*2])+static_cast<double>(code[t*128+d])*step
                 -static_cast<double>(key_float(input[t*128+d]));
    double a=diag+u2;
    double grad=diag*error+us;
    uint8_t next=threshold_code(grad,a,step,static_cast<int>(code[t*128+d]));
    double delta=(static_cast<double>(next)-static_cast<double>(code[t*128+d]))*step;
    for (int r=0;r<8;++r) s[r]+=delta*static_cast<double>(metric[d*8+r]);
    code[t*128+d]=next;
  }
}
HD inline void pack_token(const uint8_t* code, int t, uint8_t* output) {
  for (int pair=0;pair<64;++pair)
    output[t*64+pair]=static_cast<uint8_t>(code[t*128+2*pair] | (code[t*128+2*pair+1]<<4));
}
HD inline void pack_fields(const Half* field, int d, uint8_t* output) {
  uint16_t lo=half_bits(field[d*2]),step=half_bits(field[d*2+1]);
  output[2048+d*4]=static_cast<uint8_t>(lo);
  output[2048+d*4+1]=static_cast<uint8_t>(lo>>8);
  output[2048+d*4+2]=static_cast<uint8_t>(step);
  output[2048+d*4+3]=static_cast<uint8_t>(step>>8);
}
