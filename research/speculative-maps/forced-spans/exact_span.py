#!/usr/bin/env python3
"""Exact finite-field forced-token span with a reusable affine transition."""

from fractions import Fraction

P = 97
FORCED = (4, 7, 9, 4)
TRANSITION = {4: (3, 5), 7: (2, 11), 9: (4, 6), 0: (5, 3), 1: (6, 8)}


def step(h: int, token: int) -> int:
    a, b = TRANSITION[token]
    return (a * h + b) % P


def prepare(tokens: tuple[int, ...]) -> tuple[int, int]:
    a, b = 1, 0
    for token in tokens:
        next_a, next_b = TRANSITION[token]
        a, b = (next_a * a) % P, (next_a * b + next_b) % P
    return a, b


def terminal_law(h: int) -> tuple[Fraction, Fraction]:
    w0, w1 = h % 5 + 1, (3 * h) % 7 + 1
    return Fraction(w0, w0 + w1), Fraction(w1, w0 + w1)


def main() -> None:
    a, b = prepare(FORCED)
    omissions = 0
    for h0 in range(P):
        h = h0
        for token in FORCED:
            # Grammar support is exactly {token}, so masked sampling is point mass 1.
            h = step(h, token)
        contracted = (a * h0 + b) % P
        assert contracted == h
        assert terminal_law(contracted) == terminal_law(h)
        for next_token in (0, 1):
            assert step(contracted, next_token) == step(h, next_token)
        omissions += terminal_law(h0) != terminal_law(h)
    assert omissions > 0
    print(f"span={FORCED} summary=({a},{b}) checked={P} skipped_state_changes_law={omissions}/{P}")
    print(f"h0=0: correct_end={(a * 0 + b) % P} correct_next={terminal_law(b)} omitted_next={terminal_law(0)}")
    print("online forced-span state updates: 4 affine steps -> 1 affine step; 3 saved")


if __name__ == "__main__":
    main()
