#include <immintrin.h>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <utility>
#include <vector>

// Two ternary 3x3 matrices per step: gate and suppressor. The seed was selected
// only to keep at least eight distinct reachable states through all eight steps.
constexpr int8_t W[8][2][3][3] = {
    {{{0,1,-1},{1,1,1},{1,1,-1}},{{-1,1,0},{-1,0,-1},{0,-1,1}}},
    {{{1,0,-1},{-1,0,1},{1,1,0}},{{0,-1,1},{1,1,1},{0,1,1}}},
    {{{1,0,1},{1,0,1},{0,1,0}},{{-1,1,1},{0,1,1},{0,1,0}}},
    {{{1,0,1},{-1,-1,0},{-1,-1,1}},{{-1,1,-1},{-1,-1,0},{-1,1,0}}},
    {{{0,0,1},{-1,0,1},{1,-1,1}},{{-1,0,-1},{-1,0,1},{1,-1,1}}},
    {{{1,1,-1},{-1,1,1},{-1,-1,0}},{{-1,-1,-1},{1,-1,1},{1,1,-1}}},
    {{{1,-1,0},{0,1,0},{-1,-1,0}},{{-1,-1,0},{0,1,1},{-1,-1,0}}},
    {{{-1,-1,0},{0,-1,-1},{1,-1,0}},{{-1,1,0},{0,1,-1},{-1,1,0}}},
};

constexpr int clamp(int x) { return x < -1 ? -1 : x > 1 ? 1 : x; }
constexpr int relu(int x) { return x > 0 ? x : 0; }
constexpr std::array<int, 3> decode(int q) {
    return {q % 3 - 1, q / 3 % 3 - 1, q / 9 - 1};
}
constexpr int encode(std::array<int, 3> x) {
    return (x[0]+1) + 3*(x[1]+1) + 9*(x[2]+1);
}
constexpr int step(int t, int q) {
    auto x = decode(q);
    std::array<int, 3> y{};
    for (int i=0; i<3; ++i) {
        int a=0, b=0;
        for (int j=0; j<3; ++j) {
            a += W[t][0][i][j]*x[j];
            b += W[t][1][i][j]*x[j];
        }
        y[i] = clamp(x[i] + relu(a) - relu(b));
    }
    return encode(y);
}
constexpr auto tables() {
    std::array<std::array<uint8_t,64>,9> out{};
    for (int t=0; t<8; ++t)
        for (int q=0; q<27; ++q) out[t][q] = step(t,q);
    for (int q=0; q<27; ++q) {
        int s=q;
        for (int t=0; t<8; ++t) s=step(t,s);
        out[8][q]=s;
    }
    return out;
}
alignas(64) constexpr auto TABLES=tables();
constexpr auto decode_tables() {
    std::array<std::array<uint8_t,64>,3> out{};
    for (int q=0;q<27;++q) for (int j=0;j<3;++j) out[j][q]=decode(q)[j];
    return out;
}
alignas(64) constexpr auto DECODE=decode_tables();

