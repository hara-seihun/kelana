"""Seconds-long CPU contract for the tied paid-scale decoder."""

import torch

from quantize import quantize
from tune import PackedEmbedding, PackedLinear, PaidScaleImage


def test_tied_image():
    torch.set_num_threads(2)
    torch.manual_seed(11)
    image = quantize(torch.randn(24, 128), rotation_block=128)
    provider = PaidScaleImage(image)
    embedding = PackedEmbedding(provider, None)
    head = PackedLinear(provider)
    ids = torch.tensor([[2, 3, 2, 7]])
    assert torch.allclose(provider.decode(), image.decode(), atol=1e-6)
    assert torch.allclose(provider.decode(ids), image.decode()[ids], atol=1e-6)
    result = head(embedding(ids))
    assert result.shape == (1, 4, 24)
    loss = result.float().square().mean()
    loss.backward()
    assert provider.log_scales.grad is not None
    assert torch.isfinite(provider.log_scales.grad).all()
    assert provider.log_scales.grad[2].abs().sum() > 0
    assert provider.log_scales.grad[10].abs().sum() > 0
    assert torch.equal(provider.image().codes, image.codes)
    assert provider.image().scales.dtype == torch.float16


if __name__ == "__main__":
    test_tied_image()
    print("tied paid-scale decoder CPU contract passes")
