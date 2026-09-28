#include "weights.hpp"
#include <cassert>
#include <cstdio>

int main(){
    constexpr int N=128,K=256,NB=K/128;
    std::vector<uint8_t> halo(halo::halo_tensor_bytes(N,K),0);
    std::vector<int8_t> trits(N*K);
    uint32_t rng=72361;
    auto next=[&]{rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;};
    for(int row=0;row<N;++row) for(int b=0;b<NB;++b){
        uint8_t t[128],qs[24],qh[2];
        for(int k=0;k<128;++k){t[k]=next()%3;trits[row*K+b*128+k]=int(t[k])-1;}
        halo::encode_block(t,qs,qh);
        auto *dst=halo.data()+(size_t(row/32)*NB+b)*halo::TILE_BLOCK_BYTES;
        int lane=row%32;
        std::memcpy(dst+halo::tile_off_qs_a(lane),qs,16);
        std::memcpy(dst+halo::tile_off_qs_b(lane),qs+16,8);
        std::memcpy(dst+halo::tile_off_tail(lane),qh,2);
        uint16_t sc=uint16_t(next());std::memcpy(dst+halo::tile_off_tail(lane)+2,&sc,2);
    }
    auto packed=kelana_table::pack(halo.data(),nullptr,N,K);
    unsigned tested=0;
    for(int row=0;row<N;++row) for(int b=0;b<NB;++b){
        auto *src=packed.data()+b*kelana_table::BLOCK_BYTES;
        uint32_t words[7];
        for(int j=0;j<7;++j)std::memcpy(&words[j],src+(j*N+row)*4,4);
        uint16_t sc=(words[6]>>23)|(unsigned(src[7*N*4+row])<<9);
        uint16_t original;
        std::memcpy(&original,halo.data()+(size_t(row/32)*NB+b)*halo::TILE_BLOCK_BYTES+halo::tile_off_tail(row%32)+2,2);
        assert(sc==original);
        int x[2][129]={};
        for(int c=0;c<2;++c)for(int k=0;k<128;++k)x[c][k]=int(next()%256)-128;
        unsigned accumulator=0;
        int reference[2]={};
        for(int group=0;group<43;++group){
            int bit=group*5,word=bit/32,shift=bit%32;
            unsigned code=words[word]>>shift;
            if(shift>27)code|=words[word+1]<<(32-shift);
            code&=31; assert(code<27);
            int w[3]={int(code%3)-1,int((code/3)%3)-1,int(code/9)-1};
            int sum[2]={};
            for(int j=0;j<3;++j){
                int k=group*3+j;
                assert(w[j]==(k<128?trits[row*K+b*128+k]:0));
                for(int c=0;c<2;++c){sum[c]+=w[j]*x[c][k];reference[c]+=w[j]*x[c][k];}
            }
            unsigned value=unsigned(sum[0]+384)|(unsigned(sum[1]+384)<<16);
            accumulator+=value;
            ++tested;
        }
        assert(int(accumulator&65535)-43*384==reference[0]);
        assert(int(accumulator>>16)-43*384==reference[1]);
    }
    auto interleaved=kelana_table::pack(halo.data(),halo.data(),2*N,K);
    assert(interleaved.size()==2*packed.size());
    std::printf("%u triplets, 256 scale fields and 512 packed sums exact\n",tested);
}
