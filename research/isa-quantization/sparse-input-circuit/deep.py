"""Two input layers: removed-input shears, then sparse fan-out into live lanes."""
import hashlib
import json
import numpy as np
from pathlib import Path
from study import FIX, CONTROL, HERE, relerr, select_kept, fit_edges, polish, readout, q4_readout


def choose_shears(h,w,kept,removed,a,steps=16):
    s=np.eye(32)
    chosen=np.zeros((32,32),dtype=bool)
    t=np.eye(128)[:,kept].copy()
    t[removed]=s@a
    b=readout(h,h@w.T,t)
    for _ in range(steps):
        e=w.T-t@b
        he=h@e
        vectors=a@b
        g=he[removed]@vectors.T
        curv=h[removed,removed,None]*np.sum(vectors*vectors,axis=1)[None,:]
        gain=g*g/np.maximum(curv,1e-100)
        gain[chosen]=-np.inf
        np.fill_diagonal(gain,-np.inf)
        src,dest=np.unravel_index(np.argmax(gain),gain.shape)
        coefficient=g[src,dest]/curv[src,dest]
        s[src,dest]+=coefficient
        chosen[src,dest]=True
        t[removed[src]]+=coefficient*a[dest]
        b=readout(h,h@w.T,t)
    return s,chosen


def polish_layers(h,w,kept,removed,s,a,support,rounds=20):
    t=np.eye(128)[:,kept].copy()
    hrr=h[np.ix_(removed,removed)]
    cov=s.T@hrr@s
    hs=h[:,removed]@s
    trajectory=[]
    for sweep in range(rounds):
        t[removed]=s@a
        b=readout(h,h@w.T,t)
        e=w.T-t@b
        he=h@e
        q=b@b.T
        for j in range(32):
            indices=np.flatnonzero(support[j])
            delta=np.linalg.solve(cov[j,j]*q[np.ix_(indices,indices)],
                                  (s[:,j]@he[removed])@b[indices].T)
            a[j,indices]+=delta
            he-=hs[:,j,None]*(delta@b[indices])[None,:]
        t[removed]=s@a
        b=readout(h,h@w.T,t)
        err=w.T-t@b
        trajectory.append(float(np.sum(err*(h@err))/np.sum(w*(w@h))))
    return t,trajectory


def encode(kept,removed,s,chosen,a,support,records):
    image=bytearray(np.asarray(kept,dtype='u1').tobytes())
    for j,i in zip(*np.nonzero(chosen)):
        image.extend(bytes((j,i)))
        image.extend(np.asarray(s[j,i],dtype='<f2').tobytes())
    for j,i in zip(*np.nonzero(support)):
        image.extend(bytes((j,i)))
        image.extend(np.asarray(a[j,i],dtype='<f2').tobytes())
    for codes,origin,step in records:
        image.extend((codes[::2]|(codes[1::2]<<4)).tobytes())
        image.extend(np.asarray((origin,step),dtype='<f2').tobytes())
    HERE.joinpath('two-layer-q4.bin').write_bytes(image)
    return bytes(image)


def decode(image, pre, fan):
    kept=list(np.frombuffer(image,dtype='u1',count=96))
    if len(set(kept))!=96 or max(kept)>127:raise ValueError('kept lanes')
    removed=[i for i in range(128) if i not in kept]
    s=np.eye(32)
    pos=96
    for _ in range(pre):
        j,i=image[pos:pos+2]
        s[j,i]+=float(np.frombuffer(image,dtype='<f2',count=1,offset=pos+2)[0])
        pos+=4
    a=np.zeros((32,96))
    for _ in range(fan):
        j,i=image[pos:pos+2]
        a[j,i]+=float(np.frombuffer(image,dtype='<f2',count=1,offset=pos+2)[0])
        pos+=4
    t=np.eye(128)[:,kept].copy()
    t[removed]=s@a
    b=np.empty((96,128))
    for r in range(128):
        packed=np.frombuffer(image,dtype='u1',count=48,offset=pos+52*r)
        code=np.empty(96)
        code[::2]=packed&15;code[1::2]=packed>>4
        origin,step=np.frombuffer(image,dtype='<f2',count=2,offset=pos+52*r+48).astype('float64')
        b[:,r]=origin+code*step
    if len(image)!=pos+128*52:raise ValueError('length')
    return t,b


def main():
    with np.load(FIX) as f:
        x=f['train'][:,:128].astype('float64')
        v=f['validation'][:,:128].astype('float64')
        w=f['weight'][:128,:128].astype('float64')
    h=x.T@x; y=x@w.T; vy=v@w.T
    kept,removed=select_kept(h,w)
    t,support,greedy=fit_edges(h,w,kept,removed,464)
    initial_polish=polish(h,w,t,support,removed,12)
    a=t[removed].copy()
    s,chosen=choose_shears(h,w,kept,removed,a)
    t,trajectory=polish_layers(h,w,kept,removed,s,a,support)
    s[np.nonzero(chosen)]=s[np.nonzero(chosen)].astype('float16').astype('float64')
    a[np.nonzero(support)]=a[np.nonzero(support)].astype('float16').astype('float64')
    t[removed]=s@a
    b=readout(h,h@w.T,t)
    floor=relerr(x@t@b,y)
    q,records=q4_readout(b,t.T@h@t)
    image=encode(kept,removed,s,chosen,a,support,records)
    td,bd=decode(image,int(chosen.sum()),int(support.sum()))
    if not np.array_equal(td,t) or not np.array_equal(bd,q):raise AssertionError('decode mismatch')
    result=dict(fixture_sha256=hashlib.sha256(FIX.read_bytes()).hexdigest(),
                control_sha256=hashlib.sha256(CONTROL.read_bytes()).hexdigest(),
                image_sha256=hashlib.sha256(image).hexdigest(),image_bytes=len(image),
                kept=kept,removed=removed,pre_edges=int(chosen.sum()),fan_edges=int(support.sum()),
                greedy=greedy,initial_polish=initial_polish,trajectory=trajectory,
                real_readout_train_floor=floor,decoded_train=relerr(x@td@bd,y),
                decoded_held=relerr(v@td@bd,vy),
                output_coeff_contributions=96*128,
                input_scaled_adds=int(chosen.sum()+support.sum()),
                direct_coeff_contributions=128*128,
                max_input_fanout=int(np.max(support.sum(axis=1))),
                max_live_indegree=int(np.max(support.sum(axis=0))))
    HERE.joinpath('two-layer-results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('kept','removed','greedy','initial_polish','trajectory')},indent=2))
    print('trajectory',trajectory)

if __name__=='__main__':main()
