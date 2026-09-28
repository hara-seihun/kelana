#!/usr/bin/env python3
"""Accept adjacent ternary-code changes only on complete-model train loss.

A gradient ranks candidate trit changes across every decoder projection.
Each proposed global budget is tested by a real forward pass on a fixed,
disjoint TRAIN check panel. Losing candidates are rolled back. Scales, signs,
tied embedding/head codes, norms and packed byte cost never change.
"""

import argparse
from dataclasses import dataclass
import json
import math
from pathlib import Path
import shutil
import tempfile
import time

import numpy as np
import torch

from pilot import ROOT, MODEL, load_model, packed, sha, unpacked
from quantize import TernaryImage
from tune import _install, _nll


@dataclass(frozen=True)
class Move:
    key: str
    index: int
    next_code: int
    estimated_gain: float


def rank_moves(providers, maximum: int) -> list[Move]:
    """Global top-k valid single-step trit changes under the STE derivative."""
    local = []
    for key, provider in providers.items():
        latent = provider.code_latent
        if latent is None:
            continue
        grad = latent.grad
        if grad is None:
            raise ValueError(f"missing whole-model gradient for {key}")
        with torch.no_grad():
            current = latent.clamp(-1, 1).round().to(torch.int8)
            delta = torch.where(grad < 0, 1, -1)
            allowed = ((current.float() + delta).abs() <= 1) & torch.isfinite(grad) & (grad != 0)
            benefit = grad.abs().masked_fill(~allowed, float("-inf"))
            scores, indexes = benefit.reshape(-1).topk(min(maximum, benefit.numel()))
            valid = torch.isfinite(scores)
            if valid.any().item():
                indexes = indexes[valid]
                local.append((key, scores[valid], indexes,
                              (current.flatten()[indexes].long() + delta.flatten()[indexes].long())))
    if not local:
        return []
    all_scores = torch.cat([record[1] for record in local])
    selected = all_scores.topk(min(maximum, all_scores.numel())).indices.cpu().tolist()
    starts = []
    cursor = 0
    for _, scores, _, _ in local:
        starts.append(cursor)
        cursor += scores.numel()
    result = []
    for i in selected:
        group = next(group for group in range(len(local)) if i < starts[group] + local[group][1].numel())
        key, scores, indexes, new_codes = local[group]
        at = i - starts[group]
        result.append(Move(key, int(indexes[at]), int(new_codes[at]), float(scores[at])))
    return result


def _assign(providers, moves: list[Move], restore=None):
    with torch.no_grad():
        for position, move in enumerate(moves):
            value = move.next_code if restore is None else restore[position]
            providers[move.key].code_latent.view(-1)[move.index] = value


def try_budgets(providers, moves: list[Move], budgets: list[int], score, baseline: float,
                min_gain: float = 1e-5):
    """Test independent prefixes against the same current image and check panel."""
    if not moves:
        return baseline, None, []
    trials = []
    best_score, best_budget = baseline, None
    for budget in budgets:
        chosen = moves[:min(budget, len(moves))]
        originals = [float(providers[move.key].code_latent.detach().view(-1)[move.index]) for move in chosen]
        _assign(providers, chosen)
        try:
            measured = score()
        finally:
            _assign(providers, chosen, originals)
        if not math.isfinite(measured):
            raise ValueError(f"nonfinite complete-model check loss for budget {budget}")
        trials.append({"budget": budget, "proposed_changes": len(chosen), "check_train_nll": measured})
        if measured < best_score - min_gain:
            best_score, best_budget = measured, budget
    if best_budget is not None:
        _assign(providers, moves[:min(best_budget, len(moves))])
    return best_score, best_budget, trials


def save_images(destination: Path, source: Path, source_manifest: dict, providers, receipt: dict):
    if destination.exists():
        raise FileExistsError(destination)
    with tempfile.TemporaryDirectory(prefix=f".{destination.name}-", dir=destination.parent) as temporary:
        output = Path(temporary)
        records = []
        changed_total = 0
        for previous in source_manifest["matrices"]:
            key = previous["key"]
            filename = key.replace(".", "_") + ".npz"
            original_path, path = source / filename, output / filename
            provider = providers[key]
            image = provider.image()
            altered = int((image.codes != provider.codes).sum().item())
            changed_total += altered
            if altered:
                original = unpacked(original_path, device="cpu")
                if not torch.equal(image.scales.cpu(), original.scales):
                    raise ValueError(f"paid scales changed for {key}")
                fixed = TernaryImage(image.codes.cpu(), original.scales, original.signs, original.rotation_block)
                size = packed(fixed, path)
            else:
                shutil.copy2(original_path, path)
                size = previous["payload_bytes"]
            if size != previous["payload_bytes"]:
                raise ValueError(f"packed byte cost changed for {key}")
            record = dict(previous)
            record.update(sha256=sha(path), file_bytes=path.stat().st_size,
                          source_image_sha256=previous["sha256"],
                          method="whole-model-discrete-tune" if altered else previous.get("method"),
                          discrete_code_changes=altered)
            records.append(record)
            (path.with_suffix(".json")).write_text(json.dumps(record, indent=2) + "\n")
        shutil.copy2(source / "norms.npz", output / "norms.npz")
        manifest = dict(source_manifest)
        manifest.update(matrices=records, matrix_count=len(records),
                        source_manifest_sha256=sha(source / "manifest.json"),
                        discrete_training=receipt)
        source_matrix_bytes = sum(r["payload_bytes"] for r in source_manifest["matrices"])
        norm_bytes = source_manifest["payload_bytes"] - source_matrix_bytes
        if norm_bytes < 0 or sum(r["payload_bytes"] for r in records) + norm_bytes != manifest["payload_bytes"]:
            raise ValueError("complete image accounting changed")
        if changed_total != receipt["accepted_code_changes"]:
            raise ValueError("exported trit changes differ from the accepted proposal")
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        (output / "training.json").write_text(json.dumps(receipt, indent=2) + "\n")
        output.rename(destination)


