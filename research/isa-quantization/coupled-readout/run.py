#!/usr/bin/env python3
"""Run the exact coupled-search oracle, independent codecs and isolated timings."""
import hashlib
import json
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent


def signature(teacher):
    return sorted((p['bytes'], p['work'], p['loss']) for p in teacher['arms'][0]['frontier'])


def main():
    with tempfile.TemporaryDirectory(prefix='kelana-coupled-') as temporary:
        temp = Path(temporary)
        binary = temp / 'search'
        test = temp / 'ising-test'
        for src, output in [('search.cpp', binary), ('ising_test.cpp', test)]:
            subprocess.run(['c++', '-O3', '-std=c++20', str(HERE/src), '-o', str(output)], check=True, timeout=45)
        receipt = subprocess.check_output([str(test)], text=True, timeout=45)
        (HERE/'ising-receipt.txt').write_text(receipt)
        subprocess.run([str(binary), str(HERE/'results.json'), str(HERE/'structures.json')], check=True, timeout=45)
        subprocess.run(['python3', str(HERE/'replay.py')], check=True, timeout=45)
        oracle = json.loads((HERE/'results.json').read_text())
        arms = []
        for arm in range(6):
            samples = []
            for _ in range(3):
                subprocess.run([str(binary), str(temp/'result.json'), str(temp/'detail.json'), str(arm)], check=True, timeout=45)
                result = json.loads((temp/'result.json').read_text())
                for a, b in zip(result['teachers'], oracle['teachers'], strict=True):
                    assert a['target'] == b['target'] and signature(a) == signature(b)
                samples.append({'elapsed_ms': result['elapsed_ms'],
                                'search_ms': sum(t['arms'][0]['ms'] for t in result['teachers']),
                                'peak_rss_kib': result['peak_rss_kib']})
            arms.append({'arm': arm, 'samples': samples,
                         'median': {k: statistics.median(s[k] for s in samples) for k in samples[0]}})
        result = {'compiler': subprocess.check_output(['c++', '--version'], text=True).splitlines()[0],
                  'platform': platform.platform(),
                  'source_sha256': {name: hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in ['search.cpp','ising.hpp']},
                  'method': 'Three foreground isolated single-threaded processes per arm; all control fitting included; independent diagnostics outside timed arms; VmHWM executable peak RSS.',
                  'arms': arms}
        (HERE/'timings.json').write_text(json.dumps(result, indent=2)+'\n')
        for arm in arms:
            print(arm['arm'], arm['median'])


if __name__ == '__main__':
    main()
