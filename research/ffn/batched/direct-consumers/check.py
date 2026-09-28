#!/usr/bin/env python3
"""Exact finite checks of consumers and a bounded two-projection composition."""
import hashlib
import itertools
import json
from pathlib import Path
import random

MASK = (1 << 32)-1
R = 1 << 16


def signed_field(word, start, width):
    v = (word >> start) & ((1 << width)-1)
    return v if v < (1 << (width-1)) else v-(1 << width)


def product(p):
    return signed_field((p*p) & MASK, 17, 15)


def relu_product(p):
    return product(p) if not p & 32768 else 0


def poly(p):
    p2 = (p*p) & MASK
    return (p2*(480+80*p-p2*p)) & MASK


def run():
    for g,u in itertools.product(range(-127,128), repeat=2):
        p = (g+R*u) & MASK
        assert product(p) == g*u
        assert relu_product(p) == max(g,0)*u
    for g,u in itertools.product(range(-3,4), range(-7,8)):
        p = (g+R*u) & MASK
        actual = signed_field((poly(p)+32768) & MASK, 16, 16)
        assert actual == u*(960*g+240*g*g-5*g**4)
    rng = random.Random(16256)
    digest = hashlib.sha256()
    for _ in range(128):
        # A complete small bilinear region. Input width7 bounds |Gx|,|Ux|≤7;
        # hidden128 bounds both downstream coefficient sums by6272.
        x = [rng.randrange(-1,2) for _ in range(7)]
        gw = [[rng.randrange(-1,2) for _ in x] for _ in range(128)]
        uw = [[rng.randrange(-1,2) for _ in x] for _ in range(128)]
        encoded_weights = [[a+R*b for a,b in zip(gr,ur)] for gr,ur in zip(gw,uw)]
        packed = [sum(w*a for w,a in zip(row,x)) & MASK for row in encoded_weights]
        # Only the reference path constructs gate/up and individual products.
        gates = [sum(w*a for w,a in zip(row,x)) for row in gw]
        ups = [sum(w*a for w,a in zip(row,x)) for row in uw]
        for _ in range(16):
            down = [rng.randrange(-1,2) for _ in range(128)]
            for relu in (False, True):
                total = sum(c*((p*p)&MASK) for c,p in zip(down,packed)
                            if not relu or not p & 32768) & MASK
                got = signed_field((total+65536)&MASK, 17, 15)
                expected = sum(c*(max(g,0) if relu else g)*u
                               for c,g,u in zip(down,gates,ups))
                assert got == expected
                digest.update(got.to_bytes(4,"little",signed=True))
    return {"product_cases": 255**2, "relu_cases": 255**2,
            "polynomial_cases": 7*15, "spanning_random_regions": 128,
            "spanning_output_cases": 128*16*2,
            "spanning_shape": {"input":7,"hidden":128,"output":16},
            "spanning_reference_sha256": digest.hexdigest(),
            "scope": "exact integer arithmetic; random spanning checks, not a native throughput measurement or the deployed SiLU FFN"}


if __name__ == "__main__":
    result = run()
    result["source_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    Path(__file__).with_name("checks.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,indent=2))
