#!/usr/bin/env python3
"""Prepare source gate/up Gaussian-law sufficient moments from existing full-state captures."""
import argparse
from pathlib import Path
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
PARENT=HERE.parent/'nonlinear-response-bank'
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--split',choices=('train','held'),required=True)
    args=parser.parse_args()
    x=np.concatenate([np.load(PARENT/f'{args.split}-{i}.npz')['inputs'] for i in range(4)]).astype(np.float32)
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        gate=f.get_tensor('model.layers.0.mlp.gate_proj.weight').float().numpy()
        up=f.get_tensor('model.layers.0.mlp.up_proj.weight').float().numpy()
    g=x@gate.T
    u=x@up.T
    np.savez_compressed(HERE/f'preactivation-{args.split}.npz',g=g,u=u)
    print('preactivation',args.split,g.shape,'gate mean/std',np.median(g.mean(0)),np.median(g.std(0)),
          'gate extremes',g.min(),g.max(),'up mean/std',np.median(u.mean(0)),np.median(u.std(0)))


if __name__=='__main__': main()
