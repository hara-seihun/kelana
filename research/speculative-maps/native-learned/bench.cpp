// Frozen learned CDFs: native CPU construction, transition, and prefix costs.
#include <immintrin.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <numeric>
#include <random>
#include <vector>

constexpr int C = 32, T = 6, S = 16, G = 256, CASES = 8192;
using Rows = std::array<uint16_t, C*T*S*S>;
using Cols = Rows;
using ByteMap = std::array<uint8_t, S>;
using Path = std::array<uint8_t, T>;
using Clock = std::chrono::steady_clock;
struct Input { uint16_t index; uint8_t context; std::array<uint8_t,T> uniform; };
struct Data {
    Rows rows{};
    Cols cols{};
    std::vector<uint8_t> inverse; // 32*6*16*256, one byte per inverse-CDF output
    std::array<Input, CASES> inputs{};
    std::array<std::array<ByteMap,T>,CASES> prepared{};
};
constexpr int row(int c,int t,int s,int k) { return (((c*T+t)*S+s)*S+k); }
constexpr int col(int c,int t,int k,int s) { return (((c*T+t)*S+k)*S+s); }
constexpr int lut(int c,int t,int s,int u) { return (((c*T+t)*S+s)*G+u); }
int scalar_lookup(const Data& d,int c,int t,int s,int u) {
    const uint16_t* p = &d.rows[row(c,t,s,0)];
    for (int k=0;k<S-1;++k) if (u<p[k]) return k;
    return S-1;
}
int vector_lookup(const Data& d,int c,int t,int s,int u) {
    __m256i x=_mm256_loadu_si256(reinterpret_cast<const __m256i*>(&d.rows[row(c,t,s,0)]));
    __m256i gt=_mm256_cmpgt_epi16(x,_mm256_set1_epi16(u));
    return __builtin_ctz(unsigned(_mm256_movemask_epi8(gt)))/2;
}
int binary_lookup(const Data& d,int c,int t,int s,int u) {
    const uint16_t* p = &d.rows[row(c,t,s,0)];
    int lo=0,hi=S-1;
    while(lo<hi) { int mid=(lo+hi)/2; if (u<p[mid]) hi=mid; else lo=mid+1; }
    return lo;
}
ByteMap scalar_map(const Data& d,int c,int t,int u) {
    ByteMap m;
    for(int s=0;s<S;++s) m[s]=scalar_lookup(d,c,t,s,u);
    return m;
}
// Candidate-major CDFs admit 16 parallel predecessor comparisons per candidate.
ByteMap vector_map(const Data& d,int c,int t,int u) {
    __m256i acc=_mm256_setzero_si256(), uni=_mm256_set1_epi16(u);
    for(int k=0;k<S-1;++k) {
        __m256i x=_mm256_loadu_si256(reinterpret_cast<const __m256i*>(&d.cols[col(c,t,k,0)]));
        acc=_mm256_sub_epi16(acc,_mm256_cmpgt_epi16(uni,x)); // cdf <= uniform
        acc=_mm256_sub_epi16(acc,_mm256_cmpeq_epi16(uni,x));
    }
    alignas(32) uint16_t tmp[S];
    _mm256_store_si256(reinterpret_cast<__m256i*>(tmp),acc);
    ByteMap m;
    for(int s=0;s<S;++s) m[s]=uint8_t(tmp[s]);
    return m;
}
ByteMap table_map(const Data& d,int c,int t,int u) {
    ByteMap m;
    for(int s=0;s<S;++s) m[s]=d.inverse[lut(c,t,s,u)];
    return m;
}
using Mapper = ByteMap (*)(const Data&,int,int,int);
using Sampler = int (*)(const Data&,int,int,int,int);
Path direct(const Data& d,const Input& in,Sampler sample) {
    Path path{}; int s=0;
    for(int t=0;t<T;++t) { s=sample(d,in.context,t,s,in.uniform[t]); path[t]=s; }
    return path;
}
int table_lookup(const Data& d,int c,int t,int s,int u) { return d.inverse[lut(c,t,s,u)]; }
Path walk_maps(const Data& d,const Input& in,Mapper mapper) {
    Path path{}; int s=0;
    for(int t=0;t<T;++t) { auto m=mapper(d,in.context,t,in.uniform[t]); s=m[s]; path[t]=s; }
    return path;
}
Path prepare_then_walk(const Data& d,const Input& in) {
    std::array<ByteMap,T> maps;
    for(int t=0;t<T;++t) maps[t]=vector_map(d,in.context,t,in.uniform[t]);
    Path path{}; int s=0;
    for(int t=0;t<T;++t){s=maps[t][s];path[t]=s;}
    return path;
}
Path prepared_walk(const Data& d,const Input& in) {
    Path path{};int s=0;
    for(int t=0;t<T;++t){s=d.prepared[in.index][t][s];path[t]=s;}
    return path;
}
Path prepared_prefix(const Data& d,const Input& in) {
    Path path{};
    __m128i acc=_mm_setr_epi8(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15);
    for(int t=0;t<T;++t) {
        acc=_mm_shuffle_epi8(_mm_loadu_si128(reinterpret_cast<const __m128i*>(d.prepared[in.index][t].data())),acc);
        path[t]=uint8_t(_mm_cvtsi128_si32(acc));
    }
    return path;
}
Path compose_bytes(const Data& d,const Input& in,Mapper mapper) {
    Path path{};
    __m128i acc=_mm_setr_epi8(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15);
    for(int t=0;t<T;++t) {
        ByteMap m=mapper(d,in.context,t,in.uniform[t]);
        acc=_mm_shuffle_epi8(_mm_loadu_si128(reinterpret_cast<const __m128i*>(m.data())),acc);
        path[t]=uint8_t(_mm_cvtsi128_si32(acc)); // initial state zero, all prefixes
    }
    return path;
}
using Packed = uint64_t;
Packed pack(const ByteMap& m) {
    Packed p=0;for(int i=0;i<S;++i)p|=Packed(m[i])<<(i*4);return p;
}
Packed compose_nibbles(Packed left,Packed right) {
    Packed out=0;
    for(int s=0;s<S;++s) out|=((right>>(((left>>(4*s))&15)*4))&15)<<(4*s);
    return out;
}
Path packed_prefix(const Data& d,const Input& in,Mapper mapper) {
    Path path{};Packed acc=0xFEDCBA9876543210ULL;
    for(int t=0;t<T;++t) {
        acc=compose_nibbles(acc,pack(mapper(d,in.context,t,in.uniform[t])));
        path[t]=uint8_t(acc&15);
    }
    return path;
}
void prepare_columns(Data& d,int active) {
    for(int c=0;c<active;++c)for(int t=0;t<T;++t)for(int s=0;s<S;++s)for(int k=0;k<S;++k)
        d.cols[col(c,t,k,s)]=d.rows[row(c,t,s,k)];
}
void prepare_inverse(Data& d,int active) {
    d.inverse.resize(active*T*S*G);
    for(int c=0;c<active;++c)for(int t=0;t<T;++t)for(int s=0;s<S;++s) {
        int prior=0;
        for(int k=0;k<S;++k) {
            int end=d.rows[row(c,t,s,k)];
            std::fill(d.inverse.begin()+lut(c,t,s,prior),d.inverse.begin()+lut(c,t,s,end),uint8_t(k));
            prior=end;
        }
    }
}
volatile uint64_t sink=0;
using Work=Path (*)(const Data&,const Input&);
Path linear(const Data& d,const Input& i){return direct(d,i,scalar_lookup);}
Path binary(const Data& d,const Input& i){return direct(d,i,binary_lookup);}
Path vector_direct(const Data& d,const Input& i){return direct(d,i,vector_lookup);}
Path table(const Data& d,const Input& i){return direct(d,i,table_lookup);}
Path scalar_walk(const Data& d,const Input& i){return walk_maps(d,i,scalar_map);}
Path vector_walk(const Data& d,const Input& i){return walk_maps(d,i,vector_map);}
Path scalar_compose(const Data& d,const Input& i){return compose_bytes(d,i,scalar_map);}
Path vector_compose(const Data& d,const Input& i){return compose_bytes(d,i,vector_map);}
Path table_compose(const Data& d,const Input& i){return compose_bytes(d,i,table_map);}
Path nibble(const Data& d,const Input& i){return packed_prefix(d,i,vector_map);}
struct Mode {const char* name; Work work;};
constexpr std::array<Mode,13> modes{{ {"direct_linear",linear},{"direct_binary",binary},{"direct_vector",vector_direct},{"direct_inverse_table",table},
    {"scalar_map_walk",scalar_walk},{"vector_map_walk",vector_walk},{"prepare_then_walk",prepare_then_walk},
    {"prepared_walk",prepared_walk},{"prepared_prefix",prepared_prefix},{"scalar_map_prefix",scalar_compose},
    {"vector_map_prefix",vector_compose},{"inverse_table_prefix",table_compose},{"packed_nibble_prefix",nibble} }};
