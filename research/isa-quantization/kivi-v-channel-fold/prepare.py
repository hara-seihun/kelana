"""One train-only RMS grouping and physically folded BF16 V/O source images."""
import hashlib
import json
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')

def sha(data):return hashlib.sha256(data).hexdigest()

def run():
    torch.set_num_threads(1)
    with np.load(FIX) as data:x=torch.from_numpy(data['train'].astype(np.float32))
    assert x.shape==(2048,1024)
    with safe_open(MODEL,framework='pt',device='cpu') as model:
        assert not any(z in model.keys() for z in ('model.layers.0.self_attn.v_proj.bias','model.layers.0.self_attn.o_proj.bias'))
        v=model.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].contiguous()
        o=model.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].contiguous()
    assert v.shape==(128,1024) and o.shape==(1024,256) and v.dtype==o.dtype==torch.bfloat16
    values=(x@v.float().T).to(torch.bfloat16).float()
    rms=values.square().mean(0).sqrt().numpy()
    assert (rms>0).all() and np.isfinite(rms).all()
    # lexsort's second key is primary. No quality statistic or held data used.
    permutation=np.lexsort((np.arange(128),rms)).astype(np.int32)
    vw=v.view(torch.int16).numpy().view(np.uint16)[permutation].copy()
    ow=o.view(torch.int16).numpy().view(np.uint16).copy()
    for h in range(2):ow[:,h*128:(h+1)*128]=ow[:,h*128+permutation]
    vb=vw.astype('<u2').tobytes();ob=ow.astype('<u2').tobytes()
    assert len(vb)==262144 and len(ob)==524288
    (HERE/'v-replacement.bf16').write_bytes(vb)
    (HERE/'o-replacement.bf16').write_bytes(ob)
    result={'policy':'stable ascending train2048 BF16-projected V-channel RMS; four consecutive 32-channel grids',
            'permutation_new_to_old':permutation.tolist(),'rms_by_original_channel':rms.tolist(),
            'rms_groups_minmax':[[float(rms[p].min()),float(rms[p].max())] for p in permutation.reshape(4,32)],
            'v_sha256':sha(vb),'o_sha256':sha(ob),'v_bytes':len(vb),'o_bytes':len(ob),
            'incremental_static_bytes':0,'online_permutation_bytes':0}
    (HERE/'source-image.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('v_sha256','o_sha256','rms_groups_minmax','incremental_static_bytes')},indent=2))

if __name__=='__main__':run()
