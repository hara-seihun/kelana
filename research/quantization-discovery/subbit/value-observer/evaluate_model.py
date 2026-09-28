#!/usr/bin/env python3
"""One frozen V/O substitution per layer in the original Qwen model, quality only."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-0.6b'
TOKENS = ROOT / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
JOINT = ROOT / 'value-observer'
CONTROL = ROOT / 'full-model/image-binary055-refined'
QUANTIZER = Path(__file__).resolve().parents[1] / 'spectral_quant.py'


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def binary_weight(path):
    with np.load(path) as f:
        n, k, r = map(int, f['dimensions'])
        u = np.unpackbits(f['U'], axis=1, bitorder='little')[:, :r].astype(np.float32) * 2 - 1
        v = np.unpackbits(f['V'], axis=1, bitorder='little')[:, :k].astype(np.float32) * 2 - 1
        u *= f['scale_post'].astype(np.float32)[:, None]
        v *= f['scale_pre'].astype(np.float32)[None, :]
        paid = sum(f[key].nbytes for key in f.files)
    return (torch.from_numpy(u).to('cuda') @ torch.from_numpy(v).to('cuda')).to(torch.bfloat16), paid


def narrow_weights(path, decode):
    with np.load(path) as f:
        paid = sum(f[key].nbytes for key in f.files)
        assert set(f.files) == {'left_shape', 'left_codes', 'left_scales', 'right_shape', 'right_codes', 'right_scales'}
        v = torch.zeros(1024, 1024, dtype=torch.bfloat16, device='cuda')
        o = torch.zeros(1024, 2048, dtype=torch.bfloat16, device='cuda')
        for group in range(8):
            arrays = {key: f[key][group].copy() for key in f.files}
            assert tuple(arrays['left_shape']) == (2048, 28, 2, 128)
            assert tuple(arrays['right_shape']) == (28, 1024, 2, 128)
            right = decode(arrays, 'right').to(device='cuda', dtype=torch.bfloat16)
            left = decode(arrays, 'left').to(device='cuda', dtype=torch.bfloat16)
            v[group*128:group*128+28] = right
            for local in range(2):
                head = 2*group + local
                o[:, head*128:head*128+28] = left[local*1024:(local+1)*1024]
    assert paid == 208640
    return v, o, paid


def scores(logp, teacher, targets):
    nll = -logp.gather(-1, targets[:, :, None]).squeeze(-1)
    kl = (teacher.exp() * (teacher - logp)).sum(-1)
    agreement = (teacher.argmax(-1) == logp.argmax(-1))
    return [{'window': index, 'predictions': targets.shape[1],
             'nll_sum': float(nll[index].sum()), 'nll': float(nll[index].mean()),
             'teacher_kl_sum': float(kl[index].sum()), 'teacher_kl': float(kl[index].mean()),
             'argmax_agreements': int(agreement[index].sum()),
             'argmax_agreement': float(agreement[index].float().mean())}
            for index in range(len(targets))]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--out', type=Path, default=None)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    out = args.out or JOINT / f'full-model-layer{args.layer:02d}.json'
    spec = importlib.util.spec_from_file_location('value_observer_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    image = JOINT / f'layer{args.layer:02d}-joint-r28.npz'
    expected = {0: '93b969a9dbde2c28a23862f5199c1db7e7a12080a836aafb8eed94f8170f420c',
                14: '6673197d16a29148f64b997a2007a004161bfe7d8277d77e7dcf4e6af273e4e4'}
    assert sha(image) == expected[args.layer]
    manifest_path = CONTROL / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    control_paths = {name: CONTROL / f'layer{args.layer:02d}-self_attn_{name}_proj.npz'
                     for name in ('v', 'o')}
    entries = {entry['path']: entry for entry in manifest['body']}
    for path in control_paths.values():
        assert sha(path) == entries[path.name]['sha256']
    with np.load(TOKENS) as fixture:
        tokens = {split: fixture[split][:4].copy() for split in ('validation', 'test')}
    model = AutoModelForCausalLM.from_pretrained(
        MODEL, local_files_only=True, dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    unique = sum(parameter.numel() for parameter in model.parameters())
    v_param = model.get_parameter(f'model.layers.{args.layer}.self_attn.v_proj.weight')
    o_param = model.get_parameter(f'model.layers.{args.layer}.self_attn.o_proj.weight')
    original_v, original_o = v_param.detach().clone(), o_param.detach().clone()
    binary_v, v_paid = binary_weight(control_paths['v'])
    binary_o, o_paid = binary_weight(control_paths['o'])
    joint_v, joint_o, joint_paid = narrow_weights(image, quantizer.decode)
    original_bytes = 2*unique
    replaced_bytes = 2*(v_param.numel()+o_param.numel())
    arms = {'reference': (original_v, original_o, original_bytes),
            'independent_binary': (binary_v, binary_o, original_bytes-replaced_bytes+v_paid+o_paid),
            'joint_rank28': (joint_v, joint_o, original_bytes-replaced_bytes+joint_paid)}
    assert (v_paid + o_paid) == 210968
    result = {'format': 'qwen-single-layer-joint-value-model-quality/1', 'layer': args.layer,
              'model': str(MODEL), 'model_source_sha256': sha(MODEL/'source.json'),
              'model_weights_sha256': sha(MODEL/'model.safetensors'),
              'model_revision': json.loads((MODEL/'source.json').read_text())['revision'],
              'tokens': str(TOKENS), 'tokens_sha256': sha(TOKENS),
              'window_token_sha256': {split: [hashlib.sha256(row.tobytes()).hexdigest() for row in batch]
                                      for split, batch in tokens.items()},
              'source_sha256': {path.name: sha(path) for path in (Path(__file__), QUANTIZER)},
              'control_manifest_sha256': sha(manifest_path),
              'images': {'joint': {'path': str(image), 'sha256': sha(image), 'payload_bytes': joint_paid},
                         **{name: {'path': str(path), 'sha256': sha(path),
                                   'payload_bytes': v_paid if name == 'v' else o_paid}
                            for name, path in control_paths.items()}},
              'unique_parameters': unique, 'original_v_o_elements': v_param.numel()+o_param.numel(),
              'method': 'only one layer changes per panel; Q/K and all other layers original; joint 28 coordinates occupy first 28 of each 128-wide HF GQA V/O block, other entries exact zero; weights expanded and rounded BF16 for model quality, not native timing',
              'torch': torch.__version__, 'hip': torch.version.hip,
              'device': torch.cuda.get_device_name(), 'splits': {}}
    with torch.inference_mode():
        for split, batch in tokens.items():
            ids = torch.tensor(batch, dtype=torch.long, device='cuda')
            targets = ids[:, 1:]
            split_result = {}
            teacher = None
            for name, (v, o, paid) in arms.items():
                v_param.copy_(v)
                o_param.copy_(o)
                logits = model(ids, use_cache=False).logits[:, :-1].float()
                logp = logits.log_softmax(-1)
                if name == 'reference':
                    teacher = logp
                windows = scores(logp, teacher, targets)
                count = sum(row['predictions'] for row in windows)
                nll = sum(row['nll_sum'] for row in windows)/count
                split_result[name] = {'payload_bytes': paid, 'all_unique_parameter_bpw': 8*paid/unique,
                                      'predictions': count, 'nll': nll, 'perplexity': math.exp(nll),
                                      'teacher_kl': sum(row['teacher_kl_sum'] for row in windows)/count,
                                      'argmax_agreement': sum(row['argmax_agreements'] for row in windows)/count,
                                      'windows': windows}
                del logits, logp
            result['splits'][split] = split_result
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(json.dumps(result, indent=2)+'\n')
            print(json.dumps({'layer': args.layer, 'split': split,
                              'arms': {name: {key: row[key] for key in ('nll', 'teacher_kl', 'argmax_agreement')}
                                       for name, row in split_result.items()}}), flush=True)
            del teacher


if __name__ == '__main__':
    main()
