#!/usr/bin/env python3
"""Frozen KIVI K/V error interaction; no new fitted or deployed cache program."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
import torch

HERE = Path(__file__).resolve().parent
OWNER = HERE.parent / 'kivi-causal-cache'
sys.path.insert(0, str(OWNER))
import source
import replay


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def packed_prefixes(panel, window, src):
    manifest = json.loads((OWNER / f'{panel}-{window}-manifest.json').read_text())
    log = (OWNER / f'{panel}-{window}-flush.bin').read_bytes()
    assert hashlib.sha256(log).hexdigest() == manifest['flush_log_sha256']
    kq, vq, kr, vr, at = [], [], [], [], 0
    for t in range(1, 257):
        kr.append(src['key'][t - 1].astype('<u2').tobytes())
        vr.append(src['value'][t - 1].astype('<u2').tobytes())
        packed = b''.join(kq + vq + kr + vr)
        receipt = manifest['prefixes'][t - 1]['before_flush']
        assert len(packed) == receipt['live_state_bytes']
        assert hashlib.sha256(packed).hexdigest() == receipt['sha256']
        yield t, replay.decode(packed, len(kq) * 32, len(vq), len(kr), len(vr))
        for kind, count in [('K', 2560), ('V', 80)]:
            ready = len(kr) == 32 if kind == 'K' else len(vr) > 32
            if ready:
                assert log[at:at + 1] == kind.encode()
                assert int.from_bytes(log[at + 1:at + 3], 'little') == t
                payload = log[at + 3:at + 3 + count]
                assert len(payload) == count
                at += 3 + count
                if kind == 'K':
                    kq.append(payload)
                    kr = []
                else:
                    vq.append(payload)
                    vr.pop(0)
        post = b''.join(kq + vq + kr + vr)
        assert hashlib.sha256(post).hexdigest() == manifest['prefixes'][t - 1]['after_flush']['sha256']
    assert at == len(log)
    assert post == (OWNER / f'{panel}-{window}-final.bin').read_bytes()


def run(panel, window):
    torch.set_num_threads(1)
    src = source.arrays(panel, window)
    key = src['krot'].double()
    value = src['vraw'].double()
    queries = [q.double() for q in src['qrot']]
    output = src['o'].double()
    names = ['reference', 'key', 'value', 'cross', 'both', 'key_linear']
    records = {name: [[], []] for name in names}
    max_probability_sum_error = 0.
    with torch.no_grad():
        for t, (decoded_k, decoded_v) in packed_prefixes(panel, window, src):
            khat = torch.from_numpy(decoded_k.copy()).double()
            vhat = torch.from_numpy(decoded_v.copy()).double()
            v = value[:t]
            dv = vhat - v
            for h, qs in enumerate(queries):
                q = qs[t - 1]
                logits = q @ key[:t].T / math.sqrt(128)
                changed_logits = q @ khat.T / math.sqrt(128)
                p = logits.softmax(-1)
                a = changed_logits.softmax(-1)
                dp = a - p
                ref = p @ v
                key_error = dp @ v
                value_error = p @ dv
                interaction = dp @ dv
                both = a @ vhat - ref
                e = changed_logits - logits
                key_linear = (p * (e - p @ e)) @ v
                max_probability_sum_error = max(max_probability_sum_error, float(dp.sum().abs()))
                for name, vec in zip(names, [ref, key_error, value_error, interaction, both, key_linear]):
                    records[name][h].append(vec)
    projected = {}
    for name in names:
        projected[name] = sum(torch.stack(records[name][h]) @ output[:, h * 128:(h + 1) * 128].T
                              for h in range(2))
    k, v, cross, both = (projected[name] for name in ('key', 'value', 'cross', 'both'))
    closure = float((both - k - v - cross).abs().max())
    assert closure < 1e-11
    inner = lambda x, y: float((x * y).sum())
    squares = {name: inner(val, val) for name, val in projected.items()}
    terms = {'key_value': 2 * inner(k, v), 'key_cross': 2 * inner(k, cross),
             'value_cross': 2 * inner(v, cross)}
    reconstructed = squares['key'] + squares['value'] + squares['cross'] + sum(terms.values())
    assert abs(reconstructed - squares['both']) < 1e-10 * max(1., squares['both'])
    linear = projected['key_linear'] + v
    result = {'panel': panel, 'window': window,
              'arithmetic': 'Frozen BF16/FP32 source and FP32-decoded paid cache, then FP64 softmax/value/O diagnostic.',
              'source_sha256': digest(OWNER / 'source.py'), 'decoder_sha256': digest(OWNER / 'replay.py'),
              'manifest_sha256': digest(OWNER / f'{panel}-{window}-manifest.json'),
              'original_kivi_result_sha256': digest(OWNER / f'{panel}-{window}-result.json'),
              'squared_norms': squares, 'twice_inner_products': terms,
              'linear_prediction_squared_norm': inner(linear, linear),
              'linear_prediction_discrepancy_squared': inner(linear - both, linear - both),
              'exact_identity_max_abs': closure,
              'probability_difference_mass_max_abs': max_probability_sum_error,
              'pair_relative_squared': {name: sq / squares['reference'] for name, sq in squares.items() if name != 'reference'}}
    (HERE / f'{panel}-{window}.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'panel': panel, 'window': window, 'errors': result['pair_relative_squared'],
                      'key_value_cross': terms['key_value'] / squares['reference']}, indent=2))


if __name__ == '__main__':
    run(sys.argv[1], int(sys.argv[2]))
