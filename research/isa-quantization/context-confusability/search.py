#!/usr/bin/env python3
"""Conditional-centroid oracle and context-conflict graph certificate.

Three source-specific context laws create a triangle of co-visibility despite
only two laws in each individual context. Exact rational logs bound all costs.
"""
import itertools
import json
import sys
from fractions import Fraction as F
from pathlib import Path
from time import perf_counter

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'categorical-tree'))
from search import add, scaled, log_interval, minimum, receipt


def entropy(p):
    return add(*(scaled(-x, log_interval(x)) for x in p if x))


class ConditionalCase:
    def __init__(self, occupancy, context_weights, laws, C):
        self.nu = tuple(F(x, sum(occupancy)) for x in occupancy)
        self.pi = tuple(tuple(F(x, sum(row)) for x in row) for row in context_weights)
        self.p = tuple(tuple(tuple(F(v, sum(law)) for v in law) for law in row)
                       for row in laws)
        self.n, self.C, self.T = len(occupancy), C, len(context_weights[0])
        assert all(len(row) == self.T for row in self.pi)

    def cluster(self, t, ss):
        weights=[self.nu[s]*self.pi[s][t] for s in ss]
        mass=sum(weights)
        if not mass:
            return F(0),F(0)
        q=[sum(w*self.p[s][t][y] for s,w in zip(ss,weights))/mass
           for y in range(len(self.p[0][0]))]
        return add(scaled(mass, entropy(q)),
                   *(scaled(-w,entropy(self.p[s][t])) for s,w in zip(ss,weights)))

    def assignments(self):
        # All unlabeled assignments with at most C labels; oracle only.
        def rec(prefix,used):
            if len(prefix)==self.n:
                yield prefix
                return
            for k in range(min(used+1,self.C)):
                yield from rec(prefix+(k,),max(used,k+1))
        return list(rec((0,),1))

    def context_cost(self,t,g):
        return add(*(self.cluster(t,[s for s in range(self.n) if g[s]==k])
                     for k in range(max(g)+1)))

    def oracle(self):
        assignments=self.assignments()
        return minimum([add(*(self.context_cost(t,g) for t in range(self.T)))
                        for g in assignments]),len(assignments)

    def independent_context(self):
        return add(*(minimum([self.context_cost(t,g) for g in self.assignments()])
                     for t in range(self.T)))

    def graph_edges(self):
        return [(i,j,t) for i in range(self.n) for j in range(i+1,self.n)
                for t in range(self.T) if self.nu[i]*self.pi[i][t]>0
                and self.nu[j]*self.pi[j][t]>0 and self.p[i][t]!=self.p[j][t]]

    def edge_cost(self,i,j,t):
        return self.cluster(t,[i,j])

    def joint_support_disjoint(self):
        # P_x(t,y)=pi_x(t)p_x,t(y); checks orthogonality of all sqrt(P_x).
        return all(self.pi[i][t]*self.p[i][t][y]*self.pi[j][t]*self.p[j][t][y]==0
                   for i in range(self.n) for j in range(i+1,self.n)
                   for t in range(self.T) for y in range(len(self.p[0][0])))

    def run(self,name):
        full,npart=self.oracle()
        edges=self.graph_edges()
        independent=self.independent_context()
        # For the explicit triangle, every two-coloring is monochromatic on
        # an edge, whose two source-context cells alone cost at least D_edge.
        triangle=(self.n==3 and self.C==2 and
                  all(any({i,j}==set(pair) for i,j,t in edges) for pair in ((0,1),(1,2),(0,2))))
        certificate=minimum([self.edge_cost(*e) for e in edges]) if triangle else (F(0),F(0))
        assert certificate[0] <= full[1]
        return {'case':name,'occupancy':[str(x) for x in self.nu],
                'context_weights':[[str(x) for x in row] for row in self.pi],
                'laws':[[[str(v) for v in law] for law in row] for row in self.p],
                'labels':self.C,'contexts':self.T,'complete_assignments':npart,
                'graph_edges':[{'sources':[i,j],'context':t,'weighted_JS':receipt(self.edge_cost(i,j,t))}
                               for i,j,t in edges],
                'independent_context_optimum':receipt(independent),
                'triangle_certificate':receipt(certificate),
                'complete_shared_label_optimum':receipt(full),
                'joint_laws_pairwise_disjoint_support':self.joint_support_disjoint()}


def triangle(delta):
    # Contexts 0,1,2 reveal each source uniquely. Contexts 3,4,5 have
    # source pairs 01,12,20 respectively, with opposite point-mass outputs.
    pi=[[F(0) for _ in range(6)] for _ in range(3)]
    laws=[[[1,0] for _ in range(6)] for _ in range(3)]
    for x in range(3):
        pi[x][x]=1-2*delta
    for t,(i,j) in enumerate(((0,1),(1,2),(2,0)),start=3):
        pi[i][t]=pi[j][t]=delta
        laws[i][t]=[1,0]
        laws[j][t]=[0,1]
    return ConditionalCase([1]*3,pi,laws,2)


def revealed():
    pi=[[int(i==t) for t in range(3)] for i in range(3)]
    p=[[[1,0] for _ in range(3)] for _ in range(3)]
    return ConditionalCase([1]*3,pi,p,1)


def main():
    start=perf_counter()
    tri=triangle(F(1,10)).run('source_dependent_triangle')
    reveal=revealed().run('context_reveals_source')
    assert tri['joint_laws_pairwise_disjoint_support']
    assert reveal['joint_laws_pairwise_disjoint_support']
    assert tri['independent_context_optimum']['interval']==['0','0']
    assert reveal['complete_shared_label_optimum']['interval']==['0','0']
    out={'cases':[tri,reveal], 'naive_joint_subspace':{
            'triangle':'log(3/2), because three disjoint joint supports give rho=I_3/3 and C=2',
            'revealed':'log(3), because three disjoint joint supports give rho=I_3/3 and C=1'},
         'arithmetic':'Rational probabilities and 24-term atanh-series rational log intervals from categorical-tree/search.py; float only in display.',
         'elapsed_seconds':perf_counter()-start}
    Path(__file__).with_name('results.json').write_text(json.dumps(out,indent=2)+'\n')
    for x in (tri,reveal):
        print(x['case'],'independent',x['independent_context_optimum']['decimal'][0],
              'graph',x['triangle_certificate']['decimal'][0],
              'exact',x['complete_shared_label_optimum']['decimal'][0])
    print('seconds',out['elapsed_seconds'])


if __name__=='__main__':
    main()
