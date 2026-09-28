#!/usr/bin/env python3
"""Exact rational paid readers and interval-certified live-value transfer."""
from fractions import Fraction as Q
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from itertools import permutations
import hashlib
import json

HERE = Path(__file__).resolve().parent
spec = spec_from_file_location('capacity_certificate', HERE.parent/'causal-state-capacity'/'certificate.py')
capacity = module_from_spec(spec)
spec.loader.exec_module(capacity)
log = lambda x: capacity.log_interval(x, terms=64)


def add(a,b):
    return a[0]+b[0], a[1]+b[1]


def neg(a):
    return -a[1],-a[0]


def mul(a,b):
    values = [x*y for x in a for y in b]
    return min(values),max(values)


def times(q,a):
    return mul((q,q),a)


def kl(p,q):
    return add(times(p,log(p/q)),times(1-p,log((1-p)/(1-q))))


def display(a):
    unit=10**9
    outer=(Q((a[0]*unit).numerator//(a[0]*unit).denominator,unit),
           Q(-((-a[1]*unit).numerator//(-a[1]*unit).denominator),unit))
    assert outer[0]<=a[0]<=a[1]<=outer[1]
    return {'rational_outer': [str(x) for x in outer], 'decimal_outer':[float(x) for x in outer]}


def serialize(pairs):
    return bytes(z for p in pairs for z in (p.numerator,p.denominator))


def decode(data,count):
    assert len(data)==2*count
    result = [Q(data[2*i],data[2*i+1]) for i in range(count)]
    assert all(0<p<=1 for p in result)
    return result


def det3(A):
    total=(Q(0),Q(0))
    for perm in permutations(range(3)):
        inversions=sum(perm[i]>perm[j] for i in range(3) for j in range(i+1,3))
        term=(Q(1),Q(1))
        for i,j in enumerate(perm):
            term=mul(term,A[i][j])
        total=add(total,neg(term) if inversions%2 else term)
    return total


def main():
    q=(Q(1,10),Q(2,5),Q(4,5))
    c=(Q(1,8),Q(1,2),Q(3,4),Q(1))
    teacher=tuple(tuple(a*b for b in c) for a in q)
    assert all(0<p<1 for row in teacher for p in row)
    # Direct score/probability table: 12 rational probabilities; teacher prior V=1.
    direct=serialize([p for row in teacher for p in row])
    # Rank-zero row odds: three q values; separate four-key live value carrier c.
    quotient=serialize(q+c)
    (HERE/'direct.bin').write_bytes(direct)
    (HERE/'value-transfer.bin').write_bytes(quotient)
    teacher_read=decode(direct,12)
    rows=[teacher_read[4*i:4*i+4] for i in range(3)]
    decoded=decode(quotient,7)
    candidate_q,candidate_values=decoded[:3],decoded[3:]
    assert rows==list(map(list,teacher))
    assert rows==[[candidate_q[i]*candidate_values[j] for j in range(4)] for i in range(3)]
    assert all(v>0 for v in candidate_values)
    mean_kl=(Q(0),Q(0))
    for i,row in enumerate(rows):
        for p in row:
            mean_kl=add(mean_kl,kl(p,candidate_q[i]))
    mean_kl=times(Q(1,12),mean_kl)
    assert mean_kl[0]>Q(18,100) and mean_kl[1]<Q(181,1000)
    # A row shift makes the fourth column zero; nonzero determinant proves rank 3.
    odds=lambda p:p/(1-p)
    D=[[log(odds(row[j])/odds(row[3])) for j in range(3)] for row in rows]
    determinant=det3(D)
    assert determinant[1]<-Q(1,100) and determinant[0]>-Q(2,100)
    def image(data):
        return {'payload_bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    result={
        'histories':'3 current labels × 4 prior labels, every [y,x] reachable; current V=0',
        'teacher_probability_rows':[[str(p) for p in row] for row in rows],
        'teacher_prior_values':['1']*4,
        'rank_zero_candidate_query_probabilities':[str(p) for p in candidate_q],
        'candidate_prior_values':[str(v) for v in candidate_values],
        'live_output_equality':'teacher p_xy * 1 = candidate q_x * candidate prior value c_y, all 12 cells',
        'all_value_gaps_positive':True,
        'teacher_centered_logodds_3x3_minor_interval':display(determinant),
        'teacher_centered_logodds_rank':3,
        'candidate_centered_logodds_rank':0,
        'mean_attention_KL_interval':display(mean_kl),
        'mean_post_value_output_squared_error':'0',
        'paid_images':{'full_probability_direct':image(direct),'rank_zero_value_transfer':image(quotient),
                       'strong_direct_output_factorization':image(quotient)},
        'reader_contract':'two-byte numerator/denominator per rational; fixed shape and dispatch common program; candidate and direct-output factorization do one multiplication per history, direct table one indexed probability read; no native timing claim',
        'arithmetic':'64-term exact rational atanh logarithms with geometric tails; interval determinant and KL; integer byte decoding',
    }
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'centered_minor':display(determinant),'attention_KL':display(mean_kl),
                      'payload_bytes':{'direct':len(direct),'value_transfer':len(quotient)},
                      'output_error':0},indent=2))


if __name__=='__main__':
    main()
