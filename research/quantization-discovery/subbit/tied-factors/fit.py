#!/usr/bin/env python3
"""Train a signed low-rank residual for the pinned tied codebook, then encode row shards."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent/'tied-head'))
import codec

DATA = Path('/path/to/workspace/data/kelana-subbit/tied-factors')
HEAD = Path('/path/to/workspace/data/kelana-subbit/tied-head')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
ROWS, WIDTH, RANK = 151936, 1024, 64
SHARD = 18992


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def weights(ids):
    with safe_open(MODEL/'model.safetensors', framework='pt', device='cpu') as f:
        return f.get_tensor('model.embed_tokens.weight')[ids].float().numpy()


def base():
    with np.load(HEAD/'codebook64.npz') as z:
        labels = codec.unpack(z['labels'], 64, 6)
        return labels, z['scales'].astype(np.float32), z['code'].astype(np.float32)*float(z['unit'])


def residual(ids, labels, scales, code):
    decoded = code[labels[ids]].reshape(len(ids), WIDTH)*np.repeat(scales[ids], 128, axis=1)
    return weights(ids)-decoded


def randomized_basis(x, rank, seed):
    rng = np.random.default_rng(seed)
    omega = rng.standard_normal((x.shape[1], rank+12)).astype(np.float32)
    q, _ = np.linalg.qr(x@omega, mode='reduced')
    for _ in range(2):
        q, _ = np.linalg.qr(x@(x.T@q), mode='reduced')
    _, _, v = np.linalg.svd(q.T@x, full_matrices=False)
    return v[:rank].astype(np.float32)


def train():
    DATA.mkdir(parents=True, exist_ok=True)
    with np.load(HEAD/'frequency.npz') as z: counts=z['train'].copy()
    with np.load(HEAD/'final-head.npz') as z: hidden=z['train_hidden'].copy()
    labels, scales, code = base()
    rng = np.random.default_rng(50916)
    order=np.lexsort((np.arange(ROWS),-counts))
    ids=np.unique(np.r_[rng.choice(ROWS, 8192, replace=False),order[:4096]])
    r=residual(ids,labels,scales,code)
    # Half of the directions target residual weight geometry; half target the
    # response geometry of the real normalized training head inputs.
    eu=randomized_basis(r, RANK//2, 7101)
    h=hidden[::4]
    response=r@h.T
    q=randomized_basis(response,RANK//2,7102)
    left=response@q.T
    head=left.T@r
    head/=np.maximum(np.linalg.norm(head,axis=1,keepdims=True),1.e-12)
    directions=np.vstack((eu,head)).astype(np.float32)
    projection=r@directions.T
    signs=np.where(projection>=0,1.,-1.).astype(np.float32)
    # The single FP16 row amplitude absorbs the row-to-row residual magnitude.
    amplitude=np.linalg.norm(projection,axis=1)/(RANK**0.5)
    basis=(np.linalg.lstsq(signs*amplitude[:,None],r,rcond=1.e-4)[0]).astype(np.float32)
    np.savez(DATA/'basis.npz',basis=basis.astype(np.float16),sample_ids=ids.astype(np.int32))
    receipt={'format':'tied-signed-residual-basis/1','source_sha256':sha(HERE/'fit.py'),
             'base_sha256':sha(HEAD/'codebook64.npz'),'capture_sha256':sha(HEAD/'final-head.npz'),
             'frequency_sha256':sha(HEAD/'frequency.npz'),
             'model_sha256':sha(MODEL/'model.safetensors'),
             'train_rows':len(ids),'train_hidden_rows':len(hidden),'rank':RANK,
             'fit':'32 residual PCA + 32 head-response PCA directions; binary signs and row amplitude, joint least-squares basis; train only',
             'basis_sha256':sha(DATA/'basis.npz')}
    (DATA/'basis.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'train_rows':len(ids),'basis_sha256':receipt['basis_sha256']}))


def encode(part):
    assert 0<=part<8
    with np.load(DATA/'basis.npz') as z: basis=z['basis'].astype(np.float32)
    labels,scales,code=base()
    ids=np.arange(part*SHARD,(part+1)*SHARD)
    r=residual(ids,labels,scales,code)
    # A signed row's optimum amplitude for its chosen signs is a scalar LS fit.
    # Two coordinate updates correct sign errors due to correlated basis vectors.
    projection=r@basis.T
    signs=np.where(projection>=0,1.,-1.).astype(np.float32)
    gram=basis@basis.T
    for _ in range(2):
        bg=signs@gram
        amplitude=np.maximum(0.,np.sum(projection*signs,axis=1)/np.maximum(np.sum(bg*signs,axis=1),1.e-16))
        for j in range(RANK):
            choice=projection[:,j]-amplitude*(bg[:,j]-signs[:,j]*gram[j,j])
            changed=np.where(choice>=0,1.,-1.)-signs[:,j]
            signs[:,j]+=changed
            bg+=changed[:,None]*gram[j]
    bg=signs@gram
    amplitude=np.maximum(0.,np.sum(projection*signs,axis=1)/np.maximum(np.sum(bg*signs,axis=1),1.e-16))
    amp16=amplitude.astype(np.float16)
    if not np.isfinite(amp16).all():raise ValueError('invalid amplitude')
    packed=np.packbits(signs>0,axis=1,bitorder='little')
    image=DATA/f'shard{part}.npz'
    np.savez_compressed(image,signs=packed,amplitude=amp16)
    e=r-amp16.astype(np.float32)[:,None]*(np.where(np.unpackbits(packed,axis=1,bitorder='little')[:,:RANK]>0,1.,-1.)@basis)
    receipt={'format':'tied-signed-residual-shard/1','part':part,'row_start':int(ids[0]),'row_stop':int(ids[-1]+1),
             'basis_sha256':sha(DATA/'basis.npz'),'base_sha256':sha(HEAD/'codebook64.npz'),
             'source_sha256':sha(HERE/'fit.py'),'image_sha256':sha(image),
             'residual_mse_before':float(np.mean(r*r)),'residual_mse_after':float(np.mean(e*e)),
             'payload_bytes':int(packed.nbytes+amp16.nbytes)}
    (DATA/f'shard{part}.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'part':part,'before':receipt['residual_mse_before'],'after':receipt['residual_mse_after']}))

if __name__=='__main__':
    if len(sys.argv)==2 and sys.argv[1]=='train':train()
    elif len(sys.argv)==3 and sys.argv[1]=='encode':encode(int(sys.argv[2]))
    else:raise SystemExit('fit.py train | encode PART[0..7]')
