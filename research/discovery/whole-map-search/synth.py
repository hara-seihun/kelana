"""Component-based synthesis of exact whole-map programs, bounded and reported.

One SMT query covers every wiring and every ordering of a fixed multiset of
components, together with every value of its constants. A `sat` answer is a
program; an `unsat` answer is a negative for that whole multiset; a timeout is
neither and is recorded as its own outcome.

The specification is the complete map on all 27 inputs at once. There is no
sampling and no CEGIS: the domain is finite, so the 27 instances are the whole
correctness condition.

Prepared values are shared across instances. That is exactly what "prepared"
means here: a value the wave may compute once per weight set, never per input.
Every prepared value a solution uses is reported and priced.
"""

from __future__ import annotations

import itertools
import json
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

import z3

from isa import BY_NAME, LIBRARY, Component

W = 32
INLINE_MIN, INLINE_MAX = -16, 64


@dataclass
class Contract:
    """What arrives in registers and what the consumer reads."""

    name: str
    # per-state input register values, one tuple per input register
    inputs: List[List[int]]
    input_names: List[str]
    description: str
    output: str = "int32"  # "int32" or "byte"


@dataclass
class Spec:
    contract: Contract
    targets: List[int]  # exact integer outputs, one per state
    label: str
    # What the consumer reads off the final register.
    #   int32 : the whole word
    #   byte  : its low byte
    #   lane5 : bits [6:2] after adding a free 16-bit offset, which is exactly
    #           what ds_bpermute_b32 uses as its lane index
    projection: str = "int32"
    # What the program has to achieve on that projection.
    #   exact  : the projected value is the map's value
    #   match  : the projection's collision structure equals the map's, so the
    #            two differ by a bijective relabeling of the reachable image
    #   refine : the projection separates at least what the map separates, so a
    #            general decoder exists and is priced separately
    mode: str = "exact"


@dataclass
class Result:
    multiset: Tuple[str, ...]
    outcome: str  # sat | unsat | timeout
    seconds: float
    program: Optional[List[dict]] = None
    constants: Optional[List[int]] = None
    table: Optional[List[int]] = None
    observed: Optional[List[int]] = None
    relabel: Optional[List[List[int]]] = None
    relabel_is_bijective: Optional[bool] = None


def _slots(comps: Sequence[Component], n_bperm: int) -> int:
    return sum(c.arity for c in comps) + n_bperm


