#!/usr/bin/env python3
"""Scan one real Bonsai layer for gate rows that are equal or opposite as whole rows.

Whole-row equality (up to global sign, with equal block-scale vectors) is the exact
precondition for sharing one gate dot product and one SiLU across several hidden units.
Anything weaker is not enough: see NOTES.md, obstruction O2/O3.

Usage: scan_gate_rows.py [LAYER] [GGUF]
"""
import sys, struct, hashlib
import numpy as np

GGUF = sys.argv[2] if len(sys.argv) > 2 else "/path/to/workspace/data/bonsai2/PTQ1_0.gguf"
LAYER = int(sys.argv[1]) if len(sys.argv) > 1 else 0

TYPE_SIZE = {41: (32, 10), 143: (128, 28), 1: (1, 2), 0: (1, 4), 30: (1, 2)}


def read_gguf_index(path):
    f = open(path, "rb")
    magic, ver, n_tensors, n_kv = struct.unpack("<4sIQQ", f.read(24))
    assert magic == b"GGUF", magic

    def rd(fmt):
        n = struct.calcsize(fmt)
        return struct.unpack(fmt, f.read(n))

    def rstr():
        (n,) = rd("<Q")
        return f.read(n).decode("utf-8", "replace")

    def rval(t):
        simple = {0: "<B", 1: "<b", 2: "<H", 3: "<h", 4: "<I", 5: "<i", 6: "<f",
                  7: "<?", 10: "<Q", 11: "<q", 12: "<d"}
        if t == 8:
            return rstr()
        if t == 9:
            (et,) = rd("<I")
            (n,) = rd("<Q")
            return [rval(et) for _ in range(n)]
        return rd(simple[t])[0]

    kv = {}
    for _ in range(n_kv):
        k = rstr()
        (t,) = rd("<I")
        kv[k] = rval(t)
    tensors = {}
    for _ in range(n_tensors):
        name = rstr()
        (nd,) = rd("<I")
        dims = rd("<" + "Q" * nd)
        (ttype,) = rd("<I")
        (off,) = rd("<Q")
        tensors[name] = (dims, ttype, off)
    align = kv.get("general.alignment", 32)
    base = f.tell()
    base = (base + align - 1) // align * align
    return f, tensors, base


def decode_ptq1_0(raw, nblocks):
    """raw: (nblocks, 28) uint8 -> (trits (nblocks,128) int8 in {-1,0,1}, scale (nblocks,) f32)."""
    qs = raw[:, :24].astype(np.uint32)
    qh = raw[:, 24:26].astype(np.uint32)
    out = np.empty((nblocks, 128), dtype=np.int8)
    e = 0
    for j0, c in ((0, 16), (16, 8)):
        q = qs[:, j0:j0 + c].copy()
        for n in range(5):
            out[:, e:e + c] = ((q * 3) >> 8).astype(np.int8)
            q = (q * 3) & 0xFF
            e += c
    q = qh.copy()
    for n in range(4):
        out[:, e:e + 2] = ((q * 3) >> 8).astype(np.int8)
        q = (q * 3) & 0xFF
        e += 2
    scale = raw[:, 26:28].copy().view(np.float16).astype(np.float32).reshape(nblocks)
    return out.astype(np.int8) - 1, scale


def load_ternary(f, tensors, base, name):
    dims, ttype, off = tensors[name]
    assert ttype == 143, (name, ttype)
    K, N = dims[0], dims[1]
    nb = K // 128
    f.seek(base + off)
    raw = np.frombuffer(f.read(N * nb * 28), dtype=np.uint8).reshape(N * nb, 28)
    trits, scales = decode_ptq1_0(raw, N * nb)
    return trits.reshape(N, K), scales.reshape(N, nb)


def classify(trits, scales, label):
    N, K = trits.shape
    print(f"{label}: {N} rows x {K} cols, {scales.shape[1]} scale blocks")
    nz = (trits != 0).sum(axis=1)
    print(f"  nonzero trits per row: min {nz.min()} mean {nz.mean():.1f} max {nz.max()}")
    print(f"  all-zero rows: {(nz == 0).sum()}")
    dead_blocks = ((trits.reshape(N, -1, 128) != 0).sum(axis=2) == 0).sum()
    print(f"  all-zero 128-blocks: {dead_blocks} / {N * scales.shape[1]}")

    # Canonical sign: first nonzero trit forced to +1, so equal-and-opposite rows collide.
    first = np.zeros(N, dtype=np.int8)
    idx = np.argmax(trits != 0, axis=1)
    first = trits[np.arange(N), idx]
    first[nz == 0] = 1
    canon = trits * first[:, None]

    def dup_report(mat, tag):
        h = {}
        for i in range(N):
            k = hashlib.blake2b(mat[i].tobytes(), digest_size=16).digest()
            h.setdefault(k, []).append(i)
        classes = [v for v in h.values() if len(v) > 1]
        print(f"  {tag}: {len(h)} distinct rows, {len(classes)} classes of size>1, "
              f"{sum(len(v) - 1 for v in classes)} removable rows")
        return classes

    dup_report(trits, "exact equal patterns")
    cls = dup_report(canon, "equal-up-to-sign patterns")
    for v in cls[:5]:
        same_scale = np.allclose(scales[v[0]], scales[v[1]])
        print(f"    class {v[:4]} scales equal: {same_scale}")
    return cls


def canon(trits):
    N = trits.shape[0]
    idx = np.argmax(trits != 0, axis=1)
    first = trits[np.arange(N), idx]
    first[first == 0] = 1
    return trits * first[:, None]


f, tensors, base = read_gguf_index(GGUF)
mats = {}
for part in ("gate", "up"):
    name = f"blk.{LAYER}.ffn_{part}.weight"
    mats[part] = load_ternary(f, tensors, base, name)
    classify(*mats[part], name)

# Cross collisions: a gate row equal (up to sign) to an up row lets one dot product feed both
# matvecs; U_i = +-G_i additionally makes the unit a function of a single dot product.
g, gs = mats["gate"]
u, us = mats["up"]
cg, cu = canon(g), canon(u)
gh = {hashlib.blake2b(r.tobytes(), digest_size=16).digest() for r in cg}
uh = [hashlib.blake2b(r.tobytes(), digest_size=16).digest() for r in cu]
cross = sum(1 for h in uh if h in gh)
print(f"gate/up cross collisions up to sign: {cross}")
print(f"units with U_i == +-G_i: {int((cg == cu).all(axis=1).sum())}")

# How close does any pair come to +-equality? Sample-based, ternary agreement fraction.
rng = np.random.default_rng(0)
samp = rng.choice(g.shape[0], 3072, replace=False)
A = g[samp].astype(np.float32)
gram = np.abs(A @ A.T)
np.fill_diagonal(gram, 0.0)
norms = np.sqrt((A * A).sum(axis=1))
cos = gram / np.outer(norms, norms)
print(f"sampled 3072 gate rows: max |cos| between distinct rows = {cos.max():.4f} "
      f"(1.0 required for any exact sharing)")

