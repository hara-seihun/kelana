#pragma once

#include <algorithm>
#include <array>
#include <cstdint>
#include <limits>
#include <numeric>
#include <queue>
#include <vector>

namespace coupled_ising {

// Cost of an edge is `same` for equal original bits, `different` otherwise.
struct Edge {
    int u, v;
    int64_t same, different;
};

enum class Status { exact, invalid_edge, cut_limit_exceeded, loss_overflow };

struct Result {
    Status status = Status::exact;
    int64_t loss = 0;
    std::vector<int> bits;
    int conditioned_vertices = 0;
    uint64_t cuts = 0;
};

namespace detail {
using Wide = __int128_t;

struct Arc {
    int to, rev;
    Wide cap;
};

class Flow {
public:
    explicit Flow(int n) : graph_(n), level_(n), next_(n) {}

    void add(int u, int v, Wide capacity) {
        if (!capacity) return;
        int a = static_cast<int>(graph_[u].size());
        int b = static_cast<int>(graph_[v].size());
        graph_[u].push_back({v, b + (u == v), capacity});
        graph_[v].push_back({u, a, 0});
    }

    Wide maxflow(int source, int sink) {
        Wide total = 0;
        while (levels(source, sink)) {
            std::fill(next_.begin(), next_.end(), 0);
            while (Wide pushed = augment(source, sink, infinity())) total += pushed;
        }
        return total;
    }

    std::vector<int> source_side(int source) const {
        std::vector<int> seen(graph_.size());
        std::queue<int> queue;
        seen[source] = 1;
        queue.push(source);
        while (!queue.empty()) {
            int u = queue.front();
            queue.pop();
            for (const Arc& a : graph_[u]) {
                if (a.cap && !seen[a.to]) {
                    seen[a.to] = 1;
                    queue.push(a.to);
                }
            }
        }
        return seen;
    }

private:
    static constexpr Wide infinity() { return Wide(1) << 120; }

    bool levels(int source, int sink) {
        std::fill(level_.begin(), level_.end(), -1);
        std::queue<int> queue;
        level_[source] = 0;
        queue.push(source);
        while (!queue.empty()) {
            int u = queue.front();
            queue.pop();
            for (const Arc& a : graph_[u]) {
                if (a.cap && level_[a.to] < 0) {
                    level_[a.to] = level_[u] + 1;
                    queue.push(a.to);
                }
            }
        }
        return level_[sink] >= 0;
    }

    Wide augment(int u, int sink, Wide available) {
        if (u == sink) return available;
        for (int& i = next_[u]; i < static_cast<int>(graph_[u].size()); ++i) {
            Arc& a = graph_[u][i];
            if (!a.cap || level_[a.to] != level_[u] + 1) continue;
            Wide pushed = augment(a.to, sink, std::min(available, a.cap));
            if (!pushed) continue;
            a.cap -= pushed;
            graph_[a.to][a.rev].cap += pushed;
            return pushed;
        }
        return 0;
    }

