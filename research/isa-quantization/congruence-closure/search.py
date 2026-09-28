#!/usr/bin/env python3
"""Quantitative right-congruence closure instead of independent history labels."""
import importlib.util
import itertools
import json
from fractions import Fraction as F
from functools import cache
from pathlib import Path
from time import perf_counter

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('loss_owner',HERE.parent/'categorical-tree/search.py')
loss = importlib.util.module_from_spec(spec)
spec.loader.exec_module(loss)
WORDS = tuple(w for t in range(3) for w in itertools.product(range(2),repeat=t))
INDEX = {w:i for i,w in enumerate(WORDS)}
CHILD = {(i,a):INDEX[w+(a,)] for i,w in enumerate(WORDS) for a in range(2) if w+(a,) in INDEX}
CAPACITY = 2


def canonical(labels):
    seen = {}
    return tuple(seen.setdefault(c,len(seen)) for c in labels)


@cache
def close(partition,i,j):
    parent = list(range(len(WORDS)))
    def find(i):
        while parent[i]!=i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    def join(i,j):
        i,j = find(i),find(j)
        if i == j:
            return False
        parent[max(i,j)] = min(i,j)
        return True
    for a in range(len(WORDS)):
        for b in range(a):
            if partition[a]==partition[b]:
                join(a,b)
    join(i,j)
    changed = True
    while changed:
        changed = False
        for a in range(len(WORDS)):
            for b in range(a):
                if find(a)==find(b):
                    for token in range(2):
                        if (a,token) in CHILD and (b,token) in CHILD:
                            changed |= join(CHILD[a,token],CHILD[b,token])
    return canonical([find(i) for i in range(len(WORDS))])


def run_table(u):
    labels = []
    for word in WORDS:
        c = 0
        for a in word:
            c = u[2*c+a]
        labels.append(c)
    return canonical(labels)


