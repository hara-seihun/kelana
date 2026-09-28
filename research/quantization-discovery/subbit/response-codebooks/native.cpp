#include <immintrin.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <string>
#include <vector>

constexpr int R=5120, S=16, K=64, D=8, Q=8;
static std::vector<uint8_t> read(const std::string& path, size_t n) {
    std::ifstream f(path,std::ios::binary);
    if (!f) throw std::runtime_error("missing "+path);
    std::vector<uint8_t> b((std::istreambuf_iterator<char>(f)),{});
    if (b.size()!=n) throw std::runtime_error("size mismatch "+path);
    return b;
}
struct Inputs {
    std::vector<uint8_t> code, labels, dense, queries, oracle;
    std::array<int, R> row_sum{};
    Inputs(const std::string& dir):
        code(read(dir+"/dictionary.i8",K*D)),labels(read(dir+"/labels.u6",R*12)),
        dense(read(dir+"/decoded.i8",R*128)),queries(read(dir+"/queries.i8",Q*128)),
        oracle(read(dir+"/oracle.i32",Q*R*4)) {
        for(int r=0;r<R;++r)
            for(int j=0;j<128;++j) row_sum[r]+=int(int8_t(dense[r*128+j]));
    }
};
struct Table { int32_t value[S][K]{}; };
static Table prepare(const Inputs& in, int query) {
    Table table;
    for (int s=0;s<S;++s)
        for (int c=0;c<K;++c) {
            int sum=0;
            for (int j=0;j<D;++j)
                sum += int(int8_t(in.queries[query*128+s*D+j]))*int(int8_t(in.code[c*D+j]));
            table.value[s][c]=sum;
        }
    return table;
}
static uint64_t compact(const Inputs& in,const Table& table,int32_t* out) {
    uint64_t checksum=0;
    for (int r=0;r<R;++r) {
        int sum=0;
        const uint8_t* bytes=in.labels.data()+r*12;
        for (int g=0;g<4;++g) {
            const uint32_t w=uint32_t(bytes[3*g]) | uint32_t(bytes[3*g+1])<<8 | uint32_t(bytes[3*g+2])<<16;
            sum+=table.value[4*g][w&63];
            sum+=table.value[4*g+1][(w>>6)&63];
            sum+=table.value[4*g+2][(w>>12)&63];
            sum+=table.value[4*g+3][(w>>18)&63];
        }
        out[r]=sum;checksum+=uint32_t(sum);
    }
    return checksum;
}
static uint64_t dense_vnni(const Inputs& in,int query,int32_t* out) {
    alignas(64) uint8_t u[128];
    for(int j=0;j<128;++j)u[j]=uint8_t(int(int8_t(in.queries[query*128+j]))+128);
    const __m512i q0=_mm512_load_si512(u),q1=_mm512_load_si512(u+64);
    uint64_t checksum=0;
    for(int r=0;r<R;++r) {
        const auto* w=in.dense.data()+128*r;
        __m512i acc=_mm512_dpbusd_epi32(_mm512_setzero_si512(),q0,_mm512_loadu_si512(w));
        acc=_mm512_dpbusd_epi32(acc,q1,_mm512_loadu_si512(w+64));
        const int sum=_mm512_reduce_add_epi32(acc)-128*in.row_sum[r];
        out[r]=sum;checksum+=uint32_t(sum);
    }
    return checksum;
}
template<class F> static double measure(F f,int repeats) {
    const auto before=std::chrono::steady_clock::now();
    uint64_t sink=0;
    for(int i=0;i<repeats;++i) sink+=f(i%Q);
    const auto after=std::chrono::steady_clock::now();
    static volatile uint64_t keep=0;keep=sink;
    return std::chrono::duration<double,std::micro>(after-before).count()/repeats;
}
int main(int argc,char** argv) {
    if(argc!=2) {std::cerr<<"native FIXTURE_DIR\n";return 2;}
    try {
        Inputs in(argv[1]);std::array<int32_t,R> out{};
        std::array<Table,Q> tables;
        for(int q=0;q<Q;++q) {
            tables[q]=prepare(in,q);
            for(int method=0;method<2;++method) {
                if(method) dense_vnni(in,q,out.data());
                else compact(in,tables[q],out.data());
                for(int r=0;r<R;++r) {
                    int32_t expected;
                    std::memcpy(&expected,in.oracle.data()+4*(q*R+r),4);
                    if(out[r]!=expected)throw std::runtime_error("oracle mismatch query="+std::to_string(q)+" row="+std::to_string(r));
                }
            }
        }
        std::array<std::array<double,3>,9> sample{};
        for(int round=0;round<9;++round) {
            for(int arm=0;arm<3;++arm) {
                int choice=(round+arm)%3;
                sample[round][choice]=measure([&](int q) {
                    if(choice==0)return dense_vnni(in,q,out.data());
                    if(choice==1)return compact(in,tables[q],out.data());
                    Table t=prepare(in,q);return compact(in,t,out.data());
                },256);
            }
        }
        const char* names[]={"dense_vnni","compact_reused_table","compact_fresh_table"};
        std::cout<<"{\"rows\":"<<R<<",\"queries\":"<<Q<<",\"samples_us\":{";
        for(int arm=0;arm<3;++arm) {
            if(arm)std::cout<<",";
            std::cout<<"\""<<names[arm]<<"\":[";
            for(int round=0;round<9;++round) {
                if(round)std::cout<<",";
                std::cout<<sample[round][arm];
            }
            std::cout<<"]";
        }
        std::cout<<"}}\n";
    }catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}
}
