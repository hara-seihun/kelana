"""A finite register machine, its declared integer grammar and its abstract charges.

The machine is `registers` registers of `width` bits each. A machine state is the
whole register file, so the input stays in the state until an instruction
overwrites it. Every instruction is a total map on the machine state set.

A *semantic state* is the machine state of every declared input at once: the map
`domain -> machine state`. Programs are straight-line, so a program prefix is
fully described by its semantic state, and the set of semantic states is finite.
That is what makes the search finite without a depth bound.

`check.py` re-derives the instruction tables from the same names with its own
implementation. The duplication is deliberate; the checker must not inherit a bug
from the generator.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Mapping, Sequence

import numpy as np

REG_OPS: Mapping[str, Callable[[int, int, int], int]] = {
    "mov": lambda a, b, m: b,
    "and": lambda a, b, m: a & b,
    "or": lambda a, b, m: a | b,
    "xor": lambda a, b, m: a ^ b,
    "add": lambda a, b, m: (a + b) & m,
    "sub": lambda a, b, m: (a - b) & m,
    "mul": lambda a, b, m: (a * b) & m,
}

IMM_OPS: Mapping[str, Callable[[int, int, int], int]] = {
    "movi": lambda a, c, m: c & m,
    "andi": lambda a, c, m: a & c,
    "ori": lambda a, c, m: a | c,
    "xori": lambda a, c, m: a ^ c,
    "addi": lambda a, c, m: (a + c) & m,
    "muli": lambda a, c, m: (a * c) & m,
    "shli": lambda a, c, m: (a << c) & m,
    "shri": lambda a, c, m: a >> c,
}

UNARY_OPS: Mapping[str, Callable[[int, int], int]] = {
    "not": lambda a, m: (~a) & m,
}

CHARGES: Mapping[str, int] = {
    "mov": 1,
    "and": 1,
    "or": 1,
    "xor": 1,
    "add": 1,
    "sub": 1,
    "mul": 3,
    "movi": 1,
    "andi": 1,
    "ori": 1,
    "xori": 1,
    "addi": 1,
    "muli": 3,
    "shli": 1,
    "shri": 1,
    "not": 1,
}

ALL_OPS = tuple(sorted(set(REG_OPS) | set(IMM_OPS) | set(UNARY_OPS)))

GRAMMARS: Mapping[str, tuple[str, ...]] = {
    "full": ALL_OPS,
    "monotone": ("and", "andi", "mov", "movi", "or", "ori", "shli", "shri"),
    "affine": ("add", "addi", "mov", "movi", "muli", "shli", "sub"),
    "nomul": tuple(op for op in ALL_OPS if op not in ("mul", "muli")),
    "noshr": tuple(op for op in ALL_OPS if op != "shri"),
}

GRAMMAR_NOTES: Mapping[str, str] = {
    "full": "every declared op",
    "monotone": "no complement, xor, or carry arithmetic",
    "affine": "no bitwise op and no register-by-register multiply",
    "nomul": "no multiply, by register or by immediate",
    "noshr": "no right shift; nothing moves a bit toward a lower position",
}


@dataclass(frozen=True)
class Machine:
    width: int
    registers: int
    domain: tuple[int, ...]
    scratch: tuple[int, ...]

    def __post_init__(self) -> None:
        if self.registers < 1 or self.width < 1:
            raise ValueError("machine needs at least one register of at least one bit")
        if len(self.scratch) != self.registers - 1:
            raise ValueError("scratch must give an initial value for registers 1..k-1")
        limit = 1 << self.width
        if any(v < 0 or v >= limit for v in self.domain + self.scratch):
            raise ValueError("domain and scratch values must fit the register width")
        if len(set(self.domain)) != len(self.domain):
            raise ValueError("input domain must be a set of distinct values")

    @property
    def mask(self) -> int:
        return (1 << self.width) - 1

    @property
    def state_count(self) -> int:
        return 1 << (self.width * self.registers)

    @property
    def inputs(self) -> int:
        return len(self.domain)

    @property
    def semantic_count(self) -> int:
        return self.state_count**self.inputs

    def pack(self, regs: Sequence[int]) -> int:
        return sum((r & self.mask) << (j * self.width) for j, r in enumerate(regs))

    def unpack(self, state: int) -> tuple[int, ...]:
        return tuple((state >> (j * self.width)) & self.mask for j in range(self.registers))

    def initial_states(self) -> tuple[int, ...]:
        return tuple(self.pack((x,) + self.scratch) for x in self.domain)

    def initial_semantic(self) -> int:
        acc = 0
        for i, ms in enumerate(self.initial_states()):
            acc += ms * self.state_count**i
        return acc

    def as_json(self) -> dict:
        return {
            "width": self.width,
            "registers": self.registers,
            "domain": list(self.domain),
            "scratch": list(self.scratch),
        }


@dataclass(frozen=True)
class Instruction:
    name: str
    charge: int
    table: tuple[int, ...]


def instruction_table(name: str, width: int, registers: int) -> tuple[int, ...]:
    tokens = name.split()
    op = tokens[0]
    mask = (1 << width) - 1
    dst = int(tokens[1][1:])
    if not 0 <= dst < registers:
        raise ValueError(f"{name}: destination register out of range")

    if op in UNARY_OPS:
        if len(tokens) != 2:
            raise ValueError(f"{name}: unary op takes one register")
        apply = lambda regs: UNARY_OPS[op](regs[dst], mask)
    elif op in REG_OPS:
        if len(tokens) != 3 or not tokens[2].startswith("r"):
            raise ValueError(f"{name}: register op takes two registers")
        src = int(tokens[2][1:])
        if not 0 <= src < registers or src == dst:
            raise ValueError(f"{name}: source register out of range or equal to destination")
        apply = lambda regs: REG_OPS[op](regs[dst], regs[src], mask)
    elif op in IMM_OPS:
        if len(tokens) != 3:
            raise ValueError(f"{name}: immediate op takes a register and a constant")
        imm = int(tokens[2])
        apply = lambda regs: IMM_OPS[op](regs[dst], imm, mask)
    else:
        raise ValueError(f"{name}: unknown op")

    table = []
    for state in range(1 << (width * registers)):
        regs = [(state >> (j * width)) & mask for j in range(registers)]
        regs[dst] = apply(regs) & mask
        table.append(sum(r << (j * width) for j, r in enumerate(regs)))
    return tuple(table)


def instruction_names(machine: Machine, ops: Sequence[str]) -> list[str]:
    names: list[str] = []
    regs = range(machine.registers)
    for op in sorted(ops):
        if op in UNARY_OPS:
            names += [f"{op} r{d}" for d in regs]
        elif op in REG_OPS:
            names += [f"{op} r{d} r{s}" for d in regs for s in regs if s != d]
        elif op in ("shli", "shri"):
            names += [f"{op} r{d} {c}" for d in regs for c in range(1, machine.width)]
        else:
            names += [f"{op} r{d} {c}" for d in regs for c in range(1 << machine.width)]
    return names


def build_grammar(machine: Machine, ops: Sequence[str]) -> list[Instruction]:
    out = []
    for name in instruction_names(machine, ops):
        charge = CHARGES[name.split()[0]]
        if charge <= 0:
            raise ValueError(f"{name}: charges must be positive")
        out.append(Instruction(name, charge, instruction_table(name, machine.width, machine.registers)))
    return out


def semantic_digits(machine: Machine) -> list[np.ndarray]:
    size = machine.semantic_count
    base = machine.state_count
    idx = np.arange(size, dtype=np.int64)
    return [(idx // base**i) % base for i in range(machine.inputs)]


def index_dtype(size: int):
    """The transition tables dominate memory, so index them in the narrowest type that fits."""
    for dtype in (np.uint8, np.uint16, np.uint32):
        if size - 1 <= np.iinfo(dtype).max:
            return dtype
    return np.uint64


def semantic_tables(machine: Machine, instructions: Sequence[Instruction]) -> np.ndarray:
    digits = semantic_digits(machine)
    base = machine.state_count
    out = np.empty((len(instructions), machine.semantic_count), dtype=index_dtype(machine.semantic_count))
    for k, ins in enumerate(instructions):
        table = np.asarray(ins.table, dtype=np.int64)
        acc = np.zeros(machine.semantic_count, dtype=np.int64)
        for i, digit in enumerate(digits):
            acc += table[digit] * base**i
        out[k] = acc
    return out


def register_views(machine: Machine, reg: int) -> list[np.ndarray]:
    """Value held in `reg` for each declared input, over every semantic state."""
    return [(digit >> (reg * machine.width)) & machine.mask for digit in semantic_digits(machine)]


def exact_goal(machine: Machine, reg: int, target: Sequence[int]) -> np.ndarray:
    views = register_views(machine, reg)
    ok = np.ones(machine.semantic_count, dtype=bool)
    for view, want in zip(views, target):
        ok &= view == want
    return ok


def cleared_goal(machine: Machine, reg: int, target: Sequence[int]) -> np.ndarray:
    ok = exact_goal(machine, reg, target)
    for other in range(machine.registers):
        if other == reg:
            continue
        for view in register_views(machine, other):
            ok &= view == 0
    return ok


def relabeled_goal(machine: Machine, reg: int, target: Sequence[int]) -> np.ndarray:
    views = register_views(machine, reg)
    ok = np.ones(machine.semantic_count, dtype=bool)
    for i in range(machine.inputs):
        for j in range(i + 1, machine.inputs):
            same = views[i] == views[j]
            ok &= same == (target[i] == target[j])
    return ok


def refines_goal(machine: Machine, reg: int, target: Sequence[int]) -> np.ndarray:
    views = register_views(machine, reg)
    ok = np.ones(machine.semantic_count, dtype=bool)
    for i in range(machine.inputs):
        for j in range(i + 1, machine.inputs):
            if target[i] != target[j]:
                ok &= views[i] != views[j]
    return ok


GOAL_KINDS: Mapping[str, Callable[[Machine, int, Sequence[int]], np.ndarray]] = {
    "exact": exact_goal,
    "cleared": cleared_goal,
    "relabeled": relabeled_goal,
    "refines": refines_goal,
}


def goal_mask(machine: Machine, spec: Mapping) -> np.ndarray:
    if spec["kind"] == "pair-exact":
        if machine.registers != 2:
            raise ValueError("pair-exact requires exactly two registers")
        targets = spec["targets"]
        if len(targets) != 2 or any(len(t) != machine.inputs for t in targets):
            raise ValueError("pair-exact needs one target per register and input")
        return exact_goal(machine, 0, targets[0]) & exact_goal(machine, 1, targets[1])
    return GOAL_KINDS[spec["kind"]](machine, spec["observe"], spec["target"])


def waypoint_mask(machine: Machine, spec: Mapping) -> np.ndarray:
    target = spec["target"]
    regs = range(machine.registers) if spec["registers"] == "any" else [spec["registers"]]
    ok = np.zeros(machine.semantic_count, dtype=bool)
    for reg in regs:
        here = np.ones(machine.semantic_count, dtype=bool)
        for view, want in zip(register_views(machine, reg), target):
            here &= view == want
        ok |= here
    return ok
