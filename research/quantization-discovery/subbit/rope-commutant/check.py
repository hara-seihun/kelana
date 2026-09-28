#!/usr/bin/env python3
"""Finite witnesses for the RoPE phase gauge and its packed-key quantizer."""
import hashlib
import json
import math
from pathlib import Path


def rotate(x, angle):
    a, b = x
    c, s = math.cos(angle), math.sin(angle)
    return (c*a-s*b, s*a+c*b)


def dot(x, y):
    return x[0]*y[0]+x[1]*y[1]


def rounded_score(q, k, phase, step):
    # The query is transformed but never quantized; the key becomes a signed-nibble code.
    qr, kr = rotate(q, phase), rotate(k, phase)
    code = tuple(max(-7, min(7, round(z/step))) for z in kr)
    return dot(qr, tuple(z*step for z in code)), code


def main():
    q, k = (1., 1.), (.49, .49)
    step = .75
    target = dot(q, k)
    zero, zero_code = rounded_score(q, k, 0., step)
    turned, turned_code = rounded_score(q, k, math.pi/4, step)
    assert zero_code == (1, 1) and turned_code == (0, 1)
    assert abs(turned-target) < abs(zero-target)
    largest = 0.
    for i in range(201):
        a = ((i*67) % 103-51)/17
        b = ((i*31) % 109-54)/19
        q = (a, b)
        k = (b/3, a/7)
        theta = (i*17 % 83)/13
        phase = (i*11 % 97)/23
        lhs = dot(rotate(q, theta+phase), rotate(k, theta+phase))
        rhs = dot(rotate(q, theta), rotate(k, theta))
        largest = max(largest, abs(lhs-rhs))
    assert largest < 1e-13
    output = {
        'domain': 'real two-coordinate score; independent signed-nibble key quantization with fixed real step; deterministic 201-point floating check',
        'teacher_score': target, 'step': step,
        'phase_zero': {'code': zero_code, 'score': zero, 'absolute_error': abs(zero-target)},
        'phase_pi_over_four': {'code': turned_code, 'score': turned, 'absolute_error': abs(turned-target)},
        'max_float_score_identity_error': largest,
        'source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    Path(__file__).with_name('receipt.json').write_text(json.dumps(output, indent=2)+'\n')
    print(json.dumps(output, indent=2))


if __name__ == '__main__':
    main()
