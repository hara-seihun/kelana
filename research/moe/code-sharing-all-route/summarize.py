#!/usr/bin/env python3
"""Aggregate independently bounded layer shards of the actual-route code census."""
import hashlib
import json
from pathlib import Path

DATA = Path('/path/to/workspace/data/qwen-moe')
SHARDS = DATA / 'code-sharing-all-route'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    inventory = json.loads((DATA/'traffic.json').read_text())
    cap = json.loads((DATA/'all-producers/receipt.json').read_text())
    layers = {}
    files = {}
    common = None
    for path in sorted(SHARDS.glob('layers-*.json')):
        j = json.loads(path.read_text())
        invariant = tuple(j[k] for k in ('model_sha256', 'header_sha256', 'inventory_sha256',
                                          'capture_receipt_sha256', 'source_sha256'))
        if common is None:
            common = invariant
        assert common == invariant
        assert j['stop'] - j['start'] == len(j['layers'])
        files[path.name] = sha(path)
        for layer in j['layers']:
            assert j['start'] <= layer['layer'] < j['stop'] and layer['layer'] not in layers
            assert len(layer['banks']) == 2
            layers[layer['layer']] = layer
    assert sorted(layers) == list(range(40)), sorted(layers)
    assert common[0] == cap['model_sha256'] and common[1] == inventory['header_sha256']
    assert common[2] == sha(DATA/'traffic.json') and common[3] == sha(DATA/'all-producers/receipt.json')
    result = {'model_sha256': common[0], 'inventory_sha256': common[2],
              'capture_receipt_sha256': common[3], 'measurement_source_sha256': common[4],
              'summary_source_sha256': sha(__file__), 'shard_sha256': files,
              'complete_one_read_bytes_per_token': inventory['one_token_weight_stream_bytes'],
              'splits': {}}
    for split in ('train', 'held'):
        stats = {}
        for n in ('4', '8', '16', 'full'):
            counts = [sum(sum(b['counts'][n][split]) for b in layers[l]['banks']) for l in range(40)]
            total = sum(counts)
            bytes_per_token = total * (144 if n == 'full' else int(n)) / 64
            stats[n] = {'reusable_fragments': total, 'layer_counts': counts,
                        'layer_zero_fraction': counts[0]/total if total else 0,
                        'optimistic_reusable_bytes_per_token': bytes_per_token,
                        'optimistic_fraction_complete_one_read_bytes': bytes_per_token/inventory['one_token_weight_stream_bytes']}
        result['splits'][split] = stats
    (SHARDS/'receipt.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'train': result['splits']['train'], 'held': result['splits']['held']}, indent=2))


if __name__ == '__main__':
    main()
