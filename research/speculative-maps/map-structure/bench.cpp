// Exact uint8 CDF encoding against the existing uint16 AVX2 visited-row path.
#include <immintrin.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <random>

constexpr int C=32,T=6,S=16,G=256,N=8192;
using Rows16=std::array<uint16_t,C*T*S*S>;
using Rows8=std::array<uint8_t,C*T*S*S>;
using Path=std::array<uint8_t,T>;
struct Input {uint8_t context;std::array<uint8_t,T> u;};
struct Data {Rows16 full{};Rows8 compact{};std::array<Input,N> inputs{};};
int offset(int c,int t,int s){return ((c*T+t)*S+s)*S;}
int scalar(const Data& d,int c,int t,int s,int u){
    const auto* p=&d.full[offset(c,t,s)];
    for(int k=0;k<15;++k)if(u<p[k])return k;
    return 15;
}
int avx2(const Data& d,int c,int t,int s,int u){
    auto x=_mm256_loadu_si256(reinterpret_cast<const __m256i*>(&d.full[offset(c,t,s)]));
    auto gt=_mm256_cmpgt_epi16(x,_mm256_set1_epi16(u));
    return __builtin_ctz(unsigned(_mm256_movemask_epi8(gt)))/2;
}
int sse8(const Data& d,int c,int t,int s,int u){
    auto x=_mm_loadu_si128(reinterpret_cast<const __m128i*>(&d.compact[offset(c,t,s)]));
    auto sign=_mm_set1_epi8(char(0x80));
    auto gt=_mm_cmpgt_epi8(_mm_xor_si128(x,sign),_mm_set1_epi8(char(u^128)));
    return __builtin_ctz(unsigned(_mm_movemask_epi8(gt))|0x8000u);
}
int scalar8(const Data& d,int c,int t,int s,int u){
    const auto* p=&d.compact[offset(c,t,s)];
    for(int k=0;k<15;++k)if(u<p[k])return k;
    return 15;
}
using Sample=int (*)(const Data&,int,int,int,int);
Path walk(const Data& d,const Input& in,Sample sample){
    Path path{};int s=0;
    for(int t=0;t<T;++t){s=sample(d,in.context,t,s,in.u[t]);path[t]=s;}
    return path;
}
volatile uint64_t sink=0;
double measure(const Data& d,Sample sample,int rounds){
    uint64_t checksum=0;
    auto start=std::chrono::steady_clock::now();
    for(int r=0;r<rounds;++r)for(const auto& in:d.inputs)
        for(auto label:walk(d,in,sample))checksum+=label;
    auto elapsed=std::chrono::steady_clock::now()-start;
    sink=sink^checksum;
    return std::chrono::duration<double,std::nano>(elapsed).count()/(rounds*N);
}
int main(int argc,char** argv){
    if(argc!=4)return 2;
    int rounds=std::atoi(argv[2]),active=std::atoi(argv[3]);
    if(rounds<1||rounds>10000||active<1||active>32)return 2;
    Data d;
    std::ifstream file(argv[1],std::ios::binary);
    file.read(reinterpret_cast<char*>(d.full.data()),d.full.size()*sizeof(uint16_t));
    if(!file||file.peek()!=EOF)return 2;
    std::mt19937 gen(0x76123);
    for(auto& in:d.inputs){in.context=gen()%active;for(auto& u:in.u)u=uint8_t(gen()%256);}
    auto prepare=std::chrono::steady_clock::now();
    for(int c=0;c<active;++c)for(int t=0;t<T;++t)for(int s=0;s<S;++s){
        int p=offset(c,t,s),previous=0;
        for(int k=0;k<15;++k){int value=d.full[p+k];if(value<previous||value>255)return 3;d.compact[p+k]=uint8_t(value);previous=value;}
        if(d.full[p+15]!=256)return 3;
        d.compact[p+15]=0;
    }
    double prep_ns=std::chrono::duration<double,std::nano>(std::chrono::steady_clock::now()-prepare).count();
    for(int c=0;c<active;++c)for(int t=0;t<T;++t)for(int s=0;s<S;++s)
        for(int u=0;u<256;++u){int expected=scalar(d,c,t,s,u);if(avx2(d,c,t,s,u)!=expected||sse8(d,c,t,s,u)!=expected||scalar8(d,c,t,s,u)!=expected){std::fprintf(stderr,"mismatch %d,%d,%d,%d\n",c,t,s,u);return 4;}}
    for(const auto& in:d.inputs){Path expected=walk(d,in,scalar);if(walk(d,in,avx2)!=expected||walk(d,in,sse8)!=expected||walk(d,in,scalar8)!=expected)return 5;}
    Sample methods[]={avx2,sse8,scalar8};const char* names[]={"avx2_u16","sse_u8","scalar_u8"};
    std::printf("{\"active_contexts\":%d,\"streams\":%d,\"rounds\":%d,\"u16_bytes\":%d,\"u8_bytes\":%d,\"prepare_ns\":%.0f,\"trials\":[",active,N,rounds,active*T*S*S*2,active*T*S*S,prep_ns);
    for(int trial=0;trial<5;++trial){
        if(trial)std::printf(",");std::printf("{");
        for(int j=0;j<3;++j){int k=(trial+j)%3;if(j)std::printf(",");std::printf("\"%s\":%.2f",names[k],measure(d,methods[k],rounds));}
        std::printf("}");
    }
    std::printf("],\"sink\":%llu}\n",static_cast<unsigned long long>(sink));
}
