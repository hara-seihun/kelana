#!/usr/bin/env python3
"""Consume a learned conditional head as 16-state random functions."""
import importlib.util
import json
import time
from pathlib import Path

import numpy as np
import torch
from pilot import DATA, Drafter, HORIZON, dataset, sha, save_json

spec = importlib.util.spec_from_file_location('finite', Path(__file__).parents[1]/'finite/experiment.py')
finite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(finite)


def main():
    torch.set_num_threads(4)
    state = torch.load(DATA/'conditional-s200.pt', weights_only=True)
    vocab = state['vocabulary']
    model = Drafter(len(vocab), True)
    model.load_state_dict(state)
    model.eval()
    lookup = torch.full((151936,), len(vocab), dtype=torch.long)
    lookup[vocab] = torch.arange(len(vocab))
    x, anchor, _, _ = dataset('test-greedy', lookup, 'cpu')
    rng = np.random.default_rng(76123)
    tables, candidate_tokens = [], []
    paths, max_score_difference, zero_rows = 0, 0., 0
    started = time.perf_counter()
    with torch.inference_mode():
        for h, a in zip(x, anchor):
            base, gate = model.backbone(h[None])
            base, gate = base[0], gate[0]
            candidates = base.topk(16, dim=-1).indices
            cdfs = []
            for t in range(HORIZON):
                prev = a.repeat(16) if t == 0 else candidates[t-1]
                incoming = model.labels(prev)*torch.tanh(gate[t])
                outgoing = model.labels(candidates[t])
                # No vocabulary-sized corrected logits: score candidate pairs directly.
                scores = base[t, candidates[t]][None] + incoming @ outgoing.T / (32**0.5)
                full = model.logits(base[t][None].expand(16, -1), gate[t][None].expand(16, -1), prev)
                max_score_difference = max(max_score_difference,
                    (scores-full[:, candidates[t]]).abs().max().item())
                probabilities = scores.double().softmax(-1)
                cdf = torch.floor(probabilities.cumsum(-1)*256).to(torch.int64)
                cdf[:, -1] = 256
                masses = torch.diff(cdf, prepend=torch.zeros((16,1), dtype=torch.int64), dim=-1)
                assert bool((masses >= 0).all()) and bool((masses.sum(-1) == 256).all())
                zero_rows += int((masses == 0).sum())
                cdfs.append(cdf.numpy())
            cdfs = np.asarray(cdfs)
            tables.append(cdfs.astype(np.uint16))
            candidate_tokens.append(vocab[candidates].numpy())
            # Independent per-position uniforms, shared by all counterfactual predecessors.
            for _ in range(32):
                uniforms = rng.integers(0, 256, HORIZON)
                successors = (uniforms[:, None, None] >= cdfs).sum(-1)
                maps = [finite.pack(row.tolist()) for row in successors]
                serial_prefix = finite.scan_serial(maps)
                tree_prefix = finite.scan_tree(maps)
                direct = []
                current = 0  # First map has identical rows because the anchor is known.
                for row in successors:
                    current = int(row[current])
                    direct.append(current)
                assert direct == [finite.at(m, 0) for m in serial_prefix]
                assert serial_prefix == tree_prefix
                paths += 1
    destination = DATA/'learned-transition-tables.npz'
    np.savez(destination, cdf=np.asarray(tables), tokens=np.asarray(candidate_tokens))
    record = {'source_sha256': sha(__file__), 'pilot_source_sha256': sha(Path(__file__).with_name('pilot.py')),
              'checkpoint_sha256': sha(DATA/'conditional-s200.pt'),
              'contexts': len(x), 'sample_paths': paths, 'path_mismatches': 0,
              'states': 16, 'steps': HORIZON, 'uniform_grid': 256,
              'max_direct_pair_vs_full_score_difference': max_score_difference,
              'zero_mass_entries': zero_rows, 'tables_sha256': sha(destination),
              'python_total_seconds': time.perf_counter()-started,
              'map_payload_bytes_per_context_and_random_stream': HORIZON*8,
              'cdf_payload_bytes_per_context': HORIZON*16*16*2,
              'candidate_id_bytes_per_context': HORIZON*16*4,
              'contract': 'Exact sampling of the declared top16-truncated, 256-grid learned proposal. '
                          'Not identical to full-vocabulary proposal or continuous softmax. '
                          'Target verification would preserve target output; this experiment checks proposal only. '
                          'No throughput claim; Python constructs every counterfactual row.'}
    save_json(DATA/'transition-bridge.json', record)
    sources = DATA/'sources'
    (sources/(sha(__file__)+'.py')).write_bytes(Path(__file__).read_bytes())
    print(json.dumps(record), flush=True)


if __name__ == '__main__':
    main()
