#!/usr/bin/env python3
"""Independently serialize, decode and replay every paid coupled-readout point.

Usage: python3 replay.py [results.json] [payloads.json]
The format is contiguous LSB-first fields, with only zero padding at the end
of the final byte. Model-dependent values are never supplied to the decoder.
"""

import argparse
import json
from pathlib import Path

TAG = {("machine", 1): 0, ("machine", 2): 1, ("scalar", 4): 2,
       ("direct", 1): 3, ("direct", 2): 4, ("direct", 4): 5,
       ("constant", 4): 6}
REVERSE_TAG = {v: k for k, v in TAG.items()}


class BitStream:
    def __init__(self, payload=b""):
        self.data = int.from_bytes(payload, "little")
        self.bits = len(payload) * 8
        self.at = 0

    def add(self, value, width):
        if not isinstance(value, int) or not 0 <= value < 1 << width:
            raise ValueError(f"field {value!r} cannot fit in {width} bits")
        self.data |= value << self.bits
        self.bits += width

    def take(self, width):
        if self.at + width > self.bits:
            raise ValueError("truncated field")
        value = (self.data >> self.at) & ((1 << width) - 1)
        self.at += width
        return value

    def finish(self):
        if self.bits - self.at >= 8 or self.data >> self.at:
            raise ValueError("extra byte or nonzero padding")

    def encode(self):
        return self.data.to_bytes((self.bits + 7) // 8, "little")


def encode(point):
    witness = point["witness"].split(":")
    kind = witness[0]
    values = point["values"]
    if len(values) != 8:
        raise ValueError("expected exactly eight readout cells")
    stream = BitStream()
    if kind == "machine":
        if len(witness) != 6:
            raise ValueError(f"malformed machine witness {witness}")
        square, k, a, b, width = map(int, witness[1:])
        stream.add(TAG[(kind, width)], 3)
        for value, bits in ((square, 1), (k, 2), (a, 2), (b, 2)):
            stream.add(value, bits)
        for code in values:
            stream.add(code, width)
    elif kind == "scalar":
        if len(witness) != 3:
            raise ValueError(f"malformed scalar witness {witness}")
        intercept, slope = map(int, witness[1:])
        stream.add(TAG[(kind, 4)], 3)
        stream.add(intercept, 4)
        stream.add(slope, 4)
    elif kind == "direct":
        if len(witness) != 2:
            raise ValueError(f"malformed direct witness {witness}")
        width = int(witness[1])
        stream.add(TAG[(kind, width)], 3)
        for cell in values:
            stream.add(cell + 8 if width == 4 else cell, width)
    elif kind == "constant":
        if len(witness) != 2:
            raise ValueError(f"malformed constant witness {witness}")
        stream.add(TAG[(kind, 4)], 3)
        stream.add(int(witness[1]), 4)
    else:
        raise ValueError(f"unknown witness family {kind!r}")
    return stream.encode()


def operation(state, action):
    if action == 0:
        return state
    if action == 1:
        return (state + 1) & 7
    if action == 2:
        return state ^ 1
    if action == 3:
        return ((state << 1) | (state >> 2)) & 7
    raise ValueError(f"invalid action {action}")


def machine_value(code, width):
    return (1 if code else -1) if width == 1 else code - 2


def decode(payload):
    stream = BitStream(payload)
    tag = stream.take(3)
    if tag not in REVERSE_TAG:
        raise ValueError(f"invalid format tag {tag}")
    kind, width = REVERSE_TAG[tag]
    if kind == "machine":
        square = stream.take(1)
        k, a, b = stream.take(2), stream.take(2), stream.take(2)
        values = [stream.take(width) for _ in range(8)]
        work = 10 + square + (k != 0) + (a != 0) + (b != 0)
        def branch(x):
            z = (((x * x) if square else x) & 7) ^ k
            i, j = operation(z, a), operation(z, b)
            return tuple(4 * machine_value(values[t], width) for t in (z, i, j))
    elif kind == "scalar":
        intercept, slope = stream.take(4) - 8, stream.take(4) - 8
        values = [intercept + slope * x for x in range(8)]
        work = 12
        def branch(x):
            return tuple(values[t] for t in (x, operation(x, 1), operation(x, 3)))
    elif kind == "direct":
        codes = [stream.take(width) for _ in range(8)]
        values = [(code - 8 if width == 4 else machine_value(code, width) * 4)
                  for code in codes]
        work = 12
        def branch(x):
            return tuple(values[t] for t in (x, operation(x, 1), operation(x, 3)))
    else:
        code = stream.take(4)
        values = [code - 8] * 8
        work = 6
        def branch(x):
            return values[x], values[operation(x, 1)], values[operation(x, 3)]
    stream.finish()
    return kind, width, values, work, branch


def endpoint_loss(branch, target):
    total = 0
    for x in range(8):
        candidate = branch(x)
        reference = (target[x], target[operation(x, 1)], target[operation(x, 3)])
        total += 16 * sum((a - b) ** 2 for a, b in zip(candidate, reference))
        total += (candidate[0] * candidate[1] - reference[0] * reference[1]) ** 2
        total += (candidate[1] * candidate[2] - reference[1] * reference[2]) ** 2
    return total


def replay(results):
    verified = 0
    teachers = []
    for teacher in results["teachers"]:
        target = teacher["target"]
        if len(target) != 8 or any(not isinstance(x, int) for x in target):
            raise ValueError(f"invalid target for {teacher['name']}")
        arms = []
        for arm in teacher["arms"]:
            points = []
            for point in arm["frontier"]:
                payload = encode(point)
                kind, width, decoded, work, branch = decode(payload)
                original = point["values"]
                if kind == "direct" and width in (1, 2):
                    expected_readout = [4 * machine_value(c, width) for c in original]
                else:
                    expected_readout = original
                actual_readout = decoded
                if actual_readout != expected_readout:
                    raise ValueError(f"{teacher['name']} {point['witness']}: readout differs")
                actual = (len(payload), work, endpoint_loss(branch, target))
                expected = (point["bytes"], point["work"], point["loss"])
                if actual != expected:
                    raise ValueError(f"{teacher['name']} arm {arm['arm']} {point['witness']}: "
                                     f"reported (bytes,work,loss) {expected}, replay {actual}")
                points.append({"witness": point["witness"], "payload_hex": payload.hex()})
                verified += 1
            arms.append({"arm": arm["arm"], "points": points})
        teachers.append({"name": teacher["name"], "arms": arms})
    return {"format": "LSB-first; 3-bit tag; zero-padded final byte",
            "checked_points": verified, "teachers": teachers}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    here = Path(__file__).resolve().parent
    parser.add_argument("results", type=Path, nargs="?", default=here / "results.json")
    parser.add_argument("output", type=Path, nargs="?", default=here / "payloads.json")
    args = parser.parse_args()
    try:
        data = replay(json.loads(args.results.read_text()))
    except (ValueError, TypeError, KeyError) as exc:
        parser.exit(1, f"coupled-readout replay failed: {exc}\n")
    args.output.write_text(json.dumps(data, separators=(",", ":")) + "\n")
    print(f"replayed {data['checked_points']} frontier points; wrote {args.output}")


if __name__ == "__main__":
    main()
