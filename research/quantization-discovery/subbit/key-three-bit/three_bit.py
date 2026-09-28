#!/usr/bin/env python3
"""Train a three-bit post-RoPE key coordinate and replay its integer score consumer."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cache = imported(ROOT/'key-nibble-cache/measure.py', 'key_cache')
lowering = imported(ROOT/'nibble-query-lowering/measure.py', 'query_lowering')
paid = cache.paid
finite = cache.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def codes(k, origin, step):
    # The half-step is a constant key translation, invisible to causal softmax.
    return ((k-origin)/step - 0.5).round().clamp(-4, 3)


def query_scores(q, c, step):
    prepared = q*step
    delta = prepared.abs().amax(-1, keepdim=True).clamp_min(1e-20)/119
    iq = (prepared/delta).round().clamp(-119, 119)
    lo = (iq+8).remainder(16)-8
    hi = (iq-lo)/16
    assert torch.equal(iq, lo+16*hi)
    integer = iq @ c.transpose(-1, -2)
    assert torch.equal(integer, lo @ c.transpose(-1,-2) + 16*(hi @ c.transpose(-1,-2)))
    assert integer.abs().max().item() <= 32*119*4
    return (integer * delta)/math.sqrt(128)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0,14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    suffix = f'layer{args.layer:02d}'
    parent_path = DATA/f'key-nibble-cache/{suffix}.json'
    parent = json.loads(parent_path.read_text())
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    prior = json.loads(prior_path.read_text())
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    projected = []
    for split, count in (('train',8), ('validation',4)):
        x = finite.load_capture(args.layer, split).reshape(count,256,1024)
        q,k = paid.projected(x, weights, gamma)
        tq,tk = paid.projected(x, original, original['k_norm'])
        projected.append((q,k,tq,tk))
    train, held = projected
    positions = list(range(64,256,12))
    groups = []
    for g, old in enumerate(parent['groups']):
        idx = old['mask'] + [p+64 for p in old['mask']]
        qt = train[0][:,2*g:2*g+2,:,idx]
        kt = train[1][:,g:g+1,:,idx]
        qh = held[0][:,2*g:2*g+2,:,idx].double()
        kh = held[1][:,g:g+1,:,idx].double()
        teacher_train = cache.scores(train[2][:,2*g:2*g+2],train[3][:,g:g+1],positions)
        teacher_held = cache.scores(held[2][:,2*g:2*g+2],held[3][:,g:g+1],list(range(256)))
        center = torch.tensor(old['train_center'],dtype=torch.float64).reshape(1,1,1,-1)
        candidates = []
        for name, origin in (('raw',torch.zeros_like(center)),('centered',center)):
            residual = (kt.double()-origin).abs().reshape(-1,len(idx))
            for quantile in (.99,.995,.999,1.):
                step = (torch.quantile(residual,quantile,dim=0).clamp_min(1e-8)/3.5).half().float().double().reshape(1,1,1,-1)
                ck = codes(kt.double(),origin,step)
                score = (qt.double()*step)[:, :, positions] @ ck.transpose(-1,-2)/math.sqrt(128)
                train_kl = lowering.causal_kl(score,teacher_train).mean().item() if len(positions)==256 else cache.kl(qt,ck*step,teacher_train,positions)
                candidates.append({'center':name,'quantile':quantile,'train_kl':train_kl,'steps':step.flatten().tolist()})
        choice = min(candidates,key=lambda item:item['train_kl'])
        origin = center if choice['center']=='centered' else torch.zeros_like(center)
        step = torch.tensor(choice['steps']).double().reshape(1,1,1,-1)
        c = codes(kh,origin,step)
        q_scaled = qh*step
        real_scores = q_scaled @ c.transpose(-1,-2)/math.sqrt(128)
        int_scores = query_scores(qh,c,step)
        arm = parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        old_step = torch.tensor(old['int4'][arm]['steps']).double().reshape(1,1,1,-1)
        old_origin = center if arm.startswith('centered') else torch.zeros_like(center)
        old_c = ((kh-old_origin)/old_step).round().clamp(-7,7)
        nibble_int_scores = query_scores(qh,old_c,old_step)
        def by_window(s):
            return lowering.causal_kl(s,teacher_held).tolist()
        row = {'group':g,'mask':old['mask'],'train_candidates':candidates,'selected':choice,
               'held_by_window':{'three_bit_float_query':by_window(real_scores),'three_bit_two_dot':by_window(int_scores),
                                 'nibble_two_dot':by_window(nibble_int_scores)},
               'query_score_abs_error':(int_scores-real_scores).abs().mean().item()}
        groups.append(row)
        print('group',g,'selected',choice['center'],choice['quantile'], 'held', {n:sum(v)/4 for n,v in row['held_by_window'].items()},flush=True)
    names = groups[0]['held_by_window']
    aggregate = {n:[sum(g['held_by_window'][n][w] for g in groups)/8 for w in range(4)] for n in names}
    result = {'layer':args.layer,'contract':'original-producer paid binary Q/K, 128 selected RoPE planes, full raw K norm, eight-level signed three-bit post-RoPE key; train-selected raw/centered per-coordinate FP16 steps; query int8 split in two nibble dots; real causal softmax',
              'train_windows':8,'held_windows':4,'groups':groups,'aggregate_by_window':aggregate,
              'aggregate_mean':{n:sum(v)/4 for n,v in aggregate.items()},
              'cost':{'three_bit_payload_bytes_per_token_layer':96,'nibble_payload_bytes_per_token_layer':128,
                      'three_bit_codes_per_group':32,'packed_three_bit_bytes_per_group':12,
                      'step_fp16_bytes_per_layer':512,'max_center_fp16_bytes_per_layer':512,
                      'key_quantize_rounds_per_token_layer':256,'query_step_products_per_token_layer':512,
                      'query_rounds_per_token_layer':512,'two_head_nibble_products_per_key':1024,
                      'score_scale_multiplies_per_key':16,'raw_k_norm_rows':1024,
                      'native_code_expansion_and_alignment_cost_unmeasured':True},
              'source_sha256':sha(Path(__file__)),'parent_sha256':sha(parent_path),'prior_sha256':sha(prior_path),
              'model_sha256':sha(finite.MODEL),'capture_sha256':sha(finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'paid_q_sha256':sha(q_path),'paid_k_sha256':sha(k_path)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('aggregate',result['aggregate_mean'],flush=True)


if __name__=='__main__':
    main()
