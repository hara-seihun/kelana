"""Immutable layer-local pair coupling: exact expected complete-O correction to pinned independent risk."""
import csv
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch
from threadpoolctl import threadpool_limits

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
INDEPENDENT = ROOT / 'kivi-value-rounding-risk'
PAIRS = ROOT / 'value-pair-covariance'
spec = importlib.util.spec_from_file_location('independent_rounding_screen', INDEPENDENT/'screen.py')
independent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(independent)
from replay import unpack_records


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pin(path, expected):
    data = path.read_bytes()
    assert sha(data) == expected, path
    return data


def pair_source():
    summary = json.loads((PAIRS/'summary.json').read_text())
    for filename, key in [('pair-map.bin','pair_map_sha256'), ('matching.tsv','matching_sha256'),
                          ('coefficients.tsv','coefficients_sha256'),('certificates.tsv','certificates_sha256')]:
        pin(PAIRS/filename, summary[key])
    assert summary['pair_map_sha256'] == '2e5a182308b17a2e6b417521a7937fd9b98037bb6bfb3df3269fabb02b3e35f3'
    match = {}
    with (PAIRS/'matching.tsv').open() as stream:
        for row in csv.DictReader(stream, delimiter='\t'):
            layer,h,g,i,j = (int(row[k]) for k in ('layer','head','group','i','j'))
            match[layer,h,g,i,j] = row['sign']
    coeff = {}
    with (PAIRS/'coefficients.tsv').open() as stream:
        for row in csv.DictReader(stream, delimiter='\t'):
            key = tuple(int(row[k]) for k in ('layer','head','group','i','j'))
            if key in match:
                coeff[key] = np.array([int(row[k])*2.**-70 for k in ('A','B','D')])
    out = {}
    raw = (PAIRS/'pair-map.bin').read_bytes()
    for layer in (0,1):
        groups = []
        offset = layer * 1568
        for h in range(8):
            head = []
            for g in range(4):
                assert raw[offset] == 16
                offset += 1
                tuples = []
                for _ in range(16):
                    i,j,flag = raw[offset:offset+3]
                    offset += 3
                    key = (layer,h,g,h*128+g*32+i,h*128+g*32+j)
                    sign = '+' if flag else '-'
                    assert match[key] == sign and key in coeff
                    tuples.append((g*32+i,g*32+j,sign,coeff[key]))
                head.extend(tuples)
            groups.append(head)
        assert offset == (layer+1)*1568
        out[layer] = groups
    assert len(match) == len(coeff) == 1024
    return summary,out


def adjacent(src, records):
    n = len(records)
    raw = np.frombuffer(b''.join(records),dtype='u1').reshape(n,48)
    fields = np.frombuffer(raw[:,32:].copy().tobytes(),dtype='<f2').astype('<f4').reshape(n,4,2)
    low = np.repeat(fields[:,:,0],32,axis=1)
    step = np.repeat(fields[:,:,1],32,axis=1)
    levels = np.empty((n,128,4),dtype=np.float64)
    for j in range(4):
        levels[:,:,j] = np.add(low,np.multiply(step,np.float32(j),dtype=np.float32),dtype=np.float32)
    v = independent.bf16(src[:n]).astype(np.float64)
    lo = np.zeros((n,128),dtype=np.intp)
    hi = np.zeros_like(lo)
    for j in range(1,4):
        mask = (v>levels[:,:,j-1]) & (v<levels[:,:,j])
        lo[mask] = j-1
        hi[mask] = j
    above = v>levels[:,:,3]
    lo[above] = hi[above] = 3
    for j in range(3,-1,-1):
        equal = v==levels[:,:,j]
        lo[equal] = hi[equal] = j
    rows = np.arange(n)[:,None]
    cols = np.arange(128)[None,:]
    lower = levels[rows,cols,lo]
    gap = levels[rows,cols,hi]-lower
    p = np.zeros((n,128),dtype=np.float64)
    interior = hi!=lo
    p[interior] = (v[interior]-lower[interior])/gap[interior]
    assert np.all((0<=p)&(p<=1)) and np.all(gap>=0)
    mean,var,_,_ = independent.level_law(src, records)
    assert np.array_equal(mean,lower+p*gap) and np.array_equal(var,p*(1-p)*np.square(gap))
    return p,gap


