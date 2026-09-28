#!/usr/bin/env python3
"""Finite checks for the signed-ternary, radix-16 IU4 construction.

The script has no third-party dependencies. Its JSON output is a compact
certificate of every finite enumeration performed here.
"""

from __future__ import annotations

import itertools
import json
import random


def signed_nibble(code: int) -> int:
    assert 0 <= code < 16
    return code if code < 8 else code - 16


def activation_digits(x: int) -> tuple[int, int]:
    """Return unsigned-low and signed-high nibble codes from an int8."""
    assert -128 <= x <= 127
    raw = x & 0xFF
    return raw & 0xF, raw >> 4


def weight_code(trit: int) -> int:
    """Map Bonsai's 0,1,2 trit to an i4 code for -1,0,1."""
    assert 0 <= trit <= 2
    return (trit - 1) & 0xF


def signed_weight_word(trits: tuple[int, ...]) -> int:
    assert len(trits) == 8
    unsigned_word = sum(t << (4 * i) for i, t in enumerate(trits))
    # No addition carry crosses a nibble because t + 7 is at most 9.
    return ((unsigned_word + 0x77777777) ^ 0x88888888) & 0xFFFFFFFF


def pack5(trits: tuple[int, ...]) -> int:
    assert len(trits) == 5
    q = 0
    for t in trits:
        assert 0 <= t <= 2
        q = 3 * q + t
    return (q * 256 + 242) // 243


def peel5(byte: int) -> tuple[int, ...]:
    out = []
    for _ in range(5):
        byte *= 3
        out.append(byte >> 8)
        byte &= 0xFF
    return tuple(out)


def pack_three_bytes_10bit(a: int, b: int, c: int) -> int:
    assert 0 <= a < 256 and 0 <= b < 256 and 0 <= c < 256
    return a | (b << 10) | (c << 20)


def peel_three_10bit(a: int, b: int, c: int) -> tuple[tuple[int, ...], ...]:
    remainder = pack_three_bytes_10bit(a, b, c)
    mask_remainder = 0x0FF3FCFF
    mask_digit = 0x00300C03
    digits = [[], [], []]
    for _ in range(5):
        product = remainder * 3
        digit_fields = (product >> 8) & mask_digit
        digits[0].append(digit_fields & 3)
        digits[1].append((digit_fields >> 10) & 3)
        digits[2].append((digit_fields >> 20) & 3)
        remainder = product & mask_remainder
    return tuple(tuple(lane) for lane in digits)


def pair_first_four_nibbles(a: int, b: int) -> int:
    """Simulate packed-u16 peel, two shift-ORs, and the byte permutation."""
    remainder = a | (b << 16)
    peeled = []
    for _ in range(4):
        product = ((remainder & 0xFFFF) * 3) | (((remainder >> 16) * 3) << 16)
        peeled.append((product >> 8) & 0x00FF00FF)
        remainder = product & 0x00FF00FF
    q01 = (peeled[1] << 4) | peeled[0]
    q23 = (peeled[3] << 4) | peeled[2]
    selected_bytes = (
        q01 & 0xFF,
        (q01 >> 16) & 0xFF,
        q23 & 0xFF,
        (q23 >> 16) & 0xFF,
    )
    return sum(byte << (8 * i) for i, byte in enumerate(selected_bytes))


def pack_four_byte_trits_to_nibbles(trits: tuple[int, ...]) -> int:
    """Pack four byte-spaced trits with packed-u16 multiply 0x11 and shift."""
    assert len(trits) == 4 and all(0 <= t <= 2 for t in trits)
    byte_word = sum(t << (8 * i) for i, t in enumerate(trits))
    lo_product = (byte_word & 0xFFFF) * 0x11
    hi_product = ((byte_word >> 16) & 0xFFFF) * 0x11
    packed_product = (lo_product & 0xFFFF) | ((hi_product & 0xFFFF) << 16)
    shifted = ((packed_product & 0xFFFF) >> 4) | ((((packed_product >> 16) & 0xFFFF) >> 4) << 16)
    return (shifted & 0xFF) | (((shifted >> 16) & 0xFF) << 8)


def exact_product_from_iu4(weight_trit: int, x: int) -> int:
    lo_code, hi_code = activation_digits(x)
    w = signed_nibble(weight_code(weight_trit))
    return w * lo_code + 16 * w * signed_nibble(hi_code)


