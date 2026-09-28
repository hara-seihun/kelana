#!/usr/bin/env python3
"""Split exact tied rows between embedding frequency and head softmax error."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp
from safetensors import safe_open
import torch
import evaluate
import codec

HERE=Path(__file__).resolve().parent
DATA=evaluate.DATA
MODEL=evaluate.MODEL


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def allocate(k,mode):
    with np.load(DATA/'final-head.npz') as z:hidden=z['train_hidden'][::8].copy()
    with np.load(DATA/'frequency.npz') as z:freq=z['train'].copy()
    with np.load(DATA/f'codebook{k}.npz') as z:
        labels=codec.unpack(z['labels'],64,int(np.log2(k)))
        scales=z['scales'].copy();code=z['code'].copy();unit=float(z['unit'])
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as f:
        w=f.get_tensor('model.embed_tokens.weight')
        source=w.float().numpy().copy()
        bits=w.view(torch.int16).numpy().copy().view(np.uint16)
    original=hidden@source.T
    approximate=evaluate.respond(hidden,labels,scales,code,unit)
    po=np.exp(original-logsumexp(original,axis=1)[:,None])
    pa=np.exp(approximate-logsumexp(approximate,axis=1)[:,None])
    if mode=='mixed':
        importance=np.mean(abs(po-pa),axis=0)
        criterion='mean absolute train softmax probability difference'
    elif mode=='loss':
        tokens_path=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')
        with np.load(tokens_path) as z:
            gold=z['train'][:4,np.arange(0,255,8)+1].reshape(-1)
        logz=logsumexp(approximate,axis=1)
        new_exp=np.exp(np.clip(original-logz[:,None],-80,50))
        old_exp=np.exp(approximate-logz[:,None])
        change=np.log1p(np.maximum(-0.99999999,new_exp-old_exp))
        importance=-change.mean(0)
        np.add.at(importance,gold,(original[np.arange(len(gold)),gold]-approximate[np.arange(len(gold)),gold])/len(gold))
        criterion='mean train cross-entropy gain from replacing one approximate row by its exact row at a time'
    else:
        raise ValueError(mode)
    freq_order=np.lexsort((np.arange(evaluate.ROWS),-freq))
    freq_keep=freq_order[:1024]
    importance[freq_keep]=-np.inf
    head_order=np.lexsort((np.arange(evaluate.ROWS),-importance))
    chosen=np.concatenate([freq_keep,head_order[:1024]])
    if len(np.unique(chosen))!=2048:raise ValueError('duplicate exact rows')
    selected_bits=bits[chosen]
    image=DATA/f'{mode}{k}.npz'
    np.savez_compressed(image,ids=chosen.astype('<u4'),bf16_bits=selected_bits)
    record={'format':'qwen3-tied-mixed-rows/1','k':k,
        'source_sha256':sha(Path(__file__)),
        'evaluate_source_sha256':sha(Path(evaluate.__file__)),
        'capture_sha256':sha(DATA/'final-head.npz'),
        'frequency_sha256':sha(DATA/'frequency.npz'),
        'codebook_sha256':sha(DATA/f'codebook{k}.npz'),
        'train_input_positions':'first four train windows, positions 0,8,...,248; 128 observations',
        'selection':'top 1024 train-corpus frequent IDs, plus top 1024 IDs by '+criterion+'; no validation input used',
        'frequency_rows':1024,'head_error_rows':1024,
        'image_sha256':sha(image),'paid_ids_bytes':int(chosen.astype('<u4').nbytes),
        'paid_exact_bf16_bytes':int(selected_bits.nbytes),
        'selected_ids_sha256':hashlib.sha256(chosen.astype('<u4').tobytes()).hexdigest()}
    (DATA/f'{mode}{k}.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({'k':k,'image_sha256':record['image_sha256'],
                      'train_token_coverage':float(freq[chosen].sum()/freq.sum())}))


if __name__=='__main__':
    if len(sys.argv)!=3 or int(sys.argv[1]) not in (64,256) or sys.argv[2] not in ('mixed','loss'):
        raise SystemExit('allocate.py K mixed | loss')
    allocate(int(sys.argv[1]),sys.argv[2])
