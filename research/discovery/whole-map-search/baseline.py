"""Same-contract baselines, and what one address buys across many consumers.

Reference descriptions evaluate the same integer map. Counts below name their
input convention and operand-availability assumptions; they are not measured
or source-matched executable performance baselines:

  direct     the network as written: gate dot, up dot, ReLU, product, accumulate
  contracted the 19-monomial canonical form on the ternary cube
  memlut     address arithmetic plus a dword load from a per-weight-set table

The monomial identity is checked exactly. Its coefficients need not fit int4
or even be integral, so a three-nibble-dot lowering is not asserted.

The multi-consumer measurement answers a different question: once the input
word has been turned into a lane address, every further function of the same
three trits costs one more lookup and one more table VGPR, with no second
address computation and no decode between consumers.
"""

from __future__ import annotations

import itertools
import json
import random
from fractions import Fraction
from typing import Dict, List

from construction import COEFF_WORD, BIAS, lane_table
from emulate import check_program, u32
from model import (Network, STATES, balanced_index, coefficients,
                   evaluate_monomial, monomial_basis, packed_bytes)
from panel import RESULTS, load_panel


def canonical_form(net: Network) -> dict:
    """Exact coefficients in Q[x]/(x^3-x), and a re-check on all 27 states."""
    table = net.table()
    co = coefficients(table)
    bad = []
    for i, x in enumerate(STATES):
        v = sum(c * evaluate_monomial(e, x) for e, c in co.items())
        if v != table[i]:
            bad.append({"state": x, "want": table[i], "got": str(v)})
    odd = {e: c for e, c in co.items() if sum(e) % 2 == 1}
    even = {e: c for e, c in co.items() if sum(e) % 2 == 0}
    return {
        "monomials": len(co),
        "odd_monomials": len(odd),
        "even_monomials": len(even),
        "even_degrees": sorted({sum(e) for e in even}),
        "integer_coefficients": all(c.denominator == 1 for c in co.values()),
        "coefficients_fit_i4": all(c.denominator == 1 and -8 <= c <= 7 for c in co.values()),
        "coefficient_range": [str(min(co.values(), default=Fraction(0))),
                              str(max(co.values(), default=Fraction(0)))],
        "reproduces_map": not bad,
        "mismatches": bad,
    }


# Instruction counts for each baseline, stated step by step. Every count is for
# the same contract: one input word in, the exact int32 value out, weights fixed
# and prepared operands allowed to be built once per weight set.
def price_direct(width: int) -> dict:
    steps = {
        "input is already three signed byte lanes": 0,
        "gate dot per unit (v_dot4_i32_iu8)": width,
        "up dot per unit (v_dot4_i32_iu8)": width,
        "ReLU per unit (v_max_i32)": width,
        "gate*up per unit (v_mul_lo_u32)": width,
        "accumulate per unit (v_add_nc_u32)": width,
    }
    return {"steps": steps, "instructions": sum(steps.values()),
            "prepared_vgprs": 2 * width,
            "note": "logical arithmetic count for byte-packed input, with one prepared "
                    "operand for each gate and up and output signs folded into up. "
                    "Operand loads, waits and register-capacity effects are not counted; "
                    "this is not an emitted kernel or a speed baseline"}


def price_contracted() -> dict:
    return {"steps": {}, "instructions": None, "prepared_vgprs": None,
            "note": "The exact 19-monomial identity is retained, but its native lowering "
                    "is unpriced. Trit-valued features do not imply int4 coefficients. "
                    "The earlier 41-instruction estimate using three nibble dots was invalid "
                    "for coefficients outside [-8,7] or with nonunit denominators."}


def price_memlut() -> dict:
    steps = {
        "address (v_dot4_i32_iu8 with the balanced-ternary coefficient word)": 1,
        "global_load_dword": 1,
    }
    return {"steps": steps, "instructions": sum(steps.values()),
            "prepared_vgprs": 1,
            "note": "27 dwords per weight set resident in L1/L2 rather than in "
                    "registers; a VMEM load is not a VALU-rate operation and "
                    "this row is a different cost class, not a cheaper program"}


def multi_consumer(k: int, seed: int = 99) -> dict:
    """One address, k independent complete maps of the same three trits."""
    rng = random.Random(seed)
    nets = [Network.random(rng.choice((1, 8, 64, 256)), rng) for _ in range(k)]
    inputs = [[u32(packed_bytes(x)) for x in STATES]]
    address = {"dst": "r0", "op": "v_dot4_i32_i8",
               "args": ["xb", f"const0=0x{COEFF_WORD:08x}",
                        f"const1=0x{BIAS:08x}"]}
    bad = []
    for net in nets:
        prog = [address,
                {"dst": "out", "op": "ds_bpermute_b32", "args": ["r0"],
                 "offset0": 0}]
        chk = check_program(prog, ["xb"], inputs, [net(x) for x in STATES],
                            "int32", lane_table(net))
        if not chk["exact"]:
            bad.append(chk)
    # The joint map of all k outputs, as a partition of the 27 states.
    joint = {}
    for i, x in enumerate(STATES):
        joint.setdefault(tuple(net(x) for net in nets), []).append(i)
    return {
        "consumers": k,
        "address_instructions": 1,
        "lookup_instructions": k,
        "total_instructions": 1 + k,
        "prepared_vgprs": k,
        "prepared_bits": k * 27 * 32,
        "joint_image": len(joint),
        "shared_relabeling": "the 5-bit address is a sufficient statistic for "
                             "every function of the three trits at once, so no "
                             "consumer decodes before the next one reads",
        "exact": not bad,
        "mismatches": bad,
    }


if __name__ == "__main__":
    panel = load_panel()
    out: Dict[str, object] = {"canonical_form": {}, "baselines": {}}
    for label, d in panel.items():
        net = Network(d["gates"], d["ups"], d["signs"])
        out["canonical_form"][label] = canonical_form(net)
    out["baselines"] = {
        "direct-w64": price_direct(64),
        "direct-w256": price_direct(256),
        "contracted-19-monomial": price_contracted(),
        "memory-lut": price_memlut(),
        "this-search-A-balanced4": {"instructions": 1, "prepared_vgprs": 1,
                                    "steps": {"ds_bpermute_b32": 1}},
        "this-search-B-bytes": {"instructions": 2, "prepared_vgprs": 1,
                                "steps": {"v_dot4_i32_iu8": 1,
                                          "ds_bpermute_b32": 1}},
    }
    out["multi_consumer"] = [multi_consumer(k) for k in (1, 4, 16)]
    (RESULTS / "baselines.json").write_text(json.dumps(out, indent=1, default=str))
    for label, c in out["canonical_form"].items():
        print(f"{label:9s} monomials={c['monomials']:3d} odd={c['odd_monomials']:3d} "
              f"even_degrees={c['even_degrees']} exact={c['reproduces_map']}")
    print()
    for name, b in out["baselines"].items():
        print(f"{name:26s} {str(b['instructions']):>5s} instructions")
    print()
    for m in out["multi_consumer"]:
        print(f"{m['consumers']:3d} consumers -> {m['total_instructions']:3d} "
              f"instructions, joint image {m['joint_image']}, exact={m['exact']}")
