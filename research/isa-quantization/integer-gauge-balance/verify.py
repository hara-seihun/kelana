"""Independently verify the exact finite objective and balanced circulation, no optimizer."""
from fractions import Fraction as Q
import hashlib
import json
from pathlib import Path
import time
import numpy as np

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'qwen-coupled-gamma'


def power4(k):
    return Q(4 ** k) if k >= 0 else Q(1, 4 ** -k)


def main():
    start = time.monotonic()
    raw = (HERE / 'certificate.json').read_bytes()
    cert = json.loads(raw)
    source = SOURCE / 'train-pair-moment.npy'
    assert hashlib.sha256(source.read_bytes()).hexdigest() == cert['source_npy_sha256']
    C = np.load(source, allow_pickle=False)
    assert C.shape == (64, 64) and C.dtype == np.float64 and np.isfinite(C).all() and (C > 0).all()
    assert hashlib.sha256(C.astype('<f8').tobytes()).hexdigest() == cert['source_float64_payload_sha256']
    e = cert['optimal_exponents']
    original_e = json.loads((SOURCE / 'prepare.json').read_text())['integer_e']
    assert cert['original_exponents'] == original_e
    assert len(e) == 64 and all(type(x) is int for x in e) and e[0] == 0
    B = [[Q(float(C[a, b])) * power4(e[a] - e[b]) for b in range(64)] for a in range(64)]
    denom = 2 ** cert['common_denominator_power_two']
    G = [[Q(int(x), denom) for x in row] for row in cert['balanced_G_integer']]
    assert len(G) == 64 and all(len(row) == 64 for row in G)
    for a in range(64):
        assert sum(G[a]) == sum(G[b][a] for b in range(64))
        for b in range(64):
            assert B[a][b] <= G[a][b] <= 4 * B[a][b]
    optimum = sum(map(sum, B))
    initial = sum(Q(float(C[a, b])) * power4(original_e[a] - original_e[b]) for a in range(64) for b in range(64))
    for name, value in [('original_F', initial), ('optimal_F', optimum)]:
        receipt = cert[name]
        assert value == Q(int(receipt['numerator']), int(receipt['denominator']))
    # A balanced f=3G/4 in [3B/4,3B] supplies a discrete supporting line
    # on every edge. The report proves that integer-exponential inequality.
    assert optimum <= initial
    result = {
        'certificate_sha256': hashlib.sha256(raw).hexdigest(),
        'source_npy_sha256': cert['source_npy_sha256'],
        'exact_flow_bounds_checked': 4096,
        'exact_balance_equalities_checked': 64,
        'global_integer_optimum_for_exact_stored_matrix': True,
        'source_selected_exponents_unchanged': e == original_e,
        'optimal_F_numerator': str(optimum.numerator),
        'optimal_F_denominator': str(optimum.denominator),
        'optimal_F_decimal': float(optimum),
        'scope': 'Exact dyadic stored C and unrestricted integer gauges; no unrounded-moment or quantized-output optimum claim',
    }
    (HERE / 'verified.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({**result, 'seconds': time.monotonic() - start}, indent=2))


if __name__ == '__main__':
    main()
