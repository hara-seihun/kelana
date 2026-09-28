#!/usr/bin/env python3
"""Check the scoped top-k softmax law and inspect Qwen's captured route scores."""
import hashlib
import json
import math
from pathlib import Path
import struct

N = 256
K = 8
ROOT = Path('/path/to/workspace/data/qwen-moe/route-capture')
OUT = Path('/path/to/workspace/data/qwen-moe/router-observer/receipt.json')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def captured(split, rows):
    id_path = ROOT / f'{split}.0.ffn_moe_topk-0.bin'
    score_path = ROOT / f'{split}.0.ffn_moe_weights_norm-0.bin'
    ids = struct.unpack(f'<{rows*K}i', id_path.read_bytes())
    scores = struct.unpack(f'<{rows*K}f', score_path.read_bytes())
    sums = [math.fsum(scores[i*K:(i+1)*K]) for i in range(rows)]
    assert all(len(set(ids[i*K:(i+1)*K])) == K and
               all(0 <= x < N for x in ids[i*K:(i+1)*K]) for i in range(rows))
    assert all(math.isfinite(x) and x >= 0 for x in scores)
    return {
        'rows': rows, 'id_sha256': digest(id_path), 'score_sha256': digest(score_path),
        'min_sum': min(sums), 'max_sum': max(sums),
        'min_score': min(scores), 'max_score': max(scores),
        'rows_not_close_to_one_1e-5': sum(abs(s-1) > 1e-5 for s in sums),
    }


def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]


def rounded_counterexample():
    # A nearby unselected logit changes the full softmax denominator. Rounded
    # probabilities can tie even though the underlying logits are distinct.
    logits = [-1.0]*N
    logits[:7] = [1.0]*7
    logits[7], logits[8] = f32(0.0), f32(1e-8)
    numerator = [f32(math.exp(f32(x))) for x in logits]
    denom = f32(sum(numerator))
    probs = [f32(f32(x)/denom) for x in numerator]
    raw_top = sorted(range(N), key=lambda i: (-logits[i], i))[:K]
    rounded_top = sorted(range(N), key=lambda i: (-probs[i], i))[:K]
    assert logits[8] > logits[7] and probs[7] == probs[8] and set(raw_top) != set(rounded_top)
    return {'logit_7': logits[7], 'logit_8': logits[8],
            'rounded_probability_7': probs[7], 'rounded_probability_8': probs[8],
            'raw_top': raw_top, 'rounded_top': rounded_top}


def main():
    output = {
        'contract': 'finite real logits, fixed 256 experts and 8 routed choices; no bias, with_norm=true; real-arithmetic identity only, not the HIP FP32 map',
        'selected_source': 'Qwen35MoE build_layer_ffn: softmax gating and norm_w=true',
        'clamp': 6.103515625e-5,
        'proved_min_selected_mass': K/N,
        'full_exp_evaluations': N, 'shortcut_exp_evaluations': K-1,
        'full_preselection_sum_terms': N, 'shortcut_preselection_sum_terms': 0,
        'splits': {'train': captured('train', 113), 'held': captured('held', 126)},
        'fp32_counterexample': rounded_counterexample(),
        'source_sha256': digest(Path(__file__)),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(output, indent=2, sort_keys=True) + '\n')
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
