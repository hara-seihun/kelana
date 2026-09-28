#!/usr/bin/env python3
"""Price exact temporal differential coding of the frozen paid nibble K cache."""
import argparse
import hashlib
import json
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')
import importlib.util
spec = importlib.util.spec_from_file_location('parent_measure', ROOT/'key-nibble-cache/measure.py')
parent_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent_module)
paid = parent_module.paid
finite = parent_module.finite


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def count(codes):
    # The eighth three-bit symbol is an escape. Its four-bit payload is the
    # absolute signed nibble, so decoding remains exact even after a miss.
    delta = (codes[:, :, 1:] - codes[:, :, :-1]).to(torch.int32)
    hist = torch.bincount((delta + 14).flatten(), minlength=29)
    central = hist.sum() - hist[11:18].sum()  # seven changes -3,...,+3
    oracle = hist.sum() - hist.topk(7).values.sum()
    n = int(hist.sum())
    return {'changes': n, 'central_escape': int(central), 'central_fraction': central.item()/n,
            'best_seven_escape': int(oracle), 'best_seven_fraction': oracle.item()/n,
            'histogram_minus14_to_plus14': hist.tolist()}


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
    parent = json.loads(parent_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights = dict(original)
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    x = finite.load_capture(args.layer, 'validation').reshape(4,256,1024)
    _, k = paid.projected(x, weights, gamma)
    group_codes = []
    groups = []
    for g, row in enumerate(parent['groups']):
        idx = row['mask'] + [i+64 for i in row['mask']]
        selected = parent['group_arms_selected_by_train']['coordinate'][g]
        arm = row['int4'][selected+'_coordinate']
        center = torch.tensor(row['train_center']).reshape(1,1,1,32) if selected == 'centered' else 0
        step = torch.tensor(arm['steps']).reshape(1,1,1,32)
        c = ((k[:,g:g+1,:,idx]-center)/step).round().clamp(-7,7).to(torch.int32)
        group_codes.append(c)
        groups.append({'group':g, 'selected':selected, **count(c),
                       'windows': [count(c[w:w+1]) for w in range(4)]})
    all_codes = torch.cat(group_codes,dim=1)
    total = count(all_codes)
    blocked = {}
    for width in (8,32,256):
        parts = all_codes.reshape(4,8,256//width,width,32).permute(0,2,1,3,4)
        packed = parts.reshape(4*(256//width),8,width,32)
        statistics = count(packed)
        block_anchors = 4*(256//width)*8*32*4
        block_deltas = 4*(256-256//width)*8*32*3
        differences = parts[:,:,:,1:,:] - parts[:,:,:,:-1,:]
        escapes_per_block = ((differences < -3) | (differences > 3)).sum((-1,-2))
        block_bits = 32*4 + (width-1)*32*3 + 4*escapes_per_block
        byte_aligned = int(((block_bits + 7)//8).sum())
        address_bytes = int(block_bits.numel())*4
        blocked[str(width)] = {'central_escape_fraction': statistics['central_fraction'],
                               'bits': block_anchors+block_deltas+4*statistics['central_escape'],
                               'anchors':block_anchors,'deltas':block_deltas,
                               'escapes':statistics['central_escape'],
                               'byte_aligned_bytes':byte_aligned,
                               'bytes_with_four_byte_block_offsets':byte_aligned+address_bytes}
    # Four 256-token windows, eight groups of 32 signed nibble coordinates.
    windows, tokens, groups_n, dimensions = 4,256,8,32
    ordinary_bits = windows*tokens*groups_n*dimensions*4
    anchors = windows*groups_n*dimensions*4
    delta_bits = windows*(tokens-1)*groups_n*dimensions*3
    def cost(escapes):
        return anchors + delta_bits + 4*escapes
    report = {'layer':args.layer,'contract':'frozen original-producer paid Q/K post-RoPE signed nibble codes, four inspected validation windows; exact sequential delta cache with seven inline signed deltas and absolute nibble escape',
              'groups':groups,'total':total,'block_restart':blocked,
              'bits':{'ordinary':ordinary_bits,'anchor':anchors,'three_bit_deltas':delta_bits,
                      'central_exact':cost(total['central_escape']), 'best_seven_held_oracle_exact':cost(total['best_seven_escape'])},
              'rate':{'central_bits_per_code':cost(total['central_escape'])/(windows*tokens*groups_n*dimensions),
                      'best_seven_held_oracle_bits_per_code':cost(total['best_seven_escape'])/(windows*tokens*groups_n*dimensions),
                      'break_even_escape_fraction':0.25},
              'cost_contract':'Three-bit delta plus four-bit absolute nibble on escapes; sequential previous-code dependency on cache writes and reads; direct dot would reconstruct signed nibbles in registers; no GPU instruction or full-model timing.',
              'source_sha256':digest(Path(__file__)), 'parent_sha256':digest(parent_path),
              'prior_sha256':digest(prior_path),'model_sha256':digest(finite.MODEL),
              'capture_sha256':digest(finite.value_fit.CAPTURES/f'{suffix}.npz'), 'paid_k_sha256':digest(k_path)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'layer':args.layer,'groups':[(g['group'],round(g['central_fraction'],4),round(g['best_seven_fraction'],4)) for g in groups], 'bits':report['bits'],'rate':report['rate'],'block_restart':blocked}))

if __name__ == '__main__':
    main()
