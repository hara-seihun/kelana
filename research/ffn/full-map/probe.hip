#include "paired_phases.hpp"
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#define HIP(call) do { hipError_t e = (call); if (e != hipSuccess) { std::fprintf(stderr, "%s: %s\n", #call, hipGetErrorString(e)); std::exit(1); } } while (0)

template<class T> T *upload(const std::vector<T> &v) {
    T *p; HIP(hipMalloc(&p, v.size() * sizeof(T)));
    HIP(hipMemcpy(p, v.data(), v.size() * sizeof(T), hipMemcpyHostToDevice)); return p;
}
__global__ void codec_probe(unsigned long long *out) {
    int n = blockIdx.x * blockDim.x + threadIdx.x;
    if (n >= 6561) return;
    int t = n; unsigned codes = 0;
    for (int i = 0; i < 4; ++i) {
        int d = t % 9; t /= 9; codes |= (d == 8 ? 12 : d) << (4 * i);
    }
    uint2 v = kelana_ffn::decode_four(codes);
    out[n] = (static_cast<unsigned long long>(v.y) << 32) | v.x;
}
__global__ __launch_bounds__(256, 1) void pair_probe(const uint8_t *w, const _Float16 *p,
        const float *xs, const float *signs, float *h, float *g, float *u, unsigned *work) {
    __shared__ float lds[halo::LDS_FLOATS], red[8];
    __shared__ int unit;
    halo::Ctx c = {nullptr, work, nullptr, 0, 0, false, lds, red, &unit};
    halo::ph_pair_gate_up<8, 16, true>(c, w, p, xs, signs, h, 8, g, u);
}
int main() {
    constexpr int K = 1024, H = 16, T = 8, NB = 8;
    std::vector<unsigned long long> lut(6561);
    auto dlut = upload(lut);
    codec_probe<<<26, 256>>>(dlut); HIP(hipGetLastError());
    HIP(hipMemcpy(lut.data(), dlut, lut.size() * 8, hipMemcpyDeviceToHost));
    for (int n = 0; n < 6561; ++n) {
        int t = n; unsigned long long want = 0;
        for (int j = 0; j < 4; ++j) { want |= (unsigned long long)kelana_ffn::PAIR_HALF[t % 9] << (16*j); t /= 9; }
        if (lut[n] != want) { std::printf("codec failure %d: %llx != %llx\n", n, lut[n], want); return 1; }
    }
    std::vector<int8_t> g(H*K), u(H*K), q(T*K);
    std::vector<uint16_t> gs(H*NB), us(H*NB);
    std::vector<float> xs(T*NB), signs(H), zero(T*H, 0.0f);
    std::vector<_Float16> planes(2*T*K);
    uint32_t state = 1234567;
    auto next = [&] { state ^= state << 13; state ^= state >> 17; state ^= state << 5; return state; };
    for (int r = 0; r < H; ++r) {
        signs[r] = r & 1 ? -1.f : 1.f;
        for (int k = 0; k < K; ++k) { g[r*K+k] = int(next()%3)-1; u[r*K+k] = int(next()%3)-1; }
        for (int b = 0; b < NB; ++b) { gs[r*NB+b] = 0x3000 + 128*((r+b)%8); us[r*NB+b] = 0x3400 + 64*((r+3*b)%16); }
    }
    for (int t = 0; t < T; ++t) {
        for (int b = 0; b < NB; ++b) xs[t*NB+b] = float(t+b+1)/128.f;
        for (int k = 0; k < K; ++k) {
            int v = t == 0 ? 127 : t == 1 ? -128 : t == 2 ? 8 : t == 3 ? ((k&1)?127:-128) : int(next()&255)-128;
            q[t*K+k] = v;
            int low = ((v+8)&15)-8;
            planes[t*K+k] = (_Float16)low; planes[(T+t)*K+k] = (_Float16)((v-low)/16);
        }
    }
    auto w = kelana_ffn::pack_pair_weights(g.data(), u.data(), gs.data(), us.data(), H, K);
    auto dw=upload(w); auto dp=upload(planes); auto dxs=upload(xs); auto ds=upload(signs);
    auto dh=upload(zero), dg=upload(zero), du=upload(zero);
    auto work=upload(std::vector<unsigned>(1,0));
    pair_probe<<<1,256>>>(dw,dp,dxs,ds,dh,dg,du,work); HIP(hipGetLastError());
    std::vector<float> gotG(T*H),gotU(T*H),gotH(T*H);
    HIP(hipMemcpy(gotG.data(),dg,zero.size()*4,hipMemcpyDeviceToHost));
    HIP(hipMemcpy(gotU.data(),du,zero.size()*4,hipMemcpyDeviceToHost));
    HIP(hipMemcpy(gotH.data(),dh,zero.size()*4,hipMemcpyDeviceToHost));
    int wrong=0; float maxHiddenRel=0;
    for (int t=0;t<T;++t) for(int r=0;r<H;++r) {
        float gr=0,ur=0;
        for(int b=0;b<NB;++b) {
            int gi=0,ui=0;
            for(int k=0;k<128;++k) { int j=b*128+k; gi+=g[r*K+j]*q[t*K+j]; ui+=u[r*K+j]*q[t*K+j]; }
            _Float16 gh,uh; std::memcpy(&gh,&gs[r*NB+b],2); std::memcpy(&uh,&us[r*NB+b],2);
            float gg=std::fma(float(gi),float(gh)*xs[t*NB+b],0.f);
            float uu=std::fma(float(ui),float(uh)*xs[t*NB+b],0.f);
            if (b==0) { gr=gg; ur=uu; } else { gr+=gg; ur+=uu; }
        }
        int o=t*H+r;
        if(gotG[o]!=gr || gotU[o]!=ur) { if(wrong<8) std::printf("pair mismatch [%d,%d] %a/%a expected %a/%a\n",t,r,gotG[o],gotU[o],gr,ur); ++wrong; }
        float hr=(gr/(1.f+std::exp(-gr)))*ur*signs[r];
        maxHiddenRel=std::fmax(maxHiddenRel,std::fabs(hr-gotH[o])/std::fmax(1.f,std::fabs(hr)));
    }
    std::printf("codec 6561 exact; gate/up %d/256 wrong; hidden CPU-exp relative max %.9g\n",2*wrong,maxHiddenRel);
    for (void *p : std::initializer_list<void*>{dlut,dw,dp,dxs,ds,dh,dg,du,work}) HIP(hipFree(p));
    return wrong ? 1 : 0;
}
