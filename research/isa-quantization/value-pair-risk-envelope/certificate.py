"""Source-only vertex-envelope lower bound for independent within-G32 pair laws."""
import csv
import importlib.util
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch
from threadpoolctl import threadpool_limits

ROOT = Path(__file__).resolve().parent.parent
HERE = Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('rounding_risk_screen',ROOT/'kivi-value-rounding-risk'/'screen.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
bf16,checked,events,get_input,sha,unpack_records=(getattr(module,k) for k in ('bf16','checked','events','get_input','sha','unpack_records'))

COEFF = ROOT/'value-pair-covariance'/'coefficients.tsv'
MATCH = ROOT/'value-pair-covariance'/'matching.tsv'
LAW = ROOT/'kivi-value-rounding-risk'


def graph(layer):
    checked(COEFF, '9a83683e04b1486fd072dbbe023d4858e75eebbf7a778d7c88824252b5757d46')
    checked(MATCH, '85c19887e88bd6936c66d676eccb56e07715948838fde5a54994188c32f6176d')
    coefficients=np.zeros((8,4,32,32,3),dtype=np.float64)
    seen=set()
    with COEFF.open() as f:
        for row in csv.DictReader(f,delimiter='\t'):
            if int(row['layer'])!=layer:continue
            h,g,i,j=(int(row[k]) for k in ('head','group','i','j'))
            base=h*128+g*32
            assert 0<=h<8 and 0<=g<4 and base<=i<j<base+32
            key=(h,g,i,j);assert key not in seen;seen.add(key)
            coefficients[h,g,i-base,j-base]=[int(row[k])*2.**-70 for k in ('A','B','D')]
            coefficients[h,g,j-base,i-base]=coefficients[h,g,i-base,j-base]
    assert len(seen)==8*4*496
    match=[]
    with MATCH.open() as f:
        for row in csv.DictReader(f,delimiter='\t'):
            if int(row['layer'])==layer:
                h,g,i,j=(int(row[k]) for k in ('head','group','i','j'))
                match.append((h,g,i-(h*128+g*32),j-(h*128+g*32),row['sign']))
    assert len(match)==512
    return coefficients,match


def grid(source,records):
    n=len(records)
    assert len(source)==n
    fields=np.frombuffer(b''.join(b[32:] for b in records),dtype='<f2').astype(np.float32).reshape(n,4,2)
    low=np.repeat(fields[:,:,0],32,axis=1);step=np.repeat(fields[:,:,1],32,axis=1)
    levels=np.stack([np.add(low,np.multiply(step,np.float32(j),dtype=np.float32),dtype=np.float32).astype(np.float64) for j in range(4)],axis=-1)
    v=bf16(source).astype(np.float64)
    lo=np.zeros((n,128),dtype=np.intp);hi=lo.copy()
    for j in range(1,4):
        between=(v>levels[:,:,j-1])&(v<levels[:,:,j]);lo[between]=j-1;hi[between]=j
    above=v>levels[:,:,3];lo[above]=3;hi[above]=3
    for j in range(3,-1,-1):
        equal=v==levels[:,:,j];lo[equal]=j;hi[equal]=j
    rows=np.arange(n)[:,None];cols=np.arange(128)[None,:]
    a=levels[rows,cols,lo];b=levels[rows,cols,hi];d=b-a
    f=np.zeros_like(d);mask=d>0;f[mask]=(v[mask]-a[mask])/d[mask]
    assert np.all((f>=0)&(f<=1)) and np.all(d>=0)
    return d.reshape(n,4,32),f.reshape(n,4,32),sha(b''.join(b[32:] for b in records))


def edge_arrays(d,f):
    fi=f[:,None];fj=f[None,:];ind=fi*fj
    lower=np.maximum(0,fi+fj-1);upper=np.minimum(fi,fj)
    cmax=np.maximum(ind-lower,upper-ind)
    edges=2*d[:,None]*d[None,:]*cmax
    return edges,cmax,ind,lower,upper


def main(panel,w):
    torch.set_num_threads(1)
    with threadpool_limits(1):
        arrays,queries,obits,donor,donor_sha,source_sha,_,_=get_input(panel,w)
        layer=0 if panel=='held' else 1
        coefficients,matching=graph(layer)
        source_result=json.loads((LAW/f'{panel}-{w}-result.json').read_text())
        assert source_result['source_sha256']==source_sha and source_result['donor_manifest_sha256']==donor_sha
        assert source_result['original_o_sha256']==sha(obits.tobytes())
        expected_o=('803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499',
                    '677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48')[layer]
        assert source_result['original_o_sha256']==expected_o
        assert len(source_result['rows'])==len(queries)
        name=f'{panel}-{w}'
        kcache=[]; dlist=[];flist=[];fields=[];evt=[]
        constants=np.zeros((224,8,3),dtype=np.float64)
        for h in range(8):
            owner=donor['groups'][f'kv{h}'] if panel=='held' else donor['arms']['original']['heads'][h]
            path=(ROOT/'kivi-two-bit-causal'/f'{name}-head{h}-events.bin') if panel=='held' else (ROOT/'contextual-value-feedback'/f'{name}-original-h{h}-events.bin')
            log=events(checked(path,owner['events_sha256']))
            ks=[(t,b) for kind,t,b in log if kind=='K'];vs=[(t,b) for kind,t,b in log if kind=='V']
            assert [t for t,_ in ks]==list(range(32,257,32)) and [t for t,_ in vs]==list(range(33,257))
            source_v=arrays['v'][:224,h]
            d,f,field_sha=grid(source_v,[b for _,b in vs])
            chronology=source_result['chronology'][h]
            assert chronology['event_sha256']==owner['events_sha256'] and chronology['stored_v_fields_sha256']==field_sha
            assert chronology['source_v_sha256']==sha(arrays['v'][:,h].tobytes())
            evt.append(owner['events_sha256']);fields.append(field_sha)
            dlist.append(d);flist.append(f)
            for token in range(224):
                for g in range(4):
                    edges,*_=edge_arrays(d[token,g],f[token,g])
                    weighted=edges[:,:,None]*np.abs(coefficients[h,g])
                    constants[token,h]+=0.5*weighted.max(axis=1).sum(axis=0)
            kcache.append((unpack_records([b for _,b in ks],2,True).astype(np.float32),bf16(arrays['k'][:,h])))
        grouped={}
        for h,g,i,j,sign in matching:grouped.setdefault(h,[]).append((g,i,j,sign))
        rows=[];max_edge_slack=0.;max_map_slack=0.
        for t,(q,_) in queries.items():
            n=max(0,t-33);nkey=(t-1)//32*32
            keys=np.stack([np.concatenate((kc[0][:nkey],kc[1][nkey:t])) for kc in kcache])
            qt=torch.from_numpy(np.array(q,copy=True));kt=torch.from_numpy(np.ascontiguousarray(keys))
            a=torch.bmm(qt[:,None,:],kt[torch.arange(16)//2].transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1).numpy().astype(np.float64)
            p0=a[::2,:n].T;p1=a[1::2,:n].T
            components=[float(np.sum(constants[:n,:,0]*p0**2)),float(np.sum(constants[:n,:,1]*p0*p1)),float(np.sum(constants[:n,:,2]*p1**2))]
            benefit=sum(components)
            own=source_result['rows'][len(rows)];assert own['t']==t and own['aged_tokens']==n
            variance=own['variance_trace'];mean=own['mean_bias_sse'];det=own['deterministic_fp64_sse']
            lower=mean+max(0.,variance-benefit)
            row={'t':t,'aged_tokens':n,'mean_bias_sse':mean,'independent_variance':variance,'deterministic_fp64_sse':det,'benefit_upper':benefit,'benefit_components_A_B_D':components,'variance_floor':max(0.,variance-benefit),'expected_risk_lower':lower,'lower_minus_deterministic':lower-det}
            if t in (128,256):
                direct=0.;fixed=0.;row_envelope=0.
                for token in range(n):
                    for h in range(8):
                        x=float(p0[token,h]);y=float(p1[token,h])
                        for g in range(4):
                            edges,cmax,ind,L,U=edge_arrays(dlist[h][token,g],flist[h][token,g])
                            c=coefficients[h,g];gamma=c[:,:,0]*x*x+c[:,:,1]*x*y+c[:,:,2]*y*y
                            direct+=float(np.triu(edges*np.abs(gamma),1).sum())
                            poly=edges*(abs(c[:,:,0])*x*x+abs(c[:,:,1])*x*y+abs(c[:,:,2])*y*y)
                            assert np.all(edges*np.abs(gamma)<=poly+1e-14)
                            row_envelope+=0.5*float(poly.max(axis=1).sum())
                            for gg,i,j,sign in grouped[h]:
                                if gg!=g:continue
                                cov=(L if sign=='+' else U)[i,j]-ind[i,j]
                                fixed+=float(-2*dlist[h][token,g,i]*dlist[h][token,g,j]*cov*gamma[i,j])
                max_edge_slack=max(max_edge_slack,row_envelope-benefit)
                max_map_slack=max(max_map_slack,fixed-benefit)
                assert row_envelope<=benefit+1e-9 and fixed<=direct+1e-9 and fixed<=benefit+1e-9
                row['all_pair_edge_gain_sum_not_a_matching']=direct
                row['direct_row_envelope']=row_envelope
                row['certified_fixed_map_reduction']=fixed
                row['fixed_map_expected_sse']=mean+variance-fixed
            rows.append(row)
        result={'panel':panel,'window':w,'source_sha256':source_sha,'donor_manifest_sha256':donor_sha,'original_o_sha256':source_result['original_o_sha256'],'source_result_sha256':sha((LAW/f'{name}-result.json').read_bytes()),'coefficients_sha256':sha(COEFF.read_bytes()),'matching_sha256':sha(MATCH.read_bytes()),'events_sha256':evt,'fields_sha256':fields,'grid':'FP32 multiply then add of original FP16 fields; source BF16 clipped to actual adjacent decoded levels','bound_constants_per_event_head':constants.tolist(),'checks':{'max_direct_row_minus_envelope':max_edge_slack,'max_fixed_map_minus_envelope':max_map_slack},'rows':rows}
        (HERE/f'{name}.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
        print(json.dumps({'window':name,'queries':len(rows),'bound':sum(r['expected_risk_lower'] for r in rows),'deterministic':sum(r['deterministic_fp64_sse'] for r in rows),'benefit':sum(r['benefit_upper'] for r in rows)}))

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
