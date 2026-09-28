"""Minimal read-only GGUF reader for Bonsai PTQ1_0, plus PTQ1_0 block decode.

Mirrors bonsai-halo/src/gguf.cpp (header walk) and halo_format.h
(decode_gguf_ptq1_0). Trits are returned as int8 in {-1,0,+1}.
"""

import numpy as np
import struct

GGML_F32, GGML_F16, GGML_BF16 = 0, 1, 30
GGML_Q1_0, GGML_PQ2_0, GGML_PTQ1_0 = 41, 142, 143

# GGUF value types
U8, I8, U16, I16, U32, I32, F32, BOOL, STRING, ARRAY, U64, I64, F64 = range(13)
_FIX = {U8: "B", I8: "b", U16: "H", I16: "h", U32: "I", I32: "i",
        F32: "f", BOOL: "?", U64: "Q", I64: "q", F64: "d"}


class Gguf:
    def __init__(self, path):
        self.path = path
        self.f = open(path, "rb")
        buf = self.f.read(1 << 22)
        self.buf, self.p = buf, 0
        magic, version, n_tensors, n_kv = struct.unpack_from("<IIQQ", buf, 0)
        assert magic == 0x46554747 and version == 3, (magic, version)
        self.p = 24
        self.kv = {}
        for _ in range(n_kv):
            k = self._str()
            self.kv[k] = self._value()
        self.tensors = {}
        for _ in range(n_tensors):
            name = self._str()
            nd = self._u32()
            ne = [self._u64() for _ in range(nd)]
            dtype = self._u32()
            off = self._u64()
            self.tensors[name] = (ne, dtype, off)
        align = self.kv.get("general.alignment", 32)
        self.data0 = (self.p + align - 1) // align * align

    # -- primitive readers -------------------------------------------------
    def _need(self, n):
        if self.p + n > len(self.buf):
            self.f.seek(len(self.buf))
            self.buf += self.f.read(max(n, 1 << 22))

    def _u32(self):
        self._need(4)
        v = struct.unpack_from("<I", self.buf, self.p)[0]
        self.p += 4
        return v

    def _u64(self):
        self._need(8)
        v = struct.unpack_from("<Q", self.buf, self.p)[0]
        self.p += 8
        return v

    def _str(self):
        n = self._u64()
        self._need(n)
        s = self.buf[self.p:self.p + n].decode("utf-8", "replace")
        self.p += n
        return s

    def _value(self):
        t = self._u32()
        return self._value_of(t)

    def _value_of(self, t):
        if t == STRING:
            return self._str()
        if t == ARRAY:
            et = self._u32()
            n = self._u64()
            if et in _FIX:
                fmt = _FIX[et]
                sz = struct.calcsize("<" + fmt) * n
                self._need(sz)
                a = np.frombuffer(self.buf, dtype=np.dtype("<" + fmt), count=n,
                                  offset=self.p).copy()
                self.p += sz
                return a
            return [self._value_of(et) for _ in range(n)]
        fmt = _FIX[t]
        sz = struct.calcsize("<" + fmt)
        self._need(sz)
        v = struct.unpack_from("<" + fmt, self.buf, self.p)[0]
        self.p += sz
        return v

    # -- tensor access -----------------------------------------------------
    def rows_ptq1_0(self, name, row0, nrows, col0=0, ncols=None):
        """Decode rows [row0, row0+nrows) of a PTQ1_0 tensor.

        Returns (trits int8 [nrows, ncols] in {-1,0,1}, scales f32 [nrows, ncols/128]).
        ne = [K, N]: K is the contiguous (column) dimension.
        """
        ne, dtype, off = self.tensors[name]
        assert dtype == GGML_PTQ1_0, dtype
        K, N = ne[0], ne[1]
        ncols = K if ncols is None else ncols
        assert col0 % 128 == 0 and ncols % 128 == 0 and col0 + ncols <= K
        row_bytes = (K // 128) * 28
        base = self.data0 + off + row0 * row_bytes + (col0 // 128) * 28
        nblk = ncols // 128
        raw = np.empty((nrows, nblk * 28), dtype=np.uint8)
        for r in range(nrows):
            self.f.seek(base + r * row_bytes)
            raw[r] = np.frombuffer(self.f.read(nblk * 28), dtype=np.uint8)
        blk = raw.reshape(nrows * nblk, 28)
        trit = decode_ptq1_0(blk).reshape(nrows, ncols)
        scale = blk[:, 26:28].copy().view(np.float16).astype(np.float32).reshape(nrows, nblk)
        return trit, scale


def decode_ptq1_0(blk):
    """blk uint8 [n, 28] -> int8 trits [n, 128] in {-1,0,+1}, natural order."""
    n = blk.shape[0]
    qs = blk[:, :24].astype(np.uint32)
    qh = blk[:, 24:26].astype(np.uint32)
    out = np.empty((n, 128), dtype=np.int8)
    e = 0
    for j0, c in ((0, 16), (16, 8)):
        q = qs[:, j0:j0 + c].copy()
        for _ in range(5):
            m = q * 3
            out[:, e:e + c] = (m >> 8).astype(np.int8)
            q = m & 0xFF
            e += c
    q = qh.copy()
    for _ in range(4):
        m = q * 3
        out[:, e:e + 2] = (m >> 8).astype(np.int8)
        q = m & 0xFF
        e += 2
    return out - 1  # {0,1,2} -> {-1,0,+1}


def hadamard(n):
    h = np.ones((1, 1), dtype=np.int64)
    while h.shape[0] < n:
        h = np.block([[h, h], [h, -h]])
    return h


def sign_vectors(g):
    """prism.hadamard sign vectors as {width: int8 array}, from GGUF metadata."""
    widths = [int(w) for w in g.kv["prism.hadamard.sign_widths"]]
    values = np.asarray(g.kv["prism.hadamard.sign_values"]).astype(np.int8)
    out, off = {}, 0
    for w in widths:
        out[w] = values[off:off + w].copy()
        off += w
    return out
