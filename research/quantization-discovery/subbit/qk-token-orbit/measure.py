#!/usr/bin/env python3
"""Price exact first-layer token-keyed pre-RoPE Q/K reuse on paid Qwen images."""
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
SUBBIT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
MODEL = DATA / 'models/qwen3-0.6b/model.safetensors'
CAPTURE = DATA / 'full-model/capture/layer00.npz'
TOKENS = DATA / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
IMAGES = {name: DATA / f'full-model/image-binary055-refined/layer00-self_attn_{name}_proj.npz' for name in ('q', 'k')}
MASKS = DATA / 'paid-qk-plane-allocation/layer00.json'
OUTPUT = DATA / 'qk-token-orbit/receipt.json'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def load_helper():
    spec = importlib.util.spec_from_file_location('narrow_value_measure', SUBBIT / 'value-observer/measure.py')
    # The helper's local imports live in its own directory.
    import sys
    sys.path.insert(0, str(SUBBIT / 'value-observer'))
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper


def main():
    torch.set_num_threads(4)
    helper = load_helper()
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        norms = {name: model.get_tensor(f'model.layers.0.self_attn.{name}_norm.weight').clone()
                 for name in ('q', 'k')}
    weights = {name: helper.binary_weight(path).to(torch.bfloat16).float() for name, path in IMAGES.items()}
    rank = {}
    for name, path in IMAGES.items():
        with np.load(path) as image:
            n, k, r = [int(x) for x in image['dimensions']]
            rank[name] = dict(outputs=n, inputs=k, rank=r, factor_terms=r*(n+k))
    with np.load(CAPTURE) as capture, np.load(TOKENS) as fixture:
        token_rows = fixture['validation'].copy()
        bits = capture['validation_qkv'].reshape(4, 256, 1024).copy()
    masks = json.loads(MASKS.read_text())['selected_masks']
    assert sum(map(len, masks)) == 112
    windows = []
    for wid, (tokens, input_bits) in enumerate(zip(token_rows, bits)):
        first = {}
        indices = []
        for i, token in enumerate(tokens):
            indices.append(first.setdefault(int(token), i))
        distinct = sorted(set(indices))
        assert all(np.array_equal(input_bits[i], input_bits[indices[i]]) for i in range(256))
        x = torch.from_numpy(input_bits.view(np.uint16).copy().view(np.int16)).view(torch.bfloat16).float()
        unique = x[distinct]
        window = dict(window=wid, keys=256, distinct_tokens=len(distinct), hits=256-len(distinct),
                      token_sha256=hashlib.sha256(tokens.tobytes()).hexdigest(),
                      input_bits_sha256=hashlib.sha256(input_bits.tobytes()).hexdigest())
        selected_bytes = bytearray()
        rotated_first_mismatches = {}
        for name in ('q', 'k'):
            nheads = 16 if name == 'q' else 8
            # Exactly the paid-image BF16 matmul boundary and head RMSNorm from the causal Q/K replay.
            def pre_rope(source):
                projected = (source @ weights[name].T).to(torch.bfloat16).float().reshape(-1, nheads, 128)
                normalized = helper.rms(projected, norms[name])
                assert torch.equal(normalized, normalized.to(torch.bfloat16).float())
                return normalized.to(torch.bfloat16)
            whole = pre_rope(x)
            memo = pre_rope(unique)[torch.tensor([distinct.index(j) for j in indices])]
            assert torch.equal(whole.view(torch.int16), memo.view(torch.int16))
            window[f'{name}_pre_rope_sha256'] = hashlib.sha256(whole.view(torch.int16).numpy().tobytes()).hexdigest()
            # Position cannot be memoized. The *same* RoPE operation at the actual key positions
            # produces the same bits from the memoized and full pre-RoPE vectors.
            phase = torch.outer(torch.arange(256).float(), 1/(1_000_000. ** (torch.arange(0, 128, 2).float()/128)))
            phase = torch.cat((phase, phase), dim=-1)
            cosine, sine = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
            def rotate(y):
                y = y.float()
                return y*cosine[:, None, :] + torch.cat((-y[..., 64:], y[..., :64]), -1)*sine[:, None, :]
            rotated = rotate(whole)
            assert torch.equal(rotated.view(torch.int32), rotate(memo).view(torch.int32))
            window[f'{name}_post_rope_sha256'] = hashlib.sha256(rotated.view(torch.int32).numpy().tobytes()).hexdigest()
            first_rotated = rotated[torch.tensor(indices)]
            rotated_first_mismatches[name] = sum(not torch.equal(rotated[i].view(torch.int32), first_rotated[i].view(torch.int32)) for i in range(256) if indices[i] != i)
            # The selected-plane score reader observes just two Q heads and one K head per group.
            # Memoize only those pre-RoPE coordinates, and rotate them at each actual position.
            for group, planes in enumerate(masks):
                heads = (2*group, 2*group+1) if name == 'q' else (group,)
                coords = planes + [p+64 for p in planes]
                selected = memo[:, heads][:, :, coords]
                selected_bytes.extend(selected.view(torch.int16).numpy().tobytes())
                assert torch.equal(whole[:, heads][:, :, coords].view(torch.int16), selected.view(torch.int16))
                assert torch.equal(rotated[:, heads][:, :, coords].view(torch.int32),
                                   rotate(memo)[:, heads][:, :, coords].view(torch.int32))
        window['naive_rotated_hit_mismatches'] = rotated_first_mismatches
        window['selected_pre_rope_sha256'] = hashlib.sha256(selected_bytes).hexdigest()
        windows.append(window)
        print('window', wid, 'hits', window['hits'], flush=True)
    hits = sum(w['hits'] for w in windows)
    saved = {name: hits*info['factor_terms'] for name, info in rank.items()}
    result = dict(domain='Four separate 256-token original-producer Qwen3-0.6B validation windows; paid binary .55 refined Q/K images expanded to BF16; projected BF16 and RMSNorm BF16; position-dependent FP32 RoPE',
                  windows=windows, rank=rank, hits=hits, saved_factor_terms=saved,
                  full_factor_terms={name: 1024*info['factor_terms'] for name, info in rank.items()},
                  memo_bf16_bytes_per_new_token=6144,
                  selected_plane_bf16_bytes_per_new_token=1344,
                  memo_bf16_bytes_total=sum(w['distinct_tokens']*6144 for w in windows),
                  selected_plane_bf16_bytes_total=sum(w['distinct_tokens']*1344 for w in windows),
                  extra_hit_reads_bytes=hits*6144,
                  selected_extra_hit_reads_bytes=hits*1344,
                  artifact_sha256={str(path): sha(path) for path in (CAPTURE, TOKENS, MODEL, MASKS, *IMAGES.values())},
                  source_sha256=sha(Path(__file__)))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2)+'\n')
    print(OUTPUT, saved)


if __name__ == '__main__':
    main()
