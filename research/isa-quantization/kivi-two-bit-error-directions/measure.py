"""Four frozen full-layer KIVI2 counterfactuals on retained held snapshots only."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SNAP = ROOT / 'kivi-two-bit-dot-native'
ARRIVAL = ROOT / 'kivi-value-intern'
OWNER = ROOT / 'kivi-two-bit-causal'
sys.path.insert(0, str(OWNER))
import replay


def digest(data):
    return hashlib.sha256(data).hexdigest()


def pinned(path, expected):
    data = path.read_bytes()
    assert digest(data) == expected, path
    return data


def vector(path, expected, count):
    data = pinned(path, expected)
    assert len(data) == count * 4
    return torch.from_numpy(np.frombuffer(data, '<f4').copy())


def run():
    torch.set_num_threads(1)
    manifest_path = SNAP / 'snapshots.json'
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    o_data = pinned(SNAP / 'original-o.bf16', manifest['original_o_sha256'])
    o = torch.from_numpy(replay.bf16(np.frombuffer(o_data, '<u2').reshape(1024, 2048)).copy())
    stream_cache = {}
    receipts = []
    total = np.zeros((4, 4), dtype=np.float64)
    total_ref = 0.
    max_closure = max_cpu_abs = 0.
    for record in manifest['states']:
        tag = record['tag']
        window, t = record['window'], record['position']
        assert tag == f'held-{window}-t{t}' and t in (128, 256)
        if window not in stream_cache:
            name = f'held-{window}'
            audit_data = (ARRIVAL / f'{name}-manifest.json').read_bytes()
            audit = json.loads(audit_data)
            original = json.loads((OWNER / f'{name}-manifest.json').read_bytes())
            assert audit['source_fixture_sha256'] == manifest['fixture_sha256'] == original['fixture_sha256']
            assert audit['baseline_manifest_sha256'] == digest((OWNER / f'{name}-manifest.json').read_bytes())
            assert audit['baseline_events_sha256'] == record['owner_event_sha256']
            events = []
            for h, expected in enumerate(record['owner_event_sha256']):
                log = pinned(OWNER / f'{name}-head{h}-events.bin', expected)
                parsed = {'K': [], 'V': []}
                pos = 0
                while pos < len(log):
                    kind = chr(log[pos]); assert kind in parsed
                    length = 1536 if kind == 'K' else 48
                    position = int.from_bytes(log[pos+1:pos+3], 'little')
                    blob = log[pos+3:pos+3+length]
                    assert len(blob) == length and 1 <= position <= 256
                    assert position == (len(parsed['K'])+1)*32 if kind == 'K' else position == len(parsed['V'])+33
                    parsed[kind].append((position, blob))
                    pos += length+3
                events.append(parsed)
            stream = pinned(ARRIVAL / f'{name}-events.bin', audit['events_sha256'])
            assert len(stream) == audit['events_bytes'] == 256 * 4098
            raw = np.frombuffer(stream, dtype=np.uint8).reshape(256, 4098)
            assert np.array_equal(raw[:, :2], np.arange(1, 257, dtype='<u2').view(np.uint8).reshape(256, 2))
            kb = np.ascontiguousarray(raw[:, 2:2050]).view('<u2').reshape(256, 8, 128)
            vb = np.ascontiguousarray(raw[:, 2050:]).view('<u2').reshape(256, 8, 128)
            stream_cache[window] = (kb, vb, audit, original, events, digest(audit_data))
        kb, vb, audit, original, events, audit_manifest_sha = stream_cache[window]
        q = vector(SNAP / f'{tag}-q.f32', record['query_sha256'], 2048).reshape(16, 128)
        teacher = vector(SNAP / f'{tag}-teacher.f32', record['teacher_sha256'], 1024)
        conventional = vector(SNAP / f'{tag}-conventional-cpu.f32', record['cpu_conventional_sha256'], 1024)
        pinned(SNAP / f'{tag}-byte-cpu.f32', record['cpu_byte_sha256'])
        # The arrival stream is BF16: it is not the original FP32 post-RoPE K teacher.
        source_k = torch.from_numpy(replay.bf16(kb[:t].copy()).transpose(1, 0, 2).copy()).repeat_interleave(2, 0)
        source_v = torch.from_numpy(replay.bf16(vb[:t].copy()).transpose(1, 0, 2).copy()).repeat_interleave(2, 0)
        quant_k, quant_v = [], []
        for h, expected in enumerate(record['state_sha256']):
            state = pinned(SNAP / f'{tag}-kv{h}.bin', expected)
            before = original['groups'][f'kv{h}']['prefixes'][t-1]['before_query_flush']
            assert digest(state) == before['sha256'] and len(state) == before['bytes'] == record['state_bytes'][h]
            assert [p for p, _ in events[h]['K'][:record['nchunk']]] == list(range(32, t, 32))
            assert [p for p, _ in events[h]['V'][:record['nv']]] == list(range(33, t+1))[:record['nv']]
            assert state[:record['nchunk']*1536] == b''.join(blob for _, blob in events[h]['K'][:record['nchunk']])
            start = record['nchunk']*1536
            assert state[start:start+record['nv']*48] == b''.join(blob for _, blob in events[h]['V'][:record['nv']])
            k, v = replay.decode(state, record['nchunk'], record['nv'], record['nkr'], record['nvr'])
            assert np.array_equal(k[-record['nkr']:].view('<u4'), replay.bf16(kb[t-record['nkr']:t, h]).view('<u4'))
            assert np.array_equal(v[-record['nvr']:].view('<u4'), replay.bf16(vb[t-record['nvr']:t, h]).view('<u4'))
            quant_k.append(torch.from_numpy(k.copy()))
            quant_v.append(torch.from_numpy(v.copy()))
        quant_k = torch.stack(quant_k).repeat_interleave(2, 0)
        quant_v = torch.stack(quant_v).repeat_interleave(2, 0)
        assert source_k.shape == source_v.shape == quant_k.shape == quant_v.shape == (16, t, 128)
        probs = []
        for k in (source_k, quant_k):
            logits = torch.bmm(q[:, None, :], k.transpose(1, 2)).squeeze(1) / math.sqrt(128)
            probs.append(logits.softmax(-1))
        outputs = []
        for p in probs:
            for v in (source_v, quant_v):
                outputs.append(torch.bmm(p[:, None, :], v).reshape(2048) @ o.T)
        source, value_only, key_only, both = outputs
        cpu_abs = float((both - conventional).abs().max())
        assert cpu_abs <= 1e-5, (tag, cpu_abs)
        max_cpu_abs = max(max_cpu_abs, cpu_abs)
        effects = torch.stack((source-teacher, key_only-source, value_only-source,
                               both-key_only-value_only+source))
        closure = float(((effects.sum(0)) - (both-teacher)).abs().max())
        assert closure < 1e-5, (tag, closure)
        max_closure = max(max_closure, closure)
        e = effects.numpy().astype(np.float64)
        gram = e @ e.T
        ref = float(np.dot(teacher.numpy().astype(np.float64), teacher.numpy().astype(np.float64)))
        total += gram
        total_ref += ref
        inputs = {f'{tag}-{suffix}': digest((SNAP/f'{tag}-{suffix}').read_bytes()) for suffix in ('q.f32', 'teacher.f32', 'conventional-cpu.f32', 'byte-cpu.f32')}
        receipts.append({'tag': tag, 'original_teacher_sq': ref, 'effect_gram': gram.tolist(),
                         'relative_gram': (gram/ref).tolist(), 'closure_max_abs': closure,
                         'packed_cpu_max_abs': cpu_abs, 'both_minus_teacher_sq': float(np.dot((both-teacher).numpy().astype(np.float64), (both-teacher).numpy().astype(np.float64))),
                         'output_sha256': dict(zip(('rounded_source', 'value_only', 'key_only', 'both'),
                                                    (digest(x.numpy().tobytes()) for x in outputs))),
                         'input_sha256': inputs,
                         'arrival_sha256': audit['events_sha256'],
                         'arrival_manifest_sha256': audit_manifest_sha,
                         'original_manifest_sha256': audit['baseline_manifest_sha256'],
                         'original_event_sha256': record['owner_event_sha256'],
                         'state_sha256': record['state_sha256']})
    assert len(receipts) == 8
    result = {'arithmetic': 'torch CPU float32 bmm, softmax, bmm, BF16 O decoded to float32, then matmul; gram accumulated float64',
              'effect_order': ['source_rounding', 'key_quantization', 'value_quantization', 'interaction'],
              'snapshot_manifest_sha256': digest(manifest_bytes),
              'original_o_sha256': manifest['original_o_sha256'],
              'source_fixture_sha256': manifest['fixture_sha256'],
              'states': receipts, 'teacher_sq_total': total_ref,
              'effect_gram_total': total.tolist(), 'relative_gram_total': (total/total_ref).tolist(),
              'both_relative_sq_from_gram': float(total.sum()/total_ref),
              'max_closure_abs': max_closure, 'max_packed_cpu_abs': max_cpu_abs}
    (HERE/'results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'states': len(receipts), 'relative_gram': result['relative_gram_total'],
                      'both_relative_sq': result['both_relative_sq_from_gram'],
                      'max_packed_cpu_abs': max_cpu_abs, 'max_closure_abs': max_closure}))


if __name__ == '__main__':
    run()
