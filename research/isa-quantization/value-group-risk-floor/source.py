#!/usr/bin/env sage -python
"""Source-only exact G32/paired-Q Gram certificates; one layer/head per bounded call."""
import gzip
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from sage.all import ZZ, matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCES = (
    ('kivi-two-bit-dot-native/original-o.bf16', '803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499'),
    ('contextual-value-feedback/original-o.bf16', '677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48'),
)


def main(layer, head):
    assert 0 <= layer < 2 and 0 <= head < 8
    rel, digest = SOURCES[layer]
    raw = (ROOT / rel).read_bytes()
    assert len(raw) == 4194304 and hashlib.sha256(raw).hexdigest() == digest
    words = np.frombuffer(raw, dtype='<u2').reshape(1024, 16, 128)
    fp = (words.astype('<u4') << 16).view('<f4').astype(np.float64)
    scaled = fp * 2.**35
    assert np.isfinite(scaled).all() and np.equal(scaled, np.rint(scaled)).all()
    assert np.max(np.abs(scaled)) < 2.**34
    integers = scaled.astype(np.int64)
    groups = []
    for group in range(4):
        sl = slice(32 * group, 32 * (group + 1))
        bf = np.concatenate((fp[:, 2*head, sl], fp[:, 2*head+1, sl]), axis=1)
        bi = np.concatenate((integers[:, 2*head, sl], integers[:, 2*head+1, sl]), axis=1)
        B = matrix(ZZ, bi.tolist())
        gram = B.transpose() * B
        d = np.array([int(gram[i,i]) for i in range(64)], dtype=np.float64)
        assert (d > 0).all()
        gf = bf.T @ bf
        assert np.allclose(gf, np.array(gram, dtype=np.float64) * 2.**-70, atol=1e-12, rtol=1e-12)
        normalized = gf / np.sqrt(np.outer(np.diag(gf), np.diag(gf)))
        eigmin = float(np.linalg.eigvalsh(normalized)[0])
        numerator = math.floor(4096 * eigmin)
        cert = 4096 * gram - numerator * matrix(ZZ, 64, 64, {(i,i): gram[i,i] for i in range(64)})
        # Exact rational congruence P*C*P^T = L*D*L^T, with all diagonal blocks 1x1.
        permutation, _, diagonal = cert.block_ldlt()
        pivots = [diagonal[i,i] for i in range(64)]
        assert all(diagonal[i,j] == 0 for i in range(64) for j in range(64) if i != j)
        assert all(p > 0 for p in pivots), (layer,head,group,numerator)
        assert cert.is_positive_definite()
        groups.append({
            'group': group, 'eigmin_fp64': eigmin, 'lambda_numerator': numerator,
            'diagonal': [int(gram[i,i]) for i in range(64)],
            'gram_upper': [int(gram[i,j]) for i in range(64) for j in range(i,64)],
            'ldlt_permutation': [[int(permutation[i,j]) for j in range(64)] for i in range(64)],
            'ldlt_positive_pivots': [str(x) for x in pivots],
            'source_zero_words': int(np.count_nonzero(bi == 0)),
        })
    output = {'layer':layer, 'head':head, 'source':rel, 'source_sha256':digest,
              'shape':[1024,64], 'gram_unit':'2^-70', 'lambda_denominator':4096,
              'numeric_rule':'one numpy FP64 eigvalsh per D-normalized exact Gram; floor(4096*eigmin)',
              'certificate':'exact rational block LDLT of 4096G - numerator*D; all pivots positive',
              'groups':groups}
    path = HERE / f'cert-{layer}-{head}.json.gz'
    with path.open('wb') as f:
        with gzip.GzipFile(filename='', mode='wb', fileobj=f, mtime=0, compresslevel=9) as z:
            z.write((json.dumps(output, separators=(',',':'))+'\n').encode())
    print(json.dumps({'layer':layer,'head':head,'lambda_numerators':[g['lambda_numerator'] for g in groups],
                      'zeros':[g['source_zero_words'] for g in groups], 'certificate_sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes':path.stat().st_size}))

if __name__ == '__main__':
    main(int(sys.argv[1]), int(sys.argv[2]))
