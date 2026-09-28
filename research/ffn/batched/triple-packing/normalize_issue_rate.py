#!/usr/bin/env python3
"""Derive per-SIMD instruction costs from the stored issue-rate samples.

`results/issue-rate.json` records `ns per work unit per wave`, and its `waves_per_simd` field is
the value the probe printed when it read HIP's 20 work-group processors as 20 SIMD32 units rather
than 80. The stored labels are therefore twice the physical waves per SIMD, and dividing a stored
value by its own label yields half the true per-instruction cost.

This recomputes the costs from the stored numbers without touching them.

    python3 normalize_issue_rate.py results/issue-rate.json --out results/issue-rate-per-simd.json
"""
import argparse
import hashlib
import json
from pathlib import Path

PHYSICAL_SIMDS = 80
STORED_SIMDS = 40          # what the probe assumed when these samples were recorded
BLOCK_WAVES = 4
INSTRUCTION_COLUMNS = ('f16_wmma', 'iu4_wmma', 'valu_op')
UNIT_COLUMNS = ('iu4x3', 'triple', 'triple_pow2', 'pair_scaled_to_48_rows',
                'packed_ceiling_no_decode')
MAC_PER_WMMA = 16 * 16 * 16


def divisor(label):
    """Waves sharing one SIMD, floored at one.

    The probe launched `STORED_SIMDS * label / BLOCK_WAVES` blocks of `BLOCK_WAVES` waves, so
    `STORED_SIMDS * label` waves ran on PHYSICAL_SIMDS units. Below one wave per SIMD the surplus
    units simply idle, which does not shorten the elapsed time of the waves that do run.
    """
    waves = STORED_SIMDS * label
    return max(1.0, waves / PHYSICAL_SIMDS)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('source', type=Path)
    p.add_argument('--out', type=Path)
    a = p.parse_args()
    data = json.loads(a.source.read_text())
    rows = []
    for r in data['rows']:
        label = r['waves_per_simd']
        d = divisor(label)
        row = {'stored_waves_per_simd_label': label,
               'resident_waves': STORED_SIMDS * label,
               'physical_waves_per_simd': STORED_SIMDS * label / PHYSICAL_SIMDS,
               'divisor_applied': d}
        for k in INSTRUCTION_COLUMNS + UNIT_COLUMNS:
            if k in r:
                row[k + '_ns_per_simd'] = round(r[k] / d, 4)
        if 'iu4_wmma' in r:
            row['iu4_mac_per_ns_per_simd'] = round(MAC_PER_WMMA / (r['iu4_wmma'] / d), 1)
            row['device_tops_at_this_rate'] = round(
                MAC_PER_WMMA / (r['iu4_wmma'] / d) * PHYSICAL_SIMDS * 2 / 1000.0, 1)
        rows.append(row)
    print(f"{'label':>6} {'waves':>6} {'phys/SIMD':>10} {'f16 ns':>8} {'iu4 ns':>8} "
          f"{'valu ns':>8} {'iu4 MAC/ns/SIMD':>16} {'TOPS':>7}")
    for r in rows:
        print(f"{r['stored_waves_per_simd_label']:>6} {r['resident_waves']:>6} "
              f"{r['physical_waves_per_simd']:>10.1f} {r['f16_wmma_ns_per_simd']:>8.3f} "
              f"{r['iu4_wmma_ns_per_simd']:>8.3f} {r['valu_op_ns_per_simd']:>8.4f} "
              f"{r['iu4_mac_per_ns_per_simd']:>16.1f} {r['device_tops_at_this_rate']:>7.1f}")
    report = {
        'derived_from': str(a.source),
        'source_sha256': hashlib.sha256(a.source.read_bytes()).hexdigest(),
        'unit': data.get('unit'),
        'device': data.get('device'),
        'what_this_corrects':
            'The stored waves_per_simd field was printed against 40 assumed SIMD32 units; the '
            'physical count is 80, so each stored label is twice the physical waves per SIMD. '
            'Dividing a stored value by its own label halves the per-instruction cost.',
        'normalization':
            'Stored values are ns per work unit per wave with resident_waves waves running. One '
            'SIMD issues divisor_applied waves concurrently, so the per-SIMD cost of one '
            'instruction is the stored value divided by divisor_applied.',
        'scope':
            'Arithmetic on recorded elapsed times. Not a cycle count, not a clock measurement, '
            'and not a re-run of the probe.',
        'physical_simds': PHYSICAL_SIMDS,
        'rows': rows,
    }
    if a.out:
        a.out.write_text(json.dumps(report, indent=2) + '\n')
        print(f'wrote {a.out}')


if __name__ == '__main__':
    main()
