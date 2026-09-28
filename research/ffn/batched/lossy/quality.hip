#include "policy.hpp"
#include "phases.hpp"
#include "../consumer-polynomial/consumer.hpp"
#include <cstdio>
#include <cstdlib>
namespace {
__constant__ QuantPolicy policy;
__device__ unsigned quant_counts[64], consumer_counts[64];
__device__ __forceinline__ unsigned hash32(unsigned x) {
    x ^= x >> 16; x *= 0x7feb352du; x ^= x >> 15; x *= 0x846ca68bu; return x ^ (x >> 16);
}
}
namespace halo {
namespace {
__device__ __forceinline__ void lossy_ffn_prep(Ctx &c,const PrepR &a,int nrows) {
    bool hidden = c.gen>=10 && (c.gen-10)%10==0 && a.n==FF &&
                  a.flags==(PREP_SILU_MUL|PREP_HADAMARD|PREP_QUANT);
    bool down = policy.down && hidden;
    bool input = c.gen>=8 && (c.gen-8)%10==0 && a.n==D &&
                 a.flags==(PREP_NORM|PREP_HADAMARD|PREP_QUANT);
    int layer = input ? int((c.gen-8)/10) : hidden ? int((c.gen-10)/10) : -1;
    bool quantize = policy.bits<8 && (input || down);
    bool consumer = policy.consumer && hidden;
    if(layer<0 || layer>=64 || !(policy.layers & (uint64_t(1)<<layer)) || (!quantize && !consumer)) {
        ph_prep(c,a,nrows);
        return;
    }
    int chunks=a.n/1024,total=nrows*chunks,tid=threadIdx.x,lane=tid&31,wave=tid>>5;
    int limit=(1<<(policy.bits-1))-1;
    for(int u=blockIdx.x;u>=0 && u<total;u=next_unit(c,total)) {
        c.dirty=true;
        int row=u/chunks,chunk=u%chunks;
        float inv=1.f;
        if(input) {
            const float *x=a.x+size_t(row)*a.n;
            float ss=0;
            for(int i=tid*4;i<a.n;i+=NT*4) {
                float4 v=*(const float4*)(x+i);
                ss=fmaf(v.x,v.x,ss);ss=fmaf(v.y,v.y,ss);ss=fmaf(v.z,v.z,ss);ss=fmaf(v.w,v.w,ss);
            }
            ss=block_sum_256(ss,c.red);
            inv=rsqrtf(ss/float(a.n)+a.eps);
        }
        PrepR work=a;
        if(consumer) {
            size_t at=size_t(row)*a.n+chunk*1024+tid*4;
            float4 g=*(const float4*)(a.x+at), u=*(const float4*)(a.x2+at);
            float4 h=make_float4(kelana_consumer::consume(g.x,u.x,policy.consumer),
                kelana_consumer::consume(g.y,u.y,policy.consumer),
                kelana_consumer::consume(g.z,u.z,policy.consumer),
                kelana_consumer::consume(g.w,u.w,policy.consumer));
            *(float4*)(const_cast<float*>(a.x)+at)=h;
            __syncthreads();
            work.flags=(a.flags & ~PREP_SILU_MUL)|PREP_SIGN;
            if(tid==0)atomicAdd(consumer_counts+layer,1u);
        }
        prep_chunk_r(work,row,chunk,inv,c.lds,0);
        __syncthreads();
        if(!quantize) continue;
        int base=chunk*1024+wave*128+lane*4;
        int8_t *q=a.xq+size_t(row)*a.n+base;
        float4 transformed=*(const float4*)(c.lds+wave*128+lane*4);
        float amax=warp_max(fmaxf(fmaxf(fabsf(transformed.x),fabsf(transformed.y)),
                                 fmaxf(fabsf(transformed.z),fabsf(transformed.w))));
        float direct_iscale=amax>0 ? float(limit)/amax : 0.f;
        int sum=0;
        #pragma unroll
        for(int j=0;j<4;++j) {
            int original=q[j],value;
            if(policy.direct) {
                value=__float2int_rn((&transformed.x)[j]*direct_iscale);
                value=max(-limit,min(limit,value));
            } else if(policy.stochastic) {
                int numerator=original*limit;
                int low=numerator/127,rem=numerator%127;
                if(rem<0){--low;rem+=127;}
                unsigned key=policy.seed ^ (policy.sample*0x9e3779b9u) ^ (unsigned(layer)*0x85ebca6bu)
                    ^ unsigned(row*a.n+base+j);
                unsigned random=hash32(key);
                value=low+(uint64_t(random)*127 < (uint64_t(unsigned(rem))<<32));
            } else {
                int magnitude=original<0?-original:original;
                value=(magnitude*limit+63)/127;
                if(original<0)value=-value;
            }
            q[j]=int8_t(value);sum+=value;
        }
        sum=warp_sum_i(sum);
        if(lane==0) {
            int index=row*(a.n/128)+base/128;
            if(policy.direct) a.xs[index]=amax/float(limit);
            else a.xs[index]*=127.f/float(limit);
            a.xsum[index]=sum;
        }
        if(tid==0)atomicAdd(quant_counts+layer,1u);
        __syncthreads();
    }
    end_phase(c);
}
}
}

// The engine links this translation unit in place of halo_rows.o. Including the
// unchanged upstream source keeps attention, state, head and barrier ordering intact.
#define ph_prep lossy_ffn_prep
#include "halo_rows.hip"
#undef ph_prep

namespace {
void check(hipError_t e){if(e!=hipSuccess){std::fprintf(stderr,"quality policy: %s\n",hipGetErrorString(e));std::abort();}}
}
void set_quant_policy(QuantPolicy p){check(hipMemcpyToSymbol(HIP_SYMBOL(policy),&p,sizeof(p)));}
void reset_quant_counts(){unsigned zero[64]={};check(hipMemcpyToSymbol(HIP_SYMBOL(quant_counts),zero,sizeof(zero)));check(hipMemcpyToSymbol(HIP_SYMBOL(consumer_counts),zero,sizeof(zero)));}
void read_quant_counts(unsigned (&c)[64]){check(hipMemcpyFromSymbol(c,HIP_SYMBOL(quant_counts),sizeof(c)));}
void read_consumer_counts(unsigned (&c)[64]){check(hipMemcpyFromSymbol(c,HIP_SYMBOL(consumer_counts),sizeof(c)));}
