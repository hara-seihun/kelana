#!/usr/bin/env python3
"""Direct scores from per-block mode-centered signed-nibble key codes."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parent.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('key_delta_parent', ROOT/'key-delta-cache/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
paid, finite = parent.paid, parent.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def fit_anchors(blocks):
    # Minimize the exact escape count independently for each block/coordinate.
    candidates = torch.arange(-7, 8, dtype=torch.int32)
    diff = blocks[..., None] - candidates
    escapes = (diff.abs() > 3).sum(dim=-3)
    # A tie picks the smaller absolute center; this cannot affect rate.
    costs = escapes * 32 + candidates.abs()
    chosen = candidates[costs.argmin(-1)]
    residual = blocks - chosen.unsqueeze(-2)
    return chosen, residual


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer', type=int, choices=(0, 14), required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    torch.set_num_threads(4)
    suffix = f'layer{args.layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        weights = {n:model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    x = finite.load_capture(args.layer, 'validation').reshape(4,256,1024)
    q, k = paid.projected(x, weights, gamma)
    codes, queries = [], []
    for group, row in enumerate(nibble['groups']):
        idx = row['mask'] + [i+64 for i in row['mask']]
        selected = nibble['group_arms_selected_by_train']['coordinate'][group]
        arm = row['int4'][selected+'_coordinate']
        center = torch.tensor(row['train_center']).reshape(1,1,1,32) if selected == 'centered' else 0
        step = torch.tensor(arm['steps']).reshape(1,1,1,32)
        codes.append(((k[:,group:group+1,:,idx]-center)/step).round().clamp(-7,7).to(torch.int32))
        queries.append(q[:,2*group:2*group+2,:,idx]*step)
    c = torch.cat(codes,1)
    query = torch.cat(queries,1)
    widths = (8,16,32,64,128,256)
    arms = []
    for width in widths:
        blocks = c.reshape(4,8,256//width,width,32)
        for policy in ('mode', 'first'):
            if policy == 'mode':
                anchors, residual = fit_anchors(blocks)
            else:
                anchors = blocks[...,0,:]
                residual = blocks - anchors.unsqueeze(-2)
            assert int(residual.abs().max()) <= 14
            # First-key anchor is itself stored in four bits, not twice in the residual stream.
            encoded = residual if policy == 'mode' else residual[...,1:,:]
            escape = encoded.abs() > 3
            bits = 128 + encoded.shape[-2]*32*3 + 5*escape.sum((-1,-2))
            aligned = int(((bits+7)//8).sum())
            total = aligned + 4*4*8*(256//width)
            by_window = [int(((bits[w]+7)//8).sum())+4*8*(256//width) for w in range(4)]
            arms.append({'width':width,'policy':policy,'escapes':int(escape.sum()),'residuals':int(escape.numel()),
                         'logical_bits':int(bits.sum()),'byte_aligned_plus_offsets':total,
                         'bytes_per_token':total/1024,'window_bytes':by_window,
                         'anchor_score_products_per_key_both_heads':64/width,
                         'residual_score_products_per_key_both_heads':64*(encoded.shape[-2]/width),
                         'escape_correction_products_per_key_both_heads':float(64*escape.float().mean())*encoded.shape[-2]/width})
    width = 32
    blocks = c.reshape(4,8,8,width,32)
    anchor, residual = fit_anchors(blocks)
    witness = []
    for w in range(4):
        max_error = 0.
        kl_total = 0.
        rows = 0
        for group in range(8):
            for head in range(2):
                for pos in (31,63,127,255):
                    u = query[w,2*group+head,pos]
                    direct = (c[w,group,:pos+1].float()*u).sum(-1)
                    block_score = (anchor[w,group].float()*u).sum(-1)[:,None]
                    decoded = (block_score+(residual[w,group].float()*u).sum(-1)).reshape(256)[:pos+1]
                    max_error = max(max_error,float((direct-decoded).abs().max()))
                    a = (direct.double()/math.sqrt(128)).log_softmax(-1)
                    b = (decoded.double()/math.sqrt(128)).log_softmax(-1)
                    kl_total += float((a.exp()*(a-b)).sum())
                    rows += 1
        witness.append({'window':w,'rows':rows,'max_fp32_score_difference':max_error,
                        'mean_direct_to_block_softmax_kl':kl_total/rows})
    report = {'layer':args.layer, 'contract':'Four inspected original-producer validation windows, frozen paid Q/K and signed-nibble K codes; independent 32-key block anchors fit to the validation codes as an online encoder, never a train-set quality decision; FP32 direct-score replay',
              'arms':arms,'direct_nibble_bytes':131072,'static_mixed_bytes':114688,
              'temporal_score_bytes':json.loads((DATA/f'key-delta-score/{suffix}.json').read_text())['bytes']['delta_aligned_plus_four_byte_offsets'],
              'score_replay':witness,
              'source_sha256':sha(Path(__file__)), 'model_sha256':sha(finite.MODEL),
              'capture_sha256':sha(finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'paid_q_sha256':sha(q_path),'paid_k_sha256':sha(k_path),
              'nibble_receipt_sha256':sha(nibble_path),'prior_sha256':sha(prior_path),
              'temporal_receipt_sha256':sha(DATA/f'key-delta-score/{suffix}.json')}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'layer':args.layer,'arms':arms,'score_replay':witness}))


if __name__ == '__main__':
    main()
