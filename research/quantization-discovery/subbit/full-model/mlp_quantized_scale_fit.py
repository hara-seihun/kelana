#!/usr/bin/env python3
"""Capture a damaged layer-0 producer, then fit already-paid binary MLP scales."""
import argparse
import hashlib
import importlib.util
import json
import os
import tempfile
from pathlib import Path

import numpy as np
import torch

from mlp_factor_response import ROOT, PARTS, digest, error, unpack_bf16, weight
from mlp_input_scale_fit import mlp, stored_scales

BASE = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / 'mlp-quantized-producer-capture.npz'


def capture():
    source = Path(__file__).read_bytes()
    source_sha256 = hashlib.sha256(source).hexdigest()
    snapshots = ROOT / 'sources'
    snapshots.mkdir(exist_ok=True)
    snapshot = snapshots / f'{source_sha256}.py'
    with tempfile.NamedTemporaryFile(dir=snapshots, delete=False) as tmp:
        pending = Path(tmp.name)
        try:
            tmp.write(source)
            tmp.flush()
            os.fsync(tmp.fileno())
        except BaseException:
            pending.unlink(missing_ok=True)
            raise
    try:
        try:
            os.link(pending, snapshot)
        except FileExistsError:
            pass
    finally:
        pending.unlink()
    if snapshot.read_bytes() != source:
        raise ValueError(f'Producer snapshot hash collision or corrupted source: {snapshot}')

    from transformers import AutoModelForCausalLM
    from image import binary_weight
    from narrow_prefix import narrow, QUANTIZER, sha

    torch.backends.cuda.matmul.allow_tf32 = False
    model_dir = ROOT.parent / 'models/qwen3-0.6b'
    tokens = ROOT.parent / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
    image_dir = ROOT / 'image-binary055-refined'
    narrow_file = ROOT.parent / 'value-observer/layer00-joint-r28.npz'
    spec = importlib.util.spec_from_file_location('narrow_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    nv, no, _ = narrow(narrow_file, quantizer.decode)
    model = AutoModelForCausalLM.from_pretrained(model_dir, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    layer = model.model.layers[0]
    names = ('self_attn.q_proj', 'self_attn.k_proj', 'self_attn.v_proj',
             'self_attn.o_proj', 'input_layernorm', 'post_attention_layernorm')
    originals = {name: layer.get_submodule(name).weight.detach().clone() for name in names}
    manifest = json.loads((image_dir / 'manifest.json').read_text())
    images = {}
    files = {str(tokens): sha(tokens), str(model_dir / 'model.safetensors'): sha(model_dir / 'model.safetensors'),
             str(narrow_file): sha(narrow_file), str(image_dir / 'manifest.json'): sha(image_dir / 'manifest.json')}
    for entry in manifest['body']:
        if entry['key'] in (f'model.layers.0.{name}.weight' for name in names):
            path = image_dir / entry['path']
            files[str(path)] = sha(path)
            images[entry['key'].split('layers.0.')[1].removesuffix('.weight')] = binary_weight(path)
    with np.load(image_dir / manifest['norms']['path']) as f:
        for name in ('input_layernorm', 'post_attention_layernorm'):
            key = f'model.layers.0.{name}.weight'
            images[name] = torch.from_numpy(f[key].view(np.int16).copy()).view(torch.bfloat16)
    images['self_attn.v_proj'], images['self_attn.o_proj'] = nv.cpu(), no.cpu()
    files[str(image_dir / manifest['norms']['path'])] = sha(image_dir / manifest['norms']['path'])
    with np.load(tokens) as f:
        batches = {split: f[split].copy() for split in ('train', 'validation')}
    class StopAtLayer(Exception):
        pass
    collected = {}
    def pre_norm(module, args):
        collected['pre'] = args[0].detach().clone()
    def pre_gate(module, args):
        collected['input'] = args[0].detach().clone()
    def end_layer(module, args, output):
        collected['post'] = (output[0] if isinstance(output, tuple) else output).detach().clone()
        raise StopAtLayer
    hooks = [layer.post_attention_layernorm.register_forward_pre_hook(pre_norm),
             layer.mlp.gate_proj.register_forward_pre_hook(pre_gate),
             layer.register_forward_hook(end_layer)]
    arrays = {}
    with torch.inference_mode():
        for split, batch in batches.items():
            for mode in ('teacher', 'damaged'):
                for name in names:
                    layer.get_submodule(name).weight.copy_(
                        originals[name] if mode == 'teacher' else images[name].to('cuda'))
                rows = {'input': [], 'pre': [], 'post': []}
                for row in batch:
                    collected.clear()
                    try:
                        model.model(torch.as_tensor(row.astype(np.int64), device='cuda')[None], use_cache=False)
                    except StopAtLayer:
                        pass
                    for key in rows:
                        rows[key].append(collected[key].flatten(0, 1).to('cpu').view(torch.int16).numpy().view(np.uint16).copy())
                for key, parts in rows.items():
                    arrays[f'{split}_{mode}_{key}'] = np.concatenate(parts)
                print(json.dumps({'split': split, 'mode': mode, 'rows': len(arrays[f'{split}_{mode}_input'])}), flush=True)
    for hook in hooks:
        hook.remove()
    np.savez(CAPTURE, **arrays)
    meta = {'format': 'layer0-narrow-quantized-mlp-producer/1', 'source_sha256': source_sha256,
            'source_snapshot': {'path': str(snapshot), 'sha256': source_sha256},
            'inputs_sha256': files, 'capture_sha256': digest(CAPTURE),
            'arrays': {name: list(value.shape) for name, value in arrays.items()},
            'observation': 'Original tied embedding. Teacher original layer0 endpoint. Damaged layer0 binary Q/K and norms, shared rank28 V/O, original MLP during capture (only its input observed). Actual BF16 model forward; stop after layer0.'}
    (ROOT / 'mlp-quantized-producer-capture.json').write_text(json.dumps(meta, indent=2) + '\n')
    print(json.dumps({'capture': str(CAPTURE), 'sha256': meta['capture_sha256']}), flush=True)


def fit(args):
    files = {str(CAPTURE): digest(CAPTURE)}
    weights, paths = {}, {}
    for part in PARTS:
        for quant in (False, True):
            w, path, sha = weight(part, quant)
            weights[part, quant] = w
            files[path] = sha
            if quant:
                paths[part] = path
    with np.load(CAPTURE) as data:
        inputs = {}
        targets = {}
        for split, count in (('train', args.train_rows), ('validation', 1024)):
            x = unpack_bf16(data[f'{split}_damaged_input'][:count])
            pre = unpack_bf16(data[f'{split}_damaged_pre'][:count])
            post = unpack_bf16(data[f'{split}_teacher_post'][:count])
            inputs[split] = x
            targets[split] = post - pre
    quant = {part: weights[part, True] for part in PARTS}
    initial = {f'{part}_{side}': torch.zeros(weights[part, True].shape[0 if side == 'post' else 1])
               for part in PARTS for side in (('pre', 'post') if part != 'down' else ('post',))}
    scores = {}
    for arm in ('binary', 'original_producer_fit', 'damaged_fit'):
        if arm == 'original_producer_fit':
            images = ROOT / 'mlp-input-scale-2048-image'
            logs = {}
            for part in PARTS:
                with np.load(paths[part]) as f, np.load(images / f'layer00-mlp_{part}_proj.npz') as updated:
                    for side in (('pre', 'post') if part != 'down' else ('post',)):
                        logs[f'{part}_{side}'] = torch.from_numpy(
                            (updated[f'scale_{side}'].astype(np.float32) / f[f'scale_{side}'].astype(np.float32)).copy()).log()
        else:
            logs = initial
        scores[arm] = {split: error(targets[split], mlp(x, quant, logs)) for split, x in inputs.items()}
    logs = {name: torch.nn.Parameter(value.clone()) for name, value in initial.items()}
    optimizer = torch.optim.Adam(list(logs.values()), lr=args.lr)
    history = []
    for step in range(1, args.steps + 1):
        optimizer.zero_grad(set_to_none=True)
        loss = (mlp(inputs['train'], quant, logs) - targets['train']).square().sum() / targets['train'].square().sum()
        penalty = args.ridge * sum(v.square().mean() for v in logs.values())
        (loss + penalty).backward()
        optimizer.step()
        history.append({'step': step, 'train_error': float(loss.detach()), 'penalty': float(penalty.detach())})
    stored, effective = stored_scales(paths, logs)
    rounded = {name: value.log() for name, value in effective.items()}
    scores['damaged_fit'] = {split: error(targets[split], mlp(x, quant, rounded)) for split, x in inputs.items()}
    out_dir = ROOT / f'mlp-quantized-scale-{args.train_rows}-image'
    out_dir.mkdir(exist_ok=True)
    outputs = {}
    for part, payload in stored.items():
        path = out_dir / f'layer00-mlp_{part}_proj.npz'
        np.savez_compressed(path, **payload)
        outputs[str(path)] = digest(path)
    receipt = {'format': 'layer0-quantized-producer-scale-fit/1', 'source_sha256': digest(Path(__file__)),
        'inputs_sha256': files, 'original_fit_sha256': {str(p): digest(p) for p in
          (ROOT / 'mlp-input-scale-2048-image').glob('*.npz')}, 'output_sha256': outputs,
        'train_rows': args.train_rows, 'held_rows': len(inputs['validation']),
        'lr': args.lr, 'ridge': args.ridge, 'steps': args.steps, 'history': history, 'scores': scores,
        'observation': 'Actual BF16 layer0 narrow V/O + binary Q/K and norms producer, original tied embedding. Target is teacher post-layer0 endpoint minus damaged pre-MLP residual. FP32 complete MLP fit; stored FP16 scales, frozen binary codes. Validation capture previously inspected.'}
    out = ROOT / f'mlp-quantized-scale-{args.train_rows}.json'
    out.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(out), 'scores': scores}, indent=2))


