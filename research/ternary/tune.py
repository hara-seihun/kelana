#!/usr/bin/env python3
"""Train paid scales and optional bounded code flips on full-model gold loss.

Run with the same Python environment as pilot.py. Signs, norms, weight tying
and paid image bytes stay fixed. Export radix-243 images for held evaluation.
"""

import argparse
import json
import math
from pathlib import Path
import shutil
import tempfile
import time

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

from quantize import GROUP, TernaryImage, _hadamard, _rotate


class PaidScaleImage(nn.Module):
    """Frozen trits/signs and a single trainable group-scale map."""

    def __init__(self, image: TernaryImage):
        super().__init__()
        self.register_buffer("codes", image.codes.detach().clone())
        self.register_buffer("signs", image.signs.detach().clone() if image.signs is not None else None)
        self.rotation_block = image.rotation_block
        self.log_scales = nn.Parameter(image.scales.float().clamp_min(1e-8).log())
        self.code_latent = None
        if image.codes.ndim != 2 or image.codes.shape[1] % GROUP:
            raise ValueError("image must be a group-128 matrix")

    def enable_codes(self, original):
        with torch.no_grad():
            target = original.float()
            if self.rotation_block is not None:
                target = _rotate(target, self.signs, self.rotation_block)
            scale = self.log_scales.exp().repeat_interleave(GROUP, dim=1)
            residual = (target / scale - self.codes.float()).clamp(-0.49, 0.49)
            self.code_latent = nn.Parameter((self.codes.float() + residual).clamp(-1, 1))

    def _scales(self, rows=None):
        raw = self.log_scales if rows is None else self.log_scales[rows]
        value = raw.exp()
        return value + (value.half().float() - value).detach()

    def decode(self, rows=None):
        if self.code_latent is None:
            codes = (self.codes if rows is None else self.codes[rows]).float()
        else:
            latent = self.code_latent if rows is None else self.code_latent[rows]
            continuous = latent.clamp(-1, 1)
            codes = continuous + (continuous.round() - continuous).detach()
        scales = self._scales(rows)
        shape = codes.shape
        weight = (codes.float().reshape(-1, shape[-1] // GROUP, GROUP)
                  * scales.reshape(-1, shape[-1] // GROUP, 1)).reshape(shape)
        if self.rotation_block is not None:
            weight = _hadamard(weight, self.rotation_block) * self.signs.float()
        return weight

    @torch.no_grad()
    def image(self) -> TernaryImage:
        codes = self.codes if self.code_latent is None else self.code_latent.clamp(-1, 1).round().to(torch.int8)
        return TernaryImage(codes, self.log_scales.exp().half(), self.signs, self.rotation_block)


class PackedLinear(nn.Module):
    def __init__(self, provider: PaidScaleImage):
        super().__init__()
        self.provider = provider

    def forward(self, x):
        return F.linear(x, self.provider.decode().to(x.dtype))


class PackedEmbedding(nn.Module):
    def __init__(self, provider: PaidScaleImage, padding_idx: int | None):
        super().__init__()
        self.provider = provider
        self.padding_idx = padding_idx

    def forward(self, ids):
        # Gather first. Decoding all 151,936 rows on every token lookup would
        # add a second full LM-head matrix to each training forward.
        return self.provider.decode(ids).to(torch.bfloat16)


def _install(model, source: Path, manifest: dict, code_layers: set[int]) -> dict[str, PaidScaleImage]:
    from pilot import sha, unpacked

    expected = {"model.embed_tokens.weight"}
    for i in range(model.config.num_hidden_layers):
        expected.update(f"model.layers.{i}.{name}.weight" for name in (
            "self_attn.q_proj", "self_attn.k_proj", "self_attn.v_proj", "self_attn.o_proj",
            "mlp.gate_proj", "mlp.up_proj", "mlp.down_proj"))
    records = {r["key"]: r for r in manifest["matrices"]}
    if set(records) != expected or not manifest["complete"]:
        raise ValueError("source must have exactly one packed tied image and seven per decoder block")
    if model.model.embed_tokens.weight.data_ptr() != model.lm_head.weight.data_ptr():
        raise ValueError("BF16 source embedding and LM head must be tied")
    providers = {}
    for key, rec in records.items():
        path = source / (key.replace(".", "_") + ".npz")
        if sha(path) != rec["sha256"]:
            raise ValueError(f"image digest mismatch for {key}")
        provider = PaidScaleImage(unpacked(path, device="cuda"))
        if key != "model.embed_tokens.weight" and int(key.split(".")[2]) in code_layers:
            parts = key.split(".")
            original_module = model.model.layers[int(parts[2])]
            for part in parts[3:-1]:
                original_module = getattr(original_module, part)
            provider.enable_codes(original_module.weight.detach())
        if key == "model.embed_tokens.weight":
            if provider.codes.shape != tuple(model.model.embed_tokens.weight.shape):
                raise ValueError("tied image shape mismatch")
            padding_idx = model.model.embed_tokens.padding_idx
            model.model.embed_tokens = PackedEmbedding(provider, padding_idx)
            model.lm_head = PackedLinear(provider)
        else:
            parts = key.split(".")
            layer = model.model.layers[int(parts[2])]
            path_parts = parts[3:-1]
            parent = layer
            for part in path_parts[:-1]:
                parent = getattr(parent, part)
            original = getattr(parent, path_parts[-1])
            if original.bias is not None or tuple(original.weight.shape) != tuple(provider.codes.shape):
                raise ValueError(f"unsupported biased projection or shape for {key}")
            setattr(parent, path_parts[-1], PackedLinear(provider))
        providers[key] = provider
    for param in model.parameters():
        param.requires_grad_(False)
    for provider in providers.values():
        provider.log_scales.requires_grad_(True)
        if provider.code_latent is not None:
            provider.code_latent.requires_grad_(True)
    return providers


def _nll(model, tokens):
    logits = model(tokens[None], use_cache=False).logits[:, :-1].float()
    return F.cross_entropy(logits.reshape(-1, logits.shape[-1]), tokens[1:].reshape(-1))


def _save(destination: Path, source: Path, source_manifest: dict, providers: dict[str, PaidScaleImage],
          receipt: dict):
    if destination.exists():
        raise FileExistsError(f"destination already exists: {destination}")
    with tempfile.TemporaryDirectory(prefix=f".{destination.name}-", dir=destination.parent) as temporary:
        _write_images(Path(temporary), source, source_manifest, providers, receipt)
        Path(temporary).rename(destination)


def _write_images(destination: Path, source: Path, source_manifest: dict,
                  providers: dict[str, PaidScaleImage], receipt: dict):
    from pilot import packed, sha

    matrices = []
    for previous in source_manifest["matrices"]:
        key = previous["key"]
        image = providers[key].image()
        path = destination / (key.replace(".", "_") + ".npz")
        size = packed(image, path)
        if size != previous["payload_bytes"]:
            raise ValueError(f"image byte cost changed for {key}")
        record = dict(previous)
        record.update(sha256=sha(path), payload_bytes=size, file_bytes=path.stat().st_size,
                      source_image_sha256=previous["sha256"],
                      method="whole-model-code-scale-tune" if receipt["code_layers"] else "whole-model-scale-tune")
        matrices.append(record)
        (path.with_suffix(".json")).write_text(json.dumps(record, indent=2) + "\n")
    shutil.copy2(source / "norms.npz", destination / "norms.npz")
    manifest = dict(source_manifest)
    manifest.update(matrices=matrices, matrix_count=len(matrices),
                    source_manifest_sha256=sha(source / "manifest.json"),
                    scale_training=receipt)
    if manifest["payload_bytes"] != source_manifest["payload_bytes"] or manifest["bpw"] != source_manifest["bpw"]:
        raise ValueError("complete image byte accounting changed")
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (destination / "training.json").write_text(json.dumps(receipt, indent=2) + "\n")


def run(args):
    from pilot import ROOT, MODEL, load_model, sha

    if (args.source == args.name or args.steps <= 0 or args.windows <= 0 or args.tokens < 2
            or args.lr <= 0 or args.evaluate_every <= 0 or args.score_windows <= 0 or args.train_offset < 0):
        raise ValueError("use distinct source/name, positive steps/windows/rates and at least two tokens")
    source, destination = ROOT / args.source, ROOT / args.name
    if destination.exists():
        raise FileExistsError(destination)
    manifest = json.loads((source / "manifest.json").read_text())
    if sha(MODEL / "source.json") != manifest["model_source_sha256"]:
        raise ValueError("BF16 model source changed")
    model = load_model()
    code_layers = {int(layer) for layer in args.code_layers.split(",") if layer}
    if any(layer < 0 or layer >= model.config.num_hidden_layers for layer in code_layers):
        raise ValueError("code layer outside decoder")
    providers = _install(model, source, manifest, code_layers)
    model.train()
    model.gradient_checkpointing_enable(gradient_checkpointing_kwargs={"use_reentrant": False})
    fixture = Path(args.fixture)
    with np.load(fixture) as z:
        rows = z["train"][args.train_offset:args.train_offset + args.windows, :args.tokens].copy()
    if len(rows) != args.windows or rows.shape[1] != args.tokens:
        raise ValueError("not enough requested fresh train tokens")
    samples = torch.as_tensor(rows, device="cuda", dtype=torch.long)
    if args.code_budget < 0:
        raise ValueError("code budget must be nonnegative")
    optimizer = torch.optim.Adam([
        {"params": [p.log_scales for p in providers.values()], "lr": args.lr},
        {"params": [p.code_latent for p in providers.values() if p.code_latent is not None], "lr": args.code_lr},
    ])
    def score_train():
        with torch.no_grad():
            return sum(float(_nll(model, row)) for row in samples[:min(args.score_windows, len(samples))]) / min(args.score_windows, len(samples))

    started = time.time()
    best_loss = score_train()
    best_scales = {key: provider.log_scales.detach().clone() for key, provider in providers.items()}
    best_codes = {key: p.code_latent.detach().clone() for key, p in providers.items() if p.code_latent is not None}
    history = [{"step": 0, "check_train_nll": best_loss}]
    print(json.dumps(history[0]), flush=True)
    for step in range(args.steps):
        optimizer.zero_grad(set_to_none=True)
        loss = _nll(model, samples[step % len(samples)])
        if not torch.isfinite(loss).item():
            raise ValueError(f"nonfinite gold loss at step {step + 1}")
        loss.backward()
        optimizer.step()
        if args.code_budget:
            with torch.no_grad():
                for p in providers.values():
                    latent = p.code_latent
                    if latent is None:
                        continue
                    candidate = latent.clamp(-1, 1).round()
                    changed = candidate != p.codes
                    benefit = -latent.grad * (candidate - p.codes.float())
                    benefit = benefit.masked_fill(~changed, float("-inf"))
                    keep = torch.zeros_like(changed)
                    indexes = benefit.flatten().topk(min(args.code_budget, benefit.numel())).indices
                    keep.view(-1)[indexes] = benefit.flatten()[indexes] > 0
                    reset = p.codes.float() + (latent - p.codes.float()).clamp(-.499, .499)
                    latent.data.copy_(torch.where(changed & ~keep, reset, latent))
        value = float(loss.detach())
        entry = {"step": step + 1, "pre_update_nll": value}
        if (step + 1) % args.evaluate_every == 0 or step + 1 == args.steps:
            check_loss = score_train()
            entry["check_train_nll"] = check_loss
            entry["code_changes"] = {key: int((p.image().codes != p.codes).sum()) for key, p in providers.items() if p.code_latent is not None}
            if not math.isfinite(check_loss):
                raise ValueError(f"nonfinite checkpoint loss at step {step + 1}")
            if check_loss < best_loss:
                best_loss = check_loss
                best_scales = {key: provider.log_scales.detach().clone() for key, provider in providers.items()}
                best_codes = {key: p.code_latent.detach().clone() for key, p in providers.items() if p.code_latent is not None}
        history.append(entry)
        print(json.dumps(entry), flush=True)
    for key, provider in providers.items():
        provider.log_scales.data.copy_(best_scales[key])
        if key in best_codes:
            provider.code_latent.data.copy_(best_codes[key])
    code_changes = {key: int((p.image().codes != p.codes).sum()) for key, p in providers.items() if p.code_latent is not None}
    receipt = dict(code_layers=sorted(code_layers), code_learning_rate=args.code_lr, code_budget_per_matrix=args.code_budget,
                   code_changes=code_changes, fixture=str(fixture), train_offset=args.train_offset,
                   source=args.source, destination=args.name, steps=args.steps, windows=args.windows,
                   tokens=args.tokens, learning_rate=args.lr, evaluate_every=args.evaluate_every,
                   score_windows=min(args.score_windows, len(samples)), best_check_train_nll=best_loss,
                   history=history, seconds=time.time() - started, source_manifest_sha256=sha(source / "manifest.json"),
                   token_sha256=sha(fixture), optimizer_source_sha256=sha(Path(__file__)), signs_fixed=True,
                   optimizer="Adam FP32 log scales and selected STE ternary codes, FP16-round STE; Qwen layer gradient checkpointing")
    _save(destination, source, manifest, providers, receipt)
    print(json.dumps({"destination": str(destination), "source_bpw": manifest["bpw"],
                      "image_bpw": manifest["bpw"], "best_check_train_nll": best_loss}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="sequential-gptq")
    parser.add_argument("--name", default="model-tuned")
    parser.add_argument("--steps", type=int, default=32)
    parser.add_argument("--windows", type=int, default=16)
    parser.add_argument("--fixture", default="/path/to/workspace/data/kelana-subbit/ternary/tokens.npz")
    parser.add_argument("--train-offset", type=int, default=0)
    parser.add_argument("--tokens", type=int, default=256)
    parser.add_argument("--lr", type=float, default=.001)
    parser.add_argument("--evaluate-every", type=int, default=8)
    parser.add_argument("--score-windows", type=int, default=4)
    parser.add_argument("--code-layers", default="", help="comma-separated decoder layers whose seven ternary matrices may change codes")
    parser.add_argument("--code-lr", type=float, default=.03)
    parser.add_argument("--code-budget", type=int, default=0, help="maximum gradient-favored code flips per selected matrix")
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    run(args)


if __name__ == "__main__":
    main()
