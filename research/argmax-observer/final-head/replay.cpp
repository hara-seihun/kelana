#include "halo_format.h"
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

constexpr int N=248320,K=5120,B=40,TILE=32,STEP=896;
constexpr std::array<int,8> cuts={8,24,30,32,34,36,39,40};
uint8_t peel(uint8_t b,int n){for(int i=0;i<n;i++)b=uint8_t(3u*b);return uint8_t((3u*b)>>8);}
void decode(const uint8_t* run,int row,int8_t* w,float& scale,int& nz){
    uint8_t qs[24],qh[2];std::memcpy(qs,run+row*16,16);
    std::memcpy(qs+16,run+512+row*8,8);std::memcpy(qh,run+768+row*4,2);
    uint16_t bits;std::memcpy(&bits,run+768+row*4+2,2);
    _Float16 half;std::memcpy(&half,&bits,2);scale=float(half);
    for(int d=0;d<6;d++)for(int j=0;j<4;j++){
        int pair=2*d+(j&1),h=j>>1;
        w[8*pair+2*h]=int8_t(peel(qs[4*d+j],0))-1;
        w[8*pair+2*h+1]=int8_t(peel(qs[4*d+j],1))-1;
        w[8*pair+4+2*h]=int8_t(peel(qs[4*d+j],2))-1;
        w[8*pair+4+2*h+1]=int8_t(peel(qs[4*d+j],3))-1;
        w[96+4*d+j]=int8_t(peel(qs[4*d+j],4))-1;
    }
    for(int h=0;h<2;h++)for(int d=0;d<4;d++)w[120+4*(d/2)+2*h+(d%2)]=int8_t(peel(qh[h],d))-1;
    uint8_t reference[128];halo::decode_block(qs,qh,reference);
    nz=0;for(int j=0;j<128;j++){
        if(w[j]+1!=reference[j])throw std::runtime_error("HALO decoder mismatch");
        nz+=w[j]!=0;
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
struct Cache{
    int fd;size_t size,offset=0,len=0;const uint8_t* bytes;
    explicit Cache(const char* path){
        fd=open(path,O_RDONLY);if(fd<0)throw std::runtime_error("cache open");
        struct stat st{};fstat(fd,&st);size=st.st_size;
        bytes=(const uint8_t*)mmap(nullptr,size,PROT_READ,MAP_PRIVATE,fd,0);
        if(bytes==MAP_FAILED||std::memcmp(bytes,"HALOCAC2",8))throw std::runtime_error("cache format");
        uint64_t count;std::memcpy(&count,bytes+24,8);size_t cur=40;
        for(uint64_t i=0;i<count;i++){
            uint32_t l;std::memcpy(&l,bytes+cur,4);cur+=4;
            std::string name((const char*)bytes+cur,l);cur+=l;
            int64_t n,k;uint64_t o,z;std::memcpy(&n,bytes+cur,8);std::memcpy(&k,bytes+cur+8,8);
            std::memcpy(&o,bytes+cur+16,8);std::memcpy(&z,bytes+cur+24,8);cur+=32;
            if(name=="output.weight"){
                if(n!=N||k!=K||o+z>size||z!=uint64_t(N/32)*B*STEP)throw std::runtime_error("head shape");
                offset=o;len=z;
            }
        }
        if(!len)throw std::runtime_error("head absent");
    }
    ~Cache(){munmap((void*)bytes,size);close(fd);}
};
template<class T>std::vector<T> read(const std::string& p,size_t count){
    std::vector<T> out(count);std::ifstream f(p,std::ios::binary);
    if(!f.read((char*)out.data(),count*sizeof(T)))throw std::runtime_error("read "+p);
    return out;
}
struct Row{
    float simulated=0;long double real_score=0;
    std::array<long double,cuts.size()> upper{};
};
uint64_t tail_line_bytes(const std::vector<uint8_t>& finish,int blocks,int line_bytes){
    uint64_t lines=0;
    for(int tile=0;tile<N/TILE;tile++){
        std::array<bool,STEP/32> touched{};
        for(int row=0;row<TILE;row++)if(finish[tile*TILE+row]){
            touched[row*16/line_bytes]=true;
            touched[(512+row*8)/line_bytes]=true;
            touched[(768+row*4)/line_bytes]=true;
        }
        for(bool used:touched)lines+=used;
    }
    return lines*blocks*line_bytes;
}
int main(int argc,char** argv){
 try{
    if(argc!=6)throw std::runtime_error("replay CACHE CASE_DIRECTORY CANDIDATE_WINDOW OUTPUT_JSON REAL_SCORES.f64");
    check_tail_basis();
    Cache cache(argv[1]);std::string dir=argv[2];int window=std::stoi(argv[3]);
    if(window<1||window>N)throw std::runtime_error("candidate window");
    auto q=read<int8_t>(dir+"/query.i8",K);
    auto xs=read<float>(dir+"/scales.f32",B);
    auto sums=read<int32_t>(dir+"/sums.i32",B);
    auto logits=read<float>(dir+"/logits.f32",N);
    std::array<int,B> maxabs{},sumabs{};
    for(int b=0;b<B;b++){
        int sum=0;for(int j=0;j<128;j++){
            int a=q[b*128+j];sum+=a;sumabs[b]+=std::abs(a);maxabs[b]=std::max(maxabs[b],std::abs(a));
        }
        if(sum!=sums[b]||!std::isfinite(xs[b])||xs[b]<=0)throw std::runtime_error("bad input scales/sums");
    }
    int winner=0,candidate=0,nonfinite=0,simulated_mismatch=0;
    float max_simulated_delta=0;
    for(int i=0;i<N;i++){
        if(!std::isfinite(logits[i]))nonfinite++;
        if(logits[i]>logits[winner])winner=i;
        if(i<window&&logits[i]>logits[candidate])candidate=i;
    }
    if(nonfinite)throw std::runtime_error("nonfinite logits need separate comparator contract");
    std::vector<Row> rows(N);
    for(int tile=0;tile<N/TILE;tile++)for(int row=0;row<TILE;row++){
        int idx=tile*TILE+row;auto& r=rows[idx];
        std::array<float,8> chain{};
        std::array<long double,B+1> prefix{},prefix_abs{},suffix{};
        std::array<long double,B> caps{};
        for(int b=0;b<B;b++){
            const uint8_t* run=cache.bytes+cache.offset+(tile*B+b)*STEP;
            int8_t weights[128];float scale;int nz;decode(run,row,weights,scale,nz);
            if(!std::isfinite(scale)||scale<0)throw std::runtime_error("bad weight scale");
            int dot=0;for(int j=0;j<128;j++)dot+=int(weights[j])*int(q[b*128+j]);
            chain[b/5]=std::fma(float(dot),scale*xs[b],chain[b/5]);
            long double term=(long double)dot*(long double)scale*(long double)xs[b];
            prefix[b+1]=prefix[b]+term;prefix_abs[b+1]=prefix_abs[b]+std::abs(term);
            caps[b]=(long double)std::min(sumabs[b],nz*maxabs[b])*(long double)scale*(long double)xs[b];
        }
        float simulated=chain[0];for(int w=1;w<8;w++)simulated+=chain[w];r.simulated=simulated;r.real_score=prefix[B];
        if(std::bit_cast<uint32_t>(simulated)!=std::bit_cast<uint32_t>(logits[idx])){
            simulated_mismatch++;max_simulated_delta=std::max(max_simulated_delta,std::abs(simulated-logits[idx]));
        }
        for(int b=B-1;b>=0;b--)suffix[b]=suffix[b+1]+caps[b];
        // Binary32 roundoff envelope for 40 products, 40 FMAs and seven adds.
        // The accepted domain excludes non-finite inputs and overflow; tiny
        // absolute slack covers underflow/FTZ and long-double bound arithmetic.
        for(size_t j=0;j<cuts.size();j++){
            int c=cuts[j];
            // Only decoded prefix terms and suffix metadata may fund the guard.
            long double mass_bound=prefix_abs[c]+suffix[c];
            if(mass_bound>1000000.0L)throw std::runtime_error("roundoff-domain magnitude exceeded");
            long double guard=0.0001L*mass_bound+0.000000000001L;
            r.upper[j]=prefix[c]+suffix[c]+guard;
        }
    }
    if(simulated_mismatch)throw std::runtime_error("native FP replay differs from deployed logits");
    std::ofstream scores(argv[5],std::ios::binary);
    for(const Row& r:rows){double value=double(r.real_score);scores.write((const char*)&value,8);}
    std::ofstream f(argv[4]);
    f<<"{\n  \"roundoff_envelope\": \"1e-4 times prefix absolute terms plus suffix caps, then 1e-12\", \"winner\": "<<winner<<", \"candidate\": "<<candidate
     <<", \"candidate_window\": "<<window<<", \"winner_logit\": "<<logits[winner]
     <<", \"candidate_logit\": "<<logits[candidate]
     <<", \"nonfinite\": "<<nonfinite<<", \"simulated_mismatch\": "<<simulated_mismatch
     <<", \"max_simulated_delta\": "<<max_simulated_delta<<",\n  \"cuts\": [\n";
    for(size_t j=0;j<cuts.size();j++){
        int c=cuts[j],survive=0,uncovered=0,best=candidate;
        std::vector<uint8_t> finish(N);
        for(int i=0;i<N;i++){
            if(rows[i].upper[j]<(long double)logits[i])uncovered++;
            bool keep=i==candidate||(i<candidate?rows[i].upper[j]>=(long double)logits[candidate]:rows[i].upper[j]>(long double)logits[candidate]);
            if(keep){survive++;if(logits[i]>logits[best]||(logits[i]==logits[best]&&i<best))best=i;}
            finish[i]=keep||i<window;
        }
        f<<"    {\"prefix_blocks\": "<<c<<", \"survivors\": "<<survive
         <<", \"upper_failures\": "<<uncovered<<", \"winner_from_survivors\": "<<best
         <<", \"weight_bytes_prefix\": "<<uint64_t(N)*c*28<<", \"bound_bytes\": "<<uint64_t(N)*(B-c)*3
         <<", \"weight_bytes_exact_survivors\": "<<uint64_t(survive)*(B-c)*28
         <<", \"tail_weight_bytes_candidates_and_survivors_32byte_lines\": "<<tail_line_bytes(finish,B-c,32)
         <<", \"tail_weight_bytes_candidates_and_survivors_64byte_lines\": "<<tail_line_bytes(finish,B-c,64)
         <<", \"tail_weight_bytes_candidates_and_survivors_128byte_lines\": "<<tail_line_bytes(finish,B-c,128)<<"}"
         <<(j+1==cuts.size()?"\n":",\n");
        if(uncovered||best!=winner)throw std::runtime_error("invalid FP bound or wrong winner");
    }
    f<<"  ]\n}\n";
    std::cout<<"winner "<<winner<<" candidate "<<candidate<<" sim_diff "<<simulated_mismatch
             <<" max_delta "<<max_simulated_delta<<"\n";
 }catch(const std::exception& e){std::cerr<<"replay: "<<e.what()<<"\n";return 1;}
}
