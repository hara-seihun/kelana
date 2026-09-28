// CPU lowering of Cornell-RelaxML/qtip e90c668 lib/codebook/bitshift.py
// HYB L=16 Q=9 K=3 V=2; official cyclic two-pass Viterbi and block-LDLQ tile order.
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

static constexpr int S=65536, G=1024, T=128, N=1024, R=16;
int kernel_permute(int j) {
    int e=j%2,d=(j/2)%2,c=(j/4)%2,b=(j/8)%4,a=(j/32)%8;
    return ((((d*8+a)*2+c)*4+b)*2+e);
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
    Trellis(const std::string& dir):lut(S*2),prev(S),cost(S),trace(T*G) {
        std::vector<float> table(1024);read_exact(dir+"/hyb-tlut-f32.bin",table);
        for(int s=0;s<S;s++) {
            uint32_t n=uint32_t(s+1)*uint32_t(s);
            int sign=1-2*int((n>>15)&1),idx=int((n>>6)&511);
            lut[2*s]=sign*table[2*idx];lut[2*s+1]=table[2*idx+1];
        }
    }
    void pass(const float* input, int rotation, int anchor,std::array<uint16_t,T>& path) {
        for(int s=0;s<S;s++) {
            float d=lut[2*s]-input[2*(rotation%T)];
            float e=lut[2*s+1]-input[2*(rotation%T)+1];
            prev[s]=(anchor<0 || (s>>6)==anchor)?d*d+e*e:INFINITY;
        }
        for(int t=1;t<T;t++) {
            const float x=input[2*((t+rotation)%T)],y=input[2*((t+rotation)%T)+1];
            uint16_t* tr=trace.data()+t*G;
            for(int g=0;g<G;g++) {
                float best=prev[g];int arg=g;
                for(int j=1;j<64;j++) {
                    int p=g+j*G;
                    if(prev[p]<best) {best=prev[p];arg=p;}
                }
                tr[g]=uint16_t(arg);
                for(int d=0;d<64;d++) {
                    int s=g*64+d;float e=lut[2*s]-x,f=lut[2*s+1]-y;
                    cost[s]=best+e*e+f*f;
                }
            }
            prev.swap(cost);
        }
        float best=INFINITY;int s=0;
        for(int i=0;i<S;i++) if((anchor<0 || (i&(G-1))==anchor) && prev[i]<best) {best=prev[i];s=i;}
        if(!std::isfinite(best)) {std::fprintf(stderr,"nonfinite viterbi\n");std::exit(3);}
        for(int t=T-1;t>=0;t--) {
            path[t]=uint16_t(s);
            if(t) s=trace[t*G+(s>>6)];
        }
    }
    void quantize(const float* x,std::array<uint16_t,T>& path) {
        std::array<uint16_t,T> warm;
        pass(x,T/2,-1,warm);
        int anchor=warm[T/2]>>6;
        pass(x,0,anchor,path);
        for(int t=1;t<T;t++) if((path[t-1]&1023)!=(path[t]>>6)) std::abort();
        if((path.back()&1023)!=(path[0]>>6)) std::abort();
    }
};
int main(int argc,char**argv) {
    if(argc<3) return 2;
    std::string dir=argv[2]; Trellis tc(dir);
    if(std::string(argv[1])=="fit-one") {
        std::array<float,T*2> input;std::array<uint16_t,T> states;
        read_exact(dir+"/parity-input.bin",input);
        for(float& x:input)x=float((_Float16)x);
        tc.quantize(input.data(),states);
        write_exact(dir+"/parity-states.bin",states.data(),states.size()*sizeof(uint16_t));return 0;
    }
    if(std::string(argv[1])=="lut") {write_exact(dir+"/hyb-lut-f32.bin",tc.lut.data(),S*2*sizeof(float));return 0;}
    if(argc!=4 || std::string(argv[1])!="fit") return 2;
    int group=std::atoi(argv[3]);if(group<0 || group>=8) return 2;
    std::vector<float> w(128*N),l(N*N);read_exact(dir+"/prepared-hyb/wr-f32.bin",w);read_exact(dir+"/prepared-hyb/ldl-f32.bin",l);
    std::vector<float> q(R*N,0);std::array<uint16_t,T> states;
    std::vector<uint8_t> image(64*96);float tile[T*2],permuted[T*2];
    for(int k=63;k>=0;k--) {
        int begin=k*16;
        for(int r=0;r<R;r++) for(int i=0;i<16;i++) {
            float x=w[(group*R+r)*N+begin+i];
            for(int j=begin+16;j<N;j++) x+=(w[(group*R+r)*N+j]-q[r*N+j])*l[j*N+begin+i];
            tile[r*16+i]=float((_Float16)x);
        }
        for(int i=0;i<T*2;i++) permuted[i]=tile[kernel_permute(i)];
        tc.quantize(permuted,states);
        for(int i=0;i<T*2;i++) {
            int original=kernel_permute(i);
            q[(original/16)*N+begin+original%16]=tc.lut[2*states[i/2]+i%2];
        }
        uint8_t* b=image.data()+k*96;
        int at=0;
        auto append=[&](unsigned bits,int count){for(int j=count-1;j>=0;j--) {if(at>=768)std::abort();b[at/8]|=((bits>>j)&1)<<(7-(at%8));at++;}};
        append(states[0],16);
        for(int i=1;i<T && at<768;i++) append(states[i]&63,std::min(6,768-at));
        if(at!=768)std::abort();
    }
    write_exact(dir+"/prepared-hyb/group-"+std::to_string(group)+".bin",image.data(),image.size());
    std::printf("group %d HYB %zu bytes\n",group,image.size());
}
