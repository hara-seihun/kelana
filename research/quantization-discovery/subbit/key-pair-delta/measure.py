#!/usr/bin/env python3
"""Train a paired temporal key alphabet; replay its direct-score coordinate."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import networkx as nx
import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parent.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('prior', ROOT / 'key-delta-parallel/measure.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
paid, finite = prior.paid, prior.finite


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def codes_for(layer, split, weights, gamma, nibble):
    x = finite.load_capture(layer, split).reshape(-1, 256, 1024)
    _, k = paid.projected(x, weights, gamma)
    result = []
    for group, row in enumerate(nibble['groups']):
        idx = row['mask'] + [i + 64 for i in row['mask']]
        selected = nibble['group_arms_selected_by_train']['coordinate'][group]
        arm = row['int4'][selected + '_coordinate']
        center = torch.tensor(row['train_center']).reshape(1, 1, 1, 32) if selected == 'centered' else 0
        step = torch.tensor(arm['steps']).reshape(1, 1, 1, 32)
        result.append(((k[:, group:group+1, :, idx] - center) / step).round().clamp(-7, 7).to(torch.int8).squeeze(1).numpy())
    return np.stack(result, axis=1)


def transition(c):
    blocks = c.reshape(c.shape[0], 8, 8, 32, 32).astype(np.int16)
    return blocks[:, :, :, 1:, :] - blocks[:, :, :, :-1, :]


def pair_counts(d, a, b):
    index = (d[..., a] + 14) * 29 + (d[..., b] + 14)
    return np.bincount(index.ravel(), minlength=841)


def matching_and_tables(train, bits, optimized):
    pairs = []
    tables = []
    for group in range(8):
        d = train[:, group]
        counts = {}
        for a in range(32):
            for b in range(a + 1, 32):
                c = pair_counts(d, a, b)
                counts[a, b] = c
        if optimized:
            graph = nx.Graph()
            graph.add_nodes_from(range(32))
            for (a, b), count in counts.items():
                top = np.sort(count)[-(1 << bits) + 1:].sum()
                graph.add_edge(a, b, weight=int(top) * 1_000_000 + (31-a)*32 + 31-b)
            edges = sorted(tuple(sorted(pair)) for pair in nx.max_weight_matching(graph, maxcardinality=True))
        else:
            edges = [(i, i+1) for i in range(0, 32, 2)]
        pairs.append(edges)
        tables.append([])
        for a, b in edges:
            count = counts[a, b]
            # Fixed tie rule, and no validation-derived symbol choice.
            labels = sorted(range(841), key=lambda code: (-int(count[code]), code))[:(1 << bits)-1]
            tables[-1].append(labels)
    return pairs, tables


def pack_bits(values, bits):
    out = bytearray((len(values) * bits + 7)//8)
    for i, value in enumerate(values):
        offset = i * bits
        word = int(value) << (offset & 7)
        p = offset >> 3
        for j in range((bits + (offset & 7) + 7)//8):
            out[p+j] |= (word >> (8*j)) & 255
    return bytes(out)


def unpack_bits(data, count, bits):
    return [(int.from_bytes(data[(i*bits)//8:(i*bits)//8+3], 'little') >> ((i*bits) & 7)) & ((1 << bits)-1)
            for i in range(count)]


def replay(held, pairs, tables, bits):
    d = transition(held)
    total = 0
    escapes = 0
    payload = hashlib.sha256()
    per_window = [0] * held.shape[0]
    escape_by_group = [0] * 8
    # One fixed-width symbol row per key; escapes are a separate block-local bitstream.
    for w in range(held.shape[0]):
        for g in range(8):
            lookup = [{code: label for label, code in enumerate(table)} for table in tables[g]]
            for block in range(8):
                first = held[w, g, 32*block].astype(np.int16)
                anchor = pack_bits(first + 7, 4)
                codes = []
                escaped = []
                for key in range(1, 32):
                    row = []
                    for j, (a, b) in enumerate(pairs[g]):
                        va, vb = map(int, (d[w, g, block, key-1, a], d[w, g, block, key-1, b]))
                        code = (va+14)*29+vb+14
                        label = lookup[j].get(code, (1 << bits)-1)
                        row.append(label)
                        if label == (1 << bits)-1:
                            escaped.append((va+14)*29+vb+14)
                            escapes += 1
                            escape_by_group[g] += 1
                        else:
                            assert tables[g][j][label] == code
                    codes.append(pack_bits(row, bits))
                # A pair of signed-five differences fits ten bits. Parsing these
                # two planes uses no previous decoded vector, only escape ranks.
                escape_bits = [((v // 29) << 5) | (v % 29) for v in escaped]
                escape_stream = pack_bits(escape_bits, 10)
                decoded_escapes = unpack_bits(escape_stream, len(escaped), 10)
                assert decoded_escapes == escape_bits
                recovered = np.zeros((32, 32), dtype=np.int16)
                recovered[0] = np.array(unpack_bits(anchor, 32, 4), dtype=np.int16)-7
                cursor = 0
                for key, row_bytes in enumerate(codes, 1):
                    labels = unpack_bits(row_bytes, 16, bits)
                    for j, (a, b) in enumerate(pairs[g]):
                        if labels[j] == (1 << bits)-1:
                            word = decoded_escapes[cursor]
                            cursor += 1
                            va, vb = (word >> 5)-14, (word & 31)-14
                        else:
                            symbol = tables[g][j][labels[j]]
                            va, vb = symbol//29-14, symbol%29-14
                        recovered[key, a] = recovered[key-1, a] + va
                        recovered[key, b] = recovered[key-1, b] + vb
                assert cursor == len(escaped)
                assert np.array_equal(recovered, held[w, g, 32*block:32*(block+1)])
                stream = anchor + b''.join(codes) + escape_stream
                payload.update(stream)
                size = len(stream) + 4
                total += size
                per_window[w] += size
    return {'bytes': total, 'bytes_per_token': total / (held.shape[0]*256),
            'escapes': escapes, 'escape_by_group': escape_by_group,
            'per_window_bytes': per_window, 'payload_sha256': payload.hexdigest(),
            'dictionary_bytes': 8*16*((1 << bits)-1)*2 + 8*32}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer', required=True, type=int, choices=(0, 14))
    ap.add_argument('--output', required=True, type=Path)
    args = ap.parse_args()
    torch.set_num_threads(4)
    layer = args.layer
    suffix = f'layer{layer:02d}'
    nibble_path = DATA / f'key-nibble-cache/{suffix}.json'
    nibble = json.loads(nibble_path.read_text())
    parent_receipt = DATA / f'key-delta-parallel/{suffix}.json'
    q_path = DATA / f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA / f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        weights = {n: model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    prior_receipt = json.loads((DATA/f'paid-qk-cache-slack/{suffix}.json').read_text())
    gamma = torch.tensor(prior_receipt['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    train = codes_for(layer, 'train', weights, gamma, nibble)[:8]
    held = codes_for(layer, 'validation', weights, gamma, nibble)[:4]
    arms = {}
    for bits in (5, 6):
        for optimized in (False, True):
            pairs, tables = matching_and_tables(transition(train), bits, optimized)
            arm = replay(held, pairs, tables, bits)
            arm['pairs'] = pairs
            arm['tables'] = tables
            arms[f'{bits}bit_{"matched" if optimized else "adjacent"}'] = arm
            print(layer, bits, optimized, arm['bytes'], arm['escapes'], flush=True)
    report = {'layer': layer, 'contract': 'Eight original-producer train windows choose pair matching and per-pair top-symbol tables; four separate repeatedly inspected original-producer validation windows test exact frozen paid signed-nibble K codes. Each 32-key block is independently addressable.',
              'arms': arms, 'parent_split_bytes': json.loads(parent_receipt.read_text())['bytes_including_offsets'],
              'static_mixed_bytes': 112*1024, 'source_sha256': digest(Path(__file__)),
              'parent_source_sha256': digest(ROOT/'key-delta-parallel/measure.py'),
              'parent_receipt_sha256': digest(parent_receipt), 'model_sha256': digest(finite.MODEL),
              'train_capture_sha256': digest(finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'paid_q_sha256': digest(q_path), 'paid_k_sha256': digest(k_path),
              'nibble_receipt_sha256': digest(nibble_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
