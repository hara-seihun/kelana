#!/usr/bin/env python3
"""Block-adaptive placement of the one short K-difference microstream."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parent.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('frontier', ROOT/'key-segment-frontier/measure.py')
frontier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frontier)
parent = frontier.parent


def boundaries(rows, short_position):
    count = (30 + rows)//rows
    assert count*rows == 32
    widths = [rows]*count
    widths[short_position] -= 1
    return np.cumsum(widths).tolist()


def run(layer):
    torch.set_num_threads(4)
    suffix = f'layer{layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(parent.finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        weights = {name:model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = parent.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = parent.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    train = parent.image(layer,'train',8,weights,gamma,nibble)
    held = parent.image(layer,'validation',4,weights,gamma,nibble)
    tr = parent.differences(train,32)
    hd = parent.differences(held,32)
    arms = {}
    for rows, field_bits in ((4,6),(8,8)):
        count = 32//rows
        per_window = np.zeros((4,6),dtype=np.int64) # last, oracle, selector-byte, packed-selector, first, train-fixed
        selectors = np.zeros((4,count),dtype=np.int64)
        selected = np.zeros((4,8,8),dtype=np.uint8)
        train_choices = []
        exceptional = np.zeros((4,2),dtype=np.int64)
        stream_hash = hashlib.sha256()
        for g in range(8):
            hist = np.bincount((tr[:,g]+15).ravel(),minlength=31)
            lengths, mapping = parent.entropy.canonical(hist)
            costs = frontier.segment_bytes(hd[:,g],np.asarray(lengths))
            train_costs = frontier.segment_bytes(tr[:,g].reshape(-1,31,32),np.asarray(lengths))
            training_totals = []
            sentinel = (1<<field_bits)-1
            for choice in range(count):
                ends = boundaries(rows,choice)
                starts = [0]+ends[:-1]
                training_totals.append(sum(int(train_costs[a,z].sum()) for a,z in zip(starts,ends))
                                       + sum(2*int((train_costs[a,z]>=sentinel).sum())
                                             for a,z in zip(starts[:-1],ends[:-1])))
            train_choices.append(int(np.argmin(training_totals)))
            for w in range(4):
                for b in range(8):
                    lengths_by_choice = []
                    for choice in range(count):
                        ends = boundaries(rows,choice)
                        start = 0
                        chunks = []
                        for end in ends:
                            piece = hd[w,g,b,start:end]
                            raw = parent.entropy.roundtrip((piece+15).ravel(),mapping)
                            assert len(raw) == costs[start,end][w,b]
                            if w == 0 and b == 0:
                                assert np.array_equal(parent.decode(raw,mapping,piece.size).reshape(piece.shape),piece)
                            chunks.append(raw)
                            start = end
                        encoded, escape = frontier.record(chunks,field_bits)
                        lengths_by_choice.append((encoded,choice,escape,chunks))
                    fixed_len,_,fixed_escape,_ = lengths_by_choice[-1]
                    best_len,choice,best_escape,chunks = min(lengths_by_choice,key=lambda x:(x[0],x[1]))
                    per_window[w] += (20+fixed_len,20+best_len,21+best_len,20+best_len,
                                      20+lengths_by_choice[0][0],20+lengths_by_choice[train_choices[-1]][0])
                    exceptional[w] += (fixed_escape,best_escape)
                    selectors[w,choice] += 1
                    selected[w,g,b] = choice
                    # Reconstruct all signed-nibble key rows, then compare the
                    # direct two-head integer score prefix against the original.
                    delta = np.concatenate([parent.decode(raw,mapping,32*(end-start)).reshape(end-start,32)
                                            for raw,start,end in zip(chunks,[0]+boundaries(rows,choice)[:-1],boundaries(rows,choice))])
                    assert np.array_equal(delta,hd[w,g,b])
                    reconstructed = np.cumsum(delta.astype(np.int16),axis=0)
                    assert np.array_equal(reconstructed,np.cumsum(hd[w,g,b].astype(np.int16),axis=0))
                    stream_hash.update(bytes([choice]))
                    for raw in chunks:
                        stream_hash.update(len(raw).to_bytes(2,'little'))
                        stream_hash.update(raw)
        # A separately addressed selector slab reserves all eight block entries
        # per group/window, so an append never shifts a prior selector.
        bits = (count-1).bit_length()
        for w in range(4):
            for g in range(8):
                word = 0
                for choice in selected[w,g]:
                    word = (word << bits) | int(choice)
                slab = word.to_bytes(8*bits//8,'big')
                recovered = [(int.from_bytes(slab,'big') >> (bits*(7-i))) & ((1<<bits)-1)
                             for i in range(8)]
                assert recovered == selected[w,g].tolist()
                per_window[w,3] += len(slab)
        table_bytes = 155
        arms[str(rows)] = {'maximum_symbols_per_parser':32*rows,'selector_bits':bits,
                           'train_fixed_short_position_per_group':train_choices,
                           'per_window_bytes':per_window.tolist(),
                           'per_window_exceptions':exceptional.tolist(),'selector_histogram':selectors.tolist(),
                           'table_bytes':table_bytes,'total_fixed_bytes':int(per_window[:,0].sum())+table_bytes,
                           'total_oracle_bytes':int(per_window[:,1].sum())+table_bytes,
                           'total_selector_byte_bytes':int(per_window[:,2].sum())+table_bytes,
                           'total_packed_selector_bytes':int(per_window[:,3].sum())+table_bytes,
                           'total_first_bytes':int(per_window[:,4].sum())+table_bytes,
                           'total_train_fixed_bytes':int(per_window[:,5].sum())+table_bytes+bits,
                           'stream_sha256':stream_hash.hexdigest()}
    result = {'layer':layer,'restart':32,'train_windows':8,'held_windows':4,'arms':arms,
              'source_sha256':parent.sha(Path(__file__)),
              'parent_source_sha256':parent.sha(ROOT/'key-segment-frontier/measure.py'),
              'model_sha256':parent.sha(parent.finite.MODEL),
              'capture_sha256':parent.sha(parent.finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'nibble_sha256':parent.sha(nibble_path),'prior_sha256':parent.sha(prior_path),
              'paid_q_sha256':parent.sha(q_path),'paid_k_sha256':parent.sha(k_path)}
    out = DATA/f'key-segment-dynamic/{suffix}.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'rates':{k:[v[name]/1024 for name in ('total_fixed_bytes','total_oracle_bytes','total_selector_byte_bytes','total_packed_selector_bytes','total_first_bytes','total_train_fixed_bytes')] for k,v in arms.items()}}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    run(parser.parse_args().layer)
