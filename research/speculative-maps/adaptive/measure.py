#!/usr/bin/env python3
"""Unequal token difficulty and validation-fitted verification budgets on frozen traces."""
import hashlib
import heapq
import importlib.util
import json
import math
import time
from collections import Counter
from pathlib import Path

import numpy as np
import torch

ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location('pilot', ROOT/'qwen/pilot.py')
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)
DATA = pilot.DATA
BUDGETS = [0, 1, 2, 4, 6, 8, 12, 18, 32, 64]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def capture_rows(model, split, lookup):
    hidden, anchors, targets, _ = pilot.dataset(split+'-greedy', lookup, 'cpu')
    rows = []
    with torch.inference_mode():
        for h, anchor, target in zip(hidden, anchors, targets):
            base, gate = model.backbone(h[None])
            base, gate = base[0], gate[0]
            candidates = base.topk(16, dim=-1).indices
            memo = {}
            hits = misses = 0
            def distribution(depth, previous):
                nonlocal hits, misses
                key = (depth, previous)
                if key in memo:
                    hits += 1
                    return memo[key]
                misses += 1
                logp = model.logits(base[depth], gate[depth], torch.tensor(previous)).log_softmax(-1)
                memo[key] = logp
                return logp
            def children(prefix):
                depth = len(prefix)
                previous = int(anchor) if depth == 0 else prefix[-1]
                logp = distribution(depth, previous)
                return [(int(token), float(logp[token])) for token in candidates[depth]]
            root_p = distribution(0, int(anchor)).exp()
            root_sorted = root_p.sort(descending=True).values
            entropy = float(-(root_p * root_p.clamp_min(1e-30).log()).sum())
            heap = [(-lp, (token,)) for token, lp in children(())]
            heapq.heapify(heap)
            selected, masses = [], []
            while heap and len(selected) < max(BUDGETS):
                negative_logp, prefix = heapq.heappop(heap)
                selected.append(prefix)
                masses.append(math.exp(-negative_logp))
                if len(prefix) < pilot.HORIZON:
                    for token, logp in children(prefix):
                        heapq.heappush(heap, (negative_logp-logp, prefix+(token,)))
            path = tuple(target.tolist())
            visits = [int(node == path[:len(node)]) for node in selected]
            # Selected nodes are ancestor-closed, so summed visits equals covered prefix.
            actual = [1+sum(visits[:b]) for b in BUDGETS]
            predicted = [1+sum(masses[:b]) for b in BUDGETS]
            for b, a in zip(BUDGETS, actual):
                selected_set = set(selected[:b])
                depth = next((j for j in range(pilot.HORIZON)
                              if path[:j+1] not in selected_set), pilot.HORIZON)
                assert a == depth+1
            pool_depth = next((j for j in range(pilot.HORIZON)
                               if not bool((candidates[j] == target[j]).any())), pilot.HORIZON)
            vocab_depth = next((j for j in range(pilot.HORIZON)
                                if target[j] == len(model.vocabulary)), pilot.HORIZON)
            chain, _ = pilot.trees(model, h, int(anchor), 6, 16)
            chain_depth = next((j for j in range(pilot.HORIZON) if path[j] != chain[j]), pilot.HORIZON)
            rows.append({'entropy_nats': entropy, 'root_top1': float(root_sorted[0]),
                         'root_margin': float(root_sorted[0]-root_sorted[1]),
                         'root_prediction_correct': int(int(root_p.argmax()) == path[0]),
                         'actual': actual, 'predicted': predicted, 'masses': masses,
                         'visits': visits, 'node_depths': [len(n) for n in selected],
                         'pool_oracle_tokens': pool_depth+1, 'vocab_oracle_tokens': vocab_depth+1,
                         'chain_tokens': chain_depth+1, 'conditional_row_evaluations': misses,
                         'conditional_row_cache_hits': hits})
    return rows


def fit_power(rows):
    p = np.asarray([r['masses'] for r in rows])
    y = np.asarray([r['visits'] for r in rows])
    grid = np.geomspace(.125, 4., 81)
    losses = [float(np.mean((p**a-y)**2)) for a in grid]
    idx = int(np.argmin(losses))
    return float(grid[idx]), {'grid': grid.tolist(), 'validation_brier': losses,
                              'chosen_power': float(grid[idx]),
                              'raw_validation_brier': float(np.mean((p-y)**2))}


def predicted_progress(rows, power):
    return np.asarray([[1+sum(p**power for p in row['masses'][:b]) for b in BUDGETS]
                       for row in rows])


def optimal_policy(values, costs):
    # Renewal ratio on this finite distribution. It is an oracle only if values
    # are measured outcomes; otherwise it optimizes the declared prediction.
    rate = float(values[:, 0].mean()/costs[0])
    for _ in range(30):
        choice = np.argmax(values-rate*costs[None], axis=1)
        revised = float(values[np.arange(len(values)), choice].sum()/costs[choice].sum())
        if abs(revised-rate) < 1e-12:
            break
        rate = revised
    return rate, choice


def score(actual, costs, choices):
    chosen = actual[np.arange(len(actual)), choices]
    return {'mean_tokens': float(chosen.mean()), 'mean_normalized_cycle_cost': float(costs[choices].mean()),
            'tokens_per_normalized_time': float(chosen.sum()/costs[choices].sum()),
            'mean_verified_nodes': float(np.asarray(BUDGETS)[choices].mean()),
            'budget_counts': dict(sorted(Counter(str(BUDGETS[i]) for i in choices).items(),
                                        key=lambda kv: int(kv[0])))}


