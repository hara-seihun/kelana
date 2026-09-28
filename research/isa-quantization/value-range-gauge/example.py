"""Exact rational counterexample: a smaller envelope need not improve code error."""
from fractions import Fraction as Q
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent

def quantize(v):
    low, high=min(v),max(v)
    if low==high:return list(v)
    step=(high-low)/3
    levels=[low+k*step for k in range(4)]
    return [min(enumerate(levels),key=lambda z:(abs(z[1]-x),z[0]%2,z[0]))[1] for x in v]

def dot(a,b):return sum(x*y for x,y in zip(a,b))
def text(q):return f'{q.numerator}/{q.denominator}'

source=[list(map(Q,row)) for row in ((4,1,4),(0,1,3))]
M=[max(abs(v[d]) for v in source) for d in range(3)]
scale=list(map(Q,(1,4,1)))
O=list(map(Q,(0,1,1)))
folded_O=[x/s for x,s in zip(O,scale)]
rows=[]
for v in source:
    folded=[x*s for x,s in zip(v,scale)]
    teacher=dot(O,v)
    assert dot(folded_O,folded)==teacher
    original=dot(O,quantize(v))
    changed=dot(folded_O,quantize(folded))
    rows.append({'teacher':text(teacher),'original':text(original),'folded':text(changed),
                 'original_sse':text((original-teacher)**2),'folded_sse':text((changed-teacher)**2)})
H=max(M)
Hnew=max(x*s for x,s in zip(M,scale))
assert H==Hnew==4
original_bound=sum(abs(x)*H/3 for x in O)**2
folded_bound=sum(abs(x)*Hnew/(3*s) for x,s in zip(O,scale))**2
assert original_bound==Q(64,9) and folded_bound==Q(25,9)
assert sum(Q(row['original_sse']) for row in rows)==0
assert sum(Q(row['folded_sse']) for row in rows)==Q(1,9)
result={'source':[[text(x) for x in v] for v in source],'scale':[text(x) for x in scale],
        'rows':rows,'original_per_token_robust_sse':text(original_bound),'folded_per_token_robust_sse':text(folded_bound),
        'statement':'Strictly smaller robust box risk, strictly worse realized minmax error; no packed-format or native claim'}
(HERE/'example.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
