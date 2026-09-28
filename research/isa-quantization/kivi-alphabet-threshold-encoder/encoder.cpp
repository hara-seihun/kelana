#include "threshold_core.hpp"
#include <boost/multiprecision/cpp_int.hpp>
#include <algorithm>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
using boost::multiprecision::cpp_int;
using Bytes=std::vector<unsigned char>;
static Bytes read(const std::string& path) {
  std::ifstream f(path,std::ios::binary);if(!f)throw std::runtime_error("missing "+path);
  return {std::istreambuf_iterator<char>(f),{}};
}
static uint16_t u16(const unsigned char* p) {return uint16_t(p[0])|(uint16_t(p[1])<<8);}
static float bf16(const unsigned char* p) {return std::bit_cast<float>(uint32_t(u16(p))<<16);}
static float half(uint16_t bits) {
  uint32_t sign=uint32_t(bits&0x8000)<<16,exp=(bits>>10)&31,mant=bits&1023;
  uint32_t out;
  if(exp==31)out=sign|0x7f800000|(mant<<13);
  else if(exp)out=sign|((exp+112)<<23)|(mant<<13);
  else if(!mant)out=sign;
  else {
    int e=-14;while((mant&1024)==0){mant<<=1;e--;}
    out=sign|((e+127)<<23)|((mant&1023)<<13);
  }
  return std::bit_cast<float>(out);
}
struct Exact {cpp_int numerator;int exponent;};
static Exact number(float v) {
  uint32_t b=std::bit_cast<uint32_t>(v),mag=b&0x7fffffff;
  if((mag>>23)==255)throw std::runtime_error("nonfinite source/level");
  cpp_int m=(mag>>23)?((mag&0x7fffff)|0x800000):(mag&0x7fffff);
  if(b>>31)m=-m;
  return {m,(mag>>23)?int(mag>>23)-150:-149};
}
static Exact number(double v) {
  uint64_t b=std::bit_cast<uint64_t>(v),mag=b&0x7fffffffffffffffULL;
  if((mag>>52)==2047)throw std::runtime_error("nonfinite boundary");
  cpp_int m=(mag>>52)?((mag&0xfffffffffffffULL)|0x10000000000000ULL):(mag&0xfffffffffffffULL);
  if(b>>63)m=-m;
  return {m,(mag>>52)?int(mag>>52)-1075:-1074};
}
static Exact add(Exact a,Exact b) {
  int e=std::min(a.exponent,b.exponent);
  return {(a.numerator<<(a.exponent-e))+(b.numerator<<(b.exponent-e)),e};
}
static Exact sub(Exact a,Exact b) {b.numerator=-b.numerator;return add(a,b);}
static int sign(const Exact& x) {return x.numerator>0?1:x.numerator<0?-1:0;}
static bool abs_less(const Exact& a,const Exact& b) {
  int e=std::min(a.exponent,b.exponent);
  cpp_int x=a.numerator<0?-a.numerator:a.numerator;
  cpp_int y=b.numerator<0?-b.numerator:b.numerator;
  return (x<<(a.exponent-e))<(y<<(b.exponent-e));
}
struct Events {std::vector<Bytes> key,value;};
static Events parse(const Bytes& blob) {
  Events e;size_t at=0;
  while(at<blob.size()) {
    if(at+3>blob.size())throw std::runtime_error("event tail");
    char kind=blob[at];int t=u16(blob.data()+at+1);int width=kind=='K'?1536:kind=='V'?48:0;
    if(!width||at+3+width>blob.size())throw std::runtime_error("event kind/width");
    auto& target=kind=='K'?e.key:e.value;
    if(t!=(kind=='K'?32*(int(target.size())+1):33+int(target.size())))throw std::runtime_error("event chronology");
    target.emplace_back(blob.begin()+at+3,blob.begin()+at+3+width);at+=3+width;
  }
  if(e.key.size()!=8||e.value.size()!=224)throw std::runtime_error("event counts");
  return e;
}
static void duplicate_cases() {
  const float left[]={0,0,1,2},middle[]={0,1,1,2};
  const float right[]={0,1,2,2},flat[]={0,0,0,0};
  auto a=threshold::prepare(0,1,left),b=threshold::prepare(0,1,middle);
  auto c=threshold::prepare(0,1,right),d=threshold::prepare(0,1,flat);
  if(threshold::select(.5f,a)!=0 || threshold::select(.75f,a)!=2 ||
     threshold::select(1.f,b)!=1 || threshold::select(1.75f,b)!=3 ||
     threshold::select(2.f,c)!=2 || threshold::select(3.f,c)!=2 ||
     threshold::select(-4.f,d)!=0 || threshold::select(4.f,d)!=0)
    throw std::runtime_error("partial/all-equal first-label cases");
}
int main(int argc,char** argv) {
  try {
    duplicate_cases();
    if(argc==2 && std::strcmp(argv[1],"--selfcheck")==0){std::puts("partial/all-equal tie cases: passed");return 0;}
    if(argc!=5)throw std::runtime_error("usage: encoder table.f32 source-v.u16 donor-prefix candidate-prefix");
    auto tb=read(argv[1]),source=read(argv[2]);
    if(tb.size()!=16||source.size()!=256*8*128*2)throw std::runtime_error("table/source shape");
    float table[4];std::memcpy(table,tb.data(),16);
    if(!(table[0]<table[1]&&table[1]<table[2]&&table[2]<table[3]))throw std::runtime_error("table order");
    unsigned long long records=0,coordinates=0,comparisons=0,rounded_sums=0,
      rounded_decision_disagreements=0,exact_ties=0,level_equal_groups=0,zero_step_groups=0,mismatches=0;
    Exact minimum{};bool have_minimum=false;
    int first_head=-1,first_token=-1,first_coord=-1,first_expected=-1,first_actual=-1;
    for(int h=0;h<8;h++) {
      Events old=parse(read(std::string(argv[3])+std::to_string(h)+"-events.bin"));
      Events target=parse(read(std::string(argv[4])+std::to_string(h)+"-events.bin"));
      if(old.key!=target.key)throw std::runtime_error("source K events differ");
      for(int token=0;token<224;token++) {
        const auto& donor=old.value[token];const auto& expected=target.value[token];
        if(!std::equal(donor.begin()+32,donor.end(),expected.begin()+32))throw std::runtime_error("source fields differ");
        unsigned char digits[128]{};
        for(int g=0;g<4;g++) {
          const unsigned char* field=donor.data()+32+g*4;
          float a=half(u16(field)),b=half(u16(field+2));
          if(b==0)zero_step_groups++;
          auto plan=threshold::prepare(a,b,table);
          float levels[4]={plan.l0,plan.l1,plan.l2,plan.l3};
          double midpoints[3]={plan.m01,plan.m12,plan.m23};
          for(int c=1;c<4;c++)if(levels[c]<levels[c-1])throw std::runtime_error("decoded level ordering");
          bool equal=false;
          for(int c=1;c<4;c++)if(levels[c]==levels[c-1])equal=true;
          if(equal)level_equal_groups++;
          Exact boundary[3];
          for(int c=0;c<3;c++) {
            boundary[c]=add(number(levels[c]),number(levels[c+1]));
            if(sign(sub(boundary[c],number(midpoints[c])))!=0)rounded_sums++;
          }
          for(int i=0;i<32;i++) {
            int coord=g*32+i;
            const unsigned char* word=source.data()+((token*8+h)*128+coord)*2;
            float x=bf16(word);
            unsigned chosen=threshold::select(x,plan);
            Exact twice=number(x);twice.numerator*=2;
            for(int c=0;c<3;c++) {
              Exact margin=sub(twice,boundary[c]);
              int exact=sign(margin);
              int approx=2.0*double(x)>midpoints[c]?1:2.0*double(x)<midpoints[c]?-1:0;
              if(exact!=approx)rounded_decision_disagreements++;
              if(exact==0)exact_ties++;
              else if(!have_minimum||abs_less(margin,minimum)){minimum=margin;have_minimum=true;}
              comparisons++;
            }
            unsigned nearest=0;double best=INFINITY;
            for(unsigned c=0;c<4;c++) {
              double delta=double(x)-double(levels[c]);double d=delta*delta;
              if(d<best){best=d;nearest=c;}
            }
            unsigned expected_digit=(expected[coord>>2]>>(2*(coord&3)))&3;
            if(chosen!=nearest||chosen!=expected_digit) {
              if(!mismatches){first_head=h;first_token=token;first_coord=coord;
                first_expected=expected_digit;first_actual=chosen;}
              mismatches++;
            }
            digits[coord]=chosen;
            coordinates++;
          }
        }
        for(int i=0;i<32;i++) {
          unsigned actual=digits[4*i]|(digits[4*i+1]<<2)|(digits[4*i+2]<<4)|(digits[4*i+3]<<6);
          if(actual!=expected[i] && !mismatches)throw std::runtime_error("packed byte differs without coordinate mismatch");
        }
        records++;
      }
    }
    cpp_int abs_min=minimum.numerator<0?-minimum.numerator:minimum.numerator;
    long double approx_min=have_minimum?std::ldexp(abs_min.convert_to<long double>(),minimum.exponent):0;
    std::printf("{\"records\":%llu,\"coordinates\":%llu,\"threshold_checks\":%llu,\"rounded_adjacent_sums\":%llu,\"rounded_decision_disagreements\":%llu,\"exact_midpoint_ties\":%llu,\"groups_with_repeated_levels\":%llu,\"zero_step_groups\":%llu,\"minimum_nonzero_exact_margin\":{\"abs_numerator\":\"%s\",\"binary_exponent\":%d,\"approx\":%.17Lg},\"mismatches\":%llu,\"first_mismatch\":{\"h\":%d,\"token\":%d,\"coord\":%d,\"expected\":%d,\"actual\":%d}}\n",
      records,coordinates,comparisons,rounded_sums,rounded_decision_disagreements,exact_ties,
      level_equal_groups,zero_step_groups,abs_min.convert_to<std::string>().c_str(),minimum.exponent,approx_min,
      mismatches,first_head,first_token,first_coord,first_expected,first_actual);
    return mismatches||rounded_decision_disagreements?2:0;
  } catch(const std::exception& ex){std::fprintf(stderr,"threshold encoder: %s\n",ex.what());return 1;}
}
