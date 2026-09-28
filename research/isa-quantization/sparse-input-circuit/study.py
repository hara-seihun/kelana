"""Sparse fan-out/accumulation circuit on the fixed Qwen q_proj response panel.

Each live lane begins as one kept input; an edge adds a quantized multiple of a
removed input to a live lane. Refit the complete readout after each edge group.
No held states participate in fitting or selection.
"""
import hashlib
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
FIX = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
CONTROL = ROOT / 'producer-screen' / 'affine-q4.bin'


def relerr(a, b):
    return float(np.sum((a-b)**2)/np.sum(b*b))


def select_kept(h, w):
    """Greedy removal using exact conditional cost of one deleted input."""
    kept = list(range(128))
    for _ in range(32):
        q = np.linalg.inv(h[np.ix_(kept, kept)])
        fitted = q @ h[np.ix_(kept, range(128))] @ w.T
        scores = np.sum(fitted*fitted, axis=1)/np.diag(q)
        del kept[int(np.argmin(scores))]
    removed = [i for i in range(128) if i not in kept]
    return kept, removed


def readout(h, cross, t):
    return np.linalg.solve(t.T@h@t, t.T@cross)


def fit_edges(h, w, kept, removed, budget=480):
    t = np.eye(128, dtype=np.float64)[:, kept].copy()
    cross = h@w.T
    selected = np.zeros((len(removed),len(kept)), dtype=bool)
    checkpoints = []
    y_norm = float(np.sum(w*(w@h)))
    b = readout(h, cross, t)
    for iteration in range(budget):
        # Full response gradient; only removed source -> kept destination edges legal.
        e = w.T-t@b
        g = (h[np.ix_(removed, range(128))]@e)@b.T
        curvature = h[removed, removed, None]*np.sum(b*b, axis=1)[None,:]
        gains = g*g/curvature
        gains[selected] = -np.inf
        j,i = np.unravel_index(np.argmax(gains), gains.shape)
        if not np.isfinite(gains[j,i]) or gains[j,i] <= 0: break
        t[removed[j],i] += g[j,i]/curvature[j,i]
        selected[j,i] = True
        if (iteration+1)%32 == 0 or iteration+1 == budget:
            b = readout(h, cross, t)
            e = w.T-t@b
            floor = float(np.sum(e*(h@e))/y_norm)
            checkpoints.append(dict(edges=iteration+1, real_readout_train=floor,
                                    max_fanout=int(np.max(selected.sum(axis=1)))))
    return t, selected, checkpoints


def polish(h, w, t, selected, removed, passes=24):
    """Exact block-coordinate A minimizers at fixed B, followed by readout refits."""
    cross=h@w.T
    scores=[]
    for sweep in range(passes):
        b=readout(h,cross,t)
        e=w.T-t@b
        he=h@e
        q=b@b.T
        for j,index in enumerate(removed):
            support=np.flatnonzero(selected[j])
            delta=np.linalg.solve(h[index,index]*q[np.ix_(support,support)],
                                  he[index]@b[support].T)
            t[index,support]+=delta
            he-=h[:,index,None]*(delta@b[support])[None,:]
        b=readout(h,cross,t)
        e=w.T-t@b
        scores.append(float(np.sum(e*(h@e))/np.sum(w*(w@h))))
    return scores


def q4_readout(b, ht):
    """Affine nibble grid on each output row, weighted by carrier covariance."""
    rows=[]; records=[]
    for row in b.T:
        best=None
        for lo_pct,hi_pct in ((0,100),(1,99),(2,98),(4,96),(8,92)):
            lo,hi=np.percentile(row,[lo_pct,hi_pct]); step=max((hi-lo)/15,1e-8); origin=lo
            for _ in range(6):
                codes=np.clip(np.rint((row-origin)/step),0,15)
                design=np.stack((np.ones(len(row)),codes),axis=1)
                origin,step=np.linalg.solve(design.T@ht@design,design.T@ht@row)
                step=max(float(step),1e-8)
            origin=float(np.float16(origin)); step=float(np.float16(step))
            codes=np.clip(np.rint((row-origin)/step),0,15).astype(np.uint8)
            approximation=origin+step*codes
            diff=row-approximation
            loss=float(diff@ht@diff)
            if best is None or loss<best[0]:best=(loss,approximation,codes,origin,step)
        rows.append(best[1]);records.append(best[2:])
    return np.asarray(rows).T,records


