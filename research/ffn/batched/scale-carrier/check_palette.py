#!/usr/bin/env python3
"""Exhaust the packed-byte map, independently of the native implementation."""
import json


def check():
    cases = 0
    for multiplier in range(1, 128):
        palette = [0, multiplier, 0, (-multiplier) & 255]
        for code in range(256):
            # One byte contains four two-bit codes. The four output selectors
            # each address the row's prepared palette, without a trit value.
            expanded = code | (code << 12)
            selectors = (expanded | (expanded << 6)) & 0x03030303
            result = sum(palette[(selectors >> (8 * i)) & 255] << (8 * i) for i in range(4))
            reference = 0
            for i in range(4):
                trit = {0: 0, 1: 1, 2: 0, 3: -1}[(code >> (2 * i)) & 3]
                reference |= ((trit * multiplier) & 255) << (8 * i)
            assert result == reference, (code, multiplier, result, reference)
            cases += 1
    # Triangle inequality bounds every partial sum, not just the final result.
    bound = 17408 * 127 * 127
    assert bound < 2**31
    return {"packed_byte_multiplier_cases": cases, "mismatches": 0,
            "largest_K": 17408, "absolute_sum_bound": bound,
            "int32_safe": True,
            "scope": "integer map and range; not floating scale fitting or full-model quality"}


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
