"""Exact algebra of functions on {-1,0,1}^n, with x**3 = x.

Every function T^n -> Q, T = {-1,0,1}, is exactly one element of

    Q[x_1..x_n] / (x_1**3 - x_1, ..., x_n**3 - x_n),

whose monomial basis uses per-variable exponents 0, 1, 2. This module holds
those elements sparsely, does exact ring arithmetic, interpolates them from
rational truth tables, substitutes trit-valued maps into them, and produces an
input point where two of them differ.

The canonical form is the function, not the program that produced it. Two maps
built from different layer stacks are equal exactly when their canonical forms
are equal, so layer boundaries need not be preserved to compare them.

Monomial counts here are algebraic size, not an instruction count or a cost.
"""

from fractions import Fraction
from itertools import product
from types import MappingProxyType

TRITS = (-1, 0, 1)

#: Guard for exponential truth tables: 3**11 = 177147 points.
MAX_POINTS = 3 ** 11


def _coefficient(value):
    if isinstance(value, Fraction):
        return value
    if isinstance(value, bool):
        return Fraction(int(value))
    if isinstance(value, int):
        return Fraction(value)
    if isinstance(value, float):
        return Fraction(value)  # exact binary value of the float, never rounded
    raise TypeError(f"coefficient must be rational, got {type(value).__name__}")


def _reduce_exponent(exponent):
    """x**3 = x sends exponents above 2 back into {1, 2}."""
    return exponent if exponent <= 2 else (exponent - 1) % 2 + 1


def _normalize_monomial(monomial):
    """Canonicalize a user-supplied monomial: sorted, merged, exponents in {1,2}.

    Rejects what cannot be a monomial of this ring, so equality and
    multiplication never see two spellings of one basis element.
    """
    merged = {}
    for pair in monomial:
        try:
            variable, exponent = pair
        except (TypeError, ValueError):
            raise ValueError(f"monomial factor must be a (variable, exponent) pair: {pair!r}")
        if isinstance(exponent, bool) or not isinstance(exponent, int):
            raise ValueError(f"exponent of {variable!r} must be an integer, got {exponent!r}")
        if exponent < 0:
            raise ValueError(f"exponent of {variable!r} is negative: {exponent}")
        if exponent == 0:
            continue
        merged[variable] = merged.get(variable, 0) + exponent
    return tuple(sorted((v, _reduce_exponent(e)) for v, e in merged.items()))


def _check_variables(variables):
    """Distinct variable names, so a table axis cannot be claimed twice."""
    variables = list(variables)
    duplicates = {v for v in variables if variables.count(v) > 1}
    if duplicates:
        raise ValueError(f"duplicate variable names: {sorted(map(str, duplicates))}")
    return variables


def _mul_monomial(a, b):
    """Multiply monomials under x**3 = x, keeping exponents in {1, 2}."""
    merged = dict(a)
    for variable, exponent in b:
        total = merged.get(variable, 0) + exponent
        merged[variable] = total - 2 if total > 2 else total
    return tuple(sorted(merged.items()))


