#!/usr/bin/env python3
"""Checks the packed decoder and full-covariance compensation on a small matrix."""
import tempfile
import unittest
from pathlib import Path

import numpy as np
import torch

from calibrated import _initial_grid, _upper_inverse, decode, quantize, save


class ImageTest(unittest.TestCase):
    def test_paid_nibbles_and_decoder(self):
        generator = torch.Generator().manual_seed(20260923)
        weight = torch.randn((3, 256), generator=generator)
        image = quantize(weight, row_chunk=2)
        with tempfile.TemporaryDirectory() as directory:
            receipt = save('sample.weight', image, Path(directory))
            reconstructed = decode(receipt['path'])
            self.assertEqual(receipt['payload_bytes'], 3 * 256 // 2 + 3 * 2 * 4 + 8)
            unpacked = np.empty((3, 256), dtype=np.uint8)
            unpacked[:, 0::2] = image['codes'] & 15
            unpacked[:, 1::2] = image['codes'] >> 4
            expected = (torch.from_numpy(unpacked).float().reshape(3, 2, 128) *
                        torch.from_numpy(image['scales']).float().unsqueeze(-1) +
                        torch.from_numpy(image['origins']).float().unsqueeze(-1)).reshape(3, 256)
            torch.testing.assert_close(reconstructed, expected, rtol=0, atol=0)
            self.assertEqual(receipt['shape'], [3, 256])

    def test_cross_group_updates_match_dense_sequential_reference(self):
        generator = torch.Generator().manual_seed(91)
        weight = torch.randn((4, 256), generator=generator)
        latent = torch.randn((512, 128), generator=generator)
        inputs = torch.cat((latent, latent + .2 * torch.randn((512, 128), generator=generator)), dim=1)
        upper = _upper_inverse(inputs.T @ inputs / len(inputs), .01)
        step, origin = _initial_grid(weight)
        working = weight.clone()
        reference = torch.empty_like(weight, dtype=torch.uint8)
        for col in range(256):
            scale, shift = step[:, col // 128], origin[:, col // 128]
            digit = ((working[:, col] - shift) / scale).round().clamp(0, 15).to(torch.uint8)
            reference[:, col] = digit
            error = (working[:, col] - digit.float() * scale - shift) / upper[col, col]
            working[:, col + 1:] -= error[:, None] * upper[col, col + 1:]
        actual = quantize(weight, upper=upper, row_chunk=4)['codes']
        packed = reference[:, 0::2].numpy() | (reference[:, 1::2].numpy() << 4)
        np.testing.assert_array_equal(actual, packed)

    def test_diagonal_metric_does_not_change_rtn_codes(self):
        generator = torch.Generator().manual_seed(8)
        weight = torch.randn((4, 256), generator=generator)
        diagonal = torch.diag(torch.linspace(.7, 1.3, 256))
        upper = _upper_inverse(diagonal, .01)
        rtn = quantize(weight, row_chunk=2)
        compensated = quantize(weight, upper=upper, row_chunk=2)
        for key in ('codes', 'scales', 'origins'):
            np.testing.assert_array_equal(rtn[key], compensated[key])


if __name__ == '__main__':
    unittest.main()
