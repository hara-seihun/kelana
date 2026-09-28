// Which fixed-radix packings of ternary weight rows fit one FP16 WMMA operand, and how long the
// accumulator may run before the channels have to be separated again.
//
// Setting. Activations are ternary, a in {-1,0,1}. One v_wmma_*_16x16x16_* contributes K = 16
// products to each accumulator. A weight operand carries c ternary channels at radices
// 1 = R_0 < R_1 < ... < R_{c-1}:  w = sum_i R_i * w_i,  w_i in {-1,0,1}.
//
// After n instructions accumulate without separation, the accumulator holds
//   P = sum_i R_i * S_i,  S_i = sum over the 16n products of channel i,  |S_i| <= B = 16n.
//
// Two constraints decide everything:
//   (A) representation: every attainable operand value must be an exact FP16 integer, and the
//       attainable set contains sum_i R_i and sum_i R_i - 2 (odd and even), so the hard limit is
//       sum_i R_i <= 2048, the largest integer below FP16's first gap.
//   (B) separability: peeling from the top, round(P / R_{c-1}) = S_{c-1} requires
//       B * sum_{j<c-1} R_j < R_{c-1} / 2, and the same at every lower level.
//
// Minimising under (B) gives R_i = 2*B*T_{i-1} + 1 with T_i = sum_{j<=i} R_j, so
//   T_i = ((2B+1)^(i+1) - 1) / (2B).
// This program enumerates the feasible region rather than trusting that closed form, reports the
// margin-optimal radices for each shape, and verifies decode exhaustively over every attainable
// digit triple, including a perturbation sweep that measures how much accumulator error each
// choice tolerates.
//
//   c++ -O2 -std=c++17 feasibility.cpp -o build/feasibility && ./build/feasibility
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {

constexpr int FP16_MAX_EXACT_INT = 2048;   // 2^11; 2049 is the first integer FP16 cannot hold

// Smallest feasible radix ladder for c channels at digit bound B, or empty if it does not fit.
std::vector<long long> minimal_ladder(int c, long long B, long long limit = FP16_MAX_EXACT_INT) {
    std::vector<long long> R{1};
    long long T = 1;
    for (int i = 1; i < c; ++i) {
        long long Ri = 2 * B * T + 1;          // need B*T < Ri/2, integers, so Ri >= 2*B*T + 1
        R.push_back(Ri);
        T += Ri;
        if (T > limit) return {};
    }
    return T <= limit ? R : std::vector<long long>{};
}

// Separation margin of a ladder, in units of the accumulator P: at level i the quantity being
// rounded away is bounded by B * T_{i-1}, and the rounding boundary sits at R_i / 2.
double ladder_margin(const std::vector<long long> & R, long long B) {
    double worst = 1e300;
    long long T = 0;
    for (size_t i = 0; i < R.size(); ++i) {
        if (i) worst = std::min(worst, 0.5 * double(R[i]) - double(B) * double(T));
        T += R[i];
    }
    return worst;
}
long long ladder_sum(const std::vector<long long> & R) {
    long long T = 0; for (long long r : R) T += r; return T;
}
std::string ladder_text(const std::vector<long long> & R) {
    std::string s = "[";
    for (size_t i = 0; i < R.size(); ++i) s += (i ? ", " : "") + std::to_string(R[i]);
    return s + "]";
}

// Exhaustive decode check over every attainable digit vector, with the accumulator perturbed by
// `eps`. The decoder is the one the kernel runs: multiply by the FP32 reciprocal of the radix,
// round to nearest even, subtract with an FMA.
//
// `round_bottom` distinguishes two questions. With it set, the whole integer triple must come back
// exactly, which no ladder can survive beyond |eps| = 0.5 because the bottom channel is recovered
// by rounding the residual. Clear, and only the separating divisions are checked: the bottom
// channel is then carried as a float residual, inherits eps as ordinary numerical error, and is
// multiplied by a float scale like any other accumulation. That is what a kernel actually does, so
// the second number is the one that describes how much accumulator error the packing tolerates.
bool decode_survives(const std::vector<long long> & R, long long B, float eps, bool round_bottom) {
    const int c = (int) R.size();
    std::vector<float> inv(c);
    for (int i = 0; i < c; ++i) inv[i] = 1.0f / float(R[i]);
    std::vector<long long> S(c, -B);
    for (;;) {
        double exact = 0;
        for (int i = 0; i < c; ++i) exact += double(R[i]) * double(S[i]);
        float P = float(exact) + eps;
        for (int i = c - 1; i >= 1; --i) {
            float v = std::nearbyintf(P * inv[i]);
            if (v != float(S[i])) return false;
            P = std::fmaf(-float(R[i]), v, P);
        }
        if (round_bottom ? std::nearbyintf(P) != float(S[0])
                         : std::fabs(P - float(S[0])) > std::fabs(eps) + 1e-3f) return false;
        int i = 0;
        while (i < c && ++S[i] > B) S[i++] = -B;
        if (i == c) break;
    }
    return true;
}

// Largest perturbation the ladder tolerates, to 1e-4 in P, by bisection on the exhaustive check.
double tolerance(const std::vector<long long> & R, long long B, bool round_bottom) {
    if (!decode_survives(R, B, 0.0f, round_bottom)) return -1;
    double lo = 0, hi = 1024;
    while (hi - lo > 1e-4) {
        double mid = 0.5 * (lo + hi);
        // A one-sided probe suffices: the decoder is odd in P and the digit set is symmetric.
        if (decode_survives(R, B, (float) mid, round_bottom) &&
            decode_survives(R, B, (float) -mid, round_bottom)) lo = mid;
        else hi = mid;
    }
    return lo;
}

// Margin-optimal ladder for c channels at bound B: search all ladders whose levels are at least
// the minimal ones and whose sum stays within the FP16 limit, maximising the smallest margin.
std::vector<long long> best_ladder(int c, long long B) {
    std::vector<long long> base = minimal_ladder(c, B);
    if (base.empty()) return {};
    if (c == 1) return base;
    std::vector<long long> best;
    double best_margin = -1;
    if (c == 2) {
        for (long long R1 = base[1]; R1 <= FP16_MAX_EXACT_INT - 1; ++R1) {
            std::vector<long long> R{1, R1};
            if (ladder_sum(R) > FP16_MAX_EXACT_INT) break;
            double m = ladder_margin(R, B);
            if (m > best_margin) { best_margin = m; best = R; }
        }
        return best;
    }
    if (c == 3) {
        for (long long R1 = base[1]; ; ++R1) {
            long long R2min = 2 * B * (1 + R1) + 1;
            if (1 + R1 + R2min > FP16_MAX_EXACT_INT) break;
            long long R2 = FP16_MAX_EXACT_INT - 1 - R1;      // largest second radix that still fits
            std::vector<long long> R{1, R1, R2};
            double m = ladder_margin(R, B);
            if (m > best_margin) { best_margin = m; best = R; }
        }
        return best;
    }
    return base;
}

void rule(const char * title) { std::printf("\n== %s ==\n", title); }

}  // namespace

