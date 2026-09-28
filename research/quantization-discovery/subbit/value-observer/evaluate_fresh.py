#!/usr/bin/env python3
"""Frozen, equal-rate narrow V/O substitutions on disjoint fresh WikiText windows."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from evaluate_model import ROOT, MODEL, JOINT, QUANTIZER, sha, scores, narrow_weights

FIXTURE = ROOT / 'fresh-evaluation'
ARMS = ('uniform_24', 'train_causal_optimum')


def pruned_weights(path, decode):
    with np.load(path) as image:
        paid = sum(image[key].nbytes for key in image.files)
        assert paid == 183552
        v = torch.zeros(1024, 1024, dtype=torch.bfloat16, device='cuda')
        o = torch.zeros(1024, 2048, dtype=torch.bfloat16, device='cuda')
        for group in range(8):
            arrays = {key: image[f'group{group}_{key}'].copy()
                      for key in ('left_shape', 'left_codes', 'left_scales',
                                  'right_shape', 'right_codes', 'right_scales')}
            rank = int(arrays['right_shape'][0])
            assert 0 < rank <= 28 and tuple(arrays['right_shape']) == (rank, 1024, 2, 128)
            assert tuple(arrays['left_shape']) == (2048, rank, 2, 128)
            v[group*128:group*128+rank] = decode(arrays, 'right').to(device='cuda', dtype=torch.bfloat16)
            left = decode(arrays, 'left').to(device='cuda', dtype=torch.bfloat16)
            for local in range(2):
                head = 2*group + local
                o[:, head*128:head*128+rank] = left[local*1024:(local+1)*1024]
    return v, o, paid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--split', choices=('validation', 'test'), required=True)
    parser.add_argument('--start', type=int, required=True)
    parser.add_argument('--count', type=int, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    fixture_manifest = FIXTURE / 'manifest.json'
    fixture_tokens = FIXTURE / 'tokens.npz'
    manifest = json.loads(fixture_manifest.read_text())
    assert sha(fixture_tokens) == manifest['tokens_sha256']
    key = f'{args.split}_256'
    with np.load(fixture_tokens) as fixture:
        whole = fixture[key]
        assert 0 <= args.start and args.count > 0 and args.start + args.count <= len(whole)
        tokens = whole[args.start:args.start + args.count].copy()
    images = {arm: JOINT / f'layer{args.layer:02d}-causal-refit-{arm}.npz' for arm in ARMS}
    full = JOINT / f'layer{args.layer:02d}-joint-r28.npz'
    receipts = {arm: json.loads(path.with_suffix('.json').read_text()) for arm, path in images.items()}
    for arm, path in images.items():
        assert sha(path) == receipts[arm]['image_sha256']
    spec = importlib.util.spec_from_file_location('value_observer_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    pv = model.get_parameter(f'model.layers.{args.layer}.self_attn.v_proj.weight')
    po = model.get_parameter(f'model.layers.{args.layer}.self_attn.o_proj.weight')
    original = (pv.detach().clone(), po.detach().clone())
    weights = {'reference': (*original, 2 * sum(p.numel() for p in model.parameters()))}
    weights.update({arm: pruned_weights(path, quantizer.decode) for arm, path in images.items()})
    weights['joint_rank28'] = narrow_weights(full, quantizer.decode)
    original_bytes = weights['reference'][2]
    replaced = 2 * (pv.numel() + po.numel())
    result = {'format': 'qwen-fresh-narrow-value-single-layer/1', 'layer': args.layer,
              'split': args.split, 'start': args.start, 'count': args.count,
              'fixture_manifest_sha256': sha(fixture_manifest), 'fixture_tokens_sha256': sha(fixture_tokens),
              'model_weights_sha256': sha(MODEL / 'model.safetensors'),
              'source_sha256': {p.name: sha(p) for p in (Path(__file__), QUANTIZER)},
              'images': {arm: {'path': str(path), 'sha256': sha(path),
                               'payload_bytes': weights[arm][2], 'ranks': receipts[arm]['ranks']}
                         for arm, path in images.items()},
              'joint_rank28_image_sha256': sha(full),
              'observation': 'one substituted V/O layer; original Q/K, other layers, embedding/head; BF16-expanded paid image in HF model for quality only; fresh disjoint 256-token windows',
              'torch': torch.__version__, 'hip': torch.version.hip,
              'device': torch.cuda.get_device_name(), 'windows': []}
    with torch.inference_mode():
        for index, row in enumerate(tokens, args.start):
            ids = torch.from_numpy(row.astype(np.int64)).to('cuda').unsqueeze(0)
            target = ids[:, 1:]
            teacher = None
            record = {'index': index, 'token_start': manifest['windows'][key]['starts'][index],
                      'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'arms': {}}
            for arm, (v, o, paid) in weights.items():
                pv.copy_(v)
                po.copy_(o)
                logits = model(ids, use_cache=False).logits[:, :-1].float()
                logp = logits.log_softmax(-1)
                if teacher is None:
                    teacher = logp
                metrics = scores(logp, teacher, target)[0]
                record['arms'][arm] = {**metrics, 'whole_model_payload_bytes': original_bytes-replaced+paid,
                                       'v_o_payload_bytes': paid if arm != 'reference' else replaced}
                del logits, logp
            result['windows'].append(record)
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps({'layer': args.layer, 'split': args.split, 'index': index,
                              'nll': {arm: round(value['nll'], 5) for arm, value in record['arms'].items()}}), flush=True)
    with torch.no_grad():
        pv.copy_(original[0])
        po.copy_(original[1])


if __name__ == '__main__':
    main()
