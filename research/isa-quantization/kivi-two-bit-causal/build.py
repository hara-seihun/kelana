"""Fixed KIVI K2/V2 G32/R32: pack actual full-layer causal flush events."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'skvq-global-gqa'))
from source import arrays, FIX_SHA  # original complete 16Q/8KV source; not a new capture

KEY_CHUNK = 32 * 128 // 4 + 128 * 4  # 1536: 2-bit codes + FP16 min/step
VALUE_TOKEN = 128 // 4 + 4 * 4      # 48: 2-bit codes + FP16 min/step
RECENT = 32


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def pack(codes):
    c = np.asarray(codes, dtype=np.uint8).ravel()
    assert len(c) % 4 == 0 and np.all(c < 4)
    return (c[::4] | (c[1::4] << 2) | (c[2::4] << 4) | (c[3::4] << 6)).tobytes()


def quantize(data):
    """Same source min/max and nearest-even assignment as pinned KIVI4, divisor 3."""
    data = np.asarray(data, dtype=np.float32)
    low = float(data.min())
    step = (float(data.max()) - low) / 3
    digits = np.zeros(data.size, dtype=np.uint8) if step == 0 else np.clip(np.rint((data - low) / step), 0, 3).astype(np.uint8)
    fields = np.array((low, step), dtype='<f2')
    assert np.isfinite(fields).all() and fields[1] >= 0
    return digits, fields.tobytes()


def bf16(bits):
    return (np.asarray(bits, dtype=np.uint32) << 16).view(np.float32)


def key_chunk(source):
    assert source.shape == (32, 128) and source.dtype == np.uint16
    data = bf16(source)
    code = np.empty((32, 128), dtype=np.uint8)
    fields = bytearray()
    for channel in range(128):
        code[:, channel], f = quantize(data[:, channel])
        fields += f
    blob = pack(code) + fields
    assert len(blob) == KEY_CHUNK
    return blob


def value_token(source):
    assert source.shape == (128,) and source.dtype == np.uint16
    data = bf16(source)
    code = np.empty(128, dtype=np.uint8)
    fields = bytearray()
    for group in range(4):
        code[group * 32:(group + 1) * 32], f = quantize(data[group * 32:(group + 1) * 32])
        fields += f
    blob = pack(code) + fields
    assert len(blob) == VALUE_TOKEN
    return blob


def serialize(kq, vq, kr, vr):
    return b''.join(kq) + b''.join(vq) + b''.join(kr) + b''.join(vr)


def receipt(kq, vq, kr, vr):
    state = serialize(kq, vq, kr, vr)
    sizes = {'key_quant_chunks': len(kq), 'value_quant_tokens': len(vq),
             'key_recent_tokens': len(kr), 'value_recent_tokens': len(vr),
             'key_quant_bytes': len(kq) * KEY_CHUNK, 'value_quant_bytes': len(vq) * VALUE_TOKEN,
             'key_recent_bytes': len(kr) * 256, 'value_recent_bytes': len(vr) * 256}
    assert sum(sizes[x] for x in ('key_quant_bytes', 'value_quant_bytes', 'key_recent_bytes', 'value_recent_bytes')) == len(state)
    return {'bytes': len(state), 'sha256': sha(state), **sizes}


def run(panel, window):
    src = arrays(panel, window)
    key = src['krot'].permute(1, 0, 2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
    value = src['value'].reshape(256, 8, 128)
    assert key.shape == value.shape == (256, 8, 128)
    groups = {}
    for h in range(8):
        kq, vq, kr, vr, events, prefixes = [], [], [], [], bytearray(), []
        peak = 0
        for t in range(1, 257):
            kr.append(key[t-1, h].astype('<u2').tobytes())
            vr.append(value[t-1, h].astype('<u2').tobytes())
            before = receipt(kq, vq, kr, vr)
            peak = max(peak, before['bytes'])
            if len(kr) == RECENT:
                chunk = key_chunk(np.frombuffer(b''.join(kr), dtype='<u2').reshape(32, 128))
                kq.append(chunk)
                kr.clear()
                events += b'K' + t.to_bytes(2, 'little') + chunk
            if len(vr) > RECENT:
                token = value_token(np.frombuffer(vr.pop(0), dtype='<u2'))
                vq.append(token)
                events += b'V' + t.to_bytes(2, 'little') + token
            prefixes.append({'position': t-1, 'before_query_flush': before,
                             'after_query_flush': receipt(kq, vq, kr, vr)})
        final = serialize(kq, vq, kr, vr)
        assert peak == 38096 and len(final) == 31232
        name = f'{panel}-{window}-head{h}'
        (HERE / f'{name}-events.bin').write_bytes(events)
        (HERE / f'{name}-final.bin').write_bytes(final)
        groups[f'kv{h}'] = {'peak_bytes': peak, 'final_bytes': len(final),
                             'events_bytes': len(events), 'events_sha256': sha(events),
                             'final_sha256': sha(final), 'prefixes': prefixes}
    manifest = {'panel': panel, 'window': window, 'fixture_sha256': FIX_SHA,
                'source': 'Qwen3-0.6B BF16 layer0 original full16Q/8KV, post-RoPE recent K',
                'method': 'official-supported KIVI K2/V2 G32/R32; FP16 min/step, BF16 recent, after-query flush',
                'peak_full_layer_bytes': 304768, 'final_full_layer_bytes': 249856,
                'groups': groups, 'events_are_evidence_not_retained_state': True}
    (HERE / f'{panel}-{window}-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'panel':panel, 'window':window, 'peak':304768, 'final':249856}))

if __name__ == '__main__':
    run(sys.argv[1], int(sys.argv[2]))
