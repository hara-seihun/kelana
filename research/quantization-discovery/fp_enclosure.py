#!/usr/bin/env python3
"""Shared-generator producer enclosures; binary64 directed bookkeeping.

Source binary32 errors are explicit residuals. The native-exp contract is passed
in, never inferred from observed agreement. Inputs and all source ranges must be
finite and safely away from overflow. Unsupported ranges raise rather than
returning a finite certificate.
"""
from dataclasses import dataclass
from decimal import Decimal, localcontext
from functools import lru_cache
import numpy as np

U32 = 2.0**-24
ETA32 = 2.0**-149


def down(x):
    return np.nextafter(np.asarray(x, dtype=np.float64), -np.inf)


def up(x):
    return np.nextafter(np.asarray(x, dtype=np.float64), np.inf)


def sum_up(a, axis=-1):
    a = np.moveaxis(np.asarray(a, dtype=np.float64), axis, -1)
    result = np.zeros(a.shape[:-1])
    for i in range(a.shape[-1]):
        result = up(result+a[..., i])
    return result


@dataclass
class Interval:
    lo: np.ndarray
    hi: np.ndarray

    def __post_init__(self):
        self.lo, self.hi = np.broadcast_arrays(np.asarray(self.lo, dtype=np.float64), np.asarray(self.hi, dtype=np.float64))
        assert np.all(np.isfinite(self.lo)) and np.all(np.isfinite(self.hi))
        assert np.all(self.lo <= self.hi)

    @staticmethod
    def point(x):
        return Interval(x, x)

    def __add__(self, other):
        return Interval(down(self.lo+other.lo), up(self.hi+other.hi))

    def __neg__(self):
        return Interval(-self.hi, -self.lo)

    def __sub__(self, other):
        return self+-other

    def __mul__(self, other):
        corners = np.stack(np.broadcast_arrays(self.lo*other.lo, self.lo*other.hi,
                                               self.hi*other.lo, self.hi*other.hi))
        return Interval(down(corners.min(axis=0)), up(corners.max(axis=0)))

    def reciprocal(self):
        assert np.all(self.lo > 0)
        return Interval(down(1/self.hi), up(1/self.lo))

    def __truediv__(self, other):
        return self*other.reciprocal()

    def absmax(self):
        return np.maximum(np.abs(self.lo), np.abs(self.hi))

    def rn32(self):
        lo, hi = self.lo.astype(np.float32).astype(np.float64), self.hi.astype(np.float32).astype(np.float64)
        assert np.all(np.isfinite(lo)) and np.all(np.isfinite(hi))
        # Also encloses a source flushing subnormal results to signed zero.
        tiny = np.finfo(np.float32).tiny
        lo = np.where((lo > 0) & (lo < tiny), 0., lo)
        hi = np.where((hi < 0) & (hi > -tiny), 0., hi)
        return Interval(lo, hi)


@lru_cache(maxsize=65536)
def exp_point(value):
    assert abs(value) < 80, 'transcendental input outside this evaluator contract'
    with localcontext() as context:
        context.prec = 60
        # Decimal.exp is correctly rounded to ROUND_HALF_EVEN. Adjacent decimal
        # values enclose the exact real exponential; float conversion adds one
        # outward binary64 step.
        answer = Decimal.from_float(float(value)).exp()
        return float(down(float(context.next_minus(answer)))), float(up(float(context.next_plus(answer))))


def exp_interval(interval):
    lo = np.array([exp_point(float(x))[0] for x in interval.lo.flat]).reshape(interval.lo.shape)
    hi = np.array([exp_point(float(x))[1] for x in interval.hi.flat]).reshape(interval.hi.shape)
    return Interval(lo, hi)


def rounding64(value):
    return np.abs(np.spacing(np.asarray(value, dtype=np.float64)))


