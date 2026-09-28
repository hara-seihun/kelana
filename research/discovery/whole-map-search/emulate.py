"""Independent concrete emulator for the synthesized programs.

Written from the same vendor pseudocode as `isa.py` but in plain Python integer
arithmetic, so a program found by the solver is re-checked on all inputs by code
that shares nothing with the solver's bitvector encoding. A synthesized program
that fails here is a defect in the model, not a result.
"""

from __future__ import annotations

from typing import Dict, List, Optional, Sequence

M32 = 0xFFFFFFFF


def u32(v: int) -> int:
    return v & M32


def i32(v: int) -> int:
    v &= M32
    return v - (1 << 32) if v >> 31 else v


def byte(v: int, i: int) -> int:
    return (v >> (8 * i)) & 0xFF


def s8(b: int) -> int:
    return b - 256 if b & 0x80 else b


def s4(b: int) -> int:
    return b - 16 if b & 0x8 else b


def _perm_byte(hi: int, lo: int, sel: int) -> int:
    data = (u32(hi) << 32) | u32(lo)
    if sel >= 13:
        return 0xFF
    if sel == 12:
        return 0x00
    if sel >= 8:
        src = (data >> (8 * (2 * (sel - 8) + 1))) & 0xFF
        return 0xFF if src & 0x80 else 0x00
    return (data >> (8 * sel)) & 0xFF


OPS = {
    "v_add_nc_u32": lambda a, b: u32(a + b),
    "v_sub_nc_u32": lambda a, b: u32(a - b),
    "v_mul_lo_u32": lambda a, b: u32(a * b),
    "v_and_b32": lambda a, b: u32(a & b),
    "v_or_b32": lambda a, b: u32(a | b),
    "v_xor_b32": lambda a, b: u32(a ^ b),
    "v_lshlrev_b32": lambda a, b: u32(b << (a & 31)),
    "v_lshrrev_b32": lambda a, b: u32(b) >> (a & 31),
    "v_ashrrev_i32": lambda a, b: u32(i32(b) >> (a & 31)),
    "v_lshl_or_b32": lambda a, b, c: u32((a << (b & 31)) | c),
    "v_lshl_add_u32": lambda a, b, c: u32((a << (b & 31)) + c),
    "v_add3_u32": lambda a, b, c: u32(a + b + c),
    "v_and_or_b32": lambda a, b, c: u32((a & b) | c),
    "v_bfe_u32": lambda a, b, c: u32((u32(a) >> (b & 31)) & ((1 << (c & 31)) - 1)),
    "v_perm_b32": lambda a, b, c: u32(
        sum(_perm_byte(a, b, byte(c, i)) << (8 * i) for i in range(4))
    ),
    "v_alignbit_b32": lambda a, b, c: u32(((u32(a) << 32 | u32(b)) >> (c & 31))),
    "v_med3_i32": lambda a, b, c: u32(sorted((i32(a), i32(b), i32(c)))[1]),
    "v_sad_u8": lambda a, b, c: u32(
        c + sum(abs(byte(a, i) - byte(b, i)) for i in range(4))
    ),
    "v_dot4_i32_i8": lambda a, b, c: u32(
        c + sum(s8(byte(a, i)) * s8(byte(b, i)) for i in range(4))
    ),
    "v_dot4_u32_u8": lambda a, b, c: u32(
        c + sum(byte(a, i) * byte(b, i) for i in range(4))
    ),
    "v_dot8_i32_i4": lambda a, b, c: u32(
        c + sum(s4((a >> (4 * i)) & 15) * s4((b >> (4 * i)) & 15) for i in range(8))
    ),
    "v_mad_u32_u24": lambda a, b, c: u32((a & 0xFFFFFF) * (b & 0xFFFFFF) + c),
}


def run(
    program: Sequence[dict],
    env: Dict[str, int],
    table: Optional[Sequence[int]] = None,
) -> int:
    """Execute a synthesized straight-line program; returns the last result."""
    regs = dict(env)
    last = 0
    for step in program:
        args = []
        for a in step["args"]:
            if a in regs:
                args.append(regs[a])
            elif a.startswith("const") and "=" in a:
                args.append(int(a.split("=")[1], 16))
            else:
                raise KeyError(f"unknown operand {a}")
        if step["op"] == "ds_bpermute_b32":
            assert table is not None, "bpermute needs its wave table"
            addr = u32(args[0] + step.get("offset0", 0))
            last = u32(table[(addr >> 2) & 31])
        else:
            last = OPS[step["op"]](*args)
        regs[step["dst"]] = last
    return last


def check_index_partition(program, input_names, inputs, targets, mode):
    """Check fibers BEFORE the final gather, independently of its table values."""
    if not program or program[-1]["op"] != "ds_bpermute_b32":
        raise ValueError("the lane-index contract requires a final gather")
    gather = program[-1]
    indices = []
    for st in range(len(targets)):
        env = {n: u32(inputs[r][st]) for r, n in enumerate(input_names)}
        for step in program[:-1]:
            env[step["dst"]] = run([step], env)
        arg = gather["args"][0]
        address = env[arg] if arg in env else int(arg.split("=")[1], 16)
        indices.append((u32(address + gather.get("offset0", 0)) >> 2) & 31)
    bad = []
    for i in range(len(targets)):
        for j in range(i):
            same_index, same_target = indices[i] == indices[j], targets[i] == targets[j]
            if (same_index and not same_target) or (mode == "match" and same_target and not same_index):
                bad.append({"left": j, "right": i, "same_index": same_index, "same_target": same_target})
    return {"observation": "lane index before the lookup", "mode": mode,
            "mismatches": bad, "valid": not bad, "indices": indices}


def check_program(
    program: Sequence[dict],
    input_names: Sequence[str],
    inputs: Sequence[Sequence[int]],
    targets: Sequence[int],
    output: str = "int32",
    table: Optional[Sequence[int]] = None,
) -> dict:
    """Exhaustive re-check on every state. Returns mismatches, if any."""
    bad = []
    for st, want in enumerate(targets):
        env = {n: u32(inputs[r][st]) for r, n in enumerate(input_names)}
        got = run(program, env, table)
        ok = (got & 0xFF) == (want & 0xFF) if output == "byte" else i32(got) == want
        if not ok:
            bad.append({"state": st, "want": want, "got": i32(got)})
    return {"states": len(targets), "mismatches": bad, "exact": not bad}
