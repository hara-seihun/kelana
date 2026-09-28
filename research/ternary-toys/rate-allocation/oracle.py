"""Finite paid-image oracle for a two-block composed residual map."""
import itertools
import json
from pathlib import Path

import numpy as np

SCALES = (0.5, 0.75, 1.0, 1.5, 2.0)
ALPHABETS = {
    "ternary": (-1, 0, 1),
    "four_neg": (-2, -1, 0, 1),
    "four_pos": (-1, 0, 1, 2),
}
EYE = np.eye(2)
# Both operands are exactly representable as BF16; only the objective uses FP64.
A = np.array([[0.625, 1.5], [-0.5, 0.25]])
B = np.array([[-0.5, -0.5], [0.25, -0.5]])
INPUT = np.diag([2.0, 1.0])
TARGET = (EYE + B) @ (EYE + A)


def options(weight):
    images, meta, costs = [], [], []
    for alphabet, symbols in ALPHABETS.items():
        for scale in SCALES:
            for codes in itertools.product(symbols, repeat=4):
                base = (scale * np.array(codes, dtype=float)).reshape(2, 2)
                images.append(base)
                meta.append({"kind": alphabet, "scale": scale, "codes": list(codes)})
                costs.append(3)  # one radix-81/256 byte plus one FP16 scale
                if alphabet == "ternary":
                    for pos in range(4):
                        changed = base.copy()
                        changed.flat[pos] = weight.flat[pos]
                        images.append(changed)
                        meta.append({"kind": "exception", "scale": scale, "codes": list(codes), "position": pos})
                        costs.append(6)  # base 3 + one byte coordinate + FP16 value
    for scale in (0.25, 0.375) + SCALES:
        codes = np.clip(np.rint(weight / scale), -8, 7).astype(int)
        base = scale * codes
        images.append(base)
        meta.append({"kind": "four_bit", "scale": scale, "codes": codes.ravel().tolist()})
        costs.append(4)  # four signed nibbles plus one FP16 scale
        for pos in range(4):
            changed = base.copy()
            changed.flat[pos] = weight.flat[pos]
            images.append(changed)
            meta.append({"kind": "exception_four_bit", "scale": scale,
                         "codes": codes.ravel().tolist(), "position": pos})
            costs.append(7)
    images.append(weight.copy())
    meta.append({"kind": "bf16"})
    costs.append(8)  # 4 BF16 elements; no scale or code bytes
    return np.array(images), meta, np.array(costs)


def local_scores(a, b):
    err_a = (EYE + B) @ (a - A) @ INPUT
    err_b = (b - B) @ (EYE + A) @ INPUT
    return np.sum(err_a**2, axis=(1, 2)), np.sum(err_b**2, axis=(1, 2))


def exact_grid(a, b):
    # Rows index A images; columns index B images. Avoid a multi-million 2x2x2 tensor.
    aa = EYE + a
    bb = EYE + b
    e00 = aa[:, 0, 0, None] * bb[None, :, 0, 0] + aa[:, 1, 0, None] * bb[None, :, 0, 1] - TARGET[0, 0]
    e10 = aa[:, 0, 0, None] * bb[None, :, 1, 0] + aa[:, 1, 0, None] * bb[None, :, 1, 1] - TARGET[1, 0]
    e01 = aa[:, 0, 1, None] * bb[None, :, 0, 0] + aa[:, 1, 1, None] * bb[None, :, 0, 1] - TARGET[0, 1]
    e11 = aa[:, 0, 1, None] * bb[None, :, 1, 0] + aa[:, 1, 1, None] * bb[None, :, 1, 1] - TARGET[1, 1]
    return 4 * (e00**2 + e10**2) + e01**2 + e11**2