@dataclass
class Affine:
    center: np.ndarray
    generators: np.ndarray
    residual: np.ndarray
    radii: np.ndarray

    def total_radius(self):
        return up(sum_up(up(np.abs(self.generators)*self.radii))+self.residual)

    def interval(self):
        radius = self.total_radius()
        return Interval(down(self.center-radius), up(self.center+radius))

    def add(self, other, sign=1):
        center = self.center+sign*other.center
        generators = self.generators+sign*other.generators
        residual = up(up(self.residual+other.residual)+rounding64(center))
        residual = up(residual+sum_up(up(rounding64(generators)*self.radii)))
        return Affine(center, generators, residual, self.radii)

    def multiply(self, other):
        center = self.center*other.center
        left = self.center[..., None]*other.generators
        right = other.center[..., None]*self.generators
        generators = left+right
        coeff_error = up(up(rounding64(left)+rounding64(right))+rounding64(generators))
        residual = up(up(np.abs(self.center)*other.residual)+up(np.abs(other.center)*self.residual))
        residual = up(residual+up(self.total_radius()*other.total_radius()))
        residual = up(up(residual+rounding64(center))+sum_up(up(coeff_error*self.radii)))
        return Affine(center, generators, residual, self.radii)

    def scale(self, factor):
        factor = np.asarray(factor, dtype=np.float64)
        center = self.center*factor
        generators = self.generators*factor[..., None]
        residual = up(up(self.residual*np.abs(factor))+rounding64(center))
        residual = up(residual+sum_up(up(rounding64(generators)*self.radii)))
        return Affine(center, generators, residual, self.radii)

    def source_round(self):
        magnitude = up(np.abs(self.center)+self.total_radius())
        assert np.all(magnitude < 2.0**100)
        residual = up(self.residual+up(up(U32*magnitude)+ETA32))
        return Affine(self.center, self.generators, residual, self.radii)

    def at(self, latent):
        value = Interval.point(self.center)
        for j in range(len(self.radii)):
            value = value+Interval.point(self.generators[..., j])*Interval.point(latent[j])
        return Interval(down(value.lo-self.residual), up(value.hi+self.residual))

    def support(self, row):
        row = np.asarray(row, dtype=np.float64)
        center = Interval.point(0.)
        coefficients = Interval.point(np.zeros(len(self.radii)))
        for i in range(len(row)):
            center = center+Interval.point(self.center[i])*Interval.point(row[i])
            coefficients = coefficients+Interval.point(self.generators[i])*Interval.point(row[i])
        result = up(center.absmax()+sum_up(up(coefficients.absmax()*self.radii)))
        return float(up(result+sum_up(up(np.abs(row)*self.residual))))


def scale_domain(scales, relative_radius):
    assert 0 <= relative_radius < 0.1
    scales = np.asarray(scales, dtype=np.float64)
    if relative_radius == 0:
        lo, hi = scales.copy(), scales.copy()
    else:
        lo = down(scales*(1-relative_radius)).astype(np.float32)
        hi = up(scales*(1+relative_radius)).astype(np.float32)
        lo = np.nextafter(lo, np.float32(-np.inf)).astype(np.float64)
        hi = np.nextafter(hi, np.float32(np.inf)).astype(np.float64)
    assert np.all(lo > 2.0**-100) and np.all(hi < 2.0**100)
    # Every binary32 number in these intervals is a multiple of this lattice.
    exponent = np.frexp(float(lo.min()))[1]-1
    unit = 2.0**(exponent-24)
    low_integer, high_integer = lo/unit, hi/unit
    assert np.all(low_integer == np.rint(low_integer)) and np.all(high_integer == np.rint(high_integer))
    center = (lo+hi)/2
    radii = (high_integer-low_integer)/2
    assert np.all(radii == np.rint(radii)) and np.all(radii < 2**52)
    latent = (scales-center)/unit
    assert np.all(np.abs(latent) <= radii) and np.all(latent == np.rint(latent))
    return dict(lo=lo, hi=hi, center=center, radii=radii, unit=unit, captured_latent=latent)


