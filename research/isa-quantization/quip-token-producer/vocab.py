"""Exact all-ID second moment for the pinned layer-0 token producer.

Each chunk is independently bounded; merge removes redundant intermediate chunks.
"""
from pathlib import Path
import argparse
import io
import numpy as np
import torch
from safetensors import safe_open
from producer import HERE, MODEL, normalize

N=151936
CHUNKS=8
DATA=Path('/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input/uniform-id-second-moment.npy')


def chunk(index):
    assert 0<=index<CHUNKS
    start=N*index//CHUNKS;end=N*(index+1)//CHUNKS
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as f:
        emb=f.get_tensor('model.embed_tokens.weight')
        gamma=f.get_tensor('model.layers.0.input_layernorm.weight')
        assert emb.shape==(N,1024)
        # Avoid large model-specific intermediates outside the pinned checkpoint.
        x=normalize(emb[start:end],gamma).numpy().astype(np.float64)
    second=x.T@x
    np.save(HERE/f'chunk-{index}.npy',second)
    print('source IDs',start,end,'rows',len(x),'gram diagonal sum',float(np.trace(second)))


def merge():
    files=[HERE/f'chunk-{i}.npy' for i in range(CHUNKS)]
    assert all(p.exists() for p in files)
    gram=sum(np.load(p) for p in files)/N
    assert gram.shape==(1024,1024) and np.isfinite(gram).all()
    stream=io.BytesIO();np.save(stream,gram)
    image=stream.getvalue()
    if DATA.exists():
        assert DATA.read_bytes()==image, 'existing owned source moment differs'
    else:
        DATA.parent.mkdir(parents=True,exist_ok=True)
        DATA.write_bytes(image)
    for path in files:path.unlink()
    print('full uniform-ID second moment',gram.shape,'trace',float(np.trace(gram)),'owner',DATA)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('mode',choices=('chunk','merge'));p.add_argument('index',nargs='?',type=int)
    a=p.parse_args()
    if a.mode=='chunk':chunk(a.index)
    else:merge()
