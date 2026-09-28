#!/usr/bin/env python3
"""Exact 4x4 integer map and static image/code accounting for two readers."""
import ctypes
import itertools
import random
import re
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TILES = 64
SEED = 240924


def compiler_sizes(object_file):
    text = subprocess.check_output(["nm", "-S", "--defined-only", str(object_file)], text=True)
    sizes = {}
    for line in text.splitlines():
        match = re.fullmatch(r"[0-9a-f]+ ([0-9a-f]+) T (scalar_reader|program_reader)", line)
        if match:
            sizes[match[2]] = int(match[1], 16)
    assert sizes.keys() == {"scalar_reader", "program_reader"}, sizes
    return sizes


def make_images(seed=SEED):
    rng = random.Random(seed)
    permutations = list(itertools.permutations(range(4)))
    scalar = bytearray()
    program = bytearray()
    reference = []
    for _ in range(TILES):
        template = [rng.randrange(-1, 2) for _ in range(4)]
        shifts = rng.choice(permutations)
        scale = rng.randrange(1, 8)
        matrix = [[template[(c + shifts[r]) & 3] for c in range(4)] for r in range(4)]
        code = sum((w + 1) * 3 ** (4 * r + c) for r in range(4) for c, w in enumerate(matrix[r]))
        scalar.extend(code.to_bytes(4, "little"))
        scalar.append(scale)
        program.append(sum((w + 1) * 3 ** c for c, w in enumerate(template)))
        program.append(sum(shift << (2 * r) for r, shift in enumerate(shifts)))
        program.append(scale)
        reference.append((matrix, scale))
    return scalar, program, reference


def main():
    scalar, program, reference = make_images()
    rng = random.Random(SEED + 1)
    inputs = [rng.randrange(-3, 4) for _ in range(4 * TILES)]
    expected = [sum(matrix[r][c] * inputs[4 * t + c] for c in range(4)) * scale
                for t, (matrix, scale) in enumerate(reference) for r in range(4)]
    with tempfile.TemporaryDirectory() as tmp:
        library = Path(tmp) / "readers.so"
        object_file = Path(tmp) / "readers.o"
        flags = ["clang", "-Os", "-fno-inline", "-fno-unroll-loops"]
        subprocess.run(flags + ["-c", str(HERE / "readers.c"), "-o", str(object_file)], check=True)
        subprocess.run(flags + ["-shared", "-fPIC", str(HERE / "readers.c"), "-o", str(library)], check=True)
        lib = ctypes.CDLL(str(library))
        x = (ctypes.c_int16 * len(inputs))(*inputs)
        sizes = compiler_sizes(object_file)
        for name, image in (("scalar_reader", scalar), ("program_reader", program)):
            out = (ctypes.c_int32 * (4 * TILES))()
            data = (ctypes.c_uint8 * len(image)).from_buffer_copy(image)
            fn = getattr(lib, name)
            fn.argtypes = [ctypes.POINTER(ctypes.c_uint8), ctypes.POINTER(ctypes.c_int16),
                           ctypes.POINTER(ctypes.c_int32), ctypes.c_size_t]
            fn(data, x, out, TILES)
            assert list(out) == expected, name
        totals = {"scalar": len(scalar) + sizes["scalar_reader"],
                  "program": len(program) + sizes["program_reader"]}
        print(f"tiles={TILES} original_weights={16*TILES} seed={SEED}")
        print(f"scalar model={len(scalar)} code={sizes['scalar_reader']} total={totals['scalar']}")
        print(f"program model={len(program)} code={sizes['program_reader']} total={totals['program']}")
        print(f"code_delta={sizes['program_reader']-sizes['scalar_reader']} "
              f"break_even_tiles={(sizes['program_reader']-sizes['scalar_reader']) // 2 + 1}")
        print(f"program_saving={totals['scalar']-totals['program']} exact_outputs={len(expected)}")


if __name__ == "__main__":
    main()
