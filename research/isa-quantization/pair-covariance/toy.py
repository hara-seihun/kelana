"""Exact four-coordinate counterexample to every diagonal-only pair certificate."""
from fractions import Fraction as Q
import json
from pathlib import Path

n=4
eps=Q(1,4)
h=[[Q(int(i==j))-(1-eps)/n for j in range(n)] for i in range(n)]
d=[eps]*n
# The pair-difference reader keeps x0-x1 and x2-x3. Its error map projects
# onto pair sums, including the global low-eigenvalue direction.
e=[[Q(1,2) if i//2==j//2 else Q(0) for j in range(n)] for i in range(n)]
actual=sum(e[i][a]*h[a][b]*e[i][b] for i in range(n) for a in range(n) for b in range(n))
assert actual==Q(5,4)
# For any candidate 4x4 response rank<=2, the spectral tail of H is
# epsilon+1. The explicit reader above attains it.
assert actual==eps+1
# For W=I and any positive diagonal minorant, an edge (i,j) with free ratio
# costs min(d_i,d_j). Uniform d=epsilon is PSD-feasible, yielding 2 epsilon.
cert=sum(d[:2]);assert cert==Q(1,2)
# The all-ones vector budget forces sum_i d_i <= 4 epsilon for every
# diagonal minorant. The minimum matching pairs the two smallest d's with
# the two largest, so no diagonal certificate can exceed 2 epsilon.
assert cert==2*eps
result=dict(epsilon=str(eps),h=[[str(z) for z in row] for row in h],
            attainable_full_covariance_error=str(actual),
            maximal_diagonal_matching_certificate=str(cert),
            exact_gap=str(actual-cert),
            required_positive_correction_rank=n-1)
Path(__file__).with_name('toy-results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
