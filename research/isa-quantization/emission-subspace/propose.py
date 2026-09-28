#!/usr/bin/env python3
"""Spectral proposal only; verify.py accepts its rational matrix certificate."""
import json
from fractions import Fraction as F
from pathlib import Path
import numpy as np
from verify import source_cases, digest

BITS = 40
SCALE = 1 << BITS


def factor_density(rho, capacity):
    values, vectors = np.linalg.eigh(rho)
    t = int(round(max(0, values[-capacity])*SCALE))
    difference = values-t/SCALE
    plus = vectors*np.sqrt(np.maximum(difference, 0))[None, :]
    minus = vectors*np.sqrt(np.maximum(-difference, 0))[None, :]
    return {'scale_bits': BITS, 'offset': t,
            'positive_factor': np.rint(plus*SCALE).astype(np.int64).tolist(),
            'negative_factor': np.rint(minus*SCALE).astype(np.int64).tolist()}


def main():
    proposals = {}
    for name, case in source_cases().items():
        p = np.array([[float(F(x)) for x in row] for row in case['teacher_laws']])
        nu = np.array([float(F(x)) for x in case['occupancy']])
        a = np.sqrt(p)*np.sqrt(nu[:, None])
        rho = a.T@a
        proposals[name] = {'source_sha256': digest(case),
                           **factor_density(rho, case['candidate_state_budget'])}
    Path(__file__).with_name('certificates.json').write_text(json.dumps(proposals, indent=2)+'\n')


if __name__ == '__main__':
    main()
