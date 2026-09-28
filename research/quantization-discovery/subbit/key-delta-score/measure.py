#!/usr/bin/env python3
"""Measure a self-contained temporal key code and its direct score recurrence."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('key_delta_parent', ROOT/'key-delta-cache/measure.py')
parent_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent_module)
paid, finite = parent_module.paid, parent_module.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def recurrence(codes, query, width):
    """Serial FP32 block score scan, no reconstructed absolute vector keys."""
    direct = (codes.float() * query[:, None, :]).sum(-1)
    delta = codes[:, 1:] - codes[:, :-1]
    assert torch.equal(delta[:, 1:] + codes[:, 1:-1], codes[:, 2:])
    scores = torch.empty_like(direct)
    for start in range(0, codes.shape[1], width):
        end = min(start + width, codes.shape[1])
        score = direct[:, start]
        scores[:, start] = score
        for index in range(start + 1, end):
            score = score + (delta[:, index - 1].float() * query).sum(-1)
            scores[:, index] = score
    return direct, scores


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    suffix = f'layer{args.layer:02d}'
    parent_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    parent = json.loads(parent_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    q, k = paid.projected(x, weights, gamma)
    codes, queries = [], []
    for group, row in enumerate(parent['groups']):
        idx = row['mask'] + [i + 64 for i in row['mask']]
        selected = parent['group_arms_selected_by_train']['coordinate'][group]
        arm = row['int4'][selected+'_coordinate']
        center = torch.tensor(row['train_center']).reshape(1,1,1,32) if selected == 'centered' else 0
        step = torch.tensor(arm['steps']).reshape(1,1,1,32)
        codes.append(((k[:,group:group+1,:,idx]-center)/step).round().clamp(-7,7).to(torch.int32))
        queries.append(q[:,2*group:2*group+2,:,idx] * step)
    c = torch.cat(codes, dim=1)
    query = torch.cat(queries, dim=1)
    width = 32
    blocks = c.reshape(4,8,256//width,width,32)
    differences = blocks[:,:,:,1:] - blocks[:,:,:,:-1]
    escapes = (differences < -3) | (differences > 3)
    assert int(differences.abs().max()) <= 14
    escapes_per_block = escapes.sum((-1,-2))
    # One independent five-bit signed delta for every escape. No prior code
    # is consulted while reading the compressed block.
    block_bits = 32*4 + (width-1)*32*3 + 5*escapes_per_block
    aligned = int(((block_bits+7)//8).sum())
    logical = int(block_bits.sum())
    scan = []
    for window in range(4):
        max_diff = 0.
        mean_diff = 0.
        kl_sum = 0.
        tested = 0
        for group in range(8):
            for head in range(2):
                for pos in (31,63,127,255):
                    # Query scale includes the head normalization from the
                    # parent; center scores are a softmax-invisible constant.
                    qrow = query[window,2*group+head,pos].reshape(1,32)
                    d, s = recurrence(c[window,group].reshape(1,256,32), qrow, width)
                    d, s = d[0,:pos+1], s[0,:pos+1]
                    error = (d-s).abs()
                    max_diff = max(max_diff, float(error.max()))
                    mean_diff += float(error.mean())
                    p = (d.double()/math.sqrt(128)).log_softmax(-1)
                    r = (s.double()/math.sqrt(128)).log_softmax(-1)
                    kl_sum += float((p.exp()*(p-r)).sum())
                    tested += 1
        scan.append({'window':window, 'query_rows':tested, 'max_abs_score_difference':max_diff,
                     'mean_abs_score_difference':mean_diff/tested, 'mean_direct_to_scan_kl':kl_sum/tested})
    report = {
        'layer':args.layer,
        'contract':'Qwen3-0.6B four inspected original-producer validation windows; frozen paid Q/K and selected signed-nibble K codes; 32-key restarts; signed-five-bit escape difference; four causal query positions/window/head; FP32 serial block score scan against direct FP32 per-key dot',
        'bytes':{'direct_nibble':4*256*8*32*4//8, 'static_mixed_112':4*256*112,
                 'delta_logical_ceil_bytes':(logical+7)//8, 'delta_logical_bits':logical,
                 'delta_byte_aligned':aligned, 'delta_aligned_plus_four_byte_offsets':aligned+4*4*8*(256//width)},
        'transitions':int(differences.numel()), 'escapes':int(escapes.sum()),
        'escapes_per_block_max':int(escapes_per_block.max()), 'escapes_per_block_mean':float(escapes_per_block.float().mean()),
        'scan':scan,
        'cost':{'score_dot_coordinates_per_key_both_heads':512,
                'extra_scalar_prefix_additions_per_32_key_block_both_heads':62,
                'extra_query_weighted_sparse_escape_products_per_key_both_heads_mean':float(64*escapes.float().mean()),
                'absolute_key_vector_reads_or_reconstructions_per_query':0,
                'metadata_four_byte_offsets_per_block_per_group':1},
        'source_sha256':sha(Path(__file__)), 'parent_source_sha256':sha(ROOT/'key-delta-cache/measure.py'),
        'parent_receipt_sha256':sha(DATA/f'key-delta-cache/{suffix}.json'),
        'nibble_receipt_sha256':sha(parent_path), 'prior_sha256':sha(prior_path),
        'model_sha256':sha(finite.MODEL), 'capture_sha256':sha(finite.value_fit.CAPTURES/f'{suffix}.npz'),
        'paid_q_sha256':sha(q_path), 'paid_k_sha256':sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'layer':args.layer,'bytes':report['bytes'], 'escapes':report['escapes'], 'scan':scan}))

if __name__ == '__main__':
    main()
