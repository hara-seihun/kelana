#!/usr/bin/env python3
"""Screen paired down-projection trit/scale moves, then score exact Qwen NLL.

Run search once, then held --split test/validation --offset N --windows N.
All GPU entry points belong under tools/run-batch-compare. No held data enter search.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pilot import MODEL, ROOT, load_model, packed, sha, unpacked
from quantize import _rotate, TernaryImage
from tune import _install, _nll

BASE = ROOT / "expanded-scale384"
OUT = ROOT / "paired-repair"
KEY = "model.layers.12.mlp.down_proj.weight"
FIXTURE = ROOT / "expanded-tokens.npz"


def setup():
    source = json.loads((BASE / "manifest.json").read_text())
    if sha(MODEL / "source.json") != source["model_source_sha256"]:
        raise ValueError("BF16 checkpoint changed")
    model = load_model()
    original = model.model.layers[12].mlp.down_proj.weight.detach().float().clone()
    providers = _install(model, BASE, source, set())
    model.eval()
    target = providers[KEY]
    for provider in providers.values():
        provider.log_scales.requires_grad_(False)
    return model, target, original, source


def panels():
    with np.load(FIXTURE) as fixture:
        proposal = fixture["train"][448:450, :96].copy()
        check = fixture["train"][450:454, :96].copy()
    if proposal.shape != (2, 96) or check.shape != (4, 96):
        raise ValueError("fresh train panels missing")
    return [torch.as_tensor(x, device="cuda", dtype=torch.long) for x in proposal], [
        torch.as_tensor(x, device="cuda", dtype=torch.long) for x in check]


def loss(model, panel):
    with torch.inference_mode():
        return sum(float(_nll(model, row)) for row in panel) / len(panel)


def moves(model, provider, original, proposal):
    captured = []
    def capture(_module, inputs):
        captured.append(inputs[0].detach().reshape(-1, inputs[0].shape[-1]))
    handle = model.model.layers[12].mlp.down_proj.register_forward_pre_hook(capture)
    try:
        loss(model, proposal)
    finally:
        handle.remove()
    x = _rotate(torch.cat(captured).float(), provider.signs, provider.rotation_block)
    teacher = _rotate(original, provider.signs, provider.rotation_block)
    codes = provider.codes.float()
    scales = provider.image().scales.float()
    residual = x @ (teacher - codes * scales.repeat_interleave(128, dim=1)).T
    rows = residual.square().mean(0).topk(8).indices.tolist()
    pool = []
    for row in rows:
        y = residual[:, row]
        for group in range(codes.shape[1] // 128):
            g = x[:, group * 128:(group + 1) * 128]
            old = float(scales[row, group]); base = g @ codes[row, group * 128:(group + 1) * 128]
            dot = g.T @ y
            square = g.square().sum(dim=0)
            current_codes = codes[row, group * 128:(group + 1) * 128].tolist()
            for factor in (0.7, 0.85, 1.15, 1.3):
                new = float(torch.tensor(old * factor, dtype=torch.float16))
                if new == old or new <= 0:
                    continue
                scale_delta = (new - old) * base
                scale_gain = float(2 * y.dot(scale_delta) - scale_delta.square().sum())
                pair_dot = g.T @ (y - scale_delta)
                for step in (-1, 1):
                    code_gain = 2 * old * step * dot - old**2 * square
                    pair_gain = scale_gain + 2 * new * step * pair_dot - new**2 * square
                    for col, (cg, pg) in enumerate(zip(code_gain.tolist(), pair_gain.tolist())):
                        current = int(current_codes[col])
                        if abs(current + step) > 1:
                            continue
                        pool.append(dict(row=row, group=group, col=group * 128 + col,
                                         old_code=current, next_code=current + step, old_scale=old,
                                         next_scale=new, local_pair_gain=pg,
                                         local_code_gain=cg, local_scale_gain=scale_gain,
                                         local_interaction=pg - cg - scale_gain))
    # Cover local fit winners and strong negative mixed differences. Distinct groups
    # avoid spending complete-model calls on near-identical perturbations.
    chosen = []; groups = set()
    for ranked in (sorted(pool, key=lambda m: m["local_pair_gain"], reverse=True),
                   sorted(pool, key=lambda m: m["local_interaction"], reverse=True)):
        limit = 3 if not chosen else 6
        for move in ranked:
            identity = (move["row"], move["group"])
            if identity in groups:
                continue
            chosen.append(move); groups.add(identity)
            if len(chosen) == limit:
                break
    return chosen, dict(captured_tokens=int(x.shape[0]), nominated_rows=rows,
                        searched_pairs=len(pool), local_metric="BF16 down output on actual quantized producer inputs")


def apply(provider, move, arm):
    row, group, col = (move[k] for k in ("row", "group", "col"))
    with torch.no_grad():
        provider.codes[row, col] = move["next_code"] if arm in ("pair", "code") else move["old_code"]
        value = move["next_scale"] if arm in ("pair", "scale") else move["old_scale"]
        provider.log_scales[row, group] = torch.tensor(value, device="cuda").log()
        # The real decoder rounds to FP16. A log round-trip that misses the
        # requested word would silently score a different image from export.
        if float(provider.image().scales[row, group]) != value:
            raise ValueError("requested FP16 scale not reproduced by provider")


def score_move(model, provider, panel, move, arm):
    apply(provider, move, arm)
    try:
        return loss(model, panel)
    finally:
        apply(provider, move, "baseline")


def export(source, provider, arm, move, receipt):
    dest = OUT / arm
    if dest.exists():
        raise FileExistsError(dest)
    with tempfile.TemporaryDirectory(prefix=f".{arm}-", dir=OUT) as td:
        path = Path(td)
        records = []
        for old in source["matrices"]:
            name = old["key"].replace(".", "_") + ".npz"
            target = path / name
            record = dict(old)
            if old["key"] == KEY:
                image = provider.image()
                size = packed(image, target)
                if size != old["payload_bytes"]:
                    raise ValueError("payload changed")
                record.update(method="paired-repair-" + arm, source_image_sha256=old["sha256"])
            else:
                shutil.copy2(BASE / name, target)
            record.update(sha256=sha(target), file_bytes=target.stat().st_size)
            records.append(record)
            (target.with_suffix(".json")).write_text(json.dumps(record, indent=2) + "\n")
        shutil.copy2(BASE / "norms.npz", path / "norms.npz")
        manifest = dict(source, matrices=records, source_manifest_sha256=sha(BASE / "manifest.json"),
                        paired_repair=dict(arm=arm, move=move, receipt=str(OUT / "search.json")))
        norm_bytes = source["payload_bytes"] - sum(r["payload_bytes"] for r in source["matrices"])
        if norm_bytes < 0 or sum(r["payload_bytes"] for r in records) + norm_bytes != source["payload_bytes"]:
            raise ValueError("complete image byte accounting changed")
        (path / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        (path / "training.json").write_text(json.dumps(receipt, indent=2) + "\n")
        path.rename(dest)
    return sha(dest / "manifest.json")


def nominate():
    OUT.mkdir(parents=True, exist_ok=True)
    destination = OUT / "nominations.json"
    if destination.exists():
        raise FileExistsError(destination)
    model, provider, original, _ = setup()
    proposal, _ = panels()
    selected, screen = moves(model, provider, original, proposal)
    destination.write_text(json.dumps(dict(moves=selected, screen=screen,
        source_manifest_sha256=sha(BASE / "manifest.json"), fixture_sha256=sha(FIXTURE)), indent=2) + "\n")
    print(json.dumps({"path": str(destination), "screen": screen, "moves": selected}), flush=True)


def search():
    OUT.mkdir(parents=True, exist_ok=True)
    if (OUT / "search.json").exists():
        raise FileExistsError(OUT / "search.json")
    started = time.time()
    model, provider, _, source = setup()
    proposal, check = panels()
    nominations = json.loads((OUT / "nominations.json").read_text())
    if (nominations["source_manifest_sha256"] != sha(BASE / "manifest.json") or
            nominations["fixture_sha256"] != sha(FIXTURE)):
        raise ValueError("nominations no longer match source and fixture")
    selected, screen = nominations["moves"], nominations["screen"]
    base_proposal, base_check = loss(model, proposal), loss(model, check)
    scores = []
    for index, move in enumerate(selected):
        for arm in ("pair", "code", "scale"):
            value = score_move(model, provider, proposal, move, arm)
            scores.append(dict(index=index, arm=arm, proposal_nll=value,
                               proposal_gain=base_proposal - value))
        print(json.dumps({"proposal": index, "scores": scores[-3:]}), flush=True)
    winners = {}
    for arm in ("pair", "code", "scale"):
        ranked = sorted((r for r in scores if r["arm"] == arm), key=lambda r: r["proposal_nll"])
        # The separate check panel chooses among the three proposal finalists.
        finalists = ranked[:2]
        for item in finalists:
            item["check_nll"] = score_move(model, provider, check, selected[item["index"]], arm)
        winners[arm] = min(finalists, key=lambda r: r["check_nll"])
    receipt = dict(source=str(BASE), source_manifest_sha256=sha(BASE / "manifest.json"),
                   model_source_sha256=sha(MODEL / "source.json"), fixture=str(FIXTURE), fixture_sha256=sha(FIXTURE),
                   script_sha256=sha(Path(__file__)), key=KEY, proposal_rows=[448, 449], check_rows=list(range(450, 454)),
                   tokens_per_row=96, screen=screen, moves=selected, proposal_baseline=base_proposal,
                   check_baseline=base_check, scores=scores, winners=winners,
                   held_policy="freeze all three arm winners before validation/test; never reselect on held data",
                   seconds=time.time() - started)
    for arm, winner in winners.items():
        apply(provider, selected[winner["index"]], arm)
        try:
            winner["image_manifest_sha256"] = export(source, provider, arm, selected[winner["index"]], receipt)
        finally:
            apply(provider, selected[winner["index"]], "baseline")
    (OUT / "search.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"baseline": base_check, "winners": winners, "seconds": time.time() - started}), flush=True)


def held(arm, split, offset, windows):
    if not (OUT / "search.json").exists():
        raise ValueError("search and its frozen arms are required")
    arms = ("pair", "code", "scale", "baseline") if arm == "all" else (arm,)
    model, provider, _, _ = setup()
    receipt = json.loads((OUT / "search.json").read_text())
    with np.load(FIXTURE) as fixture:
        rows = fixture[split][offset:offset + windows].copy()
    if len(rows) != windows or rows.shape[1] != 256:
        raise ValueError("held panel is incomplete")
    for candidate in arms:
        path = OUT / f"{candidate}-{split}-{offset}-{windows}.json"
        if path.exists():
            raise FileExistsError(path)
        if candidate != "baseline":
            move = receipt["moves"][receipt["winners"][candidate]["index"]]
            apply(provider, move, candidate)
        image = BASE if candidate == "baseline" else OUT / candidate
        if candidate != "baseline" and sha(image / "manifest.json") != receipt["winners"][candidate]["image_manifest_sha256"]:
            raise ValueError("frozen image manifest changed")
        saved = unpacked(image / (KEY.replace(".", "_") + ".npz"), device="cuda")
        current = provider.image()
        if not torch.equal(saved.codes, current.codes) or not torch.equal(saved.scales, current.scales):
            raise ValueError("scored provider differs from frozen packed image")
        per_window = []
        for i, row in enumerate(rows):
            value = loss(model, [torch.as_tensor(row, device="cuda", dtype=torch.long)])
            per_window.append(dict(index=offset + i, predictions=len(row) - 1, nll=value))
        output = dict(arm=candidate, split=split, offset=offset, windows=per_window,
                      nll=float(np.mean([x["nll"] for x in per_window])), fixture_sha256=sha(FIXTURE),
                      image_manifest_sha256=sha(image / "manifest.json"), script_sha256=sha(Path(__file__)))
        path.write_text(json.dumps(output, indent=2) + "\n")
        print(json.dumps({"path": str(path), "nll": output["nll"]}), flush=True)
        if candidate != "baseline":
            apply(provider, move, "baseline")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=("nominate", "search", "held"))
    p.add_argument("--arm", choices=("pair", "code", "scale", "baseline", "all"), default="all")
    p.add_argument("--split", choices=("validation", "test"), default="test")
    p.add_argument("--offset", type=int, default=0)
    p.add_argument("--windows", type=int, default=8)
    args = p.parse_args()
    torch.set_num_threads(2)
    torch.backends.cuda.matmul.allow_tf32 = False
    if args.action == "nominate":
        nominate()
    elif args.action == "search":
        search()
    else:
        held(args.arm, args.split, args.offset, args.windows)
