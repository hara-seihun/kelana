"""Frozen source-only weighted four-means; run once per layer."""
import hashlib, json, sys
from pathlib import Path
import numpy as np
from numba import njit

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-two-bit-causal'
CTX=ROOT/'contextual-value-feedback'
ARR=ROOT/'kivi-value-intern'
SNAP=ROOT/'kivi-two-bit-dot-native'

def sha(b):return hashlib.sha256(b).hexdigest()
def checked(p,d):
    b=p.read_bytes();assert sha(b)==d,(p,d)
    return b

def bf16(x):return (np.asarray(x,dtype='<u2').astype('<u4')<<16).view('<f4')
def original_o(layer):
    path=(SNAP if layer==0 else CTX)/'original-o.bf16'
    if layer==0: digest=json.loads((SNAP/'snapshots.json').read_text())['original_o_sha256']
    else:digest=json.loads((CTX/'original-o.json').read_text())['o_sha256']
    o=bf16(np.frombuffer(checked(path,digest),dtype='<u2')).reshape(1024,2048).astype('f8')
    diag=np.sum(o*o,axis=0).reshape(16,128)
    return (diag[::2]+diag[1::2]),digest

def donor(layer,panel,w,h):
    if layer==0:
        manifest=json.loads((BASE/f'{panel}-{w}-manifest.json').read_text())
        info=manifest['groups'][f'kv{h}']
        path=BASE/f'{panel}-{w}-head{h}'
    else:
        manifest=json.loads((CTX/f'{panel}-{w}-manifest.json').read_text())
        info=manifest['arms']['original']['heads'][h]
        path=CTX/f'{panel}-{w}-original-h{h}'
    stream=checked(path.with_name(path.name+'-events.bin'),info['events_sha256'])
    p=0;values=[];keys=[]
    while p<len(stream):
        kind=stream[p:p+1];t=int.from_bytes(stream[p+1:p+3],'little')
        assert kind in (b'K',b'V')
        size=1536 if kind==b'K' else 48
        blob=stream[p+3:p+3+size];assert len(blob)==size
        (keys if kind==b'K' else values).append((t,blob))
        p+=3+size
    assert len(keys)==8 and len(values)==224 and all(t==33+i for i,(t,_) in enumerate(values))
    assert all(t==32*(i+1) for i,(t,_) in enumerate(keys))
    checked(path.with_name(path.name+'-final.bin'),info['final_sha256'])
    return keys,values,info

def source(layer,w):
    if layer==0:
        m=json.loads((ARR/f'train-{w}-manifest.json').read_text());assert m['panel']=='train'
        raw=checked(ARR/f'train-{w}-events.bin',m['events_sha256'])
        records=np.frombuffer(raw,dtype='u1').reshape(256,4098)
        assert np.array_equal(records[:,:2].copy().view('<u2').ravel(),np.arange(1,257))
        v=records[:,2050:].copy().view('<u2').reshape(256,8,128)
        assert sha((BASE/f'train-{w}-manifest.json').read_bytes())==m['baseline_manifest_sha256']
        return v,{'source_sha256':m['events_sha256'],'source_owner':'kivi-value-intern'}
    r=json.loads((CTX/f'train-{w}-source.json').read_text())
    raw=checked(CTX/f'train-{w}-source.npz',r['source_file_sha256'])
    import io
    with np.load(io.BytesIO(raw)) as f:v=f['v'].copy()
    assert v.shape==(256,8,128) and sha(v.tobytes())==r['arrays']['v']['sha256']
    return v,{'source_sha256':r['source_file_sha256'],'source_owner':'contextual-value-feedback','v_sha256':sha(v.tobytes())}

@njit
def cost(pw,px,pxx,i,j):
    w=pw[j]-pw[i]; x=px[j]-px[i]
    return (pxx[j]-pxx[i])-x*x/w

@njit
def row(k,left,right,low,high,prior,out,arg,pw,px,pxx):
    if left>right:return
    mid=(left+right)//2
    end=min(mid-1,high)
    best=np.inf;split=-1
    for i in range(low,end+1):
        candidate=prior[i]+cost(pw,px,pxx,i+1,mid+1)
        if candidate<best:
            best=candidate;split=i
    out[mid]=best;arg[mid]=split
    row(k,left,mid-1,low,split,prior,out,arg,pw,px,pxx)
    row(k,mid+1,right,split,high,prior,out,arg,pw,px,pxx)

