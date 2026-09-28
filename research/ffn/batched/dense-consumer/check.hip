// Exactness of the dense five-trit direct consumer, and the native V_PERM_B32 semantics it
// depends on, measured on the device that runs it.
//
// Four things are checked, because each can fail independently:
//
//   1. The host peel turns every reachable (A, B, c) triple back into itself.
//   2. Native V_PERM_B32 over all 256 selector byte values, classified against twelve source
//      vectors. Sources and selectors are read from device memory inside the kernel, so no call
//      can be constant folded. The resulting table is recorded in full.
//   3. The same calls written with literal constant operands, so the compiler may fold them,
//      compared against the measured native results. The emitted assembly is kept alongside, in
//      results/perm-folding.s, because it shows which happened: a folded call leaves no
//      v_perm_b32 behind. As measured here the folded constants and the native instruction agree
//      on every case, so there is no compiler discrepancy to work around. An earlier revision of
//      this directory claimed one; that claim came from a wrong guess about which source byte
//      selector 8 reads, and the table below is what replaced the guess.
//   4. A whole 128-block of random ternary weights survives storage and expansion into the int4
//      operand nibbles a v_wmma_i32_16x16x16_iu4 A fragment expects.
//
// Everything printed about V_PERM_B32 below is measured here. No vendor document is quoted or
// relied on, because this file cannot cite a manual it does not carry a version of.
#include "dense5.hpp"
#include "../bench/sha256.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>

using namespace kelana_dense;

// ---------------------------------------------------------------- native selector table

// Twelve source vectors, chosen so one pass classifies every selector.
//   0,1  every one of the eight source bytes distinct and neither 0x00 nor 0xff, so an output
//        byte names the source byte it came from. Two different sets, so a coincidence has to
//        happen twice.
//   2..9 exactly one source byte has its top bit set and every other byte is 0x00, so an output
//        of 0xff names the byte whose sign was read.
//   10   all bytes 0x00.        11   all bytes 0xff.
constexpr int NPROBE = 12;

struct Probe { unsigned a, b; const char *what; };

static Probe probes[NPROBE] = {
    {0x08070605u, 0x04030201u, "distinct bytes 1..8"},
    {0x18171615u, 0x14131211u, "distinct bytes 0x11..0x18"},
    {0x00000000u, 0x00000080u, "top bit only in argB byte 0"},
    {0x00000000u, 0x00008000u, "top bit only in argB byte 1"},
    {0x00000000u, 0x00800000u, "top bit only in argB byte 2"},
    {0x00000000u, 0x80000000u, "top bit only in argB byte 3"},
    {0x00000080u, 0x00000000u, "top bit only in argA byte 0"},
    {0x00008000u, 0x00000000u, "top bit only in argA byte 1"},
    {0x00800000u, 0x00000000u, "top bit only in argA byte 2"},
    {0x80000000u, 0x00000000u, "top bit only in argA byte 3"},
    {0x00000000u, 0x00000000u, "all zero"},
    {0xffffffffu, 0xffffffffu, "all ones"},
};

// The eight source bytes, named the way this file names them: index 0..3 is argB byte 0..3 and
// index 4..7 is argA byte 0..3. That naming is a conclusion of probe vectors 0 and 1, not an
// assumption; the classifier below derives it and the printed table shows it.
__device__ __forceinline__ unsigned source_byte(unsigned a, unsigned b, int idx) {
    return idx < 4 ? ((b >> (8 * idx)) & 0xffu) : ((a >> (8 * (idx - 4))) & 0xffu);
}

__global__ void k_perm_table(unsigned *__restrict__ out, const unsigned *__restrict__ srcA,
                             const unsigned *__restrict__ srcB, const unsigned *__restrict__ sel) {
    const int p = blockIdx.x, s = threadIdx.x;
    out[p * 256 + s] = __builtin_amdgcn_perm(srcA[p], srcB[p], sel[s]);
}