def guard_membership(codes, scales, expected_codes, lo_bits, hi_bits):
    """Exact admission predicate; a hash is provenance, not this equality test."""
    if codes.dtype != np.int8 or scales.dtype != np.float32:
        return False
    if codes.shape != (5120,) or scales.shape != (40,):
        return False
    if not np.array_equal(codes, np.asarray(expected_codes).reshape(5120)):
        return False
    bits = scales.view(np.uint32)
    return bool(np.all(np.isfinite(scales)) and np.all(scales > 0) and
                np.all(bits >= np.asarray(lo_bits, dtype=np.uint32)) and
                np.all(bits <= np.asarray(hi_bits, dtype=np.uint32)))


def project(integer_dots, weight_scales, domain):
    rows, blocks = integer_dots.shape
    assert blocks == 40 and weight_scales.shape == integer_dots.shape
    assert np.issubdtype(integer_dots.dtype, np.integer) and np.all(np.abs(integer_dots.astype(np.int64)) <= 128*127)
    assert np.all(np.isfinite(weight_scales)) and np.array_equal(weight_scales, weight_scales.astype(np.float16).astype(np.float32))
    partials = []
    for wave in range(8):
        partial = Affine(np.zeros(rows), np.zeros((rows, blocks)), np.zeros(rows), domain['radii'])
        for j in range(wave*5, wave*5+5):
            lam = weight_scales[:, j].astype(np.float64)
            center = lam*domain['center'][j]
            generators = np.zeros((rows, blocks))
            generators[:, j] = lam*domain['unit']
            # Both products are exact in f64: FP16 times a dyadic scale
            # midpoint or a power of two. The source first rounds lam*scale.
            weighted = Affine(center, generators, np.zeros(rows), domain['radii']).source_round()
            term = weighted.scale(integer_dots[:, j].astype(np.float64))
            # Scale(int_acc) and add remain real affine operations; exactly one
            # source rounding models fmaf(int_acc, weighted, partial).
            partial = partial.add(term).source_round()
        partials.append(partial)
    result = partials[0]
    for partial in partials[1:]:
        result = result.add(partial).source_round()
    return result


def native_exp_relative_error(interval):
    """AMD gfx1151 __expf: RN32(x*log2e_f32), then 1-ULP V_EXP_F32.

    This evaluator restricts |x|<80 so exp2 outputs stay normal and finite.
    Native-exp input flushing is covered separately from ordinary RN error.
    """
    magnitude = interval.absmax()
    assert np.all(magnitude < 80)
    coefficient = float.fromhex('0x1.715476p+0')
    with localcontext() as context:
        context.prec = 60
        value = Decimal(2).ln()
        ln2 = Interval(float(down(float(context.next_minus(value)))),
                       float(up(float(context.next_plus(value)))))
    bias = (Interval.point(coefficient)*ln2-Interval.point(1.)).absmax()
    argument_error = up(up(magnitude*up(bias+up(U32*coefficient*ln2.hi)))+2.0**-125)
    # Two-binade relative allowance is conservative for the ISA's 1-ULP bound.
    inflated = exp_interval(Interval.point(argument_error))*Interval.point(1+2.0**-22)
    return (inflated-Interval.point(1.)).hi


