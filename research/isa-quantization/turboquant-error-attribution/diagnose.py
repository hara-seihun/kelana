"""Frozen K/V/interaction and QJL-vs-coarse attribution, no new encoder/fit."""
import hashlib,json,math,sys
import numpy as np
import torch
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'turboquant-coupled-gauge'))
from source import load
old_reader=load('turbo_fixed_reader_for_attribution',ROOT/'turboquant-causal/replay.py')
old_reader.HERE=ROOT/'turboquant-causal'
original_source=load('turbo_fixed_source_for_attribution',ROOT/'turboquant-causal/source.py')
gauged_source=load('turbo_gauged_source_for_attribution',ROOT/'turboquant-coupled-gauge/source.py')

def sha(b):return hashlib.sha256(b).hexdigest()

def run(panel,window,arm):
 assert arm in ('original','gauged')
 torch.set_num_threads(1)
 src=(original_source if arm=='original' else gauged_source).arrays(panel,window)
 folder=ROOT/('turboquant-causal' if arm=='original' else 'turboquant-coupled-gauge')
 m=json.loads((folder/f'{panel}-{window}-manifest.json').read_text())
 frozen=json.loads((folder/f'{panel}-{window}-result.json').read_text())
 raw=(folder/f'{panel}-{window}-final.bin').read_bytes()
 assert len(raw)==188416 and sha(raw)==m['final_sha256']
 meta,K,V,S,c=old_reader.assets()
 assert m['program_sha256']==meta['sha256']==frozen['program_sha256']
 keysource=dict(src)
 if arm=='gauged':keysource['key']=src['gauged_key']
 kr,rr,vr,mse,signs,valuecoords=old_reader.parse(raw,keysource,K,V,S,c)
 q=(src['qrot'] if arm=='original' else src['qrot_new']).numpy().astype(np.float32)
 qs=q@S.T
 coarsekey=kr[...,None]*mse
 decoded_value=torch.from_numpy((vr[...,None]*valuecoords).copy()).permute(1,0,2)
 exact_value=src['vraw']
 assert exact_value.shape==decoded_value.shape==(8,256,128)
 probs=torch.zeros((16,256,256),dtype=torch.float32)
 coarseprobs=torch.zeros_like(probs)
 kl=np.zeros(16);coarsekl=np.zeros(16)
 with torch.no_grad():
  for t in range(256):
   for h in range(16):
    kv=h//2
    a=coarsekey[:t+1,kv]@q[h,t]
    b=(signs[:t+1,kv]@qs[h,t])*(kr[:t+1,kv]*rr[:t+1,kv])*np.float32(np.sqrt(np.pi/2)/128)
    full=torch.from_numpy(((a+b)/math.sqrt(128)).copy()).log_softmax(-1)
    coarse=torch.from_numpy((a/math.sqrt(128)).copy()).log_softmax(-1)
    probs[h,t,:t+1]=full.exp();coarseprobs[h,t,:t+1]=coarse.exp()
    reference=src['teacher_logp'][h,t,:t+1]
    kl[h]+=float((reference.exp()*(reference-full)).sum())
    coarsekl[h]+=float((reference.exp()*(reference-coarse)).sum())
  original_p=src['teacher_logp'].exp()
  o=src['o'].T
  def response(p,v):
   mixed=torch.bmm(p,v.repeat_interleave(2,dim=0))
   return mixed.permute(1,0,2).reshape(256,2048)@o
  target=response(original_p,exact_value)
  target_drift=float((target-src['teacher']).abs().max())
  assert target_drift==0
  k_only=response(probs,exact_value)
  v_only=response(original_p,decoded_value)
  both=response(probs,decoded_value)
  coarse_k_only=response(coarseprobs,exact_value)
  coarse_both=response(coarseprobs,decoded_value)
  teacher_sq=float(target.square().sum())
  def rel(out):return float((out-target).square().sum())/teacher_sq
  E_k=k_only-target;E_v=v_only-target;E_i=both-k_only-v_only+target
  effects=[E_k,E_v,E_i]
  gram=np.asarray([[float((a*b).sum())/teacher_sq for b in effects] for a in effects])
  algebra_gap=float((both-target-sum(effects)).abs().max())
  assert algebra_gap<1e-5
  full_ratio=rel(both)
  paid=frozen['complete_o_sse']/frozen['complete_o_ref_sq']
  # Batched full-O accepts identical causal probabilities/values but can
  # differ at FP32 reduction ordering from the frozen per-query reader.
  result={'panel':panel,'window':window,'arm':arm,'fixture_sha256':original_source.FIX_SHA,
          'image_sha256':m['final_sha256'],'program_sha256':meta['sha256'],
          'gamma_image_sha256':m.get('source_gamma_replacement_sha256') if arm=='gauged' else None,
          'teacher_square':teacher_sq,'source_teacher_max_abs':target_drift,
          'frozen_paid_full_o_rel_sq':paid,'diagnostic_batched_full_o_rel_sq':full_ratio,
          'batched_minus_frozen_full_o_rel_sq':full_ratio-paid,
          'K_only_full_o_rel_sq':rel(k_only),'V_only_full_o_rel_sq':rel(v_only),
          'coarse_K_only_full_o_rel_sq':rel(coarse_k_only),
          'coarse_both_full_o_rel_sq':rel(coarse_both),
          'QJL_both_full_o_rel_sq':full_ratio,
          'K_V_interaction_rel_sq':float(E_i.square().sum())/teacher_sq,
          'K_V_interaction_max_abs':float(E_i.abs().max()),
          'effect_gram_rel_sq':gram.tolist(),
          'reconstructed_error_rel_sq_from_gram':float(gram.sum()),
          'effect_algebra_max_abs':algebra_gap,
          'QJL_mean_head_kl':float(kl.mean()/256),
          'coarse_mean_head_kl':float(coarsekl.mean()/256),
          'coarse_only_counterfactual_cache_bytes':147456,
          'coarse_only_counterfactual_assets_bytes':131088,
          'coarse_only_counterfactual_total_bytes':278544,
          'coarse_only_serialized_image_exists':False}
 (HERE/f'{arm}-{panel}-{window}.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:result[k] for k in ('panel','window','arm','diagnostic_batched_full_o_rel_sq','frozen_paid_full_o_rel_sq','K_only_full_o_rel_sq','V_only_full_o_rel_sq','K_V_interaction_rel_sq','coarse_both_full_o_rel_sq','QJL_mean_head_kl','coarse_mean_head_kl','effect_algebra_max_abs')}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]),sys.argv[3])
