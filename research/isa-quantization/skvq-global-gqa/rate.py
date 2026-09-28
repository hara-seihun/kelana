"""Exact state-count ledger; no activation replay or new quantization."""
from hashlib import sha256
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESCRIPTOR_SHA = 'ab3aa60bafda9ad741a3dc6f4e544e6d3af08bbf600e861fb70a34d76ef6ad26'


def kivi_before(t):
    if t == 0:
        return 0
    rk = 1 + (t - 1) % 32
    rv = min(t, 33)
    return 8 * (80 * (2 * t - rk - rv) + 256 * (rk + rv))


def kivi_peak(t):
    return max(kivi_before(t), kivi_before(32 * (t // 32)))


def kivi_after(t):
    rk, rv = t % 32, min(t, 32)
    return 8 * (80 * (2 * t - rk - rv) + 256 * (rk + rv))


def skvq(t, before, old_bytes, descriptors):
    retained = min(t, 70 if before else 69)
    return descriptors + 4096 * retained + old_bytes * (t - retained)


def run():
    blob = (HERE / 'global-descriptors.bin').read_bytes()
    assert len(blob) == 4228 and sha256(blob).hexdigest() == DESCRIPTOR_SHA
    desc = json.loads((HERE / 'global-descriptors.json').read_text())
    code_bytes = sum(sum((w + 3) // 4 for w in group['widths'])
                     for group in desc['groups'].values())
    assert code_bytes == 545
    old_bytes = code_bytes + 2 * 32 * 2 * 2
    assert old_bytes == desc['old_token_bytes'] == 801
    rows = []
    kq = vq = kr = vr = 0
    high = 0
    for t in range(1, 8193):
        kr += 1
        vr += 1
        high = max(high, 8 * (2560 * kq + 80 * vq + 256 * (kr + vr)))
        assert high == kivi_peak(t)
        if kr == 32:
            kr = 0
            kq += 1
        if vr == 33:
            vr -= 1
            vq += 1
        assert 8 * (2560 * kq + 80 * vq + 256 * (kr + vr)) == kivi_after(t)
        rows.append({'tokens': t, 'skvq_peak': skvq(t, True, old_bytes, len(blob)),
                     'kivi_peak': high, 'skvq_final': skvq(t, False, old_bytes, len(blob)),
                     'kivi_final': kivi_after(t)})
    crossover = {}
    for stage in ('peak', 'final'):
        a, b = 'skvq_' + stage, 'kivi_' + stage
        first = next(r['tokens'] for r in rows if r[a] < r[b])
        permanent = 1 + max(r['tokens'] for r in rows if r[a] >= r[b])
        # For every residue mod32 after saturation, the gap decreases by15328B/block.
        assert all(rows[t + 31][a] - rows[t + 31][b] == rows[t - 1][a] - rows[t - 1][b] - 15328
                   for t in range(70, 8192 - 31))
        crossover[stage] = {'first_strictly_smaller': first, 'always_smaller_from': permanent}
    selected = (256, 288, 314, 315, 320, 332, 333, 338, 339, 384, 385, 386, 416, 4096)
    record = {'descriptor_sha256': DESCRIPTOR_SHA, 'old_skvq_token_bytes': old_bytes,
              'old_kivi_token_bytes': 1280, 'static_skvq_descriptor_bytes': len(blob),
              'asymptotic_bits_per_KV_coordinate': {'skvq': 801 * 8 / 2048, 'kivi': 5},
              'closed_form_count_checks': 8192, 'crossovers': crossover,
              'points': [rows[t - 1] for t in selected],
              'scope': 'Serialized cache state plus SKVQ descriptors only; no quality beyond the original256 tokens, no native work or scratch.'}
    assert rows[255]['skvq_peak'] == desc['peak_256_bytes'] == 439934
    assert rows[255]['skvq_final'] == desc['resident_256_bytes'] == 436639
    (HERE / 'rate.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    run()
