#!/usr/bin/env python3
"""Score stock GGUF weights on the exact Qwen pilot tokens and BF16 backend."""
import argparse
import json
import math
from pathlib import Path
import re
import sys
import time

import numpy as np
import torch
from transformers import AutoTokenizer

from stock_gguf import ROOT, FILES, GGUF_SOURCE, sha
RESEARCH = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RESEARCH / 'ternary'))
from pilot import MODEL, load_model
DATA = ROOT.parent.parent
FIXTURE = DATA / 'ternary/expanded-tokens.npz'


def parameter_name(name):
    top = {'token_embd.weight': 'model.embed_tokens.weight', 'output.weight': 'lm_head.weight',
           'output_norm.weight': 'model.norm.weight'}
    if name in top:
        return top[name]
    match = re.fullmatch(r'blk\.(\d+)\.(.+)\.weight', name)
    if not match:
        raise ValueError('unknown GGUF tensor ' + name)
    layer, member = match.groups()
    members = {'attn_q': 'self_attn.q_proj', 'attn_k': 'self_attn.k_proj',
               'attn_v': 'self_attn.v_proj', 'attn_output': 'self_attn.o_proj',
               'attn_q_norm': 'self_attn.q_norm', 'attn_k_norm': 'self_attn.k_norm',
               'attn_norm': 'input_layernorm', 'ffn_norm': 'post_attention_layernorm',
               'ffn_gate': 'mlp.gate_proj', 'ffn_up': 'mlp.up_proj', 'ffn_down': 'mlp.down_proj'}
    return f'model.layers.{layer}.{members[member]}.weight'


