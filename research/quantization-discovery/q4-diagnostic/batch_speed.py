#!/usr/bin/env python3
"""Sequential fixed-prompt S1/S3 and labeled synthetic S4, one GPU reservation."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import time

from shootout import DEFAULT_BIN, MODELS, ROOT, hash_file


def run_one(model, scenario, extent, binary_dir, revision, dirty):
    image = MODELS[model]
    prompt_dir = ROOT / 'prompts/qwen3'
    common = ['-m', str(image), '-ngl', '99', '-fa', 'on']
    if scenario == 'S1':
        binary = binary_dir / 'llama-cli'
        prompt_file = prompt_dir / ('4096+128.txt' if extent else '128.txt')
        command = [str(binary), *common, '-c', str(extent + 400), '-f', str(prompt_file),
                   '-n', '256', '--temp', '0', '--ignore-eos', '--no-display-prompt', '--single-turn']
        timing = (f'llama-cli exact shared 128-token text at occupied depth {extent}; '
                  'generation rate excludes prompt/model loading')
    elif scenario == 'S3':
        binary = binary_dir / 'llama-cli'
        command = [str(binary), *common, '-c', str(extent + 16), '-f', str(prompt_dir / f'{extent}.txt'),
                   '-n', '1', '--temp', '0', '--no-display-prompt', '--single-turn']
        timing = f'llama-cli exact shared {extent}-token text; prompt eval only'
    else:
        binary = binary_dir / 'llama-batched-bench'
        command = [str(binary), *common, '-c', str(max(2048, extent * 272)), '-b', '2048', '-ub', '512',
                   '-npp', '128', '-ntg', '128', '-npl', str(extent), '--output-format', 'jsonl',
                   '--prompt-ids-dir', str(prompt_dir / 'batch')]
        timing = 'independent fixed Qwen3 prompt IDs, 128 greedy argmax steps; includes CPU logits transfer/selection'
    destination = ROOT / 'receipts/kelana-06b/M3' / scenario / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + f'-{model}-{extent}')
    destination.mkdir(parents=True, exist_ok=False)
    host = subprocess.run(['uptime'], capture_output=True, text=True).stdout.strip()
    gpu = subprocess.run(['rocm-smi', '--showuse'], capture_output=True, text=True).stdout
    start = time.monotonic()
    with (destination / 'stdout.log').open('w') as out, (destination / 'stderr.log').open('w') as err:
        result = subprocess.run(command, stdout=out, stderr=err, check=False)
    stdout = (destination / 'stdout.log').read_text()
    stderr = (destination / 'stderr.log').read_text()
    speed = re.search(r'\[ Prompt: ([0-9.]+) t/s \| Generation: ([0-9.]+) t/s \]', stdout + stderr)
    batch = [json.loads(line) for line in stdout.splitlines() if line.startswith('{')] if scenario == 'S4' else []
    receipt = dict(scenario=scenario, model=model, extent=extent, image=str(image), image_bytes=image.stat().st_size,
                   image_sha256=hash_file(image), binary=str(binary), binary_sha256=hash_file(binary),
                   backend_library_sha256=hash_file(binary_dir / 'libggml-hip.so'),
                   argv=command, source_revision=revision, source_dirty=dirty, host_load=host,
                   gpu_load=gpu, wall_seconds=time.monotonic() - start, exit_code=result.returncode,
                   timing_boundary=timing, result=dict(prompt_tokens_per_s=float(speed.group(1)),
                   generation_tokens_per_s=float(speed.group(2))) if speed else batch if batch else None)
    (destination / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(dict(receipt=str(destination / 'receipt.json'), result=receipt['result'],
                          exit_code=result.returncode)), flush=True)
    if result.returncode:
        print(stderr[-1500:], flush=True)
        raise SystemExit(result.returncode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('models', nargs='+', choices=MODELS)
    parser.add_argument('--bin-dir', type=Path, default=DEFAULT_BIN)
    parser.add_argument('--scenario', choices=['S1', 'S3', 'S4', 'all'], default='all')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    revision = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.check_output(['git', '-C', str(repo), 'status', '--short'], text=True)
    for scenario, extents in [('S1', [0, 4096]), ('S3', [512, 4096]), ('S4', [1, 8, 32, 64, 128])]:
        if args.scenario not in ('all', scenario):
            continue
        for extent in extents:
            for model in args.models:
                run_one(model, scenario, extent, args.bin_dir, revision, dirty)


if __name__ == '__main__':
    main()
