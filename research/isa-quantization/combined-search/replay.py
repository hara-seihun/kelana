#!/usr/bin/env python3
"""Serialize and independently replay every combined-search frontier witness.

Usage: python3 replay.py [results.json] [payloads.json]
The serialized format is a contiguous LSB-first bitstream padded with zero bits
at the end of the final byte. Every model-specific field is in that bitstream.
"""

import argparse
import json
from pathlib import Path


TAGS = {("machine", 1): 0, ("machine", 2): 1,
        ("scalar", 2): 2, ("scalar", 4): 3,
        ("table", 1): 4, ("table", 2): 5, ("table", 4): 6,
        ("constant", 4): 7}
KINDS = {value: key for key, value in TAGS.items()}


class Bits:
    def __init__(self, data=b""):
        self.value = int.from_bytes(data, "little")
        self.width = len(data) * 8
        self.offset = 0

    def put(self, value, width):
        if not 0 <= value < 1 << width:
            raise ValueError(f"{value} does not fit in {width} bits")
        self.value |= value << self.width
        self.width += width

    def get(self, width):
        if self.offset + width > self.width:
            raise ValueError("truncated payload")
        value = (self.value >> self.offset) & ((1 << width) - 1)
        self.offset += width
        return value

    def finish(self):
        if self.value >> self.offset:
            raise ValueError("nonzero byte-padding bits")
        if self.width - self.offset >= 8:
            raise ValueError("surplus payload byte")

    def packed(self):
        return self.value.to_bytes((self.width + 7) // 8, "little")


def code_value(bits, code, kind):
    if kind == "constant" or bits == 4 and kind in ("table", "scalar"):
        return code - 8
    if bits == 1:
        return 4 if code else -4
    return 4 * (code - 2)


def prefix_by_id(identifier):
    if identifier < 0:
        raise ValueError("negative prefix id")
    next_id = 0
    for k in range(2):
        for n in range(3):
            for e0 in range(3):
                for e1 in range(3):
                    for wi in range(6 ** n):
                        if identifier == next_id:
                            word = []
                            for _ in range(n):
                                word.append(wi % 6)
                                wi //= 6
                            return k, n, e0, e1, word
                        next_id += 1
    raise ValueError(f"invalid prefix id {identifier}")


def machine_op(state, opcode, k):
    if opcode == 6:
        return state
    if not 0 <= opcode < 6:
        raise ValueError(f"invalid machine opcode {opcode}")
    port = opcode & 1
    old = (state >> (2 * port)) & 3
    other = (state >> (2 * (1 - port))) & 3
    if opcode < 2:
        result = (old + 1 + k) & 3
    elif opcode < 4:
        result = (old + other) & 3
    else:
        result = old ^ other
    return (state & ~(3 << (2 * port))) | (result << (2 * port))


def table_codes(target, bits):
    # Each address may be reached by either source or live consumer input.
    # Search all legal codes independently, including unused cells (tie -> 0).
    occurrences = [[] for _ in range(16)]
    for x in range(16):
        u, v = x & 3, x >> 2
        occurrences[x].append(target[2 * x])
        occurrences[((u + v) & 3) | (u << 2)].append(target[2 * x + 1])
    return [min(range(1 << bits),
                key=lambda c: sum((code_value(bits, c, "table") - y) ** 2
                                  for y in observations))
            for observations in occurrences]


def encode(witness, target):
    fields = witness.split(":")
    kind = fields[0]
    writer = Bits()
    if kind == "machine":
        if len(fields) != 6:
            raise ValueError(f"malformed machine witness {witness}")
        identifier, cont, port, bits, qi = map(int, fields[1:])
        k, n, e0, e1, word = prefix_by_id(identifier)
        if bits not in (1, 2) or cont not in range(7) or port not in range(2):
            raise ValueError(f"invalid machine fields {witness}")
        if not 0 <= qi < 1 << (4 * bits):
            raise ValueError(f"invalid readout code id {qi}")
        writer.put(TAGS[(kind, bits)], 3)
        writer.put(e0, 2)
        writer.put(e1, 2)
        writer.put(k, 1)
        writer.put(n, 2)
        for opcode in word:
            writer.put(opcode, 3)
        writer.put(cont, 3)
        writer.put(port, 1)
        for label in range(4):
            writer.put((qi >> (bits * label)) & ((1 << bits) - 1), bits)
    elif kind == "scalar":
        if len(fields) != 3:
            raise ValueError(f"malformed scalar witness {witness}")
        bits, identifier = map(int, fields[1:])
        if bits not in (2, 4) or not 0 <= identifier < 1 << (3 * bits):
            raise ValueError(f"invalid scalar witness {witness}")
        writer.put(TAGS[(kind, bits)], 3)
        for coefficient in range(3):
            writer.put((identifier >> (bits * coefficient)) & ((1 << bits) - 1), bits)
    elif kind == "table":
        if len(fields) != 2:
            raise ValueError(f"malformed table witness {witness}")
        bits = int(fields[1])
        writer.put(TAGS[(kind, bits)], 3)
        for code in table_codes(target, bits):
            writer.put(code, bits)
    elif kind == "constant":
        if len(fields) != 2:
            raise ValueError(f"malformed constant witness {witness}")
        code = int(fields[1])
        writer.put(TAGS[(kind, 4)], 3)
        writer.put(code, 4)
    else:
        raise ValueError(f"unknown witness {witness}")
    return writer.packed()


def decode(payload):
    reader = Bits(payload)
    kind, bits = KINDS[reader.get(3)]
    if kind == "machine":
        e0, e1 = reader.get(2), reader.get(2)
        k, n = reader.get(1), reader.get(2)
        if e0 > 2 or e1 > 2 or n > 2:
            raise ValueError("illegal producer fields")
        word = [reader.get(3) for _ in range(n)]
        cont, port = reader.get(3), reader.get(1)
        codes = [reader.get(bits) for _ in range(4)]
        if any(opcode > 5 for opcode in word) or cont > 6:
            raise ValueError("illegal instruction")
        reader.finish()
        values = [code_value(bits, code, kind) for code in codes]
        response = []
        for x in range(16):
            features = (0, x & 3, x >> 2)
            state = ((features[e0] + k) & 3) | (((features[e1] + k) & 3) << 2)
            for opcode in word:
                state = machine_op(state, opcode, k)
            initial = (state >> (2 * port)) & 3
            # The live candidate state, not the source x, feeds the continuation.
            final = (machine_op(state, cont, k) >> (2 * port)) & 3
            response.extend((values[initial], values[final]))
        return response, 6 + n + (cont != 6)
    if kind == "scalar":
        coefficients = [code_value(bits, reader.get(bits), kind) for _ in range(3)]
        reader.finish()
        a, b, c = coefficients
        response = []
        for x in range(16):
            u, v = x & 3, x >> 2
            response.extend((a + b * u + c * v, a + b * ((u + v) & 3) + c * u))
        return response, 7
    if kind == "table":
        table = [code_value(bits, reader.get(bits), kind) for _ in range(16)]
        reader.finish()
        response = []
        for x in range(16):
            u, v = x & 3, x >> 2
            response.extend((table[x], table[((u + v) & 3) | (u << 2)]))
        return response, 7
    value = reader.get(4) - 8
    reader.finish()
    return [value] * 32, 2


def replay(results):
    output = {"format": "LSB-first, 3-bit tag, zero-padded byte", "teachers": []}
    total = 0
    for teacher in results["teachers"]:
        target = teacher["target"]
        if len(target) != 32 or not all(isinstance(v, int) for v in target):
            raise ValueError(f"invalid target for {teacher['name']}")
        arms = []
        for arm in teacher["arms"]:
            points = []
            for point in arm["frontier"]:
                witness = point["witness"]
                payload = encode(witness, target)
                response, work = decode(payload)
                sse = sum((a - b) ** 2 for a, b in zip(response, target))
                expected = (point["bytes"], point["work"], point["sse_units"])
                actual = (len(payload), work, sse)
                if actual != expected:
                    raise ValueError(f"{teacher['name']} arm {arm['flags']} {witness}: "
                                     f"reported (bytes,work,SSE) {expected}, replay {actual}")
                points.append({"witness": witness, "payload_hex": payload.hex()})
                total += 1
            arms.append({"flags": arm["flags"], "points": points})
        output["teachers"].append({"name": teacher["name"], "arms": arms})
    output["checked_points"] = total
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    here = Path(__file__).resolve().parent
    parser.add_argument("results", type=Path, nargs="?", default=here / "results.json")
    parser.add_argument("output", type=Path, nargs="?", default=here / "payloads.json")
    args = parser.parse_args()
    try:
        payloads = replay(json.loads(args.results.read_text()))
    except (ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"replay failed: {error}\n")
    args.output.write_text(json.dumps(payloads, separators=(",", ":")) + "\n")
    print(f"replayed {payloads['checked_points']} points; wrote {args.output}")


if __name__ == "__main__":
    main()
