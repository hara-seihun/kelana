"""Full-covariance response-sensitive mixed group128 Q3/Q4 image at 54,416 B."""
from pathlib import Path
import importlib.util
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'matched-rate-frontier/fit.py'
spec=importlib.util.spec_from_file_location('matched_scalar',SOURCE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)


def main():
    codes={};fields={}
    for bits in (3,4):
        with_files=[np.load(HERE/f'group-{g}.npz') for g in range(8)]
        codes[bits]=np.stack([p[f'codes{bits}'] for p in with_files],axis=1)
        fields[bits]=np.stack([p[f'fields{bits}'].astype(float) for p in with_files],axis=1)
        for p in with_files:p.close()
    with np.load(mod.FIX) as f:
        x=f['train'].astype(float);w=f['weight'][:128].astype(float)
    assert x.shape==(2048,1024) and w.shape==(128,1024)
    gram=x.T@x
    base=(codes[3]*fields[3][:,:,0,None]+fields[3][:,:,1,None]).reshape(128,1024)
    high=(codes[4]*fields[4][:,:,0,None]+fields[4][:,:,1,None]).reshape(128,8,128)
    delta=high-base.reshape(128,8,128)
    gains=np.empty((128,8));interaction=np.empty((128,8,8))
    for row in range(128):
        d=np.zeros((1024,8))
        for g in range(8):d[g*128:(g+1)*128,g]=delta[row,g]
        c=d.T@gram@d
        interaction[row]=c
        gains[row]=2*d.T@gram@(w[row]-base[row])-np.diag(c)
    modes=np.zeros((128,8),dtype=bool)
    for _ in range(65):
        ranked=np.where(modes,-np.inf,gains)
        row,g=np.unravel_index(np.argmax(ranked),ranked.shape)
        modes[row,g]=True
        gains[row]-=2*interaction[row,:,g]
    selected_codes=np.where(modes[:,:,None],codes[4],codes[3]).astype(np.uint8)
    selected_fields=np.where(modes[:,:,None],fields[4],fields[3]).copy()
    joint_refit_count=0
    for row in range(128):
        c=selected_codes[row].astype(float)
        a=np.zeros((1024,16))
        for g in range(8):
            a[g*128:(g+1)*128,2*g]=c[g]
            a[g*128:(g+1)*128,2*g+1]=1
        try:sol=np.linalg.solve(a.T@gram@a,a.T@gram@w[row])
        except np.linalg.LinAlgError:continue
        candidate=sol.astype('<f2').astype(float).reshape(8,2)
        if not np.isfinite(candidate).all() or np.any(candidate[:,0]<=0):continue
        old=selected_fields[row]
        before=(w[row]-a@old.reshape(-1))@gram@(w[row]-a@old.reshape(-1))
        after=(w[row]-a@candidate.reshape(-1))@gram@(w[row]-a@candidate.reshape(-1))
        if after<before:
            selected_fields[row]=candidate
            joint_refit_count+=1
    mask=np.packbits(modes.reshape(-1),bitorder='little').tobytes()
    image=bytearray(mask)
    for row in range(128):
        for g in range(8):
            bits=4 if modes[row,g] else 3
            image.extend(mod.pack(selected_codes[row,g],bits))
            image.extend(np.asarray(selected_fields[row,g],dtype='<f2').tobytes())
    assert len(image)==54416 and modes.sum()==65
    (HERE/'refit-group-q3q4-54416.bin').write_bytes(image)
    print('scalar image',len(image),'bytes; upgrades',int(modes.sum()),'joint full-covariance row refits',joint_refit_count)


if __name__=='__main__':main()
