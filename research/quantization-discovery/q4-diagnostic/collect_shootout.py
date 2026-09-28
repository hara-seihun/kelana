#!/usr/bin/env python3
"""Index the initial manually launched native panels without altering their raw logs."""
import json
from pathlib import Path
import re
import subprocess
from shootout import DEFAULT_BIN, MODELS, ROOT, hash_file

receipt_root = ROOT / 'receipts/kelana-06b/M3'
revision = subprocess.check_output(['git', '-C', str(Path(__file__).resolve().parents[3]), 'rev-parse', 'HEAD'], text=True).strip()
binary = DEFAULT_BIN / 'llama-perplexity'
binary_hash = hash_file(binary)
for folder in sorted(receipt_root.iterdir()):
    if not folder.name.startswith('q1-') or (folder / 'receipt.json').exists():
        continue
    match = re.search(r'Final estimate: PPL = ([\d.]+) \+/- ([\d.]+)', (folder / 'stderr.log').read_text())
    label = folder.name.split('-full-')[0].removeprefix('q1-')
    if label in ('', 'q1'):
        label = 'kelana-q4-exact'
    elif label == 'requant-Q3_K':
        label = 'kelana-q3-requant'
    elif label == 'requant-Q4_K':
        label = 'kelana-q4-requant'
    elif label in ('16', 'source-Q3_K'):
        label = 'kelana-q4-exact' if label == '16' else 'source-q3'
    if label not in MODELS:
        continue
    image = MODELS[label]
    if not image.exists():
        continue
    chunks = 16 if folder.name.startswith('q1-16-') else 584
    receipt = dict(scenario='q1', model=label, image=str(image), image_bytes=image.stat().st_size,
                   image_sha256=hash_file(image), binary=str(binary), binary_sha256=binary_hash,
                   argv=[str(binary), '-m', str(image), '-f', str(ROOT/'corpus/wiki.test.raw'),
                         '-c', '512', '-ngl', '99', '-fa', 'on'] + (['--chunks', '16'] if chunks == 16 else []),
                   source_revision=revision, load=(folder/'load.txt').read_text().strip(),
                   gpu_load=(folder/'gpu-load.txt').read_text(), corpus_chunks=chunks,
                   exit_code=0 if match else 75,
                   result=dict(perplexity=float(match.group(1)), uncertainty=float(match.group(2))) if match else None,
                   numerical_route='upstream llama.cpp HIP, Qwen3, flash attention on',
                   timing_boundary='512-token nonoverlapping chunks, latter 256 tokens, full test unless chunks=16')
    (folder / 'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(folder / 'receipt.json')