class Synthesizer:
    def __init__(
        self,
        spec: Spec,
        comps: Sequence[Component],
        n_consts: int = 2,
        n_bpermute: int = 0,
        timeout_ms: int = 20000,
        bpermute_final: bool = False,
    ) -> None:
        self.spec = spec
        self.comps = list(comps)
        self.n_bpermute = n_bpermute
        self.n_consts = n_consts
        self.timeout_ms = timeout_ms
        # When the lookup is the last instruction its 32 table words are free
        # variables, so the whole condition on the program before it is that the
        # address separates states the map sends to different values. Encoding
        # that directly, instead of 32 symbolic words behind a 32-way select,
        # is what makes these queries finish.
        self.bpermute_final = bpermute_final

    def run(self) -> Result:
        spec = self.spec
        comps = self.comps
        n_states = len(spec.targets)
        n_in = len(spec.contract.inputs)
        n_c = self.n_consts
        n_ops = len(comps) + (0 if spec.projection == "lane5" else self.n_bpermute)

        s = z3.Solver()
        s.set("timeout", self.timeout_ms)

        consts = [z3.BitVec(f"c{i}", W) for i in range(n_c)]
        addrs: List[z3.BitVecRef] = []
        # Wave-distributed table for ds_bpermute: 32 lanes of 32 bits.
        table = ([z3.BitVec(f"t{j}", W) for j in range(32)]
                 if self.n_bpermute and not self.bpermute_final else [])
        bperm_off = [z3.BitVec("boff0", W)]

        # Location numbering: inputs 0..n_in-1, constants next, then operation
        # outputs.  An operation's own line is a variable so that one query
        # covers every ordering of the multiset.
        first_op_loc = n_in + n_c
        n_loc = first_op_loc + n_ops
        line = [z3.Int(f"line{k}") for k in range(n_ops)]
        for k in range(n_ops):
            s.add(line[k] >= first_op_loc, line[k] < n_loc)
        if len(line) > 1:
            s.add(z3.Distinct(*line))

        arity = [c.arity for c in comps] + [1] * self.n_bpermute
        loc: List[List[z3.ArithRef]] = []
        for k in range(n_ops):
            row = [z3.Int(f"l{k}_{j}") for j in range(arity[k])]
            for v in row:
                s.add(v >= 0, v < n_loc)
                s.add(v != line[k])
            loc.append(row)

        # Acyclicity: an operand produced by another operation must be earlier.
        for k in range(n_ops):
            for j in range(arity[k]):
                for m in range(n_ops):
                    if m == k:
                        continue
                    s.add(z3.Implies(loc[k][j] == line[m], line[m] < line[k]))

        out_loc = z3.Int("out")
        if n_ops == 0:
            # A zero-instruction program: the consumer reads the input word
            # itself. This is the honest floor for any "cheap encoding" claim.
            s.add(out_loc >= 0, out_loc < n_loc)
        else:
            s.add(out_loc >= first_op_loc, out_loc < n_loc)

        # Every operation must be observed, directly or through another one.
        # (Vacuous when there is no operation: the lookup reads the input.)
        for k in range(n_ops):
            uses = [out_loc == line[k]]
            for m in range(n_ops):
                if m == k:
                    continue
                uses += [loc[m][j] == line[k] for j in range(arity[m])]
            s.add(z3.Or(*uses))

        # Commutative symmetry breaking.
        for k, c in enumerate(comps):
            if c.commutative:
                s.add(loc[k][0] <= loc[k][1])

        def gather(values_by_loc, sel):
            expr = values_by_loc[0]
            for idx in range(1, len(values_by_loc)):
                expr = z3.If(sel == idx, values_by_loc[idx], expr)
            return expr

        for st in range(n_states):
            vals: List[z3.BitVecRef] = []
            for r in range(n_in):
                vals.append(z3.BitVecVal(spec.contract.inputs[r][st] & 0xFFFFFFFF, W))
            vals += consts
            outs = [z3.BitVec(f"o{k}_{st}", W) for k in range(n_ops)]
            vals += outs
            for k in range(n_ops):
                args = [gather(vals, loc[k][j]) for j in range(arity[k])]
                if k < len(comps):
                    s.add(outs[k] == comps[k].sem(*args))
                else:
                    kk = k - len(comps)
                    idx = z3.Extract(6, 2, args[0] + bperm_off[kk])
                    sel = table[0]
                    for j in range(1, 32):
                        sel = z3.If(idx == z3.BitVecVal(j, 5), table[j], sel)
                    s.add(outs[k] == sel)
            result = gather(vals, out_loc)
            if spec.projection == "lane5":
                addrs.append(z3.Extract(6, 2, result + bperm_off[0]))
            elif spec.projection == "byte":
                addrs.append(z3.Extract(7, 0, result))
            else:
                addrs.append(result)

        if spec.mode == "exact":
            assert spec.projection in ("int32", "byte"), "exact needs a value"
            for st in range(n_states):
                want = spec.targets[st] & (0xFF if spec.projection == "byte"
                                           else 0xFFFFFFFF)
                s.add(addrs[st] == z3.BitVecVal(want, addrs[st].size()))
        else:
            # Collision structure. `refine` asks the program to separate at
            # least what the map separates; `match` also forbids separating
            # anything the map does not, which makes the program the map up to
            # a bijective relabeling of its reachable image.
            for a in range(n_states):
                for b in range(a + 1, n_states):
                    if spec.targets[a] != spec.targets[b]:
                        s.add(addrs[a] != addrs[b])
                    elif spec.mode == "match":
                        s.add(addrs[a] == addrs[b])

        names = tuple(c.name for c in comps)
        if spec.projection != "lane5":
            names = names + ("ds_bpermute_b32",) * self.n_bpermute
        t0 = time.time()
        check = s.check()
        dt = time.time() - t0
        if check == z3.unsat:
            return Result(names, "unsat", dt)
        if check == z3.unknown:
            return Result(names, "timeout", dt)

        m = s.model()

        def val(v) -> int:
            got = m.eval(v, model_completion=True)
            return got.as_long()

        const_vals = [val(c) for c in consts]
        loc_names = list(spec.contract.input_names) + [
            f"const{i}=0x{const_vals[i]:08x}" for i in range(n_c)
        ]
        order = sorted(range(n_ops), key=lambda k: val(line[k]))
        line_name: Dict[int, str] = {}
        for pos, k in enumerate(order):
            line_name[val(line[k])] = f"r{pos}"

        def loc_name(l: int) -> str:
            if l < first_op_loc:
                return loc_names[l]
            return line_name[l]

        prog = []
        for pos, k in enumerate(order):
            args = [loc_name(val(loc[k][j])) for j in range(arity[k])]
            entry = {"dst": f"r{pos}", "op": names[k], "args": args}
            if k >= len(comps):
                entry["offset0"] = val(bperm_off[k - len(comps)]) & 0xFFFF
            prog.append(entry)
        tbl = [val(t) for t in table] if table else None
        observed = [val(a) for a in addrs]
        relabel: Dict[int, int] = {}
        bijective = True
        for st in range(n_states):
            o = observed[st]
            if relabel.setdefault(o, spec.targets[st]) != spec.targets[st]:
                bijective = False
        if len(set(relabel.values())) != len(relabel):
            bijective = False
        if spec.projection == "lane5":
            off = val(bperm_off[0])
            src = loc_name(val(out_loc))
            prog.append({"dst": "out", "op": "ds_bpermute_b32",
                         "args": [src], "offset0": off & 0xFFFF})
            names = names + ("ds_bpermute_b32",)
            tbl = [0] * 32
            for st in range(n_states):
                tbl[observed[st]] = spec.targets[st] & 0xFFFFFFFF
            self.lane_index = observed
        return Result(names, "sat", dt, prog, const_vals, tbl, observed,
                      sorted([k, v] for k, v in relabel.items()), bijective)


