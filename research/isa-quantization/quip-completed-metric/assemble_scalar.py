"""Train-only whole-input covariance allocation, then per-row joint FP16 field refit."""
import importlib.util
import sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
METRIC=Path('/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input/conditional-completed-train-metric.npy')
SOURCE=HERE.parent/'matched-rate-frontier/fit.py'
spec=importlib.util.spec_from_file_location('matched_scalar',SOURCE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

def options():
    c={};f={}
    for bits in (2,3):
        datasets=[np.load(HERE/f'group-{g}.npz') for g in range(8)]
        c[bits]=np.stack([d[f'codes{bits}'] for d in datasets],axis=1)
        f[bits]=np.stack([d[f'fields{bits}'].astype(float) for d in datasets],axis=1)
        for d in datasets:d.close()
    return c,f

def select():
    codes,fields=options()
    with np.load(mod.FIX) as f:w=f['weight'][:128].astype(float)
    gram=np.load(METRIC)
    base=(codes[3]*fields[3][:,:,0,None]+fields[3][:,:,1,None]).reshape(128,1024)
    low=(codes[2]*fields[2][:,:,0,None]+fields[2][:,:,1,None]).reshape(128,8,128)
    delta=low-base.reshape(128,8,128)
    gains=np.empty((128,8));interaction=np.empty((128,8,8))
    for row in range(128):
        d=np.zeros((1024,8))
        for g in range(8):d[g*128:(g+1)*128,g]=delta[row,g]
        c=d.T@gram@d
        interaction[row]=c
        gains[row]=2*d.T@gram@(w[row]-base[row])-np.diag(c)
    modes=np.zeros((128,8),dtype=bool)
    for _ in range(191):
        ranked=np.where(modes,-np.inf,gains)
        row,g=np.unravel_index(np.argmax(ranked),ranked.shape)
        modes[row,g]=True
        gains[row]-=2*interaction[row,:,g]
    assert int(modes.sum())==191
    selected_codes=np.where(modes[:,:,None],codes[2],codes[3]).astype(np.uint8)
    selected_fields=np.where(modes[:,:,None],fields[2],fields[3]).astype('<f2')
    np.savez(HERE/'selection.npz',codes=selected_codes,fields=selected_fields,modes=modes)
    residual=w-(selected_codes*selected_fields[:,:,0,None]+selected_fields[:,:,1,None]).reshape(128,1024)
    print('selected exactly',int(modes.sum()),'Q2 groups via completed M greedy; unrefitted relative M',float(np.sum(residual*(residual@gram))/np.sum(w*(w@gram))))

def refit(start,end):
    assert 0<=start<end<=128
    with np.load(HERE/'selection.npz') as data:
        codes=data['codes'];fields=data['fields'].astype(float)
    with np.load(mod.FIX) as f:w=f['weight'][:128].astype(float)
    gram=np.load(METRIC)
    improved=0
    for row in range(start,end):
        c=codes[row].astype(float);a=np.zeros((1024,16))
        for g in range(8):
            a[g*128:(g+1)*128,2*g]=c[g]
            a[g*128:(g+1)*128,2*g+1]=1
        lhs=a.T@gram@a;rhs=a.T@gram@w[row]
        try:solution=np.linalg.solve(lhs,rhs)
        except np.linalg.LinAlgError:continue
        candidate=solution.astype('<f2').astype(float).reshape(8,2)
        if not np.isfinite(candidate).all() or np.any(candidate[:,0]<=0):continue
        old=fields[row]
        before=(w[row]-a@old.reshape(-1))@gram@(w[row]-a@old.reshape(-1))
        after=(w[row]-a@candidate.reshape(-1))@gram@(w[row]-a@candidate.reshape(-1))
        if after<before:
            fields[row]=candidate;improved+=1
    np.savez(HERE/f'refit-{start:03d}-{end:03d}.npz',fields=np.asarray(fields[start:end],dtype='<f2'),improved=improved)
    print('joint row fields',start,end,'accepted',improved)

def finish():
    with np.load(HERE/'selection.npz') as data:
        modes=data['modes'];codes=data['codes'];fields=data['fields'].copy()
    count=0
    for start in range(0,128,32):
        with np.load(HERE/f'refit-{start:03d}-{start+32:03d}.npz') as part:
            fields[start:start+32]=part['fields'];count+=int(part['improved'])
    image=bytearray(np.packbits(modes.reshape(-1),bitorder='little').tobytes())
    for row in range(128):
        for g in range(8):
            bits=2 if modes[row,g] else 3
            image.extend(mod.pack(codes[row,g],bits))
            image.extend(np.asarray(fields[row,g],dtype='<f2').tobytes())
    assert len(image)==50320 and int(modes.sum())==191
    (HERE/'completed-group-q2q3-50320.bin').write_bytes(image)
    print('image bytes',len(image),'Q2 groups',int(modes.sum()),'joint full covariance row refits accepted',count)

if __name__=='__main__':
    operation=sys.argv[1]
    if operation=='select':select()
    elif operation=='refit':refit(int(sys.argv[2]),int(sys.argv[3]))
    elif operation=='finish':finish()
    else:raise ValueError(operation)