def analyze(rows):
    actual = np.asarray([r['actual'] for r in rows])
    idx6, idx18, idx64 = [BUDGETS.index(b) for b in [6,18,64]]
    order = np.argsort([r['entropy_nats'] for r in rows])
    quartiles = []
    for indices in np.array_split(order, 4):
        selected = [rows[i] for i in indices]
        quartiles.append({'n':len(indices), 'entropy_range': [min(r['entropy_nats'] for r in selected),
                                                            max(r['entropy_nats'] for r in selected)],
                          'mean_chain':float(np.mean([r['chain_tokens'] for r in selected])),
                          'mean_tree6':float(actual[indices, idx6].mean()),
                          'mean_tree18':float(actual[indices, idx18].mean()),
                          'mean_tree64':float(actual[indices, idx64].mean()),
                          'root_accuracy':float(np.mean([r['root_prediction_correct'] for r in selected]))})
    return {'entropy_quartiles':quartiles,
            'chain_histogram':dict(sorted(Counter(r['chain_tokens'] for r in rows).items())),
            'pool_oracle_histogram':dict(sorted(Counter(r['pool_oracle_tokens'] for r in rows).items())),
            'benefit6_to18_contexts': int(np.sum(actual[:,idx18]>actual[:,idx6])),
            'benefit18_to64_contexts': int(np.sum(actual[:,idx64]>actual[:,idx18])),
            'mean_tree_by_budget':{str(b):float(actual[:,i].mean()) for i,b in enumerate(BUDGETS)},
            'mean_conditional_row_evaluations': float(np.mean([r['conditional_row_evaluations'] for r in rows])),
            'mean_conditional_row_cache_hits':float(np.mean([r['conditional_row_cache_hits'] for r in rows]))}


def main():
    torch.set_num_threads(4)
    state = torch.load(DATA/'conditional-s200.pt', weights_only=True)
    model = pilot.Drafter(len(state['vocabulary']), True)
    model.load_state_dict(state)
    model.eval()
    lookup = torch.full((151936,), len(model.vocabulary), dtype=torch.long)
    lookup[model.vocabulary] = torch.arange(len(model.vocabulary))
    started = time.perf_counter()
    val, test = [capture_rows(model, s, lookup) for s in ['validation','test']]
    prior = json.loads((DATA/'evaluation-s200.json').read_text())['arms']['conditional']['metrics']
    for split, rows in [('validation-greedy', val), ('test-greedy', test)]:
        for b in [6, 18, 32, 64]:
            assert [r['actual'][BUDGETS.index(b)] for r in rows] == prior[split][str(b)]['per_context_tree']
    power, fit = fit_power(val)
    yval = np.asarray([r['actual'] for r in val])
    ytest = np.asarray([r['actual'] for r in test])
    scenarios = []
    for knee in [4, 8, 16, 32, 64]:
        # Hypothetical flat-to-compute-bound curve. Zero budget bypasses draft.
        costs = np.asarray([1. if b == 0 else .2+max(1., (1+b)/knee) for b in BUDGETS])
        # A confidence-based policy has already run the drafter even if it
        # chooses no verification nodes. It cannot claim the static bypass cost.
        policy_costs = costs.copy()
        policy_costs[0] = 1.2
        fixed = int(np.argmax(yval.mean(0)/costs))
        row = {'knee_target_rows': knee, 'draft_cost':.2,
               'costs':costs.tolist(), 'policy_costs':policy_costs.tolist(),
               'best_fixed_on_validation':BUDGETS[fixed],
               'held_fixed':score(ytest,costs,np.full(len(test),fixed)),
               'held_fixed_frontier':{str(b):score(ytest,costs,np.full(len(test),i))
                                      for i,b in enumerate(BUDGETS)}}
        for name, a in [('raw',1.),('calibrated',power)]:
            rate, _ = optimal_policy(predicted_progress(val,a),policy_costs)
            choices = np.argmax(predicted_progress(test,a)-rate*policy_costs[None],axis=1)
            row[name] = {'validation_predicted_rate':rate, **score(ytest,policy_costs,choices)}
        _, choices = optimal_policy(ytest,costs)
        row['hindsight_oracle'] = score(ytest,costs,choices)
        scenarios.append(row)
    record = {'source_sha256':sha(__file__), 'checkpoint_sha256':sha(DATA/'conditional-s200.pt'),
              'capture_sha256':{s:sha(DATA/(s+'-greedy.pt')) for s in ['validation','test']},
              'budgets':BUDGETS, 'prior_per_context_comparisons':256, 'prior_mismatches':0, 'calibration':fit, 'validation_summary':analyze(val),
              'test_summary':analyze(test), 'scenarios':scenarios,
              'rows':{'validation':val,'test':test},
              'python_total_seconds':time.perf_counter()-started,
              'scope':'Previously inspected fixed 32+32 pilot contexts, greedy target trajectories. '
                      'Cost curves are hypothetical sensitivity scenarios, not measured GPU speed. '
                      'Only validation outcomes fit power, fixed budget and policy rate. '
                      'Hindsight sees test answers and is not executable; it is granted free routing '
                      'and may skip drafting, unlike confidence policies that pay .2 even for budget0. Full64 tree generated '
                      'during this offline study; a real cheap adaptive implementation must avoid '
                      'materializing unused nodes and charge selector construction.'}
    Path(__file__).with_name('results.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({'power':power,'test':record['test_summary'],
                      'scenarios':[{k:s[k] for k in ['knee_target_rows','held_fixed','raw','calibrated','hindsight_oracle']}
                                   for s in scenarios]},indent=2))


if __name__ == '__main__':
    main()