class Study:
    def __init__(self,name):
        self.name = name
        def probability(word):
            if name == 'clock':
                change = len(word)==2
            elif name == 'delayed_parity':
                change = len(word)==2 and sum(word)%2==1
            elif name == 'realizable_parity':
                change = sum(word)%2==1
            else:
                raise ValueError(name)
            return F(3,4) if change else F(1,2)
        self.p = [(1-probability(w),probability(w)) for w in WORDS]
        self.weight = []
        for word in WORDS:
            probability_word = F(1)
            for t,a in enumerate(word):
                probability_word *= self.p[INDEX[word[:t]]][a]
            self.weight.append(probability_word)
        self.mass = sum(self.weight)
        self.loss = loss.Study(self.p,self.weight)
        self.identity = tuple(range(len(WORDS)))

    @cache
    def score(self,partition):
        masks = [sum(1<<i for i,c in enumerate(partition) if c==label) for label in set(partition)]
        return loss.scaled(self.mass,loss.add(*(self.loss.cluster_full(mask) for mask in masks)))

    def branch(self,partition):
        reps = [partition.index(c) for c in set(partition)]
        queries = []
        for anchors in itertools.combinations(reps,CAPACITY+1):
            children = sorted({close(partition,i,j) for i,j in itertools.combinations(anchors,2)})
            bound = loss.minimum([self.score(p) for p in children])
            queries.append((bound,anchors,children))
        return max(queries,key=lambda query:(query[0][0],query[1]))

    def search(self):
        seeds = ((0,0,1,1),(0,1,0,1),(0,1,1,0))
        best = min((self.score(run_table(u))[1],len(set(run_table(u))),run_table(u)) for u in seeds)
        counts = {'visited_partitions':0,'duplicate_partitions':0,'pruned':0,'realizable_leaves':0}
        seen = set()
        start = perf_counter()
        def visit(partition):
            nonlocal best
            if partition in seen:
                counts['duplicate_partitions'] += 1
                return
            seen.add(partition)
            counts['visited_partitions'] += 1
            if self.score(partition)[0]>best[0]:
                counts['pruned'] += 1
                return
            if len(set(partition))<=CAPACITY:
                counts['realizable_leaves'] += 1
                best = min(best,(self.score(partition)[1],len(set(partition)),partition))
                return
            bound,_,children = self.branch(partition)
            if bound[0]>best[0]:
                counts['pruned'] += 1
                return
            for child in sorted(children,key=lambda p:(self.score(p)[0],p)):
                visit(child)
        visit(self.identity)
        return best,counts,perf_counter()-start

    def evaluate(self):
        best,counts,seconds = self.search()
        root,anchors,children = self.branch(self.identity)
        queries = []
        for aa in itertools.combinations(range(len(WORDS)),CAPACITY+1):
            pairs = list(itertools.combinations(aa,2))
            floors = [self.score(close(self.identity,i,j)) for i,j in pairs]
            footprint = sorted({s for i,j in pairs for s,c in enumerate(close(self.identity,i,j))
                                if close(self.identity,i,j).count(c)>1})
            queries.append({'anchors':list(aa),'floor':loss.receipt(loss.minimum(floors)),
                            'footprint':footprint})
        single_suffix = []
        for i,j in itertools.combinations(anchors,2):
            terms = []
            for suffix in WORDS:
                x,y = WORDS[i]+suffix,WORDS[j]+suffix
                if x in INDEX and y in INDEX:
                    mask = (1<<INDEX[x])|(1<<INDEX[y])
                    terms.append(loss.scaled(self.mass,self.loss.cluster_full(mask)))
            single_suffix.append(max(terms,key=lambda interval:interval[0]))
        # Separate complete transition oracle, after closure search and bounds.
        programs = [(self.score(run_table(u)),run_table(u),u)
                    for u in itertools.product(range(CAPACITY),repeat=2*CAPACITY)]
        oracle = min((value[1],len(set(p)),p) for value,p,u in programs)
        assert best == oracle
        assert root[0] <= min(value[1] for value,p,u in programs)
        for i,j in itertools.combinations(range(len(WORDS)),2):
            closure = close(self.identity,i,j)
            for value,p,u in programs:
                if p[i]==p[j]:
                    assert all(p[a]==p[b] for a in range(len(WORDS)) for b in range(len(WORDS))
                               if closure[a]==closure[b])
                    assert self.score(closure)[0]<=value[1]
        for value,p,u in programs:
            for token in range(2):
                for i,j in itertools.combinations(range(len(WORDS)),2):
                    if p[i]==p[j] and (i,token) in CHILD and (j,token) in CHILD:
                        assert p[CHILD[i,token]]==p[CHILD[j,token]]
        naive = loss.add(*(tuple(F(x) for x in q['floor']['interval']) for q in queries))
        return {'teacher_laws':[[str(x) for x in row] for row in self.p],
                'history_weights':[str(x) for x in self.weight], 'total_mass':str(self.mass),
                'marginal_two_label_floor':'0','root_closure_floor':loss.receipt(root),
                'selected_anchors':list(anchors),'selected_children':[list(p) for p in children],
                'best_single_suffix_per_pair':loss.receipt(loss.minimum(single_suffix)),
                'complete_optimum':loss.receipt(self.score(best[2])), 'optimum_partition':best[2],
                'search_counts':counts,'search_seconds':seconds,'post_search_transition_tables':len(programs),
                'all_hypothetical_merges_checked_against_every_completion':True,
                'queries':queries,'unsafe_unweighted_query_sum':loss.receipt(naive),
                'unsafe_sum_exceeds_optimum':naive[0]>self.score(best[2])[1]}


def main():
    result = {'words':[list(w) for w in WORDS],'candidate_states':CAPACITY,
              'cases':{name:Study(name).evaluate() for name in ('clock','delayed_parity','realizable_parity')}}
    assert result['cases']['clock']['root_closure_floor']['decimal'][0]>0
    assert result['cases']['delayed_parity']['root_closure_floor']['decimal'][0]>0
    assert result['cases']['realizable_parity']['complete_optimum']['decimal'][1]<1e-20
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    for name,row in result['cases'].items():
        print(name,'closure',row['root_closure_floor']['decimal'],'single suffix',
              row['best_single_suffix_per_pair']['decimal'],'optimum',row['complete_optimum']['decimal'],
              row['search_counts'],row['search_seconds'])


if __name__ == '__main__':
    main()
