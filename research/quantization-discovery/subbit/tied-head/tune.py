#!/usr/bin/env python3
"""Train-only two-scalar rare-head calibration for an exact frequent row set."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import minimize
from scipy.special import logsumexp
import evaluate
import codec

HERE=Path(__file__).resolve().parent
DATA=evaluate.DATA
TOKENS=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def fit(k,plan):
    with np.load(DATA/'final-head.npz') as z:
        hidden=z['train_hidden'].copy()
    positions=np.arange(0,255,8)
    selected=np.concatenate([np.arange(i*256,(i+1)*256)[positions] for i in range(4)])
    inputs=hidden[selected]
    with np.load(TOKENS) as z:
        gold=z['train'][:4,positions+1].reshape(-1)
    with np.load(DATA/'frequency.npz') as z:counts=z['train'].copy()
    if plan=='mixed2048':
        with np.load(DATA/f'mixed{k}.npz') as z:common=z['ids'].copy()
    else:
        common=np.lexsort((np.arange(evaluate.ROWS),-counts))[:int(plan)]
    with np.load(DATA/f'codebook{k}.npz') as z:
        packet=z['labels'].copy();scales=z['scales'].copy();code=z['code'].copy();unit=float(z['unit'])
    labels=codec.unpack(packet,evaluate.COLS//16,int(np.log2(k)))
    scores=evaluate.respond(inputs,labels,scales,code,unit)
    weight=evaluate.load()[5]
    scores[:,common]=inputs@weight[common].T
    rare=np.ones(evaluate.ROWS,np.float64);rare[common]=0
    common_gold=rare[gold]==0
    n=len(gold);sample=np.arange(n)
    def objective(theta):
        temperature,offset=theta
        z=scores.astype(np.float64)
        z[:,rare.astype(bool)]=temperature*z[:,rare.astype(bool)]+offset
        normalizer=logsumexp(z,axis=1)
        prob=np.exp(z-normalizer[:,None])
        loss=float(np.mean(normalizer-z[sample,gold]))
        expected_score=(prob[:,rare.astype(bool)]*scores[:,rare.astype(bool)]).sum(1)
        selected_score=np.where(common_gold,0.,scores[sample,gold])
        derivative_t=float(np.mean(expected_score-selected_score))
        derivative_offset=float(np.mean(prob[:,rare.astype(bool)].sum(1)-rare[gold]))
        return loss,np.asarray([derivative_t,derivative_offset])
    initial=objective((1.,0.))[0]
    result=minimize(objective,[1.,0.],jac=True,bounds=((0.25,2.0),(-10.,10.)),method='L-BFGS-B',
                    options={'maxiter':40,'ftol':1.e-10})
    if not result.success:raise ValueError(result.message)
    receipt={'format':'qwen3-tied-global-calibration/1','k':k,'common_plan':plan,
             'common_rows':len(common),
             'temperature_rare':float(result.x[0]),'offset_rare':float(result.x[1]),
             'train_nll_before':initial,'train_nll_after':float(result.fun),
             'train_tokens':len(gold),
             'train_positions':'four train windows; positions 0,8,...,248, target next token',
             'source_sha256':sha(Path(__file__)),
             'evaluate_source_sha256':sha(Path(evaluate.__file__)),
             'head_capture_sha256':sha(DATA/'final-head.npz'),
             'frequency_sha256':sha(DATA/'frequency.npz'),
             'codebook_sha256':sha(DATA/f'codebook{k}.npz'),
             'extra_payload_bytes':8,
             'numerical_map':'exact common logits; rare codebook response multiplied by train-fitted temperature plus rare offset; tied input embeddings unchanged'}
    (DATA/f'tune{k}-{plan}.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({key:receipt[key] for key in ('k','common_plan','common_rows','temperature_rare','offset_rare','train_nll_before','train_nll_after')}))


if __name__=='__main__':
    if len(sys.argv)!=3:raise SystemExit('tune.py K KEEP')
    fit(int(sys.argv[1]),sys.argv[2])
