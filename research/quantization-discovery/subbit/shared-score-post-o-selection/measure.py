#!/usr/bin/env python3
"""Exact finite base-head selection for the frozen three-dot Q/K score consumer."""
import argparse
import hashlib
import importlib.util
import itertools
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('producer_transfer', ROOT / 'shared-query-producer-transfer/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
base = parent.base


def hash_file(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def capture_gram(split, output):
    torch.set_num_threads(4)
    layer = 14
    capture_path = DATA / 'value-observer/layer14-quantized-upstream.npz'
    parent_path = DATA / 'shared-query-producer-transfer/layer14.json'
    key_path = DATA / 'key-nibble-cache/layer14.json'
    affine_path = DATA / 'paid-qk-cache-slack/layer14.json'
    q_path = DATA / 'full-model/image-binary055-refined/layer14-self_attn_q_proj.npz'
    k_path = DATA / 'full-model/image-binary055-refined/layer14-self_attn_k_proj.npz'
    assert hash_file(capture_path) == json.loads((DATA / 'value-observer/layer14-quantized-upstream-capture.json').read_text())['capture_sha256']
    key = json.loads(key_path.read_text())
    affine = json.loads(affine_path.read_text())
    with safe_open(base.finite.MODEL, framework='pt', device='cpu') as model:
        prefix = 'model.layers.14.self_attn.'
        original = {name: model.get_tensor(prefix + name + '.weight').float()
                    for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    paid = dict(original)
    paid['q_proj'] = base.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    paid['k_proj'] = base.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(affine['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    with np.load(capture_path) as data:
        x = torch.from_numpy(data[split].view(np.int16).copy()).view(torch.bfloat16).float()
    assert x.shape == (4, 256, 1024)
    q, k = base.paid.projected(x, paid, gamma)
    tq, tk = base.paid.projected(x, original, original['k_norm'])
    value = (x @ original['v_proj'].T).to(torch.bfloat16).float().reshape(4, 256, 8, 128).double()
    output_weight = original['o_proj'].double().reshape(1024, 16, 128)
    mask = torch.ones(256, 256, dtype=torch.bool).triu(1)
    responses = []
    teacher_output = torch.zeros(4, 256, 1024, dtype=torch.float64)
    per_group_kl = []
    for g, group in enumerate(key['groups']):
        indices = group['mask'] + [p+64 for p in group['mask']]
        arm = key['group_arms_selected_by_train']['coordinate'][g] + '_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*32, dtype=torch.float64)
        prepared = q[:,2*g:2*g+2,:,indices].double() * steps
        codes = ((k[:,g:g+1,:,indices].double()-center)/steps).round().clamp(-7,7)
        teacher = base.cache.scores(tq[:,2*g:2*g+2], tk[:,g:g+1], list(range(256)))
        scores = base.arms(prepared, codes)
        per_group_kl.append([base.lowering.causal_kl(scores[f'shared_base_{b}'], teacher).tolist()
                             for b in (0,1)])
        group_value = value[:,:,g,:]
        group_weight = output_weight[:,2*g:2*g+2,:]
        group_responses = []
        for name in ('teacher', 'shared_base_0', 'shared_base_1'):
            score = teacher if name == 'teacher' else scores[name]
            probability = score.masked_fill(mask, -1e9).softmax(-1)
            context = probability @ group_value[:,None,:,:]
            group_responses.append(torch.einsum('bhtd,ohd->bto', context, group_weight))
        teacher_output += group_responses[0]
        responses.append(group_responses[1:])
        print(split, 'group', g, flush=True)
    residual = sum((p[0] for p in responses), torch.zeros_like(teacher_output)) - teacher_output
    vectors = [residual] + [p[1]-p[0] for p in responses]
    flat = torch.stack([v.reshape(4,-1) for v in vectors], dim=1)
    gram = torch.bmm(flat, flat.transpose(1,2)).tolist()
    denominator = teacher_output.square().sum((1,2)).tolist()
    receipt = {'contract': 'Frozen paid binary Q/K and signed-nibble key labels, quantized layers 0..13 input, original layer-14 V/O, original Q/K teacher on identical input; four 256-token windows per split, all causal keys, FP64 response evaluation; no native timing or whole-model loss',
               'split': split, 'gram_by_window': gram, 'teacher_norm2_by_window': denominator,
               'group_kl_by_base_by_window': per_group_kl,
               'sha256': {name: hash_file(path) for name,path in {
                   'source': Path(__file__), 'transfer_source': Path(parent.__file__),
                   'base_source': Path(base.__file__), 'capture': capture_path,
                   'transfer_receipt': parent_path, 'key_image': key_path,
                   'affine': affine_path, 'paid_q': q_path, 'paid_k': k_path,
                   'model': base.finite.MODEL}.items()}}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2)+'\n')
    print(split, 'gram written', output, flush=True)


def select(train_path, held_path, output):
    train, held = [json.loads(path.read_text()) for path in (train_path, held_path)]
    assert train['sha256'] == held['sha256']
    train_gram, held_gram = [np.array(record['gram_by_window']) for record in (train,held)]
    train_norm, held_norm = [np.array(record['teacher_norm2_by_window']) for record in (train,held)]
    choices = np.array(list(itertools.product((0,1), repeat=8)), dtype=np.float64)
    selectors = np.concatenate([np.ones((256,1)), choices], axis=1)
    def errors(gram, norm):
        return np.einsum('mi,wij,mj->wm',selectors,gram,selectors,optimize=True)/norm[:,None]
    train_errors, held_errors = errors(train_gram, train_norm), errors(held_gram,held_norm)
    def pooled(errors, norms):
        return (errors*norms[:,None]).sum(axis=0)/norms.sum()
    parent_receipt = json.loads((DATA/'shared-query-producer-transfer/layer14.json').read_text())
    old = [record['frozen_shared_base'] for record in parent_receipt['groups']]
    kl = [int(np.argmin(np.sum(train['group_kl_by_base_by_window'][g],axis=1))) for g in range(8)]
    selected_index = int(np.argmin(pooled(train_errors,train_norm)))
    oracle_index = int(np.argmin(pooled(held_errors,held_norm)))
    index = lambda choice: int(np.flatnonzero((choices == choice).all(axis=1))[0])
    receipt = {'contract': 'Exhaustive 2^8 independent GQA-group base-head masks, train-only complete post-O relative squared-error choice; all maps retain the same three-dot K-score products and original V/O; held oracle is a diagnostic, not selection',
               'train_gram': hash_file(train_path), 'held_gram': hash_file(held_path),
               'source_sha256': hash_file(Path(__file__)),
               'choices': {'original_producer_kl':old, 'quantized_producer_kl':kl,
                           'quantized_producer_post_o':choices[selected_index].astype(int).tolist(),
                           'held_oracle':choices[oracle_index].astype(int).tolist()},
               'results': {name:{split:{'pooled_relative_error':float(pooled(errors,norms)[index(choice)]),
                                         'by_window':errors[:,index(choice)].tolist()}
                                 for split,errors,norms in (('train',train_errors,train_norm),('held',held_errors,held_norm))}
                           for name,choice in (('original_producer_kl',old),('quantized_producer_kl',kl),
                                               ('quantized_producer_post_o',choices[selected_index].astype(int).tolist()),
                                               ('held_oracle',choices[oracle_index].astype(int).tolist()))},
               'cross_check': {'train_selected_is_global_minimum':bool(np.isclose(pooled(train_errors,train_norm)[selected_index],pooled(train_errors,train_norm).min())),
                               'same_base_zero_error':train_errors[:,0].tolist()}}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'choices':receipt['choices'],'results':receipt['results']},indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--split', choices=('train','validation'))
    parser.add_argument('--train',type=Path)
    parser.add_argument('--held',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    if args.split:
        capture_gram(args.split,args.output)
    else:
        select(args.train,args.held,args.output)
