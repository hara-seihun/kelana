#!/usr/bin/env python3
"""Partial-label Hall witnesses with sound source-mass capacity floors."""
import importlib.util
import itertools
import json
from math import comb
from time import perf_counter
from fractions import Fraction as F
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('tensor_capacity', HERE.parent/'emission-tensor/study.py')
tensor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tensor)
math = tensor.certificate.intervals
BUDGET = F(1,1000)


def components(allowed):
    unseen = set(range(len(allowed)))
    out = []
    while unseen:
        source = {min(unseen)}
        labels = set()
        while True:
            new_labels = set().union(*(set(allowed[s]) for s in source))
            new_source = {s for s in range(len(allowed)) if set(allowed[s]) & new_labels}
            if new_source == source and new_labels == labels:
                break
            source, labels = new_source, new_labels
        unseen -= source
        out.append(sorted(source))
    return out


def hall_witness(allowed, source):
    matching = {}

    def augment(s, seen):
        for label in allowed[s]:
            if label in seen:
                continue
            seen.add(label)
            if label not in matching or augment(matching[label], seen):
                matching[label] = s
                return True
        return False

    for s in source:
        augment(s,set())
    unmatched = set(source)-set(matching.values())
    if not unmatched:
        return {'matching': {str(s): label for label,s in matching.items()}}
    reached = set(unmatched)
    labels = set()
    while True:
        new_labels = set().union(*(set(allowed[s]) for s in reached))
        new_reached = reached | {matching[label] for label in new_labels if label in matching}
        if new_labels == labels and new_reached == reached:
            break
        reached, labels = new_reached, new_labels
    assert labels == set().union(*(set(allowed[s]) for s in reached))
    assert len(reached) > len(labels) and labels
    return {'sources': sorted(reached), 'labels': sorted(labels), 'deficiency': len(reached)-len(labels)}


def capacity(laws, weights, sources, count):
    mass = sum(weights[s] for s in sources)
    case = {'teacher_laws': [[str(x) for x in laws[s]] for s in sources],
            'occupancy': [str(weights[s]/mass) for s in sources], 'candidate_state_budget': count}
    p, nu = tensor.collapse(case)
    if len(p) <= count:
        return (F(0),F(0)), {'distinct_laws': len(p), 'mass': str(mass), 'labels': count}
    k, certificate = tensor.selected_power(p,nu,count)
    tensor_value = tuple(F(x) for x in certificate['Gershgorin_KL_lower_interval'])
    study = math.Study(p,nu)
    pair = {(i,j): study.cluster_full((1<<i)|(1<<j))
            for i in range(len(p)) for j in range(i+1,len(p))}
    edges = list(itertools.combinations(range(len(p)),count+1))
    share = F(1,comb(len(p)-1,count))
    packing = math.scaled(share, math.add(*(math.minimum([pair[i,j] for i,j in
                   itertools.combinations(edge,2)]) for edge in edges)))
    winner = 'collision_packing' if packing[0] > tensor_value[0] else 'tensor_coherence'
    value = math.scaled(mass, max((tensor_value,packing),key=lambda interval: interval[0]))
    return value, {'distinct_laws': len(p), 'mass': str(mass), 'labels': count,
                   'selected_power': k, 'coherence_certificate': certificate,
                   'uniform_collision_hyperedges': len(edges), 'uniform_share': str(share),
                   'normalized_collision_interval': [str(x) for x in packing], 'winner': winner}


def oracle(laws, weights, allowed):
    study = math.Study([list(row) for row in laws], list(weights))
    cluster = {mask: study.cluster_full(mask) for mask in range(1<<len(laws))}
    losses = []
    for assignment in itertools.product(*allowed):
        groups = {}
        for s,label in enumerate(assignment):
            groups[label] = groups.get(label,0) | (1<<s)
        losses.append(math.add(*(cluster[mask] for mask in groups.values())))
    return math.minimum(losses), len(losses)


def solve(laws, allowed, label_count):
    laws = tuple(tuple(F(x) for x in row) for row in laws)
    weights = (F(1,len(laws)),)*len(laws)
    assert all(allowed) and all(0 <= x < label_count for row in allowed for x in row)
    start = perf_counter()
    whole, whole_receipt = capacity(laws,weights,list(range(len(laws))),label_count)
    witnesses = []
    used = set()
    totals = []
    for component in components(allowed):
        witness = hall_witness(allowed,component)
        if 'matching' in witness:
            witnesses.append(witness)
            continue
        subset = witness['sources']
        assert not used.intersection(subset)
        used.update(subset)
        bound, receipt = capacity(laws,weights,subset,len(witness['labels']))
        witness.update({'capacity': receipt, 'KL_interval': [str(x) for x in bound]})
        witnesses.append(witness)
        totals.append(bound)
    combined = math.add(*totals)
    rejected = combined[0] > BUDGET
    bound_seconds = perf_counter()-start
    start = perf_counter()
    exact, count = oracle(laws,weights,allowed)
    oracle_seconds = perf_counter()-start
    assert combined[0] <= exact[1]
    if rejected:
        assert exact[0] > BUDGET
    return {'teacher_laws': [[str(x) for x in row] for row in laws], 'occupancy': [str(x) for x in weights],
            'allowed_labels': allowed, 'label_count': label_count,
            'global_capacity': whole_receipt, 'global_KL_interval': [str(x) for x in whole],
            'disjoint_witnesses': witnesses, 'combined_KL_interval': [str(x) for x in combined],
            'combined_KL_decimal': [float(x) for x in combined], 'error_budget': str(BUDGET),
            'rejected_before_label_completion': rejected, 'candidate_completions_scored_by_bound': 0,
            'bound_seconds': bound_seconds, 'oracle_seconds': oracle_seconds,
            'post_bound_oracle_completions': count, 'exact_free_readout_KL_interval': [str(x) for x in exact],
            'exact_free_readout_KL_decimal': [float(x) for x in exact]}


def main():
    bern = [(F(1,4),F(3,4)), (F(1,2),F(1,2)), (F(3,4),F(1,4))]*2
    generic = tensor.cases()['generic_six_law_witness']['teacher_laws']
    output = {
        'separated_repeated_laws': solve(bern, [[0,1]]*3+[[2,3]]*3,4),
        'shared_access_control': solve(bern, [list(range(4))]*6,4),
        'distinct_hall_defect': solve(generic, [[0,1]]*3+[[2,3],[3,4],[4,5]],6),
        'distinct_matching_control': solve(generic, [[i,(i+1)%6] for i in range(6)],6)}
    assert output['separated_repeated_laws']['rejected_before_label_completion']
    assert output['distinct_hall_defect']['rejected_before_label_completion']
    assert not output['shared_access_control']['rejected_before_label_completion']
    assert not output['distinct_matching_control']['rejected_before_label_completion']
    assert output['shared_access_control']['exact_free_readout_KL_decimal'][1] < 1e-20
    assert output['distinct_matching_control']['exact_free_readout_KL_decimal'][1] < 1e-20
    (HERE/'results.json').write_text(json.dumps(output,indent=2)+'\n')
    for name,result in output.items():
        print(name, result['combined_KL_decimal'], 'oracle',result['exact_free_readout_KL_decimal'],
              'reject',result['rejected_before_label_completion'])


if __name__ == '__main__':
    main()
