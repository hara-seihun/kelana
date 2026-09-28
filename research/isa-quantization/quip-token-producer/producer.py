"""Exact source map: token embedding -> layer-0 input RMSNorm -> q_proj input."""
from pathlib import Path
import hashlib
import json
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')


def normalize(e,norm):
    x=e.float()
    # FP64 accumulation, then FP32 variance, matches the captured GPU
    # reduction at BF16 rounding boundaries; normalized arithmetic stays FP32.
    variance=x.double().square().mean(-1,keepdim=True).float()+1e-6
    return ((x*torch.rsqrt(variance)).to(e.dtype)*norm).float()


def main():
    with np.load(FIX/'tokens.npz') as tok, np.load(FIX/'layer00-self_attn_q_proj.npz') as f, safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as checkpoint:
        emb=checkpoint.get_tensor('model.embed_tokens.weight')
        norm=checkpoint.get_tensor('model.layers.0.input_layernorm.weight')
        results={}
        for split,key in (('train','train'),('validation','validation')):
            ids=tok[split].ravel().astype(np.int64)
            actual=f[key]
            predicted=normalize(emb[torch.from_numpy(ids)],norm).numpy()
            mismatch=np.count_nonzero(predicted.view(np.uint32)!=actual.view(np.uint32))
            results[split]={'positions':len(ids),'unique_token_ids':len(np.unique(ids)),
                            'bitwise_unequal_float32_values':int(mismatch),
                            'max_abs_difference':float(np.max(np.abs(predicted-actual))),
                            'mean_squared_difference':float(np.mean((predicted.astype(float)-actual.astype(float))**2))}
        results['source']={'model_revision':'c1899de289a04d12100db370d81485cdf75e47ca',
                           'model_safetensors_sha256':'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b',
                           'tokens_sha256':hashlib.sha256((FIX/'tokens.npz').read_bytes()).hexdigest(),
                           'fixture_sha256':hashlib.sha256((FIX/'layer00-self_attn_q_proj.npz').read_bytes()).hexdigest(),
                           'embedding_shape':list(emb.shape),'embedding_dtype':str(emb.dtype),
                           'norm_shape':list(norm.shape),'norm_dtype':str(norm.dtype),
                           'construction':'embedding[token_id] -> FP64 sum of BF16-square values cast to FP32 variance -> FP32 rsqrt/multiply -> BF16 cast -> BF16 gamma multiply -> float32 export'}
    (HERE/'producer-results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2))

if __name__=='__main__':main()