// Same eight source bytes read back through plain shifts, so the classifier can name a source
// byte without the host having to mirror any byte-order convention by hand.
__global__ void k_source_bytes(unsigned *__restrict__ out, const unsigned *__restrict__ srcA,
                               const unsigned *__restrict__ srcB) {
    const int p = blockIdx.x, i = threadIdx.x;
    out[p * 8 + i] = source_byte(srcA[p], srcB[p], i);
}

// ---------------------------------------------------------------- folding comparison
//
// Every call in k_perm_folded has literal operands, so the compiler is free to evaluate it at
// compile time, and it does: the emitted body holds no v_perm_b32 at all. k_perm_runtime makes
// the identical calls on values it loads from memory and issues the real instruction. Running
// both and diffing is the only way to tell a folder disagreement from a wrong assumption about
// the instruction, and it costs one kernel launch.
#define FOLD_CASES(X)                                                        \
    X(0, PERM_S0, PERM_S1, 0x08080808u)                                      \
    X(1, PERM_S0, PERM_S1, 0x09090909u)                                      \
    X(2, PERM_S0, PERM_S1, 0x0a0a0a0au)                                      \
    X(3, PERM_S0, PERM_S1, 0x0b0b0b0bu)                                      \
    X(4, 0x00000000u, 0x00008000u, 0x08080808u)                              \
    X(5, 0x00008000u, 0x00000000u, 0x08080808u)                              \
    X(6, 0x00000000u, 0x00000080u, 0x08080808u)                              \
    X(7, 0x00000080u, 0x00000000u, 0x08080808u)                              \
    X(8, 0x00000000u, 0x80000000u, 0x09090909u)                              \
    X(9, 0x80000000u, 0x00000000u, 0x0b0b0b0bu)

constexpr int NFOLD = 10;

__global__ void k_perm_folded(unsigned *__restrict__ out) {
#define ONE(i, A, B, S) out[i] = __builtin_amdgcn_perm((A), (B), (S));
    FOLD_CASES(ONE)
#undef ONE
}

__global__ void k_perm_runtime(unsigned *__restrict__ out, const unsigned *__restrict__ a,
                               const unsigned *__restrict__ b, const unsigned *__restrict__ s) {
    const int i = threadIdx.x;
    out[i] = __builtin_amdgcn_perm(a[i], b[i], s[i]);
}

// ---------------------------------------------------------------- dense round trip

__device__ __forceinline__ void decode_block_dense(const uint8_t *base, int lane, uint2v out[8]) {
    const uint4 s0 = *(const uint4 *) (base + lane * 16);
    const uint2 s1 = *(const uint2 *) (base + DENSE_S1_OFF + lane * 8);
    const unsigned s2 = *(const unsigned short *) (base + DENSE_S2_OFF + lane * 2);
    unsigned cc[6];
    DenseDword r;
    r = peel_dword(s0.x); out[0] = slice_of(r); cc[0] = cc_of(r);
    r = peel_dword(s0.y); out[1] = slice_of(r); cc[1] = cc_of(r);
    r = peel_dword(s0.z); out[2] = slice_of(r); cc[2] = cc_of(r);
    r = peel_dword(s0.w); out[3] = slice_of(r); cc[3] = cc_of(r);
    out[6] = slice_from_cc(cc[0], cc[1], cc[2], cc[3]);
    r = peel_dword(s1.x); out[4] = slice_of(r); cc[4] = cc_of(r);
    r = peel_dword(s1.y); out[5] = slice_of(r); cc[5] = cc_of(r);
    out[7][0] = expand_codes(perm(cc[5], cc[4], 0x06040200u));
    out[7][1] = expand_codes(tail_codes(s2));
}

