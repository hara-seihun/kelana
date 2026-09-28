"""Conditional arbitrary within-original-G32 coupling risk floor, fixed prior means/queries."""
import gzip
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch
from threadpoolctl import threadpool_limits

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
LAW=ROOT/'kivi-value-rounding-risk'
spec=importlib.util.spec_from_file_location('frozen_rounding', LAW/'screen.py')
owner=importlib.util.module_from_spec(spec)
spec.loader.exec_module(owner)
bf16,checked,events,get_input,sha,unpack_records=(getattr(owner,k) for k in ('bf16','checked','events','get_input','sha','unpack_records'))
SOURCES=('803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499',
         '677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48')


def constants(layer):
    lam=np.empty((8,4), dtype=np.float64)
    diag=np.empty((8,4,64), dtype=np.float64)
    cert_hash=[]
    for h in range(8):
        path=HERE/f'cert-{layer}-{h}.json.gz'
        cert_hash.append(sha(path.read_bytes()))
        data=json.load(gzip.open(path))
        assert (data['layer'],data['head'],data['source_sha256'])==(layer,h,SOURCES[layer])
        for g,item in enumerate(data['groups']):
            assert item['group']==g and item['lambda_numerator']>0
            lam[h,g]=item['lambda_numerator']/4096
            diag[h,g]=np.array(item['diagonal'],dtype=np.float64)*2.**-70
    return lam,diag,cert_hash


def main(panel,w):
    torch.set_num_threads(1)
    with threadpool_limits(1):
        arrays,queries,obits,donor,donor_sha,source_sha,_,_=get_input(panel,w)
        layer=0 if panel=='held' else 1
        name=f'{panel}-{w}'
        law_path=LAW/f'{name}-result.json'
        prior=json.loads(law_path.read_text())
        assert (prior['source_sha256'],prior['donor_manifest_sha256'],prior['original_o_sha256'])==(source_sha,donor_sha,sha(obits.tobytes()))
        assert prior['original_o_sha256']==SOURCES[layer]
        assert len(queries)==len(prior['rows'])
        lam,diag,cert_hash=constants(layer)
        kcache=[];field_hash=[];event_hash=[]
        coeff=np.zeros((224,8,2),dtype=np.float64)
        for h in range(8):
            entry=donor['groups'][f'kv{h}'] if panel=='held' else donor['arms']['original']['heads'][h]
            path=(ROOT/'kivi-two-bit-causal'/f'{name}-head{h}-events.bin') if panel=='held' else (ROOT/'contextual-value-feedback'/f'{name}-original-h{h}-events.bin')
            log=events(checked(path,entry['events_sha256']))
            ks=[(t,b) for kind,t,b in log if kind=='K'];vs=[(t,b) for kind,t,b in log if kind=='V']
            assert [t for t,_ in ks]==list(range(32,257,32)) and [t for t,_ in vs]==list(range(33,257))
            rows=[b for _,b in vs]
            _,variance,_,_=owner.level_law(arrays['v'][:224,h],rows)
            chronology=prior['chronology'][h]
            fields=sha(b''.join(b[32:] for b in rows))
            assert (chronology['event_sha256'],chronology['stored_v_fields_sha256'],chronology['source_v_sha256'])==(entry['events_sha256'],fields,sha(arrays['v'][:,h].tobytes()))
            event_hash.append(entry['events_sha256']);field_hash.append(fields)
            v=variance.reshape(224,4,32)
            coeff[:,h,0]=(v*lam[h,:,None]*diag[h,:,:32]).sum(axis=(1,2))
            coeff[:,h,1]=(v*lam[h,:,None]*diag[h,:,32:]).sum(axis=(1,2))
            kcache.append((unpack_records([b for _,b in ks],2,True).astype(np.float32),bf16(arrays['k'][:,h])))
        rows=[]
        for t,(q,_) in queries.items():
            n=max(0,t-33);nkey=(t-1)//32*32
            keys=np.stack([np.concatenate((kc[0][:nkey],kc[1][nkey:t])) for kc in kcache])
            qt=torch.from_numpy(np.array(q,copy=True));kt=torch.from_numpy(np.ascontiguousarray(keys))
            a=torch.bmm(qt[:,None,:],kt[torch.arange(16)//2].transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1).numpy().astype(np.float64)
            u=a[::2,:n].T;v=a[1::2,:n].T
            terms=[float(np.sum(coeff[:n,:,0]*u*u)),float(np.sum(coeff[:n,:,1]*v*v))]
            prior_row=prior['rows'][len(rows)]
            assert (prior_row['t'],prior_row['aged_tokens'])==(t,n)
            floor=sum(terms)
            expected=prior_row['mean_bias_sse']+floor
            rows.append({'t':t,'aged_tokens':n,'variance_floor':floor,'variance_terms_q0_q1':terms,
                         'mean_bias_sse':prior_row['mean_bias_sse'],
                         'independent_variance':prior_row['variance_trace'],
                         'expected_risk_lower':expected,
                         'deterministic_fp64_sse':prior_row['deterministic_fp64_sse'],
                         'lower_minus_deterministic':expected-prior_row['deterministic_fp64_sse']})
        output={'panel':panel,'window':w,'source_sha256':source_sha,'donor_manifest_sha256':donor_sha,
                'original_o_sha256':prior['original_o_sha256'],'source_result_sha256':sha(law_path.read_bytes()),
                'certificate_sha256':cert_hash,'events_sha256':event_hash,'fields_sha256':field_hash,
                'event_head_q0_q1_coefficients':coeff.tolist(),'rows':rows}
        (HERE/f'{name}.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
        print(json.dumps({'window':name,'queries':len(rows),
                          'lower':sum(r['expected_risk_lower'] for r in rows),
                          'deterministic':sum(r['deterministic_fp64_sse'] for r in rows)}))

if __name__=='__main__': main(sys.argv[1],int(sys.argv[2]))
