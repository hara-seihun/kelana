"""A modeled gfx1151 bitvector ISA subset, as Z3 semantics plus a cost model.

Every component below is an instruction that exists in the pinned RDNA 3.5 XML and
that the installed gfx1151 assembler accepts (`probe.sh` records the check). Twelve
of them transcribe `Kelana/Hardware/IntOps.lean`, which in turn transcribes the
manual's pseudocode; the rest quote the manual directly in their docstring here.

The model is lane-local and 32-bit. EXEC, VCC, flags, DPP and execution cost are
outside it, except that `ds_bpermute_b32` carries its lane-activity requirement as
an explicit contract note because the construction depends on it.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, List, Sequence

import z3

W = 32


def _bv(v: int) -> z3.BitVecNumRef:
    return z3.BitVecVal(v, W)


def _shift_count(s):
    return s & _bv(31)


def _byte(x, i: int):
    return z3.Extract(i * 8 + 7, i * 8, x)


def _sext8(b):
    return z3.SignExt(24, b)


def _zext8(b):
    return z3.ZeroExt(24, b)


# --- semantics -------------------------------------------------------------


def v_add_nc_u32(a, b):
    return a + b


def v_sub_nc_u32(a, b):
    return a - b


def v_mul_lo_u32(a, b):
    return a * b


def v_and_b32(a, b):
    return a & b


def v_or_b32(a, b):
    return a | b


def v_xor_b32(a, b):
    return a ^ b


def v_lshlrev_b32(s0, s1):
    return s1 << _shift_count(s0)


def v_lshrrev_b32(s0, s1):
    return z3.LShR(s1, _shift_count(s0))


def v_ashrrev_i32(s0, s1):
    return s1 >> _shift_count(s0)


def v_lshl_or_b32(s0, s1, s2):
    return (s0 << _shift_count(s1)) | s2


def v_lshl_add_u32(s0, s1, s2):
    """`D0.u32 = (S0.u32 << S1.u32[4 : 0].u32) + S2.u32`."""
    return (s0 << _shift_count(s1)) + s2


def v_add3_u32(s0, s1, s2):
    """`D0.u32 = S0.u32 + S1.u32 + S2.u32`."""
    return s0 + s1 + s2


def v_and_or_b32(s0, s1, s2):
    """`D0.u32 = ((S0.u32 & S1.u32) | S2.u32)`."""
    return (s0 & s1) | s2


def v_bfe_u32(s0, s1, s2):
    width = _shift_count(s2)
    mask = (_bv(1) << width) - _bv(1)
    return z3.If(width == _bv(0), _bv(0), z3.LShR(s0, _shift_count(s1)) & mask)


def _byte_permute(hi, lo, sel_byte):
    data = z3.Concat(hi, lo)  # 64 bits, S0 is the MSBs

    def in_byte(i: int):
        return z3.Extract(i * 8 + 7, i * 8, data)

    s = z3.ZeroExt(24, sel_byte)
    out = z3.BitVecVal(0xFF, 8)
    out = z3.If(s == _bv(12), z3.BitVecVal(0x00, 8), out)
    for k in range(4):
        sign = z3.If(
            z3.Extract(7, 7, in_byte(2 * k + 1)) == z3.BitVecVal(1, 1),
            z3.BitVecVal(0xFF, 8),
            z3.BitVecVal(0x00, 8),
        )
        out = z3.If(s == _bv(8 + k), sign, out)
    for k in range(8):
        out = z3.If(s == _bv(k), in_byte(k), out)
    return out


def v_perm_b32(s0, s1, s2):
    parts = [_byte_permute(s0, s1, _byte(s2, i)) for i in range(4)]
    return z3.Concat(parts[3], parts[2], parts[1], parts[0])


def v_alignbit_b32(s0, s1, s2):
    """`D0.u32 = 32'U(({ S0.u32, S1.u32 } >> S2.u32[4 : 0].u32) & 0xffffffffLL)`."""
    wide = z3.Concat(s0, s1)
    sh = z3.ZeroExt(W, _shift_count(s2))
    return z3.Extract(31, 0, z3.LShR(wide, sh))


def v_med3_i32(s0, s1, s2):
    def mx(a, b):
        return z3.If(a > b, a, b)

    def mn(a, b):
        return z3.If(a < b, a, b)

    return mx(mn(s0, s1), mn(mx(s0, s1), s2))


def v_sad_u8(s0, s1, s2):
    """`tmp = S2; tmp += ABSDIFF(S0[i], S1[i])` over four unsigned bytes."""
    acc = s2
    for i in range(4):
        a, b = _zext8(_byte(s0, i)), _zext8(_byte(s1, i))
        acc = acc + z3.If(z3.UGT(a, b), a - b, b - a)
    return acc


def v_dot4_i32_i8(s0, s1, s2):
    """`V_DOT4_I32_IU8` with NEG[0]=NEG[1]=1: both operands signed bytes."""
    acc = s2
    for i in range(4):
        acc = acc + _sext8(_byte(s0, i)) * _sext8(_byte(s1, i))
    return acc


def v_dot4_u32_u8(s0, s1, s2):
    acc = s2
    for i in range(4):
        acc = acc + _zext8(_byte(s0, i)) * _zext8(_byte(s1, i))
    return acc


def v_dot8_i32_i4(s0, s1, s2):
    """`V_DOT8_I32_IU4` with both operands signed nibbles."""
    acc = s2
    for i in range(8):
        a = z3.SignExt(28, z3.Extract(i * 4 + 3, i * 4, s0))
        b = z3.SignExt(28, z3.Extract(i * 4 + 3, i * 4, s1))
        acc = acc + a * b
    return acc


def v_mad_u32_u24(s0, s1, s2):
    """`D0.u32 = S0.u32[23 : 0] * S1.u32[23 : 0] + S2.u32`."""
    return (s0 & _bv(0xFFFFFF)) * (s1 & _bv(0xFFFFFF)) + s2


# --- component table -------------------------------------------------------


@dataclass
class Component:
    name: str
    arity: int
    sem: Callable
    cost: int = 1
    pipe: str = "valu"
    provenance: str = "Kelana/Hardware/IntOps.lean"
    commutative: bool = False
    # Operand positions that must not be a plain constant for the instruction to
    # be encodable as written (documented per component where it matters).
    notes: str = ""


LIBRARY: List[Component] = [
    Component("v_add_nc_u32", 2, v_add_nc_u32, commutative=True),
    Component("v_sub_nc_u32", 2, v_sub_nc_u32),
    Component("v_mul_lo_u32", 2, v_mul_lo_u32, cost=1, commutative=True,
              notes="quarter rate on RDNA3.5"),
    Component("v_and_b32", 2, v_and_b32, commutative=True),
    Component("v_or_b32", 2, v_or_b32, commutative=True),
    Component("v_xor_b32", 2, v_xor_b32, commutative=True),
    Component("v_lshlrev_b32", 2, v_lshlrev_b32),
    Component("v_lshrrev_b32", 2, v_lshrrev_b32),
    Component("v_ashrrev_i32", 2, v_ashrrev_i32),
    Component("v_bfe_u32", 3, v_bfe_u32),
    Component("v_perm_b32", 3, v_perm_b32),
    Component("v_lshl_or_b32", 3, v_lshl_or_b32),
    Component("v_dot4_i32_i8", 3, v_dot4_i32_i8,
              provenance="Kelana/Hardware/IntOps.lean (NEG[0]=NEG[1]=1)"),
    Component("v_dot8_i32_i4", 3, v_dot8_i32_i4,
              provenance="Kelana/Hardware/IntOps.lean (NEG[0]=NEG[1]=1)"),
    Component("v_dot4_u32_u8", 3, v_dot4_u32_u8, provenance="manual 16.12"),
    Component("v_lshl_add_u32", 3, v_lshl_add_u32, provenance="manual 16.12 op 582"),
    Component("v_add3_u32", 3, v_add3_u32, provenance="manual 16.12 op 597"),
    Component("v_and_or_b32", 3, v_and_or_b32, provenance="manual 16.12"),
    Component("v_alignbit_b32", 3, v_alignbit_b32, provenance="manual 16.12 op 534"),
    Component("v_med3_i32", 3, v_med3_i32, provenance="manual 16.12 op 544"),
    Component("v_sad_u8", 3, v_sad_u8, provenance="manual 16.12 op 546"),
    Component("v_mad_u32_u24", 3, v_mad_u32_u24, provenance="manual 16.12"),
]

BY_NAME = {c.name: c for c in LIBRARY}

# `ds_bpermute_b32` is not a lane-local component: its prepared state is one VGPR
# across the whole wave, so the synthesizer models it separately.
BPERMUTE = {
    "name": "ds_bpermute_b32",
    "pipe": "lds",
    "provenance": "manual 12.5.2",
    "semantics": "Dst[0..31] = src[index[0..31]]; index bits [6:2] only; "
                 "offset0 is added to the index before use",
    "contract": "the 27 table lanes must be enabled in EXEC; disabled lanes read 0",
}
