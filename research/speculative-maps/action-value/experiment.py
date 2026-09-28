#!/usr/bin/env python3
"""Paired, label-free construction of support-changing draft actions on frozen Qwen traces."""
import hashlib
import heapq
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'qwen'))
from pilot import DATA, Drafter, HORIZON

BUDGETS = (6, 18, 64)
ACTIONS = ('chain16', 'static16', 'static64', 'static256', 'dynamic16', 'dynamic64', 'independent16')
FLOPS_HEAD = 2 * 151936 * 1024
FLOPS_BASE = 2 * (1024*256 + 256*768 + 6*128*1024 + 6*2048*1024)
FLOPS_ROW = 2 * 2048 * 32
STATIC_RANK_COMPARISONS = 6 * 2048


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build_context(model, feature, anchor, target):
    with torch.inference_mode():
        base, gate = model.backbone(feature[None])
        base, gate = base[0].numpy(), gate[0].numpy()
        codes = model.labels.weight.detach().numpy()
        gates = np.tanh(gate) / np.sqrt(32)
    static = {w: [np.argsort(-row, kind='stable')[:w].tolist() for row in base] for w in (16, 64, 256)}
    cache = {}
    def scores(depth, previous):
        key = (depth, previous)
        if key not in cache:
            cache[key] = base[depth] + (codes[previous] * gates[depth]) @ codes[:-1].T
        return cache[key]
    root = scores(0, anchor)
    p = np.exp(root - root.max()); p /= p.sum()
    root_rank = np.argsort(-root, kind='stable')
    features = [float(-(p*np.log(np.maximum(p, 1e-35))).sum()), float(p[root_rank[0]]),
                float(p[root_rank[0]]-p[root_rank[1]]), float(p[static[16][0]].sum())]
    result = {}
    for name in ACTIONS:
        for budget in BUDGETS if name != 'chain16' else (6,):
            dynamic = name.startswith('dynamic')
            independent = name == 'independent16'
            width = int(name.replace('dynamic', '').replace('static', '').replace('independent', '').replace('chain', ''))
            used = set()
            ranking = set()
            tree = set()
            def children(prefix):
                d = len(prefix)
                prev = anchor if d == 0 else prefix[-1]
                if independent:
                    values = base[d]
                else:
                    values = scores(d, prev)
                    used.add((d, prev))
                if dynamic:
                    ranking.add((d, prev))
                    candidates = np.argsort(-values, kind='stable')[:width]
                else:
                    candidates = static[width][d]
                # Log normalization is over all 2,048 values even with a narrower pool.
                vmax = float(np.max(values))
                norm = vmax + float(np.log(np.exp(values-vmax).sum()))
                return [(int(token), float(values[token]-norm)) for token in candidates]
            if name == 'chain16':
                prefix = ()
                for _ in range(HORIZON):
                    token = max(children(prefix), key=lambda x: (x[1], -x[0]))[0]
                    prefix += (token,)
                    tree.add(prefix)
            else:
                heap = [(-lp, (token,)) for token, lp in children(())]
                heapq.heapify(heap)
                while heap and len(tree) < budget:
                    nlp, prefix = heapq.heappop(heap)
                    tree.add(prefix)
                    if len(prefix) < HORIZON:
                        for token, lp in children(prefix):
                            heapq.heappush(heap, (nlp-lp, prefix+(token,)))
            progress = 1 + next((j for j in range(HORIZON) if tuple(target[:j+1]) not in tree), HORIZON)
            # Root evaluation is paid by the selector regardless of which action it picks.
            result[f'{name}:{budget}'] = {'tokens': progress, 'nodes':len(tree),
                'corrected_rows':len(used), 'ranking_scans':len(ranking),
                'producer_flops':FLOPS_BASE + FLOPS_ROW*len(used),
                'ranking_compared_values':2048*len(ranking)}
    retained = {}
    for budget in BUDGETS:
        first = int(target[0])
        tree = {(first,)}
        used = set()
        def descendants(prefix):
            depth = len(prefix)
            previous = prefix[-1]
            values = scores(depth, previous)
            used.add((depth, previous))
            vmax = float(values.max())
            norm = vmax + float(np.log(np.exp(values-vmax).sum()))
            return [(int(token), float(values[token]-norm)) for token in static[16][depth]]
        heap = [(-lp, (first, tok)) for tok,lp in descendants((first,))]
        heapq.heapify(heap)
        while heap and len(tree) < budget:
            neg, prefix = heapq.heappop(heap)
            tree.add(prefix)
            if len(prefix) < HORIZON:
                for tok,lp in descendants(prefix):
                    heapq.heappush(heap,(neg-lp,prefix+(tok,)))
        retained[str(budget)] = {'tokens':1+next((j for j in range(HORIZON) if tuple(target[:j+1]) not in tree), HORIZON),
            'nodes':len(tree),'corrected_rows':len(used),
            'producer_flops':FLOPS_BASE+FLOPS_ROW*len(used)}
    widths = {str(w): 1+next((d for d in range(HORIZON) if target[d] not in static[w][d]), HORIZON)
              for w in (16, 64, 256)}
    dynamic_pool = {}
    for w in (16, 64):
        # Counterfactual oracle supplies the true predecessor at each position. Not a deployable pool.
        dynamic_pool[str(w)] = 1+next((d for d in range(HORIZON) if target[d] not in np.argsort(-scores(d, anchor if d == 0 else target[d-1]), kind='stable')[:w]), HORIZON)
    return {'features':features, 'actions':result, 'retained_first_token':retained, 'pool_oracle':widths,
            'conditional_pool_oracle':dynamic_pool, 'target_shortlist':list(target),
            'unique_corrected_rows_across_actions':len(cache)}


