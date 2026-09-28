#!/usr/bin/env python3
"""Exact two-dimensional discriminator for conditional moment completion."""
from fractions import Fraction as F
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def energy(matrix, error):
    return sum(error[i] * matrix[i][j] * error[j] for i in range(2) for j in range(2))


def main():
    h = F(4)
    prior = [[F(1), F(4, 5)], [F(4, 5), F(1)]]
    b = prior[1][0] / prior[0][0]
    schur = prior[1][1] - b * prior[0][1]
    completed = [[h, h*b], [h*b, schur+h*b*b]]
    assert completed == [[F(4), F(16, 5)], [F(16, 5), F(73, 25)]]
    assert schur > 0 and completed[0][0]*completed[1][1]-completed[0][1]**2 == F(36, 25)
    errors = {'A': (F(0), F(1, 5)), 'B': (F(1, 10), F(-1, 5))}
    metrics = {
        'calibration': [[h, F(0)], [F(0), F(0)]],
        'independent_fill': [[h, F(0)], [F(0), F(1)]],
        'conditional_completion': completed,
        'reference': prior,
        'opposite_reference': [[F(1), F(-4, 5)], [F(-4, 5), F(1)]],
    }
    expected = {
        'calibration': (F(0), F(1, 25)),
        'independent_fill': (F(1, 25), F(2, 25)),
        'conditional_completion': (F(73, 625), F(18, 625)),
        'reference': (F(1, 25), F(9, 500)),
        'opposite_reference': (F(1, 25), F(41, 500)),
    }
    rows = {}
    for name, metric in metrics.items():
        values = {key: energy(metric, error) for key, error in errors.items()}
        assert tuple(values.values()) == expected[name]
        rows[name] = {'matrix': [[str(x) for x in row] for row in metric],
                      'energies': {key: str(value) for key, value in values.items()},
                      'minimum_choice': min(values, key=values.get)}
    for error in errors.values():
        r, n = error
        assert energy(completed, error) == h*(r+b*n)**2 + schur*n*n
    result = {'arithmetic': 'exact rational', 'prior_conditional_slope': str(b),
              'prior_schur_complement': str(schur),
              'errors': {key: [str(x) for x in value] for key, value in errors.items()},
              'metrics': rows, 'trained_model_claim': False}
    (HERE/'results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
