#!/usr/bin/env python3
"""One frozen layer-1 CPU source-record discriminator; no model forward or attention."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
from provenance import check as check_source_provenance

ROOT = Path('/path/to/workspace/data/kelana-subbit')
CAPTURE = ROOT / 'full-model/mlp-quantized-producer-capture.npz'
META = CAPTURE.with_suffix('.json')
TOKENS = ROOT / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
MODEL = ROOT / 'models/qwen3-0.6b/model.safetensors'
HERE = Path(__file__).resolve().parent
EXPECTED = {
    str(CAPTURE): 'aa1e671af9283656efd7a95f2732a27662ce8c658766af5ee88f5e7d27b9e69c',
    str(TOKENS): '0479292cbee2cfc6cfc5f89e8f85dac85d2c0c275ed2704a59a7006faa7d66a2',
    str(MODEL): 'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b',
}


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def bf16_bits(fp32):
    """Round to nearest even, including ties, by retained mantissa LSB."""
    b = np.ascontiguousarray(fp32, dtype=np.float32).view(np.uint32)
    return ((b + np.uint32(0x7fff) + ((b >> 16) & 1)) >> 16).astype('<u2')


def fp32(bits):
    return (np.asarray(bits, dtype=np.uint32) << 16).view(np.float32)


def quantize_v(bits):
    """Original KIVI2 value_token: four 32-channel groups per KV head."""
    assert bits.shape == (8, 128) and bits.dtype == np.uint16
    result = bytearray()
    for head in bits:
        digits = np.empty(128, dtype=np.uint8)
        fields = bytearray()
        for group in range(4):
            data = fp32(head[group*32:(group+1)*32])
            low = float(data.min())
            step = (float(data.max()) - low) / 3
            digits[group*32:(group+1)*32] = (np.zeros(32, np.uint8) if step == 0 else
                np.clip(np.rint((data-low)/step), 0, 3).astype(np.uint8))
            fields += np.array((low, step), dtype='<f2').tobytes()
        result += (digits[::4] | (digits[1::4] << 2) |
                   (digits[2::4] << 4) | (digits[3::4] << 6)).tobytes() + fields
    assert len(result) == 384
    return bytes(result)


def counts(records):
    return {'total': len(records), 'unique': len(set(records)),
            'repeated_occurrences': len(records)-len(set(records))}


def run(split, window):
    assert split in ('train', 'validation') and 0 <= window < (8 if split == 'train' else 4)
    recovered_source = check_source_provenance()
    meta = json.loads(META.read_text())
    assert meta['format'] == 'layer0-narrow-quantized-mlp-producer/1'
    assert meta['source_sha256'] == '42eae1e97b1a5a609022f62df15770c6f9ffb10505e46dcbc7987c74ffa5883d'
    assert meta['capture_sha256'] == EXPECTED[str(CAPTURE)]
    for path, expected in EXPECTED.items():
        assert sha(Path(path)) == expected, path
    assert all(meta['inputs_sha256'][path] == expected for path, expected in EXPECTED.items() if path != str(CAPTURE))
    with np.load(TOKENS) as f:
        ids = f[split][window].copy()
    with np.load(CAPTURE) as f:
        source = f[f'{split}_teacher_post'][window*256:(window+1)*256].copy()
    assert source.shape == (256, 1024) and ids.shape == (256,) and source.dtype == np.uint16
    with safe_open(MODEL, framework='pt', device='cpu') as f:
        gamma = f.get_tensor('model.layers.1.input_layernorm.weight').to(dtype=torch.float32).numpy().copy()
        weight = f.get_tensor('model.layers.1.self_attn.v_proj.weight').to(dtype=torch.float32).numpy().copy()
    assert gamma.shape == (1024,) and weight.shape == (1024, 1024)
    residual = fp32(source)
    # Explicit CPU discriminator: FP32 square/mean/rsqrt, BF16 round normalized
    # activation, FP32 gamma product then BF16 round, FP32 GEMM then BF16 round.
    normed = bf16_bits(residual * np.reciprocal(np.sqrt(
        np.mean(residual*residual, axis=1, keepdims=True) + np.float32(1e-6))))
    normed = bf16_bits(fp32(normed) * gamma)
    vbits = bf16_bits(fp32(normed) @ weight.T)
    raw = [row.astype('<u2').tobytes() for row in source]
    normalized = [row.astype('<u2').tobytes() for row in normed]
    value = [row.astype('<u2').tobytes() for row in vbits]
    packed = [quantize_v(row.reshape(8, 128)) for row in vbits]
    assert all(len(r) == 2048 for r in (raw + value)) and all(len(r) == 384 for r in packed)
    same_id_pairs = sum(ids[i] == ids[j] for i in range(256) for j in range(i))
    same_id_raw = sum(ids[i] == ids[j] and raw[i] == raw[j] for i in range(256) for j in range(i))
    same_id_v = sum(ids[i] == ids[j] and value[i] == value[j] for i in range(256) for j in range(i))
    same_id_packed = sum(ids[i] == ids[j] and packed[i] == packed[j] for i in range(256) for j in range(i))
    phases = {}
    for phase in ('before', 'after'):
        stats = []
        for t in range(1, 257):
            nq = max(0, t - (33 if phase == 'before' else 32))
            q, r = packed[:nq], value[nq:t]
            stats.append({'t': t, 'quant': counts(q), 'recent': counts(r)})
        phases[phase] = {
            'max_quant_unique': max(s['quant']['unique'] for s in stats),
            'first_exceeds_148': next((s['t'] for s in stats if s['quant']['unique'] > 148), None),
            'max_recent_unique': max(s['recent']['unique'] for s in stats),
            't181': stats[180], 't256': stats[-1],
        }
    receipt = {'source_sha256': EXPECTED, 'capture_meta_sha256': sha(META),
               'recovered_source_provenance': recovered_source,
               'capture_producer_sha256_in_metadata': meta['source_sha256'],
               'panel': split, 'window': window, 'layer': 1, 'positions': 256,
               'token_ids': counts([int(x) for x in ids]), 'captured_residual_bf16': counts(raw),
               'normalized_input_bf16': counts(normalized), 'full8_v_bf16': counts(value),
               'full8_g32_kivi2_v': counts(packed),
               'same_token_id_pairs': int(same_id_pairs), 'same_id_and_raw_pairs': int(same_id_raw),
               'same_id_and_v_pairs': int(same_id_v), 'same_id_and_packed_pairs': int(same_id_packed),
               'phases': phases}
    dest = HERE / f'{split}-{window}.json'
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'panel': split, 'window': window,
                      'raw': receipt['captured_residual_bf16'], 'v': receipt['full8_v_bf16'],
                      'packed': receipt['full8_g32_kivi2_v'], 'before': phases['before']}))


if __name__ == '__main__':
    run(sys.argv[1], int(sys.argv[2]))
