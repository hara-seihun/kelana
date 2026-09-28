"""Minimum scalar add/sub DAG for a complete sign-folded ternary response table.

Inputs are x[0:k], zero is free, and each instruction produces one signed
integer from two available signed integers. No free negation is assumed.
"""

from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from random import Random


@dataclass(frozen=True)
class Step:
    dst: tuple[int, ...]
    left: tuple[int, ...]
    right: tuple[int, ...]
    op: str


def code(coeff: tuple[int, ...]) -> int:
    return sum((value + 1) * 3**i for i, value in enumerate(coeff))


def program(k: int) -> tuple[list[Step], dict[int, tuple[int, ...]]]:
    if k < 1:
        raise ValueError("k must be positive")
    zero = (0,) * k
    forms = {code(zero): zero}
    steps: list[Step] = []
    for j in range(k):
        unit = tuple(int(i == j) for i in range(k))
        negative = tuple(-v for v in unit)
        steps.append(Step(negative, zero, unit, "sub"))
        previous = list(forms.values())
        for p in previous:
            if p == zero:
                continue
            plus = tuple(a + b for a, b in zip(negative, p))
            minus = tuple(a - b for a, b in zip(negative, p))
            steps.append(Step(plus, negative, p, "add"))
            steps.append(Step(minus, negative, p, "sub"))
        for step in steps:
            forms[code(step.dst)] = step.dst
    return steps, forms


def evaluate(k: int, x: tuple[int, ...]) -> list[int]:
    if len(x) != k:
        raise ValueError("wrong query width")
    steps, forms = program(k)
    zero = (0,) * k
    values = {zero: 0}
    values.update({tuple(int(i == j) for i in range(k)): value for j, value in enumerate(x)})
    for step in steps:
        assert step.dst not in values
        a, b = values[step.left], values[step.right]
        values[step.dst] = a + b if step.op == "add" else a - b
    return [values[forms[c]] for c in sorted(forms)]


def check() -> None:
    for k in range(1, 8):
        steps, forms = program(k)
        center = (3**k - 1) // 2
        assert sorted(forms) == list(range(center + 1))
        assert len(steps) == center
        available = {(0,) * k} | {tuple(int(i == j) for i in range(k)) for j in range(k)}
        for step in steps:
            assert step.left in available and step.right in available
            actual = tuple(a + b if step.op == "add" else a - b
                           for a, b in zip(step.left, step.right))
            assert actual == step.dst and step.dst not in available
            available.add(actual)
        assert set(forms.values()) <= available
        queries = product(range(-2, 3), repeat=k) if k <= 3 else (
            tuple(Random(719 + k * 100 + n).randint(-128, 127) for _ in range(k))
            for n in range(12)
        )
        for x in queries:
            table = evaluate(k, tuple(x))
            for c in range(3**k):
                representative = min(c, 3**k - 1 - c)
                sign = 1 if c == representative else -1
                digits = tuple((c // 3**i) % 3 - 1 for i in range(k))
                assert sign * table[representative] == sum(a * b for a, b in zip(digits, x))
        print(f"k={k} representatives={center} adds/subs={len(steps)} full_table={3**k-1-k}")
    assert 42 * len(program(3)[0]) + len(program(2)[0]) == 550


if __name__ == "__main__":
    check()
