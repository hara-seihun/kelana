#!/usr/bin/env python3
"""Three-level packing, paid accounting and diagonal-Hessian contracts."""
import tempfile
import unittest
from pathlib import Path

import numpy as np
import torch

from three_level import POWERS, _initial_grid, _strict_scale, decode, quantize, save
import calibrated


class ThreeLevelTest(unittest.TestCase):
    def test_packed_roundtrip_and_group_origins(self):
        torch.set_num_threads(2)
        g = torch.Generator().manual_seed(23)
        weight = torch.randn(3, 256, generator=g) * .08
        weight[:, 128:] += .4
        image = quantize(weight, row_chunk=2)
        self.assertEqual(image['codes'].shape, (3, 52))
        self.assertTrue(np.all(image['codes'] <= 242))
        with tempfile.TemporaryDirectory() as folder:
            receipt = save('sample.weight', image, Path(folder))
            actual = decode(receipt['path'])
            digits = ((image['codes'][:, :, None].astype(np.int16) // POWERS) % 3).reshape(3, -1)[:, :256]
            expected = (torch.from_numpy(digits).float().reshape(3, 2, 128) *
                        torch.from_numpy(image['scales']).float().unsqueeze(-1) +
                        torch.from_numpy(image['origins']).float().unsqueeze(-1)).reshape(3, 256)
            torch.testing.assert_close(actual, expected, rtol=0, atol=0)
            self.assertEqual(receipt['payload_bytes'], 3 * 52 + 3 * 2 * 4 + 8)
            self.assertGreater(float(image['origins'][:, 1].mean()),
                               float(image['origins'][:, 0].mean()) + .25)

    def test_cross_group_updates_match_dense_sequential_reference(self):
        g = torch.Generator().manual_seed(91)
        weight = torch.randn((4, 256), generator=g)
        latent = torch.randn((512, 128), generator=g)
        inputs = torch.cat((latent, latent + .2 * torch.randn((512, 128), generator=g)), dim=1)
        upper = calibrated._upper_inverse(inputs.T @ inputs / len(inputs), .01)
        for strict in (False, True):
            step, origin = ((_strict_scale(weight), -_strict_scale(weight)) if strict
                            else _initial_grid(weight))
            working = weight.clone()
            reference = torch.empty_like(weight, dtype=torch.uint8)
            for col in range(256):
                scale, shift = step[:, col // 128], origin[:, col // 128]
                digit = ((working[:, col] - shift) / scale).round().clamp(0, 2).to(torch.uint8)
                reference[:, col] = digit
                error = (working[:, col] - digit.float() * scale - shift) / upper[col, col]
                working[:, col + 1:] -= error[:, None] * upper[col, col + 1:]
            raw = np.pad(reference.numpy(), ((0, 0), (0, 4))).reshape(4, 52, 5)
            expected = (raw * POWERS).sum(-1).astype(np.uint8)
            actual = quantize(weight, upper=upper, row_chunk=4, strict=strict)['codes']
            np.testing.assert_array_equal(actual, expected)

    def test_strict_implicit_origin_and_paid_scale(self):
        g = torch.Generator().manual_seed(54)
        image = quantize(torch.randn((3, 256), generator=g), row_chunk=2, strict=True)
        self.assertNotIn('origins', image)
        with tempfile.TemporaryDirectory() as folder:
            receipt = save('strict.weight', image, Path(folder))
            self.assertEqual(receipt['payload_bytes'], 3 * 52 + 3 * 2 * 2 + 8)
            self.assertTrue(torch.isfinite(decode(receipt['path'])).all())

    def test_diagonal_hessian_agrees_with_affine_rounding(self):
        g = torch.Generator().manual_seed(42)
        w = torch.randn(4, 256, generator=g)
        upper = calibrated._upper_inverse(torch.eye(256), .01)
        rtn, gptq = quantize(w, row_chunk=2), quantize(w, upper=upper, row_chunk=2)
        for key in ('codes', 'scales', 'origins'):
            np.testing.assert_array_equal(rtn[key], gptq[key])


if __name__ == '__main__':
    unittest.main()
