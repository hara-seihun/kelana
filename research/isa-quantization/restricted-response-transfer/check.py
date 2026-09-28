"""Exact rational certificate for the finite-dimensional response-transfer toy."""
import json
from fractions import Fraction as Q
from itertools import combinations
from pathlib import Path

HERE=Path(__file__).resolve().parent


def product(a,b):
    return [[sum((a[i][k]*b[k][j] for k in range(len(b))),Q(0))
             for j in range(len(b[0]))] for i in range(len(a))]


def transpose(a): return list(map(list,zip(*a)))


def inverse(a):
    n=len(a)
    rows=[[Q(x) for x in a[i]]+[Q(int(i==j)) for j in range(n)] for i in range(n)]
    for j in range(n):
        pivot=next((i for i in range(j,n) if rows[i][j]),None)
        assert pivot is not None
        rows[j],rows[pivot]=rows[pivot],rows[j]
        multiplier=rows[j][j]
        rows[j]=[x/multiplier for x in rows[j]]
        for i in range(n):
            if i!=j:
                multiplier=rows[i][j]
                rows[i]=[x-multiplier*y for x,y in zip(rows[i],rows[j])]
    return [row[n:] for row in rows]


def det(a):
    if len(a)==1: return a[0][0]
    return sum(((-1)**j*a[0][j]*det([row[:j]+row[j+1:] for row in a[1:]])
                for j in range(len(a))),Q(0))


def all_principal_nonnegative(a):
    return all(det([[a[i][j] for j in indices] for i in indices])>=0
               for size in range(1,len(a)+1)
               for indices in combinations(range(len(a)),size))


def rank(a):
    if not a or not a[0]: return 0
    x=[list(row) for row in a]
    r=0
    for j in range(len(x[0])):
        pivot=next((i for i in range(r,len(x)) if x[i][j]),None)
        if pivot is None: continue
        x[r],x[pivot]=x[pivot],x[r]
        scale=x[r][j]
        x[r]=[v/scale for v in x[r]]
        for i in range(r+1,len(x)):
            scale=x[i][j]
            x[i]=[v-scale*w for v,w in zip(x[i],x[r])]
        r+=1
        if r==len(x): break
    return r


def transfer_certificate(c,h,b):
    """Rational bound on span(B), or an exact coefficient vector blind to C.

    Columns of B must be linearly independent. No full ambient rank is needed.
    The all-zero calibration case is handled separately.
    """
    assert rank(b)==len(b[0])
    cb=product(c,b); hb=product(h,b)
    pivots=[]
    for j in range(len(cb[0])):
        cols=pivots+[j]
        if rank([[row[i] for i in cols] for row in cb])>len(pivots): pivots.append(j)
    if not pivots:
        return {'blind':next(([Q(int(i==j)) for i in range(len(cb[0]))]
                              for j in range(len(cb[0])) if any(row[j] for row in hb)),None),
                'factor':Q(0) if not any(any(row) for row in hb) else None}
    cj=[[row[i] for i in pivots] for row in cb]
    hj=[[row[i] for i in pivots] for row in hb]
    gc=product(transpose(cj),cj)
    gi=inverse(gc)
    for j in range(len(cb[0])):
        column=[[row[j]] for row in cb]
        rhs=product(transpose(cj),column)
        alpha=[row[0] for row in product(gi,rhs)]
        assert product(cj,[[v] for v in alpha])==column
        predicted=product(hj,[[v] for v in alpha])
        if any(hb[i][j]!=predicted[i][0] for i in range(len(hb))):
            blind=[Q(int(k==j)) for k in range(len(cb[0]))]
            for k,i in enumerate(pivots): blind[i]-=alpha[k]
            assert all(row[0]==0 for row in product(cb,[[v] for v in blind]))
            assert any(row[0]!=0 for row in product(hb,[[v] for v in blind]))
            return {'blind':blind,'factor':None}
    gh=product(transpose(hj),hj)
    decoder=product(product(hj,gi),transpose(cj))
    assert product(decoder,cb)==hb
    factor=sum((entry*entry for row in decoder for entry in row),Q(0))
    assert factor==sum((product(gi,gh)[i][i] for i in range(len(pivots))),Q(0))
    return {'blind':None,'factor':factor,'pivots':pivots,'gc':gc,'gh':gh,
            'decoder':decoder}


