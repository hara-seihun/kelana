#!/usr/bin/env python3
"""Export the frozen NPZ CDF payload and run the native CPU probe."""
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
    with np.load(args.tables) as archive:
        cdf = archive['cdf']
        assert cdf.shape == (32, 6, 16, 16) and cdf.dtype == np.uint16
        assert np.all(cdf[:, :, :, -1] == 256)
    with tempfile.TemporaryDirectory(prefix='kelana-learned-native-') as directory:
        binary = Path(directory) / 'bench'
        payload = Path(directory) / 'cdf.bin'
        cdf.astype('<u2', copy=False).tofile(payload)
        subprocess.run(['c++', '-O3', '-std=c++20', '-march=native', str(HERE / 'bench.cpp'), '-o', str(binary)], check=True)
        result = subprocess.run([str(binary), str(payload), str(args.rounds), str(args.active_contexts)], capture_output=True, text=True, check=True)
        record = json.loads(result.stdout)
        record['tables_sha256'] = hashlib.sha256(args.tables.read_bytes()).hexdigest()
        record['compiler'] = subprocess.check_output(['c++', '--version'], text=True).splitlines()[0]
        print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
