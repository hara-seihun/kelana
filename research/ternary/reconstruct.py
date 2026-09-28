"""Reconstruct a Qwen decoder block using only packable ternary weight images.

Give the BF16 reference layer and its seven quantized projection images, plus
actual layer inputs from the quantized model. The loss compares complete
teacher and student block outputs on *the same* inputs. Ternary codes use a
straight-through estimator; group scales train in log space and round to FP16
inside every forward pass. The returned images contain no latent parameters.

This is a calibration fit, not a whole-model optimizer. The caller controls
its train/held input split, commits returned images through the radix-243
serializer, and measures sequentially substituted model quality.
"""

from dataclasses import dataclass, field
from typing import Any, Mapping, Sequence

import torch
from torch import nn
from torch.func import functional_call

from quantize import GROUP, TernaryImage, _hadamard, _rotate

PROJECTIONS = (
    "self_attn.q_proj.weight", "self_attn.k_proj.weight", "self_attn.v_proj.weight",
    "self_attn.o_proj.weight", "mlp.gate_proj.weight", "mlp.up_proj.weight",
    "mlp.down_proj.weight",
)


@dataclass(frozen=True)
class BlockBatch:
    hidden_states: torch.Tensor
    kwargs: Mapping[str, Any] = field(default_factory=dict)


@dataclass
class ReconstructionResult:
    images: dict[str, TernaryImage]
    initial_loss: float
    best_loss: float
    history: list[dict[str, float | int]]


def _output(layer: nn.Module, batch: BlockBatch, overrides: Mapping[str, torch.Tensor] | None = None) -> torch.Tensor:
    value = (functional_call(layer, overrides, (batch.hidden_states,), dict(batch.kwargs))
             if overrides is not None else layer(batch.hidden_states, **batch.kwargs))
    if isinstance(value, tuple):
        value = value[0]
    if not isinstance(value, torch.Tensor):
        raise TypeError("decoder block must return a tensor or tuple starting with one")
    return value


def _weight(image: TernaryImage, codes: torch.Tensor, scales: torch.Tensor) -> torch.Tensor:
    w = (codes.reshape(-1, image.scales.shape[1], GROUP) * scales.unsqueeze(-1)).reshape(image.codes.shape)
    if image.rotation_block is not None:
        w = _hadamard(w, image.rotation_block) * image.signs.float()
    return w


