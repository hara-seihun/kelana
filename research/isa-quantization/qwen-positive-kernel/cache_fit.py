"""Paid dynamic per-token affine K/V Q4 and Q6 cache preparation."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
import torch
from safetensors import safe_open
import importlib.util

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
TRIMS=(0,.01,.04)
ALTERNATIONS=4

def fit_vector(row,bits):
    limit=(1<<bits)-1
    selected=None
    for trim in TRIMS:
        lo,hi=np.quantile(row,(trim,1-trim))
        origin=float(lo);scale=float((hi-lo)/limit)
        if scale<=0:scale=1e-8
        for _ in range(ALTERNATIONS):
            code=np.clip(np.rint((row-origin)/scale),0,limit)
            m=code.mean();v=np.mean((code-m)**2)
            if v>0:
                scale=float(np.mean((code-m)*(row-row.mean()))/v)
                if scale<=0:break
                origin=float(row.mean()-scale*m)
        if scale<=0:continue
        fs,fo=np.array([scale,origin],dtype='<f2').astype(float)
        if not np.isfinite(fs) or fs<=0 or not np.isfinite(fo):continue
        code=np.clip(np.rint((row-fo)/fs),0,limit).astype(np.uint8)
        cost=np.sum((row-(fo+fs*code))**2)
        if selected is None or cost<selected[0]:selected=(cost,code,fs,fo)
    assert selected is not None
    _,code,fs,fo=selected
    return code,fs,fo

def main(panel,window):
    torch.set_num_threads(1)
    assert panel in ('train','held')
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as fixture:
        x=fixture['train' if panel=='train' else 'validation']
        assert window in range(len(x)//256)
        x=torch.from_numpy(x[window*256:(window+1)*256].copy().astype(np.float32))
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        k=f.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        v=f.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        gamma=f.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    spec=importlib.util.spec_from_file_location('qwen_consumer_kv',ROOT/'attention-consumer/measure.py')
    consumer=importlib.util.module_from_spec(spec);spec.loader.exec_module(consumer)
    with torch.no_grad():
        key=consumer.rope(consumer.normalized((x@k.T).to(torch.bfloat16).float(),gamma)).numpy()
        value=(x@v.T).to(torch.bfloat16).float().numpy()
    outputs={}
    for bits in (4,6):
        packed=bytearray()
        for i in range(256):
            for row in (key[i],value[i]):
                codes,scale,origin=fit_vector(row.astype(float),bits)
                integer=sum(int(c)<<(bits*j) for j,c in enumerate(codes))
                packed+=integer.to_bytes(16*bits,'little')
                packed+=np.asarray([scale,origin],dtype='<f2').tobytes()
        path=HERE/f'{panel}-{window}-kv-q{bits}.bin'
        path.write_bytes(packed)
        outputs[f'q{bits}']={'sha256':hashlib.sha256(packed).hexdigest(),'bytes':len(packed)}
        assert len(packed)==256*2*(16*bits+4)
    (HERE/f'{panel}-{window}-cache.json').write_text(json.dumps(outputs,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'caches':outputs},indent=2))

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
