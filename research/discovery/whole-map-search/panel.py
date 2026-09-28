"""The fixed panel of networks and input/output contracts used by every search.

The panel is chosen once, by seed, and recorded with all weights so that any
result below is reproducible and so that a negative names exactly which map it
is negative about. Networks are selected to span the image size |F({-1,0,1}^3)|,
which turns out to be the quantity that decides cost.
"""

from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Dict, List

from model import Network, STATES, packed2, packed_bytes, balanced_index
from synth import Contract, Spec

HERE = Path(__file__).parent
RESULTS = HERE / "results"

# --- contracts -------------------------------------------------------------

PACKED2_INPUTS = [[packed2(x) for x in STATES]]
BYTES_INPUTS = [[packed_bytes(x) for x in STATES]]
SPLIT_INPUTS = [[x[i] & 0xFFFFFFFF for x in STATES] for i in range(3)]


def radix3(x) -> int:
    """Dense unsigned radix-3 word, 0..26."""
    return (x[0] + 1) + 3 * (x[1] + 1) + 9 * (x[2] + 1)


RADIX3_INPUTS = [[radix3(x) for x in STATES]]
RADIX3X4_INPUTS = [[4 * radix3(x) for x in STATES]]
BALANCED4_INPUTS = [[4 * balanced_index(x) for x in STATES]]

CONTRACTS: Dict[str, Contract] = {
    "packed2": Contract(
        "packed2",
        PACKED2_INPUTS,
        ["raw"],
        "one VGPR: signed two-bit trit codes at bits 0,2,4 (-1->3, 0->0, +1->1). "
        "The layout used by the existing two-trit observer result.",
    ),
    "bytes": Contract(
        "bytes",
        BYTES_INPUTS,
        ["xb"],
        "one VGPR: one signed byte per trit in lanes 0,1,2, lane 3 zero.",
    ),
    "split": Contract(
        "split",
        SPLIT_INPUTS,
        ["x0", "x1", "x2"],
        "three VGPRs, one signed 32-bit trit each: the unpacked form a "
        "quantizer produces before any packing work.",
    ),
    "radix3": Contract(
        "radix3",
        RADIX3_INPUTS,
        ["q"],
        "one VGPR: the dense radix-3 value q = (x0+1) + 3(x1+1) + 9(x2+1), "
        "0..26. The packed word is the input coordinate; no trit is recovered.",
    ),
    "radix3x4": Contract(
        "radix3x4",
        RADIX3X4_INPUTS,
        ["q4"],
        "one VGPR: 4q, the dense radix-3 value pre-scaled to a dword index. "
        "A producer that chooses its output codes pays the same packing work "
        "as any other packed layout.",
    ),
    "balanced4": Contract(
        "balanced4",
        BALANCED4_INPUTS,
        ["b4"],
        "one VGPR: 4*(13 + x0 + 3x1 + 9x2), the balanced-ternary value of the "
        "input scaled to a dword index.",
    ),
}


def contract(name: str, output: str = "int32") -> Contract:
    c = CONTRACTS[name]
    return Contract(c.name, c.inputs, c.input_names, c.description, output)


# --- networks --------------------------------------------------------------

PANEL_SEED = 20260915


def build_panel() -> Dict[str, dict]:
    """Networks spanning the image size, one per (width, image) bucket."""
    rng = random.Random(PANEL_SEED)
    want = {1: 5, 2: 8, 4: 11, 8: 14, 64: 20, 256: 27}
    chosen: Dict[str, dict] = {}
    for width, image in want.items():
        for _ in range(200000):
            net = Network.random(width, rng)
            t = net.table()
            if len(set(t)) == image:
                label = f"w{width}i{image}"
                d = net.to_json()
                d["label"] = label
                d["image"] = image
                d["max_abs"] = max(abs(v) for v in t)
                d["byte_safe"] = d["max_abs"] <= 127
                chosen[label] = d
                break
        else:
            raise RuntimeError(f"no width {width} network with image {image}")
    return chosen


def load_panel() -> Dict[str, dict]:
    path = RESULTS / "panel.json"
    if not path.exists():
        panel = build_panel()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(panel, indent=1))
    return json.loads(path.read_text())


def spec_for(label: str, contract_name: str, projection: str = "int32",
             mode: str = "exact") -> Spec:
    panel = load_panel()
    net = panel[label]
    return Spec(contract(contract_name, projection), net["table_lex"],
                f"{label}/{contract_name}/{projection}/{mode}",
                projection=projection, mode=mode)


if __name__ == "__main__":
    panel = load_panel()
    for label, d in panel.items():
        print(f"{label:10s} width={d['width']:4d} image={d['image']:3d} "
              f"max|F|={d['max_abs']:4d} byte_safe={d['byte_safe']}")
