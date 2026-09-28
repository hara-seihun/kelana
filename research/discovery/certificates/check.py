#!/usr/bin/env python3
"""Check exported examples with Lean and ensure an altered RHS is rejected."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def run(path):
    start = time.monotonic()
    result = subprocess.run(['lake', 'env', 'lean', str(path)], cwd=ROOT,
                            text=True, capture_output=True, timeout=25)
    return result, time.monotonic() - start


def main():
    receipts = []
    for path in sorted((HERE / 'examples').glob('*.lean')):
        result, elapsed = run(path)
        if result.returncode:
            raise SystemExit(result.stdout + result.stderr)
        if 'sorryAx' in result.stdout or '._native.' in result.stdout:
            raise SystemExit('unexpected trusted reduction or sorry axiom in certificate')
        receipts.append({'path': str(path.relative_to(HERE)), 'sha256': sha(path),
                         'seconds': elapsed, 'axiom_report': result.stdout.strip()})
    if len(receipts) != 2:
        raise SystemExit('expected the two exported examples')
    source = (HERE / 'examples/gated-pair.lean').read_text()
    altered, count = re.subn(r'^def rhs :.*$', 'def rhs : Expr Rat 2 := .lit 17', source, flags=re.M)
    assert count == 1
    with tempfile.TemporaryDirectory(prefix='kelana-certificate-') as directory:
        path = Path(directory) / 'Wrong.lean'
        path.write_text(altered)
        result, _ = run(path)
        if result.returncode == 0 or 'lhs.normalize = rhs.normalize' not in result.stdout:
            raise SystemExit('negative control did not fail at the equality proof: ' + result.stdout + result.stderr)
    version = subprocess.check_output(['lake', 'env', 'lean', '--version'], cwd=ROOT, text=True).strip()
    report = {'format': 'kelana-kernel-certificate-check/1', 'lean': version,
              'normalizer_sha256': sha(ROOT / 'Kelana/TernaryAlgebra.lean'),
              'checker_sha256': sha(Path(__file__)), 'certificates': receipts,
              'altered_rhs_rejected': True,
              'scope': 'Exact rational expression identities on the ternary grid, not native hardware costs or floating semantics.'}
    (HERE / 'checked.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__': main()
