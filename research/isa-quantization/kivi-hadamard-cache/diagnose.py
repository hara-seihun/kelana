"""Predeclared train0 failure diagnosis at actual last preflush cache boundary."""
from pathlib import Path
import json
import numpy as np
from program import HERE,OWNER,arrays,bf,transform,decode_state,unpack

src=arrays('train',0)
owner=json.loads((OWNER/'train-0-manifest.json').read_text())
state=(OWNER/'train-0-pre-256.bin').read_bytes()
nk,nv,kr,vr=[owner['prefixes'][255]['before_flush'][name] for name in ('key_quant_tokens','value_quant_tokens','key_recent_tokens','value_recent_tokens')]
assert (nk,nv,kr,vr)==(224,223,32,33) and len(state)==52400
kc=[state[i*2560:(i+1)*2560] for i in range(7)]
vo=7*2560
vc=[state[vo+i*80:vo+(i+1)*80] for i in range(223)]
ro=vo+223*80
rk=[state[ro+i*256:ro+(i+1)*256] for i in range(32)]
rv=[state[ro+32*256+i*256:ro+32*256+(i+1)*256] for i in range(33)]
original,_=decode_state(kc,vc,rk,rv)
log=(HERE/'train-0-flush.bin').read_bytes();candidate_k=[];at=0
while len(candidate_k)<7:
    assert log[at:at+1]==b'K';candidate_k.append(log[at+3:at+3+2560]);at+=3+2560
    # Each K flush after position32 has all earlier V flush events following it.
    next_k=(len(candidate_k)+1)*32
    while at<len(log) and log[at:at+1]==b'V':at+=3+80
candidate_recent=bf(src['key'][224:256])
from program import bits
candidate_recent=bits(transform(candidate_recent))
candidate,_=decode_state(candidate_k,vc,[v.astype('<u2').tobytes() for v in candidate_recent],rv)
base=bf(src['key']);gauged=transform(base)
q=[src['qrot'][i][255].numpy() for i in range(2)]
metrics={'preflush_position':256,'baseline_key_rel_sq':float(np.square(original-base,dtype=np.float64).sum()/np.square(base,dtype=np.float64).sum()),
         'transformed_key_rel_sq':float(np.square(candidate-gauged,dtype=np.float64).sum()/np.square(gauged,dtype=np.float64).sum()),
         'per_head_last_score_rmse':[],'per_head_last_score_max_abs':[],
         'per_head_last_score_fp32_rotation_roundoff_rmse':[],
         'per_head_last_score_transformed_bf16_no_quant_rmse':[]}
for i in range(2):
    target=q[i]@base.T/np.sqrt(128)
    old=q[i]@original.T/np.sqrt(128)
    new=transform(q[i])@candidate.T/np.sqrt(128)
    recent=transform(q[i])@transform(base).T/np.sqrt(128)
    metrics['per_head_last_score_rmse'].append({'baseline':float(np.sqrt(np.square(old-target).mean())),'candidate':float(np.sqrt(np.square(new-target).mean()))})
    metrics['per_head_last_score_max_abs'].append({'baseline':float(abs(old-target).max()),'candidate':float(abs(new-target).max())})
    unquantized_recent=transform(q[i])@bf(bits(transform(base))).T/np.sqrt(128)
    metrics['per_head_last_score_fp32_rotation_roundoff_rmse'].append(float(np.sqrt(np.square(recent-target).mean())))
    metrics['per_head_last_score_transformed_bf16_no_quant_rmse'].append(float(np.sqrt(np.square(unquantized_recent-target).mean())))
(HERE/'diagnosis-train0.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
