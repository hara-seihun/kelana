#include "halo_format.h"
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>
#include <chrono>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

constexpr int N=248320, K=5120, B=40, TILE=32, STEP=896;
constexpr std::array<int,6> cuts={0,8,24,36,39,40};
uint8_t peel(uint8_t b,int digit) {
    for(int j=0;j<digit;j++) b=uint8_t(3u*b);
    return uint8_t((3u*b)>>8);
}
void decode(const uint8_t* run,int row,int8_t* trits,float& scale,int& nonzero) {
    uint8_t qs[24], qh[2];
    std::memcpy(qs,run+row*16,16);
    std::memcpy(qs+16,run+512+row*8,8);
    std::memcpy(qh,run+768+row*4,2);
    uint16_t bits;std::memcpy(&bits,run+768+row*4+2,2);
    _Float16 half;std::memcpy(&half,&bits,2);scale=float(half);
    int p=0;
    for(int d=0;d<6;d++) for(int j=0;j<4;j++) {
        int pair=2*d+(j&1), h=j>>1;
        trits[8*pair+2*h]=int8_t(peel(qs[4*d+j],0))-1;
        trits[8*pair+2*h+1]=int8_t(peel(qs[4*d+j],1))-1;
        trits[8*pair+4+2*h]=int8_t(peel(qs[4*d+j],2))-1;
        trits[8*pair+4+2*h+1]=int8_t(peel(qs[4*d+j],3))-1;
        trits[96+4*d+j]=int8_t(peel(qs[4*d+j],4))-1;
    }
    for(int h=0;h<2;h++)for(int d=0;d<4;d++)
        trits[120+4*(d/2)+2*h+(d%2)]=int8_t(peel(qh[h],d))-1;
    uint8_t reference[128];halo::decode_block(qs,qh,reference);
    nonzero=0;
    for(int j=0;j<128;j++) {
        if(trits[j]+1!=reference[j])throw std::runtime_error("HALO decoder mismatch");
        nonzero+=trits[j]!=0;
    }
}
void check_tail_basis(){
    for(int pos=120;pos<128;pos++)for(int value=0;value<=2;value+=2){
        uint8_t original[128],qs[24],qh[2],run[STEP]{};
        std::fill(original,original+128,1);original[pos]=value;
        halo::encode_block(original,qs,qh);
        std::memcpy(run,qs,16);std::memcpy(run+512,qs+16,8);
        std::memcpy(run+768,qh,2);run[770]=0;run[771]=0x3c;
        int8_t decoded[128];float scale;int count;
        decode(run,0,decoded,scale,count);
        for(int j=0;j<128;j++)if(decoded[j]+1!=original[j])throw std::runtime_error("qh basis mismatch");
    }
}
struct Cache {
    int fd;size_t size;const uint8_t* bytes;size_t offset,len;
    explicit Cache(const char* path) {
        fd=open(path,O_RDONLY);if(fd<0)throw std::runtime_error("cache open failed");
        struct stat st{};fstat(fd,&st);size=st.st_size;
        bytes=(const uint8_t*)mmap(nullptr,size,PROT_READ,MAP_PRIVATE,fd,0);
        if(bytes==MAP_FAILED)throw std::runtime_error("cache mmap failed");
        if(std::memcmp(bytes,"HALOCAC2",8))throw std::runtime_error("wrong cache format");
        uint64_t count;std::memcpy(&count,bytes+24,8);
        size_t cur=40;bool found=false;
        for(uint64_t i=0;i<count;i++) {
            uint32_t l;std::memcpy(&l,bytes+cur,4);cur+=4;
            std::string name((const char*)bytes+cur,l);cur+=l;
            int64_t n,k;uint64_t o,z;std::memcpy(&n,bytes+cur,8);std::memcpy(&k,bytes+cur+8,8);
            std::memcpy(&o,bytes+cur+16,8);std::memcpy(&z,bytes+cur+24,8);cur+=32;
            if(name=="output.weight") {
                if(n!=N||k!=K||o+z>size||z!=uint64_t(N/32)*B*STEP)throw std::runtime_error("unexpected head shape");
                offset=o;len=z;found=true;
            }
        }
        if(!found)throw std::runtime_error("no output.weight");
    }
    ~Cache(){munmap((void*)bytes,size);close(fd);}
};
struct Row {
    float score=0;
    double real_score=0;
    int64_t real_units=0;
    std::array<int64_t,cuts.size()> upper{};
    std::array<int64_t,cuts.size()> plain_upper{};
};
int main(int argc,char** argv) {
 try {
    if(argc!=6)throw std::runtime_error("usage: probe CACHE QUERY.i8 RESULT.json ORACLE_LIMIT REAL_SCORES.f64");
    check_tail_basis();
    Cache cache(argv[1]);std::ifstream input(argv[2],std::ios::binary);std::array<int8_t,K> q{};
    if(!input.read((char*)q.data(),K))throw std::runtime_error("query is not 5120 bytes");
    std::vector<Row> rows(N);
    std::array<int64_t,B> sumabs{};std::array<int,B> maxabs{};
    for(int b=0;b<B;b++)for(int j=0;j<128;j++) {
        int x=q[b*128+j];sumabs[b]+=std::abs(x);
        maxabs[b]=std::max(maxabs[b],std::abs(x));
    }
    auto start=std::chrono::steady_clock::now();
    long long decoded=0;
    for(int tile=0;tile<N/TILE;tile++)for(int row=0;row<TILE;row++) {
        Row& r=rows[tile*TILE+row];
        std::array<float,8> chain{};std::array<int64_t,B+1> prefix{},remaining{},plain_remaining{};
        std::array<int64_t,B> cap_per_block{},plain_cap{};
        for(int b=0;b<B;b++) {
            const uint8_t* run=cache.bytes+cache.offset+(tile*B+b)*STEP;
            int8_t trits[128];float scale;int nonzero;
            decode(run,row,trits,scale,nonzero);decoded+=128;
            if(!std::isfinite(scale)||scale<0)throw std::runtime_error("invalid scale");
            int dot=0;for(int j=0;j<128;j++) dot+=int(trits[j])*int(q[b*128+j]);
            // Binary16 is an exact integer multiple of 2^-24, including subnormals.
            // The scaled-integer response and every comparison below are exact.
            int64_t scale_units=std::llround(double(scale)*16777216.0);
            if(scale_units<0 || scale_units>100000000)throw std::runtime_error("scale out of integer range");
            chain[b/5]=std::fma(float(dot),scale,chain[b/5]);
            prefix[b+1]=prefix[b]+int64_t(dot)*scale_units;
            int64_t cap=std::min(sumabs[b],int64_t(nonzero)*maxabs[b]);
            cap_per_block[b]=cap*scale_units;
            plain_cap[b]=sumabs[b]*scale_units;
        }
        float score=chain[0];for(int w=1;w<8;w++)score+=chain[w];r.score=score;
        r.real_units=prefix[B];r.real_score=double(prefix[B])/16777216.0;
        int64_t suffix=0,plain_suffix=0;
        for(int b=B-1;b>=0;b--) {
            suffix+=cap_per_block[b];remaining[b]=suffix;
            plain_suffix+=plain_cap[b];plain_remaining[b]=plain_suffix;
        }
        for(size_t j=0;j<cuts.size();j++) {
            int c=cuts[j];r.upper[j]=prefix[c]+remaining[c];r.plain_upper[j]=prefix[c]+plain_remaining[c];
            if(c==B && std::abs(r.real_score-double(score))>0.1)throw std::runtime_error("fp discrepancy");
        }
    }
    auto elapsed=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
    std::ofstream scores(argv[5],std::ios::binary);
    for(const Row& row:rows)scores.write((const char*)&row.real_score,sizeof(double));
    int oracle=0,real_oracle=0;
    for(int i=1;i<N;i++) {
        if(rows[i].score>rows[oracle].score)oracle=i;
        if(rows[i].real_units>rows[real_oracle].real_units)real_oracle=i;
    }
    int limit=std::stoi(argv[4]);if(limit<1||limit>N)throw std::runtime_error("bad candidate window");
    int candidate=0;for(int i=1;i<limit;i++)if(rows[i].score>rows[candidate].score)candidate=i;
    std::ofstream f(argv[3]);f<<"{\n  \"rows\": "<<N<<", \"blocks\": "<<B<<", \"decoded_trits\": "<<decoded<<", \"cpu_seconds\": "<<elapsed<<",\n";
    f<<"  \"head_offset\": "<<cache.offset<<", \"head_bytes\": "<<cache.len<<",\n";
    f<<"  \"oracle\": {\"index\": "<<oracle<<", \"score\": "<<rows[oracle].score<<"}, "
     <<"\"real_oracle\": {\"index\": "<<real_oracle<<", \"units\": "<<rows[real_oracle].real_units<<"}, "
     <<"\"candidate\": {\"index\": "<<candidate<<", \"score\": "<<rows[candidate].score
     <<", \"real_units\": "<<rows[candidate].real_units<<", \"window\": "<<limit<<"},\n";
    f<<"  \"cuts\": [\n";
    for(size_t j=0;j<cuts.size();j++) {
        int c=cuts[j],survive=0,plain_survive=0,oracle_survive=0,candidate_survive=0;
        int64_t threshold=rows[candidate].real_units;
        // Exact scaled-integer comparison. Earlier ties survive, later ties do not.
        // The assertion checks every excluded row against its fully decoded sum.
        int best_survivor=candidate;
        for(int i=0;i<N;i++) {
            if(rows[i].real_units>rows[i].upper[j] || rows[i].real_units>rows[i].plain_upper[j])
                throw std::runtime_error("invalid bound");
            bool keep=i==candidate || (i<candidate ? rows[i].upper[j]>=threshold : rows[i].upper[j]>threshold);
            if(keep) {
                survive++;if(i==oracle)oracle_survive=1;if(i==candidate)candidate_survive=1;
                if(rows[i].real_units>rows[best_survivor].real_units ||
                    (rows[i].real_units==rows[best_survivor].real_units && i<best_survivor)) best_survivor=i;
            } else if(rows[i].real_units>threshold || (i<candidate && rows[i].real_units==threshold))
                throw std::runtime_error("discarded winner");
            if(i==candidate || (i<candidate ? rows[i].plain_upper[j]>=threshold : rows[i].plain_upper[j]>threshold))plain_survive++;
        }
        if(best_survivor!=real_oracle)throw std::runtime_error("survivor argmax mismatch");
        f<<"    {\"prefix_blocks\": "<<c<<", \"survivors\": "<<survive
         <<", \"plain_l1_survivors\": "<<plain_survive
         <<", \"oracle_survives\": "<<oracle_survive<<", \"candidate_survives\": "<<candidate_survive
         <<", \"certified_real_winner\": "<<best_survivor
         <<", \"weight_bytes_read_at_least\": "<<uint64_t(N)*c*28<<", \"bound_bytes_per_query\": "<<uint64_t(N)*(B-c)*3<<"}";
        f<<(j+1==cuts.size()?"\n":",\n");
    }
    f<<"  ]\n}\n";
    std::cout<<"oracle "<<oracle<<" "<<rows[oracle].score<<" candidate "<<candidate<<" "<<rows[candidate].score<<" decode_s "<<elapsed<<"\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}
}
