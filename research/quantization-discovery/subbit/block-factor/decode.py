#!/usr/bin/env python3
"""Consume a stored block-factor image without reconstructing its dense weight matrix."""
import argparse
from pathlib import Path

import numpy as np
import torch


def load_image(path):
    with np.load(path) as image:
        n, k, rank = (int(v) for v in image['dimensions'][:3])
        u_bits = np.unpackbits(image['U'], axis=1, bitorder='little')[:, :rank].copy()
        u = torch.from_numpy(u_bits.astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(image['pre'].copy()).float()
        post = torch.from_numpy(image['post'].copy()).float()
        dictionary = np.unpackbits(image['dictionary'][:, :, None], axis=2, bitorder='little').astype(np.float32) * 2 - 1
        groups = k // 8
        if 'group_mask' in image:
            mask = np.unpackbits(image['group_mask'], bitorder='little')[:groups].astype(bool)
            compressed = int(mask.sum())
            bits = np.unpackbits(image['labels'], axis=1, bitorder='little')[:, :rank * 4].reshape(compressed, rank, 4)
            labels = (bits * np.array([1, 2, 4, 8])).sum(2)
            full = np.unpackbits(image['full_patterns'][:, :, None], axis=2, bitorder='little').astype(np.float32) * 2 - 1
            patterns = np.empty((rank, groups, 8), dtype=np.float32)
            patterns[:, ~mask] = full
            patterns[:, mask] = dictionary[np.arange(compressed)[:, None], labels].transpose(1, 0, 2)
        else:
            codes = dictionary.shape[1]
            label_bits = codes.bit_length() - 1
            bits = np.unpackbits(image['labels'], axis=1, bitorder='little')[:, :rank * label_bits].reshape(groups, rank, label_bits)
            labels = (bits * (1 << np.arange(label_bits))).sum(2)
            patterns = dictionary[np.arange(groups)[:, None], labels].transpose(1, 0, 2)
    return u, torch.from_numpy(patterns.reshape(rank, k)), pre, post


def apply(image, inputs):
    u, v, pre, post = image
    return ((inputs * pre) @ v.T @ u.T) * post


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(8)
    with np.load(args.fixture) as data:
        inputs = torch.from_numpy(data['validation'].copy()).float()
        reference = inputs @ torch.from_numpy(data['weight'].copy()).float().T
    estimate = apply(load_image(args.image), inputs)
    print((estimate - reference).square().sum().div(reference.square().sum()).item())


if __name__ == '__main__':
    main()
