#!/usr/bin/env python3
"""Exact score/gain witness; fixed finite-feature outputs are FP64 diagnostics."""
from fractions import Fraction as F
from hashlib import sha256
import json
import math
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent


def encode_bf16(values):
    data = bytearray()
    for value in values:
        bits = struct.unpack('<I', struct.pack('<f', float(value)))[0]
        assert bits & 65535 == 0, 'witness field must be exact BF16'
        data.extend(struct.pack('<H', bits >> 16))
    return bytes(data)


def decode_bf16(data):
    assert len(data) % 2 == 0
    return [F(struct.unpack('<f', struct.pack('<I', word << 16))[0])
            for (word,) in struct.iter_unpack('<H', data)]


def lse(values):
    top = max(values)
    return top + math.log(sum(math.exp(x - top) for x in values))


def feature_output(q, keys):
    # Two fixed features omega=-1,+1; log-sum computes their actual finite kernel.
    logs = [lse([-float(q + k), float(q + k)])
            - float(q * q + k * k) / 2 - math.log(2) for k in keys]
    return math.exp(logs[1] - lse(logs))


def run():
    paths = [HERE / 'source-gains.bf16', HERE / 'balanced-gains.bf16']
    gains = [[F(1, 4), F(4)], [F(1), F(1)]]
    for path, fields in zip(paths, gains):
        path.write_bytes(encode_bf16(fields))
    decoded = [decode_bf16(path.read_bytes()) for path in paths]
    assert decoded == gains
    source_q = [sign * decoded[0][0] for sign in (-1, 1)]
    source_k = [sign * decoded[0][1] for sign in (-1, 1)]
    balanced_q = [sign * decoded[1][0] for sign in (-1, 1)]
    balanced_k = [sign * decoded[1][1] for sign in (-1, 1)]
    source_scores = [[q * k for k in source_k] for q in source_q]
    balanced_scores = [[q * k for k in balanced_k] for q in balanced_q]
    assert source_scores == balanced_scores == [[F(1), F(-1)], [F(-1), F(1)]]
    assert sum(source_q) == sum(source_k) == sum(balanced_q) == sum(balanced_k) == 0
    mean_exp = lambda qs, ks: sum((q + k) ** 2 for q in qs for k in ks) / 4
    before, after = mean_exp(source_q, source_k), mean_exp(balanced_q, balanced_k)
    assert (before, after) == (F(257, 16), F(2))
    a, b, lam = F(1, 16), F(16), F(4)
    assert a * lam ** 2 + b / lam ** 2 == 2
    # All dyadic exponents are covered by the analytic minimizer, not a search.
    assert b == a * lam ** 4
    rows = []
    for q, qb in zip(source_q, balanced_q):
        teacher = 1 / (1 + math.exp(-float(8 * q)))
        original = feature_output(q, source_k)
        balanced = feature_output(qb, balanced_k)
        rows.append(dict(query=str(q), teacher=teacher, finite_before=original,
                         finite_after=balanced, absolute_error_before=abs(original - teacher),
                         absolute_error_after=abs(balanced - teacher)))
    result = {
        'scope': 'One fixed exact rational source/gain toy; finite two-feature output in float64.',
        'images': [{'file': p.name, 'bytes': p.stat().st_size,
                    'sha256': sha256(p.read_bytes()).hexdigest(),
                    'decoded': list(map(str, fields))} for p, fields in zip(paths, decoded)],
        'gauge': {'lambda': str(lam), 'source_pair_variances': [str(a), str(b)],
                  'source_scores': [[str(x) for x in row] for row in source_scores],
                  'exact_score_preservation': True,
                  'mean_exponent_before': str(before), 'mean_exponent_after': str(after)},
        'fixed_feature_table': [-1, 1],
        'outputs': rows,
        'strong_control': 'Direct sigmoid(8u) is exact and cheaper on the declared two-key toy.',
        'ledger': 'Four existing BF16 gain bytes replaced by four; no new scale/index fields. '
                  'The same two features, exp/sum/normalization work and two-key/value source '
                  'contract are retained; no native code size or latency claim.'
    }
    (HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    run()
