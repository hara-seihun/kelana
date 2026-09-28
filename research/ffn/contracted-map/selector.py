#!/usr/bin/env python3
"""Find an instruction-resident observer for the sparse signed two-trit code."""
import json
from pathlib import Path

codes = sorted(x + 4*y for x in (0, 1, 3) for y in (0, 1, 3))
nonzero = [x for x in codes if x]
solutions = []
for word in range(1 << 16):
    if word & 15 != 12:
        continue
    selectors = [(word >> raw) & 15 for raw in nonzero]
    if sorted(selectors) == list(range(8)):
        solutions.append(word)
assert solutions and solutions[0] == 0x722c
word = solutions[0]
result = {
    "search": "all 16-bit BFE source words, width 4, signed two-bit input fields",
    "solutions": [hex(x) for x in solutions],
    "selected": hex(word),
    "mapping": {str(raw): (word >> raw) & 15 for raw in codes},
    "scope": "Selector synthesis only. Not an instruction-count optimum or a whole-FFN speed measurement."
}
Path(__file__).with_name("selector.json").write_text(json.dumps(result, indent=2)+"\n")
print(f"{len(solutions)} source words; selected {word:#x}")
