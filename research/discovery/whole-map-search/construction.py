"""The exact constructions this search produced, with their contracts and costs.

Each one is checked on all 27 inputs for the whole panel and for a large sample
of random networks of the family, by `emulate.py`. The shape never depends on
the network: only the wave-distributed table does. That is the claim worth
making, and it is the one checked here.

    python3 construction.py
"""

from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Dict, List

from emulate import check_program, u32
from model import Network, STATES, balanced_index, packed_bytes
from panel import RESULTS, load_panel, radix3

# The universal coefficient word for the balanced-ternary address: signed bytes
# (4, 12, 36, 0), i.e. 4 * (1, 3, 9). It does not depend on the network.
COEFF_WORD = 0x00240C04
BIAS = 52  # 4 * 13, an inline constant; also expressible as ds offset0


def lane_table(net: Network) -> List[int]:
    """Lane j holds the map's value at the input whose address selects lane j."""
    tbl = [0] * 32
    for x in STATES:
        tbl[balanced_index(x)] = net(x) & 0xFFFFFFFF
    return tbl


def radix3_lane_table(net: Network) -> List[int]:
    tbl = [0] * 32
    for x in STATES:
        tbl[radix3(x)] = net(x) & 0xFFFFFFFF
    return tbl


CONSTRUCTIONS: Dict[str, dict] = {
    "A-balanced4": {
        "contract_in": "one VGPR holding 4*(13 + x0 + 3*x1 + 9*x2)",
        "contract_out": "exact int32 value of the network",
        "instructions": 1,
        "pipe": ["lds"],
        "program": [
            {"dst": "out", "op": "ds_bpermute_b32", "args": ["b4"], "offset0": 0},
        ],
        "input": "balanced4",
        "table": "balanced",
    },
    "B-bytes": {
        "contract_in": "one VGPR holding one signed byte per trit in lanes 0,1,2",
        "contract_out": "exact int32 value of the network",
        "instructions": 2,
        "pipe": ["valu", "lds"],
        "program": [
            {"dst": "r0", "op": "v_dot4_i32_i8",
             "args": ["xb", f"const0=0x{COEFF_WORD:08x}", f"const1=0x{BIAS:08x}"]},
            {"dst": "out", "op": "ds_bpermute_b32", "args": ["r0"], "offset0": 0},
        ],
        "input": "bytes",
        "table": "balanced",
    },
    "C-radix3": {
        "contract_in": "one VGPR holding the dense radix-3 word q in 0..26",
        "contract_out": "exact int32 value of the network",
        "instructions": 2,
        "pipe": ["valu", "lds"],
        "program": [
            {"dst": "r0", "op": "v_lshlrev_b32", "args": ["const0=0x00000002", "q"]},
            {"dst": "out", "op": "ds_bpermute_b32", "args": ["r0"], "offset0": 0},
        ],
        "input": "radix3",
        "table": "radix3",
    },
}

INPUT_FN = {
    "balanced4": lambda x: 4 * balanced_index(x),
    "bytes": packed_bytes,
    "radix3": radix3,
}
INPUT_NAME = {"balanced4": "b4", "bytes": "xb", "radix3": "q"}
TABLE_FN = {"balanced": lane_table, "radix3": radix3_lane_table}


def check_all(samples: int = 200, seed: int = 4242) -> dict:
    rng = random.Random(seed)
    nets: List[Network] = []
    panel = load_panel()
    for d in panel.values():
        nets.append(Network(d["gates"], d["ups"], d["signs"]))
    for _ in range(samples):
        nets.append(Network.random(rng.choice((1, 2, 3, 8, 64, 256)), rng))

    out = {}
    for name, c in CONSTRUCTIONS.items():
        fn = INPUT_FN[c["input"]]
        inputs = [[u32(fn(x)) for x in STATES]]
        bad = []
        for net in nets:
            targets = [net(x) for x in STATES]
            chk = check_program(c["program"], [INPUT_NAME[c["input"]]], inputs,
                                targets, "int32", TABLE_FN[c["table"]](net))
            if not chk["exact"]:
                bad.append({"width": net.width, "mismatches": chk["mismatches"]})
        out[name] = {
            **{k: v for k, v in c.items() if k != "program"},
            "program": c["program"],
            "networks_checked": len(nets),
            "states_per_network": 27,
            "cases": len(nets) * 27,
            "mismatches": bad,
            "exact": not bad,
        }
    return out


if __name__ == "__main__":
    res = check_all()
    for name, r in res.items():
        print(f"{name:14s} {r['instructions']} instr  "
              f"{r['cases']:6d} cases  exact={r['exact']}")
    (RESULTS / "constructions.json").write_text(json.dumps(res, indent=1))
    print(f"\nwrote {RESULTS / 'constructions.json'}")
