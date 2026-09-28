#include "packed.hpp"
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <random>
#include <vector>
#define HIP(x) do { auto e=(x); if(e!=hipSuccess){std::fprintf(stderr,"HIP line %d: %s\n",__LINE__,hipGetErrorString(e));std::exit(1);} } while(0)

__global__ void probe(const v16h *A, const v16h *B, float *out, float *inputs) {
    int lane=threadIdx.x;
    v8f total={};
    for(int s=0;s<8;++s) {
        v16h a=A[s*32+lane], b=B[s*32+lane];
        for(int k=0;k<16;++k) {
            inputs[((s*32+lane)*16+k)*2]=(float)a[k];
            inputs[((s*32+lane)*16+k)*2+1]=(float)b[k];
        }
        total=__builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a,b,total);
        v8f single=__builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a,b,v8f{});
        for(int r=0;r<8;++r) {
            out[((s*34)*32+lane)*8+r]=total[r];
            out[((s*34+1)*32+lane)*8+r]=single[r];
        }
        for(int k=0;k<16;++k) {
            v16h only={}; only[k]=b[k];
            v8f one=__builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a,only,v8f{});
            for(int r=0;r<8;++r) out[((s*34+2+k)*32+lane)*8+r]=one[r];
            v16h onlyA={}; onlyA[k]=a[k];
            v8f both=__builtin_amdgcn_wmma_f32_16x16x16_f16_w32(onlyA,only,v8f{});
            for(int r=0;r<8;++r) out[((s*34+18+k)*32+lane)*8+r]=both[r];
        }
    }
}

__global__ void minimal_probe(float *out) {
    const int zs[9]={-2048,-2047,-2046,-1,0,1,2046,2047,2048};
    int c=blockIdx.x%135, k=c%15+1, z=zs[c/15], b1=int(blockIdx.x)/135-1;
    v16h a={},b={}; a[0]=-1; a[k]=(h16)z; b[0]=1; b[k]=(h16)b1;
    v8f p=__builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a,b,v8f{});
    if(threadIdx.x==0) out[blockIdx.x]=p[0];
}

int main(int argc, char **argv) {
    int offset=argc>1?std::atoi(argv[1]):0;
    int8_t W[ROWS][KDIM], X[KDIM][COLS];
    std::mt19937 rng(20260915);
    for(auto &row:W) for(auto &w:row) w=int(rng()%3)-1;
    for(auto &row:X) for(auto &x:row) x=int(rng()%256)-128;
    Digits d; split_digits(X,d);
    std::vector<v16h> A(8*32), B(8*32);
    pack_weights_f16(W,A.data()); pack_digits_f16(d,B.data());
    for(auto &frag:B) for(int k=0;k<16;++k) frag[k]=(h16)((float)frag[k]+offset);
    v16h *da,*db; float *dout,*din;
    HIP(hipMalloc(&da,A.size()*sizeof(v16h))); HIP(hipMalloc(&db,B.size()*sizeof(v16h)));
    HIP(hipMalloc(&dout,8*34*256*sizeof(float))); HIP(hipMalloc(&din,8*32*16*2*sizeof(float)));
    HIP(hipMemcpy(da,A.data(),A.size()*sizeof(v16h),hipMemcpyHostToDevice));
    HIP(hipMemcpy(db,B.data(),B.size()*sizeof(v16h),hipMemcpyHostToDevice));
    hipLaunchKernelGGL(probe,dim3(1),dim3(32),0,0,da,db,dout,din); HIP(hipDeviceSynchronize());
    std::vector<float> out(8*34*256), ins(8*32*16*2);
    HIP(hipMemcpy(out.data(),dout,out.size()*sizeof(float),hipMemcpyDeviceToHost));
    HIP(hipMemcpy(ins.data(),din,ins.size()*sizeof(float),hipMemcpyDeviceToHost));
    int inputbad=0, bad[4]={}; double worst[4]={};
    for(int s=0;s<8;++s) for(int l=0;l<32;++l) for(int k=0;k<16;++k) {
        float a=ins[((s*32+l)*16+k)*2], b=ins[((s*32+l)*16+k)*2+1];
        if(a!=(float)A[s*32+l][k] || b!=(float)B[s*32+l][k] || a!=std::nearbyint(a) || b!=std::nearbyint(b)) ++inputbad;
    }
    int shown=0;
    for(int s=0;s<8;++s) for(int mode=0;mode<34;++mode) for(int l=0;l<32;++l) for(int r=0;r<8;++r) {
        int m=2*r+(l>>4), j=l&15;
        int begin=mode==0?0:s*16, end=(s+1)*16;
        if(mode>=2) {begin=s*16+(mode-2)%16;end=begin+1;}
        int expected=0;
        for(int k=begin;k<end;++k) expected+=(W[2*m][k]+2047*W[2*m+1][k])*(offset+(j<8?d.lo[k][j]:d.hi[k][j-8]));
        float got=out[((s*34+mode)*32+l)*8+r];
        double err=double(got)-expected; int type=mode==0?0:mode==1?1:mode<18?2:3;
        if(err!=0) {++bad[type];worst[type]=std::fmax(worst[type],std::fabs(err));
            if(shown<12 && mode>=2) {++shown; int k=begin;
                std::printf("product s=%d k=%d row=%d col=%d A=%d B=%d expected=%d got=%.12g hex=%a error=%g\n",s,k,m,j,W[2*m][k]+2047*W[2*m+1][k],offset+(j<8?d.lo[k][j]:d.hi[k][j-8]),expected,got,got,err);
            }
        }
    }
    std::printf("input failures %d; cumulative %d / %g; single WMMA %d / %g; B-isolated %d / %g; both-isolated %d / %g\n",inputbad,bad[0],worst[0],bad[1],worst[1],bad[2],worst[2],bad[3],worst[3]);
    float *dm; HIP(hipMalloc(&dm,405*sizeof(float)));
    hipLaunchKernelGGL(minimal_probe,dim3(405),dim3(32),0,0,dm); HIP(hipDeviceSynchronize());
    float minimal[405]; HIP(hipMemcpy(minimal,dm,sizeof(minimal),hipMemcpyDeviceToHost));
    const int zs[9]={-2048,-2047,-2046,-1,0,1,2046,2047,2048};
    int minimalbad=0;
    for(int ci=0;ci<405;++ci) {
        int c=ci%135,b1=ci/135-1,expected=-1+zs[c/15]*b1;
        if(minimal[ci]!=expected) {
            if(minimalbad++<25) std::printf("minimal A[0]=-1 A[%d]=%d B[0]=1 B[%d]=%d: expected %d got %.12g %a\n",c%15+1,zs[c/15],c%15+1,b1,expected,minimal[ci],minimal[ci]);
        }
    }
    std::printf("minimal two-term failures %d /405\n",minimalbad);
    return inputbad!=0;
}