def check():
    # V=Q^3. C(x,y,z)=(x,z); H(x,y,z)=(x+y,2z).
    c=[[Q(1),Q(0),Q(0)],[Q(0),Q(0),Q(1)]]
    h=[[Q(1),Q(1),Q(0)],[Q(0),Q(0),Q(2)]]
    # Legal error subspace has basis (1,1,0),(0,0,1).
    b=[[Q(1),Q(0)],[Q(1),Q(0)],[Q(0),Q(1)]]
    cert=transfer_certificate(c,h,b)
    assert cert['blind'] is None and cert['pivots']==[0,1]
    gc=cert['gc']; gh=cert['gh']; lam=cert['factor']
    assert lam==8 and cert['decoder']==[[Q(2),Q(0)],[Q(0),Q(2)]]
    ambient=transfer_certificate(c,h,[[Q(int(i==j)) for j in range(3)] for i in range(3)])
    assert ambient['factor'] is None and ambient['blind'] is not None
    assert ambient['blind']==[Q(0),Q(1),Q(0)]
    # A rank-deficient calibration map can also annihilate the entire legal
    # space; if held annihilates it too the bound is zero.
    zero=transfer_certificate([[Q(0),Q(0)]],[[Q(0),Q(0)]],
                              [[Q(1),Q(0)],[Q(0),Q(1)]])
    assert zero['factor']==0 and zero['blind'] is None
    shared_kernel=transfer_certificate([[Q(1),Q(0)]],[[Q(2),Q(0)]],
                                       [[Q(1),Q(0)],[Q(0),Q(1)]])
    assert shared_kernel['factor']==4 and shared_kernel['blind'] is None
    # The trace recipe is constructive and universal. A separately checked
    # smaller coefficient is sharp on this example.
    optimal=Q(4)
    gap=[[optimal*gc[i][j]-gh[i][j] for j in range(2)] for i in range(2)]
    assert all_principal_nonnegative(gap) and gap==[[Q(0),Q(0)],[Q(0),Q(0)]]
    blind=[Q(0),Q(1),Q(0)]
    assert product(c,[[x] for x in blind])==[[Q(0)],[Q(0)]]
    assert product(h,[[x] for x in blind])==[[Q(1)],[Q(0)]]
    # Each nonlinear branch intersects ker C only at 0. One has unbounded
    # held/calibration ratio, the other remains bounded by the sharp 4.
    for n in (1,2,4,8,16):
        t=Q(1,n)
        escaping=[t*t,t,Q(0)]; controlled=[t,t*t,Q(0)]
        def energy(map_,v):
            response=product(map_,[[x] for x in v])
            return sum((row[0]**2 for row in response),Q(0))
        assert energy(c,escaping)>0
        assert energy(h,escaping)/energy(c,escaping)==(n+1)**2
        assert energy(h,controlled)/energy(c,controlled)==(1+t)**2<=4
    receipt={'calibration':[[int(x) for x in row] for row in c],
             'held':[[int(x) for x in row] for row in h],
             'legal_basis':[[int(x) for x in row] for row in b],
             'calibration_gram':[[int(x) for x in row] for row in gc],
             'held_gram':[[int(x) for x in row] for row in gh],
             'constructive_trace_bound':str(lam),'sharp_psd_bound':str(optimal),
             'ambient_calibration_rank':2,'legal_subspace_rank':2,
             'ambient_blind_held_energy':1,
             'escaping_n16_ratio':289,'controlled_max_ratio':4}
    (HERE/'verified.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))

if __name__=='__main__':check()