int main() {
    std::printf("FP16 exact-integer limit for an operand value: %d\n", FP16_MAX_EXACT_INT);
    std::printf("Ternary activations, K = 16 products per WMMA, digit bound B = 16 * n for n"
                " instructions accumulated before separation.\n");

    rule("How many ternary channels fit one FP16 operand");
    std::printf("%-3s %-8s %-28s %-9s %-10s\n", "c", "n", "minimal radices", "operand", "verdict");
    for (int c = 1; c <= 5; ++c) {
        std::vector<long long> R = minimal_ladder(c, 16);
        std::printf("%-3d %-8d %-28s %-9lld %s\n", c, 1,
                    R.empty() ? "-" : ladder_text(R).c_str(),
                    R.empty() ? (long long) 0 : ladder_sum(R),
                    R.empty() ? "does not fit FP16" : "fits");
    }
    std::printf("Three channels is the ceiling: a fourth needs an operand of 37060.\n");

    rule("How many WMMAs may accumulate before the channels must be separated");
    std::printf("%-3s %-6s %-30s %-9s\n", "c", "max n", "minimal radices at max n", "operand");
    for (int c = 1; c <= 3; ++c) {
        int best_n = 0;
        std::vector<long long> R;
        for (int n = 1; n <= 4096; ++n) {
            std::vector<long long> cand = minimal_ladder(c, 16LL * n);
            if (cand.empty()) break;
            best_n = n; R = cand;
        }
        std::printf("%-3d %-6d %-30s %-9lld\n", c, best_n, R.empty() ? "-" : ladder_text(R).c_str(),
                    R.empty() ? 0 : ladder_sum(R));
    }
    std::printf("A pair amortises one separation over 63 instructions (K = 1008). A triple must\n"
                "separate after every single instruction: that is the cost this experiment measures.\n");

    rule("Margin-optimal radices, and the accumulator error each tolerates");
    std::printf("%-18s %-4s %-8s %-8s %-11s %-11s  %s\n", "ladder", "ch", "operand", "margin",
                "separation", "all-integer", "shape");
    std::printf("%-18s %-4s %-8s %-8s %-11s %-11s  %s\n", "", "", "", "in P", "tolerance",
                "tolerance", "");
    struct Entry { const char * label; std::vector<long long> R; long long B; };
    std::vector<Entry> entries;
    entries.push_back({"lead's minimal triple", {1, 33, 1089}, 16});
    entries.push_back({"margin-optimal triple", best_ladder(3, 16), 16});
    entries.push_back({"power-of-two triple (needs <=15 nonzero activations per K16)", {1, 32, 1024}, 15});
    entries.push_back({"minimal pair, n = 1", minimal_ladder(2, 16), 16});
    entries.push_back({"pair at n = 8 (one K128 block)", minimal_ladder(2, 128), 128});
    entries.push_back({"margin-optimal pair at n = 8", best_ladder(2, 128), 128});
    entries.push_back({"deployed paired map, n = 8, four-bit activations", {1, 2047}, 889});
    for (const Entry & e : entries) {
        if (e.R.empty()) { std::printf("%-18s infeasible  %s\n", "-", e.label); continue; }
        double sep = tolerance(e.R, e.B, false), all = tolerance(e.R, e.B, true);
        std::printf("%-18s %-4d %-8lld %-8.2f %-11.4f %-11.4f  %s\n", ladder_text(e.R).c_str(),
                    (int) e.R.size(), ladder_sum(e.R), ladder_margin(e.R, e.B), sep, all, e.label);
    }
    std::printf("\nThe all-integer column is pinned just under 0.5 for every ladder, because the bottom\n"
                "channel is recovered by rounding. The separation column is the one a kernel needs, and\n"
                "it is where the radix choice matters: the minimal triple [1, 33, 1089] leaves 0.5 of\n"
                "room in an accumulator that reaches 17968, while [1, 60, 1987] leaves 14 at the cost of\n"
                "filling the FP16 operand exactly to 2048.\n");

    rule("Instruction budget");
    // Measured issue costs come from the rate probe; the arithmetic here is the break-even question.
    std::printf("One triple-packed FP16 WMMA produces the same 48 logical rows x 16 tokens as three\n"
                "native IU4 WMMAs. With f16 at t_f16 and iu4 at t_iu4 per instruction, the decode of\n"
                "8 accumulator elements per lane must fit in 3*t_iu4 - t_f16 to break even.\n");
    return 0;
}
