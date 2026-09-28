#!/usr/bin/env python3
"""Build the native intervention, run under the research GPU lock, record provenance."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BONSAI = Path('/path/to/workspace/projects/bonsai-halo')

def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda: f.read(8 << 20), b''):
            h.update(block)
    return h.hexdigest()

def command(*args):
    return subprocess.check_output(args, text=True, timeout=30).strip()

def provenance():
    paths = [HERE / n for n in ('quality.cpp', 'quality.hip', 'policy.hpp', 'Makefile', 'run_quality.py', 'build/quality-probe')]
    paths += [HERE.parent / 'consumer-polynomial/consumer.hpp']
    paths += list((BONSAI / 'kernels').glob('*.hpp'))
    paths += [BONSAI / 'kernels/halo_rows.hip']
    paths += [BONSAI / f'src/{n}.o' for n in ('gguf', 'repack', 'q8', 'engine', 'tokenizer')]
    paths += [BONSAI / f'kernels/{n}.o' for n in ('halo_kernels', 'halo_draft')]
    return {'sha256': {str(p): sha(p) for p in paths},
            'kelana_revision': command('git', '-C', str(ROOT), 'rev-parse', 'HEAD'),
            'bonsai_revision': command('git', '-C', str(BONSAI), 'rev-parse', 'HEAD'),
            'compiler': command('hipcc', '--version')}

def main():
    args = sys.argv[1:]
    if '--out' not in args:
        raise SystemExit('Required: --out FILE; other arguments pass to quality-probe')
    out = Path(args[args.index('--out')+1])
    subprocess.run(['make', '-C', str(HERE), '-j2'], check=True, timeout=55)
    before = provenance()
    model = Path(args[args.index('--model')+1]) if '--model' in args else Path('/path/to/workspace/data/bonsai2/PTQ1_0.gguf')
    before['model_files'] = {str(p): {'bytes': p.stat().st_size, 'mtime_ns': p.stat().st_mtime_ns}
                             for p in (model, Path(str(model)+'.halo'))}
    before['command'] = [str(HERE/'build/quality-probe'), *args]
    result = subprocess.run([str(HERE.parent/'hardware-run'), *before['command']], timeout=180)
    if result.returncode:
        raise SystemExit(result.returncode)
    if provenance()['sha256'] != before['sha256']:
        raise SystemExit('Source or binary changed during measurement; result not stamped')
    data = json.loads(out.read_text())
    data['provenance'] = before
    out.write_text(json.dumps(data, indent=2)+'\n')

if __name__ == '__main__':
    main()