class Poly:
    """A canonical element of the ternary quotient ring.

    Terms map a monomial - a sorted tuple of (variable, exponent in {1,2}) -
    to a nonzero rational coefficient. Construction never stores a zero.
    """

    __slots__ = ("_terms",)

    def __init__(self, terms=None, _canonical=False):
        if _canonical:
            self._terms = terms
            return
        collected = {}
        if terms:
            for monomial, coefficient in terms.items():
                coefficient = _coefficient(coefficient)
                if not coefficient:
                    continue
                key = _normalize_monomial(monomial)
                total = collected.get(key, Fraction(0)) + coefficient
                if total:
                    collected[key] = total
                else:
                    collected.pop(key, None)
        self._terms = collected

    @property
    def terms(self):
        """Read-only coefficient map, so a stored hash cannot drift."""
        return MappingProxyType(self._terms)

    @classmethod
    def _trusted(cls, terms):
        """Build from a map this module already normalized."""
        return cls(terms, _canonical=True)

    # construction -----------------------------------------------------

    @staticmethod
    def constant(value):
        return Poly({(): _coefficient(value)})

    @staticmethod
    def variable(name):
        return Poly({((name, 1),): Fraction(1)})

    @staticmethod
    def zero():
        return Poly()

    @staticmethod
    def sum(polys):
        total = Poly()
        for poly in polys:
            total = total + poly
        return total

    @staticmethod
    def product(polys):
        total = Poly.constant(1)
        for poly in polys:
            total = total * poly
        return total

    def _coerce(self, other):
        if isinstance(other, Poly):
            return other
        return Poly.constant(other)

    # ring operations --------------------------------------------------

    def __add__(self, other):
        other = self._coerce(other)
        terms = dict(self._terms)
        for monomial, coefficient in other._terms.items():
            total = terms.get(monomial, Fraction(0)) + coefficient
            if total:
                terms[monomial] = total
            else:
                terms.pop(monomial, None)
        return Poly._trusted(terms)

    __radd__ = __add__

    def __neg__(self):
        return Poly._trusted({m: -c for m, c in self._terms.items()})

    def __sub__(self, other):
        return self + (-self._coerce(other))

    def __rsub__(self, other):
        return self._coerce(other) + (-self)

    def __mul__(self, other):
        other = self._coerce(other)
        terms = {}
        for left, left_coefficient in self._terms.items():
            for right, right_coefficient in other._terms.items():
                monomial = _mul_monomial(left, right)
                total = terms.get(monomial, Fraction(0)) + left_coefficient * right_coefficient
                if total:
                    terms[monomial] = total
                else:
                    terms.pop(monomial, None)
        return Poly._trusted(terms)

    __rmul__ = __mul__

    def power(self, exponent):
        if exponent < 0:
            raise ValueError("negative powers are not ring elements")
        result = Poly.constant(1)
        for _ in range(exponent):
            result = result * self
        return result

    # comparison -------------------------------------------------------

    def canonical_key(self):
        """Hashable identity of the function, independent of build order."""
        return tuple(sorted((m, (c.numerator, c.denominator)) for m, c in self._terms.items()))

    def __eq__(self, other):
        if not isinstance(other, Poly):
            other = self._coerce(other)
        return self._terms == other._terms

    def __hash__(self):
        return hash(self.canonical_key())

    def is_zero(self):
        return not self.terms

    # structure --------------------------------------------------------

    def support(self):
        """Variables the function actually depends on."""
        return {variable for monomial in self.terms for variable, _ in monomial}

    def support_size(self):
        return len(self.support())

    def interaction_degree(self):
        """Largest number of distinct variables multiplied in one monomial."""
        return max((len(monomial) for monomial in self.terms), default=0)

    def total_degree(self):
        return max((sum(e for _, e in monomial) for monomial in self.terms), default=0)

    def monomial_count(self):
        return len(self.terms)

    def profile(self):
        return {
            "monomials": self.monomial_count(),
            "support_size": self.support_size(),
            "interaction_degree": self.interaction_degree(),
            "total_degree": self.total_degree(),
        }

    def __repr__(self):
        if not self.terms:
            return "0"
        parts = []
        for monomial, coefficient in sorted(self.terms.items()):
            factors = "*".join(v if e == 1 else f"{v}^{e}" for v, e in monomial)
            parts.append(f"{coefficient}" if not factors else f"{coefficient}*{factors}")
        return " + ".join(parts)

    # evaluation and substitution --------------------------------------

    def evaluate(self, point):
        """Evaluate at a mapping from variable to rational.

        Values outside {-1,0,1} evaluate this representative, which is not the
        original map: reduction by x**3 = x only preserves values on T^n.
        """
        total = Fraction(0)
        for monomial, coefficient in self.terms.items():
            term = coefficient
            for variable, exponent in monomial:
                term *= _coefficient(point[variable]) ** exponent
            total += term
        return total

    def restrict(self, variable, value):
        """Fix one variable to a trit, exactly."""
        if value not in TRITS:
            raise ValueError(f"restriction value {value} is not a trit")
        terms = {}
        for monomial, coefficient in self._terms.items():
            scale = Fraction(1)
            rest = []
            for name, exponent in monomial:
                if name == variable:
                    scale *= Fraction(value) ** exponent
                else:
                    rest.append((name, exponent))
            if not scale:
                continue
            key = tuple(rest)
            total = terms.get(key, Fraction(0)) + coefficient * scale
            if total:
                terms[key] = total
            else:
                terms.pop(key, None)
        return Poly._trusted(terms)

    def is_trit_valued(self):
        """True when this map lands in {-1,0,1} on the whole domain.

        Uses p**3 = p, which holds as functions on T^n exactly for trit-valued
        p, so no enumeration of the domain is needed.
        """
        return (self * self * self - self).is_zero()

    def substitute_representative(self, mapping):
        """Algebraic substitution into this representative, no semantics claimed.

        This rewrites the chosen normal form. It is the composed finite map only
        when the substituted coordinates stay in T; see `compose`. The two differ:
        y**3 - y normalizes to 0 here, so substituting y = x + 1 gives 0, while the
        unreduced expression at x = 1 is 2**3 - 2 = 6.
        """
        result = Poly()
        for monomial, coefficient in self.terms.items():
            term = Poly.constant(coefficient)
            for variable, exponent in monomial:
                replacement = mapping.get(variable)
                replacement = (Poly.variable(variable) if replacement is None
                               else self._coerce(replacement))
                term = term * replacement.power(exponent)
            result = result + term
        return result

    def compose(self, mapping):
        """Semantic composition of finite maps: canonical form of self(mapping(x)).

        Sound exactly when every substituted coordinate map is trit-valued, which
        this checks by cubic closure p**3 = p. Otherwise the outer normal form
        describes no value the inner map produces, and the result would be an
        artefact of the representative rather than the composed map.
        """
        return self.substitute(mapping, require_trit_valued=True)

    def substitute(self, mapping, require_trit_valued=True):
        """Compose: returns the canonical form of x -> self(mapping(x)).

        `self` is canonical under the assumption that its own arguments are
        trits, so composition is exact only when each substituted map is
        trit-valued. Pass require_trit_valued=False to get plain algebraic
        substitution into this representative, with no composition claim.
        """
        mapping = {variable: self._coerce(replacement)
                   for variable, replacement in mapping.items()}
        if require_trit_valued:
            for variable, poly in mapping.items():
                if not poly.is_trit_valued():
                    raise ValueError(
                        f"substituted map for {variable!r} fails cubic closure "
                        "p**3 = p, so it leaves {-1,0,1}; the outer normal form "
                        "says nothing there. Interpolate the composed map, or use "
                        "substitute_representative for algebraic rewriting only"
                    )
        return self.substitute_representative(mapping)


