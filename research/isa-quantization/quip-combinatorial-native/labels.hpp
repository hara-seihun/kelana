#pragma once
#include <cstdint>
#if defined(__HIPCC__)
#define LABEL_HD __host__ __device__ __forceinline__
#else
#define LABEL_HD inline
#endif
// Colex subsets of the eight coordinates; exception bytes live at image+49298.
LABEL_HD unsigned choose8(unsigned i,unsigned k) {
  if(k>i)return 0;
  if(k==0)return 1;
  if(k==1)return i;
  if(k==2)return i*(i-1)/2;
  if(k==3)return i*(i-1)*(i-2)/6;
  return i*(i-1)*(i-2)*(i-3)/24;
}
LABEL_HD unsigned masks(unsigned c,const unsigned char *exception,unsigned &fives) {
  unsigned threes=0;fives=0;
  if(c>=192) {
    unsigned i=c&7,j=(c>>3)&7;
    fives=1u<<i;
    threes=i==j?0:1u<<j;
  } else if(c>=163) {
    threes=exception[c-163];
  } else {
    unsigned k=(c>=93)?4:(c>=37)?3:(c>=9)?2:(c>=1)?1:0;
    unsigned rank=c-((k==4)?93:(k==3)?37:(k==2)?9:(k==1)?1:0);
    for(int i=7;i>=0;i--) {
      unsigned b=choose8(i,k);
      if(k && b<=rank) {threes|=1u<<i;rank-=b;k--;}
    }
  }
  return threes;
}
LABEL_HD unsigned packed_magnitude(unsigned c,const unsigned char *exception) {
  unsigned fives,threes=masks(c,exception,fives);
  unsigned packed=0,odd=__builtin_popcount(threes)&1;
  for(unsigned j=0;j<8;j++) {
    int v=1+2*((threes>>j)&1)+4*((fives>>j)&1);
    if(j==7 && odd)v=-v;
    packed|=((unsigned)(v+8)&15)<<(4*j);
  }
  return packed;
}
#undef LABEL_HD
