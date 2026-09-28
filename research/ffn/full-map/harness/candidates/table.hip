#include "../ffn_harness.h"
#include "../../table/table_phases.hpp"
#include <cstdio>
#include <cstdlib>
using namespace halo;
namespace {
struct State { uint8_t *gu,*down; };
struct Params { const uint8_t *gu,*down,*baseline_down;const float *norm,*signs;kffn::Work work;int nrows; };
template<int TT,bool BOTH,bool CAPTURE>
__global__ __launch_bounds__(NT,8) void kernel(Params p) {
    __shared__ __attribute__((aligned(16))) float lds[LDS_FLOATS];
    __shared__ float red[8]; __shared__ int unit;
    const auto &w=p.work;
    Ctx c{w.bar,w.work,w.prof,0,0,true,lds,red,&unit};
    auto *table=static_cast<unsigned*>(w.scratch);
    float *hidden=reinterpret_cast<float*>(table+size_t(NB_FF)*43*32*4);
    if(w.prof && blockIdx.x==0 && threadIdx.x==0) w.prof[0]=wall_clock64();
    { PrepR a{};a.x=w.x;a.kvec=p.norm;a.n=D;a.eps=NORM_EPS;
      a.flags=PREP_NORM|PREP_HADAMARD|PREP_QUANT;a.xq=w.xq;a.xs=w.xs;a.xsum=w.xsum;
      ph_prep(c,a,p.nrows); }
    grid_sync(c);
    ph_linear_tables<TT>(c,w.xq,NB_D,table,p.nrows);
    grid_sync(c);
    ph_table_projection<NB_D,1,TT,2*FF,true,CAPTURE>(c,p.gu,table,w.xs,p.signs,hidden,p.nrows,w.gu,w.gu+RMAX*FF);
    grid_sync(c);
    { PrepR a{};a.x=hidden;a.n=FF;a.flags=PREP_HADAMARD|PREP_QUANT;
      a.xq=w.xq;a.xs=w.xs;a.xsum=w.xsum;ph_prep(c,a,p.nrows); }
    grid_sync(c);
    if constexpr(BOTH) {
        ph_linear_tables<TT>(c,w.xq,NB_FF,table,p.nrows);
        grid_sync(c);
        ph_table_projection<NB_FF,2,TT,D,false>(c,p.down,table,w.xs,nullptr,w.x,p.nrows);
    } else {
        MvR m{};m.nseg=1;m.seg[0]={p.baseline_down,w.x,D/32,1};m.total_tiles=D/32;
        ph_matvec_auto<NB_FF,2,TT,false>(c,m,w.xq,w.xs,w.xsum,p.nrows);
    }
    grid_sync(c);
}
void check(hipError_t e){if(e!=hipSuccess){std::fprintf(stderr,"table: %s\n",hipGetErrorString(e));std::abort();}}
uint8_t *upload(const std::vector<uint8_t>&v){uint8_t *p;check(hipMalloc(&p,v.size()));check(hipMemcpy(p,v.data(),v.size(),hipMemcpyHostToDevice));return p;}
void *prepare(const kffn::Shape&s,const kffn::Weights&w){
    if(s.D!=D || s.FF!=FF || s.rmax!=RMAX)std::abort();
    auto *v=new State{};
    v->gu=upload(kelana_table::pack(w.gate_host,w.up_host,2*FF,D));
    v->down=upload(kelana_table::pack(w.down_host,nullptr,D,FF));
    return v;
}
void release(void*p){auto*v=static_cast<State*>(p);check(hipFree(v->gu));check(hipFree(v->down));delete v;}
template<bool BOTH,bool CAPTURE> const void *function(int n){return n<=1?(const void*)kernel<1,BOTH,CAPTURE>:(const void*)kernel<8,BOTH,CAPTURE>;}
template<bool BOTH,bool CAPTURE> int grid(int n){return coop_grid(function<BOTH,CAPTURE>(n));}
template<bool BOTH,bool CAPTURE>
void run(void*state,const kffn::Shape&,const kffn::Weights&w,const kffn::Work&k,int n,hipStream_t stream){
    if(k.scratch_bytes<size_t(NB_FF)*43*32*4*4+RMAX*FF*4)std::abort();
    auto*v=static_cast<State*>(state);
    Params p{v->gu,v->down,w.down,w.post_norm_s,w.signs_ff,k,n};void *args[]={&p};
    check(hipLaunchCooperativeKernel(function<BOTH,CAPTURE>(n),dim3(k.grid),dim3(NT),args,0,stream));
}
const char *instruction(int){return "ternary-linear-form-lookup/packed-u16-add";}
const char *const stages_all[]={"prep_post_norm","tables_input","table_gate_up_silu","prep_hidden_quant","tables_hidden","table_down"};
const char *const stages_gate[]={"prep_post_norm","tables_input","table_gate_up_silu","prep_hidden_quant","mv_down"};
template<bool BOTH> size_t bytes(const kffn::Shape&s,int){
    size_t gu=size_t(2*s.FF/128)*(s.D/128)*kelana_table::BLOCK_BYTES;
    return gu+(BOTH?size_t(s.D/128)*(s.FF/128)*kelana_table::BLOCK_BYTES:halo_tensor_bytes(s.D,s.FF));
}
template<bool BOTH,bool CAPTURE> kffn::Candidate make(){
    kffn::Candidate c{};
    c.name=BOTH?(CAPTURE?"table-capture":"table"):(CAPTURE?"table-gate-capture":"table-gate");
    c.emits_gate_up=CAPTURE;c.emits_ff_quant=true;c.nstages=BOTH?6:5;c.stages=BOTH?stages_all:stages_gate;
    c.grid=grid<BOTH,CAPTURE>;c.instruction=instruction;c.prepare=prepare;c.run=run<BOTH,CAPTURE>;c.release=release;c.weight_bytes=bytes<BOTH>;
    return c;
}
kffn::Candidate table(){return make<true,false>();}
kffn::Candidate table_capture(){return make<true,true>();}
kffn::Candidate table_gate(){return make<false,false>();}
kffn::Candidate table_gate_capture(){return make<false,true>();}
}
KFFN_REGISTER(table)
KFFN_REGISTER(table_capture)
KFFN_REGISTER(table_gate)
KFFN_REGISTER(table_gate_capture)