def coupling(p,q,sign):
    t = max(0.,p+q-1.) if sign=='+' else min(p,q)
    weights = np.array([1-p-q+t,p-t,q-t,t])
    assert min(weights)>=-1e-15 and abs(sum(weights)-1)<1e-15
    assert abs(weights[2]+weights[3]-q)<1e-15
    assert abs(weights[1]+weights[3]-p)<1e-15
    return t,weights


def run(panel,w):
    torch.set_num_threads(1)
    with threadpool_limits(1):
        pins = json.loads((HERE/'pins.json').read_text())
        pin(INDEPENDENT/'summary.json',pins['summary_sha256'])
        name=f'{panel}-{w}'
        original=json.loads(pin(INDEPENDENT/f'{name}-result.json',pins['receipts_sha256'][name]))
        source_summary, pair_map = pair_source()
        layer=0 if panel=='held' else 1
        arrays,queries,obits,donor,donor_sha,source_sha,_,_=independent.get_input(panel,w)
        assert source_sha==original['source_sha256'] and donor_sha==original['donor_manifest_sha256']
        assert sha(obits.tobytes())==original['original_o_sha256']==source_summary['source_sha256'][layer]
        o=independent.bf16(obits).astype(np.float64).reshape(1024,16,128)
        kcache=[]
        # [head, aged event index, (u²,uv,v²)]: one contraction per pair/event, no output arrays.
        corrections=np.zeros((8,224,3),dtype=np.float64)
        probabilities=[]
        gaps=[]
        joint_law_cases=0
        min_joint_weight=1.
        max_marginal_error=0.
        for h in range(8):
            owner=donor['groups'][f'kv{h}'] if panel=='held' else donor['arms']['original']['heads'][h]
            path=(ROOT/'kivi-two-bit-causal'/f'{name}-head{h}-events.bin') if panel=='held' else (ROOT/'contextual-value-feedback'/f'{name}-original-h{h}-events.bin')
            log=independent.events(pin(path,owner['events_sha256']))
            ks=[(t,b) for kind,t,b in log if kind=='K']
            vs=[(t,b) for kind,t,b in log if kind=='V']
            assert [t for t,_ in ks]==list(range(32,257,32)) and [t for t,_ in vs]==list(range(33,257))
            receipt=original['chronology'][h]
            assert receipt['event_sha256']==owner['events_sha256']
            assert receipt['source_v_sha256']==sha(arrays['v'][:,h].tobytes())
            assert receipt['stored_v_fields_sha256']==sha(b''.join(b[32:] for _,b in vs))
            key_quant=unpack_records([b for _,b in ks],2,True).astype(np.float32)
            kcache.append((key_quant,independent.bf16(arrays['k'][:,h])))
            p,gap=adjacent(arrays['v'][:,h],[b for _,b in vs])
            probabilities.append(p)
            gaps.append(gap)
            for i,j,sign,abc in pair_map[layer][h]:
                upper_i=p[:,i]
                upper_j=p[:,j]
                t=np.maximum(0.,upper_i+upper_j-1.) if sign=='+' else np.minimum(upper_i,upper_j)
                weights=np.stack((1-upper_i-upper_j+t,upper_i-t,upper_j-t,t))
                min_joint_weight=min(min_joint_weight,float(np.min(weights)))
                max_marginal_error=max(max_marginal_error,float(np.max(np.abs(weights[1]+weights[3]-upper_i))),
                                         float(np.max(np.abs(weights[2]+weights[3]-upper_j))),
                                         float(np.max(np.abs(np.sum(weights,axis=0)-1))))
                assert min_joint_weight>=-1e-15 and max_marginal_error<=1e-15
                joint_law_cases+=len(t)
                cov=(t-upper_i*upper_j)*gap[:,i]*gap[:,j]
                if sign=='+':
                    assert np.max(cov)<=2e-16
                    assert np.min(abc[[0,2]])>=-1e-16
                else:
                    assert np.min(cov)>=-2e-16
                    assert np.max(abc[[0,2]])<=1e-16
                corrections[h]+=2*cov[:,None]*abc
        rows=[]
        checked_direct=[]
        max_rounding_increase=0.
        for index,(t,(q,_)) in enumerate(queries.items()):
            prior=original['rows'][index]
            assert prior['t']==t and prior['aged_tokens']==max(0,t-33)
            n=prior['aged_tokens']
            nkey=(t-1)//32*32
            keys=np.stack([np.concatenate((kcache[h][0][:nkey],kcache[h][1][nkey:t])) for h in range(8)])
            qt=torch.from_numpy(np.array(q,copy=True))
            kt=torch.from_numpy(np.ascontiguousarray(keys))
            a=torch.bmm(qt[:,None,:],kt[torch.arange(16)//2].transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1).numpy().astype(np.float64)
            delta=0.
            for h in range(8):
                u,v=a[2*h,:n],a[2*h+1,:n]
                co=corrections[h,:n]
                delta+=float(np.sum(co[:,0]*u*u+co[:,1]*u*v+co[:,2]*v*v))
            independent_risk=prior['expected_sse']
            expected=independent_risk+delta
            tolerance=1e-11*max(1.,independent_risk)
            max_rounding_increase=max(max_rounding_increase,delta)
            assert delta<=tolerance and expected>=-tolerance
            assert abs(expected-(prior['mean_bias_sse']+prior['variance_trace']+delta))<=tolerance
            rows.append({'t':t,'aged_tokens':n,'independent_expected_sse':independent_risk,
                         'pair_covariance_correction':delta,'paired_expected_sse':expected,
                         'original_fp64_sse':prior['deterministic_fp64_sse'],
                         'original_cpu_sse':prior['original_cpu_sse'],'teacher_sq':prior['teacher_sq']})
            # Bounded direct four-outcome projected O vectors, at a live event with the actual unequal gaps.
            if t in (128,256):
                for h in (0,3,7):
                    for i,j,sign,abc in pair_map[layer][h][::16]:
                        event=min(n-1,31+h)
                        p,qprob=probabilities[h][event,[i,j]]
                        di,dj=gaps[h][event,[i,j]]
                        joint,weights=coupling(float(p),float(qprob),sign)
                        u,v=a[2*h,event],a[2*h+1,event]
                        x=di*(u*o[:,2*h,i]+v*o[:,2*h+1,i])
                        y=dj*(u*o[:,2*h,j]+v*o[:,2*h+1,j])
                        outcomes=(np.zeros_like(x),x,y,x+y)
                        squares=np.array([np.dot(z,z) for z in outcomes])
                        independents=np.array([(1-p)*(1-qprob),p*(1-qprob),(1-p)*qprob,p*qprob])
                        observed=float((weights-independents)@squares)
                        analytic=2*(joint-p*qprob)*di*dj*(abc[0]*u*u+abc[1]*u*v+abc[2]*v*v)
                        assert abs(observed-analytic)<2e-12*max(1.,abs(observed),abs(analytic))
                        checked_direct.append(abs(observed-analytic))
        result={'panel':panel,'window':w,'layer':layer,'source_sha256':source_sha,
                'donor_manifest_sha256':donor_sha,'original_o_sha256':sha(obits.tobytes()),
                'independent_receipt_sha256':pins['receipts_sha256'][name],
                'pair_map_sha256':source_summary['pair_map_sha256'],
                'joint_law_cases':joint_law_cases,'min_joint_weight':min_joint_weight,
                'max_marginal_error':max_marginal_error,
                'direct_four_outcome_cases':len(checked_direct),
                'max_direct_analytic_difference':max(checked_direct),
                'max_per_query_covariance_correction':max_rounding_increase,'rows':rows}
        (HERE/f'{name}-result.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
        print(json.dumps({'name':name,'independent':sum(r['independent_expected_sse'] for r in rows),
                          'paired':sum(r['paired_expected_sse'] for r in rows),
                          'baseline':sum(r['original_fp64_sse'] for r in rows),
                          'direct_checks':len(checked_direct)}),flush=True)


if __name__=='__main__':
    run(sys.argv[1],int(sys.argv[2]))
