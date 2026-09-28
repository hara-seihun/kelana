#pragma once

#if defined(__HIPCC__)
#define ALPHABET_HD __host__ __device__ __forceinline__
#else
#define ALPHABET_HD inline
#endif

namespace threshold {
struct Plan {
  float l0,l1,l2,l3;
  double m01,m12,m23;
  unsigned first1,first2,first3;
};

ALPHABET_HD Plan prepare(float a,float b,const float* table) {
  Plan p;
  float product0=b*table[0],product1=b*table[1];
  float product2=b*table[2],product3=b*table[3];
  p.l0=a+product0;p.l1=a+product1;
  p.l2=a+product2;p.l3=a+product3;
  p.m01=double(p.l0)+double(p.l1);
  p.m12=double(p.l1)+double(p.l2);
  p.m23=double(p.l2)+double(p.l3);
  p.first1=p.l0==p.l1?0:1;
  p.first2=p.l1==p.l2?p.first1:2;
  p.first3=p.l2==p.l3?p.first2:3;
  return p;
}

ALPHABET_HD unsigned select(float source,const Plan& p) {
  double twice=2.0*double(source);
  if(twice<=p.m01)return 0;
  if(twice<=p.m12)return p.first1;
  if(twice<=p.m23)return p.first2;
  return p.first3;
}
}
#undef ALPHABET_HD