def cost(row, action, knee, feature=True):
    item = row['actions'][action]
    # Charge all candidate nodes including the exit/bonus target row, and every producer row.
    # All actions construct six static pools; dynamic actions also rank at visited prefixes.
    # One comparison per shortlist value is a common abstract scan price, not argsort timing.
    producer = (item['producer_flops'] + STATIC_RANK_COMPARISONS + item['ranking_compared_values'])/FLOPS_HEAD
    # Corrected actions already evaluated the root distribution. Only the independent
    # action needs an additional corrected root row to expose the routing features.
    feature_cost = FLOPS_ROW/FLOPS_HEAD if feature and action.startswith('independent') else 0
    return .12 + producer + feature_cost + max(1, (1+item['nodes'])/knee)


def rate(rows, picks, knee, feature=True):
    rewards = [r['actions'][a]['tokens'] for r,a in zip(rows,picks)]
    costs = [cost(r,a,knee,feature) for r,a in zip(rows,picks)]
    return {'tokens_per_cost':float(sum(rewards)/sum(costs)), 'mean_tokens':float(np.mean(rewards)),
            'mean_cost':float(np.mean(costs)), 'mean_nodes':float(np.mean([r['actions'][a]['nodes'] for r,a in zip(rows,picks)])),
            'actions':dict(Counter(picks))}


def fit_route(validation, keys, knee, kind):
    x = np.asarray([r['features'] for r in validation]);
    y = np.asarray([[r['actions'][key]['tokens'] for key in keys] for r in validation])
    c = np.asarray([[cost(r,key,knee) for key in keys] for r in validation])
    baseline = max(keys, key=lambda key:rate(validation,[key]*len(validation),knee,False)['tokens_per_cost'])
    rho = rate(validation,[baseline]*len(validation),knee,False)['tokens_per_cost']
    if kind == 'entropy':
        best = (-float('inf'),None)
        for threshold in sorted(set(x[:,0])):
            for lo in keys:
                for hi in keys:
                    picks = [lo if v < threshold else hi for v in x[:,0]]
                    score = rate(validation,picks,knee)['tokens_per_cost']
                    if score > best[0]: best = (score,(float(threshold),lo,hi))
        threshold, lo, hi = best[1]
        return {'threshold':threshold, 'low':lo, 'high':hi}, lambda rows:[lo if r['features'][0]<threshold else hi for r in rows]
    # Ridge regress net *incremental* value against root uncertainty and mass not captured
    # by the static16 root. No target outcome or target rank is an input to the route.
    z = np.column_stack((np.ones(len(x)), (x[:,0]-x[:,0].mean())/max(x[:,0].std(),.01),
                         (x[:,3]-x[:,3].mean())/max(x[:,3].std(),.01)))
    delta = y-rho*c
    coefficients = np.linalg.solve(z.T@z+np.diag([0,8,8]),z.T@delta)
    mean, scale = x[:,[0,3]].mean(0),np.maximum(x[:,[0,3]].std(0),.01)
    def predict(rows):
        f = np.asarray([r['features'] for r in rows])[:,[0,3]]
        zz = np.column_stack((np.ones(len(rows)),(f-mean)/scale))
        estimates = zz@coefficients
        return [keys[i] for i in estimates.argmax(1)]
    return {'features':['root_entropy','static16_root_mass'],'ridge_penalty':8,'coefficients':coefficients.tolist(),
            'center':mean.tolist(),'scale':scale.tolist(),'validation_fixed_rate':rho},predict


