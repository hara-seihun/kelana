// Native CPU cost probe: 64-bit nibble labels versus 128-bit byte labels.
#include <immintrin.h>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

constexpr int N = 32, CASES = 128, STATES = 16;
using Map = uint64_t;
using Clock = std::chrono::steady_clock;
volatile uint64_t sink = 0;

inline int at(Map map, int state) { return (map >> (4 * state)) & 15; }
Map identity() {
    Map result = 0;
    for (int s = 0; s < STATES; ++s) result |= Map(s) << (4 * s);
    return result;
}
inline Map compose(Map left, Map right) {
    Map result = 0;
    for (int s = 0; s < STATES; ++s)
        result |= Map(at(right, at(left, s))) << (4 * s);
    return result;
}

struct ByteMap { __m128i lanes; };
inline ByteMap byte_identity() {
    return {_mm_setr_epi8(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)};
}
inline ByteMap byte_next() {
    return {_mm_setr_epi8(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0)};
}
inline ByteMap byte_compose(ByteMap left, ByteMap right) {
    return {_mm_shuffle_epi8(right.lanes, left.lanes)};
}
inline int byte_at(ByteMap map, int state) {
    return _mm_cvtsi128_si32(_mm_shuffle_epi8(map.lanes, _mm_set1_epi8(state))) & 255;
}

struct Fixture {
    std::array<std::array<uint8_t, STATES>, N> thresholds{};
    std::array<std::array<uint8_t, N>, CASES> uniforms{};
    std::array<std::array<Map, N>, CASES> prepared{};
    std::array<std::array<ByteMap, N>, CASES> byte_prepared{};
};

inline int draw(const Fixture &f, int t, int s, int u) {
    return u < f.thresholds[t][s] ? s : ((s + 1) & 15);
}
Map construct(const Fixture &f, int t, int u) {
    Map result = 0;
    for (int s = 0; s < STATES; ++s)
        result |= Map(draw(f, t, s, u)) << (4 * s);
    return result;
}
ByteMap byte_construct(const Fixture &f, int t, int u) {
    __m128i threshold = _mm_loadu_si128(reinterpret_cast<const __m128i *>(f.thresholds[t].data()));
    __m128i stay = _mm_cmpgt_epi8(threshold, _mm_set1_epi8(u));
    return {_mm_blendv_epi8(byte_next().lanes, byte_identity().lanes, stay)};
}
Fixture make_fixture() {
    Fixture f;
    uint32_t seed = 0x21348c19;
    auto random = [&]() { seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5; return seed; };
    for (int t = 0; t < N; ++t)
        for (int s = 0; s < STATES; ++s) f.thresholds[t][s] = 2 + random() % 6;
    for (int c = 0; c < CASES; ++c)
        for (int t = 0; t < N; ++t) f.uniforms[c][t] = random() & 7;
    for (int c = 0; c < CASES; ++c)
        for (int t = 0; t < N; ++t) {
            f.prepared[c][t] = construct(f, t, f.uniforms[c][t]);
            f.byte_prepared[c][t] = byte_construct(f, t, f.uniforms[c][t]);
        }
    return f;
}

int direct_path(const Fixture &f, int c) {
    int state = c & 15;
    for (int t = 0; t < N; ++t) state = draw(f, t, state, f.uniforms[c][t]);
    return state;
}
int construct_then_consume(const Fixture &f, int c) {
    int state = c & 15;
    for (int t = 0; t < N; ++t)
        state = at(construct(f, t, f.uniforms[c][t]), state);
    return state;
}
int construct_then_compose(const Fixture &f, int c) {
    Map accumulated = identity();
    for (int t = 0; t < N; ++t)
        accumulated = compose(accumulated, construct(f, t, f.uniforms[c][t]));
    return at(accumulated, c & 15);
}
int build_only(const Fixture &f, int c) {
    uint64_t checksum = 0;
    for (int t = 0; t < N; ++t) checksum ^= construct(f, t, f.uniforms[c][t]);
    return int((checksum ^ (checksum >> 32)) & 0x7fffffff);
}
int prepared_compose(const Fixture &f, int c) {
    Map accumulated = identity();
    for (int t = 0; t < N; ++t) accumulated = compose(accumulated, f.prepared[c][t]);
    return at(accumulated, c & 15);
}
int prepared_serial_prefix(const Fixture &f, int c) {
    Map accumulated = identity();
    uint64_t checksum = 0;
    for (int t = 0; t < N; ++t) {
        accumulated = compose(accumulated, f.prepared[c][t]);
        checksum += at(accumulated, c & 15);
    }
    return int(checksum);
}
int nibble_tree_prefix(const std::array<Map, N> &maps, int state) {
    std::array<Map, N> tree = maps, exclusive{};
    for (int stride = 2; stride <= N; stride *= 2)
        for (int i = stride - 1; i < N; i += stride)
            tree[i] = compose(tree[i - stride / 2], tree[i]);
    tree[N - 1] = identity();
    for (int stride = N; stride >= 2; stride /= 2)
        for (int i = stride - 1; i < N; i += stride) {
            Map prior = tree[i];
            tree[i] = compose(prior, tree[i - stride / 2]);
            tree[i - stride / 2] = prior;
        }
    exclusive = tree;
    uint64_t checksum = 0;
    for (int t = 0; t < N; ++t)
        checksum += at(compose(exclusive[t], maps[t]), state);
    return int(checksum);
}
int prepared_tree(const Fixture &f, int c) {
    return nibble_tree_prefix(f.prepared[c], c & 15);
}
int build_serial_prefix(const Fixture &f, int c) {
    Map accumulated = identity();
    int checksum = 0;
    for (int t = 0; t < N; ++t) {
        accumulated = compose(accumulated, construct(f, t, f.uniforms[c][t]));
        checksum += at(accumulated, c & 15);
    }
    return checksum;
}
int build_tree_prefix(const Fixture &f, int c) {
    std::array<Map, N> maps;
    for (int t = 0; t < N; ++t) maps[t] = construct(f, t, f.uniforms[c][t]);
    return nibble_tree_prefix(maps, c & 15);
}

