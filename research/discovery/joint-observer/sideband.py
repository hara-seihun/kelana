#!/usr/bin/env python3
"""Exact side information needed to repair the eleven-state joint carrier.

Input q is the five-bit packed three-trit word, 0..26. These statements concern
finite integer maps, not floating-point evaluation of the trained FFN.
"""
from collections import defaultdict
import json


def carrier(q):
    if q not in range(27):
        raise ValueError("the packed three-trit domain is 0..26")
    return (27 * q // 64) - 5


def fibers():
    result = defaultdict(list)
    for q in range(27):
        result[carrier(q)].append(q)
    return dict(sorted(result.items()))


def repair(side):
    """Build the inverse of (h, side) or return a concrete collision."""
    if len(side) != 27:
        raise ValueError("one side label per packed input is required")
    inverse = {}
    for q, label in enumerate(side):
        key = (carrier(q), label)
        if key in inverse:
            return None, (inverse[key], q)
        inverse[key] = q
    return inverse, None


def bits_needed():
    return (max(map(len, fibers().values())) - 1).bit_length()


def mask_witnesses():
    # An AND mask is one gfx1151 VALU instruction. Values >31 cannot distinguish
    # packed inputs any better; their extra bits are zero on this domain.
    return [mask for mask in range(1, 32)
            if repair([q & mask for q in range(27)])[1] is None]


def report():
    partition = fibers()
    inverse, collision = repair([q & 3 for q in range(27)])
    assert collision is None
    assert all(inverse[(carrier(q), q & 3)] == q for q in range(27))
    # This is the exhaustive lower bound for arbitrary one-bit side functions:
    # a fiber with three distinct q cannot inject into {0,1}.
    assert bits_needed() == 2
    # The stronger one-instruction screen enumerates all AND masks on q.
    masks = mask_witnesses()
    assert masks[0] == 3
    assert all((mask & 3) == 3 for mask in masks)
    return {"domain": "q in [0,26]", "carrier": "floor(27*q/64)-5",
            "fibers": {str(h): qs for h, qs in partition.items()},
            "minimum_arbitrary_side_labels": max(map(len, partition.values())),
            "minimum_fixed_width_side_bits": bits_needed(),
            "least_mask": 3, "injective_and_masks_5bit": masks,
            "inverse": [{"h": h, "s": s, "q": q}
                        for (h, s), q in sorted(inverse.items())],
            "single_bit_collision": repair([q & 1 for q in range(27)])[1]}


if __name__ == "__main__":
    print(json.dumps(report(), indent=2))
