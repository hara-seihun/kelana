"""Frozen QTIP 3-bit full-input images through the canonical complete-head observer."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'qtip-full-row-3inst'))
from replay import decoded_image

ORIGINAL=ROOT/'quip-complete-head-observer'
sys.path.insert(0,str(ORIGINAL))
from measure import source_module

FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
ASSETS={
 'qtip-full-row-3inst/qtip-hyb-full-row.bin':'d06984e4407020db073d9eed087f570315a04fb119c36d96489335f0c5cfd222',
 'qtip-full-row-3inst/qtip-3inst-full-row.bin':'ee55370b26fb39baf0eab0fc4a43ff90ec247d494dfd48dd6e390887aa75f565',
}

def measure(panel,window):
    torch.set_num_threads(1)
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    images={}
    for arm in ('hyb','3inst'):
        path=f'qtip-full-row-3inst/qtip-{arm}-full-row.bin'
        image=(ROOT/path).read_bytes()
        assert hashlib.sha256(image).hexdigest()==ASSETS[path]
        images[arm]=torch.from_numpy(decoded_image(image,arm).astype(np.float32))
    with np.load(FIX) as fixture:
        positions=fixture['train' if panel=='train' else 'validation']
        original=fixture['weight'][:128].astype(np.float32)
        assert positions.shape[1]==1024 and len(positions)%256==0
        assert 0<=window<len(positions)//256
        x=torch.from_numpy(positions[window*256:(window+1)*256].astype(np.float32))
    with safe_open(MODEL,framework='pt',device='cpu') as model:
        q=model.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=model.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        v=model.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        o=model.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        qgamma=model.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    assert np.array_equal(original,q[:128].numpy()),'capture does not match checkpoint Q-head source'
    assert k.shape==(128,1024) and v.shape==(128,1024) and o.shape==(1024,256)
    consumer=source_module('original_qwen_causal_observer',ROOT/'attention-consumer/measure.py')
    with torch.no_grad():
        qref=(x@q[:128].T).to(torch.bfloat16).float()
        qpeer=(x@q[128:256].T).to(torch.bfloat16).float()
        kval=(x@k.T).to(torch.bfloat16).float()
        vval=(x@v.T).to(torch.bfloat16).float()
        teacher=consumer.head(qref,kval,vval,qgamma,kgamma,o[:,:128])
        peer=consumer.head(qpeer,kval,vval,qgamma,kgamma,o[:,128:256])
        result={'panel':panel,'window':window,'source_rows':[window*256,(window+1)*256],
                'images_sha256':ASSETS,'capture_model_q_exact':True,'modes':{}}
        mask=torch.tril(torch.ones((256,256),dtype=torch.bool))
        ref_center=torch.where(mask,teacher[2],0.)
        for arm,w in images.items():
            raw=(x@w.T).to(torch.bfloat16).float()
            candidate=consumer.head(raw,kval,vval,qgamma,kgamma,o[:,:128])
            logp,value,logits=candidate
            metrics=consumer.compare(teacher,candidate)
            metrics['raw_q_rel_sq']=float((raw-qref).square().sum()/qref.square().sum())
            qnorm=consumer.normalized(raw,qgamma)
            qnorm_ref=consumer.normalized(qref,qgamma)
            metrics['normalized_q_rel_sq']=float((qnorm-qnorm_ref).square().sum()/qnorm_ref.square().sum())
            delta=(logits-teacher[2]).double()
            probability=teacher[0].double().exp()
            mean=(probability*torch.where(mask,delta,0)).sum(-1)
            variance=(probability*torch.where(mask,(delta-mean[:,None]).square(),0)).sum(-1)
            visible_min=torch.where(mask,delta,float('inf')).min(-1).values
            visible_max=torch.where(mask,delta,-float('inf')).max(-1).values
            oscillation=visible_max-visible_min
            lower_factor=torch.where(oscillation>1e-8,(oscillation-1+torch.exp(-oscillation))/oscillation.square(),torch.full_like(oscillation,.5))
            upper_factor=torch.where(oscillation>1e-8,(torch.exp(oscillation)-1-oscillation)/oscillation.square(),torch.full_like(oscillation,.5))
            lower=variance*lower_factor
            upper=torch.minimum(variance*upper_factor,oscillation.square()/8)
            assert float(lower.mean())<=metrics['attention_kl']+3e-5 and metrics['attention_kl']<=float(upper.mean())+3e-5
            metrics['teacher_score_variance_mean']=float(variance.mean())
            metrics['score_oscillation_mean']=float(oscillation.mean())
            metrics['score_oscillation_max']=float(oscillation.max())
            metrics['certified_kl_lower_mean']=float(lower.mean())
            metrics['certified_kl_upper_mean']=float(upper.mean())
            metrics['gqa_pair_mean_attention_kl']=metrics['attention_kl']/2
            combined=teacher[1]+peer[1];changed=value+peer[1]
            metrics['gqa_pair_post_o_rel_sq']=float((combined-changed).square().sum()/combined.square().sum())
            metrics['counts']={'query_tokens':256,'visible_causal_pairs':32896,
                'head0_post_o_sse':float((teacher[1]-value).square().sum()),
                'head0_post_o_ref_sq':float(teacher[1].square().sum()),
                'gqa_pair_post_o_sse':float((combined-changed).square().sum()),
                'gqa_pair_post_o_ref_sq':float(combined.square().sum()),
                'raw_q_sse':float((raw-qref).square().sum()),
                'raw_q_ref_sq':float(qref.square().sum()),
                'normalized_q_sse':float((qnorm-qnorm_ref).square().sum()),
                'normalized_q_ref_sq':float(qnorm_ref.square().sum()),
                'centered_score_sse':float(metrics['centered_score_rel_sq']*ref_center.square().sum()),
                'centered_score_ref_sq':float(ref_center.square().sum())}
            result['modes'][arm]=metrics
        assert torch.equal(peer[0],consumer.head(qpeer,kval,vval,qgamma,kgamma,o[:,128:256])[0])
    (HERE/f'{panel}-{window}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'modes':{k:{field:v[field] for field in ('attention_kl','post_o_rel_sq','gqa_pair_post_o_rel_sq')} for k,v in result['modes'].items()}},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('panel',choices=['train','held']);p.add_argument('window',type=int);a=p.parse_args()
    measure(a.panel,a.window)
