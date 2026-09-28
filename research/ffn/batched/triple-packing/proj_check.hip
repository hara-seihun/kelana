// Correctness and streamed-weight cost of the triple-packed projection against native IU4.
//
// `check` runs both projection kernels on the same ternary weights and the same ternary
// activations and compares each against a CPU integer reference that applies the row and column
// scales in the same order. Nothing here depends on the FFN plumbing, so a disagreement points at
// the map rather than at the producer.
//
// `run` streams the real gate/up shape (D = 5120, FF = 17408) from memory at 16..256 tokens, so
// the decode, the scales and the weight image traffic are all inside the measurement.
//
//   hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value proj_check.hip -o build/proj_check
//   ../hardware-run ./build/proj_check check
//   ../hardware-run ./build/proj_check run 20 [json]
#include "triple_kernels.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

using namespace kelana_triple;
using namespace kelana_triple_kernels;

namespace {

unsigned g_rng = 20260915u;
int next_int() { g_rng = g_rng * 1664525u + 1013904223u; return int(g_rng >> 8); }
int8_t rand_trit(int density) { const int v = next_int(); return int8_t(v % 100 < density ? (v & 256 ? 1 : -1) : 0); }

uint16_t f16_of(float f) { _Float16 h = (_Float16) f; uint16_t u; std::memcpy(&u, &h, 2); return u; }
float f32_of(uint16_t u) { _Float16 h; std::memcpy(&h, &u, 2); return (float) h; }

struct Case {
    int rows, kdim, tokens;
    std::vector<int8_t> w;            // [rows_padded][kdim] ternary
    std::vector<uint16_t> rs;         // [rows_padded][kdim/128] FP16 row scales
    std::vector<int8_t> a;            // [tokens][kdim] ternary activations
    std::vector<float> cs;            // [tokens][kdim/128] column scales
};

Case make_case(int rows_real, int kdim, int tokens, int rows_pad, int wdensity, int adensity) {
    Case c{rows_real, kdim, tokens};
    const int nb = kdim / 128;
    c.w.assign(size_t(rows_pad) * kdim, 0);
    c.rs.assign(size_t(rows_pad) * nb, 0);
    c.a.assign(size_t(tokens) * kdim, 0);
    c.cs.assign(size_t(tokens) * nb, 0);
    for (int r = 0; r < rows_real; ++r) {
        for (int j = 0; j < kdim; ++j) c.w[size_t(r) * kdim + j] = rand_trit(wdensity);
        for (int b = 0; b < nb; ++b) c.rs[size_t(r) * nb + b] = f16_of(0.01f + 0.001f * float(next_int() % 50));
    }
    for (int t = 0; t < tokens; ++t) {
        for (int j = 0; j < kdim; ++j) c.a[size_t(t) * kdim + j] = rand_trit(adensity);
        for (int b = 0; b < nb; ++b) c.cs[size_t(t) * nb + b] = 0.02f + 0.001f * float(next_int() % 50);
    }
    return c;
}

// Reference in the kernels' own order: an exact integer dot per (row, 128-block), scaled by the
// FP16 row scale and the FP32 column scale, accumulated in FP32 across blocks.
std::vector<float> reference(const Case & c) {
    const int nb = c.kdim / 128;
    std::vector<float> y(size_t(c.tokens) * c.rows, 0.f);
    for (int t = 0; t < c.tokens; ++t)
        for (int r = 0; r < c.rows; ++r) {
            float acc = 0;
            for (int b = 0; b < nb; ++b) {
                int dot = 0;
                for (int j = 0; j < 128; ++j)
                    dot += int(c.w[size_t(r) * c.kdim + b * 128 + j]) * int(c.a[size_t(t) * c.kdim + b * 128 + j]);
                acc = std::fmaf(float(dot), f32_of(c.rs[size_t(r) * nb + b]) * c.cs[size_t(t) * nb + b], acc);
            }
            y[size_t(t) * c.rows + r] = acc;
        }
    return y;
}

template <class T> T * dev(const std::vector<T> & v) {
    T * p = nullptr;
    check(hipMalloc(&p, v.size() * sizeof(T)), "malloc");
    check(hipMemcpy(p, v.data(), v.size() * sizeof(T), hipMemcpyHostToDevice), "copy");
    return p;
}

// B fragments in the layout both projection kernels read: [kslice][Npad tokens][16 values].
std::vector<_Float16> b_fragments_f16(const Case & c, int Npad) {
    std::vector<_Float16> b(size_t(c.kdim / 16) * Npad * 16, (_Float16) 0.f);
    for (int t = 0; t < c.tokens; ++t)
        for (int j = 0; j < c.kdim; ++j)
            b[(size_t(j / 16) * Npad + t) * 16 + (j % 16)] = (_Float16) float(c.a[size_t(t) * c.kdim + j]);
    return b;
}
std::vector<uint8_t> b_fragments_i4(const Case & c, int Npad) {
    std::vector<uint8_t> b(size_t(c.kdim / 16) * Npad * 8, 0);
    for (int t = 0; t < c.tokens; ++t)
        for (int j = 0; j < c.kdim; ++j) {
            const size_t o = (size_t(j / 16) * Npad + t) * 8 + (j % 16) / 2;
            b[o] |= uint8_t(c.a[size_t(t) * c.kdim + j] & 0xf) << (4 * (j & 1));
        }
    return b;
}

struct Dev {
    std::vector<void *> owned;
    template <class T> T * keep(T * p) { owned.push_back((void *) p); return p; }
    ~Dev() { for (void * p : owned) hipFree(p); }
};

double worst_rel(const std::vector<float> & got, const std::vector<float> & ref, double & worst_abs) {
    double worst = 0;
    worst_abs = 0;
    double scale = 0;
    for (float v : ref) scale = std::max(scale, std::fabs(double(v)));
    for (size_t i = 0; i < ref.size(); ++i) {
        const double d = std::fabs(double(got[i]) - double(ref[i]));
        worst_abs = std::max(worst_abs, d);
        if (scale > 0) worst = std::max(worst, d / scale);
    }
    return worst;
}

int run_check() {
    struct Shape { const char * label; int rows, kdim, tokens, wd, ad; };
    const Shape shapes[] = {
        {"dense weights, dense activations", 96, 512, 32, 100, 100},
        {"sparse weights, dense activations", 144, 256, 16, 45, 100},
        {"dense weights, sparse activations", 96, 1024, 48, 100, 35},
        {"unaligned row count", 100, 384, 32, 80, 70},
        {"one block", 48, 128, 16, 100, 100},
    };
    int failures = 0;
    std::printf("%-36s %-6s %-6s %-7s %-14s %-14s\n", "case", "rows", "K", "tokens",
                "triple worst", "iu4 worst");
    for (const Shape & s : shapes) {
        const int rows_pad_t = (s.rows + ROWS_PER_TILE - 1) / ROWS_PER_TILE * ROWS_PER_TILE;
        const int rows_pad_i = (s.rows + 15) / 16 * 16;
        const int rows_pad = std::max(rows_pad_t, rows_pad_i);
        Case c = make_case(s.rows, s.kdim, s.tokens, rows_pad, s.wd, s.ad);
        const std::vector<float> ref = reference(c);
        const int nb = s.kdim / 128, Npad = (s.tokens + 15) / 16 * 16;
        Dev d;

        std::vector<int8_t> wt(c.w.begin(), c.w.begin() + size_t(rows_pad_t) * s.kdim);
        std::vector<uint16_t> rst(c.rs.begin(), c.rs.begin() + size_t(rows_pad_t) * nb);
        wt.resize(size_t(rows_pad_t) * s.kdim, 0);
        rst.resize(size_t(rows_pad_t) * nb, 0);
        uint8_t * wtri = d.keep(dev(pack_triple(wt.data(), rst.data(), rows_pad_t, s.kdim, LAD)));
        uint8_t * wi4 = d.keep(dev(pack_two_bit(c.w.data(), rows_pad_i, s.kdim)));
        uint16_t * si4 = d.keep(dev(std::vector<uint16_t>(c.rs.begin(), c.rs.begin() + size_t(rows_pad_i) * nb)));
        _Float16 * bf16 = d.keep(dev(b_fragments_f16(c, Npad)));
        uint8_t * bi4 = d.keep(dev(b_fragments_i4(c, Npad)));
        float * cs = d.keep(dev(c.cs));
        float * out = nullptr;
        check(hipMalloc(&out, size_t(Npad) * s.rows * sizeof(float)), "out");
        d.keep(out);
        std::vector<float> got(size_t(Npad) * s.rows);
        std::vector<float> zeros(size_t(Npad) * s.rows, 0.f);
        float * resid = d.keep(dev(zeros));

        const int tiles_t = rows_pad_t / ROWS_PER_TILE, tiles_i = rows_pad_i / 16;
        check(hipMemset(out, 0, size_t(Npad) * s.rows * sizeof(float)), "zero");
        k_proj_triple<2, 0><<<dim3((tiles_t + NW - 1) / NW, 1), NW * 32>>>(
            wtri, (const half16 *) bf16, cs, nullptr, resid, out, nb, s.tokens, Npad,
            s.rows, s.rows, tiles_t);
        check(hipDeviceSynchronize(), "triple sync");
        check(hipMemcpy(got.data(), out, got.size() * sizeof(float), hipMemcpyDeviceToHost), "back");
        double abs_t = 0;
        const double rel_t = worst_rel(std::vector<float>(got.begin(), got.begin() + size_t(s.tokens) * s.rows),
                                       ref, abs_t);

        check(hipMemset(out, 0, size_t(Npad) * s.rows * sizeof(float)), "zero");
        k_proj_iu4<2, false><<<dim3((tiles_i + NW - 1) / NW, 1), NW * 32>>>(
            wi4, nullptr, (const int2v *) bi4, si4, nullptr, cs, nullptr, resid, out, nb, s.tokens,
            Npad, s.rows, s.rows, tiles_i);
        check(hipDeviceSynchronize(), "iu4 sync");
        check(hipMemcpy(got.data(), out, got.size() * sizeof(float), hipMemcpyDeviceToHost), "back");
        double abs_i = 0;
        const double rel_i = worst_rel(std::vector<float>(got.begin(), got.begin() + size_t(s.tokens) * s.rows),
                                       ref, abs_i);

        std::printf("%-36s %-6d %-6d %-7d %-14.3g %-14.3g\n", s.label, s.rows, s.kdim, s.tokens, rel_t, rel_i);
        if (getenv("KELANA_TRIPLE_TRACE") && failures == 0 && rel_t >= 1e-5) {
            check(hipMemset(out, 0, size_t(Npad) * s.rows * sizeof(float)), "zero");
            k_proj_triple<2, 0><<<dim3((tiles_t + NW - 1) / NW, 1), NW * 32>>>(
                wtri, (const half16 *) bf16, cs, nullptr, resid, out, nb, s.tokens, Npad,
                s.rows, s.rows, tiles_t);
            check(hipDeviceSynchronize(), "trace");
            check(hipMemcpy(got.data(), out, got.size() * sizeof(float), hipMemcpyDeviceToHost), "back");
            std::printf("  token 0, rows 0..5 triple: ");
            for (int r = 0; r < 6; ++r) std::printf("%9.4f ", got[r]);
            std::printf("\n  token 0, rows 0..5 ref   : ");
            for (int r = 0; r < 6; ++r) std::printf("%9.4f ", ref[r]);
            std::printf("\n  ref rows 16..21          : ");
            for (int r = 16; r < 22; ++r) std::printf("%9.4f ", ref[r]);
            std::printf("\n  ref rows 32..37          : ");
            for (int r = 32; r < 38; ++r) std::printf("%9.4f ", ref[r]);
            std::printf("\n  triple rows 16..21       : ");
            for (int r = 16; r < 22; ++r) std::printf("%9.4f ", got[r]);
            std::printf("\n");
        }
        if (!(rel_t < 1e-5) || !(rel_i < 1e-5)) failures++;
    }
    std::printf("\n%s\n", failures ? "MISMATCH against the integer reference" :
                "both maps reproduce the integer reference to FP16 scale rounding");
    return failures ? 1 : 0;
}

template <class F> float best_ms(F launch, int reps) {
    float best = 1e30f;
    for (int rep = 0; rep < reps; ++rep) {
        hipEvent_t a, b; hipEventCreate(&a); hipEventCreate(&b);
        check(hipDeviceSynchronize(), "sync"); hipEventRecord(a);
        launch();
        hipEventRecord(b); hipEventSynchronize(b);
        float ms = 0; hipEventElapsedTime(&ms, a, b);
        best = std::min(best, ms);
        hipEventDestroy(a); hipEventDestroy(b);
    }
    return best;
}

int group_split(int tiles, int groups) {
    const int want = 320 / (tiles > 0 ? tiles : 1);
    return std::max(1, std::min(groups, want));
}

int run_bench(int reps, const char * json) {
    const int D = 5120, FF = 17408, nb = D / 128;
    const int FFt = (FF + ROWS_PER_TILE - 1) / ROWS_PER_TILE * ROWS_PER_TILE, FFi = FF;
    std::printf("gate and up projection, D = %d, FF = %d, %.1f M ternary weights, weights streamed"
                " from memory every pass.\n", D, FF, 2.0 * FF * D / 1e6);
    std::vector<int8_t> w(size_t(FFt) * D, 0);
    std::vector<uint16_t> rs(size_t(FFt) * nb, 0);
    for (int r = 0; r < FF; ++r) {
        for (int j = 0; j < D; ++j) w[size_t(r) * D + j] = rand_trit(70);
        for (int b = 0; b < nb; ++b) rs[size_t(r) * nb + b] = f16_of(0.02f);
    }
    Dev d;
    std::vector<uint8_t> tri = pack_triple(w.data(), rs.data(), FFt, D, LAD);
    std::vector<uint8_t> two = pack_two_bit(w.data(), FFi, D);
    const double tri_mb = double(tri.size()) / 1e6, two_mb = double(two.size()) / 1e6;
    uint8_t * wtri = d.keep(dev(tri));
    uint8_t * wtri2 = d.keep(dev(tri));
    uint8_t * wi4 = d.keep(dev(two));
    uint8_t * wi42 = d.keep(dev(two));
    uint16_t * si4 = d.keep(dev(rs));
    std::printf("weight image per matrix: triple-packed FP16 %.2f MB, two-bit ternary %.2f MB "
                "(%.2fx)\n\n", tri_mb, two_mb, tri_mb / two_mb);

    std::printf("%-8s %-14s %-14s %-10s %-24s\n", "tokens", "triple ms", "iu4 ms", "iu4/triple",
                "effective TOPS triple/iu4");
    std::string rows_json;
    for (int tokens : {16, 32, 64, 128, 256}) {
        const int Npad = (tokens + 15) / 16 * 16;
        std::vector<float> cs(size_t(Npad) * nb, 0.03f);
        float * dcs = d.keep(dev(cs));
        std::vector<_Float16> bf(size_t(D / 16) * Npad * 16, (_Float16) 1.f);
        _Float16 * dbf = d.keep(dev(bf));
        std::vector<uint8_t> bi(size_t(D / 16) * Npad * 8, 0x11);
        uint8_t * dbi = d.keep(dev(bi));
        float * out = nullptr, * signs = nullptr;
        check(hipMalloc(&out, size_t(Npad) * FF * sizeof(float)), "out");
        check(hipMalloc(&signs, size_t(FF) * sizeof(float)), "signs");
        check(hipMemset(signs, 0, size_t(FF) * sizeof(float)), "signs zero");
        d.keep(out); d.keep(signs);
        const int tt = FFt / ROWS_PER_TILE, ti = FFi / 16;
        const int tb_t = (tt + NW - 1) / NW, tb_i = (ti + NW - 1) / NW;
        const float ms_t = best_ms([&] {
            k_proj_triple<2, 1><<<dim3(tb_t, group_split(tb_t, std::max(1, Npad / 32))), NW * 32>>>(
                wtri, (const half16 *) dbf, dcs, nullptr, nullptr, out, nb, tokens, Npad, FF, FF, tt);
            k_proj_triple<2, 2><<<dim3(tb_t, group_split(tb_t, std::max(1, Npad / 32))), NW * 32>>>(
                wtri2, (const half16 *) dbf, dcs, signs, nullptr, out, nb, tokens, Npad, FF, FF, tt);
        }, reps);
        const float ms_i = best_ms([&] {
            k_proj_iu4<4, true><<<dim3(tb_i, group_split(tb_i, std::max(1, Npad / 64))), NW * 32>>>(
                wi4, wi42, (const int2v *) dbi, si4, si4, dcs, signs, nullptr, out, nb, tokens, Npad, FF, FF, ti);
        }, reps);
        check(hipGetLastError(), "launch");
        const double macs = 2.0 * double(FF) * D * tokens;
        std::printf("%-8d %-14.3f %-14.3f %-10.2f %.1f / %.1f\n", tokens, ms_t, ms_i, ms_t / ms_i,
                    2 * macs / (ms_t * 1e-3) / 1e12, 2 * macs / (ms_i * 1e-3) / 1e12);
        rows_json += std::string(rows_json.empty() ? "" : ",\n") + "    { \"tokens\": " +
                     std::to_string(tokens) + ", \"triple_ms\": " + std::to_string(ms_t) +
                     ", \"iu4_ms\": " + std::to_string(ms_i) + " }";
    }
    if (json) {
        FILE * f = fopen(json, "w");
        fprintf(f, "{\n  \"shape\": { \"D\": %d, \"FF\": %d },\n"
                   "  \"weight_image_mb\": { \"triple_fp16\": %.3f, \"two_bit\": %.3f },\n"
                   "  \"rows\": [\n%s\n  ]\n}\n", D, FF, tri_mb, two_mb, rows_json.c_str());
        fclose(f);
    }
    return 0;
}

}  // namespace

int main(int argc, char ** argv) {
    const std::string mode = argc > 1 ? argv[1] : "check";
    hipDeviceProp_t prop{};
    check(hipGetDeviceProperties(&prop, 0), "props");
    std::printf("device %s, %d CU\n\n", prop.gcnArchName, prop.multiProcessorCount);
    if (mode == "check") return run_check();
    if (mode == "run") return run_bench(argc > 2 ? std::atoi(argv[2]) : 10, argc > 3 ? argv[3] : nullptr);
    std::fprintf(stderr, "usage: proj_check check | run [reps] [json]\n");
    return 2;
}