def enumerate_affine_digit_coefficients(limit: int = 32) -> list[tuple[int, int]]:
    """Find coefficient pairs whose two u4 digits span 256 consecutive ints."""
    digit = range(16)
    found = []
    for a in range(-limit, limit + 1):
        for b in range(-limit, limit + 1):
            if a == 0 or b == 0:
                continue
            values = {a * p + b * q for p in digit for q in digit}
            if len(values) == 256 and max(values) - min(values) == 255:
                found.append((a, b))
    return found


def check_matrix_trials(trials: int = 256) -> None:
    rng = random.Random(0x1151)
    for _ in range(trials):
        weights = [[rng.randrange(3) for _ in range(16)] for _ in range(16)]
        activations = [[rng.randrange(-128, 128) for _ in range(16)] for _ in range(16)]
        for row in range(16):
            for col in range(16):
                direct = sum((weights[row][k] - 1) * activations[k][col] for k in range(16))
                split = sum(exact_product_from_iu4(weights[row][k], activations[k][col]) for k in range(16))
                assert direct == split


def main() -> None:
    pack5_cases = 0
    for trits in itertools.product(range(3), repeat=5):
        assert peel5(pack5(trits)) == trits
        pack5_cases += 1

    fifth_digit_pack_cases = 0
    for trits in itertools.product(range(3), repeat=4):
        packed = pack_four_byte_trits_to_nibbles(trits)
        assert tuple((packed >> (4 * i)) & 0xF for i in range(4)) == trits
        fifth_digit_pack_cases += 1

    signed_word_cases = 0
    for trits in itertools.product(range(3), repeat=8):
        word = signed_weight_word(trits)
        got = tuple(signed_nibble((word >> (4 * i)) & 0xF) for i in range(8))
        assert got == tuple(t - 1 for t in trits)
        signed_word_cases += 1

    scalar_cases = 0
    for trit in range(3):
        for x in range(-128, 128):
            assert exact_product_from_iu4(trit, x) == (trit - 1) * x
            scalar_cases += 1

    # Check pair assembly over all independently canonical pack5 bytes.
    canonical = [pack5(t) for t in itertools.product(range(3), repeat=5)]
    assert len(set(canonical)) == 243
    pair_cases = 0
    for a in canonical:
        for b in canonical:
            word = pair_first_four_nibbles(a, b)
            ta, tb = peel5(a), peel5(b)
            expected = (ta[0], ta[1], tb[0], tb[1], ta[2], ta[3], tb[2], tb[3])
            assert tuple((word >> (4 * i)) & 0xF for i in range(8)) == expected
            pair_cases += 1

    triple_lane_cases = 0
    for byte in range(256):
        for lane in range(3):
            inputs = [0, 0, 0]
            inputs[lane] = byte
            assert peel_three_10bit(*inputs)[lane] == peel5(byte)
            triple_lane_cases += 1
    rng = random.Random(0x10B17)
    triple_random_cases = 100_000
    for _ in range(triple_random_cases):
        inputs = tuple(rng.randrange(256) for _ in range(3))
        assert peel_three_10bit(*inputs) == tuple(peel5(byte) for byte in inputs)

    coefficients = enumerate_affine_digit_coefficients()
    assert coefficients == [
        (-16, -1), (-16, 1), (-1, -16), (-1, 16),
        (1, -16), (1, 16), (16, -1), (16, 1),
    ]

    check_matrix_trials()

    result = {
        "activation_identity_cases": 256,
        "affine_digit_coefficient_search": {
            "coefficient_interval": [-32, 32],
            "digit_domain": [0, 15],
            "matches": coefficients,
            "predicate": "256 distinct values in one integer interval of width 255",
        },
        "canonical_pack5_pair_assembly_cases": pair_cases,
        "fifth_digit_pack_cases": fifth_digit_pack_cases,
        "matrix_trials": 256,
        "pack5_roundtrip_cases": pack5_cases,
        "signed_weight_word_cases": signed_word_cases,
        "ternary_times_int8_cases": scalar_cases,
        "three_10bit_lane_basis_cases": triple_lane_cases,
        "three_10bit_lane_random_cases": triple_random_cases,
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
