#!/usr/bin/env python3
"""Join split captures into matched weight/train/validation projection fixtures."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
DEST = ROOT / 'size-transfer'
MODULES = ('model.layers.0.self_attn.q_proj',
           'model.layers.27.self_attn.q_proj',
           'model.layers.14.mlp.down_proj')


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1 << 22), b''):
            digest.update(block)
    return digest.hexdigest()


def main():
    captures = {split: json.loads((DEST / f'capture-{split}.json').read_text())
                for split in ('train', 'validation', 'test')}
    if len({r['model_revision'] for r in captures.values()}) != 1:
        raise ValueError('capture revisions differ')
    if len({r['token_sha256'] for r in captures.values()}) != 1:
        raise ValueError('capture tokens differ')
    fixtures = DEST / 'fixtures'
    fixtures.mkdir(parents=True, exist_ok=True)
    files = {}
    for name in MODULES:
        train = captures['train']['files'][name]
        validation = captures['validation']['files'][name]
        parts = name.split('.')
        image = fixtures / f'layer{int(parts[2]):02d}-{parts[3]}_{parts[4]}.npz'
        np.savez(image, weight=np.load(train['weight_path']),
                 train=np.load(train['input_path']), validation=np.load(validation['input_path']))
        files[image.name] = {'sha256': sha(image), 'module': name,
                             'weight_sha256': train['weight_sha256'],
                             'train_sha256': train['input_sha256'],
                             'validation_sha256': validation['input_sha256']}
    prior = json.loads((ROOT / 'fixtures/qwen3-0.6b-wikitext/manifest.json').read_text())
    manifest = {'model_revision': captures['train']['model_revision'],
                'tokenizer_sha256': captures['train']['tokenizer_sha256'],
                'token_source': captures['train']['token_file'],
                'token_sha256': captures['train']['token_sha256'],
                'window_starts': prior['window_starts'], 'length': prior['length'],
                'reference_nll': {split: captures[split]['reference'] for split in captures},
                'unique_parameters': captures['train']['unique_parameters'],
                'serialized_tensor_elements_including_tied_alias':
                    captures['train']['serialized_tensor_elements_including_tied_alias'],
                'files': files}
    (fixtures / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'fixtures': str(fixtures), 'files': files,
                      'unique_parameters': manifest['unique_parameters']}))


if __name__ == '__main__':
    main()