int byte_build_only(const Fixture &f, int c) {
    uint64_t checksum = 0;
    for (int t = 0; t < N; ++t) {
        __m128i map = byte_construct(f, t, f.uniforms[c][t]).lanes;
        uint64_t low = static_cast<uint64_t>(_mm_cvtsi128_si64(map));
        uint64_t high = static_cast<uint64_t>(_mm_cvtsi128_si64(_mm_srli_si128(map, 8)));
        checksum ^= low ^ (high * 0x9e3779b97f4a7c15ULL);
    }
    return int((checksum ^ (checksum >> 32)) & 0x7fffffff);
}
int byte_build_consume(const Fixture &f, int c) {
    int state = c & 15;
    for (int t = 0; t < N; ++t)
        state = byte_at(byte_construct(f, t, f.uniforms[c][t]), state);
    return state;
}
int byte_build_compose(const Fixture &f, int c) {
    ByteMap accumulated = byte_identity();
    for (int t = 0; t < N; ++t)
        accumulated = byte_compose(accumulated, byte_construct(f, t, f.uniforms[c][t]));
    return byte_at(accumulated, c & 15);
}
int byte_prepared_compose(const Fixture &f, int c) {
    ByteMap accumulated = byte_identity();
    for (int t = 0; t < N; ++t)
        accumulated = byte_compose(accumulated, f.byte_prepared[c][t]);
    return byte_at(accumulated, c & 15);
}
int byte_prepared_serial_prefix(const Fixture &f, int c) {
    ByteMap accumulated = byte_identity();
    int checksum = 0;
    for (int t = 0; t < N; ++t) {
        accumulated = byte_compose(accumulated, f.byte_prepared[c][t]);
        checksum += byte_at(accumulated, c & 15);
    }
    return checksum;
}
int byte_tree_prefix(const std::array<ByteMap, N> &maps, int state) {
    std::array<ByteMap, N> tree = maps;
    for (int stride = 2; stride <= N; stride *= 2)
        for (int i = stride - 1; i < N; i += stride)
            tree[i] = byte_compose(tree[i - stride / 2], tree[i]);
    tree[N - 1] = byte_identity();
    for (int stride = N; stride >= 2; stride /= 2)
        for (int i = stride - 1; i < N; i += stride) {
            ByteMap prior = tree[i];
            tree[i] = byte_compose(prior, tree[i - stride / 2]);
            tree[i - stride / 2] = prior;
        }
    int checksum = 0;
    for (int t = 0; t < N; ++t)
        checksum += byte_at(byte_compose(tree[t], maps[t]), state);
    return checksum;
}
int byte_prepared_tree(const Fixture &f, int c) {
    return byte_tree_prefix(f.byte_prepared[c], c & 15);
}
int byte_build_serial_prefix(const Fixture &f, int c) {
    ByteMap accumulated = byte_identity();
    int checksum = 0;
    for (int t = 0; t < N; ++t) {
        accumulated = byte_compose(accumulated, byte_construct(f, t, f.uniforms[c][t]));
        checksum += byte_at(accumulated, c & 15);
    }
    return checksum;
}
int byte_build_tree_prefix(const Fixture &f, int c) {
    std::array<ByteMap, N> maps;
    for (int t = 0; t < N; ++t) maps[t] = byte_construct(f, t, f.uniforms[c][t]);
    return byte_tree_prefix(maps, c & 15);
}

