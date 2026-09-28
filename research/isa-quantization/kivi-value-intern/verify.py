"""Independent positional decoder and every-prefix byte-equivalence proof against KIVI2."""
import hashlib
import json
import sys
from pathlib import Path

import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BASE = ROOT / 'kivi-two-bit-causal'
sys.path.insert(0, str(ROOT / 'skvq-global-gqa'))
from source import arrays, FIX_SHA


def sha(data):
    return hashlib.sha256(data).hexdigest()


def decode(blob, t, phase, expected, record):
    assert len(blob) == record['bytes'] and sha(blob) == record['sha256']
    assert int.from_bytes(blob[:2], 'little') == t and blob[2] == phase
    dq, dr = blob[3], blob[4]
    nq = max(0, t-33 if phase == 0 else t-32)
    nr = t-nq
    kc = (t-1)//32 if phase == 0 else t//32
    kr = t-32*kc
    assert nq == len(expected['vq']) and nr == len(expected['vr'])
    cursor = 5
    for h in range(8):
        chunks = [blob[cursor+i*1536:cursor+(i+1)*1536] for i in range(kc)]
        cursor += kc*1536
        recent = [blob[cursor+i*256:cursor+(i+1)*256] for i in range(kr)]
        cursor += kr*256
        assert chunks == expected['kq'][h] and recent == expected['kr'][h]
    key_bytes = cursor-5
    quant_dict = [blob[cursor+i*384:cursor+(i+1)*384] for i in range(dq)]
    cursor += dq*384
    quant_refs = blob[cursor:cursor+nq]
    cursor += nq
    recent_dict = [blob[cursor+i*2048:cursor+(i+1)*2048] for i in range(dr)]
    cursor += dr*2048
    recent_refs = blob[cursor:cursor+nr]
    cursor += nr
    assert cursor == len(blob) and len(quant_refs) == nq and len(recent_refs) == nr
    assert all(len(x) == 384 for x in quant_dict) and all(len(x) == 2048 for x in recent_dict)
    assert all(i < dq for i in quant_refs) and all(i < dr for i in recent_refs)
    assert len(set(quant_dict)) == dq and len(set(recent_dict)) == dr
    assert list(dict.fromkeys(quant_refs)) == list(range(dq))
    assert list(dict.fromkeys(recent_refs)) == list(range(dr))
    for pos, ref in enumerate(quant_refs):
        stored = quant_dict[ref]
        for h in range(8):
            assert stored[h*48:(h+1)*48] == expected['vq'][pos][h]
    for pos, ref in enumerate(recent_refs):
        stored = recent_dict[ref]
        for h in range(8):
            assert stored[h*256:(h+1)*256] == expected['vr'][pos][h]
    assert (record['key_bytes'], record['quant_positions'], record['recent_positions'],
            record['quant_unique'], record['recent_unique'], record['quant_record_bytes'],
            record['recent_record_bytes'], record['quant_reference_bytes'], record['recent_reference_bytes']) == (
            key_bytes, nq, nr, dq, dr, dq*384, dr*2048, nq, nr)
    return {'quant_unique': dq, 'recent_unique': dr, 'quant_positions': nq,
            'recent_positions': nr, 'bytes': len(blob)}


def baseline_check(state, receipt):
    checked = 0
    for h in range(8):
        raw = (b''.join(state['kq'][h]) + b''.join(v[h] for v in state['vq']) +
               b''.join(state['kr'][h]) + b''.join(v[h] for v in state['vr']))
        head = receipt['groups'][f'kv{h}']['prefixes'][state['t']-1][
            'before_query_flush' if state['phase'] == 0 else 'after_query_flush']
        assert len(raw) == head['bytes'] and sha(raw) == head['sha256']
        assert (len(state['kq'][h]), len(state['vq']), len(state['kr'][h]), len(state['vr'])) == (
            head['key_quant_chunks'], head['value_quant_tokens'],
            head['key_recent_tokens'], head['value_recent_tokens'])
        checked += len(state['kq'][h])+len(state['kr'][h])+len(state['vq'])+len(state['vr'])
    return checked


