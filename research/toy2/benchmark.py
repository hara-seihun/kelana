#!/usr/bin/env python3
"""Build, inspect and measure the exact 2x2 HIP maps on gfx1151."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent


def command(args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=45)
    if result.returncode:
        raise RuntimeError(f"Command returned {result.returncode}: {args}\n{result.stderr}\n{result.stdout}")
    return result.stdout


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now():
    return datetime.now(timezone.utc).isoformat()


def services():
    return {unit: subprocess.run(['systemctl', '--user', 'is-active', unit],
                                text=True, capture_output=True, timeout=3).stdout.strip()
            for unit in ['everythinglive-voice.service', 'bonsai-halo.service']}


def bonsai_activity(start, end):
    lines = command(['journalctl', '--user', '-u', 'bonsai-halo.service',
                     '--since', start, '--until', end, '-o', 'json', '--no-pager'])
    messages = [json.loads(line)['MESSAGE'] for line in lines.splitlines()]
    return {'request_starts': sum(bool(re.search(r'\[\d+\] prompt ', m)) for m in messages),
            'request_completions': sum(bool(re.search(r'\[\d+\] stop:', m)) for m in messages),
            'journal_entries': len(messages)}


def inspect(disassembly, metadata):
    kernels = {}
    current = None
    for line in disassembly.splitlines():
        match = re.match(r'^[0-9a-f]+ <(.+)>:$', line)
        if match:
            current = match[1]
            kernels[current] = Counter()
        elif current and (op := re.match(r'\s+([sv]_[a-z0-9_]+)\s', line)):
            kernels[current][op[1]] += 1
    assert len(kernels) == 4, kernels.keys()
    for name, counts in kernels.items():
        factor = 8 if 'resident<' in name else 1
        fused = '<true>' in name
        assert counts['v_dot8_i32_iu4'] == factor * (2 if fused else 4), (name, counts)
        assert counts['v_mad_u32_u24'] == factor * (0 if fused else 2), (name, counts)
        assert counts['v_lshl_or_b32'] == factor, (name, counts)
    resources = []
    for block in metadata.split('  - .args:')[1:]:
        fields = dict(re.findall(r'^\s+\.(name|vgpr_count|sgpr_count|vgpr_spill_count|sgpr_spill_count|private_segment_fixed_size|wavefront_size):\s+(\S+)', block, re.M))
        assert fields['vgpr_spill_count'] == '0' and fields['sgpr_spill_count'] == '0', fields
        assert fields['private_segment_fixed_size'] == '0', fields
        resources.append(fields)
    assert len(resources) == 4
    return {'opcode_counts': kernels, 'resources': resources}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=HERE/'benchmark-results.json')
    parser.add_argument('--seeds', type=int, nargs='+', default=[20260919, 20260920, 20260921])
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    receipt = {'started_at': now(), 'source_sha256': {
        name: sha(HERE/name) for name in ['benchmark.cpp', 'toy2.hpp', 'benchmark.py']},
        'compiler': command(['hipcc', '--version']).strip(),
        'compile_flags': ['-O3', '-std=c++17', '--offload-arch=gfx1151'],
        'budget_mib': {'host_including_gtt': 1024, 'gtt': 256},
        'services_before': services(), 'runs': []}
    try:
        with tempfile.TemporaryDirectory(prefix='kelana-hip-') as tmp:
            tmp = Path(tmp)
            binary, bundle, obj = tmp/'benchmark', tmp/'kernels.bundle', tmp/'kernels.o'
            command(['hipcc', *receipt['compile_flags'], str(HERE/'benchmark.cpp'), '-o', str(binary)])
            # ROCm 7.2 embeds a compressed bundle, not a directly disassemblable ELF.
            command(['llvm-objcopy', '--dump-section', f'.hip_fatbin={bundle}', str(binary)])
            command(['clang-offload-bundler', '--unbundle', '--type=o',
                     '--targets=hipv4-amdgcn-amd-amdhsa--gfx1151', f'--input={bundle}', f'--output={obj}'])
            disassembly = command(['llvm-objdump', '-d', '--demangle', str(obj)])
            metadata = command(['llvm-readelf', '--notes', str(obj)])
            receipt['binary_sha256'] = sha(binary)
            receipt['gpu_object_sha256'] = sha(obj)
            receipt['compiled_kernels'] = inspect(disassembly, metadata)
            for suffix, text in [('disassembly', disassembly), ('metadata', metadata)]:
                path = args.output.with_name(args.output.stem + '-' + suffix + '.txt')
                path.write_text(text.replace(str(obj), 'kernels.o'))
                receipt[suffix] = {'file': path.name, 'sha256': sha(path)}
            for seed in args.seeds:
                start = now()
                result = json.loads(command(['gpu-run', '--host-mib', '1024', '--gtt-mib', '256', str(binary), str(seed)]))
                end = now()
                result.update({'started_at': start, 'finished_at': end,
                               'bonsai_activity': bonsai_activity(start, end)})
                receipt['runs'].append(result)
                print(f"seed {seed}: " + ', '.join(
                    f"{r['mode']} {r['median_paired_speedup']:.3f}x" for r in result['results']), flush=True)
        receipt['status'] = 'complete'
    except (RuntimeError, AssertionError, subprocess.TimeoutExpired, ValueError) as error:
        receipt['status'] = 'failed'
        receipt['error'] = str(error)
    receipt['services_after'] = services()
    receipt['finished_at'] = now()
    staged = args.output.with_suffix('.tmp')
    staged.write_text(json.dumps(receipt, indent=2) + '\n')
    staged.replace(args.output)
    print(args.output)
    if receipt['status'] != 'complete':
        raise SystemExit(receipt['error'])


if __name__ == '__main__':
    main()
