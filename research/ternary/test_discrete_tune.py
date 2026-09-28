"""CPU proof that global candidate selection and rollback obey true loss."""

import torch
from torch import nn

from discrete_tune import rank_moves, try_budgets
from quantize import TernaryImage
from tune import PaidScaleImage


def test_global_adjacent_moves():
    providers = {}
    for name in ("first", "second"):
        image = TernaryImage(torch.zeros((1, 128), dtype=torch.int8),
                             torch.ones((1, 1), dtype=torch.float16), None, None)
        provider = PaidScaleImage(image)
        provider.code_latent = nn.Parameter(provider.codes.float())
        providers[name] = provider
    providers["first"].code_latent.grad = torch.zeros((1, 128))
    providers["second"].code_latent.grad = torch.zeros((1, 128))
    providers["first"].code_latent.grad[0, 0] = -3
    providers["second"].code_latent.grad[0, 0] = 2
    providers["first"].code_latent.grad[0, 1] = -1
    moves = rank_moves(providers, 3)
    assert [move.key for move in moves] == ["first", "second", "first"]
    assert [move.next_code for move in moves] == [1, -1, 1]

    def true_loss():
        first = providers["first"].code_latent.detach().flatten()
        second = providers["second"].code_latent.detach().flatten()
        return 10 - float(first[0]) + float(second[0]) + 4 * float(first[1])

    result, budget, trials = try_budgets(providers, moves, [3, 2, 1], true_loss, 10)
    assert budget == 2 and result == 8 and len(trials) == 3
    assert providers["first"].code_latent[0, 0] == 1
    assert providers["second"].code_latent[0, 0] == -1
    assert providers["first"].code_latent[0, 1] == 0
    before = {key: provider.code_latent.detach().clone() for key, provider in providers.items()}
    result, budget, _ = try_budgets(providers, moves, [3, 2, 1], lambda: 9.0, 8)
    assert budget is None and result == 8
    assert all(torch.equal(providers[key].code_latent, value) for key, value in before.items())


if __name__ == "__main__":
    test_global_adjacent_moves()
    print("global ternary move acceptance CPU contract passes")
