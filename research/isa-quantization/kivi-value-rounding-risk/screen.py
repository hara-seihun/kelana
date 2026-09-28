"""Fixed-law analytic K2/V2 complete-output risk; no random sampling or model execution."""
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np
import torch
from threadpoolctl import threadpool_limits

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CONTEXT=ROOT/'contextual-value-feedback'
BASE=ROOT/'kivi-two-bit-causal'
ARRIVAL=ROOT/'kivi-value-intern'
SNAP=ROOT/'kivi-two-bit-dot-native'
sys.path.insert(0,str(CONTEXT))
from custody import source,sha
from replay import packed_digits,unpack_records


def checked(path,expected):
    raw=path.read_bytes();assert sha(raw)==expected,path
    return raw


def bf16(words):
    return (np.asarray(words,dtype='<u4')<<16).view('<f4')


def events(raw):
    out=[];p=0
    while p<len(raw):
        kind=chr(raw[p]);t=int.from_bytes(raw[p+1:p+3],'little');n=1536 if kind=='K' else 48
        assert kind in ('K','V') and len(raw[p+3:p+3+n])==n
        out.append((kind,t,raw[p+3:p+3+n]));p+=n+3
    assert p==len(raw)
    return out


def level_law(src,records):
    n=len(records)
    if not n:return np.empty((0,128)),np.empty((0,128)),np.empty((0,128)),{'interior':0,'clipped':0,'exact':0,'duplicate_groups':0,'max_probability_violation':0.0,'min_variance':0.0}
    raw=np.frombuffer(b''.join(records),dtype='u1').reshape(n,48)
    codes=packed_digits(raw[:,:32].tobytes(),2,n*128).reshape(n,128)
    fields=np.frombuffer(raw[:,32:].copy().tobytes(),dtype='<f2').astype('<f4').reshape(n,4,2)
    low=np.repeat(fields[:,:,0],32,axis=1);step=np.repeat(fields[:,:,1],32,axis=1)
    # Separate FP32 multiply/add exactly as the original decoder; no contraction.
    levels=np.empty((n,128,4),dtype=np.float64)
    for j in range(4):
        product=np.multiply(step,np.float32(j),dtype=np.float32)
        levels[:,:,j]=np.add(low,product,dtype=np.float32).astype(np.float64)
    v=bf16(src[:n]).astype(np.float64)
    assert np.all(np.diff(levels,axis=-1)>=0)
    lo=np.zeros((n,128),dtype=np.intp);hi=np.zeros_like(lo)
    for j in range(1,4):
        between=(v>levels[:,:,j-1])&(v<levels[:,:,j])
        lo[between]=j-1;hi[between]=j
    above=v>levels[:,:,3];lo[above]=3;hi[above]=3
    # Exact equality goes to the first matching digit, including duplicate levels.
    for j in range(3,-1,-1):
        equal=v==levels[:,:,j];lo[equal]=j;hi[equal]=j
    rows=np.arange(n)[:,None];cols=np.arange(128)[None,:]
    a=levels[rows,cols,lo];b=levels[rows,cols,hi]
    p=np.zeros((n,128),dtype=np.float64);mask=hi!=lo
    p[mask]=(v[mask]-a[mask])/(b[mask]-a[mask]);assert np.all((p>=0)&(p<=1))
    mean=a+p*(b-a);var=p*(1-p)*np.square(b-a)
    assert np.all(var>=0)
    decoded=levels[rows,cols,codes]
    stat={'interior':int(mask.sum()),'clipped':int(((v<levels[:,:,0])|(v>levels[:,:,3])).sum()),'exact':int((~mask& (v>=levels[:,:,0])&(v<=levels[:,:,3])).sum()),'duplicate_groups':int((np.diff(levels,axis=2)==0).sum()),'max_probability_violation':float(max(0,-p.min(),p.max()-1)),'min_variance':float(var.min()),'endpoint_bias_sq':float(np.square(mean-v).sum())}
    return mean,var,decoded,stat