__global__ void k_decode_dense(const uint8_t *w, int nblocks, int *out) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= nblocks * 16) return;
    int blk = idx / 16, lane = idx % 16;
    uint2v s[8];
    decode_block_dense(w + size_t(blk) * DENSE_BLOCK_BYTES, lane, s);
    int *dst = out + size_t(idx) * 128;
    for (int k = 0; k < 8; ++k)
        for (int n = 0; n < 16; ++n) {
            unsigned nib = (s[k][n >> 3] >> (4 * (n & 7))) & 0xfu;
            dst[k * 16 + n] = nib == 0xf ? -1 : int(nib);
        }
}

__global__ void k_decode_pair(const uint8_t *w, int nblocks, int *out) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= nblocks * 16) return;
    int blk = idx / 16, lane = idx % 16;
    const uint8_t *base = w + size_t(blk) * PAIR_BLOCK_BYTES;
    int *dst = out + size_t(idx) * 128;
    for (int k = 0; k < 8; ++k) {
        uint2v s = expand_paircode(*(const unsigned *) (base + k * 64 + lane * 4));
        for (int n = 0; n < 16; ++n) {
            unsigned nib = (s[n >> 3] >> (4 * (n & 7))) & 0xfu;
            dst[k * 16 + n] = nib == 0xf ? -1 : int(nib);
        }
    }
}

// ---------------------------------------------------------------- host side

static void die(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "%s: %s\n", what, hipGetErrorString(e)); std::exit(1); }
}