@torch.inference_mode()
def run(args):
    sys.path.insert(0, str(args.gguf_source))
    import gguf
    path = ROOT / FILES[args.name][0]
    label = args.label or args.name
    if not re.fullmatch(r'[A-Za-z0-9_-]+', label):
        raise ValueError('panel label must be a single filename component')
    destination = ROOT / f'{label}-{args.split}-{args.offset}-{args.windows}.json'
    if destination.exists():
        raise FileExistsError(destination)
    if path.stat().st_size != FILES[args.name][1] or sha(path) != FILES[args.name][2]:
        raise ValueError('stock file changed')
    census = json.loads(path.with_suffix('.tensors.json').read_text())
    reader = gguf.GGUFReader(path)
    fields = reader.fields
    model = load_model()
    architecture = {k:fields[k].contents() for k in ('general.architecture', 'qwen3.embedding_length',
        'qwen3.attention.head_count', 'qwen3.attention.head_count_kv', 'qwen3.rope.freq_base',
        'qwen3.attention.layer_norm_rms_epsilon')}
    expected = {'general.architecture':'qwen3','qwen3.embedding_length':model.config.hidden_size,
        'qwen3.attention.head_count':model.config.num_attention_heads,
        'qwen3.attention.head_count_kv':model.config.num_key_value_heads,
        'qwen3.rope.freq_base':model.config.rope_theta}
    for key, value in expected.items():
        if architecture[key] != value:
            raise ValueError(f'architecture mismatch {key}')
    if not math.isclose(architecture['qwen3.attention.layer_norm_rms_epsilon'], model.config.rms_norm_eps, rel_tol=1e-6):
        raise ValueError('norm epsilon mismatch')
    with np.load(FIXTURE) as fixture:
        rows = fixture[args.split][args.offset:args.offset + args.windows].copy()
    if rows.shape != (args.windows, 256):
        raise ValueError('incomplete token panel')
    tokenizer = AutoTokenizer.from_pretrained(MODEL, local_files_only=True)
    tokens = fields['tokenizer.ggml.tokens'].contents()
    vocabulary = tokenizer.get_vocab()
    mismatch = [(token, index) for token, index in vocabulary.items() if index >= len(tokens) or tokens[index] != token]
    if mismatch:
        raise ValueError(f'GGUF token IDs differ: {mismatch[:5]}')
    # The stock image stores output separately, frequently at a different quantization.
    # Keeping HF's tie would silently discard one stock image and change the comparison.
    if any(t.name == 'output.weight' for t in reader.tensors):
        model.lm_head.weight = torch.nn.Parameter(torch.empty_like(model.model.embed_tokens.weight), requires_grad=False)
        model.config.tie_word_embeddings = False
    params = dict(model.named_parameters())
    mapped = [parameter_name(t.name) for t in reader.tensors]
    if len(mapped) != len(set(mapped)) or set(mapped) != set(params):
        raise ValueError('GGUF tensor coverage does not equal the complete model parameters')
    audit = []
    norms = 0
    for tensor, key in zip(reader.tensors, mapped):
        decoded = gguf.quants.dequantize(tensor.data, tensor.tensor_type)
        weight = torch.from_numpy(np.array(decoded, dtype=np.float32, copy=True))
        if weight.shape != params[key].shape or not torch.isfinite(weight).all():
            raise ValueError('decoded tensor geometry/value mismatch ' + key)
        if weight.ndim == 1:
            reference = params[key].float().cpu()
            if not torch.equal(weight, reference):
                raise ValueError('unquantized norm differs from pinned BF16 source ' + key)
            norms += 1
        if key in ('model.layers.0.self_attn.q_proj.weight','model.layers.0.self_attn.k_proj.weight',
                   'model.layers.14.mlp.gate_proj.weight'):
            reference = params[key].float().cpu()
            relative = float(torch.linalg.vector_norm(weight-reference) / torch.linalg.vector_norm(reference))
            if relative > .8:
                raise ValueError('unexpected weight discrepancy; inspect conversion layout')
            audit.append(dict(key=key, weight_relative_rms=relative))
        params[key].copy_(weight)
        del weight, decoded
    losses = []
    for i, row in enumerate(rows):
        x = torch.tensor(row, device='cuda', dtype=torch.long)[None]
        logits = model(x, use_cache=False).logits[:, :-1].float()
        loss = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]), x[:,1:].reshape(-1), reduction='sum')
        losses.append(dict(index=args.offset+i, predictions=255, nll_sum=float(loss)))
        del logits
    nll = sum(x['nll_sum'] for x in losses) / (255 * len(losses))
    result = dict(stock=args.name, panel_label=label, gguf_sha256=sha(path), census_sha256=sha(path.with_suffix('.tensors.json')),
        architecture=architecture, matched_token_strings=len(vocabulary), exact_norm_tensors=norms,
        source_model_sha256=sha(MODEL/'source.json'), fixture_sha256=sha(FIXTURE), source_weight_audit=audit,
        untied_output=model.lm_head.weight.data_ptr() != model.model.embed_tokens.weight.data_ptr(),
        decoder_sha256=sha(args.gguf_source/'gguf/quants.py'), reader_sha256=sha(args.gguf_source/'gguf/gguf_reader.py'),
        script_sha256=sha(Path(__file__)), split=args.split, offset=args.offset, windows=losses,
        nll=nll, perplexity=math.exp(nll), file_bytes=census['file_bytes'],
        payload_bytes=census['tensor_payload_bytes'], bpw_per_source_unique=census['payload_bpw_per_source_unique'],
        bpw_per_stored_element=census['payload_bpw_per_stored_element'],
        execution='Stock weights decoded to BF16 in the same HF SDPA forward as local images. Stock separate output preserved. Not native GGUF kernel perplexity or speed.')
    partial = destination.with_suffix('.json.partial')
    partial.write_text(json.dumps(result,indent=2)+'\n');partial.rename(destination)
    print(json.dumps(dict(receipt=str(destination),nll=nll,perplexity=math.exp(nll),
                         payload_bytes=result['payload_bytes'],bpw=result['bpw_per_source_unique'])),flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--name', choices=FILES, required=True)
    p.add_argument('--gguf-source', type=Path, default=GGUF_SOURCE)
    p.add_argument('--label', help='fresh receipt label for an independent repeat')
    p.add_argument('--split', choices=['validation','test'], default='test')
    p.add_argument('--offset', type=int, default=0)
    p.add_argument('--windows', type=int, default=32)
    a = p.parse_args()
    if a.offset < 0 or a.windows < 1:p.error('invalid panel')
    torch.set_num_threads(2);torch.backends.cuda.matmul.allow_tf32=False
    run(a)
