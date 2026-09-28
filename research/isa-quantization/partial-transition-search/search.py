#!/usr/bin/env python3
"""Reachability-label envelopes versus Bellman on the existing paid grammar."""
import importlib.util
import itertools
import json
from fractions import Fraction as F
from pathlib import Path
from time import perf_counter

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('transition_owner', HERE.parent/'transition-envelopes/search.py')
owner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(owner)
P, T, H, Q = owner.P, owner.T, owner.H, owner.Q
C, A, S = range(2), range(2), range(3)
QN = tuple(itertools.product(range(3),repeat=2))
PN = tuple(tuple(int(x*4) for x in row) for row in P)
SCALE = (1<<80)*25
DEN = SCALE*4**(H-1)
CELL = tuple(tuple((int(owner.kl_interval(s,q)[0]*SCALE),
                   -int(-owner.kl_interval(s,q)[1]*SCALE//1)) for q in Q) for s in S)


def occupancy(partial, method):
    current = {(0,1): 1}
    total = [[0]*4 for _ in S]
    for t in range(H):
        nxt = {}
        for (s,mask), count in current.items():
            total[s][mask] += count*4**(H-1-t)
            for a in A:
                targets = 0
                for c in C:
                    if mask & (1<<c):
                        dest = partial[2*c+a]
                        targets |= (3 if method == 'reach' else 0) if dest is None else 1<<dest
                if targets:
                    key = (T[s][a],targets)
                    nxt[key] = nxt.get(key,0)+count*PN[s][a]
        current = nxt
    return total


def label_value(occ,q,side=0):
    return sum(occ[s][mask]*min(CELL[s][q[c]][side] for c in C if mask&(1<<c))
               for s in S for mask in range(1,4) if occ[s][mask])


def bellman(partial,q):
    v = [[0]*2 for _ in S]
    for h in range(1,H+1):
        nxt = [[0]*2 for _ in S]
        for s in S:
            for c in C:
                value = CELL[s][q[c]][0]*4**(h-1)
                for a in A:
                    dest = partial[2*c+a]
                    value += PN[s][a]*(min(v[T[s][a]]) if dest is None else v[T[s][a]][dest])
                nxt[s][c] = value
        v = nxt
    return v[0][0]


def emission_bits(q):
    return 1 if q == (1,1) else 5


def transition_bits(u):
    return owner.transition_bits(u)


def feasible_q(partial,budget):
    return tuple(q for q in QN if transition_bits(partial)+emission_bits(q)<=budget)


def lower(partial,price,budget,method):
    choices = feasible_q(partial,budget)
    occ = None if method == 'bellman' else occupancy(partial,method)
    return min(((bellman(partial,q) if occ is None else label_value(occ,q)) +
                price*(transition_bits(partial)+emission_bits(q)) for q in choices), default=None)


def order(program):
    score,u,q = program[:3]
    return score,transition_bits(u)+emission_bits(q),u,q


def full(u,price,budget):
    occ = occupancy(u,'reach')
    return min(((label_value(occ,q,1)+price*(transition_bits(u)+emission_bits(q)),u,q)
               for q in feasible_q(u,budget)),key=order)


def serialize(u,q):
    bits = []
    def put(x,n):
        bits.extend((x>>i)&1 for i in range(n))
    if u == (0,0,1,1):
        put(0,1)
    else:
        put(1,1)
        for x in u:
            put(x,1)
    if q == (1,1):
        put(0,1)
    else:
        put(1,1)
        for x in q:
            put(x,2)
    n = len(bits)
    data = sum(x<<i for i,x in enumerate(bits)).to_bytes((n+7)//8,'little')
    return {'hex': data.hex(), 'logical_bits': n, 'physical_bytes': len(data)}


def independent_replay(image):
    data = bytes.fromhex(image['hex'])
    word = int.from_bytes(data,'little')
    cursor = 0
    def take(n):
        nonlocal cursor
        value = (word>>cursor)&((1<<n)-1)
        cursor += n
        return value
    u = tuple(take(1) for _ in range(4)) if take(1) else (0,0,1,1)
    q = tuple(take(2) for _ in range(2)) if take(1) else (1,1)
    assert all(x<3 for x in q)
    assert cursor == image['logical_bits'] and word>>cursor == 0
    assert len(data) == (cursor+7)//8
    loss = [0,0]
    signature = []
    for t in range(H):
        for history in itertools.product(A,repeat=t):
            s,c,prob = 0,0,1
            for a in history:
                prob *= PN[s][a]
                s,c = T[s][a],u[2*c+a]
            signature.append(q[c])
            for side in (0,1):
                loss[side] += prob*4**(H-1-t)*CELL[s][q[c]][side]
    return u,q,tuple(loss),tuple(signature)


def explore(lam,budget,method):
    price = int(lam*DEN)
    assert F(price,DEN) == lam
    seeds = ((0,0,1,1),(0,1,0,1),(0,0,0,0))
    best = min((full(u,price,budget) for u in seeds if feasible_q(u,budget)),key=order)
    initial = best
    counts = {'nodes':0,'pruned':0,'completed_leaves':0,'label_bound_calls':0,
              'bellman_bound_calls':0,'screen_prunes':0}
    witnesses = []
    start = perf_counter()
    def visit(prefix):
        nonlocal best
        counts['nodes'] += 1
        partial = prefix+(None,)*(4-len(prefix))
        selected = 'reach' if method == 'screen_then_bellman' else method
        counts['bellman_bound_calls' if selected == 'bellman' else 'label_bound_calls'] += 1
        bound = lower(partial,price,budget,selected)
        if bound is not None and bound<=best[0] and method == 'screen_then_bellman':
            counts['bellman_bound_calls'] += 1
            bound = lower(partial,price,budget,'bellman')
        elif method == 'screen_then_bellman' and bound is not None and bound>best[0]:
            counts['screen_prunes'] += 1
        if bound is None or bound>best[0]:
            counts['pruned'] += 1
            if len(prefix)<4:
                witnesses.append({'prefix':prefix,'lower_nats':None if bound is None else float(F(bound,DEN)),
                                  'incumbent_upper_nats':float(F(best[0],DEN))})
            return
        if len(prefix)==4:
            counts['completed_leaves'] += 1
            best = min(best,full(prefix,price,budget),key=order)
            return
        for x in C:
            visit(prefix+(x,))
    visit(())
    elapsed = perf_counter()-start
    image = serialize(best[1],best[2])
    u,q,loss,_ = independent_replay(image)
    assert u == best[1] and q == best[2]
    assert loss[1]+price*image['logical_bits'] == best[0]
    return {'lambda':str(lam),'budget_bits':budget,'method':method,'counts':counts,
            'seconds':elapsed,'optimum_upper':str(F(best[0],DEN)),
            'optimum_decimal':float(F(best[0],DEN)),'transition':u,'emission_indices':q,
            'KL_interval':[str(F(x,DEN)) for x in loss],'image':image,
            'initial_upper':str(F(initial[0],DEN)),'prune_witnesses':witnesses}


def accept(rows):
    # Independent complete byte-program replay runs after every pruned search.
    winners = {}
    same_observation_ties = {}
    for row in rows:
        key = (row['lambda'],row['budget_bits'])
        if key not in winners:
            lam,budget = F(key[0]),key[1]
            programs = []
            for u in itertools.product(C,repeat=4):
                for q in feasible_q(u,budget):
                    image = serialize(u,q)
                    ru,rq,loss,signature = independent_replay(image)
                    assert (ru,rq)==(u,q)
                    programs.append((F(loss[1],DEN)+lam*image['logical_bits'],u,q,
                                     F(loss[0],DEN)+lam*image['logical_bits'],signature))
            best = min(programs,key=order)
            tied = [p for p in programs if p[3]<=best[0]]
            assert all(p[4]==best[4] and p[0]==best[0] for p in tied)
            same_observation_ties[str(key)] = len(tied)
            winners[key] = best
        best = winners[key]
        assert F(row['optimum_upper'])==best[0]
        assert (tuple(row['transition']),tuple(row['emission_indices']))==best[1:3]
    # Check the general envelope ordering at all 3^4 partial tables, not just prefixes.
    for partial in itertools.product((None,0,1),repeat=4):
        forced,reach = occupancy(partial,'forced'),occupancy(partial,'reach')
        assert sum(map(sum,reach)) == H*4**(H-1)
        for q in QN:
            assert label_value(forced,q)<=label_value(reach,q)<=bellman(partial,q)
    return {'complete_transition_tables_per_budget':16,'partial_tables_order_checked':81,
            'emission_assignments_per_partial':9,'all_different_observed_maps_strictly_separated':True,
            'same_observation_ties':same_observation_ties,
            'tie_order':'objective upper, logical bits, transition tuple, emission tuple'}


def main():
    rows = [explore(lam,budget,method) for lam,budget in
            ((F(0),2),(F(0),6),(F(0),10),(F(3,200),10),(F(1,25),10),(F(3,200),6))
            for method in ('forced','reach','bellman','screen_then_bellman')]
    acceptance = accept(rows)
    witnesses = []
    for partial in ((None,)*4,(1,0,None,None),(0,None,0,None)):
        witnesses.append({'partial':partial,'lambda':'0','budget_bits':10,
                          'bound_intervals_lower':{method:str(F(lower(partial,0,10,method),DEN))
                           for method in ('forced','reach','bellman')}})
    frontier = []
    for row in rows:
        if row['lambda'] == '0' and row['method'] == 'reach':
            if not frontier or F(row['KL_interval'][1]) < F(frontier[-1]['KL_interval'][0]):
                frontier.append({key:row[key] for key in ('image','transition','emission_indices','KL_interval')})
    result = {'owning_grammar':'../transition-envelopes/README.md','integer_interval_scale':str(SCALE),
              'common_denominator':str(DEN),'experiments':rows,'acceptance':acceptance,
              'envelope_witnesses':witnesses,'complete_logical_bit_KL_frontier':frontier}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    for row in rows:
        print(row['lambda'],row['budget_bits'],row['method'],row['counts'],
              round(row['seconds']*1000,3),'ms',row['optimum_decimal'])


if __name__ == '__main__':
    main()
