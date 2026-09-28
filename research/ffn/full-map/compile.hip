#include "paired_phases.hpp"
extern "C" __global__ __launch_bounds__(256, 1) void kelana_compile_probe(
    halo::Ctx c, halo::PrepR prep, _Float16 *planes, const uint8_t *weights,
    const float *signs, float *hidden) {
    halo::ph_pair_prep(c, prep, planes, 8);
    halo::grid_sync(c);
    halo::ph_pair_gate_up<40, 17408>(c, weights, planes, prep.xs, signs, hidden, 8);
}
