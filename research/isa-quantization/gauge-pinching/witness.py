"""Exact all-diagonal-parameter two-dimensional pinching witness."""
from fractions import Fraction as F
import json
from pathlib import Path


def add(*ps):
    out = {}
    for p in ps:
        for term, c in p.items():
            out[term] = out.get(term, F(0)) + c
    return {t: c for t, c in out.items() if c}


def scale(p, c):
    return {t: v*c for t, v in p.items() if v*c}


def multiply(p, q):
    out = {}
    for (a,b), c in p.items():
        for (x,y), d in q.items():
            term = (a+x, b+y)
            out[term] = out.get(term, F(0)) + c*d
    return {t: c for t, c in out.items() if c}


def constant(c):
    return {(0,0): F(c)} if c else {}


def main():
    q = [[F(3,5), F(4,5)], [F(-4,5), F(3,5)]]
    assert all(sum(q[i][k]*q[j][k] for k in range(2)) == int(i==j)
               for i in range(2) for j in range(2))
    source = [F(1), F(2)]
    rotated = [[sum(q[i][k]*source[k]*q[j][k] for k in range(2))
                for j in range(2)] for i in range(2)]
    optimum = [rotated[0][0], rotated[1][1]]
    b = [[sum(q[k][i]*optimum[k]*q[k][j] for k in range(2))
          for j in range(2)] for i in range(2)]
    assert b == [[F(913,625), F(84,625)], [F(84,625), F(962,625)]]
    assert [sum(F(v)*q[i][j] for j,v in enumerate([3,4])) for i in range(2)] == [5,0]
    alpha, beta = {(1,0): F(1)}, {(0,1): F(1)}
    total = {}
    for i in range(2):
        for j in range(2):
            x = add(scale(alpha, q[0][i]*q[0][j]), scale(beta, q[1][i]*q[1][j]))
            err = add(constant(source[i] if i==j else 0), scale(x, -1))
            total = add(total, multiply(err, err))
    floor = F(2)*rotated[0][1]**2
    expected = constant(floor)
    for variable, target in [(alpha,optimum[0]),(beta,optimum[1])]:
        err = add(variable, constant(-target))
        expected = add(expected, multiply(err,err))
    assert total == expected
    assert floor == F(288,625)
    # Complete three-output observer in S/complement coordinates: E^T E=[[2,1],[1,2]].
    observed = {}
    error = [[add(constant(rotated[0][0]), scale(alpha,-1)), constant(rotated[0][1])],
             [constant(rotated[1][0]), add(constant(rotated[1][1]), scale(beta,-1))]]
    for row in [[1,0],[0,1],[1,1]]:
        for j in range(2):
            response = add(*(scale(error[i][j],row[i]) for i in range(2)))
            observed = add(observed,multiply(response,response))
    weighted_diagonal = [F(47,25),F(40,25)]
    weighted_floor = F(432,625)
    weighted_expected = constant(weighted_floor)
    for variable,target in zip([alpha,beta],weighted_diagonal):
        err = add(variable,constant(-target))
        weighted_expected = add(weighted_expected,scale(multiply(err,err),2))
    assert observed == weighted_expected
    result = {
        'arithmetic': 'exact rational polynomial in two free final diagonal gains',
        'optimal_rotated_diagonal': list(map(str,optimum)),
        'pinched_original_coordinates': [[str(v) for v in row] for row in b],
        'minimum_frobenius_squared': str(floor),
        'best_scalar_gain_frobenius_squared': str(F(1,2)),
        'all_parameter_identity_coefficients': {f'alpha^{a} beta^{b}':str(c) for (a,b),c in sorted(total.items())},
        'coordinate_slice': ['5','0'],
        'scalar_source_gain_has_zero_floor': True,
        'embedding_weighted_optimal_diagonal': list(map(str,weighted_diagonal)),
        'embedding_weighted_optimal_error': str(weighted_floor),
        'embedding_weighted_error_of_unweighted_pinching': str(F(576,625)),
        'embedding_weighted_all_parameter_identity': True,
        'paid_full_model_win': False,
    }
    (Path(__file__).resolve().parent/'witness.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()
