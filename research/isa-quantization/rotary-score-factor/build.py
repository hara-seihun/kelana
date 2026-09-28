"""Exact FP64 rotary score factor on a two-token source span; screen full captured source rank."""
import hashlib
import json
from pathlib import Path
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
assert hashlib.sha256((FIX/'layer00-self_attn_q_proj.npz').read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
assert hashlib.sha256((FIX/'tokens.npz').read_bytes()).hexdigest()=='0479292cbee2cfc6cfc5f89e8f85dac85d2c0c275ed2704a59a7006faa7d66a2'
with np.load(FIX/'tokens.npz') as tok,np.load(FIX/'layer00-self_attn_q_proj.npz') as f:
    ids=np.concatenate([tok['train'].ravel(),tok['validation'].ravel()]).astype(np.int64)
    x=np.concatenate([f['train'],f['validation']]).astype(np.float64)
assert len(ids)==len(x)==3072
unique,first,reverse=np.unique(ids,return_index=True,return_inverse=True)
source=x[first]
assert len(unique)==len(np.unique(x,axis=0))==1247
assert np.array_equal(source[reverse],x)
# Select the first two distinct actual held tokens in source order, not by score.
with np.load(FIX/'tokens.npz') as tok,np.load(FIX/'layer00-self_attn_q_proj.npz') as f:
    held_ids=tok['validation'].ravel().astype(np.int64)
    chosen=np.array([held_ids[0],held_ids[np.flatnonzero(held_ids!=held_ids[0])[0]]],dtype='<u4')
    anchors=np.stack([f['validation'][np.flatnonzero(held_ids==i)[0]] for i in chosen]).astype(np.float64)
assert np.linalg.matrix_rank(anchors)==2
with safe_open(MODEL,framework='pt',device='cpu') as model:
    q=model.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float().numpy().astype(np.float64)
    k=model.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float().numpy().astype(np.float64)
    gamma_q=model.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy().astype(np.float64)
    gamma_k=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float().numpy().astype(np.float64)
with np.load(FIX/'layer00-self_attn_q_proj.npz') as f:
    assert np.array_equal(q[:128].astype(np.float32),f['weight'][:128])
q0=anchors@q[:128].T;q1=anchors@q[128:256].T;kb=anchors@k.T
basis=(q0,q1,kb)
# Three symmetric quadratic forms: one per Q head, one for their shared K.
gram=np.stack([np.array([(b[0]@b[0]),(b[0]@b[1]),(b[1]@b[1])]) for b in basis])
angles=np.arange(256,dtype=np.float64)[:,None]/(1_000_000.**(np.arange(64,dtype=np.float64)[None,:]/64))
cos=np.cos(angles);sin=np.sin(angles)
coeff=np.empty((2,256,2,2),dtype=np.float64)
for h,qb in enumerate((q0,q1)):
    qx=qb[:,:64]*gamma_q[:64];qy=qb[:,64:]*gamma_q[64:]
    kx=kb[:,:64]*gamma_k[:64];ky=kb[:,64:]*gamma_k[64:]
    for a in range(2):
        for b in range(2):
            c=qx[a]*kx[b]+qy[a]*ky[b]
            s=qx[a]*ky[b]-qy[a]*kx[b]
            coeff[h,:,a,b]=(cos@c+sin@s)/np.sqrt(128)
image=chosen.tobytes()+gram.astype('<f8').tobytes()+coeff.astype('<f8').tobytes()
assert len(image)==8+72+16384==16464
(HERE/'score-image.bin').write_bytes(image)
# A stronger conventional control on the same continuous 2D source carries
# three actual 128x2 projected maps, with gamma baked, and the same norm Gram.
span_basis=np.stack([q0*gamma_q,q1*gamma_q,kb*gamma_k])
span_image=chosen.tobytes()+gram.astype('<f8').tobytes()+span_basis.astype('<f8').tobytes()
assert len(span_image)==8+72+6144==6224
(HERE/'span-qk-image.bin').write_bytes(span_image)
# Source rank screen uses the actual BF16-rounded observer normalization.
# A nonzero modular minor of the float32 dyadic labels is an exact rational
# rank witness, rather than merely a threshold on singular values.
import torch
torch.set_num_threads(1)
prime=2147483647

def modular_rank(values):
    dimension=values.shape[1]
    assert len(values)>=dimension
    sample=values[:dimension].astype(np.float32)
    residue=np.array([[num*pow(den,-1,prime)%prime for num,den in (float(v).as_integer_ratio() for v in row)] for row in sample],dtype=np.int64)
    rank=0
    for col in range(dimension):
        candidates=np.flatnonzero(residue[rank:,col])
        if len(candidates)==0:continue
        index=rank+int(candidates[0])
        residue[[rank,index]]=residue[[index,rank]]
        residue[rank]=residue[rank]*pow(int(residue[rank,col]),prime-2,prime)%prime
        if rank+1<dimension:
            factors=residue[rank+1:,col].copy()
            residue[rank+1:]=(residue[rank+1:]-factors[:,None]*residue[rank])%prime
        rank+=1
        if rank==dimension:break
    return rank

under={};norm_labels={}
for name,w,g in (('q0',q[:128],gamma_q),('q1',q[128:256],gamma_q),('k',k,gamma_k)):
    raw=(torch.from_numpy(source.astype(np.float32))@torch.from_numpy(w.astype(np.float32)).T).to(torch.bfloat16).float()
    z=raw*torch.rsqrt(raw.square().mean(-1,keepdim=True)+1e-6)
    norm=(z.to(torch.bfloat16).float()*torch.from_numpy(g.astype(np.float32)).to(torch.bfloat16).float()).numpy().astype(np.float64)
    singular=np.linalg.svd(norm,full_matrices=False,compute_uv=False)
    norm_labels[name]=norm[:129].astype(np.float32)
    under[name]={'columns':128,'exact_dyadic_rank_lower_bound_mod_2147483647':modular_rank(norm),
                 'rank_witness_first_unique_token_ids':unique[:128].tolist(),
                 'rank_at_relative_threshold_1e-10':int(np.sum(singular>singular[0]*1e-10)),
                 'largest_singular':float(singular[0]),'smallest_singular':float(singular[-1]),
                 'condition_number':float(singular[0]/singular[-1])}
# Genuine length-two causal odds: query x at position 1, prior key y at
# position 0, and the self key x at position 1. Subtracting odds for prior
# y versus a fixed prior y0 cancels the self score and any query-row shift.
# K labels have affine dimension 128 (129x129 augmented minor); both rotated
# Q labels span 128, so the centered prior-key score matrix has rank 128.
angle=1/(1_000_000.**(torch.arange(64,dtype=torch.float32)/64))
cos=angle.cos().to(torch.bfloat16).float();sin=angle.sin().to(torch.bfloat16).float()
causal={}
k_augmented=np.column_stack((norm_labels['k'],np.ones(129,dtype=np.float32)))
causal['shared_key_augmented_rank_mod_prime']=modular_rank(k_augmented)
for name in ('q0','q1'):
    z=torch.from_numpy(norm_labels[name][:128])
    turned=torch.cat((-z[:,64:],z[:,:64]),dim=-1)
    q_at_1=(z*torch.cat((cos,cos))+turned*torch.cat((sin,sin))).numpy()
    causal[f'{name}_position1_rotated_rank_mod_prime']=modular_rank(q_at_1)
assert causal['shared_key_augmented_rank_mod_prime']==129
assert all(causal[f'{name}_position1_rotated_rank_mod_prime']==128 for name in ('q0','q1'))
causal['centered_length2_prior_key_score_rank_exact']=128
causal['source_ids_in_key_affine_minor']=unique[:129].tolist()
causal['query_ids_in_rotated_minor']=unique[:128].tolist()
receipt={'image_sha256':hashlib.sha256(image).hexdigest(),'image_bytes':len(image),
         'span_qk_image_sha256':hashlib.sha256(span_image).hexdigest(),'span_qk_image_bytes':len(span_image),
         'span_qk_three_projected_maps_bytes':6144,'score_modes':256,
         'selected_token_ids':chosen.tolist(),'source_unique_token_ids':len(unique),'source_positions':len(ids),
         'full_source_vocab_size':151936,'captured_source_normalized_ranks':under,
         'source_anchor_rank':2,'norm_gram_bytes':72,'source_label_id_bytes':8,'relative_score_coefficients_bytes':16384,
         'causal_length2_odds_rank_witness':causal}
(HERE/'build.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
