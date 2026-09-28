#!/usr/bin/env python3
"""Compare rare-token boundaries for the original .895-bit image and mixed precision."""
import json
import sys
from pathlib import Path

import numpy as np
from scipy.special import logsumexp

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'tied-head'))
import codec
import evaluate as head
sys.path.insert(0,str(HERE))
from fit import DATA,HEAD,ROWS,WIDTH,sha
from mixed import decode_rtn


def run():
    hidden,original,gold,train_counts,val,w,_=head.load()
    with np.load(HEAD/'codebook256.npz') as z:
        labels=codec.unpack(z['labels'],64,8);scales=z['scales'].copy();code=z['code'].copy();unit=float(z['unit'])
    order=np.lexsort((np.arange(ROWS),-train_counts))
    exact=order[:2560]
    baseline=head.respond(hidden,labels,scales,code,unit)
    tune=json.loads((HEAD/'tune256-2560.json').read_text())
    compressed=np.ones(ROWS,bool);compressed[exact]=False
    baseline[:,compressed]=baseline[:,compressed]*tune['temperature_rare']+tune['offset_rare']
    baseline[:,exact]=hidden@w[exact].T
    with np.load(DATA/'mixed256.npz') as z:
        ids=z['rare_ids'].copy();rt4=decode_rtn(z['rare_packed'],z['rare_scales'])
    mixed=head.respond(hidden,labels,scales,code,unit)
    mix_exact=order[:2048]
    compressed=np.ones(ROWS,bool);compressed[mix_exact]=False;compressed[ids]=False
    quality=json.loads((DATA/'mixed-quality.json').read_text())
    mixed[:,compressed]=mixed[:,compressed]*quality['train_rare_temperature']+quality['train_rare_offset']
    mixed[:,mix_exact]=hidden@w[mix_exact].T
    mixed[:,ids]=hidden@rt4.T
    o_arg=original.argmax(1)
    def head_groups(score,chosen):
        logp=score[np.arange(len(gold)),gold]-logsumexp(score.astype(np.float64),axis=1)
        mask=np.isin(gold,chosen)
        return {'gold_exact_count':int(mask.sum()),
                'nll_gold_exact':float(-logp[mask].mean()),'nll_gold_nonexact':float(-logp[~mask].mean()),
                'top_agreement_gold_exact':int(np.sum(score.argmax(1)[mask]==o_arg[mask])),
                'top_agreement_gold_nonexact':int(np.sum(score.argmax(1)[~mask]==o_arg[~mask]))}
    denominator=rare_baseline=rare_mixed_norm=rare_mixed_error=0.
    seen=np.flatnonzero(val)
    exact_mask=np.zeros(ROWS,bool);exact_mask[exact]=True
    mix_selected=np.zeros(ROWS,bool);mix_selected[mix_exact]=True;mix_selected[ids]=True
    pos={int(v):i for i,v in enumerate(ids)}
    for start in range(0,len(seen),4096):
        chunk=seen[start:start+4096]
        source=w[chunk]
        decoded=head.decode_rows(chunk,labels,scales,code,unit)
        norm=np.sum(source*source,axis=1)
        baseline_mask=~exact_mask[chunk]
        rare_baseline+=float(np.dot(val[chunk[baseline_mask]],np.sum((decoded[baseline_mask]-source[baseline_mask])**2,axis=1)))
        denominator+=float(np.dot(val[chunk[baseline_mask]],norm[baseline_mask]))
        in_rt4=np.isin(chunk,ids)
        if in_rt4.any():decoded[in_rt4]=rt4[[pos[int(i)] for i in chunk[in_rt4]]]
        mix_mask=~mix_selected[chunk]
        rare_mixed_norm+=float(np.dot(val[chunk[mix_mask]],norm[mix_mask]))
        rare_mixed_error+=float(np.dot(val[chunk[mix_mask]],np.sum((decoded[mix_mask]-source[mix_mask])**2,axis=1)))
    out={'format':'qwen3-tied-rare-diagnostics/1','source_sha256':sha(HERE/'diagnostics.py'),
         'capture_sha256':sha(HEAD/'final-head.npz'),'baseline_image_sha256':sha(HEAD/'codebook256.npz'),
         'mixed_image_sha256':sha(DATA/'mixed256.npz'),'baseline_tune_sha256':sha(HEAD/'tune256-2560.json'),
         'reference':head_groups(original,exact),'baseline':head_groups(baseline,exact),
         'mixed':head_groups(mixed,mix_exact),
         'baseline_rare_only_embedding_weighted_rms':float(np.sqrt(rare_baseline/denominator)),
         'mixed_nonexact_nonrt4_embedding_weighted_rms':float(np.sqrt(rare_mixed_error/rare_mixed_norm)),
         'baseline_head':head.quality(original,baseline,gold),
         'mixed_head':head.quality(original,mixed,gold)}
    (DATA/'diagnostics.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out))

if __name__=='__main__':run()