def main():
    torch.set_num_threads(4)
    state_path = DATA/'conditional-s200.pt'
    state = torch.load(state_path, weights_only=True, map_location='cpu')
    model = Drafter(len(state['vocabulary']),True); model.load_state_dict(state);model.eval()
    lookup = torch.full((151936,),len(state['vocabulary']),dtype=torch.long)
    lookup[state['vocabulary']] = torch.arange(len(state['vocabulary']))
    splits = {}
    for split in ('validation','test'):
        raw = torch.load(DATA/(split+'-greedy.pt'),weights_only=True,map_location='cpu')
        splits[split] = [build_context(model,h.float(),int(a),y.tolist()) for h,a,y in
                         zip(raw['hidden'],lookup[raw['anchor']],lookup[raw['future']])]
    val,test = splits['validation'],splits['test']
    keys = list(val[0]['actions'])
    scenarios = {}
    for knee in (8,16,32):
        fixed = max(keys,key=lambda a:rate(val,[a]*len(val),knee,False)['tokens_per_cost'])
        entropy_rule,entropy = fit_route(val,keys,knee,'entropy')
        benefit_rule,benefit = fit_route(val,keys,knee,'benefit')
        # Dinkelbach iteration yields the maximum ratio of sums for this panel.
        # Hindsight gets the true outcome, but still pays for its action and the feature.
        rho = rate(test,[fixed]*len(test),knee)['tokens_per_cost']
        for _ in range(30):
            oracle = [max(keys,key=lambda a:r['actions'][a]['tokens']-rho*cost(r,a,knee)) for r in test]
            updated = rate(test,oracle,knee)['tokens_per_cost']
            if abs(updated-rho)<1e-12: break
            rho = updated
        scenarios[str(knee)] = {'fixed_selected_validation':fixed,'fixed':rate(test,[fixed]*len(test),knee,False),
            'entropy_rule':entropy_rule,'entropy':rate(test,entropy(test),knee),
            'action_value_rule':benefit_rule,'action_value':rate(test,benefit(test),knee),
            'hindsight_diagnostic':rate(test,oracle,knee),
            'fixed_frontier':{a:rate(test,[a]*len(test),knee,False) for a in keys}}
    pairs = {}
    for a in keys:
        pairs[a] = {'validation_mean':float(np.mean([r['actions'][a]['tokens'] for r in val])),
                    'test_mean':float(np.mean([r['actions'][a]['tokens'] for r in test])),
                    'test_delta_vs_static16_same_budget':float(np.mean([r['actions'][a]['tokens'] - r['actions'][f'static16:{a.split(":")[1]}']['tokens'] for r in test])),
                    'test_gain_contexts':sum(r['actions'][a]['tokens']>r['actions'][f'static16:{a.split(":")[1]}']['tokens'] for r in test),
                    'test_loss_contexts':sum(r['actions'][a]['tokens']<r['actions'][f'static16:{a.split(":")[1]}']['tokens'] for r in test),
                    'mean_corrected_rows':float(np.mean([r['actions'][a]['corrected_rows'] for r in test])),
                    'mean_producer_flops':float(np.mean([r['actions'][a]['producer_flops'] for r in test]))}
    record = {'source_sha256':sha(__file__),'checkpoint_sha256':sha(state_path),
      'capture_sha256':{s:sha(DATA/(s+'-greedy.pt')) for s in ('validation','test')},
      'contracts':{'greedy':'Saved target greedy prefix membership, not sampled acceptance or measured GPU latency.',
        'pool':'Top-k static base scores, or predecessor-corrected scores at each visited prefix; no label used for construction.',
        'cost':'Normalized scenario: .12 fixed draft dispatch, computed producer FLOPs divided by one 151936x1024 full target head, six shared static ranking scans, additional dynamic ranking scans, plus max(1,(nodes+1)/knee) target rows. A scan costs one comparison per shortlist value in this abstract scenario, not measured argsort time. Target head is a reference unit, not a measured time conversion. Corrected actions reuse their already-paid root row for routing; independent actions pay an incremental root correction row if selected by a feature policy, while fixed independent needs none. All actions pay producer, including chain. No target capture, weights change, or online KV verifier.',
        'fit':'Only validation outcomes tune fixed action, entropy threshold, and ridge action value. The 32 test contexts have been inspected in prior studies. Hindsight reads outcomes and is not executable.'},
      'producer_flops_base':FLOPS_BASE,'producer_flops_row':FLOPS_ROW,'static_rank_comparisons':STATIC_RANK_COMPARISONS,'target_head_flops':FLOPS_HEAD,
      'pairs':pairs,'scenarios':scenarios,
      'retained_first_token':{str(b):{'validation_mean':float(np.mean([r['retained_first_token'][str(b)]['tokens'] for r in val])),
        'test_mean':float(np.mean([r['retained_first_token'][str(b)]['tokens'] for r in test])),
        'test_gain_contexts':sum(r['retained_first_token'][str(b)]['tokens']>r['actions'][f'static16:{b}']['tokens'] for r in test),
        'test_mean_corrected_rows':float(np.mean([r['retained_first_token'][str(b)]['corrected_rows'] for r in test]))} for b in BUDGETS},
      'rows':splits}
    HERE.mkdir(exist_ok=True)
    (HERE/'results.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({'pairs':pairs,'scenarios':{k:{a:v[a] for a in ('fixed_selected_validation','fixed','entropy','action_value','hindsight_diagnostic')} for k,v in scenarios.items()}},indent=2))


if __name__ == '__main__':main()