template <class T> static T *upload(const std::vector<T> &v) {
    T *d = nullptr;
    die(hipMalloc(&d, v.size() * sizeof(T)), "malloc");
    die(hipMemcpy(d, v.data(), v.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    return d;
}

// What one selector value does, derived from the twelve probes.
struct Rule {
    enum Kind { select, sign_of, zero, ones, mixed_bytes, unclassified } kind = unclassified;
    int index = -1;                      // source byte index for select / sign_of
    unsigned raw[NPROBE] = {};
};

static const char *kind_name(Rule::Kind k) {
    switch (k) {
        case Rule::select: return "select";
        case Rule::sign_of: return "sign_of";
        case Rule::zero: return "const_0x00";
        case Rule::ones: return "const_0xff";
        case Rule::mixed_bytes: return "per_byte";
        default: return "unclassified";
    }
}

int main(int argc, char **argv) {
    std::string json_path, srcdir = ".";
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--json" && i + 1 < argc) json_path = argv[++i];
        else if (a == "--source-dir" && i + 1 < argc) srcdir = argv[++i];
        else { std::fprintf(stderr, "usage: check [--json FILE] [--source-dir DIR]\n"); return 2; }
    }
    int fails = 0;

    // 1. host round trip over every reachable (A, B, c)
    int peel_bad = 0;
    for (unsigned A = 0; A < 9; ++A)
        for (unsigned B = 0; B < 9; ++B)
            for (unsigned c = 0; c < 3; ++c) {
                uint8_t b = pack_codes(A, B, c);
                unsigned a2, b2, c2;
                peel_codes(b, a2, b2, c2);
                if (a2 != A || b2 != B || c2 != c) {
                    std::printf("host peel mismatch A%u B%u c%u -> %u %u %u (byte %u)\n", A, B, c, a2, b2, c2, b);
                    ++peel_bad;
                }
            }
    std::printf("host peel over all 243 codes: %s\n", peel_bad ? "FAIL" : "ok");
    fails += peel_bad != 0;

    // 2. the native selector table, with runtime sources and runtime selectors
    std::vector<unsigned> hA(NPROBE), hB(NPROBE), hSel(256);
    for (int p = 0; p < NPROBE; ++p) { hA[p] = probes[p].a; hB[p] = probes[p].b; }
    for (int s = 0; s < 256; ++s) hSel[s] = unsigned(s) * 0x01010101u;
    unsigned *dA = upload(hA), *dB = upload(hB), *dSel = upload(hSel), *dTab = nullptr, *dBytes = nullptr;
    die(hipMalloc(&dTab, NPROBE * 256 * 4), "malloc table");
    die(hipMalloc(&dBytes, NPROBE * 8 * 4), "malloc bytes");
    hipLaunchKernelGGL(k_perm_table, dim3(NPROBE), dim3(256), 0, 0, dTab, dA, dB, dSel);
    hipLaunchKernelGGL(k_source_bytes, dim3(NPROBE), dim3(8), 0, 0, dBytes, dA, dB);
    die(hipDeviceSynchronize(), "table launch");
    std::vector<unsigned> tab(NPROBE * 256), sbytes(NPROBE * 8);
    die(hipMemcpy(tab.data(), dTab, tab.size() * 4, hipMemcpyDeviceToHost), "table copy");
    die(hipMemcpy(sbytes.data(), dBytes, sbytes.size() * 4, hipMemcpyDeviceToHost), "bytes copy");

    Rule rules[256];
    int broadcast_bad = 0;
    for (int s = 0; s < 256; ++s) {
        Rule &r = rules[s];
        for (int p = 0; p < NPROBE; ++p) r.raw[p] = tab[p * 256 + s];
        // Every selector byte of the call was the same value, so every output byte must match.
        for (int p = 0; p < NPROBE; ++p) {
            unsigned v = r.raw[p];
            if ((v & 0xffu) * 0x01010101u != v) { ++broadcast_bad; r.kind = Rule::mixed_bytes; }
        }
        if (r.kind == Rule::mixed_bytes) continue;
        unsigned v0 = r.raw[0] & 0xffu, v1 = r.raw[1] & 0xffu;
        int sel_idx = -1;
        for (int i = 0; i < 8; ++i)
            if (sbytes[0 * 8 + i] == v0 && sbytes[1 * 8 + i] == v1) sel_idx = i;
        if (sel_idx >= 0) { r.kind = Rule::select; r.index = sel_idx; continue; }
        if (v0 == 0xffu && v1 == 0xffu && (r.raw[10] & 0xffu) == 0xffu) { r.kind = Rule::ones; continue; }
        if (v0 == 0x00u && v1 == 0x00u) {
            int hit = -1, hits = 0;
            for (int i = 0; i < 8; ++i)
                if ((r.raw[2 + i] & 0xffu) == 0xffu) { hit = i; ++hits; }
            if (hits == 1 && (r.raw[10] & 0xffu) == 0x00u && (r.raw[11] & 0xffu) == 0xffu) {
                r.kind = Rule::sign_of; r.index = hit; continue;
            }
            if (hits == 0 && (r.raw[10] & 0xffu) == 0x00u && (r.raw[11] & 0xffu) == 0x00u) {
                r.kind = Rule::zero; continue;
            }
        }
    }
    if (broadcast_bad) { std::printf("FAIL: %d selector/probe pairs gave unequal output bytes\n", broadcast_bad); ++fails; }

    std::printf("\nnative V_PERM_B32 over __builtin_amdgcn_perm(argA, argB, sel), all 256 selectors,\n"
                "sources and selectors read from device memory so nothing can be folded.\n"
                "source byte index 0..3 is argB byte 0..3, 4..7 is argA byte 0..3, as probes 0 and 1 show.\n\n");
    std::printf("  selectors 0..15 in detail:\n");
    for (int s = 0; s < 16; ++s) {
        const Rule &r = rules[s];
        std::printf("    %3d  %-12s", s, kind_name(r.kind));
        if (r.index >= 0) {
            int i = r.index;
            std::printf(" source byte %d = %s byte %d", i, i < 4 ? "argB" : "argA", i & 3);
        }
        std::printf("\n");
    }
    // Collapse 16..255 into runs so the whole range is stated rather than sampled.
    std::printf("  selectors 16..255:");
    int run_start = 16;
    for (int s = 17; s <= 256; ++s) {
        bool same = s < 256 && rules[s].kind == rules[run_start].kind && rules[s].index == rules[run_start].index;
        if (!same) {
            std::printf(" [%d..%d] %s", run_start, s - 1, kind_name(rules[run_start].kind));
            if (rules[run_start].index >= 0) std::printf("(%d)", rules[run_start].index);
            run_start = s;
        }
    }
    std::printf("\n\n");

    // The rule this construction depends on, asserted against the measured table.
    bool table_ok = true;
    for (int s = 0; s < 4; ++s) table_ok &= rules[s].kind == Rule::select && rules[s].index == s;
    for (int s = 4; s < 8; ++s) table_ok &= rules[s].kind == Rule::select && rules[s].index == s;
    for (int s = 8; s < 12; ++s) table_ok &= rules[s].kind == Rule::sign_of;
    int sign_src[4] = {rules[8].index, rules[9].index, rules[10].index, rules[11].index};
    std::printf("selectors 8..11 read the sign of source bytes %d, %d, %d, %d",
                sign_src[0], sign_src[1], sign_src[2], sign_src[3]);
    bool odd_byte_rule = true;
    for (int k = 0; k < 4; ++k) odd_byte_rule &= sign_src[k] == 2 * k + 1;
    std::printf("  -> %s\n", odd_byte_rule
        ? "the odd byte of each 16-bit half, i.e. 2*(sel-8)+1"
        : "NOT 2*(sel-8)+1; the comments in dense5.hpp need updating to this table");
    table_ok &= odd_byte_rule;
    table_ok &= rules[12].kind == Rule::zero;
    table_ok &= rules[13].kind == Rule::ones;
    std::printf("selector table matches what dense5.hpp assumes: %s\n", table_ok ? "ok" : "FAIL");
    if (!table_ok) ++fails;

    // Code 8 needs 0x00, which happens exactly when the byte selector 8 reads has a clear top bit.
    unsigned s1b1 = (PERM_S1 >> 8) & 0xffu;
    std::printf("code 8 relies on source byte %d = PERM_S1 byte 1 = 0x%02x, top bit %s -> 0x00: %s\n",
                sign_src[0], s1b1, (s1b1 & 0x80u) ? "set" : "clear", (s1b1 & 0x80u) ? "FAIL" : "ok");
    if (s1b1 & 0x80u) ++fails;

    // 3. folded versus native, same operands
    std::vector<unsigned> fa, fb, fs;
#define COLLECT(i, A, B, S) fa.push_back((A)); fb.push_back((B)); fs.push_back((S));
    FOLD_CASES(COLLECT)
#undef COLLECT
    unsigned *dfa = upload(fa), *dfb = upload(fb), *dfs = upload(fs);
    unsigned *dFolded = nullptr, *dRuntime = nullptr;
    die(hipMalloc(&dFolded, NFOLD * 4), "malloc folded");
    die(hipMalloc(&dRuntime, NFOLD * 4), "malloc runtime");
    hipLaunchKernelGGL(k_perm_folded, dim3(1), dim3(1), 0, 0, dFolded);
    hipLaunchKernelGGL(k_perm_runtime, dim3(1), dim3(NFOLD), 0, 0, dRuntime, dfa, dfb, dfs);
    die(hipDeviceSynchronize(), "fold launch");
    std::vector<unsigned> folded(NFOLD), runtime(NFOLD);
    die(hipMemcpy(folded.data(), dFolded, NFOLD * 4, hipMemcpyDeviceToHost), "folded copy");
    die(hipMemcpy(runtime.data(), dRuntime, NFOLD * 4, hipMemcpyDeviceToHost), "runtime copy");

    int disagree = 0;
    std::printf("\ncompile-time operands versus device memory operands, identical values:\n");
    std::printf("    %-10s %-10s %-10s %-10s %-10s\n", "argA", "argB", "sel", "native", "folded");
    for (int i = 0; i < NFOLD; ++i) {
        bool d = folded[i] != runtime[i];
        disagree += d;
        std::printf("    0x%08x 0x%08x 0x%08x 0x%08x 0x%08x %s\n",
                    fa[i], fb[i], fs[i], runtime[i], folded[i], d ? "  DIFFER" : "");
    }
    std::printf("  %d of %d differ. Both columns are the same C expression on the same values;\n"
                "  results/perm-folding.s shows k_perm_folded carries no v_perm_b32, so its column\n"
                "  is the compiler's arithmetic and the other is the instruction's.\n", disagree, NFOLD);
    if (disagree) ++fails;

    // 4. whole-block round trip on random ternary weights
    const int rows = 16 * 64, kdim = 128 * 5;
    std::vector<int8_t> w(size_t(rows) * kdim);
    std::mt19937 rng(12345);
    for (auto &x : w) x = int8_t(int(rng() % 3) - 1);

    struct Case { const char *name; std::vector<uint8_t> packed; int blockbytes; bool dense; long bad; };
    Case cases[2] = {{"dense5", pack_dense(w.data(), rows, kdim), DENSE_BLOCK_BYTES, true, 0},
                     {"paircode", pack_paircode<false>(w.data(), rows, kdim), PAIR_BLOCK_BYTES, false, 0}};
    int nblocks = (rows / 16) * (kdim / 128);
    std::printf("\n");
    for (auto &c : cases) {
        uint8_t *dw = nullptr; int *dout = nullptr;
        die(hipMalloc(&dw, c.packed.size()), "malloc w");
        die(hipMemcpy(dw, c.packed.data(), c.packed.size(), hipMemcpyHostToDevice), "upload");
        die(hipMalloc(&dout, size_t(nblocks) * 16 * 128 * 4), "malloc out");
        int threads = nblocks * 16;
        if (c.dense) hipLaunchKernelGGL(k_decode_dense, dim3((threads + 255) / 256), dim3(256), 0, 0, dw, nblocks, dout);
        else hipLaunchKernelGGL(k_decode_pair, dim3((threads + 255) / 256), dim3(256), 0, 0, dw, nblocks, dout);
        die(hipDeviceSynchronize(), "launch");
        std::vector<int> got(size_t(nblocks) * 16 * 128);
        die(hipMemcpy(got.data(), dout, got.size() * 4, hipMemcpyDeviceToHost), "download");
        for (int tile = 0; tile < rows / 16; ++tile)
            for (int b = 0; b < kdim / 128; ++b)
                for (int r = 0; r < 16; ++r) {
                    size_t gi = ((size_t(tile) * (kdim / 128) + b) * 16 + r) * 128;
                    const int8_t *ref = w.data() + size_t(tile * 16 + r) * kdim + b * 128;
                    for (int j = 0; j < 128; ++j) if (got[gi + j] != ref[j]) ++c.bad;
                }
        std::printf("%-9s %d rows x %d K, %d bytes/128 weights (%.3f bpw): %ld mismatches of %ld\n",
                    c.name, rows, kdim, c.blockbytes / 16, c.blockbytes * 8.0 / (16.0 * 128),
                    c.bad, long(rows) * kdim);
        if (c.bad) ++fails;
        hipFree(dw); hipFree(dout);
    }

    // fingerprints
    hipDeviceProp_t prop{};
    die(hipGetDeviceProperties(&prop, 0), "props");
    int rt = 0, drv = 0;
    hipRuntimeGetVersion(&rt); hipDriverGetVersion(&drv);
    std::string self = argv[0];
    std::string h_check = kbsha::sha256_file(srcdir + "/check.hip");
    std::string h_hdr = kbsha::sha256_file(srcdir + "/dense5.hpp");
    std::string h_bin = kbsha::sha256_file(self);
    std::printf("\ndevice %s (%s)  hip runtime %d  driver %d\ncompiler %s\n",
                prop.name, prop.gcnArchName, rt, drv, __VERSION__);
    std::printf("check.hip %s\ndense5.hpp %s\nbinary %s\n",
                h_check.c_str(), h_hdr.c_str(), h_bin.c_str());
    std::printf("%s\n", fails ? "FAILED" : "all checks passed");

    if (!json_path.empty()) {
        FILE *f = std::fopen(json_path.c_str(), "w");
        if (!f) { std::perror("open json"); return 1; }
        std::fprintf(f, "{\n \"format\": \"kelana-dense-consumer-perm/1\",\n");
        std::fprintf(f, " \"what\": \"native V_PERM_B32 selector semantics on this device, measured with runtime sources and runtime selectors; no vendor document consulted\",\n");
        std::fprintf(f, " \"device\": \"%s\", \"arch\": \"%s\", \"hip_runtime\": %d, \"hip_driver\": %d,\n",
                     prop.name, prop.gcnArchName, rt, drv);
        std::fprintf(f, " \"compiler\": \"%s\",\n", __VERSION__);
        std::fprintf(f, " \"hip_version\": \"%d.%d.%d\",\n", HIP_VERSION_MAJOR, HIP_VERSION_MINOR, HIP_VERSION_PATCH);
        std::fprintf(f, " \"sha256\": {\"check.hip\": \"%s\", \"dense5.hpp\": \"%s\", \"binary\": \"%s\"},\n",
                     h_check.c_str(), h_hdr.c_str(), h_bin.c_str());
        std::fprintf(f, " \"source_byte_naming\": \"index 0..3 = argB byte 0..3, index 4..7 = argA byte 0..3, derived from probes 0 and 1\",\n");
        std::fprintf(f, " \"probes\": [\n");
        for (int p = 0; p < NPROBE; ++p)
            std::fprintf(f, "  {\"argA\": %u, \"argB\": %u, \"what\": \"%s\"}%s\n",
                         probes[p].a, probes[p].b, probes[p].what, p + 1 < NPROBE ? "," : "");
        std::fprintf(f, " ],\n \"selectors\": [\n");
        for (int s = 0; s < 256; ++s) {
            std::fprintf(f, "  {\"sel\": %d, \"rule\": \"%s\", \"source_byte\": %d, \"raw\": [",
                         s, kind_name(rules[s].kind), rules[s].index);
            for (int p = 0; p < NPROBE; ++p) std::fprintf(f, "%u%s", rules[s].raw[p], p + 1 < NPROBE ? "," : "");
            std::fprintf(f, "]}%s\n", s < 255 ? "," : "");
        }
        std::fprintf(f, " ],\n \"sign_sources_for_8_to_11\": [%d,%d,%d,%d],\n",
                     sign_src[0], sign_src[1], sign_src[2], sign_src[3]);
        std::fprintf(f, " \"sign_rule\": \"%s\",\n",
                     odd_byte_rule ? "source byte 2*(sel-8)+1, the odd byte of each 16-bit half" : "not 2*(sel-8)+1");
        std::fprintf(f, " \"folding\": {\"cases\": [\n");
        for (int i = 0; i < NFOLD; ++i)
            std::fprintf(f, "  {\"argA\": %u, \"argB\": %u, \"sel\": %u, \"native\": %u, \"folded\": %u, \"agree\": %s}%s\n",
                         fa[i], fb[i], fs[i], runtime[i], folded[i], folded[i] == runtime[i] ? "true" : "false",
                         i + 1 < NFOLD ? "," : "");
        std::fprintf(f, " ], \"disagreements\": %d,\n", disagree);
        std::fprintf(f, "  \"assembly\": \"results/perm-folding.s, extracted from this file's device assembly\"},\n");
        std::fprintf(f, " \"round_trip\": {\"dense5_mismatches\": %ld, \"paircode_mismatches\": %ld, \"weights\": %ld},\n",
                     cases[0].bad, cases[1].bad, long(rows) * kdim);
        std::fprintf(f, " \"host_peel_mismatches\": %d,\n \"failed\": %s\n}\n", peel_bad, fails ? "true" : "false");
        std::fclose(f);
        std::printf("wrote %s\n", json_path.c_str());
    }
    return fails ? 1 : 0;
}
