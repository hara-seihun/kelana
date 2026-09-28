#!/usr/bin/env python3
"""Bind committed small result to its scripts, model, capture and saved candidate bytes."""
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/tied-factors')
HEAD=Path('/path/to/workspace/data/kelana-subbit/tied-head')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def receipt(name,image,source):
    r=json.loads((DATA/name).read_text())
    if r['image_sha256']!=sha(DATA/image) or r['source_sha256']!=sha(HERE/source):
        raise ValueError(f'{name} does not identify saved image and source')
    if 'model_sha256' in r and r['model_sha256']!=sha(MODEL/'model.safetensors'):
        raise ValueError('model differs')
    return r


def run():
    b=json.loads((DATA/'basis.json').read_text())
    if b['source_sha256']!=sha(HERE/'fit.py') or b['basis_sha256']!=sha(DATA/'basis.npz'):
        raise ValueError('factor basis receipt differs')
    shards=[receipt(f'shard{i}.json',f'shard{i}.npz','fit.py') for i in range(8)]
    if any(s['basis_sha256']!=b['basis_sha256'] for s in shards):raise ValueError('factor shards differ')
    factor=receipt('signed64.json','signed64.npz','evaluate.py')
    mixed=receipt('mixed256.json','mixed256.npz','mixed.py')
    if factor['shard_receipts']!=[sha(DATA/f'shard{i}.json') for i in range(8)]:
        raise ValueError('factor shard receipts differ')
    diagnostics=json.loads((DATA/'diagnostics.json').read_text())
    if diagnostics['source_sha256']!=sha(HERE/'diagnostics.py') or diagnostics['mixed_image_sha256']!=mixed['image_sha256']:
        raise ValueError('diagnostics differ')
    qualities={}
    for keep in (2048,2560,2816):
        r=json.loads((DATA/f'quality{keep}.json').read_text())
        if (r['image_sha256']!=factor['image_sha256'] or r['source_sha256']!=sha(HERE/'evaluate.py')
            or r['exact_image_sha256']!=sha(DATA/f'factor-exact{keep}.npz')):
            raise ValueError('factor quality differs')
        qualities[str(keep)]={'exact_image_sha256':r['exact_image_sha256'],
            'payload_bytes':r['payload_bytes'],'bits_per_tied_weight':r['bits_per_tied_weight'],
            'head':r['head'],'held_embedding_weighted_rms':r['held_embedding_weighted_rms'],
            'held_rare_only_embedding_weighted_rms':r['held_rare_only_embedding_weighted_rms'],
            'held_validation_token_exact_coverage':r['held_validation_token_exact_coverage']}
    m=json.loads((DATA/'mixed-quality.json').read_text())
    if m['image_sha256']!=mixed['image_sha256'] or m['source_sha256']!=sha(HERE/'mixed.py'):
        raise ValueError('mixed quality differs')
    prior=json.loads((HEAD/'evaluate256.json').read_text())['plans']['2560']
    scalar={str(n):json.loads((HEAD/f'rtn{n}.json').read_text()) for n in (2,4)}
    result={'format':'qwen3-tied-factors-result/1','capture_sha256':sha(HEAD/'final-head.npz'),
            'frequency_sha256':sha(HEAD/'frequency.npz'),
            'model_sha256':sha(MODEL/'model.safetensors'),
            'factor_image_sha256':factor['image_sha256'],'mixed_image_sha256':mixed['image_sha256'],
            'factor':qualities,'mixed':{k:m[k] for k in ('payload_bytes','bits_per_tied_weight','held_head',
                 'held_embedding_weighted_rms','held_compressed_row_embedding_weighted_rms',
                 'held_token_coverage_exact','held_token_coverage_rt4','held_gold_exact','held_gold_rt4')},
            'original_codebook_exact2560':{'paid_bytes':prior['train_fitted_rare_head']['paid_bytes'],
                'bits_per_tied_weight':prior['train_fitted_rare_head']['bits_per_tied_weight'],
                'head':{k:prior['train_fitted_rare_head'][k] for k in ('nll','mean_kl_reference_to_candidate','top_token_matches')},
                'held_embedding_weighted_rms':prior['validation_frequency_weighted_embedding_relative_rms']},
            'scalar_controls':{n:{'bits_per_tied_weight':r['bits_per_tied_weight'],
                'head':{k:r['head'][k] for k in ('nll','mean_kl_reference_to_candidate','top_token_matches')},
                'held_embedding_weighted_rms':r['validation_frequency_weighted_embedding_relative_rms']}
                for n,r in scalar.items()},
            'rare':{k:diagnostics[k] for k in ('baseline','mixed','baseline_rare_only_embedding_weighted_rms',
                'mixed_nonexact_nonrt4_embedding_weighted_rms')},
            'custody':{name:sha(DATA/name) for name in ('basis.json','signed64.json','mixed256.json','diagnostics.json',
                'quality2048.json','quality2560.json','quality2816.json','mixed-quality.json')}}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'factor_image':factor['image_sha256'],'mixed_image':mixed['image_sha256'],
        'result_sha256':sha(HERE/'results.json')}))

if __name__=='__main__':run()
