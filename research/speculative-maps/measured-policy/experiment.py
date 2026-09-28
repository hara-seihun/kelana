#!/usr/bin/env python3
"""CPU paired allocation study with native online cycle-time receipts."""
import hashlib
import importlib.util
import json
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
DATA = Path('/path/to/workspace/data/kelana-speculative')
sys.path.insert(0, str(HERE))
from policy import ACTIONS, fit_policy, progress, propose, root_features


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def measured(producer):
    panels = ('fp32', 'fp32-frontier') if producer == 'residual' else ('fp32-direct',)
    samples = {n: [] for n in (0, 6, 18, 64)}
    checksums = {}
    for panel in panels:
        path = DATA/'online'/f'{panel}.json'
        checksums[panel] = sha(path)
        raw = json.loads(path.read_text())
        for run in raw['results']:
            for arm, result in run['arms'].items():
                if arm == 'serial':
                    samples[0].extend(result['cycles'])
                elif arm.startswith('tree'):
                    samples[int(arm[4:])].extend(result['cycles'])
    means = {}
    for count, rows in samples.items():
        if rows:
            means[count] = {k: float(np.mean([row[k] for row in rows]))*1000 for k in
                            ('draft_s', 'verify_s', 'adopt_s', 'cycle_s')}
            means[count]['corrected_rows'] = float(np.mean([row['corrected_rows'] for row in rows]))
            means[count]['samples'] = len(rows)
    # A piecewise measured curve. Verification depends on verified node count;
    # CPU production depends on the number of distinct correction rows visited.
    production = sorted((v['corrected_rows'], v['draft_s']) for n,v in means.items() if n)
    production.insert(0, (0., max(0., production[0][1] -
                              production[0][0] * (production[1][1]-production[0][1]) /
                              (production[1][0]-production[0][0]))))
    verification = sorted((n, v['verify_s']+v['adopt_s']) for n,v in means.items())
    if producer == 'direct':
        # The target verifier is shared. There is no direct-producer 64-node run;
        # transfer only the residual panel's GPU verifier/adoption cost.
        frontier = json.loads((DATA/'online/fp32-frontier.json').read_text())
        cycles = [c for run in frontier['results'] for c in run['arms']['tree64']['cycles']]
        verification.append((64, float(np.mean([c['verify_s']+c['adopt_s'] for c in cycles]))*1000))
        verification.sort()
    def interpolate(points, x):
        for (xa, ya), (xb, yb) in zip(points, points[1:]):
            if x <= xb:
                return ya + (x-xa)*(yb-ya)/(xb-xa)
        xa, ya = points[-2]
        xb, yb = points[-1]
        return yb+(x-xb)*(yb-ya)/(xb-xa)
    def cost(proposal):
        if not proposal['nodes']:
            # The routing features require the backbone and corrected root row.
            return verification[0][1] + interpolate(production, 1)
        return interpolate(verification, proposal['nodes']) + interpolate(production, proposal['rows'])
    return means, checksums, cost


def score(rows, choices, cost, feature=True):
    reward = sum(row['rewards'][a] for row,a in zip(rows, choices))
    elapsed = sum(cost(row['proposals'][a], feature) for row,a in zip(rows, choices))
    return {'tokens_per_second_predicted': 1000*reward/elapsed,
            'mean_tokens': reward/len(rows), 'mean_ms': elapsed/len(rows),
            'mean_nodes': float(np.mean([row['proposals'][a]['nodes'] for row,a in zip(rows,choices)])),
            'mean_rows': float(np.mean([row['proposals'][a]['rows'] for row,a in zip(rows,choices)])),
            'choices': dict(Counter(str(a.budget)+':'+a.shape for a in choices))}


def hindsight(rows, cost):
    rho = max(score(rows, [a]*len(rows), cost)['tokens_per_second_predicted'] for a in ACTIONS)/1000
    for _ in range(40):
        picks = [max(ACTIONS, key=lambda a:r['rewards'][a]-rho*cost(r['proposals'][a])) for r in rows]
        new_rho = score(rows, picks, cost)['tokens_per_second_predicted']/1000
        if abs(rho-new_rho)<1e-12:
            break
        rho = new_rho
    return picks


