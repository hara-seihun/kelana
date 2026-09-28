#!/usr/bin/env python3
"""Exact packed three-trit SiLU-gated sign-observer construction."""
import json
from itertools import product
from pathlib import Path

TRITS = tuple(product((-1, 0, 1), repeat=3))
WEIGHTS = tuple(g for g in TRITS if any(g))


def code(x):
    return sum((v + 1) * 3**i for i, v in enumerate(x))


def target(x, gate, up):
    a = sum(g * v for g, v in zip(gate, x))
    b = sum(u * v for u, v in zip(up, x))
    # For real z, sigmoid(z)>0, hence sign(SiLU(z)*b)=sign(z*b).
    return (a * b > 0) - (a * b < 0)


def masks(gate, up):
    pos = neg = 0
    for x in TRITS:
        y = target(x, gate, up)
        pos |= (y == 1) << code(x)
        neg |= (y == -1) << code(x)
    return pos, neg


def bfe(word, offset):
    # v_bfe_u32 width 1 on the packed reachable domain, 0 <= offset <= 26.
    return (word >> offset) & 1


def packed(x, gate, up):
    pos, neg = masks(gate, up)
    return bfe(pos, code(x)) - bfe(neg, code(x))


def record():
    three = two = one = 0
    unique_pairs = set()
    for g, u in product(WEIGHTS, repeat=2):
        p, n = masks(g, u)
        unique_pairs.add((p, n))
        assert p & n == 0
        assert p >> 27 == n >> 27 == 0
        values = {target(x, g, u) for x in TRITS}
        assert all(packed(x, g, u) == target(x, g, u) for x in TRITS)
        if len(values) == 3:
            three += 1
        elif len(values) == 2:
            two += 1
        else:
            one += 1
    # One full-support witness, with both signs reached.
    g, u = (1, 1, 1), (1, -1, 0)
    p, n = masks(g, u)
    assert {target(x, g, u) for x in TRITS} == {-1, 0, 1}
    result = {
        "domain": "x in {-1,0,1}^3, q=sum((x_i+1)*3^i) supplied in one VGPR",
        "observation": "sign(SiLU(g dot x)*(u dot x)), g,u in {-1,0,1}^3 excluding zero",
        "arithmetic": "real SiLU sign reduces to sign(integer product); observation is ternary sign, not engine A4 quantization or native FP32", 
        "families": len(WEIGHTS) ** 2,
        "three_value_maps": three,
        "two_value_maps": two,
        "one_value_maps": one,
        "distinct_endpoint_maps": len(unique_pairs),
        "checked_input_family_pairs": len(WEIGHTS) ** 2 * len(TRITS),
        "example": {"gate": g, "up": u, "positive_mask": f"0x{p:08x}", "negative_mask": f"0x{n:08x}"},
        "program": [f"v_bfe_u32 v1, 0x{p:08x}, v0, 1", f"v_bfe_u32 v2, 0x{n:08x}, v0, 1", "v_sub_u32 v3, v1, v2"],
        "cost": "two BFE plus one subtract per lane, two 32-bit literal words; q construction, coefficient selection, loads and scheduling excluded",
    }
    return result


if __name__ == "__main__":
    output = Path(__file__).with_name("results.json")
    result = record()
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
