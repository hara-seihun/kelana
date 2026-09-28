#!/usr/bin/env python3
"""Compile and run the native exact packed-consumer panel on the committed fixture."""
import hashlib
import json
from datetime import datetime, timezone
import os
from pathlib import Path
import platform
import subprocess
import tempfile
import time
import numpy as np

HERE = Path(__file__).resolve().parent


def run(command):
    return subprocess.run(command, check=True, capture_output=True, text=True, timeout=45).stdout


def fnv64(values):
    h = 14695981039346656037
    for byte in np.asarray(values, dtype='<i8').tobytes():
        h = ((h ^ byte)*1099511628211) & ((1 << 64)-1)
    return h


def check_native(native, reference):
    expected = [fnv64(row) for row in reference]
    for method in native['methods']:
        assert method['exact_match_all_queries'], method['name']
        observed = [int(value, 16) for value in method['output']['per_query']]
        assert observed == expected, method['name']
    return expected


def choose_cpu():
    allowed = sorted(os.sched_getaffinity(0))
    if 'KELANA_BENCH_CPU' in os.environ:
        cpu = int(os.environ['KELANA_BENCH_CPU'])
        assert cpu in allowed
        return cpu, {'selection': 'explicit environment'}
    def snapshot():
        counters = {}
        for line in Path('/proc/stat').read_text().splitlines():
            fields = line.split()
            if fields[0].startswith('cpu') and fields[0] != 'cpu':
                values = list(map(int, fields[1:]))
                counters[int(fields[0][3:])] = (sum(values[:8]), values[3]+values[4])
        return counters
    before = snapshot()
    time.sleep(0.1)
    after = snapshot()
    busy = {}
    for cpu in allowed:
        total = after[cpu][0]-before[cpu][0]
        idle = after[cpu][1]-before[cpu][1]
        busy[cpu] = 1-idle/total if total else 0
    scores = {}
    for cpu in allowed:
        text = Path(f'/sys/devices/system/cpu/cpu{cpu}/topology/thread_siblings_list').read_text().strip()
        siblings = []
        for part in text.split(','):
            limits = part.split('-')
            siblings.extend(range(int(limits[0]), int(limits[-1])+1))
        scores[cpu] = sum(busy.get(sibling, 1) for sibling in siblings)
    cpu = min(allowed, key=lambda c: (scores[c], c))
    return cpu, {'selection': 'least-busy allowed SMT sibling group over100ms', 'sibling_busy_sum': scores}


def main():
    started = time.monotonic()
    cpu, cpu_selection = choose_cpu()
    os.sched_setaffinity(0, {cpu})
    fixture_path = HERE/'instances/bonsai-layer00-down-block0.npz'
    fixture = np.load(fixture_path)
    weights = fixture['trits']
    captured = fixture['queries']
    # Extreme, zero and sparse inputs exercise the full exact integer contract.
    controls = np.stack([np.zeros(128, dtype=np.int8), np.full(128, 127, dtype=np.int8),
                         np.full(128, -127, dtype=np.int8),
                         np.array([127 if i % 2 else -127 for i in range(128)], dtype=np.int8)])
    queries = np.concatenate([captured, controls])
    reference = queries.astype(np.int64) @ weights.astype(np.int64).T
    compiler = os.environ.get('CXX', 'g++')
    flags = ['-O3', '-march=native', '-DNDEBUG', '-std=c++20', '-Wall', '-Wextra', '-Wpedantic']
    with tempfile.TemporaryDirectory(prefix='kelana-direct-') as temporary:
        directory = Path(temporary)
        wfile, qfile, binary = (directory/n for n in ('weights.i8', 'queries.i8', 'direct_consumer'))
        wfile.write_bytes(weights.tobytes())
        qfile.write_bytes(queries.tobytes())
        run([compiler, *flags, str(HERE/'direct_consumer.cpp'), '-o', str(binary)])
        output = run([str(binary), str(wfile), str(qfile), str(weights.shape[0]),
                      str(weights.shape[1]), str(queries.shape[0]), '17'])
        native = json.loads(output)
        expected = check_native(native, reference)
        edge_checks = []
        for rows, columns in ((1, 1), (31, 2), (33, 3), (127, 4), (129, 127), (33, 255)):
            w = ((np.arange(rows*columns).reshape(rows, columns) % 3)-1).astype(np.int8)
            w[0, :] = -1
            x = np.stack([np.full(columns, -128, dtype=np.int8),
                          (np.arange(columns) % 256-128).astype(np.int8)])
            wfile.write_bytes(w.tobytes())
            qfile.write_bytes(x.tobytes())
            panel = json.loads(run([str(binary), str(wfile), str(qfile), str(rows), str(columns), '2', '1']))
            check_native(panel, x.astype(np.int64) @ w.astype(np.int64).T)
            edge_checks.append(dict(rows=rows, columns=columns, methods=len(panel['methods']), exact=True))
    methods = native['methods']
    result = dict(scope='Single-core native CPU integer block on all5120 output rows. No GPU or full-model throughput claim.',
                  timestamp_utc=datetime.now(timezone.utc).isoformat(), host_loadavg=Path('/proc/loadavg').read_text().strip(),
                  fixture_sha256=hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
                  sources_sha256={name: hashlib.sha256((HERE/name).read_bytes()).hexdigest()
                                  for name in ('direct_consumer.cpp', 'simd_consumer.hpp', 'direct_experiments.py', 'direct_plan.py')},
                  compiler=run([compiler, '--version']).splitlines()[0], compiler_flags=flags,
                  platform=platform.platform(), affinity_cpu=cpu, cpu_selection=cpu_selection, edge_checks=edge_checks,
                  cpu_model=next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
                                  if line.startswith('model name')), 'unknown'),
                  query_contract=dict(captured=8, controls=4, dimension=128, signed_range=[-127, 127]),
                  source_halo_block_bytes=143360, unchanged_fp16_scale_bytes=int(weights.shape[0]*2),
                  independent_output_fnv64=expected,
                  native=native, elapsed_seconds=time.monotonic()-started)
    (HERE/'direct-results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(dict(schema=native['schema'], methods=len(methods),
                         exact_queries=len(expected), elapsed_seconds=result['elapsed_seconds']), indent=2))


if __name__ == '__main__':
    main()