def run(args):
    budgets = [int(value) for value in args.budgets.split(",")]
    if (not budgets or any(value <= 0 for value in budgets) or len(set(budgets)) != len(budgets)
            or args.source == args.name or args.rounds <= 0 or args.gradient_windows <= 0
            or args.check_windows <= 0 or args.train_offset < 0 or args.tokens < 2 or args.min_gain < 0):
        raise ValueError("distinct names, positive rounds/budgets/window counts and tokens are required")
    source, destination = ROOT / args.source, ROOT / args.name
    if destination.exists():
        raise FileExistsError(destination)
    manifest = json.loads((source / "manifest.json").read_text())
    if sha(MODEL / "source.json") != manifest["model_source_sha256"]:
        raise ValueError("BF16 source changed")
    model = load_model()
    providers = _install(model, source, manifest, set(range(model.config.num_hidden_layers)))
    for provider in providers.values():
        provider.log_scales.requires_grad_(False)
    if providers["model.embed_tokens.weight"].code_latent is not None:
        raise ValueError("tied embedding/head codes must stay fixed")
    model.train()
    model.gradient_checkpointing_enable(gradient_checkpointing_kwargs={"use_reentrant": False})
    fixture = Path(args.fixture)
    with np.load(fixture) as data:
        if "train" not in data:
            raise ValueError("fixture needs a TRAIN split")
        window = data["train"][args.train_offset:args.train_offset + args.gradient_windows + args.check_windows,
                               :args.tokens].copy()
    if len(window) != args.gradient_windows + args.check_windows or window.shape[1] != args.tokens:
        raise ValueError("requested disjoint TRAIN panels exceed the fixture")
    panel = torch.as_tensor(window, device="cuda", dtype=torch.long)
    gradient_panel = panel[:args.gradient_windows]
    check_panel = panel[args.gradient_windows:]

    def score():
        with torch.no_grad():
            return sum(float(_nll(model, row)) for row in check_panel) / len(check_panel)

    baseline = score()
    initial_loss = baseline
    history = [{"round": 0, "check_train_nll": baseline}]
    started = time.time()
    print(json.dumps(history[0]), flush=True)
    for round_number in range(1, args.rounds + 1):
        model.zero_grad(set_to_none=True)
        for row in gradient_panel:
            (_nll(model, row) / len(gradient_panel)).backward()
        moves = rank_moves(providers, max(budgets))
        baseline, accepted, trials = try_budgets(providers, moves, budgets, score, baseline, args.min_gain)
        entry = {"round": round_number, "check_train_nll": baseline,
                 "ranked_valid_changes": len(moves), "accepted_budget": accepted, "trials": trials}
        history.append(entry)
        print(json.dumps(entry), flush=True)
        if not moves or accepted is None:
            break
    changed = sum(int((p.image().codes != p.codes).sum()) for p in providers.values())
    receipt = dict(source=args.source, destination=args.name, fixture=str(fixture), token_sha256=sha(fixture),
                   source_manifest_sha256=sha(source / "manifest.json"), optimizer_source_sha256=sha(Path(__file__)),
                   train_offset=args.train_offset, gradient_windows=args.gradient_windows,
                   check_windows=args.check_windows, tokens=args.tokens, rounds_requested=args.rounds,
                   rounds_executed=len(history) - 1, budgets=budgets, min_gain=args.min_gain,
                   initial_check_train_nll=initial_loss, best_check_train_nll=baseline,
                   accepted_code_changes=changed, history=history, seconds=time.time() - started,
                   scales_frozen=True, tied_codes_frozen=True,
                   method="global adjacent-trit STE gradient proposals; exact complete-model TRAIN check acceptance")
    save_images(destination, source, manifest, providers, receipt)
    print(json.dumps({"destination": str(destination), "accepted_code_changes": changed,
                      "initial_train_nll": initial_loss, "best_train_nll": baseline,
                      "bpw": manifest["bpw"]}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="expanded-scale128")
    parser.add_argument("--name", default="discrete-codes")
    parser.add_argument("--fixture", default="/path/to/workspace/data/kelana-subbit/ternary/expanded-tokens.npz")
    parser.add_argument("--train-offset", type=int, default=160)
    parser.add_argument("--gradient-windows", type=int, default=4)
    parser.add_argument("--check-windows", type=int, default=8)
    parser.add_argument("--tokens", type=int, default=256)
    parser.add_argument("--rounds", type=int, default=8)
    parser.add_argument("--budgets", default="1024,256,64")
    parser.add_argument("--min-gain", type=float, default=1e-5)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    run(args)


if __name__ == "__main__":
    main()
