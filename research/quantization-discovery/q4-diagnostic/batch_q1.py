#!/usr/bin/env python3
"""Run Q1 arms sequentially inside one run-batch-compare GPU reservation."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import time

from shootout import DEFAULT_BIN, MODELS, ROOT, hash_file


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('models', nargs='+', choices=MODELS)
    parser.add_argument('--bin-dir', type=Path, default=DEFAULT_BIN)
    args = parser.parse_args()
    binary = args.bin_dir / 'llama-perplexity'
    binary_hash = hash_file(binary)
    repo = Path(__file__).resolve().parents[3]
    revision = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.check_output(['git', '-C', str(repo), 'status', '--short'], text=True)
    for name in args.models:
        image = MODELS[name]
        if not image.is_file():
            raise FileNotFoundError(image)
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        destination = ROOT / 'receipts/kelana-06b/M3/q1' / f'{stamp}-{name}'
        destination.mkdir(parents=True, exist_ok=False)
        command = [str(binary), '-m', str(image), '-f', str(ROOT / 'corpus/wiki.test.raw'),
                   '-c', '512', '-ngl', '99', '-fa', 'on']
        load = subprocess.run(['uptime'], capture_output=True, text=True).stdout.strip()
        gpu_load = subprocess.run(['rocm-smi', '--showuse'], capture_output=True, text=True).stdout
        start = time.monotonic()
        with (destination / 'stdout.log').open('w') as out, (destination / 'stderr.log').open('w') as err:
            result = subprocess.run(command, stdout=out, stderr=err, check=False)
        elapsed = time.monotonic() - start
        stderr = (destination / 'stderr.log').read_text()
        ppl = re.search(r'Final estimate: PPL = ([\d.]+) \+/- ([\d.]+)', stderr)
        chunks = re.search(r'calculating perplexity over (\d+) chunks', stderr)
        receipt = dict(scenario='q1', model=name, image=str(image), image_bytes=image.stat().st_size,
                       image_sha256=hash_file(image), binary=str(binary), binary_sha256=binary_hash,
                       backend_library_sha256=hash_file(args.bin_dir / 'libggml-hip.so'),
                       argv=command, source_revision=revision, source_dirty=dirty, host_load=load,
                       gpu_load=gpu_load, wall_seconds=elapsed, exit_code=result.returncode,
                       chunks=int(chunks.group(1)) if chunks else None,
                       result=dict(perplexity=float(ppl.group(1)), uncertainty=float(ppl.group(2))) if ppl else None,
                       numerical_route='upstream llama.cpp HIP, full GPU offload, flash attention',
                       timing_boundary='full wikitext-2-raw-v1 test, nonoverlap 512, latter 256 scored')
        (destination / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print(json.dumps(dict(receipt=str(destination / 'receipt.json'), result=receipt['result'],
                              exit_code=result.returncode)), flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
