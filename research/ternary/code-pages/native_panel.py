#!/usr/bin/env python3
"""Run and retain a complete-image native code-page/uncoded observation panel."""
import csv
import hashlib
import io
import json
import platform
import shutil
import statistics
import subprocess
from pathlib import Path

DATA = Path('/path/to/workspace/data/kelana-subbit/ternary')
ROOT = Path(__file__).resolve().parent
OUT = DATA / 'fresh-duration32-code-page-16384'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    image = json.loads((OUT / 'receipt.json').read_text())
    raw = DATA / image['scale_image']
    manifest = OUT / 'native-manifest.tsv'
    manifest.write_text(''.join(
        f"{item['name'].replace('.npz', '.tern')} {item['original_code_bytes']} "
        f"{item['code_pages']} {image['page_bytes']}\n" for item in image['matrices']))
    compiler = shutil.which('g++')
    if compiler is None:
        raise RuntimeError('g++ required')
    binary = OUT / 'native-consumer'
    zdev = subprocess.check_output(['nix', 'eval', '--raw', 'nixpkgs#zlib.dev.outPath'], text=True, timeout=15)
    zlib = subprocess.check_output(['nix', 'eval', '--raw', 'nixpkgs#zlib.outPath'], text=True, timeout=15)
    build = [compiler, '-O3', '-std=c++17', '-I' + zdev + '/include', str(ROOT / 'native_consumer.cpp'),
             '-L' + zlib + '/lib', '-Wl,-rpath,' + zlib + '/lib', '-lz', '-o', str(binary)]
    subprocess.run(build, check=True, timeout=35)
    run = subprocess.run([str(binary), str(manifest), str(raw), str(OUT), '8'],
                         text=True, capture_output=True, check=True, timeout=45)
    (OUT / 'native-samples.csv').write_text(run.stdout)
    (OUT / 'native-run.log').write_text(run.stderr)
    samples = list(csv.DictReader(io.StringIO(run.stdout)))
    panels = {}
    for label in ('complete-stream', 'shuffled-first'):
        pairs = {}
        for item in samples:
            if item['panel'] == label:
                pairs.setdefault(int(item['repetition']), {})[item['arm']] = item
        assert len(pairs) == 8 and all(set(v) == {'raw', 'paged'} for v in pairs.values())
        assert len({v['raw']['crc32'] for v in pairs.values()} | {v['paged']['crc32'] for v in pairs.values()}) == 1
        panels[label] = {
            'crc32': next(iter(pairs.values()))['raw']['crc32'],
            'raw_median_ms': statistics.median(float(v['raw']['milliseconds']) for v in pairs.values()),
            'paged_median_ms': statistics.median(float(v['paged']['milliseconds']) for v in pairs.values()),
            'paired_excess_median_ms': statistics.median(float(v['paged']['milliseconds']) - float(v['raw']['milliseconds']) for v in pairs.values()),
        }
    receipt = dict(contract='Host-RAM preloaded complete paid Qwen3-0.6B image; native C++ zlib uncompress followed by equal CRC32 observations; shuffled first-byte page access or ordered full code stream. No disk I/O, GPU inference, radix-243 arithmetic, scales or language evaluation inside timed region.',
                   source_sha256=sha(ROOT / 'native_consumer.cpp'), runner_sha256=sha(Path(__file__)),
                   image_receipt_sha256=sha(OUT / 'receipt.json'), manifest_sha256=sha(manifest),
                   binary_sha256=sha(binary), samples_sha256=sha(OUT / 'native-samples.csv'),
                   compiler=subprocess.check_output([compiler, '--version'], text=True).splitlines()[0],
                   host=platform.uname()._asdict(), build=build,
                   images={'raw_bytes': image['original_paid_bytes'], 'paged_bytes': image['paid_payload_bytes'],
                           'raw_code_bytes': image['original_code_bytes'], 'pages': image['code_pages'],
                           'paid_bpw': image['paid_bpw'], 'unchanged_held_nll': 4.498337}, panels=panels)
    (OUT / 'native-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(panels, indent=2))


if __name__ == '__main__':
    main()
