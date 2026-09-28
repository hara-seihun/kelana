"""Independent paid K/V cache decoder and complete two-head observer."""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import sys
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')

def decode(blob,bits):
    assert len(blob)==256*2*(16*bits+4)
    data=np.empty((2,256,128),dtype=np.float32);offset=0
    for i in range(256):
        for which in range(2):
            n=16*bits
            integer=int.from_bytes(blob[offset:offset+n],'little');offset+=n
            step,origin=np.frombuffer(blob[offset:offset+4],dtype='<f2').astype(np.float32);offset+=4
            assert np.isfinite(step) and step>0 and np.isfinite(origin)
            codes=np.array([(integer>>(j*bits))&((1<<bits)-1) for j in range(128)],dtype=np.float32)
            data[which,i]=codes*step+origin
    assert offset==len(blob)
    return data[0],data[1]

def main(panel,window):
    torch.set_num_threads(1)
    assert panel in ('train','held')
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as f:
        inputs=f['train' if panel=='train' else 'validation']
        assert window in range(len(inputs)//256)
        x=torch.from_numpy(inputs[window*256:(window+1)*256].copy().astype(np.float32))
        original=f['weight'][:128].astype(np.float32)
    with safe_open(MODEL,framework='pt',device='cpu') as model:
        q=model.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=model.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        v=model.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        o=model.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        qgamma=model.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    assert np.array_equal(original,q[:128].numpy())
    spec=importlib.util.spec_from_file_location('qwen_bf16_cache_control',ROOT/'attention-consumer/measure.py')
    consumer=importlib.util.module_from_spec(spec);spec.loader.exec_module(consumer)
    with torch.no_grad():
        qraw=[(x@q[i*128:(i+1)*128].T).to(torch.bfloat16).float() for i in range(2)]
        kraw=(x@k.T).to(torch.bfloat16).float()
        vraw=(x@v.T).to(torch.bfloat16).float()
        original_heads=[consumer.head(qa,kraw,vraw,qgamma,kgamma,o[:,i*128:(i+1)*128]) for i,qa in enumerate(qraw)]
        qrot=[consumer.rope(consumer.normalized(qa,qgamma)) for qa in qraw]
        krot=consumer.rope(consumer.normalized(kraw,kgamma))
    manifest=json.loads((HERE/f'{panel}-{window}-cache.json').read_text())
    result={'panel':panel,'window':window,'modes':{},'fixture_sha256':'389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'}
    with torch.no_grad():
        mask=torch.ones((256,256),dtype=torch.bool).triu(1)
        for bits in (4,6):
            filename=HERE/f'{panel}-{window}-kv-q{bits}.bin'
            blob=filename.read_bytes()
            assert hashlib.sha256(blob).hexdigest()==manifest[f'q{bits}']['sha256']
            assert len(blob)==manifest[f'q{bits}']['bytes']
            key,value=decode(blob,bits)
            keyt=torch.from_numpy(key);valuet=torch.from_numpy(value)
            changed=[];heads={}
            for i in range(2):
                logits=(qrot[i]@keyt.T/math.sqrt(128)).masked_fill(mask,-1e9)
                logp=logits.log_softmax(-1)
                output=(logp.exp()@valuet)@o[:,i*128:(i+1)*128].T
                original_logp,reference,_=original_heads[i]
                heads[f'head{i}']={'attention_kl':float((original_logp.exp()*(original_logp-logp)).sum(-1).mean()),
                    'post_o_rel_sq':float((reference-output).square().sum()/reference.square().sum()),
                    'output_sse':float((reference-output).square().sum()),
                    'output_ref_sq':float(reference.square().sum())}
                changed.append(output)
            pair=original_heads[0][1]+original_heads[1][1]
            newpair=changed[0]+changed[1]
            result['modes'][f'q{bits}']={'image_sha256':manifest[f'q{bits}']['sha256'],'bytes':len(blob),'heads':heads,
                'gqa_pair':{'post_o_rel_sq':float((pair-newpair).square().sum()/pair.square().sum()),
                    'output_sse':float((pair-newpair).square().sum()),
                    'output_ref_sq':float(pair.square().sum())},
                'key_rel_sq':float((keyt-krot).square().sum()/krot.square().sum()),
                'value_rel_sq':float((valuet-vraw).square().sum()/vraw.square().sum())}
    (HERE/f'{panel}-{window}-control.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'modes':result['modes']},indent=2))

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
