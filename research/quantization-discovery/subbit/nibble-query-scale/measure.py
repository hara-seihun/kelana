#!/usr/bin/env python3
"""Select a single signed-nibble query dot from frozen key-code second moments."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
spec = importlib.util.spec_from_file_location('nibble_query_reference', ROOT/'nibble-query-lowering/measure.py')
nibble = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nibble)

DATA = nibble.DATA
paid = nibble.paid
finite = nibble.finite
# Fixed before looking at validation outcomes. Every candidate has the same one-dot key loop.
RATIOS = (.5, .625, .75, .875, 1., 1.125, 1.25, 1.5)


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def score(qcodes, codes, scale):
    return (qcodes @ codes.transpose(-1, -2))*scale/math.sqrt(128)


def candidate_queries(prepared, covariance):
    maxabs = prepared.abs().amax(-1, keepdim=True).clamp_min(1e-20)
    base = maxabs/7
    ratios = torch.tensor(RATIOS, dtype=torch.float64).reshape(-1, 1, 1, 1, 1)
    step = base.unsqueeze(0)*ratios
    iq = (prepared.unsqueeze(0)/step).round().clamp(-7, 7)
    error = iq*step - prepared.unsqueeze(0)
    diagonal = covariance.diag()
    diagonal_cost = (error.square()*diagonal).sum(-1)
    full_cost = torch.einsum('...i,ij,...j->...', error, covariance, error)
    result = {}
    for name, cost in [('diagonal', diagonal_cost), ('covariance', full_cost)]:
        choice = cost.argmin(0).unsqueeze(0).unsqueeze(-1)
        result[name] = (iq.gather(0, choice.expand(1, *iq.shape[1:])).squeeze(0), step.gather(0, choice).squeeze(0),
                        torch.bincount(choice.reshape(-1), minlength=len(RATIOS)).tolist())
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    prior = json.loads(prior_path.read_text())
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {name: model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    train = paid.projected(finite.load_capture(args.layer, 'train').reshape(8, 256, 1024), weights, gamma)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    q, k = paid.projected(held_x, weights, gamma)
    tq, tk = paid.projected(held_x, original, original['k_norm'])
    by_group = []
    for g, group in enumerate(parent['groups']):
        mask = group['mask']
        idx = mask + [p+64 for p in mask]
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        steps = torch.tensor(group['int4'][arm]['steps'], dtype=torch.float64)
        center = torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*len(idx), dtype=torch.float64)
        train_codes = ((train[1][:,g:g+1,:,idx].double()-center)/steps).round().clamp(-7,7).reshape(-1,32)
        # A score is insensitive to a constant per-key shift. Use centered key-code covariance.
        train_codes = train_codes - train_codes.mean(0)
        covariance = train_codes.T @ train_codes / train_codes.shape[0]
        qg = q[:, 2*g:2*g+2, :, idx].double()
        codes = ((k[:,g:g+1,:,idx].double()-center)/steps).round().clamp(-7,7)
        prepared = qg*steps
        base_step = prepared.abs().amax(-1,keepdim=True).clamp_min(1e-20)/7
        q4 = (prepared/base_step).round().clamp(-7,7)
        q8_step = prepared.abs().amax(-1,keepdim=True).clamp_min(1e-20)/119
        q8 = (prepared/q8_step).round().clamp(-119,119)
        choices = candidate_queries(prepared, covariance)
        teacher = nibble.cache.scores(tq[:,2*g:2*g+2],tk[:,g:g+1],list(range(256)))
        floating = score(prepared,codes,torch.ones_like(base_step))
        entries = {}
        for name, (iq, step, hist) in {
            'max_q4': (q4,base_step,None), 'diagonal_q4': choices['diagonal'],
            'covariance_q4': choices['covariance'], 'two_dot_q8': (q8,q8_step,None)
        }.items():
            scored = score(iq,codes,step)
            entries[name] = {'kl_by_window': nibble.causal_kl(scored,teacher).tolist(),
                             'mean_score_error_by_window': (scored-floating).abs().mean((-1,-2,-3)).tolist()}
            if hist is not None:
                entries[name]['ratio_choices'] = hist
        entries['floating'] = {'kl_by_window': nibble.causal_kl(floating,teacher).tolist()}
        entries['arm'] = arm
        by_group.append(entries)
        print('group',g,'mean KL', {name: round(sum(entry['kl_by_window'])/4,6) for name,entry in entries.items() if isinstance(entry,dict) and 'kl_by_window' in entry},flush=True)
    aggregate = {name:[sum(group[name]['kl_by_window'][w] for group in by_group)/8 for w in range(4)]
                 for name in ('floating','max_q4','diagonal_q4','covariance_q4','two_dot_q8')}
    result = {'layer':args.layer, 'ratios': RATIOS, 'groups':by_group, 'aggregate_by_window':aggregate,
              'aggregate_mean':{k:sum(v)/4 for k,v in aggregate.items()},
              'cost':{'stored_key_bytes_per_token_layer':128, 'single_dot_products_per_cached_key_both_heads':512,
                      'two_dot_products_per_cached_key_both_heads':1024,
                      'diagonal_selection_candidate_quantizations_per_query_layer':16*32*len(RATIOS),
                      'diagonal_selection_candidate_error_weights_per_query_layer':16*32*len(RATIOS),
                      'covariance_selection_additional_multiply_terms_per_query_layer':16*32*32*len(RATIOS),
                      'diagonal_fp16_second_moment_bytes_per_layer':8*32*2,
                      'key_norm_producer_rows':1024, 'native_latency_measured':False},
              'source_sha256':digest(Path(__file__)), 'parent_sha256':digest(parent_path),'prior_sha256':digest(prior_path),
              'model_sha256':digest(finite.MODEL), 'capture_sha256':digest(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256':digest(q_path),'paid_k_sha256':digest(k_path)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('aggregate', result['aggregate_mean'],flush=True)


if __name__ == '__main__':
    main()
