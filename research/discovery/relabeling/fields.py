"""GF(2^w) arithmetic and GL(w,2) matrices, as state tables on ``w``-bit words.

Everything here produces plain transition tables for ``relabeling.Family``.
A state is a ``w``-bit integer; a bit matrix is stored as its tuple of column
images, so ``M[i]`` is the image of the ``i``-th basis vector.
"""

from __future__ import annotations

from itertools import product

#: Primitive polynomials over GF(2), leading term dropped.
#: w=2: x^2+x+1 ; w=3: x^3+x+1 ; w=4: x^4+x+1 ; w=5: x^5+x^2+1
PRIMITIVE = {2: 0b11, 3: 0b011, 4: 0b0011, 5: 0b00101}


def gf_mul(a: int, b: int, width: int) -> int:
    modulus = PRIMITIVE[width]
    result = 0
    for _ in range(width):
        if b & 1:
            result ^= a
        b >>= 1
        carry = a & (1 << (width - 1))
        a = (a << 1) & ((1 << width) - 1)
        if carry:
            a ^= modulus
    return result


def gf_powers(width: int) -> list[int]:
    """``alpha^i`` for ``i`` in ``0 .. 2^w-2``, with ``alpha = x``."""
    order = (1 << width) - 1
    out = [1]
    for _ in range(order - 1):
        out.append(gf_mul(out[-1], 2, width))
    if len(set(out)) != order:
        raise ValueError(f"x is not primitive modulo the chosen polynomial at width {width}")
    return out


def discrete_log(width: int) -> dict[int, int]:
    return {value: index for index, value in enumerate(gf_powers(width))}


# --------------------------------------------------------------------------
# bit matrices
# --------------------------------------------------------------------------


def apply(matrix: tuple[int, ...], vector: int) -> int:
    acc = 0
    for i, column in enumerate(matrix):
        if (vector >> i) & 1:
            acc ^= column
    return acc


def identity(width: int) -> tuple[int, ...]:
    return tuple(1 << i for i in range(width))


def multiply(a: tuple[int, ...], b: tuple[int, ...]) -> tuple[int, ...]:
    return tuple(apply(a, column) for column in b)


def transpose(matrix: tuple[int, ...]) -> tuple[int, ...]:
    width = len(matrix)
    return tuple(
        sum(((matrix[i] >> j) & 1) << i for i in range(width)) for j in range(width)
    )


def inverse(matrix: tuple[int, ...]) -> tuple[int, ...]:
    """By order: ``M^(k-1)`` where ``k`` is the multiplicative order of ``M``."""
    unit = identity(len(matrix))
    power = matrix
    previous = unit
    while power != unit:
        previous = power
        power = multiply(matrix, power)
    return previous


def is_invertible(columns: tuple[int, ...]) -> bool:
    width = len(columns)
    reached = {0}
    for mask in range(1, 1 << width):
        acc = 0
        for i in range(width):
            if (mask >> i) & 1:
                acc ^= columns[i]
        reached.add(acc)
    return len(reached) == 1 << width


def general_linear(width: int) -> list[tuple[int, ...]]:
    """Every element of ``GL(width, 2)`` as a tuple of column images."""
    return [
        columns
        for columns in product(range(1, 1 << width), repeat=width)
        if is_invertible(columns)
    ]


def generated_order(*matrices: tuple[int, ...]) -> int:
    unit = identity(len(matrices[0]))
    seen = {unit}
    frontier = [unit]
    while frontier:
        current = frontier.pop()
        for matrix in matrices:
            nxt = multiply(matrix, current)
            if nxt not in seen:
                seen.add(nxt)
                frontier.append(nxt)
    return len(seen)


# --------------------------------------------------------------------------
# transition tables
# --------------------------------------------------------------------------


def point_action(matrix: tuple[int, ...]) -> tuple[int, ...]:
    """Action on the ``2^w - 1`` non-zero vectors; state ``s`` is the vector ``s+1``."""
    width = len(matrix)
    return tuple(apply(matrix, s + 1) - 1 for s in range((1 << width) - 1))


def plane_action(matrix: tuple[int, ...]) -> tuple[int, ...]:
    """Action on the non-zero linear functionals: ``phi -> phi . M^-1``.

    As column vectors this is multiplication by the inverse transpose.  The
    dual space has the same size as the point set and the same abstract group
    acts on it, which is what makes the pair a fair comparison.
    """
    return point_action(transpose(inverse(matrix)))


def full_linear_action(matrix: tuple[int, ...]) -> tuple[int, ...]:
    """Action on all ``2^w`` vectors, including zero."""
    width = len(matrix)
    return tuple(apply(matrix, s) for s in range(1 << width))


def field_multiplication(width: int, exponent: int, *, include_zero: bool) -> tuple[int, ...]:
    """Multiplication by ``alpha^exponent`` in GF(2^w)."""
    powers = gf_powers(width)
    factor = powers[exponent % len(powers)]
    if include_zero:
        return tuple(gf_mul(state, factor, width) for state in range(1 << width))
    return tuple(gf_mul(state + 1, factor, width) - 1 for state in range((1 << width) - 1))


def polynomial_value(table: tuple[int, ...], coefficients: tuple[int, ...]) -> tuple[int, ...]:
    """Evaluate ``sum_i c_i M^i`` pointwise, over GF(2), given ``M`` as a table."""
    out = []
    for x in range(len(table)):
        acc = 0
        state = x
        for coefficient in coefficients:
            if coefficient:
                acc ^= state
            state = table[state]
        out.append(acc)
    return tuple(out)
