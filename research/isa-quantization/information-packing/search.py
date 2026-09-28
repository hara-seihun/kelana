#!/usr/bin/env python3
"""Global and fractionally localized information-budget floors; exact KL oracle.

Only the LP proposal uses floating numbers. All source laws, hyperedge loads,
logarithm intervals, and accepted objectives use exact rational arithmetic.
"""
import itertools
import json
import math
import sys
from fractions import Fraction as F
from functools import cache
from pathlib import Path
from time import perf_counter

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'categorical-tree'))
from search import add, scaled, log_interval, minimum, receipt


def negative(v):
    return scaled(-1, v)


def entropy(p):
    return add(*(scaled(-x, log_interval(x)) for x in p if x))


class Witness:
    def __init__(self, rows, weights, capacity):
        self.p = tuple(tuple(F(x, sum(row)) for x in row) for row in rows)
        self.nu = tuple(F(w, sum(weights)) for w in weights)
        self.n, self.C = len(rows), capacity
        assert self.n > capacity > 0
        self.single_entropy = tuple(entropy(row) for row in self.p)
        self.all = (1 << self.n)-1

    def members(self, mask):
        return [s for s in range(self.n) if mask >> s & 1]

    @cache
    def cluster(self, mask):
        if not mask:
            return F(0),F(0)
        ss = self.members(mask)
        mass = sum(self.nu[s] for s in ss)
        q = [sum(self.nu[s]*self.p[s][y] for s in ss)/mass
             for y in range(len(self.p[0]))]
        # This is M H(pbar) - sum_s nu_s H(p_s), the exact centroid KL.
        return add(scaled(mass, entropy(q)),
                   *(scaled(-self.nu[s], self.single_entropy[s]) for s in ss))

    def label_entropy_cap(self, mask):
        if self.C == 1:
            return F(0), F(0)
        base = log_interval(F(self.C))
        ss = self.members(mask)
        mass = sum(self.nu[s] for s in ss)
        alpha = max(self.nu[s] for s in ss)/mass
        if alpha < F(1, self.C):
            return base
        heavy = add(entropy((alpha, 1-alpha)),
                    scaled(1-alpha, log_interval(F(self.C-1))))
        return (min(base[0], heavy[0]), min(base[1], heavy[1]))

    @cache
    def local(self, mask):
        mass = sum(self.nu[s] for s in self.members(mask))
        value = add(self.cluster(mask), scaled(-mass, self.label_entropy_cap(mask)))
        return max(F(0),value[0]), max(F(0),value[1])

    def oracle(self):
        def partitions(prefix, used):
            if len(prefix) == self.n:
                yield prefix
                return
            for k in range(min(used+1,self.C)):
                yield from partitions(prefix + (k,), max(used,k+1))
        terms=[]
        for g in partitions((0,),1):
            terms.append(add(*(self.cluster(sum(1 << s for s in range(self.n) if g[s]==k))
                               for k in range(max(g)+1))))
        return minimum(terms), len(terms)

    def fractional_lp(self, edges, floors):
        from scipy.optimize import linprog
        incidence=[[int(bool(mask >> s & 1)) for mask in edges] for s in range(self.n)]
        proposal=linprog([-float(x[0]) for x in floors], A_ub=incidence,
                         b_ub=[1]*self.n, bounds=(0,None), method='highs')
        assert proposal.success, proposal.message
        denominator=1<<32
        shares=[F(math.floor(max(0,x)*denominator),denominator) for x in proposal.x]
        loads=[sum((shares[j] for j,mask in enumerate(edges) if mask>>s&1),F(0))
               for s in range(self.n)]
        scale=max(F(1),*loads)
        shares=[x/scale for x in shares]
        loads=[x/scale for x in loads]
        assert all(0<=x<=1 for x in loads)
        accepted=add(*(scaled(shares[j],floors[j]) for j in range(len(edges)) if shares[j]))
        return {'bound': receipt(accepted), 'subset_count':len(edges),
                'loads':[str(x) for x in loads],
                'active':[{'sources':self.members(mask),'share':str(shares[j]),
                           'local_floor':receipt(floors[j])}
                          for j,mask in enumerate(edges) if shares[j]],
                'all_local_floors':[{'sources':self.members(mask),'floor':receipt(floors[j])}
                                    for j,mask in enumerate(edges)]}

    def run(self,name):
        edges=[mask for mask in range(1,self.all+1) if mask.bit_count()>=self.C+1]
        packed=self.fractional_lp(edges,[self.local(mask) for mask in edges])
        pair={mask:self.cluster(mask) for mask in range(1,self.all+1) if mask.bit_count()==2}
        pair_edges=[mask for mask in edges if mask.bit_count()==self.C+1]
        pair_packed=self.fractional_lp(pair_edges,
            [minimum([pair[sub] for sub in pair if sub&mask==sub]) for mask in pair_edges])
        oracle,count=self.oracle()
        assert F(packed['bound']['interval'][0]) <= oracle[1]
        assert F(pair_packed['bound']['interval'][0]) <= oracle[1]
        return {'case':name,'teacher_laws':[[str(v) for v in p] for p in self.p],
                'occupancy':[str(v) for v in self.nu], 'capacity':self.C,
                'full_information_floor':receipt(self.local(self.all)),
                'fractional_information_floor':packed, 'pair_only_floor':pair_packed,
                'oracle':receipt(oracle),'complete_unlabeled_assignments':count}


def main():
    start=perf_counter()
    rows=[
        Witness([[int(i==j) for j in range(4)] for i in range(4)],[1]*4,2).run('uniform_point_masses'),
        Witness([[int(i==j) for j in range(4)] for i in range(4)],[7,1,1,1],2).run('heavy_point_mass'),
        Witness([[int(i==j) for j in range(4)] for i in range(4)]+[[1]*4],
                [1,1,1,1,16],2).run('hidden_point_masses_in_uniform_background'),
        Witness([[a*b,a*(4-b),(4-a)*b,(4-a)*(4-b)]
                 for a in (1,3) for b in (1,3)],[1]*4,2).run('crossing_product'),
    ]
    for x in rows:
        print(x['case'],'global',x['full_information_floor']['decimal'][0],
              'packed',x['fractional_information_floor']['bound']['decimal'][0],
              'pair',x['pair_only_floor']['bound']['decimal'][0],
              'oracle',x['oracle']['decimal'][0])
    out={'cases':rows,'elapsed_seconds':perf_counter()-start,
         'arithmetic':'Rational log intervals, rational dyadic/rescaled LP shares, exact load checks. Floating LP solutions propose only; no float accepted as proof.'}
    Path(__file__).with_name('results.json').write_text(json.dumps(out,indent=2)+'\n')
    print('seconds',out['elapsed_seconds'])


if __name__=='__main__':
    main()
