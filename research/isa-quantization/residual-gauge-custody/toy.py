"""Exact rational tied-endpoint, nonlinear, residual-coordinate toy."""
import json
from fractions import Fraction as F
from itertools import product
from pathlib import Path

HERE=Path(__file__).resolve().parent
Z=F(0); ONE=F(1)
Q=[[F(3,5),F(4,5),Z,Z],[-F(4,5),F(3,5),Z,Z],
   [Z,Z,ONE,Z],[Z,Z,Z,ONE]]
IDENTITY=[[F(int(i==j)) for j in range(4)] for i in range(4)]


def trans(a):return list(map(list,zip(*a)))


def mat(a,b):
    return [[sum((a[i][k]*b[k][j] for k in range(len(b))),Z)
             for j in range(len(b[0]))] for i in range(len(a))]


def vec(a,x):return [sum((a[i][j]*x[j] for j in range(len(x))),Z) for i in range(len(a))]


def normalize(x):
    denominator=ONE+sum((t*t for t in x),Z)
    return [t/denominator for t in x]


def run(x,inc,out):
    y=vec(inc,normalize(x))
    branch=vec(out,[v*v for v in y])
    return [a+b for a,b in zip(x,branch)]


def count_nonzero(a):return sum(bool(v) for row in a for v in row)


def check():
    assert mat(Q,trans(Q))==IDENTITY
    embed=Q
    incoming=Q[:2]
    outgoing=[row[:2] for row in trans(Q)]
    embed_new=mat(embed,trans(Q))
    incoming_new=mat(incoming,trans(Q))
    outgoing_new=mat(Q,outgoing)
    assert embed_new==IDENTITY
    assert incoming_new==IDENTITY[:2]
    assert outgoing_new==[[ONE,Z],[Z,ONE],[Z,Z],[Z,Z]]
    original_count=sum(map(count_nonzero,(embed,incoming,outgoing)))
    rotated_count=sum(map(count_nonzero,(embed_new,incoming_new,outgoing_new)))
    assert original_count==14 and rotated_count==8
    legal_values={F(-4,5),F(3,5),F(4,5),ONE}
    assert all(v in legal_values for matrix in (embed,incoming,outgoing,
                  embed_new,incoming_new,outgoing_new) for row in matrix for v in row if v)
    checked=0
    for token in range(4):
        x=embed[token]
        z=embed_new[token]
        for steps in range(4):
            assert vec(embed,normalize(x))==vec(embed_new,normalize(z))
            assert z==vec(Q,x)
            x=run(x,incoming,outgoing)
            z=run(z,incoming_new,outgoing_new)
            checked+=1
    for x in product((F(-1),Z,ONE),repeat=4):
        assert vec(Q,run(x,incoming,outgoing))==run(vec(Q,x),incoming_new,outgoing_new)
        checked+=1
    result={'grammar':'three fixed-shape sparse matrices; one byte row, one byte column, one byte generic rational code per nonzero, one count byte per matrix',
            'generic_nonzero_rational_dictionary':[str(v) for v in sorted(legal_values)],
            'source_nonzeros':original_count,'transformed_nonzeros':rotated_count,
            'source_bytes':3*original_count+3,'transformed_bytes':3*rotated_count+3,
            'saved_bytes':3*(original_count-rotated_count),
            'runtime_rotation_bytes':0,'exact_inputs_replayed':checked,
            'normalizer':'x/(1+sum x_i^2), rational isotropic analogue of RMSNorm',
            'branch':'two nonlinear square units with shared input and one output projection'}
    (HERE/'toy-results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':check()
