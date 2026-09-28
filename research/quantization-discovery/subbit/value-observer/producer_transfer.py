#!/usr/bin/env python3
"""Capture layer-14 inputs after quantized upstream body and price frozen narrow V/O maps."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'full-model'))
from capture import ROOT, MODEL, TOKENS, sha
from image import binary_weight

OUT = ROOT / 'value-observer'
IMAGE = ROOT / 'full-model/image-binary055-refined'


def capture():
    from transformers import AutoModelForCausalLM
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True, dtype=torch.bfloat16,
                                               attn_implementation='sdpa').eval().to('cuda')
    manifest = json.loads((IMAGE / 'manifest.json').read_text())
    applied = []
    with torch.no_grad():
        for entry in manifest['body']:
            if int(entry['key'].split('.')[2]) >= 14:
                continue
            path = IMAGE / entry['path']
            if sha(path) != entry['sha256']:
                raise ValueError(f'image changed: {path}')
            model.get_parameter(entry['key']).copy_(binary_weight(path))
            applied.append(entry['sha256'])
        with np.load(IMAGE / manifest['norms']['path']) as data:
            if sha(IMAGE / manifest['norms']['path']) != manifest['norms']['sha256']:
                raise ValueError('norms changed')
            for name in data.files:
                if name == 'model.norm.weight' or int(name.split('.')[2]) >= 14:
                    continue
                bits = torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16)
                model.get_parameter(name).copy_(bits)
    windows = {}
    def hook(module, values):
        value = values[0].detach().reshape(-1, 1024)
        windows[current].append(value.view(torch.int16).cpu().numpy().view(np.uint16).copy())
    handle = model.model.layers[14].self_attn.q_proj.register_forward_pre_hook(hook)
    with np.load(TOKENS) as f:
        tokens = {s: f[s][:4].copy() for s in ('train', 'validation')}
    with torch.inference_mode():
        for current, batch in tokens.items():
            windows[current] = []
            for row in batch:
                model.model(torch.as_tensor(row, device='cuda', dtype=torch.long)[None], use_cache=False)
            print(json.dumps({'split': current, 'windows': len(windows[current])}), flush=True)
    handle.remove()
    path = OUT / 'layer14-quantized-upstream.npz'
    np.savez(path, **{s: np.stack(rows) for s, rows in windows.items()})
    receipt = {'capture': str(path), 'capture_sha256': sha(path), 'source_sha256': sha(Path(__file__)),
               'model_source_sha256': sha(MODEL / 'source.json'), 'tokens_sha256': sha(TOKENS),
               'image_manifest_sha256': sha(IMAGE / 'manifest.json'), 'upstream_body_images': applied,
               'upstream_norms_sha256': manifest['norms']['sha256'],
               'contract': 'first four train and validation windows, preceding layers 0..13 body and norms quantized, original tied embedding and layer 14; layer-14 q_proj BF16 input bits'}
    (OUT / 'layer14-quantized-upstream-capture.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'capture': str(path), 'sha256': receipt['capture_sha256']}), flush=True)


def score():
    sys.path.insert(0, str(HERE))
    from causal_refit import load_image, response_features
    from refine import unpack_codes
    from measure import probabilities, dense_attention, error
    from fit_direct import SOURCE
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('pinned_spectral_quant', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    from fit import MODEL as WEIGHTS
    with safe_open(WEIGHTS, framework='pt', device='cpu') as model:
        w = {n: model.get_tensor(f'model.layers.14.self_attn.{n}.weight').float()
             for n in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    images = {arm: OUT / f'layer14-{filename}.npz' for arm, filename in {
        'selected192': 'causal-refit-train_causal_optimum',
        'uniform192': 'causal-refit-uniform_24', 'full224': 'joint-r28'}.items()}
    decoded = {}
    for arm, path in images.items():
        if arm == 'full224':
            with np.load(path) as image:
                groups = [{key: image[key][g].copy() for key in image.files} for g in range(8)]
        else:
            groups = load_image(path)
        left = torch.cat([q.decode(groups[h//2], 'left')[(h%2)*1024:(h%2+1)*1024] for h in range(16)], dim=1)
        decoded[arm] = (groups, left)
    results = {'contract': 'original layer-14 Q/K/V/O on the same upstream-produced x; frozen BF16-rounded narrow values and paid left codes; post-O FP32 relative squared error; no output-head or native timing',
               'capture_sha256': sha(OUT / 'layer14-quantized-upstream.npz'),
               'source_sha256': sha(Path(__file__)), 'model_sha256': sha(WEIGHTS),
               'images_sha256': {arm: sha(path) for arm, path in images.items()}, 'splits': {}}
    train_features = {}
    train_targets = None
    held_features = {}
    held_targets = None
    with np.load(OUT / 'layer14-quantized-upstream.npz') as data:
        for split in ('train', 'validation'):
            bits = data[split].copy()
            x = torch.from_numpy(bits.view(np.int16)).view(torch.bfloat16).float()
            prob = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
            teacher = dense_attention(prob, x, w['v_proj'], w['o_proj'])
            per_arm = {}
            for arm, (groups, left) in decoded.items():
                features = response_features(x, prob, groups, q)
                output = (features @ left.T).reshape_as(teacher)
                per_arm[arm] = {'aggregate': error(output, teacher),
                                'per_window': [error(output[i], teacher[i]) for i in range(len(x))]}
                if arm != 'full224':
                    (train_features if split == 'train' else held_features)[arm] = features.reshape(-1, features.shape[-1])
            if split == 'train':
                train_targets = teacher.reshape(-1, 1024)
            else:
                held_targets = teacher.reshape(-1, 1024)
            results['splits'][split] = per_arm
            print(json.dumps({'split': split, 'errors': {arm: item['aggregate'] for arm, item in per_arm.items()}}), flush=True)
    for arm in ('selected192', 'uniform192'):
        groups, _ = decoded[arm]
        ranks = [int(group['right_shape'][0]) for group in groups]
        starts = np.cumsum([0] + [rank for rank in ranks for _ in range(2)]).tolist()
        codes = torch.cat([unpack_codes(groups[h//2]['left_codes'], 2048, ranks[h//2], 2)
                           [(h%2)*1024:(h%2+1)*1024] for h in range(16)], dim=1)
        scales = torch.stack([torch.from_numpy(groups[h//2]['left_scales']
                            [(h%2)*1024:(h%2+1)*1024, 0].copy()).float() for h in range(16)], dim=1)
        coeff = torch.cat([(2*codes[:, starts[h]:starts[h+1]]-3)*scales[:, h, None]
                           for h in range(16)], dim=1)
        z, y = train_features[arm], train_targets
        gram = z.T @ z / len(z)
        target = y.T @ z / len(z)
        for _ in range(2):
            current = coeff @ gram
            for d in range(starts[-1]):
                h = int(np.searchsorted(starts, d, side='right')-1)
                optimum = (target[:, d]-current[:, d]+coeff[:, d]*gram[d, d])/gram[d, d].clamp_min(1e-20)
                new_code = ((optimum/scales[:, h].clamp_min(1e-20)+3)/2).round().clamp(0, 3)
                updated = (2*new_code-3)*scales[:, h]
                delta = updated-coeff[:, d]
                codes[:, d] = new_code
                coeff[:, d] = updated
                current += delta[:, None]*gram[d][None, :]
            prediction = z @ coeff.T
            for h in range(16):
                a, b = starts[h:h+2]
                old = z[:, a:b] @ coeff[:, a:b].T
                raw = z[:, a:b] @ (2*codes[:, a:b]-3).T
                fitted = (((y-prediction+old)*raw).sum(0)/raw.square().sum(0).clamp_min(1e-20)).clamp_min(0)
                scales[:, h] = fitted.half().float()
                coeff[:, a:b] = (2*codes[:, a:b]-3)*scales[:, h, None]
                prediction += raw*scales[:, h][None, :]-old
        output_image = {}
        for g, group in enumerate(groups):
            packed = dict(group)
            packed['left_codes'] = q.pack_codes(torch.cat([codes[:, starts[h]:starts[h+1]]
                                for h in (2*g, 2*g+1)]).to(torch.uint8).numpy(), 2)
            packed['left_scales'] = torch.cat([scales[:, 2*g], scales[:, 2*g+1]]).numpy().astype(np.float16)[:, None]
            output_image.update({f'group{g}_{key}': value for key, value in packed.items()})
        image_path = OUT / f'layer14-quantized-upstream-{arm}.npz'
        np.savez(image_path, **output_image)
        assert sum(value.nbytes for value in output_image.values()) == 183552
        restored = load_image(image_path)
        restored_coeff = torch.cat([q.decode(restored[h//2], 'left')
                 [(h%2)*1024:(h%2+1)*1024] for h in range(16)], dim=1)
        assert torch.equal(restored_coeff, coeff)
        held_output = held_features[arm] @ coeff.T
        held = held_output.reshape(4, 256, 1024)
        reference = held_targets.reshape_as(held)
        results['splits']['validation'][arm]['quantized_producer_refit'] = {
            'aggregate': error(held_output, held_targets),
            'per_window': [error(held[i], reference[i]) for i in range(4)]}
        results['splits']['train'][arm]['quantized_producer_refit'] = {
            'aggregate': error(z @ coeff.T, y)}
        results['images_sha256'][arm+'_producer_refit'] = sha(image_path)
        print(json.dumps({'arm': arm, 'refit_train': results['splits']['train'][arm]['quantized_producer_refit'],
                          'refit_validation': results['splits']['validation'][arm]['quantized_producer_refit']}), flush=True)
    path = OUT / 'layer14-quantized-upstream-transfer.json'
    path.write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps({'receipt': str(path)}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('capture', 'score'))
    args = parser.parse_args()
    globals()[args.action]()
