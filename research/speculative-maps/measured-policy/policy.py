"""Label-free allocation after a target-computed first token.

The caller owns the CPU producer and passes its five positionwise base/gate rows.
No target continuation, outcome, or target logit is read by the policy.
"""
from __future__ import annotations

import heapq
import json
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch


@dataclass(frozen=True)
class Action:
    budget: int
    shape: str = 'mass'


ACTIONS = (Action(0), Action(6), Action(18), Action(64),
           Action(6, 'depth'), Action(18, 'depth'), Action(18, 'breadth'),
           Action(64, 'depth'), Action(64, 'breadth'))


def root_features(model, base, gate, known, logits=None):
    """The corrected root row is paid once, even if the policy chooses serial."""
    if logits is None:
        logits = model.logits(base[0], gate[0], torch.tensor(known)).float()
    p = torch.softmax(logits, -1).numpy()
    pool = torch.topk(base[0], 16).indices.numpy()
    ranked = np.sort(p[pool])[::-1]
    conditional = ranked / max(ranked.sum(), 1e-30)
    return np.array([1., ranked.sum(), ranked[0],
                     float(-(conditional * np.log(np.maximum(conditional, 1e-30))).sum()),
                     float(ranked[:2].sum())], dtype=float)


def propose(model, base, gate, known, action, root_logits=None):
    """Ancestor-closed tree, including the retained target token as node zero."""
    if not action.budget:
        return {'prefixes': set(), 'rows': 0, 'nodes': 0, 'mass': 0., 'depth_counts': [0]*5}
    pools = torch.topk(base, 16, dim=-1).indices.tolist()
    cache = {}

    def children(prefix):
        key = (len(prefix)-1, prefix[-1])
        if key not in cache:
            d, previous = key
            values = (root_logits if d == 0 and root_logits is not None
                      else model.logits(base[d], gate[d], torch.tensor(previous))).float()
            lprob = torch.log_softmax(values, -1)
            cache[key] = [(int(t), float(lprob[t])) for t in pools[d]]
        return cache[key]

    selected = {()}
    ordered = [(known,)]
    parents = [-1]
    indices = {(known,): 0}
    counts = [0]*5
    mass = 0.
    heap = []

    def append(prefix, logmass):
        if len(prefix) >= 6:
            return
        for token, lp in children(prefix):
            child = prefix + (token,)
            total = logmass + lp
            # Bias changes depth versus branching without changing candidate budget.
            factor = {'mass': 0., 'depth': .70, 'breadth': -.70}[action.shape]
            heapq.heappush(heap, (-(total + factor * len(child)), child, total))

    append((known,), 0.)
    while heap and len(selected) < action.budget:
        _, full, logmass = heapq.heappop(heap)
        suffix = full[1:]
        selected.add(suffix)
        parents.append(indices[full[:-1]])
        indices[full] = len(ordered)
        ordered.append(full)
        counts[len(suffix)-1] += 1
        mass += math.exp(logmass)
        append(full, logmass)
    return {'prefixes': selected, 'rows': len(cache), 'nodes': len(selected),
            'mass': mass, 'depth_counts': counts, 'ordered': ordered, 'parents': parents}


def online_draft(model, hidden, root, lookup, policy):
    """Drop-in allocation interface for online/experiment.py's generation loop.

    The serial action is a tagged result: the caller should use ordinary SDPA,
    without building a tree mask or adopting speculative KV.
    """
    base, gate = model.backbone(hidden.float().cpu()[None])
    base, gate = base[0], gate[0]
    known = int(lookup[root])
    root_logits = model.logits(base[0], gate[0], torch.tensor(known)).float()
    features = root_features(model, base, gate, known, root_logits)
    action = policy.choose(features)
    if not action.budget:
        return action, [root], [-1], [0], 1
    proposal = propose(model, base, gate, known, action, root_logits)
    tokens = [root] + [int(model.vocabulary[p[-1]]) for p in proposal['ordered'][1:]]
    depths = [len(p)-1 for p in proposal['ordered']]
    return action, tokens, proposal['parents'], depths, proposal['rows']


def progress(proposal, continuation):
    """Offline diagnostic only; never used inside choose()."""
    if not proposal['nodes']:
        return 1
    for depth in range(1, min(6, len(continuation))):
        if tuple(continuation[1:depth+1]) not in proposal['prefixes']:
            return depth
    return min(6, len(continuation))


@dataclass
class Policy:
    actions: tuple[Action, ...]
    coefficients: np.ndarray
    center: np.ndarray
    scale: np.ndarray
    rate: float

    def choose(self, features):
        z = (np.asarray(features)[1:] - self.center) / self.scale
        values = np.r_[1., z] @ self.coefficients
        return self.actions[int(np.argmax(values))]


def load_policy(receipt):
    """Load coefficients fitted on validation from residual-results.json or direct-results.json."""
    record = json.loads(Path(receipt).read_text())
    state = record['policy']
    return Policy(tuple(Action(**a) for a in record['actions']),
                  np.asarray(state['coefficients']), np.asarray(state['center']),
                  np.asarray(state['scale']), state['rate_tokens_per_ms'])


def fit_policy(features, rewards, costs, actions=ACTIONS, penalty=16., fixed_costs=None):
    """Validation-only ridge estimate of reward minus rate times measured cost."""
    x = np.asarray(features)
    y = np.asarray(rewards)
    c = np.asarray(costs)
    fixed_prices = np.asarray(fixed_costs) if fixed_costs is not None else c
    rates = y.sum(axis=0)/fixed_prices.sum(axis=0)
    fixed = int(np.argmax(rates))
    rate = float(rates[fixed])
    center, scale = x[:, 1:].mean(0), np.maximum(x[:, 1:].std(0), .01)
    z = np.column_stack((np.ones(len(x)), (x[:, 1:]-center)/scale))
    ridge = np.diag([0.] + [penalty]*(z.shape[1]-1))
    coefficients = np.linalg.solve(z.T@z + ridge, z.T@(y-rate*c))
    return Policy(tuple(actions), coefficients, center, scale, rate), fixed
