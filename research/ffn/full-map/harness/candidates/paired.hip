#include "../ffn_harness.h"
#include "../../paired_phases.hpp"
#include "../../paired_load.hpp"
#include <cstdio>
#include <cstdlib>

using namespace halo;
namespace {
struct Params {
    const uint8_t *pairs, *down;
    const float *norm, *signs;
    kffn::Work work;
    int nrows;
};
struct State { uint8_t *pairs; };

template<bool CAPTURE>
__global__ __launch_bounds__(NT, 8) void kernel(Params p) {
    __shared__ __attribute__((aligned(16))) float lds[LDS_FLOATS];
    __shared__ float red[8];
    __shared__ int unit;
    const auto &w = p.work;
    Ctx c{w.bar,w.work,w.prof,0,0,true,lds,red,&unit};
    auto *planes = static_cast<_Float16 *>(w.scratch);
    float *hidden = reinterpret_cast<float *>(planes + 16 * D);
    if (w.prof && blockIdx.x == 0 && threadIdx.x == 0) w.prof[0] = wall_clock64();
    {
        PrepR a{}; a.x=w.x; a.kvec=p.norm; a.eps=NORM_EPS; a.n=D; a.xs=w.xs;
        ph_pair_prep(c,a,planes,p.nrows);
    }
    grid_sync(c);
    ph_pair_gate_up<NB_D,FF,CAPTURE>(c,p.pairs,planes,w.xs,p.signs,hidden,p.nrows,
                                    w.gu,w.gu+RMAX*FF);
    grid_sync(c);
    {
        PrepR a{}; a.x=hidden; a.n=FF; a.flags=PREP_HADAMARD|PREP_QUANT;
        a.xq=w.xq; a.xs=w.xs; a.xsum=w.xsum;
        ph_prep(c,a,p.nrows);
    }
    grid_sync(c);
    {
        MvR m{}; m.nseg=1; m.seg[0]={p.down,w.x,D/32,1}; m.total_tiles=D/32;
        if (p.nrows <= 1) ph_matvec_auto<NB_FF,2,1,false>(c,m,w.xq,w.xs,w.xsum,p.nrows);
        else ph_matvec_auto<NB_FF,2,8,false>(c,m,w.xq,w.xs,w.xsum,p.nrows);
    }
    grid_sync(c);
}
void check(hipError_t e) { if(e != hipSuccess) { std::fprintf(stderr,"paired: %s\n",hipGetErrorString(e)); std::abort(); } }
void *prepare(const kffn::Shape &s,const kffn::Weights &w) {
    if(s.D!=D || s.FF!=FF || s.rmax!=RMAX) std::abort();
    auto packed=kelana_ffn::pack_pair_from_halo(w.gate_host,w.up_host,FF,D);
    auto *state=new State{};
    check(hipMalloc(&state->pairs,packed.size()));
    check(hipMemcpy(state->pairs,packed.data(),packed.size(),hipMemcpyHostToDevice));
    return state;
}
void release(void *p) { auto *s=static_cast<State*>(p); check(hipFree(s->pairs)); delete s; }
template<bool CAPTURE> int grid(int) { static int n=coop_grid((const void*)kernel<CAPTURE>); return n; }
template<bool CAPTURE>
void run(void *state,const kffn::Shape &,const kffn::Weights &w,const kffn::Work &k,int nrows,hipStream_t stream) {
    if(k.scratch_bytes < 16*D*sizeof(_Float16)+RMAX*FF*sizeof(float)) std::abort();
    Params p{static_cast<State*>(state)->pairs,w.down,w.post_norm_s,w.signs_ff,k,nrows};
    void *args[]={&p};
    check(hipLaunchCooperativeKernel((const void*)kernel<CAPTURE>,dim3(k.grid),dim3(NT),args,0,stream));
}
const char *instruction(int n) { return n<=1 ? "paired-f16-gate-up/sudot4-down" : "paired-f16-gate-up/iu8-down"; }
const char *const stages[]={"prep_digit_planes","paired_gate_up_silu","prep_hidden_quant","mv_down"};
size_t weight_bytes(const kffn::Shape &s,int) {
    return size_t(s.FF/16)*(s.D/128)*kelana_ffn::PAIR_BLOCK_BYTES + halo_tensor_bytes(s.D,s.FF);
}
template<bool CAPTURE> kffn::Candidate make() {
    kffn::Candidate c{};
    c.name=CAPTURE?"paired-capture":"paired";
    c.emits_gate_up=CAPTURE; c.emits_ff_quant=true;
    c.stages=stages; c.nstages=4; c.grid=grid<CAPTURE>; c.instruction=instruction;
    c.prepare=prepare; c.run=run<CAPTURE>; c.release=release; c.weight_bytes=weight_bytes;
    return c;
}
kffn::Candidate paired(){return make<false>();}
kffn::Candidate paired_capture(){return make<true>();}
}
KFFN_REGISTER(paired)
KFFN_REGISTER(paired_capture)
