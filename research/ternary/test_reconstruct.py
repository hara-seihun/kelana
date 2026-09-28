"""Quick composed-block reconstruction contract, with no GPU or model download."""

import torch
from torch import nn

from quantize import quantize
from reconstruct import BlockBatch, PROJECTIONS, reconstruct_block


class Block(nn.Module):
    def __init__(self):
        super().__init__()
        self.self_attn = nn.Module()
        for key in ("q_proj", "k_proj", "v_proj", "o_proj"):
            setattr(self.self_attn, key, nn.Linear(128, 128, bias=False))
        self.mlp = nn.Module()
        for key in ("gate_proj", "up_proj", "down_proj"):
            setattr(self.mlp, key, nn.Linear(128, 128, bias=False))

    def forward(self, hidden_states, gain=1.0):
        a = self.self_attn
        m = self.mlp
        hidden = hidden_states + a.o_proj(
            (a.q_proj(hidden_states) + a.k_proj(hidden_states)).tanh() * a.v_proj(hidden_states))
        return hidden + gain * m.down_proj(torch.nn.functional.silu(m.gate_proj(hidden)) * m.up_proj(hidden))


def test_composed_reconstruction():
    torch.manual_seed(42)
    torch.set_num_threads(2)
    layer = Block()
    images = {name: quantize(dict(layer.named_parameters())[name].detach().clone(), rotation_block=128)
              for name in PROJECTIONS}
    batch = BlockBatch(torch.randn(6, 128), {"gain": 0.7})
    original = {key: value.detach().clone() for key, value in layer.state_dict().items()}
    result = reconstruct_block(layer, images, [batch], steps=4, evaluate_every=2)
    assert result.best_loss <= result.initial_loss
    assert set(result.images) == set(PROJECTIONS)
    assert all(image.codes.dtype == torch.int8 and image.scales.dtype == torch.float16
               for image in result.images.values())
    assert all(torch.equal(value, original[key]) for key, value in layer.state_dict().items())
    assert all(parameter.requires_grad for parameter in layer.parameters())


if __name__ == "__main__":
    test_composed_reconstruction()
    print("composed ternary reconstruction CPU contract passes")