def serialize(kept, removed, t, selected, records):
    # Exact format: 96 kept u8 indices; 256 edges, each (source u8, target u8,
    # FP16 multiplier); 128 output rows each 48 code bytes + 2 FP16 grid fields.
    image=bytearray(np.asarray(kept,dtype='u1').tobytes())
    for j,i in zip(*np.nonzero(selected)):
        image.extend(bytes((removed[j],i)))
        image.extend(np.asarray(t[removed[j],i],dtype='<f2').tobytes())
    edges=int(np.sum(selected))
    for codes,origin,step in records:
        image.extend((codes[::2]|(codes[1::2]<<4)).tobytes())
        image.extend(np.asarray([origin,step],dtype='<f2').tobytes())
    HERE.joinpath('circuit-q4.bin').write_bytes(image)
    return bytes(image),edges


def decode(image, edges):
    kept=list(np.frombuffer(image,dtype='u1',count=96))
    if len(set(kept))!=96:raise ValueError('duplicate kept lane')
    t=np.eye(128,dtype='float64')[:,kept].copy()
    start=96
    for k in range(edges):
        j,i=image[start+4*k:start+4*k+2]
        scale=float(np.frombuffer(image,dtype='<f2',count=1,offset=start+4*k+2)[0])
        t[j,i]+=scale
    b=np.empty((96,128),dtype='float64')
    start+=4*edges
    for r in range(128):
        offset=start+52*r
        packed=np.frombuffer(image,dtype='u1',count=48,offset=offset)
        codes=np.empty(96,dtype='float64')
        codes[::2]=packed&15;codes[1::2]=packed>>4
        origin,step=np.frombuffer(image,dtype='<f2',count=2,offset=offset+48).astype('float64')
        b[:,r]=origin+step*codes
    if len(image)!=start+128*52:raise ValueError('trailing bytes')
    return t,b


def main():
    with np.load(FIX) as data:
        w=data['weight'][:128,:128].astype('float64')
        x=data['train'][:,:128].astype('float64')
        v=data['validation'][:,:128].astype('float64')
    h=x.T@x; cross=h@w.T; y=x@w.T; vy=v@w.T
    kept,removed=select_kept(h,w)
    t,selected,checkpoints=fit_edges(h,w,kept,removed)
    polished=polish(h,w,t,selected,removed)
    b=readout(h,cross,t)
    # FP16 edge rounding is part of the input programme during readout fitting.
    t[removed,:]=t[removed,:].astype('float16').astype('float64')
    b=readout(h,cross,t)
    floor=relerr(x@t@b,y)
    q,records=q4_readout(b,t.T@h@t)
    image,edges=serialize(kept,removed,t,selected,records)
    td,bd=decode(image,edges)
    if not np.array_equal(td,t) or not np.array_equal(bd,q):raise AssertionError('image replay mismatch')
    baseline=CONTROL.read_bytes()
    direct=np.empty((128,128),dtype='float64')
    for r in range(128):
        offset=68*r; packed=np.frombuffer(baseline,dtype='u1',count=64,offset=offset)
        codes=np.empty(128); codes[::2]=packed&15;codes[1::2]=packed>>4
        origin,step=np.frombuffer(baseline,dtype='<f2',count=2,offset=offset+64).astype('float64')
        direct[r]=origin+step*codes
    result=dict(fixture_sha256=hashlib.sha256(FIX.read_bytes()).hexdigest(),
                control_sha256=hashlib.sha256(baseline).hexdigest(),
                image_sha256=hashlib.sha256(image).hexdigest(),
                kept=kept,removed=removed,checkpoints=checkpoints,polished=polished,
                edges=edges,bytes=len(image),format='kept indices 96B + edges 4B each + 128 affine Q4 readout rows of 52B',
                real_readout_train_floor=floor,decoded_train=relerr(x@td@bd,y),
                decoded_held=relerr(v@td@bd,vy),control_train=relerr(x@direct.T,y),
                control_held=relerr(v@direct.T,vy),
                output_coeff_contributions=128*96,input_edge_scaled_adds=edges,
                direct_coeff_contributions=128*128,
                max_removed_fanout=int(np.max(selected.sum(axis=1))),
                max_kept_indegree=int(np.max(selected.sum(axis=0))))
    HERE.joinpath('results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('kept','removed','checkpoints')},indent=2))
    print('floor trajectory',checkpoints,'polished',polished)

if __name__=='__main__':main()