def run(panel, window):
    assert panel in ('train', 'held') and 0 <= window < (8 if panel == 'train' else 4)
    name = f'{panel}-{window}'
    manifest = json.loads((HERE/f'{name}-manifest.json').read_text())
    original_path = BASE/f'{name}-manifest.json'
    original = json.loads(original_path.read_text())
    quality = json.loads((BASE/f'{name}-result.json').read_text())
    assert quality['source_fixture_sha256'] == FIX_SHA
    assert quality['peak_cache_bytes'] == original['peak_full_layer_bytes']
    assert quality['final_cache_bytes'] == original['final_full_layer_bytes']
    assert quality['head_events_sha256'] == [original['groups'][f'kv{h}']['events_sha256'] for h in range(8)]
    assert quality['head_image_sha256'] == [original['groups'][f'kv{h}']['final_sha256'] for h in range(8)]
    assert manifest['source_fixture_sha256'] == FIX_SHA == original['fixture_sha256']
    assert manifest['baseline_manifest_sha256'] == sha(original_path.read_bytes())
    stream = (HERE/f'{name}-events.bin').read_bytes()
    final = (HERE/f'{name}-final.bin').read_bytes()
    assert sha(stream) == manifest['events_sha256'] and len(stream) == manifest['events_bytes']
    assert sha(final) == manifest['final_sha256'] and len(final) == manifest['final_bytes']
    logs = [(BASE/f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    assert [sha(s) for s in logs] == manifest['baseline_events_sha256']
    source = arrays(panel, window)
    keys = source['krot'].permute(1, 0, 2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
    values = source['value'].reshape(256, 8, 128)
    state = {'kq': [[] for _ in range(8)], 'kr': [[] for _ in range(8)], 'vq': [], 'vr': [],
             't': 0, 'phase': 1}
    offsets = [0]*8
    cursor = 0
    peak, comparison_count, max_unique_q, max_unique_r, checked_records = 0, 0, 0, 0, 0
    for t in range(1, 257):
        assert int.from_bytes(stream[cursor:cursor+2], 'little') == t
        arrived_k = stream[cursor+2:cursor+2050]
        arrived_v = stream[cursor+2050:cursor+4098]
        cursor += 4098
        assert len(arrived_k) == len(arrived_v) == 2048
        assert arrived_k == keys[t-1].astype('<u2').tobytes()
        assert arrived_v == values[t-1].astype('<u2').tobytes()
        for h in range(8):
            state['kr'][h].append(arrived_k[h*256:(h+1)*256])
        state['vr'].append(tuple(arrived_v[h*256:(h+1)*256] for h in range(8)))
        state['t'], state['phase'] = t, 0
        before = manifest['prefixes'][t-1]['before']
        checked_records += baseline_check(state, original)
        blob = construct_from_independent_state(state)
        check = decode(blob, t, 0, state, before)
        peak = max(peak, check['bytes'])
        max_unique_q = max(max_unique_q, check['quant_unique'])
        max_unique_r = max(max_unique_r, check['recent_unique'])
        comparison_count += before['quant_comparisons']+before['recent_comparisons']
        for h in range(8):
            def event(tag, length):
                at = offsets[h]
                assert logs[h][at:at+1] == tag and int.from_bytes(logs[h][at+1:at+3], 'little') == t
                payload = logs[h][at+3:at+3+length]
                assert len(payload) == length
                offsets[h] = at+3+length
                return payload
            if len(state['kr'][h]) == 32:
                state['kq'][h].append(event(b'K', 1536))
                state['kr'][h].clear()
            if len(state['vr']) > 32:
                if h == 0:
                    flushed = []
                flushed.append(event(b'V', 48))
        if len(state['vr']) > 32:
            state['vq'].append(tuple(flushed))
            state['vr'].pop(0)
        state['phase'] = 1
        after = manifest['prefixes'][t-1]['after']
        checked_records += baseline_check(state, original)
        blob = construct_from_independent_state(state)
        check = decode(blob, t, 1, state, after)
        peak = max(peak, check['bytes'])
        max_unique_q = max(max_unique_q, check['quant_unique'])
        max_unique_r = max(max_unique_r, check['recent_unique'])
        comparison_count += after['quant_comparisons']+after['recent_comparisons']
    assert cursor == len(stream) and all(offsets[h] == len(logs[h]) for h in range(8))
    assert blob == final and peak == manifest['peak_bytes']
    for h in range(8):
        baseline_final = (BASE/f'{name}-head{h}-final.bin').read_bytes()
        assert baseline_final == (b''.join(state['kq'][h]) + b''.join(v[h] for v in state['vq']) +
                                  b''.join(state['kr'][h]) + b''.join(v[h] for v in state['vr']))
    result = {'panel': panel, 'window': window, 'peak_bytes': peak, 'final_bytes': len(final),
              'baseline_peak_bytes': original['peak_full_layer_bytes'],
              'baseline_final_bytes': original['final_full_layer_bytes'],
              'peak_saved_bytes': original['peak_full_layer_bytes']-peak,
              'final_saved_bytes': original['final_full_layer_bytes']-len(final),
              'max_quant_unique': max_unique_q, 'max_recent_unique': max_unique_r,
              'dictionary_record_comparisons': comparison_count,
              'prefixes_verified': 512, 'original_record_checks': checked_records,
              'full_o_quality_receipt': f'../kivi-two-bit-causal/{name}-result.json',
              'full_o_sse': quality['full_o_sse'], 'full_o_ref_sq': quality['full_o_ref_sq'],
              'final_sha256': sha(final), 'events_sha256': sha(stream)}
    (HERE/f'{name}-result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result))


def construct_from_independent_state(state):
    """Reference first-seen serializer, separate from the paid encoder implementation."""
    payload = bytearray()
    payload.extend(state['t'].to_bytes(2, 'little'))
    payload.append(state['phase'])
    payload.extend(b'\x00\x00')
    for h in range(8):
        for part in state['kq'][h]:
            payload.extend(part)
        for part in state['kr'][h]:
            payload.extend(part)
    for offset, records in ((3, state['vq']), (4, state['vr'])):
        unique = []
        refs = []
        for fields in records:
            item = b''.join(fields)
            if item not in unique:
                unique.append(item)
            refs.append(unique.index(item))
        payload[offset] = len(unique)
        for item in unique:
            payload.extend(item)
        payload.extend(refs)
    return bytes(payload)


if __name__ == '__main__':
    run(sys.argv[1], int(sys.argv[2]))
