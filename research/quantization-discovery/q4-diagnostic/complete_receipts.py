#!/usr/bin/env python3
"""Reconcile first native measurement receipts with the installed HIP library hash."""
import json
from pathlib import Path
from shootout import ROOT, RUNNER, hash_file

library = RUNNER / 'native-bin/libggml-hip.so'
backend_hash = hash_file(library)
root = ROOT / 'receipts/kelana-06b/M3'
for path in root.rglob('receipt.json'):
    receipt = json.loads(path.read_text())
    if 'backend_library_sha256' not in receipt:
        receipt['backend_library_sha256'] = backend_hash
        path.write_text(json.dumps(receipt, indent=2) + '\n')
        print(path)
