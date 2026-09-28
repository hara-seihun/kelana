#!/usr/bin/env python3
"""Price an exact first target token against a fixed-node learned residual tree."""
import hashlib
import heapq
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'qwen'))
from pilot import DATA, MODEL, Drafter, HORIZON, trees

OUT = DATA / 'candidate-repair'
BUDGETS = (6, 18, 32, 64)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def depth(tree, target):
    path = tuple(target)
    return 1 + next((j for j in range(HORIZON) if path[:j+1] not in tree), HORIZON)


def forced_tree(model, h, anchor, first, budget, width):
    with torch.no_grad():
        base, gate = model.backbone(h[None])
        base, gate = base[0], gate[0]
        pool = base.topk(width, dim=-1).indices
        def children(prefix):
            d = len(prefix)
            previous = anchor if d == 0 else prefix[-1]
            logp = model.logits(base[d], gate[d], torch.tensor(previous)).log_softmax(-1)
            return [(int(i), float(logp[i])) for i in pool[d]]
        tree = {(first,)}
        heap = []
        for token, score in children((first,)):
            heapq.heappush(heap, (-score, (first, token)))
        while heap and len(tree) < budget:
            neglogp, prefix = heapq.heappop(heap)
            tree.add(prefix)
            if len(prefix) < HORIZON:
                for token, score in children(prefix):
                    heapq.heappush(heap, (neglogp-score, prefix+(token,)))
        chain = [first]
        while len(chain) < HORIZON:
            chain.append(max(children(tuple(chain)), key=lambda pair: (pair[1], -pair[0]))[0])
        return chain, tree


def summarize(values):
    return {'mean': float(np.mean(values)), 'per_context': values}


def main():
    torch.set_num_threads(4)
    state_path = DATA / 'conditional-s200.pt'
    state = torch.load(state_path, weights_only=True, map_location='cpu')
    model = Drafter(len(state['vocabulary']), True)
    model.load_state_dict(state)
    model.eval()
    vocabulary = state['vocabulary']
    lookup = torch.full((151936,), len(vocabulary), dtype=torch.long)
    lookup[vocabulary] = torch.arange(len(vocabulary))
    with safe_open(MODEL / 'model.safetensors', framework='pt', device='cpu') as weights:
        full_head = weights.get_tensor('model.embed_tokens.weight')
    result = {'source_sha256': sha(__file__), 'checkpoint_sha256': sha(state_path),
              'held_data_sha256': {}, 'splits': {}, 'head_dtype': str(full_head.dtype),
              'head_shape': list(full_head.shape), 'budgets': list(BUDGETS), 'pool_width': 16}
    for split in ('validation-greedy', 'test-greedy'):
        path = DATA / (split + '.pt')
        raw = torch.load(path, weights_only=True, map_location='cpu')
        h = raw['hidden'].float()
        anchors = lookup[raw['anchor']].tolist()
        targets = lookup[raw['future']].tolist()
        full_targets = raw['future'].tolist()
        result['held_data_sha256'][split] = sha(path)
        # BF16 source hidden values round-trip exactly through the saved FP16.
        # Original lm_head emits BF16 logits; FP32 scoring can change argmax at a tie.
        assert torch.equal(raw['hidden'], raw['hidden'].bfloat16().half())
        t0 = time.perf_counter()
        fp32_logits = h @ full_head.float().T
        fp32_first = fp32_logits.argmax(-1).tolist()
        first = fp32_logits.bfloat16().argmax(-1).tolist()
        head_seconds = time.perf_counter() - t0
        records = {str(b): {'baseline': [], 'forced': [], 'retained': [],
                            'baseline_chain': [], 'forced_chain': [], 'retained_chain': [],
                            'baseline_nodes': [], 'forced_nodes': [], 'retained_nodes': []}
                   for b in BUDGETS}
        matches = [a == t[0] for a, t in zip(first, full_targets)]
        mapped_first = lookup[torch.tensor(first)].tolist()
        retained_first = lookup[raw['future'][:, 0]].tolist()
        t0 = time.perf_counter()
        for feature, anchor, target, tok, retained, exact in zip(h, anchors, targets, mapped_first, retained_first, matches):
            for budget in BUDGETS:
                chain, tree = trees(model, feature, anchor, budget, 16)
                new_chain, new_tree = forced_tree(model, feature, anchor, tok, budget, 16)
                handoff_chain, handoff_tree = forced_tree(model, feature, anchor, retained, budget, 16)
                row = records[str(budget)]
                row['baseline'].append(depth(tree, target))
                row['forced'].append(depth(new_tree, target) if exact else 1)
                row['retained'].append(depth(handoff_tree, target))
                row['baseline_chain'].append(1 + next((j for j in range(HORIZON) if target[j] != chain[j]), HORIZON))
                row['forced_chain'].append((1 + next((j for j in range(HORIZON) if target[j] != new_chain[j]), HORIZON)) if exact else 1)
                row['retained_chain'].append(1 + next((j for j in range(HORIZON) if target[j] != handoff_chain[j]), HORIZON))
                row['baseline_nodes'].append(len(tree))
                row['forced_nodes'].append(len(new_tree))
                row['retained_nodes'].append(len(handoff_tree))
        construction_seconds = time.perf_counter() - t0
        result['splits'][split] = {'rows': len(targets), 'head_argmax_matches_saved_target': sum(matches),
            'head_mismatch_indices': [i for i, ok in enumerate(matches) if not ok],
            'unrounded_fp32_head_mismatch_indices': [i for i, (a, t) in enumerate(zip(fp32_first, full_targets)) if a != t[0]],
            'retained_first_tokens_from_saved_target_trajectory': True,
            'head_full_batch_seconds': head_seconds, 'tree_construction_seconds': construction_seconds,
            'by_budget': {key: {metric: summarize(v) for metric, v in row.items()}
                          for key, row in records.items()}}
    result['accounting'] = {'head_flops_per_context': 2*full_head.numel(),
        'full_head_weight_bytes_bf16_per_context_if_streamed': full_head.numel()*2,
        'full_head_weight_bytes_fp32_as_scored_here_per_context': full_head.numel()*4,
        'baseline_pool_head_values_per_context': 6*2048*1024,
        'forced_target_work': 'BF16-rounded head reconstruction pays a full first-token target output projection. The retained-token arm directly reads saved target trajectory first tokens, representing a proposed verifier-to-drafter handoff; it is free only when this exact decision was previously computed and retained by the target, not from hidden alone.',
        'cpu_timing': 'Reference batch head projection and unoptimized Python tree construction; not GPU throughput, and no verifier or cache continuation measured.'}
    OUT.mkdir(parents=True, exist_ok=True)
    sources = OUT / 'sources'
    sources.mkdir(exist_ok=True)
    (sources / (result['source_sha256'] + '.py')).write_bytes(Path(__file__).read_bytes())
    (OUT / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    for split, record in result['splits'].items():
        print(split, 'head matches', record['head_argmax_matches_saved_target'], '/', record['rows'],
              'head s', round(record['head_full_batch_seconds'], 3))
        for budget, metrics in record['by_budget'].items():
            print(budget, *(f'{key}={metrics[key]["mean"]:.4f}' for key in ('baseline', 'forced', 'baseline_chain', 'forced_chain')))


if __name__ == '__main__':
    main()
