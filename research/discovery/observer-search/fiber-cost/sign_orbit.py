#!/usr/bin/env python3
"""Exact sign-orbit consumer for every ternary three-coordinate gate/up pair."""
import json
from itertools import product
from pathlib import Path

from bitplanes import TRITS, WEIGHTS, code, target


def representative(q):
    assert 0 <= q < 27
    return min(q, 26 - q)


def word(gate, up):
    result = 0
    for x in TRITS:
        r = representative(code(x))
        y = target(x, gate, up)
        field = y & 3  # signed two-bit encoding: 3 = -1
        previous = (result >> (2 * r)) & 3
        if previous and previous != field:
            raise AssertionError((gate, up, x, previous, field))
        result |= field << (2 * r)
    return result


def signed_bfe(w, r):
    field = (w >> (2 * r)) & 3
    return field if field < 2 else field - 4


def record():
    words = set()
    signatures = {x: [] for x in TRITS}
    three = two = 0
    for g, u in product(WEIGHTS, repeat=2):
        w = word(g, u)
        assert w < (1 << 28)
        words.add(w)
        outputs = set()
        for x in TRITS:
            q = code(x)
            opposite = tuple(-v for v in x)
            assert code(opposite) == 26 - q
            expected = target(x, g, u)
            signatures[x].append(expected)
            assert expected == target(opposite, g, u)
            assert signed_bfe(w, representative(q)) == expected
            outputs.add(expected)
        three += len(outputs) == 3
        two += len(outputs) == 2
    assert len({tuple(v) for v in signatures.values()}) == 14
    for x, y in product(TRITS, repeat=2):
        assert (signatures[x] == signatures[y]) == (x == y or x == tuple(-v for v in y))
    example = ((1, 1, 1), (1, -1, 0))
    witness = word(*example)
    assert len({target(x, *example) for x in TRITS}) == 3
    return {
        "domain": "x in {-1,0,1}^3, g,u in {-1,0,1}^3 excluding zero; q=sum((x_i+1)*3^i)",
        "observation": "sign(SiLU(g dot x)*(u dot x)) with real sigmoid strictly positive",
        "input_coordinate": "r=min(q,26-q), 0..13; 4 bits. BFE offset o=2*r can be supplied by the producer", 
        "output_coordinate": "one signed two-bit field per r, 0/1/3 for zero/positive/negative",
        "family_pairs": len(WEIGHTS)**2,
        "checked_points": len(WEIGHTS)**2 * len(TRITS),
        "three_value_maps": three,
        "two_value_maps": two,
        "distinct_words": len(words),
        "joint_fibers": 14,
        "minimum_fixed_state_bits_for_entire_family": 4,
        "example": {"gate": example[0], "up": example[1], "word": f"0x{witness:08x}"},
        "cost": "one v_bfe_i32 and one 32-bit literal per consumer if offset o=2*r is supplied; two instructions if only r is supplied; from q, sub+min+shift once per shared query plus one BFE per consumer; weight preparation and boundaries excluded", 
    }


if __name__ == "__main__":
    result = record()
    Path(__file__).with_name("sign-orbit-results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
