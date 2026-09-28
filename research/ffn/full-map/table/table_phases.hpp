#pragma once
#include "weights.hpp"
#include "phases.hpp"

namespace halo {
namespace {
constexpr int LUT_GROUPS=kelana_table::GROUPS;
constexpr int LUT_ROWS=kelana_table::ROWS;
constexpr int LUT_BIAS=LUT_GROUPS*384;

template<int TT>
__device__ __forceinline__ void ph_linear_tables(Ctx &c,const int8_t *xq,int nb,unsigned *table,int nrows) {
    constexpr int NP=(TT+1)/2;
    int lane=threadIdx.x&31,wave=threadIdx.x>>5;
    int code=lane<27?lane:13;
    int w0=code%3-1,w1=(code/3)%3-1,w2=code/9-1;
    int total=nb*6;
    for(int unit=blockIdx.x;unit>=0 && unit<total;unit=next_unit(c,total)) {
        c.dirty=true;
        int block=unit/6,group=(unit%6)*8+wave;
        if(group<LUT_GROUPS) {
            #pragma unroll
            for(int p=0;p<NP;++p) {
                int sums[2]={0,0};
                #pragma unroll
                for(int t=0;t<2;++t) {
                    int row=p*2+t;
                    if(row<nrows) {
                        const int8_t *v=xq+size_t(row)*nb*128+block*128+group*3;
                        int a=v[0],b=v[1],d=group*3+2<128?v[2]:0;
                        sums[t]=w0*a+w1*b+w2*d;
                    }
                }
                table[((size_t(block)*LUT_GROUPS+group)*32+lane)*NP+p]=
                    unsigned(sums[0]+384) | (unsigned(sums[1]+384)<<16);
            }
        }
        __syncthreads();
    }
    end_phase(c);
}

template<int TT>
__device__ __forceinline__ void table_values(const unsigned *p,unsigned (&v)[(TT+1)/2]) {
    if constexpr(TT==8) {
        uint4 t=*(const uint4 *)p; v[0]=t.x;v[1]=t.y;v[2]=t.z;v[3]=t.w;
    } else if constexpr(TT<=2) v[0]=*p;
    else { uint2 t=*(const uint2*)p; v[0]=t.x;v[1]=t.y; }
}

template<int NB,int KS,int TT,int OUTPUTS,bool FUSED,bool CAPTURE=false>
__device__ __forceinline__ void ph_table_projection(Ctx &c,const uint8_t *weights,
        const unsigned *table,const float *xs,const float *signs,float *output,int nrows,
        float *capture_gate=nullptr,float *capture_up=nullptr) {
    constexpr int NP=(TT+1)/2, RF=LUT_ROWS/32, NTILES=OUTPUTS/LUT_ROWS;
    using G=Geom<NB,KS>;
    int lane=threadIdx.x&31,wave=__builtin_amdgcn_readfirstlane(threadIdx.x>>5);
    for(int unit=blockIdx.x;unit>=0 && unit<NTILES*KS;unit=next_unit(c,NTILES*KS)) {
        c.dirty=true;
        int part=unit/NTILES,tile=unit%NTILES;
        int pw=part==0 || !G::SPECIAL?G::PW_A:G::PW_B;
        int wb=(part==0?0:(G::SPECIAL?G::A_BLOCKS:part*G::PART))+wave*pw;
        float y[RF][TT]={};
        #pragma unroll 1
        for(int b=0;b<pw;++b) {
            int block=wb+b;
            const uint8_t *w=weights+(size_t(tile)*NB+block)*kelana_table::BLOCK_BYTES;
            unsigned words[RF][7]; float scale[RF];
            #pragma unroll
            for(int r=0;r<RF;++r) {
                #pragma unroll
                for(int j=0;j<7;++j) words[r][j]=*(const unsigned *)(w+(j*LUT_ROWS+r*32+lane)*4);
                unsigned sc=(words[r][6]>>23) | (unsigned(w[7*LUT_ROWS*4+r*32+lane])<<9);
                scale[r]=__half2float(__ushort_as_half(sc));
            }
            unsigned acc[RF][NP]={};
            #pragma unroll
            for(int group=0;group<LUT_GROUPS;++group) {
                constexpr int dummy=0; (void)dummy;
                int bit=group*5,word=bit/32,shift=bit%32;
                #pragma unroll
                for(int r=0;r<RF;++r) {
                    unsigned index=words[r][word]>>shift;
                    if(shift>27) index|=words[r][word+1]<<(32-shift);
                    index&=31;
                    unsigned value[NP];
                    table_values<TT>(table+((size_t(block)*LUT_GROUPS+group)*32+index)*NP,value);
                    #pragma unroll
                    for(int p=0;p<NP;++p) acc[r][p]+=value[p];
                }
            }
            #pragma unroll
            for(int r=0;r<RF;++r) {
                #pragma unroll
                for(int t=0;t<TT;++t) {
                    int result=int((acc[r][t/2]>>(16*(t&1)))&65535)-LUT_BIAS;
                    y[r][t]=fmaf(float(result),scale[r]*xs[t*NB+block],y[r][t]);
                }
            }
        }
        #pragma unroll
        for(int r=0;r<RF;++r) {
            if(wave>0) {
                #pragma unroll
                for(int t=0;t<TT;++t) c.lds[((wave-1)*TT+t)*32+lane]=y[r][t];
            }
            __syncthreads();
            if(wave==0) {
                #pragma unroll
                for(int t=0;t<TT;++t) if(t<nrows) {
                    float v=y[r][t];
                    #pragma unroll
                    for(int w=1;w<NW;++w) v+=c.lds[((w-1)*TT+t)*32+lane];
                    int row=tile*LUT_ROWS+r*32+lane;
                    if constexpr(FUSED) {
                        float other=__int_as_float(__builtin_amdgcn_update_dpp(0,__float_as_int(v),0xb1,15,15,true));
                        int hidden=row/2;
                        if constexpr(CAPTURE) {
                            float *dst=(lane&1)?capture_up:capture_gate;
                            dst[size_t(t)*(OUTPUTS/2)+hidden]=v;
                        }
                        if(!(lane&1)) output[size_t(t)*(OUTPUTS/2)+hidden]=silu(v)*other*signs[hidden];
                    } else {
                        if constexpr(KS>1) atomicAdd(output+size_t(t)*OUTPUTS+row,v);
                        else output[size_t(t)*OUTPUTS+row]+=v;
                    }
                }
            }
            __syncthreads();
        }
    }
    end_phase(c);
}
}
}
