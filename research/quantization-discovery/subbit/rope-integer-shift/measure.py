#!/usr/bin/env python3
"""Fit integer position shifts of the paid Q/K RoPE gauge on frozen Qwen text."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cache = imported(ROOT/'key-nibble-cache/measure.py', 'integer_shift_cache')
paid = cache.paid
finite = cache.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def capture(layer, output):
    prior = json.loads((DATA/f'paid-qk-cache-slack/layer{layer:02d}.json').read_text())
    q_path = DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    result = {}
    for split in ('train','validation'):
        x = finite.load_capture(layer, split).reshape(-1,256,1024)
        q, k = paid.projected(x, weights, gamma)
        tq, tk = paid.projected(x, original, original['k_norm'])
        for label, tensor in (('q',q),('k',k),('tq',tq),('tk',tk)):
            result[f'{split}_{label}'] = tensor.numpy()
        print(layer, split, q.shape, flush=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    np.savez(output, **result)


def rotated(tensor, idx, cosine, sine):
    a = tensor[..., idx]
    b = tensor[..., [i+64 for i in idx]]
    return torch.cat((cosine*a-sine*b, sine*a+cosine*b), -1)


def loss(candidate, teacher, positions):
    mask = torch.arange(256)[None,:] > positions[:,None]
    a = candidate.masked_fill(mask, -1e9).log_softmax(-1)
    b = teacher.masked_fill(mask, -1e9).log_softmax(-1)
    return (b.exp()*(b-a)).sum(-1).mean((-1,-2))


def fit(layer, source, output, max_shift):
    parent_path = DATA/f'key-nibble-cache/layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    with np.load(source) as input_data:
        data = {name: torch.from_numpy(input_data[name]).double() for name in input_data.files}
    train_positions = torch.arange(64,256,12)
    held_positions = torch.arange(256)
    # Qwen3-0.6B uses theta=1e6 and 64 half-split rotary coordinates.
    theta = 1000000.0 ** (-torch.arange(64, dtype=torch.double)/64)
    output_groups = []
    for g, group in enumerate(parent['groups']):
        idx = group['mask']
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        step = torch.tensor(group['int4'][arm]['steps'], dtype=torch.double)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*len(step), dtype=torch.double)
        teacher = {}
        for split, positions in (('train',train_positions),('validation',held_positions)):
            tq = data[split+'_tq'][:,2*g:2*g+2,positions]
            tk = data[split+'_tk'][:,g:g+1]
            teacher[split] = tq @ tk.transpose(-1,-2)/math.sqrt(128)
        def score(split, positions, shift):
            angles = theta[idx]*shift
            cosine, sine = angles.cos(), angles.sin()
            q = rotated(data[split+'_q'][:,2*g:2*g+2,positions], idx, cosine, sine)
            k = rotated(data[split+'_k'][:,g:g+1], idx, cosine, sine)
            c = torch.cat((cosine*center[:len(idx)]-sine*center[len(idx):],
                           sine*center[:len(idx)]+cosine*center[len(idx):]))
            key = ((k-c)/step).round().clamp(-7,7)
            prep = q*step
            scale = prep.abs().amax(-1,keepdim=True).clamp_min(1e-20)/119
            query = (prep/scale).round().clamp(-119,119)
            result = (query @ key.transpose(-1,-2))*scale/math.sqrt(128)
            return loss(result,teacher[split],positions).tolist()
        train = [score('train',train_positions,shift) for shift in range(max_shift+1)]
        means = [sum(row)/len(row) for row in train]
        selected = min(range(len(means)),key=lambda i: means[i])
        held = {str(i):score('validation',held_positions,i) for i in sorted(set((0,selected)))}
        output_groups.append({'group':g,'arm':arm,'train_positions':train_positions.tolist(),
                              'train_kl_by_shift_and_window':train,'chosen_shift':selected,
                              'held_kl_by_shift_and_window':held})
        print('group',g,'shift',selected,'train',means[0],means[selected], 'held',sum(held['0'])/4,sum(held[str(selected)])/4,flush=True)
    zero = [sum(group['held_kl_by_shift_and_window']['0'][w] for group in output_groups)/8 for w in range(4)]
    selected = [sum(group['held_kl_by_shift_and_window'][str(group['chosen_shift'])][w] for group in output_groups)/8 for w in range(4)]
    result = {'layer':layer,'shift_range':[0,max_shift],'train_windows':8,'held_windows':4,
              'contract':'original-producer paid Q/K; fixed masks, steps, post-RoPE centers and dynamic-max signed-byte query; shared integer Q/K position shift per GQA group; train strided causal KL selects shift; held evaluates all 256 positions',
              'groups':output_groups,'held_zero_by_window':zero,'held_selected_by_window':selected,
              'held_zero_mean':sum(zero)/4,'held_selected_mean':sum(selected)/4,
              'source_sha256':sha(Path(__file__)),'parent_sha256':sha(parent_path),
              'capture_sha256':sha(source),'model_sha256':sha(finite.MODEL),
              'paid_q_sha256':sha(DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_q_proj.npz'),
              'paid_k_sha256':sha(DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_k_proj.npz')}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print('held',result['held_zero_mean'],result['held_selected_mean'],flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage',choices=('capture','fit'))
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--input',type=Path)
    parser.add_argument('--max-shift',type=int,default=31)
    args = parser.parse_args()
    torch.set_num_threads(4)
    if args.stage == 'capture':
        capture(args.layer,args.output)
    else:
        fit(args.layer,args.input,args.output,args.max_shift)
