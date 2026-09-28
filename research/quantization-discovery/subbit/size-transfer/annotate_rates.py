#!/usr/bin/env python3
"""Reconcile paid binary dimension descriptors in retained fit and continuation receipts."""
import json
from pathlib import Path

ROOT = Path('/path/to/workspace/data/kelana-subbit/size-transfer')


def main():
    for image in (ROOT / 'factors').glob('*-binary.json'):
        row = json.loads(image.read_text())
        n, k = row['dimensions']
        row['dimension_descriptor_bytes'] = 12
        row['matrix_image_bpw_including_descriptor'] = 8 * (row['matrix_payload_bytes'] + 12) / (n * k)
        image.write_text(json.dumps(row, indent=2) + '\n')
    for image in ROOT.glob('continuation-*.json'):
        row = json.loads(image.read_text())
        n, k = row['matrix_dimensions']
        binary = row['images']['binary']
        binary['dimension_descriptor_bytes'] = 12
        binary['full_model_bits_per_unique_parameter'] = (
            16 * (row['unique_parameters'] - n * k) +
            8 * (binary['matrix_payload_bytes'] + 12)) / row['unique_parameters']
        image.write_text(json.dumps(row, indent=2) + '\n')


if __name__ == '__main__':
    main()
