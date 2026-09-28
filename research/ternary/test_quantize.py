"""Small CPU contracts; run with a Python environment that has PyTorch."""

import torch

from quantize import _hadamard, _rotate, quantize


def test_rotation_and_decode():
    torch.manual_seed(7)
    w = torch.randn(3, 1024)
    x = torch.randn(11, 1024)
    for block in (128, 1024):
        image = quantize(w, rotation_block=block, row_chunk=2)
        original = x @ image.decode().T
        rotated = _rotate(x, image.signs, block)
        packed = image.codes.reshape(3, 8, 128).float() * image.scales.float()[:, :, None]
        assert torch.allclose(original, rotated @ packed.reshape(3, 1024).T, atol=1e-4, rtol=1e-5)
        assert torch.allclose(w, _hadamard(_hadamard(w, block), block), atol=1e-6)
        assert image.codes.min() >= -1 and image.codes.max() <= 1


def test_cross_block_error_propagation():
    torch.manual_seed(99)
    w = torch.randn(8, 256)
    a = torch.randn(320, 128)
    x = torch.cat((a, a + .01 * torch.randn_like(a)), dim=1)
    rtn = quantize(w)
    gptq = quantize(w, method="gptq", X=x, row_chunk=3)
    rtn_error = (x @ (w - rtn.decode()).T).square().mean()
    gptq_error = (x @ (w - gptq.decode()).T).square().mean()
    assert gptq_error < .7 * rtn_error


def test_least_squares_and_gptq():
    torch.manual_seed(3)
    w = torch.randn(4, 128)
    x = torch.randn(320, 128) @ (torch.eye(128) + .1 * torch.ones(128, 128))
    image = quantize(w)
    sorted_abs = w.abs().sort(descending=True).values
    all_objectives = w.square().sum(-1, keepdim=True) - sorted_abs.cumsum(-1).square() / torch.arange(1, 129)
    actual = (w - image.decode()).square().sum(-1)
    assert torch.allclose(actual, all_objectives.min(-1).values, atol=.005)
    gptq = quantize(w, method="gptq", X=x, rotation_block=128, row_chunk=2)
    assert gptq.codes.shape == w.shape and gptq.scales.dtype == torch.float16
    assert torch.isfinite(gptq.decode()).all()
    h = x.T @ x / len(x)
    same = quantize(w, method="gptq", H=h, rotation_block=128, signs=gptq.signs, row_chunk=2)
    assert torch.equal(gptq.codes, same.codes)
    assert torch.equal(gptq.scales, same.scales)


if __name__ == "__main__":
    torch.set_num_threads(2)
    test_rotation_and_decode()
    test_least_squares_and_gptq()
    test_cross_block_error_propagation()
    print("ternary quantizer CPU contracts pass")
