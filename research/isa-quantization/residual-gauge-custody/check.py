"""Exact modular-rank obstruction for a tied diagonal-head residual gauge."""
import hashlib
import json
from collections import defaultdict
from pathlib import Path
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
SHA='f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b'
PRIME=65521
SCALE=2**32


def dyadic_integer(tensor):
    array=tensor.float().numpy().astype(np.float64)
    scaled=array*SCALE
    assert np.all(np.isfinite(scaled)) and np.max(np.abs(scaled))<2**53
    assert np.array_equal(scaled,np.rint(scaled)), 'source not exact on 2^-32 lattice'
    return np.rint(scaled).astype(np.int64)


def modular_rank(matrix):
    a=np.mod(matrix,PRIME).copy()
    rows,cols=a.shape
    r=0
    for col in range(cols):
        if r==rows: break
        indices=np.flatnonzero(a[r:,col])
        if not indices.size: continue
        pivot=r+int(indices[0])
        if pivot!=r: a[[r,pivot]]=a[[pivot,r]]
        inv=pow(int(a[r,col]),-1,PRIME)
        a[r,col:]=(a[r,col:]*inv)%PRIME
        if r+1<rows:
            a[r+1:,col:]=(a[r+1:,col:]-a[r+1:,col,None]*a[r,col:])%PRIME
        r+=1
    return r


def main():
    digest=hashlib.sha256()
    with MODEL.open('rb') as f:
        for chunk in iter(lambda:f.read(4*1024*1024),b''):digest.update(chunk)
    assert digest.hexdigest()==SHA
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        gamma=f.get_tensor('model.norm.weight').float().numpy()
        input_gamma=f.get_tensor('model.layers.0.input_layernorm.weight').float().numpy()
        head=dyadic_integer(f.get_tensor('model.layers.0.self_attn.q_proj.weight')[:128])
        embedding=dyadic_integer(f.get_tensor('model.embed_tokens.weight')[:1152])
    assert gamma.shape==(1024,) and input_gamma.shape==(1024,)
    assert head.shape==(128,1024) and embedding.shape==(1152,1024)
    assert np.all(gamma!=0) and np.all(input_gamma!=0)
    groups=defaultdict(list)
    for i,value in enumerate(gamma):groups[float(value)].append(i)
    ranks={str(key):modular_rank(head[:,indices]) for key,indices in groups.items()}
    assert all(ranks[str(key)]==len(indices) for key,indices in groups.items())
    rank_embedding=modular_rank(embedding)
    ones=np.full((embedding.shape[0],1),SCALE,dtype=np.int64)
    rank_with_ones=modular_rank(np.concatenate((embedding,ones),axis=1))
    assert rank_embedding==1024 and rank_with_ones==1025
    result={'model_sha256':SHA,'source_scale_exponent':32,'modulus_prime':PRIME,
            'first_q_head_shape':[128,1024],
            'final_gamma_unique_values':len(groups),
            'final_gamma_largest_equal_value_class':max(map(len,groups.values())),
            'final_gamma_singleton_classes':sum(len(v)==1 for v in groups.values()),
            'sum_exact_lower_ranks':sum(ranks.values()),
            'all_gamma_class_submatrices_full_column_rank':True,
            'embedding_rows_checked':1152,'embedding_rank_lower':rank_embedding,
            'embedding_augmented_ones_rank_lower':rank_with_ones,
            'fixed_group128_q4_one_head_nominal_code_bytes_saved_if_slice128':57344,
            'fixed_group128_q4_one_head_nominal_grid_bytes_saved_if_slice128':3584}
    (HERE/'verified.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