def silu(affine, exp_relative_error=native_exp_relative_error):
    one = Interval.point(1.)
    c = Interval.point(affine.center)
    sigmoid = one/(one+exp_interval(-c))
    function = c*sigmoid
    derivative = sigmoid+c*sigmoid*(one-sigmoid)
    center = (function.lo+function.hi)/2
    slope = (derivative.lo+derivative.hi)/2
    center_error = up(np.maximum(center-function.lo, function.hi-center))
    slope_error = up(np.maximum(slope-derivative.lo, derivative.hi-slope))
    generators = slope[..., None]*affine.generators
    total = affine.total_radius()
    # Global |silu''| <= 2, so Taylor's second-order residual <= radius^2.
    residual = up(up(np.abs(slope)*affine.residual)+up(total*total))
    residual = up(up(residual+center_error)+up(slope_error*total))
    residual = up(residual+sum_up(up(rounding64(generators)*affine.radii)))
    domain = affine.interval()
    ideal_exp = exp_interval(-domain)
    relative = exp_relative_error(-domain)
    exp_error = up(up(ideal_exp.hi*relative)+ETA32)
    native_min = (Interval.point(ideal_exp.lo)*(one-Interval.point(relative))-Interval.point(ETA32)).lo
    denominator_min = ((one+Interval.point(native_min))*Interval.point(1-U32)).lo
    assert np.all(denominator_min > 0)
    denominator_error = up(exp_error+up(U32*up(1+up(ideal_exp.hi+exp_error))))
    value_error = (Interval.point(domain.absmax())*Interval.point(denominator_error)/
                   (Interval.point(denominator_min)*Interval.point(down(1+ideal_exp.lo)))).hi
    quotient_error = up(up(U32*up(domain.absmax()/denominator_min))+ETA32)
    residual = up(residual+up(value_error+quotient_error))
    return Affine(center, generators, residual, affine.radii)


def hadamard(affine):
    assert len(affine.center) == 1024
    current = affine
    stride = 1
    while stride < 1024:
        shape = (1024//(2*stride), 2, stride)
        centers = current.center.reshape(shape)
        generators = current.generators.reshape(shape+(len(current.radii),))
        residuals = current.residual.reshape(shape)
        left = Affine(centers[:, 0].copy(), generators[:, 0].copy(), residuals[:, 0].copy(), current.radii)
        right = Affine(centers[:, 1].copy(), generators[:, 1].copy(), residuals[:, 1].copy(), current.radii)
        plus, minus = left.add(right).source_round(), left.add(right, -1).source_round()
        current = Affine(np.stack((plus.center, minus.center), axis=1).reshape(1024),
                         np.stack((plus.generators, minus.generators), axis=1).reshape(1024, -1),
                         np.stack((plus.residual, minus.residual), axis=1).reshape(1024), current.radii)
        stride *= 2
    return current.scale(1/32).source_round()


def quantize(affine):
    interval = affine.interval()
    lo, hi = interval.lo.reshape(-1, 128), interval.hi.reshape(-1, 128)
    abslo = np.where((lo <= 0) & (hi >= 0), 0., np.minimum(np.abs(lo), np.abs(hi)))
    mlo, mhi = abslo.max(axis=1), np.maximum(np.abs(lo), np.abs(hi)).max(axis=1)
    assert np.all(mlo > 2.0**-100) and np.all(mhi < 2.0**100), 'dynamic scale range unsupported'
    maximum = Interval(mlo, mhi)
    inverse = (Interval.point(127.)/maximum).rn32()
    product = (Interval(lo, hi)*Interval(inverse.lo[:, None], inverse.hi[:, None])).rn32()
    codes_lo = np.maximum(-127, np.rint(product.lo)).astype(np.int32)
    codes_hi = np.minimum(127, np.rint(product.hi)).astype(np.int32)
    assert np.all(codes_lo <= codes_hi)
    scales = (maximum/Interval.point(127.)).rn32()
    # For the actual source q and stored scale, |q*scale-y| <= scale/2 +
    # m*((1+u)^3-1), plus underflow allowances. No fixed-max-index premise.
    quantization_error = up(up(up(scales.hi/2)+up(5*U32*mhi))+16*ETA32)
    dequantized = Affine(affine.center, affine.generators,
                        up(affine.residual+np.repeat(quantization_error, 128)), affine.radii)
    return dict(codes_lo=codes_lo, codes_hi=codes_hi, xsum_lo=codes_lo.sum(axis=1), xsum_hi=codes_hi.sum(axis=1),
                scale_lo=scales.lo, scale_hi=scales.hi,
                dequantized=dequantized, quantization_error=quantization_error)
