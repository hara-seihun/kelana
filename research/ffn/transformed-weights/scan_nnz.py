"""Nonzero-count histogram per 128-wide PTQ1_0 block, without decoding trits.

Each qs byte carries 5 peeled trits and each qh byte 4, so a 256-entry table per
byte kind gives the block's nonzero count directly from the raw bytes.

Usage: python3 scan_nnz.py [--pattern ffn_down] [--layers 0-47] [--all-ptq]
"""

import argparse
import json
import numpy as np

from gguf_read import Gguf, GGML_PTQ1_0

GGUF = "/path/to/workspace/data/bonsai2/PTQ1_0.gguf"


def peel_tables():
    """qs byte -> number of nonzero trits among its 5; qh byte -> among its 4."""
    b = np.arange(256, dtype=np.uint32)
    t5 = np.zeros(256, dtype=np.uint8)
    t4 = np.zeros(256, dtype=np.uint8)
    q = b.copy()
    for n in range(5):
        m = q * 3
        nz = ((m >> 8) != 1).astype(np.uint8)   # stored 1 == trit 0
        t5 += nz
        if n < 4:
            t4 += nz
        q = m & 0xFF
    return t5, t4


def scan_tensor(g, name, t5, t4, chunk_blocks=1 << 20):
    ne, dtype, off = g.tensors[name]
    assert dtype == GGML_PTQ1_0
    K, N = ne[0], ne[1]
    nblk = N * (K // 128)
    hist = np.zeros(129, dtype=np.int64)
    g.f.seek(g.data0 + off)
    done = 0
    while done < nblk:
        n = min(chunk_blocks, nblk - done)
        raw = np.frombuffer(g.f.read(n * 28), dtype=np.uint8).reshape(n, 28)
        nnz = (t5[raw[:, :24]].sum(1, dtype=np.int32) +
               t4[raw[:, 24:26]].sum(1, dtype=np.int32))
        hist += np.bincount(nnz, minlength=129)
        done += n
    return hist


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pattern", default="ffn_down")
    ap.add_argument("--layers", default="0-47")
    ap.add_argument("--all-ptq", action="store_true")
    ap.add_argument("--json", default=None)
    a = ap.parse_args()

    g = Gguf(GGUF)
    t5, t4 = peel_tables()
    if a.all_ptq:
        names = [n for n, (ne, dt, off) in g.tensors.items() if dt == GGML_PTQ1_0]
    else:
        lo, hi = (int(x) for x in a.layers.split("-"))
        names = [f"blk.{i}.{a.pattern}.weight" for i in range(lo, hi + 1)]
        names = [n for n in names if n in g.tensors]

    total = np.zeros(129, dtype=np.int64)
    per = {}
    for n in names:
        h = scan_tensor(g, n, t5, t4)
        total += h
        nz = np.nonzero(h)[0]
        per[n] = dict(blocks=int(h.sum()), min=int(nz.min()), max=int(nz.max()),
                      n_128=int(h[128]), n_ge_120=int(h[120:].sum()))
    nz = np.nonzero(total)[0]
    out = dict(tensors=len(names), blocks=int(total.sum()),
               min=int(nz.min()), max=int(nz.max()),
               hist={int(v): int(total[v]) for v in nz},
               frac_le_127=float(total[:128].sum() / total.sum()),
               per_tensor_minmax=per)
    print(json.dumps(out, indent=1))
    if a.json:
        with open(a.json, "w") as f:
            json.dump(out, f, indent=1)


if __name__ == "__main__":
    main()
