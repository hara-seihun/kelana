"""Prepare a full Qwen3-0.6B layer-0 paired image and native reader inputs."""
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open

ROOT = Path(__file__).parent
BUILD = ROOT / 'build'
SOURCE = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
CAPTURE = Path('/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-producer-capture.npz')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/vector-full/images/layer00-polar-8bit.npz')
LEARNED = Path('/path/to/workspace/data/kelana-subbit/vector-full/images/layer00-learned_pair-8bit.npz')
SCALAR = Path('/path/to/workspace/data/kelana-subbit/vector-full/images/layer00-scalar_scale-8bit.npz')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare():
    BUILD.mkdir(exist_ok=True)
    with safe_open(SOURCE, framework='pt', device='cpu') as f:
        gate = f.get_tensor('model.layers.0.mlp.gate_proj.weight').float().numpy()
        up = f.get_tensor('model.layers.0.mlp.up_proj.weight').float().numpy()
    assert gate.shape == up.shape == (3072, 1024)
    with np.load(IMAGE) as image:
        gain = image['gain'].item()
        polar = image['table'].astype('<f2')
        polar_indices = image['codes'].astype('u1')
    assert polar.shape == (256, 2) and polar_indices.shape == gate.shape
    with np.load(SCALAR) as image:
        scalar_indices = image['codes'].astype('u1')
        scales = image['scales'].astype('<f2')
    signs = np.array([-3., -1., 1., 3.])
    patterns = np.stack(np.meshgrid(signs, signs, indexing='ij'), axis=-1).reshape(16, 2)
    assert scales.shape == (16,) and scalar_indices.shape == gate.shape
    scalar = (scales[:, None, None].astype('f4') * patterns[None]).reshape(256, 2).astype('<f2')
    scales.tofile(BUILD / 'scalar-scales.f16')
    approximations = []
    for name, indices, table in [('polar', polar_indices, polar), ('scalar', scalar_indices, scalar)]:
        indices.tofile(BUILD / f'{name}.u8')
        table.tofile(BUILD / f'{name}.f16')
        approximations.append(table.astype('f4')[indices])
    with np.load(LEARNED) as learned:
        learned_codes = learned['codes'].astype('u1')
        learned_table = learned['table'].astype('<f2')
    learned_codes.tofile(BUILD / 'learned.u8')
    learned_table.tofile(BUILD / 'learned.f16')
    approximations.append(learned_table.astype('f4')[learned_codes])
    expanded = np.stack([gate.astype('<f2'), up.astype('<f2')], axis=-1)
    expanded.tofile(BUILD / 'original.f16')
    with np.load(CAPTURE) as capture:
        x = capture['validation_teacher_input'][576:584]
        assert x.shape == (8, 1024)
        if x.dtype == np.uint16:
            x = (x.astype('u4') << 16).view('f4')
        else:
            x = x.astype('f4')
        x.astype('<f4').tofile(BUILD / 'inputs.f32')
    np.array([gain], dtype='<f2').tofile(BUILD / 'gain.f16')
    approximations.append(expanded.astype('f4'))
    for name, weights in zip(('polar', 'scalar', 'learned', 'original'), approximations):
        a = x @ weights[:, :, 0].T
        b = x @ weights[:, :, 1].T
        y = (a / (1 + np.exp(-a))) * b
        y.astype('<f4').tofile(BUILD / f'reference-{name}.f32')
    receipt = {'source_sha256': digest(SOURCE), 'capture_sha256': digest(CAPTURE),
               'polar_image_sha256': digest(IMAGE), 'learned_image_sha256': digest(LEARNED),
               'scalar_image_sha256': digest(SCALAR),
               'dimensions': [3072, 1024], 'input_shape': [8, 1024],
               'gain_fp16': float(gain),
               'image_sha256': {p.name: digest(p) for p in sorted(BUILD.iterdir())
                                if p.suffix in ('.f16', '.u8', '.f32')}}
    (BUILD / 'fixture.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: v for k, v in receipt.items() if k != 'image_sha256'}))


if __name__ == '__main__':
    prepare()
