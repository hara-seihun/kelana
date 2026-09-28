#pragma once
#include "../paired_load.hpp"
namespace kelana_table {
constexpr int GROUPS=43, ROWS=128, WORDS=7;
constexpr int BLOCK_BYTES=ROWS*(WORDS*4+1);
inline std::vector<uint8_t> pack(const uint8_t *first,const uint8_t *second,int outputs,int kdim) {
    if(outputs%ROWS || kdim%128) throw std::runtime_error("table weight geometry");
    int nb=kdim/128;
    std::vector<uint8_t> out(size_t(outputs/ROWS)*nb*BLOCK_BYTES,0);
    for(int tile=0;tile<outputs/ROWS;++tile) for(int b=0;b<nb;++b) {
        uint8_t *dst=out.data()+(size_t(tile)*nb+b)*BLOCK_BYTES;
        for(int r=0;r<ROWS;++r) {
            int virtual_row=tile*ROWS+r;
            int source_row=second?virtual_row/2:virtual_row;
            auto *source=second && (virtual_row&1)?second:first;
            size_t off=(size_t(source_row/32)*nb+b)*halo::TILE_BLOCK_BYTES;
            int8_t trits[128]; uint16_t scale;
            kelana_ffn::decode_halo_row(source+off,source_row%32,trits,scale);
            uint32_t words[WORDS]={};
            for(int g=0;g<GROUPS;++g) {
                unsigned code=0,power=1;
                for(int j=0;j<3;++j) {
                    int k=g*3+j, t=k<128?trits[k]:0;
                    if(t < -1 || t > 1) throw std::runtime_error("nonternary table weight");
                    code+=(t+1)*power; power*=3;
                }
                int bit=g*5, word=bit/32, shift=bit%32;
                words[word]|=code<<shift;
                if(shift>27) words[word+1]|=code>>(32-shift);
            }
            words[6]|=unsigned(scale&511)<<23;
            for(int j=0;j<WORDS;++j) std::memcpy(dst+(j*ROWS+r)*4,&words[j],4);
            dst[WORDS*ROWS*4+r]=scale>>9;
        }
    }
    return out;
}
}
