"""Exact finite teacher, paid probability readers, and rational-log bound."""
from fractions import Fraction as F
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('causal_capacity', HERE.parent/'causal-state-capacity/certificate.py')
capacity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capacity)
log_interval = capacity.log_interval
PROBS = [F(1,3), F(1,2), F(7,12), F(2,3)]


def pack(shared, codes):
    word = int(shared)
    for i,c in enumerate(codes):
        assert 0 <= c < 4
        word |= c << (1+2*i)
    return word.to_bytes((1+2*len(codes)+7)//8, 'little')


def decode(data, table):
    assert len(table) == 8
    probabilities = [F(table[i],table[i+1]) for i in range(0,8,2)]
    assert all(0 < p < 1 for p in probabilities)
    word = int.from_bytes(data, 'little')
    shared = word & 1
    count = 3 if shared else 6
    assert len(data) == (1+2*count+7)//8 and word >> (1+2*count) == 0
    codes = [(word >> (1+2*i)) & 3 for i in range(count)]
    values = [probabilities[c] for c in codes]
    return [values[:3],values[:3]] if shared else [values[:3],values[3:]]


def kl_interval(p,q):
    return tuple(p*log_interval(p/q)[i]+(1-p)*log_interval((1-p)/(1-q))[i] for i in (0,1))


def mean_kl(p,q):
    return tuple(sum((kl_interval(a,b)[side] for row,other in zip(p,q)
                      for a,b in zip(row,other)),F(0))/6 for side in (0,1))


def describe(interval):
    return {'rational':list(map(str,interval)), 'decimal':list(map(float,interval))}


def main():
    coefficients = [[1,0,-1],[0,1,-1]]
    assert all(sum(row)==0 for row in coefficients)
    gram = [[sum(a*b for a,b in zip(x,y)) for y in coefficients] for x in coefficients]
    assert gram == [[2,1],[1,2]]
    for vec,eigenvalue in [([1,1],3),([1,-1],1)]:
        assert [sum(a*b for a,b in zip(row,vec)) for row in gram] == [eigenvalue*x for x in vec]
    # L=log(2)*coefficients has exact rank-one tail norm log(2).
    log2 = log_interval(F(2))
    lower = tuple((value-F(1,2))/27 for value in log2)
    assert lower[0] > 0
    payloads = {'direct.bin':pack(False,[3,1,0,1,3,0]),
                'shared-key.bin':pack(True,[2,2,0])}
    for name,data in payloads.items():
        (HERE/name).write_bytes(data)
    generic = bytes(v for p in PROBS for v in (p.numerator,p.denominator))
    (HERE/'probability-table.bin').write_bytes(generic)
    teacher = decode(payloads['direct.bin'],generic)
    shared = decode(payloads['shared-key.bin'],generic)
    achieved = mean_kl(teacher,shared)
    assert achieved[0] > lower[1]
    assert mean_kl(teacher,teacher) == (0,0)
    result = {
        'domain': 'two current-query labels by three prior-key labels; actual length-two prior/self probability',
        'centered_logodds_coefficient_gram':gram,
        'exact_rank_one_tail_norm':'log(2)',
        'minimum_teacher_bernoulli_variance':'2/9',
        'universal_rank_one_mean_kl_floor':describe(lower),
        'query_shared_mean_kl':describe(achieved),
        'universal_bound_requires_candidate_logit_cap':False,
        'optimized_rank_one_optimum_claimed':False,
        'generic_probability_table_bytes':len(generic),
        'images':{name:{'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
                        'standalone_with_generic_table_bytes':len(data)+len(generic)}
                  for name,data in payloads.items()},
        'native_or_model_claim':False,
    }
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()
