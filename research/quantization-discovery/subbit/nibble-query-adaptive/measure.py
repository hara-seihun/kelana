#!/usr/bin/env python3
"""Query-dependent residual selection for the frozen paid signed-nibble K score."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')
sparse = None


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    global sparse
    sparse = __import__('importlib').util
    spec = sparse.spec_from_file_location('query_sparse', ROOT/'nibble-query-sparse/measure.py')
    sparse = sparse.module_from_spec(spec)
    spec.loader.exec_module(sparse)
    lower, cache, paid, finite = sparse.lower, sparse.cache, sparse.paid, sparse.finite
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    fixed_path = DATA/f'nibble-query-sparse/layer{args.layer:02d}.json'
    parent, prior, fixed = (json.loads(p.read_text()) for p in (parent_path, prior_path, fixed_path))
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {name: model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    captures = {}
    for split, nw in (('train', 8), ('validation', 4)):
        x = finite.load_capture(args.layer, split).reshape(-1, 256, 1024)[:nw]
        q, k = paid.projected(x, weights, gamma)
        tq, tk = paid.projected(x, original, original['k_norm'])
        captures[split] = q, k, tq, tk
    rows = []
    sizes = (8, 16, 24)
    for g, group in enumerate(parent['groups']):
        idx = group['mask']+[p+64 for p in group['mask']]
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*32, dtype=torch.float64)
        qt, kt, _, _ = captures['train']
        code_train = ((kt[:,g:g+1,:,idx].double()-center)/steps).round().clamp(-7, 7)
        # Variance is invariant to a shared key translation; train-only moments.
        moment = code_train.var((0,1,2), unbiased=False).clamp_min(1e-12)
        # Spread the train-ranked coordinates across four physical eight-coordinate
        # tiles. Offline permutation changes neither code bytes nor dot values.
        ranked = fixed['groups'][g]['selected_coordinate_order']
        balanced = [ranked[t::4] for t in range(4)]
        tile_indices = torch.tensor(balanced, dtype=torch.long)
        row = {'group':g, 'key_arm':arm, 'train_code_variance':moment.tolist(),
               'balanced_tile_coordinates':balanced, 'splits':{}}
        for split in ('train','validation'):
            q, k, tq, tk = captures[split]
            q = q[:,2*g:2*g+2,:,idx].double()
            code = ((k[:,g:g+1,:,idx].double()-center)/steps).round().clamp(-7,7)
            teacher = cache.scores(tq[:,2*g:2*g+2], tk[:,g:g+1], list(range(256)))
            a = q*steps
            d = a.abs().amax(-1, keepdim=True).clamp_min(1e-20)/7
            z = (a/d).round().clamp(-7,7)
            r = ((a/d-z)*16).round().clamp(-8,7)
            base = (z @ code.transpose(-1,-2))*d/math.sqrt(128)
            full = base+(r @ code.transpose(-1,-2))*d/(16*math.sqrt(128))
            result = {'one_dot':lower.causal_kl(base,teacher).tolist(), 'full':lower.causal_kl(full,teacher).tolist()}
            residual = (r*d/16).square()*moment
            # Choose query coordinates before reading any key. This is an optimistic
            # arithmetic-only lowering: the actual key gather and selection are charged separately.
            order = residual.argsort(-1, descending=True)
            tile_energy = residual.reshape(*residual.shape[:-1],4,8).sum(-1)
            tiles = tile_energy.argsort(-1, descending=True)
            balanced_energy = residual[...,tile_indices].sum(-1)
            balanced_tiles = balanced_energy.argsort(-1, descending=True)
            for m in sizes:
                coord_mask = torch.zeros_like(r).scatter_(-1,order[...,:m],1)
                tile_mask = torch.zeros_like(tile_energy).scatter_(-1,tiles[...,:m//8],1)
                tile_mask = tile_mask.repeat_interleave(8,-1)
                balanced_mask = torch.zeros_like(balanced_energy).scatter_(-1,balanced_tiles[...,:m//8],1)
                balanced_coord_mask = torch.zeros_like(r)
                balanced_coord_mask.scatter_add_(-1, tile_indices.flatten().expand(*r.shape[:-1],32),
                                                 balanced_mask.unsqueeze(-1).expand(*r.shape[:-1],4,8).reshape_as(r))
                for label, mask in (('adaptive',coord_mask), ('tile',tile_mask), ('balanced_tile',balanced_coord_mask)):
                    score = base+((r*mask) @ code.transpose(-1,-2))*d/(16*math.sqrt(128))
                    result[f'{label}_{m}'] = lower.causal_kl(score,teacher).tolist()
                result[f'fixed_{m}'] = fixed['groups'][g][split][f'partial_{m}']
            row['splits'][split] = result
        rows.append(row)
        print(args.layer, g, {key:round(sum(v)/4,6) for key,v in row['splits']['validation'].items()},flush=True)
    keys = rows[0]['splits']['validation']
    summary = {split:{key:[sum(row['splits'][split][key][w] for row in rows)/8 for w in range(n)] for key in keys}
               for split,n in (('train',8),('validation',4))}
    result = {'layer':args.layer, 'domain':'frozen paid Q/K, original-producer 256-token captures, signed-nibble keys; train key-code variance and query-only dynamic selection',
              'rows':rows, 'aggregate_by_window':summary,
              'mean':{split:{key:sum(v)/len(v) for key,v in summary[split].items()} for split in summary},
              'cost':{'base_products_per_key_layer':512,'correction_products_per_key_layer':{str(m):16*m for m in sizes},
                      'adaptive_selection':'32 weighted residual magnitudes, selection of m coordinates per head/group/query, scattered m-key-coordinate gather at every cached key',
                      'tile_selection':'four eight-coordinate energy reductions and top 1/2/3 tile selection per head/group/query; dynamic tile reads; balanced_tile permutes coordinates offline by train-only rank round-robin',
                      'native_time_measured':False},
              'sha256':{name:digest(path) for name,path in {'source':Path(__file__),'parent':parent_path,'prior':prior_path,'fixed':fixed_path,
                        'model':finite.MODEL,'capture':finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz','paid_q':q_path,'paid_k':k_path}.items()}}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('mean',result['mean']['validation'],flush=True)


if __name__ == '__main__':
    main()