def fit(z,weight):
    order=np.argsort(z,kind='stable');z=z[order];weight=weight[order]
    unique,start=np.unique(z,return_index=True)
    w=np.add.reduceat(weight,start,dtype='f8')
    # Equal-value aggregates preserve sorted source order; use binary64 cumulative sums.
    x=w*unique;xx=x*unique
    pw=np.concatenate(([0.],np.cumsum(w)));px=np.concatenate(([0.],np.cumsum(x)));pxx=np.concatenate(([0.],np.cumsum(xx)))
    n=len(unique);assert n>=4
    prior=np.full(n,np.inf);args=[]
    for j in range(n):prior[j]=cost(pw,px,pxx,0,j+1)
    for k in range(2,5):
        out=np.full(n,np.inf);arg=np.full(n,-1,dtype=np.int64)
        row(k,k-1,n-1,k-2,n-2,prior,out,arg,pw,px,pxx)
        args.append(arg);prior=out
    cuts=[];last=n-1
    for arg in args[::-1]:
        split=int(arg[last]);assert split>=0
        cuts.append(split);last=split
    cuts=cuts[::-1]
    bounds=[0]+[x+1 for x in cuts]+[n]
    means=[float((px[b]-px[a])/(pw[b]-pw[a])) for a,b in zip(bounds[:-1],bounds[1:])]
    table=np.array(means,dtype='<f4')
    objective=float(prior[-1]);integer=float(np.sum(weight*(z-np.clip(np.rint(z),0,3))**2,dtype='f8'))
    return table,{'source_count':len(z),'unique_count':n,'bounds_unique_indices':bounds,'split_z':[float(unique[x]) for x in cuts],'centroids_f64':means,'dp_objective':objective,'integer_alphabet_ideal_weighted_objective':integer,'weight_sum':float(pw[-1])}

def run(layer):
    diag,o_digest=original_o(layer)
    zs=[];ws=[];sources=[];zero=0;positive=0
    for w in range(8):
        v,record=source(layer,w);sources.append(record)
        for h in range(8):
            _,values,_=donor(layer,'train',w,h)
            fields=np.frombuffer(b''.join(blob[32:] for _,blob in values),dtype='<f2').astype('f8').reshape(224,4,2)
            a=np.repeat(fields[:,:,0],32,axis=1);b=np.repeat(fields[:,:,1],32,axis=1)
            x32=bf16(v[:224,h]).reshape(224,4,32)
            low=x32.min(axis=2).astype('f8');high=x32.max(axis=2).astype('f8')
            expected=np.stack((low,(high-low)/3),axis=-1).astype('<f2')
            assert np.array_equal(expected,np.frombuffer(b''.join(blob[32:] for _,blob in values),dtype='<f2').reshape(224,4,2))
            x=x32.reshape(224,128).astype('f8');weights=b*b*diag[h][None,:]
            mask=b>0;positive+=int(mask.sum());zero+=int((~mask).sum())
            zs.append(((x-a)[mask]/b[mask]));ws.append(weights[mask])
    z=np.concatenate(zs);weight=np.concatenate(ws)
    assert len(z)==positive and np.isfinite(z).all() and np.isfinite(weight).all() and (weight>0).all()
    table,details=fit(z,weight)
    payload=table.tobytes();(HERE/f'layer{layer}-alphabet.f32').write_bytes(payload)
    result={'layer':layer,'algorithm':'frozen binary64 sorted unique weighted prefix + monotone divide-conquer four-row DP; smallest split ties','table_f32':table.tolist(),'table_sha256':sha(payload),'original_o_sha256':o_digest,'source_receipts':sources,'positive_step_coordinates':positive,'zero_step_coordinates':zero,**details}
    (HERE/f'layer{layer}-fit.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('layer','table_f32','source_count','unique_count','dp_objective','integer_alphabet_ideal_weighted_objective')}))
if __name__=='__main__':run(int(sys.argv[1]))