def optimize(a, b, ac, bc, la, lb, budget, mode):
    best = None
    for ca in sorted(set(ac)):
        for cb in sorted(set(bc)):
            if ca + cb > budget:
                continue
            ia = np.flatnonzero(ac == ca)
            ib = np.flatnonzero(bc == cb)
            if mode == "local":
                i, j = ia[np.argmin(la[ia])], ib[np.argmin(lb[ib])]
                score = la[i] + lb[j]
                if best is None or score < best[0]:
                    best = (score, int(i), int(j))
            else:
                for start in range(0, len(ia), 96):
                    rows = ia[start:start + 96]
                    scores = exact_grid(a[rows], b[ib])
                    k = int(np.argmin(scores))
                    i, j = rows[k // len(ib)], ib[k % len(ib)]
                    score = float(scores.flat[k])
                    if best is None or score < best[0]:
                        best = (score, int(i), int(j))
    assert best is not None
    _, i, j = best
    return {"quality": float(exact_grid(a[i:i + 1], b[j:j + 1])[0, 0]),
            "bytes": int(ac[i] + bc[j]), "a": i, "b": j}


def decode(meta, weight):
    if meta["kind"] == "bf16":
        return weight.copy()
    image = meta["scale"] * np.array(meta["codes"], dtype=float).reshape(2, 2)
    if "position" in meta:
        image.flat[meta["position"]] = weight.flat[meta["position"]]
    return image


def diagnostics(first, second):
    a, b = decode(first, A), decode(second, B)
    e_a = (EYE + B) @ (a - A) @ INPUT
    e_b = (b - B) @ (EYE + A) @ INPUT
    e_cross = (b - B) @ (a - A) @ INPUT
    return {"a_matrix": a.tolist(), "b_matrix": b.tolist(),
            "isolated_a": float(np.sum(e_a**2)), "isolated_b": float(np.sum(e_b**2)),
            "linear_sum": float(np.sum((e_a + e_b)**2)),
            "cross_norm": float(np.sum(e_cross**2)),
            "exact": float(np.sum((e_a + e_b + e_cross)**2))}


def main():
    a, am, ac = options(A)
    b, bm, bc = options(B)
    la, lb = local_scores(a, b)
    rows = []
    for budget in (7, 8, 9, 12):
        payload_budget = budget - 1  # one radix-7 mode byte names both images
        row = {"budget": budget, "joint": optimize(a, b, ac, bc, la, lb, payload_budget, "joint"),
               "independent": optimize(a, b, ac, bc, la, lb, payload_budget, "local")}
        for label, kinds in (("ternary_only", {"ternary"}),
                             ("base_alphabets", set(ALPHABETS)),
                             ("four_bit", {"four_bit"})):
            if label == "four_bit" and budget < 9:
                continue
            mask_a = np.array([m["kind"] in kinds for m in am])
            mask_b = np.array([m["kind"] in kinds for m in bm])
            row[label] = optimize(a[mask_a], b[mask_b], ac[mask_a], bc[mask_b],
                                  la[mask_a], lb[mask_b], payload_budget, "joint")
            row[label]["a_image"] = np.array(am, dtype=object)[mask_a][row[label].pop("a")]
            row[label]["b_image"] = np.array(bm, dtype=object)[mask_b][row[label].pop("b")]
        for key in ("joint", "independent"):
            v = row[key]
            v["a_image"], v["b_image"] = am[v.pop("a")], bm[v.pop("b")]
        for value in row.values():
            if isinstance(value, dict):
                value["bytes"] += 1
                measured = diagnostics(value["a_image"], value["b_image"])
                assert np.isclose(measured["exact"], value["quality"])
                if budget == 7:
                    value["diagnostics"] = measured
        rows.append(row)
    output = {"model": {"A": A.tolist(), "B": B.tolist(), "input": INPUT.tolist(),
                        "target": TARGET.tolist(), "scales": SCALES, "alphabets": ALPHABETS,
                        "options_per_matrix": len(a), "mode_header_bytes": 1,
                        "four_bit_scales": (0.25, 0.375) + SCALES}, "frontier": rows}
    Path(__file__).with_name("results.json").write_text(json.dumps(output, indent=2) + "\n")
    for row in rows:
        print(row["budget"], *(f'{row[k]["quality"]:.8f} ({row[k]["bytes"]} B)' for k in ("joint", "independent", "base_alphabets", "ternary_only") if k in row),
              f'four-bit={row.get("four_bit", {}).get("quality")}')


if __name__ == "__main__":
    main()
