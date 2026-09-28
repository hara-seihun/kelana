"""Assemble and replay a source-token admission witness from immutable KIVI2 events."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
TOKENS = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')
PRODUCER = ROOT / 'quip-token-producer' / 'producer-results.json'
COUNT = 149


def sha(data):
    return hashlib.sha256(data).hexdigest()


def donors():
    producer = json.loads(PRODUCER.read_text())
    assert producer['source']['tokens_sha256'] == sha(TOKENS.read_bytes())
    assert producer['train']['bitwise_unequal_float32_values'] == 0
    assert producer['validation']['bitwise_unequal_float32_values'] == 0
    source = {'tokens_sha256': sha(TOKENS.read_bytes()),
              'producer_receipt_sha256': sha(PRODUCER.read_bytes()), 'windows': {}}
    seen = {}
    with np.load(TOKENS) as tokens:
        for panel, total in (('train', 8), ('held', 4)):
            for window in range(total):
                name = f'{panel}-{window}'
                ids = tokens['train' if panel == 'train' else 'validation'][window]
                assert len(ids) == 256
                arrival_path = ROOT / 'kivi-value-intern' / f'{name}-events.bin'
                arrival = arrival_path.read_bytes()
                receipt = json.loads((ROOT / 'kivi-value-intern' / f'{name}-manifest.json').read_text())
                assert len(arrival) == 256 * 4098 and sha(arrival) == receipt['events_sha256']
                log_hashes = []
                events = []
                for head in range(8):
                    log = (ROOT / 'kivi-two-bit-causal' / f'{name}-head{head}-events.bin').read_bytes()
                    baseline = json.loads((ROOT / 'kivi-two-bit-causal' / f'{name}-manifest.json').read_text())
                    assert sha(log) == receipt['baseline_events_sha256'][head]
                    assert sha(log) == baseline['groups'][f'kv{head}']['events_sha256']
                    log_hashes.append(sha(log))
                    at = 0
                    by_time = {}
                    while at < len(log):
                        kind = log[at:at+1]
                        time = int.from_bytes(log[at+1:at+3], 'little')
                        assert kind in (b'K', b'V')
                        size = 1536 if kind == b'K' else 48
                        assert len(log[at+3:at+3+size]) == size
                        if kind == b'V':
                            assert time >= 33 and time not in by_time
                            by_time[time] = (at, log[at+3:at+51])
                        at += 3 + size
                    assert at == len(log) and set(by_time) == set(range(33, 257))
                    events.append(by_time)
                source['windows'][name] = {'arrival_sha256': sha(arrival), 'head_events_sha256': log_hashes}
                for pos, token in enumerate(ids):
                    packet = arrival[pos*4098:(pos+1)*4098]
                    assert int.from_bytes(packet[:2], 'little') == pos+1
                    bf16 = packet[2050:4098]
                    assert len(bf16) == 2048
                    if pos >= 224:
                        continue
                    slices = [events[h][pos+33] for h in range(8)]
                    packed = b''.join(chunk for _, chunk in slices)
                    assert len(packed) == 384
                    token = int(token)
                    entry = {'token_id': token, 'donor': name, 'source_position': pos+1,
                             'flush_time': pos+33, 'head_event_offsets': [at for at, _ in slices],
                             'bf16_sha256': sha(bf16), 'quant_sha256': sha(packed)}
                    if token in seen:
                        old_entry, old_bf16, old_packed = seen[token]
                        assert old_bf16 == bf16 and old_packed == packed, (old_entry, entry)
                    else:
                        seen[token] = (entry, bf16, packed)
    return source, seen


def main(mode):
    assert mode in ('build', 'replay')
    source, seen = donors()
    # First eligible occurrence per ID in source-panel order; no quality-based selection.
    selected = []
    unique = set()
    for entry, bf16, packed in seen.values():
        if packed in unique:
            continue
        selected.append((entry, bf16, packed))
        unique.add(packed)
        if len(selected) == COUNT:
            break
    assert len(selected) == COUNT and len({row[0]['token_id'] for row in selected}) == COUNT
    assert len({row[2] for row in selected}) == COUNT
    payload = {'source': source, 'selection': 'first 149 distinct aged whole-eight-head V byte records in train-0..7, held-0..3 position order',
               'distinct_aged_source_ids': len(seen),
               'distinct_aged_source_records': len({row[2] for row in seen.values()}),
               'entries': [entry for entry, _, _ in selected],
               'quant_concatenation_sha256': sha(b''.join(row[2] for row in selected)),
               'bf16_concatenation_sha256': sha(b''.join(row[1] for row in selected))}
    path = HERE / 'witness.json'
    if mode == 'build':
        path.write_text(json.dumps(payload, indent=2) + '\n')
    else:
        assert json.loads(path.read_text()) == payload
    print(json.dumps({'mode': mode, 'distinct_aged_source_ids': len(seen),
                      'distinct_aged_source_records': payload['distinct_aged_source_records'],
                      'witness_count': len(selected), 'manifest_sha256': sha(path.read_bytes())}))


if __name__ == '__main__':
    main(sys.argv[1])
