#!/usr/bin/env python3
"""Reproduce M3 Q1 and isolated native throughput probes with durable receipts."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path('/path/to/workspace/data/engine-shootout')
STOCK = Path('/path/to/workspace/data/kelana-subbit/q4-diagnostic/stock-gguf')
RUNNER = ROOT / 'runners/kelana-06b'
DEFAULT_BIN = RUNNER / 'native-bin'
MODELS = {
    'kelana-q4-exact': RUNNER / 'calibrated-Q4_1.gguf',
    'kelana-q4-requant': RUNNER / 'calibrated-requant-Q4_K.gguf',
    'kelana-q3-requant': RUNNER / 'calibrated-requant-Q3_K.gguf',
    'source-q3': RUNNER / 'source-Q3_K.gguf',
    'source-imatrix-q3': RUNNER / 'source-imatrix-Q3_K.gguf',
    'source-q4_1': RUNNER / 'source-Q4_1.gguf',
    'kelana-imatrix-q3': RUNNER / 'calibrated-imatrix-Q3_K.gguf',
    **{name: STOCK / f'Qwen_Qwen3-0.6B-{name}.gguf' for name in (
        'bf16', 'Q8_0', 'Q4_K_M', 'IQ2_M', 'Q3_K_S', 'Q3_K_M', 'Q3_K_L',
        'IQ3_XXS', 'IQ3_M', 'Q4_0', 'IQ4_XS')},
}


def run(command, **kw):
    return subprocess.run(command, capture_output=True, text=True, check=False, **kw)


def hash_file(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', required=True, choices=MODELS)
    parser.add_argument('--scenario', required=True, choices=['q1', 's1', 's3', 's4'])
    parser.add_argument('--chunks', type=int, default=-1)
    parser.add_argument('--bin-dir', type=Path, default=DEFAULT_BIN)
    args = parser.parse_args()
    image = MODELS[args.model]
    if not image.is_file():
        parser.error(f'model missing: {image}')
    executable = args.bin_dir / ('llama-perplexity' if args.scenario == 'q1' else
                                  'llama-batched-bench' if args.scenario == 's4' else 'llama-bench')
    if args.scenario == 'q1':
        command = [str(executable), '-m', str(image), '-f', str(ROOT / 'corpus/wiki.test.raw'),
                   '-c', '512', '-ngl', '99', '-fa', 'on']
        if args.chunks > 0:
            command += ['--chunks', str(args.chunks)]
    elif args.scenario == 's1':
        command = [str(executable), '-m', str(image), '-p', '128', '-n', '256',
                   '-d', '0,4096', '-r', '3', '-ngl', '99', '-fa', 'on', '-o', 'json']
    elif args.scenario == 's3':
        command = [str(executable), '-m', str(image), '-p', '512,4096', '-n', '0',
                   '-r', '3', '-ngl', '99', '-fa', 'on', '-o', 'json']
    else:
        command = [str(executable), '-m', str(image), '-ngl', '99', '-fa', 'on',
                   '-c', '32768', '-b', '2048', '-ub', '512', '-npp', '128', '-ntg', '128',
                   '-npl', '1,8,32,64,128', '--output-format', 'jsonl',
                   '--prompt-ids-dir', str(ROOT / 'prompts/qwen3/batch')]
    wrapper = ['/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare',
               '--runtime-max', '900s', '--memory-gib', '12', '--host-reserve-gib', '4', '--exec', *command]
    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    destination = ROOT / 'receipts/kelana-06b/M3' / args.scenario / f'{timestamp}-{args.model}'
    destination.mkdir(parents=True, exist_ok=False)
    repo = Path(__file__).resolve().parents[3]
    revision = run(['git', '-C', str(repo), 'rev-parse', 'HEAD']).stdout.strip()
    dirty = run(['git', '-C', str(repo), 'status', '--short']).stdout
    system = run(['uptime']).stdout.strip()
    gpu_load = run(['rocm-smi', '--showuse']).stdout
    start = time.monotonic()
    result = run(wrapper)
    (destination / 'stdout.log').write_text(result.stdout)
    (destination / 'stderr.log').write_text(result.stderr)
    match = re.search(r'Final estimate: PPL = ([0-9.]+) \+/- ([0-9.]+)', result.stderr)
    receipt = dict(scenario=args.scenario, model=args.model, image=str(image), image_bytes=image.stat().st_size,
                   image_sha256=hash_file(image), executable=str(executable), binary_sha256=hash_file(executable),
                   backend_library_sha256=hash_file(args.bin_dir / 'libggml-hip.so'),
                   argv=command, wrapper_argv=wrapper, source_revision=revision, source_dirty=dirty,
                   load=system, gpu_load=gpu_load, wall_seconds=time.monotonic()-start,
                   exit_code=result.returncode, result=dict(perplexity=float(match.group(1)), uncertainty=float(match.group(2)))
                   if match else None, corpus_chunks=args.chunks if args.chunks > 0 else 'full',
                   numerical_route='upstream llama.cpp HIP, Qwen3, Flash Attention on, ggml quantized matmul',
                   timing_boundary=('fixed independent Qwen3 token-ID prompts and greedy argmax; CPU logits transfer included'
                                    if args.scenario == 's4' else 'llama-bench synthetic tokens' if args.scenario in ('s1', 's3')
                                    else 'llama-perplexity 512-token nonoverlap, latter 256 tokens'))
    (destination / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(dict(receipt=str(destination / 'receipt.json'), exit_code=result.returncode,
                          result=receipt['result'])), flush=True)
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