def search(
    spec: Spec,
    size: int,
    library: Sequence[Component] = tuple(LIBRARY),
    n_consts: int = 2,
    bpermute: Sequence[int] = (0,),
    timeout_ms: int = 20000,
    stop_on_first: bool = True,
    verbose: bool = True,
) -> dict:
    """All component multisets of the given size, one SMT query each."""
    results: List[Result] = []
    found: List[Result] = []
    t0 = time.time()
    combos = []
    for nb in bpermute:
        if nb > size:
            continue
        for sub in itertools.combinations_with_replacement(library, size - nb):
            combos.append((sub, nb))
    for sub, nb in combos:
        syn = Synthesizer(spec, sub, n_consts=n_consts, n_bpermute=nb,
                          timeout_ms=timeout_ms)
        r = syn.run()
        results.append(r)
        if verbose and r.outcome != "unsat":
            print(f"  {r.outcome:8s} {r.multiset} {r.seconds:.2f}s")
        if r.outcome == "sat":
            found.append(r)
            if stop_on_first:
                break
    summary = {
        "spec": spec.label,
        "contract": spec.contract.name,
        "output": spec.contract.output,
        "size": size,
        "multisets_explored": len(results),
        "unsat": sum(1 for r in results if r.outcome == "unsat"),
        "sat": sum(1 for r in results if r.outcome == "sat"),
        "timeout": sum(1 for r in results if r.outcome == "timeout"),
        "timeout_multisets": [list(r.multiset) for r in results if r.outcome == "timeout"],
        "constants_allowed": n_consts,
        "bpermute_allowed": list(bpermute),
        "per_query_timeout_ms": timeout_ms,
        "wall_seconds": time.time() - t0,
        "solutions": [
            {
                "components": list(r.multiset),
                "program": r.program,
                "constants": [f"0x{c:08x}" for c in (r.constants or [])],
                "table": r.table,
            }
            for r in found
        ],
    }
    return summary
