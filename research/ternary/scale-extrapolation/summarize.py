#!/usr/bin/env python3
"""Aggregate frozen panel receipts without running inference."""
import hashlib
import json
from pathlib import Path
import numpy as np

ROOT=Path('/path/to/workspace/data/kelana-subbit/ternary')
OUT=ROOT/'scale-extrapolation'

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()

def scores(name,offsets):
    parts=[OUT/f'{name}-{o}-8.json' for o in offsets]
    rec=[json.loads(p.read_text()) for p in parts]
    assert len({r['fixture_sha256'] for r in rec})==1
    return np.array([x for r in rec for x in r['per_window_nll']]), {p.name:sha(p) for p in parts}

def main():
    control,base_files=scores('expanded-scale384',(0,8))
    selected,selected_files=scores('scale-extrapolate-1.5',(0,8))
    screened,screen_files=scores('scale-extrapolate-2',(0,))
    d=selected-control
    page=OUT/'page-1.5/receipt.json'
    page_rec=json.loads(page.read_text())
    assert page_rec['source_manifest_sha256']==sha(ROOT/'scale-extrapolate-1.5/manifest.json')
    receipt=dict(source_sha256=sha(Path(__file__)),fixture_sha256=sha(OUT/'tokens.npz'),fixture_manifest_sha256=sha(OUT/'tokens.json'),builder_sha256=sha(Path(__file__).with_name('build.py')),evaluator_sha256=sha(Path(__file__).with_name('evaluate.py')),page_codec_sha256=sha(Path(__file__).resolve().parents[1]/'exact-rate/measure.py'),python_executable_sha256=sha(Path('/path/to/workspace/data/fish-s2-pro/venv/bin/python').resolve()),quality_receipts={**base_files,**selected_files,**screen_files},page_receipt_sha256=sha(page),control_nll=float(control.mean()),selected_nll=float(selected.mean()),paired_improvement_nats=float(-d.mean()),paired_se_nats=float(d.std(ddof=1)/np.sqrt(len(d))),held_offset8_improvement_nats=float(np.mean(control[8:]-selected[8:])),selection_offset0=dict(control=float(control[:8].mean()),selected=float(selected[:8].mean()),screened_double=float(screened.mean())),wins=int(np.sum(d<0)),windows=len(d),predictions=255*len(d),paid_page_bytes=page_rec['paid_payload_bytes'],paid_page_bpw=page_rec['paid_bpw'],paid_raw_bytes=page_rec['original_payload_bytes'],raw_per_window_delta=d.tolist())
    (OUT/'summary.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))

if __name__=='__main__':main()
