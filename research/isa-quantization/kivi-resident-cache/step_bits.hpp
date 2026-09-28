#pragma once

#if defined(__HIPCC__)
#define RESIDENT_HD __host__ __device__
#else
#define RESIDENT_HD
#endif
namespace resident {
// Exact nonnegative binary64 -> binary16 round-to-nearest-even metadata.
// Integer bits avoid the gfx1151 compiler's illegal raw _Float16 lo16 operand.
RESIDENT_HD inline unsigned step_bits(unsigned long long bits) {
  unsigned exponent=unsigned((bits>>52)&2047);
  if(exponent==2047)return (bits&0xfffffffffffffULL)?0x7e00u:0x7c00u;
  int e=int(exponent)-1023;
  if(e < -25)return 0;
  if(e > 15)return 0x7c00u;
  unsigned long long mantissa=(bits&0xfffffffffffffULL)|(1ULL<<52);
  unsigned shift=e < -14?unsigned(28-e):42u;
  unsigned long long q=mantissa>>shift;
  unsigned long long rem=mantissa&((1ULL<<shift)-1),half=1ULL<<(shift-1);
  if(rem>half || (rem==half && (q&1)))q++;
  return e < -14?unsigned(q):unsigned((e+15)*1024)+unsigned(q)-1024u;
}
}
#undef RESIDENT_HD