def get_input(panel,w):
    name=f'{panel}-{w}'
    if panel=='held':
        audit=json.loads((ARRIVAL/f'{name}-manifest.json').read_text())
        raw=checked(ARRIVAL/f'{name}-events.bin',audit['events_sha256'])
        assert len(raw)==256*4098
        k=np.empty((256,8,128),dtype='<u2');v=np.empty_like(k)
        for t in range(256):
            row=raw[t*4098:(t+1)*4098];assert int.from_bytes(row[:2],'little')==t+1
            k[t]=np.frombuffer(row[2:2050],dtype='<u2').reshape(8,128)
            v[t]=np.frombuffer(row[2050:],dtype='<u2').reshape(8,128)
        donor_path=BASE/f'{name}-manifest.json';donor_raw=donor_path.read_bytes()
        assert sha(donor_raw)==audit['baseline_manifest_sha256']
        snaps=json.loads((SNAP/'snapshots.json').read_text());states={s['tag']:s for s in snaps['states'] if s['window']==w}
        o=np.frombuffer(checked(SNAP/'original-o.bf16',snaps['original_o_sha256']),dtype='<u2').copy()
        query={}
        for t in (128,256):
            tag=f'{name}-t{t}';s=states[tag]
            q=np.frombuffer(checked(SNAP/f'{tag}-q.f32',s['query_sha256']),dtype='<f4').reshape(16,128)
            teacher=np.frombuffer(checked(SNAP/f'{tag}-teacher.f32',s['teacher_sha256']),dtype='<f4')
            query[t]=(q,teacher)
        existing=json.loads((ROOT/'kivi-value-error-feedback'/f'{name}-result.json').read_text())
        return {'k':k,'v':v},query,o,json.loads(donor_raw),sha(donor_raw),sha(raw),existing,states
    arrays,src=source(panel,w);donor_path=CONTEXT/f'{name}-manifest.json';donor_raw=donor_path.read_bytes()
    assert json.loads(donor_raw)['source_sha256']==src['source_file_sha256']
    o=np.frombuffer(checked(CONTEXT/'original-o.bf16',src['original_o_bf16_sha256']),dtype='<u2').copy()
    query={t:(arrays['q'][:,t-1],arrays['teacher'][t-1]) for t in range(1,257)}
    existing=json.loads((CONTEXT/f'{name}-result.json').read_text())
    return arrays,query,o,json.loads(donor_raw),sha(donor_raw),src['source_file_sha256'],existing,None