    std::vector<std::vector<Arc>> graph_;
    std::vector<int> level_, next_;
};

struct Link {
    int u, v;
    int64_t same, different;
    Wide weight;
};
}  // namespace detail

// A returned exact result includes an original-bit witness. The cut limit is a
// hard work budget, not an approximation: insufficient budget returns no witness.
// Each connected interaction component is conditioned independently. A gauge
// makes all remaining edges attractive; enumerating the deleted vertices is
// complete, regardless of the deletion heuristic. Capacities and intermediate
// sums use signed 128-bit integers; only the final loss must fit int64_t.
inline Result solve(const std::vector<std::array<int64_t, 2>>& unary,
                    const std::vector<Edge>& edges,
                    uint64_t cut_limit = 65536) {
    using detail::Wide;
    const int n = static_cast<int>(unary.size());
    Result out;
    out.bits.resize(n);
    std::vector<int> parent(n);
    std::iota(parent.begin(), parent.end(), 0);
    auto root = [&](int x) {
        while (parent[x] != x) {
            parent[x] = parent[parent[x]];
            x = parent[x];
        }
        return x;
    };
    std::vector<detail::Link> links;
    Wide fixed = 0;
    for (const Edge& e : edges) {
        if (e.u < 0 || e.v < 0 || e.u >= n || e.v >= n) {
            out.status = Status::invalid_edge;
            out.bits.clear();
            return out;
        }
        if (e.u == e.v || e.same == e.different) {
            fixed += e.same;
            continue;
        }
        links.push_back({e.u, e.v, e.same, e.different,
                         Wide(e.different) - Wide(e.same)});
        parent[root(e.u)] = root(e.v);
    }
    std::vector<std::vector<int>> vertices(n), component_links(n);
    for (int v = 0; v < n; ++v) vertices[root(v)].push_back(v);
    for (int i = 0; i < static_cast<int>(links.size()); ++i)
        component_links[root(links[i].u)].push_back(i);

    Wide optimum = fixed;
    for (int c = 0; c < n; ++c) {
        if (vertices[c].empty()) continue;
        if (component_links[c].empty()) {
            int v = vertices[c].front();
            out.bits[v] = unary[v][1] < unary[v][0];
            optimum += unary[v][out.bits[v]];
            continue;
        }
        std::vector<std::vector<int>> adjacency(n);
        for (int ei : component_links[c]) {
            const auto& e = links[ei];
            adjacency[e.u].push_back(ei);
            adjacency[e.v].push_back(ei);
        }
        std::vector<int> removed(n), gauge(n, -1), conditioned;
        // On a parity conflict, delete the more connected endpoint. Recompute
        // the parity coloring: this is a heuristic deletion set, not a claim of
        // a minimum frustration number.
        for (;;) {
            std::fill(gauge.begin(), gauge.end(), -1);
            int conflict = -1;
            for (int start : vertices[c]) {
                if (removed[start] || gauge[start] >= 0) continue;
                std::queue<int> queue;
                gauge[start] = 0;
                queue.push(start);
                while (!queue.empty() && conflict < 0) {
                    int u = queue.front();
                    queue.pop();
                    for (int ei : adjacency[u]) {
                        const auto& e = links[ei];
                        int v = e.u ^ e.v ^ u;
                        if (removed[v]) continue;
                        int expected = gauge[u] ^ (e.weight < 0);
                        if (gauge[v] < 0) {
                            gauge[v] = expected;
                            queue.push(v);
                        } else if (gauge[v] != expected) {
                            int du = 0, dv = 0;
                            for (int j : adjacency[u])
                                du += !removed[links[j].u ^ links[j].v ^ u];
                            for (int j : adjacency[v])
                                dv += !removed[links[j].u ^ links[j].v ^ v];
                            conflict = dv > du ? v : u;
                            break;
                        }
                    }
                }
                if (conflict >= 0) break;
            }
            if (conflict < 0) break;
            removed[conflict] = 1;
            conditioned.push_back(conflict);
        }
        out.conditioned_vertices += static_cast<int>(conditioned.size());
        // Reject before starting an intractable enumeration, including shifts
        // beyond the width of the cut counter.
        uint64_t available = cut_limit - out.cuts;
        if (conditioned.size() >= 64 || !available ||
            (uint64_t(1) << conditioned.size()) > available) {
            out.status = Status::cut_limit_exceeded;
            out.bits.clear();
            return out;
        }
        std::vector<int> free, index(n, -1);
        for (int v : vertices[c]) {
            if (removed[v]) continue;
            index[v] = static_cast<int>(free.size());
            free.push_back(v);
        }
        Wide best = 0;
        bool have_best = false;
        const uint64_t assignments = uint64_t(1) << conditioned.size();
        for (uint64_t mask = 0; mask < assignments; ++mask) {
            ++out.cuts;
            std::vector<std::array<Wide, 2>> costs(free.size());
            for (int i = 0; i < static_cast<int>(free.size()); ++i) {
                int v = free[i];
                costs[i] = {Wide(unary[v][gauge[v]]),
                            Wide(unary[v][gauge[v] ^ 1])};
            }
            Wide base = 0;
            std::vector<int> assigned(n, 0);
            for (int i = 0; i < static_cast<int>(conditioned.size()); ++i) {
                int v = conditioned[i];
                assigned[v] = (mask >> i) & 1;
                base += unary[v][assigned[v]];
            }
            detail::Flow flow(static_cast<int>(free.size()) + 2);
            int source = static_cast<int>(free.size());
            int sink = source + 1;
            for (int ei : component_links[c]) {
                const auto& e = links[ei];
                int u = index[e.u], v = index[e.v];
                if (u < 0 && v < 0) {
                    base += assigned[e.u] == assigned[e.v] ? e.same : e.different;
                } else if (u < 0 || v < 0) {
                    int selected = u < 0 ? e.u : e.v;
                    int other = u < 0 ? v : u;
                    int other_vertex = u < 0 ? e.v : e.u;
                    for (int bit = 0; bit < 2; ++bit)
                        costs[other][bit] +=
                            (assigned[selected] == (bit ^ gauge[other_vertex]))
                                ? e.same : e.different;
                } else {
                    base += std::min(Wide(e.same), Wide(e.different));
                    flow.add(u, v, e.weight < 0 ? -e.weight : e.weight);
                    flow.add(v, u, e.weight < 0 ? -e.weight : e.weight);
                }
            }
            for (int i = 0; i < static_cast<int>(free.size()); ++i) {
                Wide lo = std::min(costs[i][0], costs[i][1]);
                base += lo;
                flow.add(source, i, costs[i][1] - lo);
                flow.add(i, sink, costs[i][0] - lo);
            }
            Wide value = base + flow.maxflow(source, sink);
            if (!have_best || value < best) {
                have_best = true;
                best = value;
                auto side = flow.source_side(source);
                for (int i = 0; i < static_cast<int>(free.size()); ++i)
                    out.bits[free[i]] = gauge[free[i]] ^ !side[i];
                for (int v : conditioned) out.bits[v] = assigned[v];
            }
        }
        optimum += best;
    }
    if (optimum < std::numeric_limits<int64_t>::min() ||
        optimum > std::numeric_limits<int64_t>::max()) {
        out.status = Status::loss_overflow;
        out.bits.clear();
        return out;
    }
    out.loss = static_cast<int64_t>(optimum);
    return out;
}
}  // namespace coupled_ising
