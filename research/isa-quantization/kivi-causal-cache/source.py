"""Source-only two-head GQA producer and fixed original causal observer."""
from pathlib import Path
import hashlib
import importlib.util
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
FIX_SHA='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
spec=importlib.util.spec_from_file_location('original_causal_consumer',ROOT/'attention-consumer/measure.py')
consumer=importlib.util.module_from_spec(spec);spec.loader.exec_module(consumer)


def arrays(panel,window):
    torch.set_num_threads(1)
    assert panel in ('train','held') and hashlib.sha256(FIX.read_bytes()).hexdigest()==FIX_SHA
    with np.load(FIX) as f:
        data=f['train' if panel=='train' else 'validation']
        assert 0<=window<len(data)//256
        x=torch.from_numpy(data[window*256:(window+1)*256].astype(np.float32).copy())
        original=f['weight'][:128].astype(np.float32)
    with safe_open(MODEL,framework='pt',device='cpu') as model:
        q=model.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=model.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        v=model.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        o=model.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        qgamma=model.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    assert np.array_equal(original,q[:128].numpy())
    with torch.no_grad():
        qraw=[(x@q[i*128:(i+1)*128].T).to(torch.bfloat16).float() for i in range(2)]
        kraw=(x@k.T).to(torch.bfloat16).float()
        vraw=(x@v.T).to(torch.bfloat16).float()
        qrot=[consumer.rope(consumer.normalized(item,qgamma)).contiguous() for item in qraw]
        krot=consumer.rope(consumer.normalized(kraw,kgamma)).contiguous()
        # Original CPU teacher keeps the full FP32 rotary K produced by the
        # canonical BF16-normalized source; the cache stores BF16-rounded K.
        heads=[consumer.head(qraw[i],kraw,vraw,qgamma,kgamma,o[:,i*128:(i+1)*128]) for i in range(2)]
    return {'key':krot.to(torch.bfloat16).view(torch.uint16).numpy().copy(),
            'value':vraw.to(torch.bfloat16).view(torch.uint16).numpy().copy(),
            'qrot':qrot,'teacher':heads,'o':o,'krot':krot,'vraw':vraw}