@torch.enable_grad()
def reconstruct_block(
    layer: nn.Module,
    images: Mapping[str, TernaryImage],
    batches: Sequence[BlockBatch],
    *,
    steps: int = 24,
    lr_codes: float = 0.05,
    lr_scales: float = 0.01,
    evaluate_every: int = 4,
) -> ReconstructionResult:
    """Fit the seven Qwen projections against full decoder-block outputs.

    `layer` is the BF16 source block; its parameters never change. `batches`
    contain already-device-placed true hidden states and forward kwargs such
    as `position_embeddings=(cos,sin)`, `attention_mask`, `use_cache=False`.
    Every step trains against one batch in round-robin order. Every
    `evaluate_every` steps, score the rounded image on *all* batches and keep
    the best image, including the initial one. Passing a held set here leaks
    it into fitting; supply train inputs only.
    """
    if set(images) != set(PROJECTIONS):
        raise ValueError("images must contain exactly the seven Qwen decoder projections")
    if not batches or steps < 0 or evaluate_every <= 0 or lr_codes <= 0 or lr_scales <= 0:
        raise ValueError("need batches, nonnegative steps, positive rates and evaluation interval")
    named = dict(layer.named_parameters())
    device = named[PROJECTIONS[0]].device
    if any(batch.hidden_states.device != device for batch in batches):
        raise ValueError("all batches must be placed on the layer device")
    for name in PROJECTIONS:
        image = images[name]
        if named[name].shape != image.codes.shape or image.codes.shape[1] % GROUP:
            raise ValueError(f"wrong image shape for {name}")
        if image.scales.shape != (image.codes.shape[0], image.codes.shape[1] // GROUP):
            raise ValueError(f"wrong scale shape for {name}")
        if image.rotation_block is not None and (
            image.signs is None or image.signs.shape != (image.codes.shape[1],)
        ):
            raise ValueError(f"wrong rotation signs for {name}")

    placed = {name: TernaryImage(image.codes.to(device), image.scales.to(device),
                                 image.signs.to(device) if image.signs is not None else None,
                                 image.rotation_block)
              for name, image in images.items()}
    latents = {}
    for name, image in placed.items():
        original = named[name].detach().float()
        if image.rotation_block is not None:
            original = _rotate(original, image.signs, image.rotation_block)
        scale = image.scales.float().clamp_min(1e-8).repeat_interleave(GROUP, dim=1)
        # The latent still rounds to the supplied image. Residual position
        # within its code cell lets a nearby threshold flip in a few steps.
        residual = (original / scale - image.codes.float()).clamp(-0.49, 0.49)
        latents[name] = nn.Parameter((image.codes.float() + residual).clamp(-1, 1))
    log_scales = {name: nn.Parameter(image.scales.float().clamp_min(1e-8).log())
                  for name, image in placed.items()}
    optimizer = torch.optim.Adam([
        {"params": list(latents.values()), "lr": lr_codes},
        {"params": list(log_scales.values()), "lr": lr_scales},
    ])
    training = layer.training
    original_grad = {name: p.requires_grad for name, p in named.items()}
    layer.eval()
    for param in named.values():
        param.requires_grad_(False)

    def current_image() -> dict[str, TernaryImage]:
        return {name: TernaryImage(
            codes=latents[name].detach().clamp(-1, 1).round().to(torch.int8).clone(),
            scales=log_scales[name].detach().exp().to(torch.float16).clone(),
            signs=image.signs,
            rotation_block=image.rotation_block,
        ) for name, image in placed.items()}

    def weights(image_map: Mapping[str, TernaryImage]) -> dict[str, torch.Tensor]:
        return {name: image.decode().to(named[name].dtype) for name, image in image_map.items()}

    try:
        with torch.no_grad():
            targets = [_output(layer, batch).detach() for batch in batches]
            target_energy = sum(target.float().square().sum().item() for target in targets)
            if target_energy <= 0:
                raise ValueError("teacher block outputs have zero energy")
            def score(candidate: Mapping[str, TernaryImage]) -> float:
                substitute = weights(candidate)
                return sum((_output(layer, batch, substitute).float() - target.float()).square().sum().item()
                           for batch, target in zip(batches, targets)) / target_energy

            best = current_image()
            initial_loss = score(best)
            best_loss = initial_loss
        history: list[dict[str, float | int]] = [{"step": 0, "loss": initial_loss}]
        for step in range(1, steps + 1):
            index = (step - 1) % len(batches)
            optimizer.zero_grad(set_to_none=True)
            substitute = {}
            for name, image in placed.items():
                continuous = latents[name].clamp(-1, 1)
                code = continuous + (continuous.round() - continuous).detach()
                scale = log_scales[name].exp()
                scale = scale + (scale.half().float() - scale).detach()
                substitute[name] = _weight(image, code, scale).to(named[name].dtype)
            prediction = _output(layer, batches[index], substitute)
            error = (prediction.float() - targets[index].float()).square().mean()
            error.backward()
            optimizer.step()
            if step % evaluate_every == 0 or step == steps:
                with torch.no_grad():
                    candidate = current_image()
                    value = score(candidate)
                if not torch.isfinite(torch.tensor(value)):
                    raise ValueError(f"nonfinite block reconstruction loss at step {step}")
                history.append({"step": step, "loss": value})
                if value < best_loss:
                    best, best_loss = candidate, value
        return ReconstructionResult(best, initial_loss, best_loss, history)
    finally:
        for name, param in named.items():
            param.requires_grad_(original_grad[name])
        layer.train(training)
