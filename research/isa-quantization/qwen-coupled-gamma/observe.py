"""Full16Q/8KV original versus paid-gamma Qwen source and complete O."""
import hashlib,json,math,sys
import numpy as np
import torch
from safetensors import safe_open
from reader import HERE,MODEL,decode
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'skvq-global-gqa'))
import source as full

def run(panel,window):
 torch.set_num_threads(1)
 replacement,original,e=decode()
 src=full.arrays(panel,window)
 with np.load(full.original.FIX) as f:
  x=torch.from_numpy(f['train' if panel=='train' else 'validation'][window*256:(window+1)*256].astype(np.float32).copy())
 with safe_open(MODEL,framework='pt',device='cpu') as f:
  qw=f.get_tensor('model.layers.0.self_attn.q_proj.weight').float()
  kw=f.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
 with torch.no_grad():
  qr=(x@qw.T).to(torch.bfloat16).float().reshape(256,16,128)
  kr=(x@kw.T).to(torch.bfloat16).float().reshape(256,8,128)
  q0=full.rope(full.original.consumer.normalized(qr,torch.from_numpy(original[0]))).permute(1,0,2)
  k0=full.rope(full.original.consumer.normalized(kr,torch.from_numpy(original[1]))).permute(1,0,2)
  assert torch.equal(q0,src['qrot']) and torch.equal(k0,src['krot'])
  q=full.rope(full.original.consumer.normalized(qr,torch.from_numpy(replacement[0]))).permute(1,0,2)
  k=full.rope(full.original.consumer.normalized(kr,torch.from_numpy(replacement[1]))).permute(1,0,2)
  factors=torch.from_numpy(np.exp2(np.r_[e[:64],e[:64]]).astype(np.float32))
  expected_q=q0*factors
  expected_k=k0/factors
  qmax=float((q-expected_q).abs().max());kmax=float((k-expected_k).abs().max())
  l=torch.bmm(q,k.repeat_interleave(2,dim=0).transpose(1,2))/math.sqrt(128)
  l=l.masked_fill(torch.ones(256,256,dtype=torch.bool).triu(1)[None],-1e9)
  logp=l.log_softmax(-1)
  pl=logp.exp()
  original_p=src['teacher_logp'].exp()
  score_max=float((l-src['teacher_logits']).abs().max())
  prob_max=float((pl-original_p).abs().max())
  mix=torch.bmm(pl,src['vraw'].repeat_interleave(2,dim=0))
  changed=mix.permute(1,0,2).reshape(256,2048)@src['o'].T
  target=src['teacher']
  odiff=changed-target
 receipt=json.loads((HERE/'prepare.json').read_text())
 r={'panel':panel,'window':window,'fixture_sha256':full.FIX_SHA,'gamma_image_sha256':receipt['gamma_image_sha256'],
    'q_pairwise_max_abs':qmax,'k_pairwise_max_abs':kmax,'score_max_abs':score_max,'prob_max_abs':prob_max,
    'complete_o_max_abs':float(odiff.abs().max()),'complete_o_sse':float(odiff.square().sum()),
    'complete_o_ref_sq':float(target.square().sum()),'bitwise':{'q':torch.equal(q,expected_q),'k':torch.equal(k,expected_k),
    'scores':torch.equal(l,src['teacher_logits']),'prob':torch.equal(pl,original_p),'o':torch.equal(changed,target)}}
 (HERE/f'{panel}-{window}-observe.json').write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'max_score_abs':score_max,'max_o_abs':r['complete_o_max_abs'],'full_o_rel_sq':r['complete_o_sse']/r['complete_o_ref_sq'],'bitwise':r['bitwise']}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
