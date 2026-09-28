#!/usr/bin/env python3
"""Reconcile all packed scalar images with the BF16 checkpoint's unique parameter ledger."""
import argparse
import json
import math
import sys
from pathlib import Path

from safetensors import safe_open

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fit import MODEL, MATRICES, sha


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/full-scalar'))
    args = p.parse_args()
    receipts = sorted((args.data/'receipts').glob('*.json'))
    if len(receipts) != 5:
        raise ValueError(f'expected four body ranges and embedding receipt, got {receipts}')
    entries = [entry for path in receipts for entry in json.loads(path.read_text())['entries']]
    with safe_open(MODEL/'model.safetensors', framework='pt', device='cpu') as store:
        keys = set(store.keys()) - {'lm_head.weight'}
        matrix = {f'model.layers.{layer}.{field}.weight' for layer in range(28) for field in MATRICES}
        matrix.add('model.embed_tokens.weight')
        assert matrix <= keys
        bf16 = keys - matrix
        assert all(len(store.get_slice(name).get_shape()) == 1 for name in bf16), bf16
        unique = sum(math.prod(store.get_slice(name).get_shape()) for name in keys)
        body = sum(math.prod(store.get_slice(name).get_shape()) for name in matrix - {'model.embed_tokens.weight'})
        embedding = math.prod(store.get_slice('model.embed_tokens.weight').get_shape())
        norm = unique-body-embedding
    result = {'model_revision': json.loads((MODEL/'source.json').read_text())['revision'],
              'model_sha256': sha(MODEL/'model.safetensors'),
              'token_fixture_sha256': sha(Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')),
              'quantizer_sha256': sha(Path(__file__).resolve().parents[1]/'spectral_quant.py'),
              'receipts': [{str(path): sha(path)} for path in receipts],
              'unique_parameters': unique, 'body_parameters': body,
              'tied_embedding_parameters': embedding, 'bf16_norm_parameters': norm,
              'bf16_norm_names': sorted(bf16), 'arms': {}, 'entries': entries}
    for bits in (2, 4):
        chosen = [r for r in entries if r['bits'] == bits]
        assert len(chosen) == 197 and {r['name'] for r in chosen} == matrix
        for item in chosen:
            if sha(Path(item['image'])) != item['sha256']:
                raise ValueError(f"changed image {item['image']}")
        payload = sum(r['payload_bytes'] for r in chosen)
        container = sum(r['container_bytes'] for r in chosen)
        arm = {'matrix_count': len(chosen), 'body_count': 196,
               'matrix_parameters': body+embedding, 'packed_payload_bytes': payload,
               'packed_container_bytes': container, 'bf16_norm_bytes': 2*norm,
               'paid_payload_bytes': payload+2*norm,
               'paid_container_bytes': container+2*norm,
               'matrix_bpw': 8*payload/(body+embedding),
               'whole_unique_bpw': 8*(payload+2*norm)/unique}
        result['arms'][str(bits)] = arm
        print(bits, json.dumps(arm), flush=True)
    (args.data/'accounting.json').write_text(json.dumps(result, indent=2)+'\n')


if __name__ == '__main__':
    main()
