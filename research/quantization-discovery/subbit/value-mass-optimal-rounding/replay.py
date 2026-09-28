#!/usr/bin/env python3
"""Complete two-head response replay of the frozen mass-concentration policy."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mass_concentration', HERE.with_name('measure.py'))
study = importlib.util.module_from_spec(spec)
spec.loader.exec_module(study)
prior_spec = importlib.util.spec_from_file_location('mass_integer', SUBBIT / 'value-integer-consumer/measure.py')
prior = importlib.util.module_from_spec(prior_spec)
prior_spec.loader.exec_module(prior)
DATA = study.DATA
CAPS = (0, 4, 16, 32)


def run(layer):
    torch.set_num_threads(8)
    p_model = study.radix.MODEL
    with safe_open(p_model, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm', 'v_proj', 'o_proj')}
    x = prior.load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = prior.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    n = prior.integer_mass(p, 4095)
    owner = p.argmax(-1, keepdim=True)
    counts = {str(cap): study.concentrate(n, owner, cap)[0].float() for cap in CAPS}
    teacher = prior.dense_attention(p, x, w['v_proj'], w['o_proj'])
    metadata_path = DATA.parent / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(metadata_path.read_text())
    factor_path = DATA.parent / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert prior.sha(factor_path) == metadata['image_sha256']
    decoder_spec = importlib.util.spec_from_file_location('factor_decoder', prior.SOURCE)
    decoder = importlib.util.module_from_spec(decoder_spec)
    decoder_spec.loader.exec_module(decoder)
    output = {key: torch.zeros_like(teacher) for key in counts}
    with np.load(factor_path) as image:
        for g in range(8):
            factors = {key: image[key][g].copy() for key in image.files}
            left, right = decoder.decode(factors, 'left'), decoder.decode(factors, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            entry = metadata['metadata'][g]['int4_coordinate']
            center, step = torch.tensor(entry['center']), torch.tensor(entry['step'])
            codes = ((z - center) / step).round().clamp(-7, 7).float()
            for h in range(2):
                projection = left[h*1024:(h+1)*1024]
                for arm, cnt in counts.items():
                    output[arm] += ((cnt[:, 2*g+h] @ codes) * (step / 4095) + center) @ projection.T
    receipt_path = DATA / f'layer{layer:02d}.json'
    result = json.loads(receipt_path.read_text())
    result['replay_source_sha256'] = prior.sha(HERE)
    result['factor_sha256'] = prior.sha(factor_path)
    result['cache_fit_sha256'] = prior.sha(metadata_path)
    result['post_o_relative_teacher_error'] = {arm: prior.relative(y, teacher) for arm, y in output.items()}
    result['per_window_post_o_relative_teacher_error'] = {
        arm: [prior.relative(y[i], teacher[i]) for i in range(4)] for arm, y in output.items()}
    result['post_o_relative_to_prefix_output'] = {
        arm: prior.relative(y, output['0']) for arm, y in output.items()}
    receipt_path.write_text(json.dumps(result, indent=2) + '\n')
    print(layer, result['post_o_relative_teacher_error'], result['post_o_relative_to_prefix_output'], flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
