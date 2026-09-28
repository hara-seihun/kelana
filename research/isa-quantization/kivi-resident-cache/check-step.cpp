#include "step_bits.hpp"
#include <cmath>
#include <cstdio>
#include <cstring>
#include <limits>
#include <initializer_list>

static unsigned long long raw(double v) {
  unsigned long long b;std::memcpy(&b,&v,8);return b;
}
static double value(unsigned short b) {
  _Float16 h;std::memcpy(&h,&b,2);return double(h);
}
int main() {
  unsigned tested=0;
  auto check=[&](double v) {
    _Float16 h=static_cast<_Float16>(v);unsigned short expected;
    std::memcpy(&expected,&h,2);
    unsigned actual=resident::step_bits(raw(v));tested++;
    if(actual!=expected){std::fprintf(stderr,"rounding mismatch x=%a got=%04x expected=%04x\n",v,actual,expected);return false;}
    return true;
  };
  for(unsigned h=0;h<0x7bff;h++) {
    double lo=value(h),hi=value(h+1),mid=(lo+hi)/2;
    if(!check(lo)||!check(std::nextafter(mid,0.0))||!check(mid)||
       !check(std::nextafter(mid,std::numeric_limits<double>::infinity())))return 1;
  }
  for(double v : {0.0,1e-300,65504.0,std::nextafter(65520.0,0.0),65520.0,
                  std::nextafter(65520.0,std::numeric_limits<double>::infinity()),65536.0,1e300})
    if(!check(v))return 1;
  std::printf("{\"checked\":%u,\"mismatches\":0,\"scope\":\"positive finite half-rounding boundaries plus zero/overflow\"}\n",tested);
}
