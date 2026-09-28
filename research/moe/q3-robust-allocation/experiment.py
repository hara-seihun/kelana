#!/usr/bin/env python3
"""Support-aware fixed-image Q3 allocation from saved actual routed producer deltas."""
import hashlib
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/qwen-moe')
SOURCE = DATA / 'q3-expert-allocation'
PARENT = DATA / 'gateup-q3-recode'
DEST = DATA / 'q3-robust-allocation'
COUNTS = (16, 32, 64)
ALPHAS = (0., .5, 2., 8.)
LAMBDAS = (0., 2., 8., 32.)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(split):
    chunks = []
    reference = None
    sources = {}
    for i in range(8):
        path = SOURCE / f'part-{i:02d}.npz'
        sources[str(path)] = sha(path)
        with np.load(path) as z:
            chunks.append(z[split].astype(np.float64))
        with np.load(PARENT / f'part-{i:02d}.npz') as z:
            a = z[f'{split}_q4'].astype(np.float64)
            reference = a if reference is None else reference + a
    return np.concatenate(chunks), float(np.square(reference).sum()), sources


def costs(deltas):
    return np.einsum('etd,etd->et', deltas, deltas)


def choose(c, count, alpha, lam):
    n = np.count_nonzero(c, axis=1)
    eligible = n > 0
    assert eligible.sum() >= count
    mean = c.sum()/max(n.sum(), 1)
    # Dirichlet frequency smoothing, pooled loss-per-hit shrinkage. A zero
    # observed expert remains ineligible rather than becoming a free Q3 image.
    frequency = (n + alpha)/(c.shape[1] + 256*alpha)
    loss = (c.sum(axis=1) + lam*mean)/(n + lam + (n == 0))
    risk = np.where(eligible, frequency*loss, np.inf)
    return np.argsort(risk, kind='stable')[:count]


def rms(d, subset, denominator):
    return float(np.linalg.norm(d[subset].sum(axis=0))/np.sqrt(denominator))


def main():
    train, train_denom, hashes = load('train')
    held, held_denom, held_hashes = load('held')
    c = costs(train)
    fold = np.arange(train.shape[1]) % 4
    controls = json.loads((SOURCE/'receipt.json').read_text())
    result = []
    for count in COUNTS:
        cv = []
        for alpha in ALPHAS:
            for lam in LAMBDAS:
                total_err = total_ref = 0.
                folds = []
                for f in range(4):
                    fit = fold != f
                    selected = choose(c[:, fit], count, alpha, lam)
                    residual = train[selected][:, ~fit].sum(axis=0)
                    err = float(np.square(residual).sum())
                    folds.append(err)
                    total_err += err
                    total_ref += train_denom * ((~fit).sum()/len(fold))
                cv.append({'alpha':alpha,'lambda':lam,'cv_rms':float(np.sqrt(total_err/total_ref)), 'fold_sq':folds})
        selected_cv = min(cv, key=lambda x:(x['cv_rms'],x['alpha'],x['lambda']))
        choices = {
            'train_greedy': controls['result'][COUNTS_INDEX[count]]['train_seen_only_selected'],
            'pooled_alpha0_lambda0':choose(c,count,0.,0.).tolist(),
            'cv_selected':choose(c,count,selected_cv['alpha'],selected_cv['lambda']).tolist(),
        }
        outcome = {name:{'expert_ids':list(map(int,ids)), 'train_rms':rms(train,ids,train_denom),
                         'held_rms':rms(held,ids,held_denom), 'held_max_token_error':float(np.max(np.linalg.norm(held[ids].sum(axis=0),axis=1)))}
                   for name,ids in choices.items()}
        result.append({'q3_experts':count,'cv_selection':selected_cv,'cv_grid':cv,'outcomes':outcome,
                       'paid_layer_gateup_bytes':256*1179648-count*278528,
                       'conditional_one_read_fraction':40*8*count*278528/(256*2626187904)})
    receipt = {'contract':'Frozen Q3_K/Q4_K paired gate/up bank; actual layer-0 routed score-weighted producer deltas against installed decoded Q4. Fixed experts selected by train-only 4-fold squared routed-sum risk; held evaluated once. CPU FP32 deltas and FP64 reduction, not native logits, model NLL or speed.',
               'script_sha256':sha(__file__), 'parent_receipt_sha256':sha(SOURCE/'receipt.json'),
               'parent_model_sha256':controls['parent_model_sha256'],
               'train_delta_hashes':hashes,'held_delta_hashes':held_hashes,
               'train_denominator':train_denom,'held_denominator':held_denom,
               'selection_note':'Fold membership token-index modulo 4; alpha frequency pseudocount; lambda global per-hit loss pseudocount; unseen experts excluded; CV counts and settings chosen without held rows.',
               'result':result}
    DEST.mkdir(parents=True,exist_ok=True)
    path = DEST/'receipt.json'
    path.write_text(json.dumps(receipt,indent=2)+'\n')
    for row in result:
        print(row['q3_experts'], row['cv_selection'],
              {name:r['held_rms'] for name,r in row['outcomes'].items()})
    print('receipt_sha256',sha(path))


COUNTS_INDEX = {int(r['q3_experts']):i for i,r in enumerate(json.loads((SOURCE/'receipt.json').read_text())['result'])}

if __name__ == '__main__':
    main()
