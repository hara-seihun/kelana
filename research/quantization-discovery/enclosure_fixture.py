#!/usr/bin/env python3
"""Capture exact integer producer blocks and source FP32 observations, CPU only."""
import hashlib
import importlib.util
import json
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
BASE = Path('/path/to/workspace/data/kelana-ffn/ptq1_0/layer00')
DECODER = HERE.parent/'ffn/batched/deferred-carrier/carrier_scan.py'


def capture():
    spec = importlib.util.spec_from_file_location('carrier_scan', DECODER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    q = np.fromfile(BASE/'r8/xq_d.i8', np.int8).reshape(8, 40, 128)
    arrays = dict(q=q, input_scales=np.fromfile(BASE/'r8/xs_d.f32', '<f4').reshape(8, 40),
                  input_sums=np.fromfile(BASE/'r8/xsum_d.i32', '<i4').reshape(8, 40))
    assert np.array_equal(q.astype(np.int32).sum(axis=-1), arrays['input_sums'])
    paths = [BASE/'manifest.json', BASE/'r8/xq_d.i8', BASE/'r8/xs_d.f32', BASE/'r8/xsum_d.i32']
    for name in ('gate', 'up'):
        weights, scales = module.halo_matrix(BASE/(name+'.halo'), 17408, 5120)
        weights = weights[:1024].reshape(1024, 40, 128).astype(np.int32)
        arrays[name+'_dot'] = np.einsum('ibk,tbk->tib', weights, q.astype(np.int32), dtype=np.int32)
        arrays[name+'_scales'] = scales[:1024].copy()
        arrays[name+'_observed'] = np.fromfile(BASE/('r8/'+name+'.f32'), '<f4').reshape(8, 17408)[:, :1024].copy()
        paths += [BASE/(name+'.halo'), BASE/('r8/'+name+'.f32')]
        del weights, scales
    arrays['signs'] = np.fromfile(BASE/'signs_ff.f32', '<f4')[:1024]
    arrays['hidden_codes'] = np.fromfile(BASE/'r8/xq_ff.i8', np.int8).reshape(8, 17408)[:, :1024].copy()
    arrays['hidden_scales'] = np.fromfile(BASE/'r8/xs_ff.f32', '<f4').reshape(8, 136)[:, :8].copy()
    arrays['hidden_sums'] = np.fromfile(BASE/'r8/xsum_ff.i32', '<i4').reshape(8, 136)[:, :8].copy()
    assert np.array_equal(arrays['hidden_codes'].reshape(8, 8, 128).astype(np.int32).sum(axis=-1), arrays['hidden_sums'])
    paths += [BASE/'signs_ff.f32', BASE/'r8/xq_ff.i8', BASE/'r8/xs_ff.f32', BASE/'r8/xsum_ff.i32']
    target = HERE/'instances/bonsai-layer00-producer-chunk0.npz'
    np.savez_compressed(target, **arrays)
    provenance = dict(scope='Eight fixed upstream code vectors; first 1024 hidden coordinates; all 40 input blocks.',
                      source_manifest=json.loads((BASE/'manifest.json').read_text()),
                      source_sha256={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
                      decoder=str(DECODER.relative_to(HERE.parent.parent)),
                      decoder_sha256=hashlib.sha256(DECODER.read_bytes()).hexdigest(),
                      fixture_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                      shapes={k: list(v.shape) for k, v in arrays.items()})
    (HERE/'instances/bonsai-layer00-producer-chunk0.json').write_text(json.dumps(provenance, indent=2)+'\n')
    print(json.dumps(dict(path=str(target), bytes=target.stat().st_size, shapes=provenance['shapes']), indent=2))


if __name__ == '__main__':
    capture()