using Vec=__m512i;
inline Vec splat(int8_t x) { return _mm512_set1_epi8(x); }
template<int T,int B,int R,int C>
inline Vec term(const Vec (&x)[3]) {
    constexpr int w=W[T][B][R][C];
    if constexpr (w==1) return x[C];
    if constexpr (w==-1) return _mm512_sub_epi8(_mm512_setzero_si512(),x[C]);
    return _mm512_setzero_si512();
}
template<int T,int B,int R>
inline Vec dot(const Vec (&x)[3]) {
    return _mm512_add_epi8(_mm512_add_epi8(term<T,B,R,0>(x),term<T,B,R,1>(x)),term<T,B,R,2>(x));
}
template<int T>
inline void direct_step(Vec (&x)[3]) {
    Vec y[3];
    for (int i=0;i<3;++i) {
        // The switch is resolved by the compiler because T and each row are constants.
        Vec a,b;
        if (i==0) { a=dot<T,0,0>(x); b=dot<T,1,0>(x); }
        else if (i==1) { a=dot<T,0,1>(x); b=dot<T,1,1>(x); }
        else { a=dot<T,0,2>(x); b=dot<T,1,2>(x); }
        a=_mm512_max_epi8(a,_mm512_setzero_si512());
        b=_mm512_max_epi8(b,_mm512_setzero_si512());
        y[i]=_mm512_min_epi8(splat(1),_mm512_max_epi8(splat(-1),
            _mm512_sub_epi8(_mm512_add_epi8(x[i],a),b)));
    }
    for(int i=0;i<3;++i) x[i]=y[i];
}
inline Vec encode_vector(const Vec (&x)[3]) {
    Vec a=_mm512_add_epi8(x[0],splat(1));
    Vec b=_mm512_add_epi8(x[1],splat(1));
    Vec c=_mm512_add_epi8(x[2],splat(1));
    Vec four_c=_mm512_add_epi8(_mm512_add_epi8(c,c),_mm512_add_epi8(c,c));
    return _mm512_add_epi8(_mm512_add_epi8(a,_mm512_add_epi8(b,_mm512_add_epi8(b,b))),
        _mm512_add_epi8(_mm512_add_epi8(four_c,four_c),c));
}
inline Vec run_direct(Vec q) {
    Vec x[3];
    for(int i=0;i<3;++i) x[i]=_mm512_permutexvar_epi8(q,
        _mm512_load_si512(reinterpret_cast<const Vec*>(DECODE[i].data())));
    direct_step<0>(x); direct_step<1>(x); direct_step<2>(x); direct_step<3>(x);
    direct_step<4>(x); direct_step<5>(x); direct_step<6>(x); direct_step<7>(x);
    return encode_vector(x);
}
inline Vec run_staged(Vec q) {
    for(int t=0;t<8;++t) q=_mm512_permutexvar_epi8(q,
        _mm512_load_si512(reinterpret_cast<const Vec*>(TABLES[t].data())));
    return q;
}
inline Vec run_fused(Vec q) {
    return _mm512_permutexvar_epi8(q,
        _mm512_load_si512(reinterpret_cast<const Vec*>(TABLES[8].data())));
}
using Kernel=Vec(*)(Vec);
using RoutedKernel=Vec(*)(Vec,uint8_t);
inline Vec run_direct_routed(Vec q,uint8_t mask) {
    Vec x[3];
    for(int i=0;i<3;++i) x[i]=_mm512_permutexvar_epi8(q,
        _mm512_load_si512(reinterpret_cast<const Vec*>(DECODE[i].data())));
    if(mask&1) direct_step<0>(x);
    if(mask&2) direct_step<1>(x);
    if(mask&4) direct_step<2>(x);
    if(mask&8) direct_step<3>(x);
    if(mask&16) direct_step<4>(x);
    if(mask&32) direct_step<5>(x);
    if(mask&64) direct_step<6>(x);
    if(mask&128) direct_step<7>(x);
    return encode_vector(x);
}
inline Vec run_staged_routed(Vec q,uint8_t mask) {
    for(int t=0;t<8;++t) if(mask&(1<<t)) q=_mm512_permutexvar_epi8(q,
        _mm512_load_si512(reinterpret_cast<const Vec*>(TABLES[t].data())));
    return q;
}
alignas(64) const auto ROUTED_TABLES=[] {
    std::array<std::array<uint8_t,64>,256> out{};
    for(int m=0;m<256;++m) for(int q=0;q<27;++q) {
        int s=q;
        for(int t=0;t<8;++t) if(m&(1<<t)) s=step(t,s);
        out[m][q]=s;
    }
    return out;
}();
inline Vec run_fused_routed(Vec q,uint8_t mask) {
    return _mm512_permutexvar_epi8(q,
        _mm512_load_si512(reinterpret_cast<const Vec*>(ROUTED_TABLES[mask].data())));
}
int main(int argc,char** argv) {
    int repetitions=argc>1?std::atoi(argv[1]):5;
    constexpr int groups=4096;
    std::vector<uint8_t> input(groups*64);
    for (size_t i=0;i<input.size();++i) input[i]=uint8_t((i*19+i/67*7+i/4096)%27);
    alignas(64) uint8_t a[64],b[64];
    for (int q=0;q<27;++q) {
        for(int lane=0;lane<64;++lane) a[lane]=q;
        Vec v=_mm512_load_si512(reinterpret_cast<const Vec*>(a));
        _mm512_store_si512(reinterpret_cast<Vec*>(b),run_direct(v));
        for(int lane=0;lane<64;++lane)
            if(b[lane]!=TABLES[8][q]) return std::fprintf(stderr,"direct mismatch %d\n",q),1;
        _mm512_store_si512(reinterpret_cast<Vec*>(b),run_staged(v));
        for(int lane=0;lane<64;++lane)
            if(b[lane]!=TABLES[8][q]) return std::fprintf(stderr,"staged mismatch %d\n",q),1;
        _mm512_store_si512(reinterpret_cast<Vec*>(b),run_fused(v));
        for(int lane=0;lane<64;++lane)
            if(b[lane]!=TABLES[8][q]) return std::fprintf(stderr,"fused mismatch %d\n",q),1;
    }
    for(int mask=0;mask<256;++mask) for(int q=0;q<27;++q) {
        for(int lane=0;lane<64;++lane) a[lane]=q;
        Vec v=_mm512_load_si512(reinterpret_cast<const Vec*>(a));
        for(const RoutedKernel f : {run_direct_routed,run_staged_routed,run_fused_routed}) {
            _mm512_store_si512(reinterpret_cast<Vec*>(b),f(v,uint8_t(mask)));
            for(int lane=0;lane<64;++lane) if(b[lane]!=ROUTED_TABLES[mask][q])
                return std::fprintf(stderr,"routed mismatch %d %d\n",mask,q),1;
        }
    }
    std::printf("{\"machine\":\"AMD Ryzen AI MAX+ 395 AVX512VBMI\",\"groups\":%d,\"repetitions\":%d,\"verified_inputs\":27,\"verified_routed_cases\":6912,\"reachable\":[",groups,repetitions);
    for(int t=0;t<8;++t) {
        bool seen[27]{}; int n=0;
        for(int q=0;q<27;++q) { int s=q;for(int j=0;j<=t;++j)s=step(j,s);if(!seen[s])seen[s]=true,++n; }
        std::printf("%s%d",t?",":"",n);
    }
    std::printf("],\"table_bytes_staged\":512,\"table_bytes_fused\":64,\"samples_ns_per_64\":{");
    const Kernel kernels[]={run_direct,run_staged,run_fused};
    const char* names[]={"direct","staged","fused"};
    for(int k=0;k<3;++k) {
        std::printf("%s\"%s\":[",k?",":"",names[k]);
        for(int r=0;r<repetitions;++r) {
            unsigned checksum=0;
            auto begin=std::chrono::steady_clock::now();
            for(int g=0;g<groups;++g) {
                Vec v=_mm512_loadu_si512(input.data()+g*64);
                Vec out=kernels[k](v);
                checksum+=unsigned(_mm_cvtsi128_si32(_mm512_castsi512_si128(out)));
            }
            auto end=std::chrono::steady_clock::now();
            auto ns=std::chrono::duration<double,std::nano>(end-begin).count()/groups;
            std::printf("%s%.3f",r?",":"",ns);
            if(checksum==0) std::abort();
        }
        std::printf("]");
    }
    std::printf("},\"routed_table_bytes\":16384,\"routed_samples_ns_per_64\":{");
    const RoutedKernel routed[]={run_direct_routed,run_staged_routed,run_fused_routed};
    for(int k=0;k<3;++k) {
        std::printf("%s\"%s\":[",k?",":"",names[k]);
        for(int r=0;r<repetitions;++r) {
            unsigned checksum=0;
            auto begin=std::chrono::steady_clock::now();
            for(int g=0;g<groups;++g) {
                Vec v=_mm512_loadu_si512(input.data()+g*64);
                uint8_t mask=uint8_t((g*73+g/256*43+r*29));
                Vec out=routed[k](v,mask);
                checksum+=unsigned(_mm_cvtsi128_si32(_mm512_castsi512_si128(out)));
            }
            auto end=std::chrono::steady_clock::now();
            auto ns=std::chrono::duration<double,std::nano>(end-begin).count()/groups;
            std::printf("%s%.3f",r?",":"",ns);
            if(checksum==0) std::abort();
        }
        std::printf("]");
    }
    std::printf("}}\n");
}
