#!/usr/bin/env python3
"""Count exact softmax score fibers of a bounded integer key sequence."""
import argparse
import itertools
import json
import math
from pathlib import Path


def classes(alphabet: int, length: int) -> int:
    return alphabet**length - (alphabet-1)**length


def saved_gauge_bits(alphabet: int, length: int, coordinates: int) -> float:
    fraction = ((alphabet-1)/alphabet)**length
    return -coordinates*math.log1p(-fraction)/math.log(2)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    # Explicit score-difference equivalence against every basis query. The
    # tiny alphabet checks the quotient count, not the model's reachable codes.
    for alphabet, length, coordinates in ((3, 3, 2), (4, 2, 2)):
        keys = list(itertools.product(range(alphabet), repeat=coordinates))
        partitions = set()
        for seq in itertools.product(keys, repeat=length):
            partitions.add(tuple(tuple(key[d]-seq[0][d] for key in seq[1:])
                                 for d in range(coordinates)))
        assert len(partitions) == classes(alphabet, length)**coordinates
    alphabet, coordinates = 15, 32
    rows = []
    for length in (2, 4, 8, 16, 32, 64, 128, 256, 1024):
        bits = coordinates*math.log2(classes(alphabet, length)) if length <= 64 else (
            coordinates*(length*math.log2(alphabet)) - saved_gauge_bits(alphabet, length, coordinates))
        rows.append({'keys': length, 'quotient_bits': bits,
                     'gauge_saving_vs_base15_bits': saved_gauge_bits(alphabet, length, coordinates),
                     'physical_nibble_bits': 4*coordinates*length,
                     'ceil_bytes_ideal_entropy_code': math.ceil(bits/8)})
    result = {'alphabet': alphabet, 'coordinates_per_group': coordinates,
              'domain': 'all 15^32 signed-nibble key vectors per position, all integer basis queries',
              'class_count': '(15^T-14^T)^32', 'rows': rows,
              'two_key_delta_range': [-14, 14], 'two_key_delta_bits_per_coordinate': 5,
              'tiny_exhaustive_checks': [[3, 3, 2], [4, 2, 2]]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