def run(producer):
    torch.set_num_threads(4)
    parent = HERE.parent
    residual = load_module('residual_policy', parent/'residual-drafter/experiment.py')
    if producer == 'direct':
        module = load_module('direct_policy', parent/'direct-producer/experiment.py')
        model = module.Direct()
        checkpoint = DATA/'direct-producer/direct-s200.pt'
    else:
        model = residual.Residual(4096)
        checkpoint = DATA/'residual-drafter/residual-v4096-s200.pt'
    state = torch.load(checkpoint, weights_only=True, map_location='cpu')
    model.load_state_dict(state)
    model.eval()
    lookup = torch.full((151936,), 4096, dtype=torch.long)
    lookup[state['vocabulary']] = torch.arange(4096)
    means, panel_hashes, measured_cost = measured(producer)
    feature_samples = []
    splits = {}
    with torch.inference_mode():
        for split in ('validation', 'test'):
            capture = DATA/f'{split}-greedy.pt'
            raw = torch.load(capture, weights_only=True, map_location='cpu')
            rows = []
            for hidden, future in zip(raw['hidden'], lookup[raw['future']]):
                base, gate = model.backbone(hidden.float()[None])
                base, gate = base[0], gate[0]
                codes = future.tolist()
                root_logits = model.logits(base[0], gate[0], torch.tensor(codes[0])).float()
                started = time.perf_counter()
                features = root_features(model, base, gate, codes[0], root_logits)
                feature_samples.append((time.perf_counter()-started)*1000)
                proposals = {a: propose(model, base, gate, codes[0], a, root_logits) for a in ACTIONS}
                rewards = {a: progress(p, codes) for a,p in proposals.items()}
                rows.append({'features':features, 'proposals':proposals, 'rewards':rewards})
            splits[split] = rows
    validation, test = splits['validation'], splits['test']
    feature_ms = float(np.median(feature_samples))
    def cost(proposal, feature=True):
        if not feature and not proposal['nodes']:
            return means[0]['cycle_s']
        # Additional full-shortlist softmax, mass/entropy and routing after the
        # corrected root row; the root correction itself is in measured_cost.
        return measured_cost(proposal) + (feature_ms if feature else 0.)
    features = [r['features'] for r in validation]
    rewards = [[r['rewards'][a] for a in ACTIONS] for r in validation]
    costs = [[cost(r['proposals'][a]) for a in ACTIONS] for r in validation]
    fixed_costs = [[cost(r['proposals'][a], False) for a in ACTIONS] for r in validation]
    policy, fixed = fit_policy(features, rewards, costs, fixed_costs=fixed_costs)
    fixed_action = ACTIONS[fixed]
    selected = [policy.choose(r['features']) for r in test]
    result = {'producer': producer, 'checkpoint_sha256':sha(checkpoint),
              'capture_sha256':{s:sha(DATA/f'{s}-greedy.pt') for s in splits},
              'online_panels_sha256':panel_hashes, 'measured_cycle_ms':means,
              'direct_64_verifier_transferred_from_residual_panel': producer == 'direct',
              'root_feature_cpu_median_ms': feature_ms,
              'actions':[vars(a) for a in ACTIONS], 'validation_fixed_action':vars(fixed_action),
              'validation_fixed':score(validation,[fixed_action]*len(validation),cost,False),
              'validation_policy':score(validation,[policy.choose(r['features']) for r in validation],cost),
              'test_fixed':score(test,[fixed_action]*len(test),cost,False),
              'test_policy':score(test,selected,cost),
              'test_hindsight':score(test,hindsight(test,cost),cost),
              'test_fixed_frontier':{str(a.budget)+':'+a.shape:score(test,[a]*len(test),cost,False) for a in ACTIONS},
              'policy':{'coefficients':policy.coefficients.tolist(), 'center':policy.center.tolist(),
                        'scale':policy.scale.tolist(), 'rate_tokens_per_ms':policy.rate,
                        'features':['root_top16_mass','root_top1_mass','root_top16_entropy','root_top2_mass'],
                        'ridge_penalty':16},
              'rows':{s:[{'features':r['features'].tolist(),
                           'actions':{str(a.budget)+':'+a.shape:{'tokens':r['rewards'][a],
                               'nodes':r['proposals'][a]['nodes'],'rows':r['proposals'][a]['rows'],
                               'depth_counts':r['proposals'][a]['depth_counts'],
                               'prefix_mass':r['proposals'][a]['mass'],
                               'predicted_ms':cost(r['proposals'][a])} for a in ACTIONS}} for r in rows]
                      for s,rows in splits.items()},
              'contract':'FP32 online cycle costs interpolate measured synchronous CPU draft, full target head, tree mask and KV adoption. Direct-producer 64-node draft cost extrapolates its measured CPU row slope; its 64-node verifier and adoption are transferred from the residual panel on the same target. Captured BF16 validation/test future IDs provide offline prefix outcomes, not continued FP32 paths. Full alternative trees are counterfactual analysis only; deployed selector computes one root row then constructs only its selected tree. All actions pay a measured CPU median for root softmax, ranking and entropy in addition to the root correction, including serial. Fixed baselines omit routing features; a fixed serial action does not run the producer. Prefix mass is descriptive and costs no second construction at runtime. Scores predict tokens/s, not a new online measurement. Test32 was inspected before this study.'}
    result['source_sha256'] = sha(__file__)
    result['policy_sha256'] = sha(HERE/'policy.py')
    HERE.joinpath(f'{producer}-results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('validation_fixed_action','validation_fixed','validation_policy','test_fixed','test_policy','test_hindsight')},indent=2))


if __name__ == '__main__':
    run(sys.argv[1] if len(sys.argv)>1 else 'residual')
