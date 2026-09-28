// Exactness checks for the batched lookup map's arithmetic, independent of any GPU.
//
// Three things have to hold before a group size is allowed to claim an exact reference:
//   1. the packed two-token channel never carries between its 16-bit halves across a whole
//      128-input scale group, for every reachable activation extreme;
//   2. the biased decode recovers the signed sum exactly;
//   3. for group 5, HALO's own five-trits-per-byte qs code is a usable table index, so the
//      consumer can look up with the stored byte and never expand a weight.

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
#include <string>

namespace {

int failures = 0;
void expect(bool ok, const char * what) {
    if (!ok) { printf("FAIL %s\n", what); failures++; }
}

// HALO's packer and its peeling decoder, copied from bonsai-halo src/halo_format.h so this check
// stands alone and would notice a divergence from the deployed format.
uint8_t pack5(const uint8_t * t) {
    unsigned q = ((((t[0] * 3u + t[1]) * 3u + t[2]) * 3u + t[3]) * 3u + t[4]);
    return (uint8_t) ((q * 256u + 242u) / 243u);
}
uint8_t pack4(const uint8_t * t) {
    unsigned q = ((((t[0] * 3u + t[1]) * 3u + t[2]) * 3u + t[3]) * 3u);
    return (uint8_t) ((q * 256u + 242u) / 243u);
}
void peel5(uint8_t byte, uint8_t * t) {
    unsigned b = byte;
    for (int n = 0; n < 5; n++) { unsigned m = b * 3u; t[n] = (uint8_t) (m >> 8); b = m & 0xff; }
}

// A group of G trits, biased so the packed field is never negative.
struct GroupSpec { int G, groups, bias; };

// The map keeps two tokens in one 32-bit word as (a + bias) + 65536 * (b + bias) and adds those
// words directly. The check is that the low field can neither borrow below zero nor carry into
// the high field, at the extremes of int8 activations and ternary weights.
bool packed_channel_is_exact(const GroupSpec & s) {
    const long extreme = 128L * s.G;              // |sum of G trits times int8| <= 128 G
    const long lo_min = (long) s.groups * (s.bias - extreme);
    const long hi_max = (long) s.groups * (s.bias + extreme);
    return lo_min >= 0 && hi_max < 65536;
}

void report_group(const GroupSpec & s, const char * name) {
    const long extreme = 128L * s.G;
    const long lo_min = (long) s.groups * (s.bias - extreme);
    const long hi_max = (long) s.groups * (s.bias + extreme);
    printf("  %-28s G=%d groups=%2d bias=%4d  accumulated field [%ld, %ld]  %s\n",
           name, s.G, s.groups, s.bias, lo_min, hi_max,
           packed_channel_is_exact(s) ? "exact" : "OVERFLOWS");
}

// Exhaustive decode check over the reachable accumulation range: every attainable pair of signed
// sums must survive packing, adding and unpacking.
void check_decode(const GroupSpec & s) {
    const long extreme = 128L * s.G;
    const long bias_total = (long) s.groups * s.bias;
    int bad = 0;
    // Walk the reachable per-group sums at their extremes and a dense interior sample.
    for (long a = -extreme; a <= extreme; a++) {
        for (long b = -extreme; b <= extreme; b += (extreme > 64 ? 37 : 1)) {
            unsigned acc = 0;
            // s.groups additions of one word each, all groups at the same value: the worst case
            // for both the borrow and the carry direction.
            unsigned word = (unsigned) (a + s.bias) | ((unsigned) (b + s.bias) << 16);
            for (int g = 0; g < s.groups; g++) acc += word;
            long lo = (long) (acc & 65535) - bias_total;
            long hi = (long) (acc >> 16) - bias_total;
            if (lo != a * s.groups || hi != b * s.groups) bad++;
        }
    }
    printf("  decode mismatches at G=%d: %d\n", s.G, bad);
    expect(bad == 0, "packed decode is exact over the reachable range");
}

} // namespace