template <class F> double measure(const Fixture &f, int repeats, F fn) {
    auto begin = Clock::now();
    uint64_t checksum = 0;
    for (int i = 0; i < repeats; ++i) checksum += fn(f, i & (CASES - 1));
    sink = sink ^ checksum;
    auto end = Clock::now();
    return std::chrono::duration<double, std::nano>(end - begin).count() / repeats;
}
int main(int argc, char **argv) {
    int repeats = argc == 2 ? std::atoi(argv[1]) : 20000;
    if (repeats < CASES) return 2;
    const auto fixture = make_fixture();
    for (int c = 0; c < CASES; ++c) {
        int answer = direct_path(fixture, c);
        if (answer != construct_then_consume(fixture, c) ||
            answer != construct_then_compose(fixture, c) ||
            answer != prepared_compose(fixture, c)) return 3;
        Map acc = identity();
        for (int t = 0; t < N; ++t) acc = compose(acc, fixture.prepared[c][t]);
        if (at(acc, c & 15) != answer) return 4;
        int state = c & 15;
        Map prefix = identity();
        uint64_t expected = 0;
        for (int t = 0; t < N; ++t) {
            prefix = compose(prefix, fixture.prepared[c][t]);
            expected += at(prefix, state);
        }
        if (prepared_tree(fixture, c) != expected ||
            prepared_serial_prefix(fixture, c) != expected ||
            build_serial_prefix(fixture, c) != expected ||
            build_tree_prefix(fixture, c) != expected) return 5;
        if (byte_build_consume(fixture, c) != answer ||
            byte_build_compose(fixture, c) != answer ||
            byte_prepared_compose(fixture, c) != answer ||
            byte_prepared_serial_prefix(fixture, c) != expected ||
            byte_prepared_tree(fixture, c) != expected ||
            byte_build_serial_prefix(fixture, c) != expected ||
            byte_build_tree_prefix(fixture, c) != expected) return 6;
        Map nibble_prefix = identity();
        ByteMap byte_prefix = byte_identity();
        for (int t = 0; t < N; ++t) {
            for (int s = 0; s < STATES; ++s)
                if (byte_at(fixture.byte_prepared[c][t], s) != at(fixture.prepared[c][t], s))
                    return 7;
            nibble_prefix = compose(nibble_prefix, fixture.prepared[c][t]);
            byte_prefix = byte_compose(byte_prefix, fixture.byte_prepared[c][t]);
            for (int s = 0; s < STATES; ++s)
                if (byte_at(byte_prefix, s) != at(nibble_prefix, s)) return 8;
        }
    }
    double direct = measure(fixture, repeats, direct_path);
    double build = measure(fixture, repeats, build_only);
    double build_consume = measure(fixture, repeats, construct_then_consume);
    double build_compose = measure(fixture, repeats, construct_then_compose);
    double composed = measure(fixture, repeats, prepared_compose);
    double serial = measure(fixture, repeats, prepared_serial_prefix);
    double tree = measure(fixture, repeats, prepared_tree);
    double full_serial = measure(fixture, repeats, build_serial_prefix);
    double full_tree = measure(fixture, repeats, build_tree_prefix);
    double byte_build = measure(fixture, repeats, byte_build_only);
    double byte_consume = measure(fixture, repeats, byte_build_consume);
    double byte_full = measure(fixture, repeats, byte_build_compose);
    double byte_composed = measure(fixture, repeats, byte_prepared_compose);
    double byte_serial = measure(fixture, repeats, byte_prepared_serial_prefix);
    double byte_tree = measure(fixture, repeats, byte_prepared_tree);
    double byte_full_serial = measure(fixture, repeats, byte_build_serial_prefix);
    double byte_full_tree = measure(fixture, repeats, byte_build_tree_prefix);
    std::printf("{\"steps\":%d,\"states\":%d,\"cases\":%d,\"repeats\":%d,"
                "\"ns_per_sequence\":{\"direct_path\":%.1f,\"build_only\":%.1f,"
                "\"build_then_consume\":%.1f,\"build_then_compose\":%.1f,"
                "\"prepared_compose_endpoint\":%.1f,\"prepared_serial_prefix_and_consume\":%.1f,"
                "\"prepared_tree_prefix_and_consume\":%.1f,"
                "\"build_serial_prefix_and_consume\":%.1f,"
                "\"build_tree_prefix_and_consume\":%.1f,"
                "\"byte_build_only\":%.1f,\"byte_build_then_consume\":%.1f,"
                "\"byte_build_then_compose\":%.1f,\"byte_prepared_compose_endpoint\":%.1f,"
                "\"byte_prepared_serial_prefix_and_consume\":%.1f,"
                "\"byte_prepared_tree_prefix_and_consume\":%.1f,"
                "\"byte_build_serial_prefix_and_consume\":%.1f,"
                "\"byte_build_tree_prefix_and_consume\":%.1f},\"checksum\":%llu}\n",
                N, STATES, CASES, repeats, direct, build, build_consume, build_compose,
                composed, serial, tree, full_serial, full_tree, byte_build, byte_consume,
                byte_full, byte_composed, byte_serial, byte_tree, byte_full_serial,
                byte_full_tree, static_cast<unsigned long long>(sink));
}
