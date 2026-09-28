#!/usr/bin/env python3
"""Stage the ADMM-only packed binary projection on the same 16 FP16 inputs."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

NANO = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures/model_layers_0_self_attn_q_proj_weight_0.55.npz')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(path, a):
    a.tofile(path)
    return {'bytes': int(a.nbytes), 'sha256': sha(path)}


def run(path, image=NANO):
    before = json.loads((path / 'inputs.json').read_text())
    x = np.fromfile(path / 'x.bin', dtype=np.float16).reshape(16, 1024).astype(np.float32)
    assert sha(path / 'x.bin') == before['inputs']['x']['sha256']
    with np.load(image) as f:
        assert f['dimensions'].tolist() == [2048, 1024, 352]
        images = {name: stage(path / ('nano_' + name + '.bin'), f[name])
                  for name in ('U', 'V', 'scale_pre', 'scale_post')}
        u = 2 * np.unpackbits(f['U'], axis=1, bitorder='little').astype(np.float32) - 1
        v = 2 * np.unpackbits(f['V'], axis=1, bitorder='little').astype(np.float32) - 1
        pre = f['scale_pre'].astype(np.float32)
        post = f['scale_post'].astype(np.float32)
        response = (((x * pre) @ v.T) @ u.T) * post
        original = np.fromfile(path / 'reference.bin', dtype=np.float32).reshape(16, 2048)
        reference = stage(path / 'nano_reference.bin', response.astype(np.float32))
        error = float(np.sum((response - original)**2) / np.sum(original**2))
        record = {'nano_fixture': str(image), 'nano_fixture_sha256': sha(image),
                  'source_sha256': sha(Path(__file__)),
                  'spectral_input_sha256': before['inputs']['x']['sha256'], 'dimensions': [2048, 1024, 352],
                  'images': images, 'reference': reference,
                  'reference_arithmetic': 'float32 x and fp16 pre-scale, float32 signed V GEMM, float32 signed U GEMM and fp16 post-scale',
                  'nano_response_vs_spectral_response_relative_squared_error': error,
                  'nano_payload_bytes_including_dimensions': sum(f[k].nbytes for k in f.files)}
        (path / 'nano_inputs.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('out', type=Path)
    p.add_argument('--image', type=Path, default=NANO)
    args = p.parse_args()
    run(args.out, args.image)
