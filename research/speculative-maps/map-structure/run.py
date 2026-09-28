#!/usr/bin/env python3
"""Run the matched native CDF encoding probe on the frozen learned tables."""
import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
DEFAULT = Path('/path/to/workspace/data/kelana-speculative/learned-transition-tables.npz')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tables', type=Path, default=DEFAULT)
    parser.add_argument('--rounds', type=int, default=4)
    parser.add_argument('--active-contexts', type=int, choices=(1, 32), default=32)
    args = parser.parse_args()
    with np.load(args.tables) as data:
        cdf = data['cdf']
        assert cdf.shape == (32, 6, 16, 16) and cdf.dtype == np.uint16
    with tempfile.TemporaryDirectory(prefix='kelana-map-structure-') as directory:
        binary = Path(directory) / 'bench'
        payload = Path(directory) / 'cdf.bin'
        cdf.astype('<u2', copy=False).tofile(payload)
        subprocess.run(['c++', '-O3', '-std=c++20', '-march=native', str(HERE / 'bench.cpp'), '-o', str(binary)], check=True)
        output = subprocess.check_output([str(binary), str(payload), str(args.rounds), str(args.active_contexts)], text=True)
        record = json.loads(output)
        record['tables_sha256'] = hashlib.sha256(args.tables.read_bytes()).hexdigest()
        record['compiler'] = subprocess.check_output(['c++', '--version'], text=True).splitlines()[0]
        print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
