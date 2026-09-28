#!/usr/bin/env python3
"""Retain compact paid-rate and causal-consumer receipts in source custody."""
import hashlib
import json
from pathlib import Path

DATA = Path('/path/to/workspace/data/kelana-subbit/value-observer')
SOURCE = Path(__file__).resolve().parent


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    layers = []
    for layer in (0, 14):
        prefix = f'layer{layer:02d}'
        fit_path = DATA / f'{prefix}-direct/fit.json'
        refine_path = DATA / f'{prefix}-refined/refine.json'
        consumer_path = DATA / f'{prefix}-joint-consumer.json'
        direct_path = DATA / f'{prefix}-direct-consumer.json'
        fit = json.loads(fit_path.read_text())
        refinement = json.loads(refine_path.read_text())
        consumer = json.loads(consumer_path.read_text())
        direct = json.loads(direct_path.read_text())
        selected = refinement['train_selected_family']
        joint = refinement['selected_joint_image']
        if sha(Path(joint['path'])) != joint['sha256']:
            raise ValueError(f'joint image changed: {joint["path"]}')
        groups = fit['families'][selected]['groups']
        layers.append({'layer': layer, 'selected_family': selected,
                       'rank': refinement['families'][selected]['rank'],
                       'input_output_bits': [refinement['families'][selected]['bits']]*2,
                       'original_V_plus_O_elements': 1024*1024 + 1024*2048,
                       'independent_binary_payload_bytes_including_descriptors': 210968,
                       'joint_image': joint,
                       'joint_bpw': 8*joint['payload_bytes_including_descriptors']/(1024*1024+1024*2048),
                       'source_capture_sha256': consumer['capture_sha256'],
                       'independent_images': consumer['independent_images'],
                       'pre_refit_composed_response_by_group':
                           [{'group': row['group'], 'rank_tail_train': row['conditional_best_rank_train_error'],
                             'train': row['train_composed_response_error'],
                             'validation': row['validation_composed_response_error']}
                            for row in groups],
                       'pre_refit_attention_output_error':
                           {split: direct['splits'][split]['relative_squared_output_error']
                            for split in ('train', 'validation')},
                       'post_refit_attention_output_error':
                           {split: consumer['splits'][split]['relative_squared_output_error']
                            for split in ('train', 'validation')},
                       'attention_input_replay_error':
                           {split: consumer['splits'][split]['original_attention_input_replay_error']
                            for split in ('train', 'validation')},
                       'validation_per_window_error':
                           consumer['splits']['validation']['per_window_relative_squared_error'],
                       'changed_left_codes': refinement['families'][selected]['changed_left_codes'],
                       'full_receipts': {str(p): sha(p) for p in (fit_path, refine_path, consumer_path, direct_path)},
                       'fixed_output_basis_group0':
                           json.loads((DATA / f'{prefix}-r76/group0.json').read_text())['full_rank_fixed_output_basis_error']})
    report = {'programme': 'Qwen3-0.6B shared GQA value/output observer',
              'model_revision': 'c1899de289a04d12100db370d81485cdf75e47ca',
              'objective': 'original-Q/K/RoPE causal post-O output squared relative error on original BF16 producer windows',
              'source_sha256': {name: sha(SOURCE / name) for name in
                                ('fit_direct.py', 'refine.py', 'measure.py', 'pack.py')},
              'layers': layers}
    output = SOURCE / 'results.json'
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(output)


if __name__ == '__main__':
    main()