# interpolation --------------------------------------------------------


def points(variables, max_points=MAX_POINTS):
    """All of T^n in a fixed order, guarded against exponential blowup."""
    variables = _check_variables(variables)
    size = 3 ** len(variables)
    if size > max_points:
        raise ValueError(
            f"{len(variables)} variables need {size} points, above the limit {max_points}"
        )
    for values in product(TRITS, repeat=len(variables)):
        yield dict(zip(variables, values))


def truth_table(function, variables, max_points=MAX_POINTS):
    """Flat table of exact values, indexed by base-3 digits of the input."""
    variables = _check_variables(variables)
    return [_coefficient(function(point)) for point in points(variables, max_points)]


def interpolate(function, variables, max_points=MAX_POINTS):
    """Recover the unique canonical polynomial of a map on T^n.

    One axis at a time, values at -1, 0, 1 become coefficients of 1, x, x**2:

        c0 = f(0),  c1 = (f(1) - f(-1)) / 2,  c2 = (f(1) + f(-1)) / 2 - f(0).

    The 3x3 evaluation matrix has determinant 2, so this inverse exists over Q
    and over any ring where 2 is a unit. See `modular_representable`.
    """
    variables = _check_variables(variables)
    n = len(variables)
    if isinstance(function, (list, tuple)):
        if 3 ** n > max_points:
            raise ValueError(
                f"{n} variables need {3 ** n} points, above the limit {max_points}")
        # Exact from the start: raw ints must not meet the division below.
        table = [_coefficient(value) for value in function]
    else:
        table = truth_table(function, variables, max_points)
    if len(table) != 3 ** n:
        raise ValueError(
            f"table has {len(table)} values, expected {3 ** n} for {n} variables")
    stride = 1
    for _ in range(n):
        block = stride * 3
        for start in range(0, len(table), block):
            for offset in range(start, start + stride):
                low = table[offset]
                mid = table[offset + stride]
                high = table[offset + 2 * stride]
                table[offset] = mid
                table[offset + stride] = (high - low) / 2
                table[offset + 2 * stride] = (high + low) / 2 - mid
        stride = block
    terms = {}
    for index, coefficient in enumerate(table):
        if not coefficient:
            continue
        rest, monomial = index, []
        for variable in reversed(variables):
            exponent = rest % 3
            rest //= 3
            if exponent:
                monomial.append((variable, exponent))
        terms[tuple(sorted(monomial))] = coefficient
    return Poly._trusted(terms)


