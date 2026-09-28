#!/usr/bin/env python3
"""Price one conventional radius+signed-direction activation state at the real skip."""
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
CAPTURE = Path('/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-producer-capture.npz')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
EPS = 1e-6


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def bf16(bits):
    return (bits.astype(np.uint32) << 16).view(np.float32)


def norm(t, gamma):
    return t * (1 / np.sqrt(np.mean(t*t, axis=1, keepdims=True) + EPS)) * gamma


def rms(pred, target):
    return float(np.linalg.norm((pred-target).astype(np.float64)) / np.linalg.norm(target.astype(np.float64)))


def screen(t, gamma, reader):
    s = np.max(np.abs(t), axis=1, keepdims=True) / 127
    q = np.clip(np.rint(t/s), -127, 127).astype(np.int8)
    # Familiar activation quantization: refit only the radius once, same 2-byte slot.
    least_squares = (np.sum(q.astype(np.float64)*t, axis=1, keepdims=True) /
                     np.sum(q.astype(np.float64)**2, axis=1, keepdims=True)).astype(np.float32)
    nt = norm(t, gamma)
    target = nt @ reader
    arms = {}
    for name, scale in (('max', s), ('least_squares', least_squares)):
        stored = scale.astype(np.float16)
        decoded = q.astype(np.float32)*stored.astype(np.float32)
        normalized = norm(decoded, gamma)
        arms[name] = {'state_relative_rms':rms(decoded,t),
                      'next_full_norm_relative_rms':rms(normalized,nt),
                      'next_all_qkv_relative_rms':rms(normalized@reader,target),
                      'scale_underflow_count':int(np.count_nonzero(stored==0))}
    return arms


def main():
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        gamma = f.get_tensor('model.layers.1.input_layernorm.weight').float().numpy()
        reader = np.concatenate([f.get_tensor('model.layers.1.self_attn.'+p+'_proj.weight').float().numpy()
                                 for p in ('q','k','v')]).T.copy()
    if np.any(gamma == 0):
        raise ValueError('full-norm injectivity premise fails: zero gamma')
    result={'model_sha256':sha(MODEL),'capture_sha256':sha(CAPTURE), 'epsilon':EPS,
            'state_bytes_per_token':1026, 'bf16_state_bytes_per_token':2048,
            'next_gamma_nonzero':True, 'next_qkv_rows':reader.shape[1], 'splits':{}}
    with np.load(CAPTURE) as f:
        for split in ('train','validation'):
            t=bf16(f[f'{split}_teacher_post'].copy())
            result['splits'][split]={'positions':len(t), **screen(t,gamma,reader)}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['splits'],indent=2))


if __name__=='__main__': main()
