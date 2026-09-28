// Included by grouped-scales/candidates/gs_maps.hip inside its implementation namespace.
// Reuses that owner's transform, weight fitting, layout and state lifecycle.

__global__ __launch_bounds__(NT) void k_pack_global(
        const float *__restrict__ x, void *__restrict__ B, float *__restrict__ scales,
        int n, int Npad) {
    __shared__ float maxima[NT / 32];
    const int row = blockIdx.x, tid = threadIdx.x;
    float amax = 0;
    for (int k = tid; k < n; k += NT) amax = fmaxf(amax, fabsf(x[size_t(row) * n + k]));
    amax = warp_max(amax);
    if ((tid & 31) == 0) maxima[tid >> 5] = amax;
    __syncthreads();
    amax = 0;
    for (int w = 0; w < NT / 32; ++w) amax = fmaxf(amax, maxima[w]);
    const float step = amax / 127.0f, inv = step > 0 ? 1.0f / step : 0;
    if (tid == 0) scales[row] = step;
    for (int k = tid; k < n; k += NT) {
        int q = max(-127, min(127, __float2int_rn(x[size_t(row) * n + k] * inv)));
        ((uint8_t *)B)[(size_t(k / 16) * Npad + row) * 16 + k % 16] = uint8_t(q);
    }
}

template<int TT, bool FUSE, int UNROLL, bool WIDE>
__global__ __launch_bounds__(NW * 32) void k_proj_global(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const void *__restrict__ B, const uint16_t *__restrict__ sa,
        const uint16_t *__restrict__ sb, const uint8_t *__restrict__ ma,
        const uint8_t *__restrict__ mb, const float *__restrict__ cs,
        const float *__restrict__ signs, const float *resid, float *out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    for (int tg = blockIdx.y * TT * 16; tg < Npad; tg += gridDim.y * TT * 16) {
        int8v aa[TT], ab[TT];
#pragma unroll
        for (int t = 0; t < TT; ++t) { aa[t] = int8v{}; ab[t] = int8v{}; }
        // For this model: nb*128*127*127 <= 280773632 < INT32_MAX.
        for (int blk = 0; blk < nb; ++blk) {
            const unsigned mA = ma[(size_t(tile) * nb + blk) * 16 + col];
            const unsigned mB = mb[(size_t(tile) * nb + blk) * 16 + col];
            if constexpr (WIDE) {
#pragma unroll
                for (int phase = 0; phase < 2; ++phase) {
                    const size_t off = (size_t(tile) * nb + blk) * 512 + col * 32 + phase * 16;
                    int4v a = __builtin_bit_cast(int4v, *(const uint4 *)(Wa + off));
                    int4v b = __builtin_bit_cast(int4v, *(const uint4 *)(Wb + off));
#pragma unroll
                    for (int slice = 0; slice < 4; ++slice) {
                        int4v wa = expand_i8_palette(unsigned(a[slice]), mA);
                        int4v wb = expand_i8_palette(unsigned(b[slice]), mB);
#pragma unroll
                        for (int t = 0; t < TT; ++t) {
                            int4v bf = ((const int4v *)B)[size_t(blk * 8 + phase * 4 + slice) * Npad + tg + t * 16 + col];
                            aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wa, true, bf, aa[t], false);
                            ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wb, true, bf, ab[t], false);
                        }
                    }
                }
            } else {
#pragma unroll UNROLL
                for (int s = 0; s < SLICES; ++s) {
                    const size_t off = (size_t(tile) * nb + blk) * 512 + s * 64 + col * 4;
                    int4v wa = expand_i8_palette(*(const unsigned *)(Wa + off), mA);
                    int4v wb = expand_i8_palette(*(const unsigned *)(Wb + off), mB);
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        int4v bf = ((const int4v *)B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                        aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wa, true, bf, aa[t], false);
                        ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wb, true, bf, ab[t], false);
                    }
                }
            }
        }
        const float asl = h2f(sa[tile * 16 + col]), bsl = h2f(sb[tile * 16 + col]);
#pragma unroll
        for (int r = 0; r < 8; ++r) {
            float asr = __shfl(asl, 2 * r + half, 32), bsr = __shfl(bsl, 2 * r + half, 32);
            const int row = tile * 16 + 2 * r + half;
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                const int token = tg + t * 16 + col;
                if (token >= rows) continue;
                float ya = float(aa[t][r]) * (asr * cs[token]);
                float yb = float(ab[t][r]) * (bsr * cs[token]);
                size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ya) * yb * signs[row];
                else { out[o] = resid[o] + ya; out[o + rowoff] = resid[o + rowoff] + yb; }
            }
        }
    }
}

template<int CAP, int UNROLL = 1, bool WIDE = false>
void run_global(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    k_prep<3,true,true,0,1000><<<rows * (D / 1024), NT, 0, stream>>>(input, p->norm, p->transformed, nullptr, D, rows, Npad);
    k_pack_global<<<rows,NT,0,stream>>>(p->transformed, p->Bin, p->csin, D, Npad);
#define GLOBAL(TT,FUSE,WA,WB,B,SA,SB,MA,MB,CS,SIGN,RES,OUT,NB,TILES,STRIDE,OFFSET) \
    k_proj_global<TT,FUSE,UNROLL,WIDE><<<dim3((TILES)/NW,group_split((TILES)/NW,Npad/(TT*16))),NW*32,0,stream>>>( \
        WA,WB,B,SA,SB,MA,MB,CS,SIGN,RES,OUT,NB,rows,Npad,STRIDE,OFFSET)
#define GU(TT) GLOBAL(TT,true,p->wgu_a,p->wgu_b,p->Bin,p->sg,p->su,p->mg,p->mu,p->csin,p->signs,nullptr,p->hidden,D/KB,FF/16,FF,0)
#define DN(TT) GLOBAL(TT,false,p->wd_a,p->wd_b,p->Bhid,p->sd_a,p->sd_b,p->md_a,p->md_b,p->cshid,nullptr,input,output,FF/KB,Dh/16,D,Dh)
    if (CAP == 8 && Npad % 128 == 0) { GU(8); }
    else if (Npad % 64 == 0) { GU(4); }
    else if (Npad % 32 == 0) { GU(2); }
    else { GU(1); }
    k_prep<3,false,false,0,1000><<<rows * (FF / 1024), NT, 0, stream>>>(p->hidden, nullptr, p->transformed, nullptr, FF, rows, Npad);
    k_pack_global<<<rows,NT,0,stream>>>(p->transformed, p->Bhid, p->cshid, FF, Npad);
    if (CAP == 8 && Npad % 128 == 0) { DN(8); }
    else if (Npad % 64 == 0) { DN(4); }
    else if (Npad % 32 == 0) { DN(2); }
    else { DN(1); }
#undef DN
#undef GU
#undef GLOBAL
}