def evaluate(args):
    from transformers import AutoModelForCausalLM
    from image import binary_weight
    from narrow_prefix import IMAGE, VALUE, MODEL, FIXTURE, QUANTIZER, narrow, sha

    torch.backends.cuda.matmul.allow_tf32 = False
    spec = importlib.util.spec_from_file_location('narrow_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    narrow_path = VALUE / 'layer00-joint-r28.npz'
    nv, no, _ = narrow(narrow_path, quantizer.decode)
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    files = {str(manifest_path): sha(manifest_path), str(narrow_path): sha(narrow_path),
             str(MODEL / 'model.safetensors'): sha(MODEL / 'model.safetensors')}
    params = {}
    for entry in manifest['body']:
        if int(entry['key'].split('.')[2]) >= 14:
            continue
        path = IMAGE / entry['path']
        assert sha(path) == entry['sha256']
        files[str(path)] = entry['sha256']
        params[entry['key']] = binary_weight(path)
    norm_path = IMAGE / manifest['norms']['path']
    files[str(norm_path)] = sha(norm_path)
    with np.load(norm_path) as data:
        for name in data.files:
            if name == 'model.norm.weight' or int(name.split('.')[2]) >= 14:
                continue
            params[name] = torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16)
    v_key, o_key = (f'model.layers.0.self_attn.{part}_proj.weight' for part in ('v', 'o'))
    params[v_key], params[o_key] = nv.cpu(), no.cpu()
    variants = {'binary': {}, 'original_producer_fit': {}, 'damaged_fit': {}}
    for arm, directory in (('original_producer_fit', ROOT / 'mlp-input-scale-2048-image'),
                           ('damaged_fit', ROOT / f'mlp-quantized-scale-{args.train_rows}-image')):
        for part in PARTS:
            path = directory / f'layer00-mlp_{part}_proj.npz'
            files[str(path)] = sha(path)
            variants[arm][f'model.layers.0.mlp.{part}_proj.weight'] = binary_weight(path)
    token_path = FIXTURE / 'tokens.npz'
    fixture_path = FIXTURE / 'manifest.json'
    fixture = json.loads(fixture_path.read_text())
    assert sha(token_path) == fixture['tokens_sha256']
    files[str(token_path)] = sha(token_path)
    with np.load(token_path) as data:
        rows = data[args.split + '_256'][args.start:args.start + args.count].copy()
    assert len(rows) == args.count
    result = {'format': 'layer0-quantized-producer-scale-model-loss/1', 'source_sha256': digest(Path(__file__)),
              'inputs_sha256': files, 'split': args.split, 'start': args.start,
              'observation': 'Binary layers 0..13 and norms, shared rank28 layer0 V/O, original tied endpoints and later layers. BF16-expanded three MLP scale arms; 255 gold targets per window. Not compressed inference timing.',
              'windows': []}
    with torch.inference_mode():
        for index, row in enumerate(rows, args.start):
            ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
            scores = {}
            for arm in variants:
                for name, image in params.items():
                    model.get_parameter(name).copy_(variants[arm].get(name, image).to('cuda'))
                logp = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
                scores[arm] = float(-logp.gather(-1, ids[:, 1:, None]).mean())
            result['windows'].append({'index': index, 'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'nll': scores})
            out = ROOT / f'mlp-quantized-scale-{args.split}-{args.start}-{args.count}.json'
            out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps({'index': index, 'nll': scores}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('capture', 'fit', 'evaluate'))
    parser.add_argument('--train-rows', type=int, default=2048)
    parser.add_argument('--steps', type=int, default=16)
    parser.add_argument('--lr', type=float, default=.025)
    parser.add_argument('--ridge', type=float, default=.002)
    parser.add_argument('--split', choices=('validation', 'test'), default='test')
    parser.add_argument('--start', type=int, default=56)
    parser.add_argument('--count', type=int, default=2)
    args = parser.parse_args()
    torch.set_num_threads(8)
    if args.mode == 'capture':
        capture()
    elif args.mode == 'fit':
        fit(args)
    else:
        evaluate(args)