uint64_t measure(const Data& d,Work f,int rounds,double& ns) {
    uint64_t checksum=0;
    auto begin=Clock::now();
    for(int r=0;r<rounds;++r)for(const Input& input:d.inputs) {
        Path p=f(d,input);
        for(int t=0;t<T;++t) checksum+=p[t];
    }
    ns=std::chrono::duration<double,std::nano>(Clock::now()-begin).count()/(rounds*CASES);
    sink=sink^checksum;
    return checksum;
}
int main(int argc,char** argv) {
    if(argc!=4) {std::fprintf(stderr,"usage: bench CDF-u16-row-major.bin rounds active-contexts\n");return 2;}
    int active=std::atoi(argv[3]);if(active<1||active>C)return 2;
    Data d;
    std::ifstream file(argv[1],std::ios::binary);
    file.read(reinterpret_cast<char*>(d.rows.data()),d.rows.size()*sizeof(uint16_t));
    if(!file || file.peek()!=EOF) {std::fprintf(stderr,"expected %zu bytes of uint16 CDFs\n",d.rows.size()*sizeof(uint16_t));return 2;}
    for(int c=0;c<C;++c)for(int t=0;t<T;++t)for(int s=0;s<S;++s) {
        int prior=0;for(int k=0;k<S;++k){int x=d.rows[row(c,t,s,k)];if(x<prior||x>G)return 3;prior=x;}
        if(prior!=G)return 3;
    }
    std::mt19937 gen(0x76123);
    for(int i=0;i<CASES;++i) {auto& in=d.inputs[i];in.index=i;in.context=gen()%active;for(auto& u:in.uniform)u=uint8_t(gen()%G);}
    auto prep=Clock::now(); prepare_columns(d,active);
    double col_ns=std::chrono::duration<double,std::nano>(Clock::now()-prep).count();
    prep=Clock::now();prepare_inverse(d,active);
    double inverse_ns=std::chrono::duration<double,std::nano>(Clock::now()-prep).count();
    prep=Clock::now();
    for(const auto& in:d.inputs)for(int t=0;t<T;++t)d.prepared[in.index][t]=vector_map(d,in.context,t,in.uniform[t]);
    double maps_ns=std::chrono::duration<double,std::nano>(Clock::now()-prep).count()/CASES;
    // Exhaustive boundary checks catch CDF ties and zero-mass candidates.
    for(int c=0;c<active;++c)for(int t=0;t<T;++t)for(int u=0;u<G;++u) {
        ByteMap a=scalar_map(d,c,t,u),b=vector_map(d,c,t,u),v=table_map(d,c,t,u);
        if(a!=b||a!=v){std::fprintf(stderr,"map mismatch c=%d t=%d u=%d\n",c,t,u);return 4;}
    }
    for(auto& input:d.inputs) {
        Path expected=linear(d,input);
        for(const auto& mode:modes)if(mode.work(d,input)!=expected) {std::fprintf(stderr,"path mismatch: %s\n",mode.name);return 5;}
    }
    int rounds=std::atoi(argv[2]);if(rounds<1||rounds>10000)return 2;
    std::printf("{\"contexts\":%d,\"active_contexts\":%d,\"steps\":%d,\"states\":%d,\"streams\":%d,\"rounds\":%d,\"cdf_bytes\":%zu,\"column_bytes\":%zu,\"inverse_bytes\":%zu,\"column_prepare_ns\":%.0f,\"inverse_prepare_ns\":%.0f,\"maps_prepare_ns_per_stream\":%.2f,\"prepared_map_bytes\":%zu,\"runs\":[",C,active,T,S,CASES,rounds,active*T*S*S*2,active*T*S*S*2,d.inverse.size(),col_ns,inverse_ns,maps_ns,sizeof(d.prepared));
    // Rotated order pairs every contender with baseline in the same trial.
    for(int trial=0;trial<5;++trial) {
        if(trial) std::printf(",");
        std::printf("{\"trial\":%d,\"timing\":{",trial);
        int order[]={0,1,2,3,4,5,6,7,8,9,10,11,12};
        std::rotate(order,order+trial%13,order+13);
        for(int j=0;j<13;++j) {
            if(j)std::printf(",");
            double ns;uint64_t check=measure(d,modes[order[j]].work,rounds,ns);
            std::printf("\"%s\":%.2f",modes[order[j]].name,ns);
            if(check!=uint64_t(rounds)*[&](){uint64_t sum=0;for(const auto& in:d.inputs)for(auto x:linear(d,in))sum+=x;return sum;}())return 6;
        }
        std::printf("}}");
    }
    std::printf("],\"sink\":%llu}\n",static_cast<unsigned long long>(sink));
}
