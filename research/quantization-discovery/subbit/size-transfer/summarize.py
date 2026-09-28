#!/usr/bin/env python3
"""Commit compact 1.7B receipts while retaining full images and per-window evidence in data."""
import hashlib
import json
from pathlib import Path

SOURCE = Path('/path/to/workspace/data/kelana-subbit/size-transfer')
TARGET = Path(__file__).with_name('results.json')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 22), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    manifest = json.loads((SOURCE / 'fixtures/manifest.json').read_text())
    model = json.loads((SOURCE.parent / 'models/qwen3-1.7b/source.json').read_text())
    capture = {name: json.loads((SOURCE / f'capture-{name}.json').read_text())
               for name in ('train', 'validation', 'test')}
    entries = []
    for name, fixture in manifest['files'].items():
        stem = name.removesuffix('.npz')
        binary = json.loads((SOURCE / 'factors' / f'{stem}-binary.json').read_text())
        spectral = json.loads((SOURCE / 'factors' / f'{stem}-spectral.json').read_text())
        continuation_path = SOURCE / f'continuation-{stem}.json'
        continuation = json.loads(continuation_path.read_text())
        qnorm_path = SOURCE / 'factors' / f'{stem}-qnorm.json'
        selected = next(e for e in spectral['entries'] if e['image'] == spectral['selected_image'])
        entries.append({'fixture': name, 'fixture_sha256': fixture['sha256'],
                        'module': fixture['module'], 'dimensions': binary['dimensions'],
                        'binary': {key: binary[key] for key in ('rank', 'matrix_payload_bpw',
                                    'dimension_descriptor_bytes', 'matrix_image_bpw_including_descriptor',
                                    'admm_train_response_error', 'admm_heldout_response_error',
                                    'refined_train_response_error', 'refined_heldout_response_error',
                                    'solver_seconds_cpu', 'online_per_vector', 'image', 'image_sha256')},
                        'spectral': {key: selected[key] for key in ('left_bits', 'right_bits',
                                     'rank', 'payload_bpw', 'train_response_error',
                                     'heldout_response_error', 'online_per_vector', 'image', 'image_sha256')},
                        'q_norm_consumer': json.loads(qnorm_path.read_text())['arms'] if qnorm_path.exists() else None,
                        'continuation': {split: continuation['splits'][split]['candidates']
                                         for split in ('validation', 'test')},
                        'continuation_receipt': str(continuation_path),
                        'continuation_sha256': sha(continuation_path)})
    report = {'model': model['repository'], 'revision': model['revision'],
              'model_source_sha256': sha(SOURCE.parent / 'models/qwen3-1.7b/source.json'),
              'source_weight_bytes': sum(value['bytes'] for key, value in model['files'].items()
                                         if key.endswith('.safetensors')),
              'unique_parameters': manifest['unique_parameters'],
              'serialized_tensor_elements_including_tied_alias':
                  manifest['serialized_tensor_elements_including_tied_alias'],
              'token_sha256': manifest['token_sha256'], 'window_starts': manifest['window_starts'],
              'tokenizer_sha256': manifest['tokenizer_sha256'],
              'reference': {split: capture[split]['reference'] for split in capture},
              'fixtures_manifest': str(SOURCE / 'fixtures/manifest.json'),
              'fixtures_manifest_sha256': sha(SOURCE / 'fixtures/manifest.json'),
              'entries': entries}
    TARGET.write_text(json.dumps(report, indent=2) + '\n')
    print(TARGET)


if __name__ == '__main__':
    main()
