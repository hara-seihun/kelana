#!/usr/bin/env python3
"""Emit exact FP16 rows for the finite seed-0 SiLU teacher and a live quadratic consumer."""
import json
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'instruction-cells'))
from search import X, affine_partitions, teacher

T = np.array([-1.0, -0.25, 0.5, 1.25])
B = np.stack((np.ones_like(T), T, T*T), axis=1)
Y, parameters = teacher(0)

def fit(q):
    q = np.asarray(q)
    rows = np.zeros((int(max(q)) + 1, 4), dtype=np.float16)
    for c in range(len(rows)):
        rows[c, :3] = Y[q == c].mean(axis=0).astype(np.float16)
    prediction = rows[q, :3].astype(np.float64) @ B.T
    target = Y @ B.T
    return float(np.sum((prediction-target)**2)), rows

square_q = (X*X)>>7
square_sse, square = fit(square_q)
best = min(((fit(q)[0], q, spec) for q, spec in affine_partitions().items()), key=lambda item:item[0])
affine_sse, affine = fit(best[1])
uniform_sse, uniform = fit(X>>2)
direct_sse, direct = fit(X)
energy = float(np.sum(((Y-Y.mean(axis=0)) @ B.T)**2))

with (HERE/'tables.h').open('w') as f:
    f.write('#pragma once\n#include <cstdint>\n')
    for name, table in [('square',square),('affine',affine),('uniform',uniform),('direct',direct)]:
        bits = table.view(np.uint16).reshape(-1)
        f.write(f'static constexpr uint16_t {name}_bits[{len(bits)}] = {{')
        f.write(','.join(str(int(x)) for x in bits))
        f.write('};\n')
receipt = dict(seed=0, teacher=parameters, t=T.tolist(), basis=['1','t','t*t'],
               centered_energy=energy, square_sse=square_sse, affine_sse=affine_sse,
               uniform_sse=uniform_sse, direct_sse=direct_sse,
               affine_program=dict(a=best[2][0],b=best[2][1],s=best[2][2]),
               square_cuts=np.flatnonzero(np.diff(square_q)).astype(int).tolist(),
               relative_rms={name: float(np.sqrt(sse/energy)) for name,sse in
                             [('square',square_sse),('affine',affine_sse),('uniform',uniform_sse),('direct',direct_sse)]})
(HERE/'structural.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:receipt[k] for k in ['relative_rms','affine_program']}))