def run(panel,w):
    torch.set_num_threads(1)
    with threadpool_limits(1):
        arrays,queries,obits,donor,donor_sha,source_sha,existing,held_states=get_input(panel,w)
        name=f'{panel}-{w}';o=bf16(obits).astype(np.float64).reshape(1024,16,128)
        gram=np.empty((8,128,3),dtype=np.float64)
        for h in range(8):
            x,y=o[:,2*h,:],o[:,2*h+1,:]
            gram[h,:,0]=np.einsum('id,id->d',x,x);gram[h,:,1]=np.einsum('id,id->d',x,y);gram[h,:,2]=np.einsum('id,id->d',y,y)
        kcache=[];vmeans=[];vvars=[];vdet=[];statistics=[];chronology=[]
        for h in range(8):
            owner=donor['groups'][f'kv{h}'] if panel=='held' else donor['arms']['original']['heads'][h]
            path=(BASE/f'{name}-head{h}-events.bin') if panel=='held' else (CONTEXT/f'{name}-original-h{h}-events.bin')
            log=events(checked(path,owner['events_sha256']))
            ks=[(t,b) for kind,t,b in log if kind=='K'];vs=[(t,b) for kind,t,b in log if kind=='V']
            assert len(ks)==8 and len(vs)==224 and [t for t,_ in ks]==list(range(32,257,32)) and [t for t,_ in vs]==list(range(33,257))
            for ix,(t,b) in enumerate(vs):
                source_row=bf16(arrays['v'][ix,h]);expected=np.empty((4,2),dtype='<f2')
                for g in range(4):
                    group=source_row[g*32:(g+1)*32];expected[g]=np.array((float(group.min()),(float(group.max())-float(group.min()))/3),dtype='<f2')
                assert b[32:]==expected.tobytes()
            key_quant=unpack_records([b for _,b in ks],2,True).astype(np.float32)
            # At t=32 and every subsequent boundary the K flush is after the query.
            # Full K readout uses per-query pre-state: the last 32 source tokens remain recent.
            kcache.append((key_quant,bf16(arrays['k'][:,h])))
            mean,var,det,stat=level_law(arrays['v'][:,h],[b for _,b in vs]);vmeans.append(mean);vvars.append(var);vdet.append(det);statistics.append(stat)
            chronology.append({'h':h,'event_sha256':owner['events_sha256'],'source_v_sha256':sha(arrays['v'][:,h].tobytes()),'stored_v_fields_sha256':sha(b''.join(b[32:] for _,b in vs)),'first_v_flush':vs[0][0],'last_v_flush':vs[-1][0],'v_flushes':len(vs),'first_k_flush':ks[0][0],'last_k_flush':ks[-1][0]})
        matrix=o.reshape(1024,2048)
        rows=[]
        for t,(q,teacher) in queries.items():
            n=max(0,t-33);nkey=(t-1)//32*32
            keys=np.stack([np.concatenate((kcache[h][0][:nkey],kcache[h][1][nkey:t])) for h in range(8)])
            qt=torch.from_numpy(np.array(q,copy=True));kt=torch.from_numpy(np.ascontiguousarray(keys))
            a=torch.bmm(qt[:,None,:],kt[torch.arange(16)//2].transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1).numpy().astype(np.float64)
            meanmixed=np.empty((16,128),dtype=np.float64);detmixed=np.empty_like(meanmixed)
            variance=0.;direct=0.
            for h in range(8):
                vals=np.concatenate((vmeans[h][:n],bf16(arrays['v'][n:t,h]).astype(np.float64)))
                original=np.concatenate((vdet[h][:n],bf16(arrays['v'][n:t,h]).astype(np.float64)))
                p0,p1=a[2*h],a[2*h+1]
                meanmixed[2*h]=p0@vals;meanmixed[2*h+1]=p1@vals
                detmixed[2*h]=p0@original;detmixed[2*h+1]=p1@original
                v=vvars[h][:n]
                g=gram[h];variance+=float(np.sum(v*(p0[:n,None]**2*g[:,0]+2*p0[:n,None]*p1[:n,None]*g[:,1]+p1[:n,None]**2*g[:,2])))
                if t in (128,256):
                    coeff=p0[:n,None,None]*o[:,2*h,:][None,:,:]+p1[:n,None,None]*o[:,2*h+1,:][None,:,:]
                    direct+=float(np.sum(v[:,None,:]*coeff**2))
            output=matrix@meanmixed.ravel();detout=matrix@detmixed.ravel();target=teacher.astype(np.float64)
            bias=float(np.square(output-target).sum());baseline=float(np.square(detout-target).sum())
            assert variance>=-1e-12
            if t in (128,256):assert abs(direct-variance)<=1e-9*max(1,variance),(name,t,direct,variance)
            cpu=(existing['arms']['original'][t-1]['sse'] if panel!='held' else next(r['K2V2_sse'] for r in json.loads((ROOT/'kivi-kv-rate-exchange'/'results.json').read_text())['per_state'] if r['window']==w and r['t']==t))
            rows.append({'t':t,'aged_tokens':n,'teacher_sq':float(np.square(target).sum()),'deterministic_fp64_sse':baseline,'mean_bias_sse':bias,'variance_trace':variance,'expected_sse':bias+variance,'original_cpu_sse':cpu,'fp64_minus_cpu':baseline-cpu,'covariance_direct':direct if t in (128,256) else None})
        result={'panel':panel,'window':w,'source_sha256':source_sha,'donor_manifest_sha256':donor_sha,'original_o_sha256':sha(obits.tobytes()),'chronology':chronology,'law_statistics':statistics,'rows':rows}
        (HERE/f'{name}-result.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
        print(json.dumps({'name':name,'queries':len(rows),'expected':sum(r['expected_sse'] for r in rows),'baseline':sum(r['deterministic_fp64_sse'] for r in rows),'variance':sum(r['variance_trace'] for r in rows)}),flush=True)

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
