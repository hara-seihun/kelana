#include "paired_load.hpp"
#include <array>
#include <cassert>
#include <cstdio>

static unsigned perm(unsigned high, unsigned low, unsigned selectors) {
    uint64_t x = (uint64_t(high) << 32) | low;
    unsigned out = 0;
    for (int i = 0; i < 4; ++i) {
        unsigned s = (selectors >> (8 * i)) & 255;
        unsigned b = s < 8 ? (x >> (8 * s)) & 255 :
            s < 12 ? ((x >> (8 * (2 * (s - 8) + 1) + 7)) & 1) * 255 :
            s == 12 ? 0 : 255;
        out |= b << (8 * i);
    }
    return out;
}
int main() {
    unsigned checks = 0;
    for (int n = 0; n < 6561; ++n) {
        int t = n; unsigned codes = 0; uint64_t expected = 0;
        for (int i = 0; i < 4; ++i) {
            int d = t % 9; t /= 9;
            unsigned c = d == 8 ? 12 : d;
            codes |= c << (4 * i);
            expected |= uint64_t(kelana_ffn::PAIR_HALF[d]) << (16 * i);
        }
        unsigned s = (codes | (codes << 8)) & 0x00ff00ffu;
        s = (s | (s << 4)) & 0x0f0f0f0fu;
        unsigned lo = perm(0x00fffe00u, 0x00feff00u, s);
        unsigned hi = perm(0x6867673cu, 0xbce7e7e8u, s);
        uint64_t actual = perm(hi, lo, 0x05010400u);
        actual |= uint64_t(perm(hi, lo, 0x07030602u)) << 32;
        assert(actual == expected);
        ++checks;
    }
    std::array<int8_t, 16 * 128> g, u;
    std::array<uint16_t, 16> gs, us;
    for (int r = 0; r < 16; ++r) {
        gs[r] = 0x3c00 + r; us[r] = 0x4000 + r;
        for (int k = 0; k < 128; ++k) {
            g[r * 128 + k] = (k + r) % 3 - 1;
            u[r * 128 + k] = ((k + r) / 3) % 3 - 1;
        }
    }
    auto packed = kelana_ffn::pack_pair_weights(g.data(), u.data(), gs.data(), us.data(), 16, 128);
    assert(packed.size() == 1088);
    for (int r = 0; r < 16; ++r) {
        for (int k = 0; k < 128; ++k) {
            unsigned code = (packed[(k / 16) * 128 + r * 8 + k % 16 / 2] >> (4 * (k & 1))) & 15;
            assert(code == kelana_ffn::pair_code(g[r * 128 + k], u[r * 128 + k]));
        }
        uint16_t sg, su;
        std::memcpy(&sg, packed.data() + 1024 + r * 4, 2);
        std::memcpy(&su, packed.data() + 1026 + r * 4, 2);
        assert(sg == gs[r] && su == us[r]);
    }
    constexpr int H = 32, K = 256, NB = K / 128;
    std::vector<int8_t> gg(H*K), uu(H*K);
    std::vector<uint16_t> ggs(H*NB), uus(H*NB);
    std::vector<uint8_t> haloG(NB*halo::TILE_BLOCK_BYTES,0), haloU(haloG.size(),0);
    for (int r=0;r<H;++r) for(int b=0;b<NB;++b) {
        uint8_t gt[128],ut[128],gqs[24],uqs[24],gqh[2],uqh[2];
        for(int k=0;k<128;++k) {
            gt[k]=(k+7*r+2*b)%3; ut[k]=((k+2*r)/3+b)%3;
            gg[r*K+b*128+k]=int(gt[k])-1; uu[r*K+b*128+k]=int(ut[k])-1;
        }
        ggs[r*NB+b]=0x3000+r+b; uus[r*NB+b]=0x3400+r+b;
        halo::encode_block(gt,gqs,gqh); halo::encode_block(ut,uqs,uqh);
        auto *hg=haloG.data()+b*halo::TILE_BLOCK_BYTES;
        auto *hu=haloU.data()+b*halo::TILE_BLOCK_BYTES;
        std::memcpy(hg+halo::tile_off_qs_a(r),gqs,16); std::memcpy(hu+halo::tile_off_qs_a(r),uqs,16);
        std::memcpy(hg+halo::tile_off_qs_b(r),gqs+16,8); std::memcpy(hu+halo::tile_off_qs_b(r),uqs+16,8);
        std::memcpy(hg+halo::tile_off_tail(r),gqh,2); std::memcpy(hu+halo::tile_off_tail(r),uqh,2);
        std::memcpy(hg+halo::tile_off_tail(r)+2,&ggs[r*NB+b],2);
        std::memcpy(hu+halo::tile_off_tail(r)+2,&uus[r*NB+b],2);
    }
    assert(kelana_ffn::pack_pair_from_halo(haloG.data(),haloU.data(),H,K) ==
           kelana_ffn::pack_pair_weights(gg.data(),uu.data(),ggs.data(),uus.data(),H,K));
    std::printf("%u exhaustive LUT cases; layout/scales correct; HALO repack matches direct ternary pack\n", checks);
}
