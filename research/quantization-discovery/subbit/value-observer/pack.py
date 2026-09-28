#!/usr/bin/env python3
"""Combine the selected eight GQA groups into one paid packed V/O image."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    args = parser.parse_args()
    folder = ROOT / f'layer{args.layer:02d}-refined'
    path = folder / 'refine.json'
    report = json.loads(path.read_text())
    selected = report['train_selected_family']
    sources = report['families'][selected]['images']
    images = []
    for source in sources:
        image = Path(source['path'])
        if sha(image) != source['sha256']:
            raise ValueError(f'group image changed: {image}')
        with np.load(image) as f:
            images.append({name: f[name].copy() for name in f.files})
    names = ('left_shape', 'left_codes', 'left_scales', 'right_shape', 'right_codes', 'right_scales')
    arrays = {name: np.stack([image[name] for image in images]) for name in names}
    joint = ROOT / f'layer{args.layer:02d}-joint-r{report["families"][selected]["rank"]}.npz'
    np.savez(joint, **arrays)
    paid = sum(array.nbytes for array in arrays.values())
    if paid != report['families'][selected]['payload_bytes_including_descriptors']:
        raise ValueError('combined image differs in paid bytes from group images')
    report['selected_joint_image'] = {'path': str(joint), 'sha256': sha(joint),
                                      'payload_bytes_including_descriptors': paid,
                                      'serialized_bytes': joint.stat().st_size,
                                      'layout': 'eight groups in ascending KV-group order; each left factor rows are first then second query head'}
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'layer': args.layer, 'selected_family': selected,
                      'image': report['selected_joint_image']}))


if __name__ == '__main__':
    main()
