"""Full-channel, complete-down Qwen3-0.6B MLP response experiment."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open

from codec import build_image, decode_image, sha256

DATA = Path('/path/to/workspace/data/kelana-subbit')
SOURCE = DATA / 'models/qwen3-0.6b/model.safetensors'
CAPTURE = DATA / 'vector-full/capture'
OUT = DATA / 'vector-full/images'
TERNSRC = Path(__file__).resolve().parents[3] / 'ternary'


def bf16(bits):
    return (np.asarray(bits, dtype=np.uint32) << 16).view(np.float32)


def source_weights(layer):
    prefix = f'model.layers.{layer}.mlp.'
    with safe_open(SOURCE, framework='pt', device='cpu') as model:
        gate = model.get_tensor(prefix + 'gate_proj.weight').float().numpy()
        up = model.get_tensor(prefix + 'up_proj.weight').float().numpy()
        down = model.get_tensor(prefix + 'down_proj.weight').float().numpy()
    return np.stack((gate, up), axis=-1), down


def packed_projection(layer, projection):
    sys.path.insert(0, str(TERNSRC))
    from pilot import unpacked
    path = DATA / f'ternary/expanded-scale384/model_layers_{layer}_mlp_{projection}_proj_weight.npz'
    return unpacked(path, device='cpu').decode().numpy(), path


def physical_ternary_bytes(path):
    with np.load(path) as image:
        return sum(image[field].nbytes for field in ('codes', 'scales', 'signs', 'shape', 'rotation_block'))


def inputs(layer, split, windows=4, positions_per_window=32):
    path = CAPTURE / f'ternary-{split}-{464 if split == "train" else 8}-{windows}.npz'
    with np.load(path) as values:
        bits = values[f'layer{layer:02}']
        positions = np.concatenate([np.arange(w * 256, w * 256 + positions_per_window) for w in range(windows)])
        x = bf16(bits[positions]).copy()
    return x, path, positions


def response(x, gate, up, down):
    g = x @ gate.T
    u = x @ up.T
    hidden = (g / (1 + np.exp(-np.clip(g, -80, 80)))) * u
    return hidden @ down.T


def relative(pred, target):
    return float(np.linalg.norm((pred - target).astype(np.float64)) / np.linalg.norm(target.astype(np.float64)))


def fit(args):
    weights, _ = source_weights(args.layer)
    name = f'layer{args.layer:02}-{args.method}-{args.width}bit.npz'
    image = OUT / name
    record = build_image(weights, args.width, args.method, image, layer=args.layer, source_sha256=sha256(SOURCE))
    print(json.dumps(record), flush=True)


def score(args):
    image = Path(args.image)
    record = json.loads(image.with_suffix('.json').read_text())
    layer = record['layer']
    weights, original_down = source_weights(layer)
    common_down, down_path = packed_projection(layer, 'down')
    gate, up = decode_image(image)
    result = {'image': record, 'common_down': {'path': str(down_path), 'sha256': sha256(down_path),
               'physical_bytes': physical_ternary_bytes(down_path),
               'representation': 'expanded-scale384 packed ternary, decoded effective FP32 for response scoring'},
              'total_paid_mlp_bytes': None, 'split': {}}
    result['total_paid_mlp_bytes'] = record['physical_bytes'] + result['common_down']['physical_bytes']
    for split in ('train', 'validation'):
        x, capture_path, positions = inputs(layer, split, positions_per_window=args.positions_per_window)
        target = response(x, weights[:, :, 0], weights[:, :, 1], original_down)
        down_control = response(x, weights[:, :, 0], weights[:, :, 1], common_down)
        image_response = response(x, gate, up, common_down)
        result['split'][split] = {'capture': str(capture_path), 'capture_sha256': sha256(capture_path),
            'positions': positions.tolist(), 'producer_input_sha256': hashlib.sha256(x.tobytes()).hexdigest(),
            'target_norm': float(np.linalg.norm(target.astype(np.float64))),
            'common_down_only_relative_rms': relative(down_control, target),
            'pair_image_relative_rms': relative(image_response, target),
            'pair_vs_down_only_relative_rms': relative(image_response, down_control)}
    output = image.with_suffix('.quality.json')
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'image': str(image), 'total_bytes': result['total_paid_mlp_bytes'],
                      'train': result['split']['train']['pair_image_relative_rms'],
                      'held': result['split']['validation']['pair_image_relative_rms'],
                      'held_down_only': result['split']['validation']['common_down_only_relative_rms']}), flush=True)


def baseline(args):
    layer = args.layer
    weights, original_down = source_weights(layer)
    down, down_path = packed_projection(layer, 'down')
    gate, gate_path = packed_projection(layer, 'gate')
    up, up_path = packed_projection(layer, 'up')
    result = {'layer': layer, 'method': 'selected-expanded-scale384',
              'bytes': {name: physical_ternary_bytes(path) for name, path in
                        [('gate', gate_path), ('up', up_path), ('down', down_path)]},
              'image_sha256': {name: sha256(path) for name, path in
                               [('gate', gate_path), ('up', up_path), ('down', down_path)]}, 'split': {}}
    result['physical_bytes'] = sum(result['bytes'].values())
    for split in ('train', 'validation'):
        x, capture_path, positions = inputs(layer, split, positions_per_window=args.positions_per_window)
        target = response(x, weights[:, :, 0], weights[:, :, 1], original_down)
        control = response(x, weights[:, :, 0], weights[:, :, 1], down)
        actual = response(x, gate, up, down)
        result['split'][split] = {'capture': str(capture_path), 'capture_sha256': sha256(capture_path),
                                  'positions': positions.tolist(),
                                  'common_down_only_relative_rms': relative(control, target),
                                  'selected_relative_rms': relative(actual, target)}
    output = OUT / f'layer{layer:02}-selected-baseline.json'
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'layer': layer, 'total_bytes': result['physical_bytes'],
                      'train': result['split']['train']['selected_relative_rms'],
                      'held': result['split']['validation']['selected_relative_rms']}))


def scalar4(args):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'subbit'))
    from spectral_quant import decode
    layer = args.layer
    weights, original_down = source_weights(layer)
    down, down_path = packed_projection(layer, 'down')
    paths = {name: DATA / f'full-scalar/model_layers_{layer}_mlp_{name}_proj_weight-g128-b4.npz'
             for name in ('gate', 'up')}
    arrays = {}
    for name, path in paths.items():
        with np.load(path) as image:
            arrays[name] = decode(image, 'weight').numpy()
    receipt = {'layer': layer, 'method': 'independent-scalar4-g128', 'down': str(down_path),
               'images': {name: {'path': str(path), 'sha256': sha256(path), 'payload_bytes':
                  sum(np.load(path)[key].nbytes for key in ('weight_codes', 'weight_scales', 'weight_shape'))}
                          for name, path in paths.items()}, 'split': {}}
    receipt['total_paid_mlp_bytes'] = physical_ternary_bytes(down_path) + sum(x['payload_bytes'] for x in receipt['images'].values())
    for split in ('train', 'validation'):
        x, capture_path, positions = inputs(layer, split)
        target = response(x, weights[:, :, 0], weights[:, :, 1], original_down)
        predicted = response(x, arrays['gate'], arrays['up'], down)
        receipt['split'][split] = {'capture': str(capture_path), 'capture_sha256': sha256(capture_path),
                                   'positions': positions.tolist(), 'relative_rms': relative(predicted, target)}
    output = OUT / f'layer{layer:02}-independent-scalar4-g128.json'
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'layer': layer, 'total_bytes': receipt['total_paid_mlp_bytes'],
                      'train': receipt['split']['train']['relative_rms'],
                      'held': receipt['split']['validation']['relative_rms']}))


def main():
    parser = argparse.ArgumentParser()
    subs = parser.add_subparsers(dest='action', required=True)
    fit_cmd = subs.add_parser('fit')
    fit_cmd.add_argument('--layer', type=int, choices=(0, 14, 27), required=True)
    fit_cmd.add_argument('--width', type=int, choices=(3, 4, 6, 8), required=True)
    fit_cmd.add_argument('--method', choices=('polar', 'scalar_scale', 'learned_pair'), required=True)
    score_cmd = subs.add_parser('score')
    score_cmd.add_argument('image')
    score_cmd.add_argument('--positions-per-window', type=int, default=32)
    baseline_cmd = subs.add_parser('baseline')
    baseline_cmd.add_argument('--layer', type=int, choices=(0, 14, 27), required=True)
    baseline_cmd.add_argument('--positions-per-window', type=int, default=32)
    scalar_cmd = subs.add_parser('scalar4')
    scalar_cmd.add_argument('--layer', type=int, choices=(0, 14, 27), required=True)
    args = parser.parse_args()
    {'fit': fit, 'score': score, 'baseline': baseline, 'scalar4': scalar4}[args.action](args)


if __name__ == '__main__':
    main()