def from_values(values, variables, max_points=MAX_POINTS):
    """Interpolate from a mapping point-tuple -> value, in `variables` order."""
    variables = _check_variables(variables)
    return interpolate(lambda point: values[tuple(point[v] for v in variables)],
                       variables, max_points)


# comparison -----------------------------------------------------------


def difference_witness(left, right, variables=None):
    """None when the two maps are equal, else a point where they differ.

    Descends one variable at a time, so the cost is linear in the support
    rather than 3**n. Variables outside the difference's support are set to 0
    because the difference does not read them.
    """
    difference = left - right
    if difference.is_zero():
        return None
    point = {}
    remaining = difference
    for variable in sorted(difference.support()):
        for value in TRITS:
            restricted = remaining.restrict(variable, value)
            if not restricted.is_zero():
                point[variable] = value
                remaining = restricted
                break
        else:  # pragma: no cover - impossible: the three restrictions span
            raise AssertionError("nonzero map with three zero restrictions")
    for variable in variables or ():
        point.setdefault(variable, 0)
    return point


def reachable_states(polys, variables, max_points=MAX_POINTS):
    """Every output tuple the map attains on T^n."""
    polys = list(polys)
    variables = _check_variables(variables)
    return {tuple(p.evaluate(point) for p in polys) for point in points(variables, max_points)}


def states_equal(left, right, variables, max_points=MAX_POINTS):
    """Pointwise equality of two output vectors, checked on every state."""
    left, right = list(left), list(right)
    for point in points(variables, max_points):
        if [p.evaluate(point) for p in left] != [q.evaluate(point) for q in right]:
            return False
    return True


# the modular obstruction ---------------------------------------------


def modular_representable(values, modulus):
    """Can a one-variable map T -> Z/modulus use the basis 1, x, x**2?

    Interpolation needs 2 to be a unit. For a modulus 2**k it is not, and
    exactly the maps with f(1) + f(-1) - 2*f(0) even are representable: half
    of them. This is why `ContractedFFN.compile` represents 4F rather than F.
    """
    low, mid, high = (v % modulus for v in values)
    target = (high + low - 2 * mid) % modulus
    return any((2 * c2 - target) % modulus == 0 for c2 in range(modulus))
