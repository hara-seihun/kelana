// CPU lowering of Cornell-RelaxML/qtip e90c668 lib/codebook/bitshift.py
// 3INST L=16 K=3 V=1; official cyclic two-pass Viterbi and block-LDLQ tile order.
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <limits>
#include <string>
#include <vector>

static constexpr int S=65536, G=8192, T=256, N=1024, R=16;
float half(uint16_t h) {
    int sign=h>>15, exponent=(h>>10)&31, mantissa=h&1023;
    float x;
    if(exponent==0) x=std::ldexp(float(mantissa),-24);
    else if(exponent==31) x=mantissa?std::numeric_limits<float>::quiet_NaN():INFINITY;
    else x=std::ldexp(float(mantissa+1024),exponent-25);
    return sign?-x:x;
}
float level(int s) {
    uint64_t x=uint64_t(s)*89226354u+64248484u;
    uint32_t mask=(uint32_t(0x8fff)<<16)|0x8fff;
    uint32_t v=(uint32_t(x)&mask)^996162400u;
    // Upstream converts each 16-bit field to IEEE binary16, adds them in binary16,
    // then promotes the result to fp32 (torch float16 top+bottom).
    float sum=half(uint16_t(v>>16))+half(uint16_t(v));
    // Quantize binary32 sum to binary16 with round-to-nearest-even via hardware F16C.
    _Float16 rounded=(_Float16)sum;
    return float(rounded);
}
template<class V> void read_exact(const std::string& path,V& v) {
    std::ifstream f(path,std::ios::binary);
    if(!f.read(reinterpret_cast<char*>(v.data()),v.size()*sizeof(typename V::value_type))) {std::fprintf(stderr,"read failed %s\n",path.c_str());std::exit(2);}
}
void write_exact(const std::string& path,const void* p,size_t n) {
    std::ofstream f(path,std::ios::binary);f.write(reinterpret_cast<const char*>(p),n);
    if(!f) {std::fprintf(stderr,"write failed %s\n",path.c_str());std::exit(2);}
}
struct Trellis {
    std::vector<float> lut,prev,cost;
    std::vector<uint16_t> trace;
    Trellis():lut(S),prev(S),cost(S),trace(T*G) {for(int s=0;s<S;s++)lut[s]=level(s);}
    void pass(const float* input, int rotation, int anchor,std::array<uint16_t,T>& path) {
        for(int s=0;s<S;s++) {
            float d=lut[s]-input[rotation%T];
            prev[s]=(anchor<0 || (s>>3)==anchor)?d*d:INFINITY;
        }
        for(int t=1;t<T;t++) {
            const float x=input[(t+rotation)%T];
            uint16_t* tr=trace.data()+t*G;
            for(int g=0;g<G;g++) {
                float best=prev[g];int arg=g;
                for(int j=1;j<8;j++) {
                    int p=g+j*G;
                    if(prev[p]<best) {best=prev[p];arg=p;}
                }
                tr[g]=uint16_t(arg);
                for(int d=0;d<8;d++) {
                    int s=g*8+d;float e=lut[s]-x;
                    cost[s]=best+e*e;
                }
            }
            prev.swap(cost);
        }
        float best=INFINITY;int s=0;
        for(int i=0;i<S;i++) if((anchor<0 || (i&(G-1))==anchor) && prev[i]<best) {best=prev[i];s=i;}
        if(!std::isfinite(best)) {std::fprintf(stderr,"nonfinite viterbi\n");std::exit(3);}
        for(int t=T-1;t>=0;t--) {
            path[t]=uint16_t(s);
            if(t) s=trace[t*G+(s>>3)];
        }
    }
    void quantize(const float* x,std::array<uint16_t,T>& path) {
        std::array<uint16_t,T> warm;
        pass(x,T/2,-1,warm);
        int anchor=warm[T/2]>>3;
        pass(x,0,anchor,path);
        for(int t=1;t<T;t++) if((path[t-1]&8191)!=(path[t]>>3)) std::abort();
        if((path.back()&8191)!=(path[0]>>3)) std::abort();
    }
};
int main(int argc,char**argv) {
    if(argc<3) return 2;
    std::string dir=argv[2]; Trellis tc;
    if(std::string(argv[1])=="fit-one") {
        std::array<float,T> input;std::array<uint16_t,T> states;
        read_exact(dir+"/parity-input.bin",input);
        for(float& x:input)x=float((_Float16)x);
        tc.quantize(input.data(),states);
        write_exact(dir+"/parity-states.bin",states.data(),states.size()*sizeof(uint16_t));return 0;
    }
    if(std::string(argv[1])=="lut") {write_exact(dir+"/lut-f32.bin",tc.lut.data(),S*sizeof(float));return 0;}
    if(argc!=4 || std::string(argv[1])!="fit") return 2;
    int group=std::atoi(argv[3]);if(group<0 || group>=8) return 2;
    std::vector<float> w(128*N),l(N*N);read_exact(dir+"/prepared/wr-f32.bin",w);read_exact(dir+"/prepared/ldl-f32.bin",l);
    std::vector<float> q(R*N,0);std::array<uint16_t,T> states;
    std::vector<uint8_t> image(64*96);float tile[T];
    for(int k=63;k>=0;k--) {
        int begin=k*16;
        for(int r=0;r<R;r++) for(int i=0;i<16;i++) {
            float x=w[(group*R+r)*N+begin+i];
            for(int j=begin+16;j<N;j++) x+=(w[(group*R+r)*N+j]-q[r*N+j])*l[j*N+begin+i];
            tile[r*16+i]=float((_Float16)x);
        }
        tc.quantize(tile,states);
        for(int r=0;r<R;r++) for(int i=0;i<16;i++) q[r*N+begin+i]=tc.lut[states[r*16+i]];
        uint8_t* b=image.data()+k*96;
        int at=0;
        auto append=[&](unsigned bits,int count){for(int j=count-1;j>=0;j--) {if(at>=768)std::abort();b[at/8]|=((bits>>j)&1)<<(7-(at%8));at++;}};
        append(states[0],16);
        for(int i=1;i<T && at<768;i++) append(states[i]&7,std::min(3,768-at));
        if(at!=768)std::abort();
    }
    write_exact(dir+"/prepared/group-"+std::to_string(group)+".bin",image.data(),image.size());
    std::printf("group %d 3INST %zu bytes\n",group,image.size());
}
