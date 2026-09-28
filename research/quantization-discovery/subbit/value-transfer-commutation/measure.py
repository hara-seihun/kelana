#!/usr/bin/env python3
"""Price eliminating missing-head V dots by substituting its GQA partner's attention."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
SUB = HERE.parent
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention
from refine import features

PARENT = Path('/path/to/workspace/data/kelana-subbit/value-column-skeleton')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')
DATA = Path('/path/to/workspace/data/kelana-subbit/value-transfer-commutation')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def err(y, target):
    return float((y - target).square().sum() / target.square().sum())


def main(layer):
    torch.set_num_threads(8)
    parent_path = PARENT / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    image_path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(image_path) as packed:
        images = [{k: packed[k][g].copy() for k in packed.files} for g in range(8)]
    a = torch.cat([torch.cat([decoder.decode(image, 'left')[h*1024:(h+1)*1024]
                              for h in range(2)], dim=1) for image in images], dim=1).contiguous()
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    x = load_capture(layer, 'validation').reshape(4, 256, 1024)
    p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    z = features(x, p, images, decoder, 28)
    teacher = dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
    entries = {}
    for keep in (8, 10, 12, 14):
        info = parent['results'][str(keep)]
        retained = info['retained_head_groups']
        missing = info['missing_head_groups']
        kidx = [g*28+j for g in retained for j in range(28)]
        midx = [g*28+j for g in missing for j in range(28)]
        c = a[:, kidx].double()
        transfer = torch.linalg.lstsq(c, a[:, midx].double()).solution.T.float().contiguous()
        image = decoder.quantize(transfer, 2, 28, 't')
        paid_transfer = decoder.decode(image, 't')
        zretain = z[:, kidx]
        zmissing = z[:, midx]
        proxy = zmissing.clone()
        paired = []
        for i, g in enumerate(missing):
            partner = g ^ 1
            if partner in retained:
                proxy[:, i*28:(i+1)*28] = z[:, partner*28:(partner+1)*28]
                paired.append(g)
        baseline = (zretain + zmissing @ paid_transfer) @ c.float().T
        shortcut = (zretain + proxy @ paid_transfer) @ c.float().T
        response = z @ a.T
        entries[str(keep)] = {
            'retained': retained, 'missing': missing, 'paired_missing': paired,
            'removed_28_coordinate_head_value_dots': len(paired),
            'remaining_head_value_dots': 16-len(paired),
            'teacher_error_original_paid': err(response, teacher),
            'teacher_error_preserved_transfer': err(baseline, teacher),
            'teacher_error_paired_attention': err(shortcut, teacher),
            'relative_shortcut_delta_to_teacher': float((shortcut-baseline).square().sum() / teacher.square().sum()),
            'relative_shortcut_delta_to_preserved': err(shortcut, baseline),
            'per_window_teacher_error': {
                name: [err(y.reshape(4, 256, 1024)[i], teacher.reshape(4, 256, 1024)[i])
                       for i in range(4)]
                for name, y in [('preserved', baseline), ('paired', shortcut)]},
        }
    result = {'layer': layer, 'source_sha256': sha(Path(__file__)),
              'parent_sha256': sha(parent_path), 'model_sha256': sha(MODEL),
              'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
              'paid_image_sha256': sha(image_path), 'decoder_sha256': sha(SOURCE),
              'observation': 'four 256-token original-producer validation windows, complete two-head post-O teacher; packed two-bit paid-response transfer; replace a missing head attended coordinate only if its GQA partner is retained',
              'entries': entries}
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA / f'layer{layer:02d}.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'path': str(path), 'entries': {k: {
        name: value for name, value in v.items() if name in (
            'paired_missing', 'teacher_error_preserved_transfer',
            'teacher_error_paired_attention', 'relative_shortcut_delta_to_preserved')}
        for k, v in entries.items()}}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    main(parser.parse_args().layer)