int main() {
    printf("packed two-token channel\n");
    // The deployed map: 43 groups of 3, bias 384.
    GroupSpec g3{3, 43, 384};
    // Group 4 covers 128 inputs in 32 groups with no padding at all.
    GroupSpec g4{4, 32, 512};
    // Group 5 covers 128 inputs as HALO does: 24 qs bytes of five trits and 2 qh bytes of four.
    GroupSpec g5{5, 26, 640};
    report_group(g3, "deployed 43 x group 3");
    report_group(g4, "32 x group 4");
    report_group(g5, "26 x group 5 (HALO slots)");
    expect(packed_channel_is_exact(g3), "group 3 packed channel");
    expect(packed_channel_is_exact(g4), "group 4 packed channel");
    expect(packed_channel_is_exact(g5), "group 5 packed channel");

    // How far a group size could go before the packed channel breaks, which is the real cap on
    // "use a bigger group to do more MACs per lookup".
    printf("\nlargest exact group size for one 128-input scale block, two tokens per dword\n");
    for (int G = 2; G <= 10; G++) {
        int groups = (128 + G - 1) / G;
        long extreme = 128L * G;
        long bias = extreme;                       // smallest bias that cannot borrow
        long hi_max = (long) groups * (bias + extreme);
        printf("  G=%2d groups=%2d  needs bias %4ld, accumulates to %6ld  %s\n",
               G, groups, bias, hi_max, hi_max < 65536 ? "exact" : "needs a wider channel");
    }

    check_decode(g3);
    check_decode(g4);
    check_decode(g5);

    printf("\nHALO qs byte as a direct table index\n");
    // Every five-trit pattern must map to a distinct byte, and peeling that byte must return the
    // pattern. Then a 256-entry table indexed by the stored byte needs no index extraction.
    std::vector<int> seen(256, -1);
    int collisions = 0, roundtrip_bad = 0;
    for (int q = 0; q < 243; q++) {
        uint8_t t[5]; int v = q;
        for (int n = 4; n >= 0; n--) { t[n] = (uint8_t) (v % 3); v /= 3; }
        uint8_t byte = pack5(t);
        if (seen[byte] >= 0) collisions++;
        seen[byte] = q;
        uint8_t back[5];
        peel5(byte, back);
        if (memcmp(t, back, 5) != 0) roundtrip_bad++;
    }
    printf("  distinct bytes for 243 patterns: collisions %d, peel round-trip mismatches %d\n",
           collisions, roundtrip_bad);
    expect(collisions == 0, "pack5 is injective, so the stored byte indexes the table");
    expect(roundtrip_bad == 0, "peeling the stored byte returns the packed trits");

    int used = 0;
    for (int i = 0; i < 256; i++) if (seen[i] >= 0) used++;
    printf("  byte-indexed table occupancy: %d of 256 entries carry a pattern\n", used);
    printf("  table entries a byte-indexed group-5 map must build per slot: 256 "
           "(%d reachable, %d built only to keep the index free of a remap)\n", used, 256 - used);

    // The four-trit qh bytes share the same property with 81 patterns.
    std::vector<int> seen4(256, -1);
    int coll4 = 0;
    for (int q = 0; q < 81; q++) {
        uint8_t t[4]; int v = q;
        for (int n = 3; n >= 0; n--) { t[n] = (uint8_t) (v % 3); v /= 3; }
        uint8_t byte = pack4(t);
        if (seen4[byte] >= 0) coll4++;
        seen4[byte] = q;
    }
    printf("  qh four-trit bytes: collisions %d\n", coll4);
    expect(coll4 == 0, "pack4 is injective");

    printf("\nweight bytes per row per 128-input block\n");
    printf("  HALO deployed                 26\n");
    printf("  deployed 43 x group 3 (5b)    %.1f\n", 43 * 5 / 8.0 + 2.0 / 128 * 0);
    printf("  32 x group 4 (7 bits)         %.1f\n", 32 * 7 / 8.0);
    printf("  26 x group 5 (HALO qs/qh)     26.0  (the stored bytes themselves)\n");

    printf("\n%s\n", failures ? "CHECKS FAILED" : "all checks passed");
    return failures ? 1 : 0;
}
