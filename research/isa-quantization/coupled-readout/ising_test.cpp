#include "ising.hpp"

#include <cassert>
#include <chrono>
#include <iostream>
#include <limits>
#include <random>

using coupled_ising::Edge;
using coupled_ising::Result;
using coupled_ising::Status;
using coupled_ising::solve;
using Wide = __int128_t;

static Wide score(const std::vector<std::array<int64_t, 2>>& unary,
                  const std::vector<Edge>& edges, const std::vector<int>& bits) {
    Wide result = 0;
    for (size_t i = 0; i < unary.size(); ++i) result += unary[i][bits[i]];
    for (const Edge& e : edges)
        result += bits[e.u] == bits[e.v] ? e.same : e.different;
    return result;
}

static Wide brute(const std::vector<std::array<int64_t, 2>>& unary,
                  const std::vector<Edge>& edges) {
    Wide best = Wide(1) << 120;
    std::vector<int> bits(unary.size());
    for (uint64_t mask = 0; mask < (uint64_t(1) << unary.size()); ++mask) {
        for (size_t i = 0; i < unary.size(); ++i) bits[i] = (mask >> i) & 1;
        best = std::min(best, score(unary, edges, bits));
    }
    return best;
}

int main() {
    const auto begin = std::chrono::steady_clock::now();
    std::mt19937 rng(20260924);
    uint64_t total_cuts = 0;
    int frustrated = 0;
    for (int trial = 0; trial < 1200; ++trial) {
        int n = trial % 9;
        std::vector<std::array<int64_t, 2>> unary(n);
        for (auto& a : unary)
            for (auto& x : a) x = int(rng() % 19) - 9;
        std::vector<Edge> edges;
        if (n) for (int i = 0, m = int(rng() % 25); i < m; ++i)
            edges.push_back({int(rng() % n), int(rng() % n),
                             int(rng() % 19) - 9, int(rng() % 19) - 9});
        Result r = solve(unary, edges);
        assert(r.status == Status::exact);
        assert(r.bits.size() == unary.size());
        assert(score(unary, edges, r.bits) == r.loss);
        assert(brute(unary, edges) == r.loss);
        total_cuts += r.cuts;
        frustrated += r.conditioned_vertices != 0;
    }
    // Large, dense and arbitrarily signed but gauge-balanced. Each term's
    // separate minimum is attained by the planted assignment, so the sum of
    // those minima independently certifies the global optimum.
    const int n = 192;
    std::vector<int> planted(n);
    std::vector<std::array<int64_t, 2>> unary(n);
    std::vector<Edge> edges;
    Wide certificate = 0;
    for (int i = 0; i < n; ++i) {
        planted[i] = rng() & 1;
        unary[i][planted[i]] = -int64_t(rng() % 10);
        unary[i][!planted[i]] = unary[i][planted[i]] + 1 + rng() % 10;
        certificate += unary[i][planted[i]];
    }
    for (int i = 0; i < n; ++i) for (int j = i + 1; j < n; ++j) {
        int64_t minimum = -int64_t(rng() % 8);
        bool equal = planted[i] == planted[j];
        edges.push_back({i, j, minimum + (equal ? 0 : 3),
                        minimum + (equal ? 3 : 0)});
        certificate += minimum;
    }
    Result large = solve(unary, edges);
    assert(large.status == Status::exact && large.conditioned_vertices == 0);
    assert(large.cuts == 1 && large.loss == certificate);
    assert(score(unary, edges, large.bits) == certificate);
    assert(large.bits == planted);

    std::vector<Edge> triangle{{0, 1, 1, 0}, {1, 2, 1, 0}, {2, 0, 1, 0}};
    auto limited = solve(std::vector<std::array<int64_t, 2>>(3), triangle, 1);
    assert(limited.status == Status::cut_limit_exceeded && limited.bits.empty());
    auto exact = solve(std::vector<std::array<int64_t, 2>>(3), triangle, 2);
    assert(exact.status == Status::exact && exact.conditioned_vertices == 1);
    assert(exact.cuts == 2 && exact.loss == 1);
    std::vector<Edge> frustrated_clique;
    for (int i = 0; i < 20; ++i) for (int j = i + 1; j < 20; ++j)
        frustrated_clique.push_back({i, j, 1, 0});
    auto boundary = solve(std::vector<std::array<int64_t, 2>>(20),
                          frustrated_clique);
    assert(boundary.status == Status::cut_limit_exceeded);
    assert(boundary.conditioned_vertices == 18 && boundary.cuts == 0);
    frustrated_clique.erase(
        std::remove_if(frustrated_clique.begin(), frustrated_clique.end(),
                       [](const Edge& e) { return e.u >= 14 || e.v >= 14; }),
        frustrated_clique.end());
    auto hard = solve(std::vector<std::array<int64_t, 2>>(14),
                      frustrated_clique);
    assert(hard.status == Status::exact && hard.conditioned_vertices == 12);
    assert(hard.cuts == 4096 && hard.loss == 42);
    assert(score(std::vector<std::array<int64_t, 2>>(14),
                 frustrated_clique, hard.bits) == hard.loss);
    assert(solve({{0, 0}}, {{0, 1, 0, 1}}).status == Status::invalid_edge);
    const int64_t min = std::numeric_limits<int64_t>::min();
    const int64_t max = std::numeric_limits<int64_t>::max();
    auto wide = solve({{min, max}, {max, min}}, {{0, 1, max, min}});
    assert(wide.status == Status::loss_overflow && wide.bits.empty());
    // A huge unary difference and huge signed edge difference require >64-bit
    // capacities even when the final exact answer is representable.
    auto extreme = solve({{min, max}, {0, 0}},
                         {{0, 1, max, min}, {0, 0, max, max}, {1, 1, max, max}});
    assert(extreme.status == Status::exact && extreme.loss == -2);
    const auto elapsed = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - begin).count();
    std::cout << "ising oracle cases=1200 frustrated=" << frustrated
              << " cuts=" << total_cuts << " planted_n=" << n
              << " planted_edges=" << edges.size() << " seconds=" << elapsed << '\n';
}
