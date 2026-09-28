"""Source-matched complete layer-0 Q-head causal observer; one 256-token window per bounded call."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
ASSETS={
 'e8-root-program/quip-root-standalone.bin':'d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a',
 'quip-root-matched-scalar/refit-group-q2q3-50320.bin':'e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15',
 'quip-completed-metric/completed-rvq3-root-50322.bin':'1375c3809f12a7484fba1a49d5573b529c6f0946e73408a2f0232a8dd61ae2b0',
 'quip-completed-metric/completed-group-q2q3-50320.bin':'bbf25784aba49c5687c3af203471dc4f91d6beb14dc4eaddb4f7e3377bb323f5',
}

def source_module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module)
    return module

def load_images():
    for path,sha in ASSETS.items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
    root=source_module('root_full_head_replay',ROOT/'e8-root-program/replay.py')
    scalar=source_module('scalar_full_head_replay',ROOT/'quip-root-matched-scalar/replay.py')
    images={'root_H':root.decode((ROOT/'e8-root-program/quip-root-standalone.bin').read_bytes()).astype(np.float32),
            'scalar_H':scalar.scalar().astype(np.float32),
            'root_M':root.decode((ROOT/'quip-completed-metric/completed-rvq3-root-50322.bin').read_bytes()).astype(np.float32),
            'scalar_M':decode_scalar_bytes((ROOT/'quip-completed-metric/completed-group-q2q3-50320.bin').read_bytes())}
    assert np.array_equal(images['scalar_H'],decode_scalar_bytes((ROOT/'quip-root-matched-scalar/refit-group-q2q3-50320.bin').read_bytes()))
    return images

def decode_scalar_bytes(data):
    modes=np.unpackbits(np.frombuffer(data[:128],dtype='u1'),bitorder='little').reshape(128,8)
    assert int(modes.sum())==191
    matrix=np.empty((128,1024),dtype=np.float32);offset=128
    for row in range(128):
        for group in range(8):
            bits=2 if modes[row,group] else 3
            payload=data[offset:offset+16*bits];offset+=16*bits
            digit=np.array([(payload[(i*bits)//8]>>((i*bits)%8) | (payload[(i*bits)//8+1]<<(8-(i*bits)%8) if (i*bits)%8+bits>8 else 0))&((1<<bits)-1) for i in range(128)],dtype=np.float32)
            step,origin=np.frombuffer(data[offset:offset+4],dtype='<f2').astype(np.float32);offset+=4
            assert np.isfinite(step) and step>0 and np.isfinite(origin)
            matrix[row,group*128:(group+1)*128]=digit*step+origin
    assert offset==len(data)
    return matrix

def measure(panel,window):
    torch.set_num_threads(1)
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    weights=load_images()
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
    assert np.array_equal(original,q[:128].numpy()),'fixture and original source model Q head disagree'
    assert tuple(k.shape)==(128,1024) and tuple(v.shape)==(128,1024) and tuple(o.shape)==(1024,256)
    consumer=source_module('original_qwen_causal_observer',ROOT/'attention-consumer/measure.py')
    with torch.no_grad():
        qref=(x@q[:128].T).to(torch.bfloat16).float()
        qpeer=(x@q[128:256].T).to(torch.bfloat16).float()
        kval=(x@k.T).to(torch.bfloat16).float()
        vval=(x@v.T).to(torch.bfloat16).float()
        teacher=consumer.head(qref,kval,vval,qgamma,kgamma,o[:,:128])
        peer=consumer.head(qpeer,kval,vval,qgamma,kgamma,o[:,128:256])
        result={'panel':panel,'window':window,'source_rows':[window*256,(window+1)*256],
                'fixture_sha256':'389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f',
                'images_sha256':ASSETS,'capture_model_q_exact':True,'modes':{}}
        mask=torch.tril(torch.ones((256,256),dtype=torch.bool))
        ref_center=torch.where(mask,teacher[2],0.)
        for name,weights_np in weights.items():
            raw=(x@torch.from_numpy(weights_np).T).to(torch.bfloat16).float()
            candidate=consumer.head(raw,kval,vval,qgamma,kgamma,o[:,:128])
            logp,value,logits=candidate
            metrics=consumer.compare(teacher,candidate)
            metrics['raw_q_rel_sq']=float((raw-qref).square().sum()/qref.square().sum())
            qnorm=consumer.normalized(raw,qgamma)
            qnorm_ref=consumer.normalized(qref,qgamma)
            metrics['normalized_q_rel_sq']=float((qnorm-qnorm_ref).square().sum()/qnorm_ref.square().sum())
            # Exact teacher-softmax score-variance diagnostic and finite-edit bounds
            # from ../observation-loss/README.md. The KL itself remains primary.
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
            # Preserve additive numerators and denominators for aggregation across all windows.
            metrics['counts']={'query_tokens':256,'visible_causal_pairs':256*257//2,
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
            result['modes'][name]=metrics
        assert torch.equal(peer[0],consumer.head(qpeer,kval,vval,qgamma,kgamma,o[:,128:256])[0])
    path=HERE/f'{panel}-{window}.json';path.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'modes':result['modes']},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('panel',choices=('train','held'));p.add_argument('window',type=int)
    a=p.parse_args();measure(a.panel,a.window)
