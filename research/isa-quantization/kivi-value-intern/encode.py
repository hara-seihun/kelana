"""Pinned exact full-eight-head V-record interner over immutable KIVI2 events."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / 'skvq-global-gqa'))
from source import arrays, FIX_SHA

BASE = ROOT / 'kivi-two-bit-causal'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def image(t, phase, kchunks, krecent, vquant, vrecent):
    nq, nr = len(vquant), len(vrecent)
    assert nq <= 224 and nr <= 33 and all(len(x) == 384 for x in vquant)
    assert all(len(x) == 2048 for x in vrecent)
    dictionaries = []
    references = []
    comparisons = []
    for records in (vquant, vrecent):
        entries, indices, probes = [], bytearray(), 0
        for record in records:
            for index, candidate in enumerate(entries):
                probes += 1
                if record == candidate:
                    indices.append(index)
                    break
            else:
                indices.append(len(entries))
                entries.append(record)
        dictionaries.append(entries)
        references.append(bytes(indices))
        comparisons.append(probes)
    qdict, rdict = dictionaries
    header = t.to_bytes(2, 'little') + bytes((phase, len(qdict), len(rdict)))
    keys = b''.join(b''.join(kchunks[h]) + b''.join(krecent[h]) for h in range(8))
    data = header + keys + b''.join(qdict) + references[0] + b''.join(rdict) + references[1]
    ledger = {'bytes': len(data), 'sha256': digest(data), 'key_bytes': len(keys),
              'quant_positions': nq, 'recent_positions': nr, 'quant_unique': len(qdict),
              'recent_unique': len(rdict), 'quant_record_bytes': len(qdict)*384,
              'recent_record_bytes': len(rdict)*2048, 'quant_reference_bytes': nq,
              'recent_reference_bytes': nr, 'quant_comparisons': comparisons[0],
              'recent_comparisons': comparisons[1]}
    assert len(data) == 5 + len(keys) + len(qdict)*384 + nq + len(rdict)*2048 + nr
    return data, ledger


def run(panel, window):
    assert panel in ('train', 'held') and 0 <= window < (8 if panel == 'train' else 4)
    src = arrays(panel, window)
    keys = src['krot'].permute(1, 0, 2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
    values = src['value'].reshape(256, 8, 128)
    baseline = json.loads((BASE / f'{panel}-{window}-manifest.json').read_text())
    assert baseline['fixture_sha256'] == FIX_SHA
    streams = [(BASE / f'{panel}-{window}-head{h}-events.bin').read_bytes() for h in range(8)]
    kchunks, krecent = [[] for _ in range(8)], [[] for _ in range(8)]
    vquant, vrecent = [], []
    offsets = [0]*8
    receipts, events = [], bytearray()
    peak = 0
    for t in range(1, 257):
        kb = keys[t-1].astype('<u2').tobytes()
        vb = values[t-1].astype('<u2').tobytes()
        assert len(kb) == len(vb) == 2048
        for h in range(8):
            krecent[h].append(kb[h*256:(h+1)*256])
        vrecent.append(vb)
        events += t.to_bytes(2, 'little') + kb + vb
        before, before_ledger = image(t, 0, kchunks, krecent, vquant, vrecent)
        peak = max(peak, len(before))
        quant_tokens = [None]*8
        for h in range(8):
            def consume(tag, size):
                at = offsets[h]
                assert streams[h][at:at+1] == tag and int.from_bytes(streams[h][at+1:at+3], 'little') == t
                payload = streams[h][at+3:at+3+size]
                assert len(payload) == size
                offsets[h] = at+3+size
                return payload
            if len(krecent[h]) == 32:
                kchunks[h].append(consume(b'K', 1536))
                krecent[h].clear()
            if len(vrecent) > 32:
                quant_tokens[h] = consume(b'V', 48)
        if len(vrecent) > 32:
            vquant.append(b''.join(quant_tokens))
            vrecent.pop(0)
        after, after_ledger = image(t, 1, kchunks, krecent, vquant, vrecent)
        receipts.append({'t': t, 'before': before_ledger, 'after': after_ledger})
        assert offsets and all(before_ledger['quant_positions'] == baseline['groups'][f'kv{h}']['prefixes'][t-1]['before_query_flush']['value_quant_tokens'] for h in range(8))
    assert all(offsets[h] == len(streams[h]) for h in range(8))
    assert all(digest(streams[h]) == baseline['groups'][f'kv{h}']['events_sha256'] for h in range(8))
    path = f'{panel}-{window}'
    (HERE / f'{path}-events.bin').write_bytes(events)
    (HERE / f'{path}-final.bin').write_bytes(after)
    result = {'panel': panel, 'window': window, 'source_fixture_sha256': FIX_SHA,
              'baseline_manifest_sha256': digest((BASE / f'{path}-manifest.json').read_bytes()),
              'baseline_events_sha256': [digest(s) for s in streams],
              'events_sha256': digest(events), 'events_bytes': len(events),
              'final_sha256': digest(after), 'peak_bytes': peak, 'final_bytes': len(after),
              'prefixes': receipts}
    (HERE / f'{path}-manifest.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print(json.dumps({'window': path, 'peak': peak, 'final': len(after),
                      'quant_unique': after_ledger['quant_unique'], 'recent_unique': after_ledger['recent_unique']}))


if __name__ == '__main__':
    run(sys.argv[1], int(sys.argv[2]))
