#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <numeric>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>
#include <immintrin.h>

using Bytes = std::vector<uint8_t>;
static Bytes read_file(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error(path);
    return Bytes(std::istreambuf_iterator<char>(file), {});
}
static unsigned u16(const uint8_t* p) { return unsigned(p[0]) | (unsigned(p[1]) << 8); }
static unsigned u32(const uint8_t* p) { return unsigned(p[0]) | (unsigned(p[1]) << 8) | (unsigned(p[2]) << 16) | (unsigned(p[3]) << 24); }

struct Reader {
    Bytes aos, codes, raw_scale, pages, query;
    std::array<std::array<int8_t, 5>, 243> digit{};
    Reader(const std::string& dir): aos(read_file(dir+"/aos.bin")), codes(read_file(dir+"/codes.bin")),
        raw_scale(read_file(dir+"/scales.bin")), pages(read_file(dir+"/pages.bin")), query(read_file(dir+"/query.bin")) {
        for (int c=0; c<243; ++c) {
            int x=c;
            for (int j=0; j<5; ++j) { digit[c][j]=int8_t(x%3-1); x/=3; }
        }
        if (aos.size()!=5120*28 || codes.size()!=5120*26 || raw_scale.size()!=5120*2 || query.size()!=128)
            throw std::runtime_error("shape");
    }
    unsigned scale(int mode, int row) const {
        if (mode==0) return u16(aos.data()+row*28+26);
        if (mode==1) return u16(raw_scale.data()+row*2);
        const unsigned offset=u32(pages.data()+(row/64)*4);
        const unsigned next=u32(pages.data()+(row/64+1)*4);
        const uint8_t* page=pages.data()+81*4+offset;
        const unsigned base=u16(page), width=page[2], bit=(row%64)*width;
        const unsigned pos=3+bit/8;
        unsigned word=0;
        for (unsigned j=0; j<3 && offset+pos+j<next; ++j) word|=unsigned(page[pos+j])<<(8*j);
        return base+((word>>(bit%8))&((1u<<width)-1));
    }
    int dot(int mode, int row) const {
        const uint8_t* p=mode==0 ? aos.data()+row*28 : codes.data()+row*26;
        int value=0;
        for (int chunk=0; chunk<26; ++chunk) {
            auto& d=digit[p[chunk]];
            const int end=std::min(5,128-chunk*5);
            for (int j=0; j<end; ++j) value+=d[j]*int(int8_t(query[chunk*5+j]));
        }
        return value;
    }
    uint64_t run(int mode, const std::vector<int>& rows, int repeats, bool scale_only) const {
        uint64_t check=0;
        for (int repeat=0; repeat<repeats; ++repeat)
            for (auto r: rows) {
                auto bits=scale(mode,r);
                if (scale_only) check+=bits;
                else {
                    float y=float(dot(mode,r))*_cvtsh_ss(bits);
                    uint32_t value;
                    std::memcpy(&value,&y,4);
                    check+=value;
                }
            }
        return check;
    }
};
int main(int argc, char** argv) {
    if(argc!=2) return 2;
    Reader reader(argv[1]);
    std::vector<int> sequential(5120); std::iota(sequential.begin(),sequential.end(),0);
    auto random=sequential; std::mt19937 rng(19); std::shuffle(random.begin(),random.end(),rng);
    std::vector<int> sparse;
    for(int j=0;j<16;++j) sparse.push_back(64*(j*5)+(j*13)%64);
    std::array<std::vector<int>,3> panels={sequential, random, sparse};
    const char* names[]={"sequential", "random", "sparse_16_pages"};
    std::cout<<"{\n";
    bool first=true;
    for (int workload=0; workload<2; ++workload)
        for (int panel=0; panel<3; ++panel) {
            auto& rows=panels[panel];
            int repeats=std::max(1,160000/int(rows.size()));
            uint64_t check=reader.run(0,rows,1,workload==1);
            for(int mode=1;mode<3;++mode)
                if (reader.run(mode,rows,1,workload==1)!=check) throw std::runtime_error("consumer mismatch");
            if (!first) std::cout<<",\n";
            first=false;
            std::cout<<"  \""<<(workload==0?"dot_":"scale_")<<names[panel]<<"\": {\"checksum\": "<<check;
            for (int mode=0;mode<3;++mode) {
                std::vector<double> samples;
                for(int trial=0;trial<9;++trial) {
                    auto start=std::chrono::steady_clock::now();
                    volatile uint64_t sink=reader.run(mode,rows,repeats,workload==1);
                    (void)sink;
                    auto end=std::chrono::steady_clock::now();
                    double ns=std::chrono::duration<double,std::nano>(end-start).count()/(rows.size()*repeats);
                    samples.push_back(ns);
                }
                std::sort(samples.begin(),samples.end());
                std::cout<<", \""<<(mode==0?"aos":mode==1?"soa":"page")<<"_ns_per_row\": "<<samples[4];
            }
            std::cout<<"}";
        }
    std::cout<<"\n}\n";
}
