#!/usr/bin/env python3
"""Check persistent non-Gaussian joint moments in actual full producer projections."""
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent


def moments(split):
    with np.load(HERE/f'preactivation-{split}.npz') as f:
        gate=f['g'].astype(np.float64)
        up=f['u'].astype(np.float64)
    g=(gate-gate.mean(0))/gate.std(0)
    u=(up-up.mean(0))/up.std(0)
    mixed=g*g*u
    third=mixed.mean(0)
    sample_error=mixed.std(0)/np.sqrt(len(g))
    return dict(third=third,standard_error=sample_error,
                gate_skew=np.mean(g**3,axis=0),
                gate_excess_kurtosis=np.mean(g**4,axis=0)-3,
                up_skew=np.mean(u**3,axis=0),
                up_excess_kurtosis=np.mean(u**4,axis=0)-3)


def main():
    train,held=moments('train'),moments('held')
    result={}
    for split,m in [('train',train),('held',held)]:
        result[split]=dict(mixed_third_rms=float(np.sqrt(np.mean(m['third']**2))),
            mixed_third_median_absolute=float(np.median(abs(m['third']))),
            mixed_third_fraction_above_three_sample_se=float(np.mean(abs(m['third'])>3*m['standard_error'])),
            gate_median_absolute_skew=float(np.median(abs(m['gate_skew']))),
            gate_median_excess_kurtosis=float(np.median(m['gate_excess_kurtosis'])),
            up_median_absolute_skew=float(np.median(abs(m['up_skew']))),
            up_median_excess_kurtosis=float(np.median(m['up_excess_kurtosis'])))
    result['train_held_mixed_third_correlation']=float(np.corrcoef(train['third'],held['third'])[0,1])
    result['train_held_mixed_third_same_sign_fraction']=float(np.mean(np.sign(train['third'])==np.sign(held['third'])))
    (HERE/'producer-law.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
