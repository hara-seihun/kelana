#!/usr/bin/env python3
"""Store the train-selected down gain in the existing FP16 row-scale slots."""
import json
from pathlib import Path

import numpy as np

from mlp_factor_response import ROOT, digest

BASE = ROOT / 'mlp-quantized-scale-2048-image'
CHOICE = ROOT / 'mlp-gold-down-gain.json'
OUTPUT = ROOT / 'mlp-gold-down-image'


def main():
    choice = json.loads(CHOICE.read_text())
    gain = float(choice['selected_gain'])
    OUTPUT.mkdir(exist_ok=True)
    inputs, outputs = {}, {}
    before = after = 0
    for part in ('gate', 'up', 'down'):
        name = f'layer00-mlp_{part}_proj.npz'
        source = BASE / name
        with np.load(source) as f:
            payload = {key: f[key].copy() for key in f.files}
        inputs[str(source)] = digest(source)
        before += sum(v.nbytes for v in payload.values())
        if part == 'down':
            payload['scale_post'] = (payload['scale_post'].astype(np.float32) * gain).astype(np.float16)
            assert np.isfinite(payload['scale_post']).all()
        after += sum(v.nbytes for v in payload.values())
        path = OUTPUT / name
        np.savez_compressed(path, **payload)
        outputs[str(path)] = digest(path)
    assert before == after
    result = {'format': 'paid-layer0-mlp-down-gold-image/1', 'source_sha256': digest(Path(__file__)),
        'choice_sha256': digest(CHOICE), 'inputs_sha256': inputs, 'outputs_sha256': outputs,
        'gain': gain, 'payload_bytes_before': before, 'payload_bytes_after': after,
        'online_factor_terms_delta': 0, 'observation': 'Three self-contained packed binary MLP factors; only the already-paid FP16 down output scales change. The BF16-expanded loss evaluation uses the same scale-rounding rule.'}
    receipt = ROOT / 'mlp-gold-down-image.json'
    receipt.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
