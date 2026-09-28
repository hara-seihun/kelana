"""Independent physical source equality, causal K parity, and fixed admission gate."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
import torch
from safetensors import safe_open
from source import HERE,BASE,original,arrays
from source_image import read_source_images


def source_check():
    torch.set_num_threads(1)
    policy=json.loads((HERE/'source-image.json').read_text())
    p=np.asarray(policy['permutation_new_to_old'],dtype=np.int64)
    assert sorted(p.tolist())==list(range(128))
    v,o=read_source_images()
    with safe_open(original.MODEL,framework='pt',device='cpu') as model:
        vo=model.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128]
        oo=model.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256]
        assert torch.equal(v,vo[p].float())
        for h in range(2):assert torch.equal(o[:,128*h:128*(h+1)],oo[:,128*h+p].float())
    a=original.arrays('train',0)
    b=arrays('train',0)
    assert np.array_equal(a['key'],b['key']) and all(torch.equal(q,r) for q,r in zip(a['qrot'],b['qrot']))
    assert torch.equal(b['vraw'],a['vraw'][:,p])
    errors=[];reference=[]
    with torch.no_grad():
        for h in range(2):
            # All 256 causal queries, original teacher scores and physical new O.
            logp,teacher,logits=a['teacher'][h]
            changed=torch.stack([(logits[t,:t+1].softmax(-1)@b['vraw'][:t+1])@b['o'][:,h*128:(h+1)*128].T for t in range(256)])
            errors.append(float((teacher-changed).square().sum()))
            reference.append(float(teacher.square().sum()))
    result={'train0_source_o_max_abs':max(float((a['teacher'][h][1]-torch.stack([(a['teacher'][h][2][t,:t+1].softmax(-1)@b['vraw'][:t+1])@b['o'][:,h*128:(h+1)*128].T for t in range(256)])).abs().max()) for h in range(2)),
            'source_o_sse_per_head':errors,'source_o_ref_sq_per_head':reference,
            'v_image_sha256':policy['v_sha256'],'o_image_sha256':policy['o_sha256']}
    assert result['train0_source_o_max_abs']<1e-4
    (HERE/'source-check.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


def k_events(path):
    blob=Path(path).read_bytes();i=0;out=[]
    while i<len(blob):
        kind=blob[i:i+1];n=2560 if kind==b'K' else 80
        assert kind in (b'K',b'V')
        event=blob[i:i+3+n];assert len(event)==3+n
        if kind==b'K':out.append(event)
        i+=3+n
    return out


def gate():
    source=json.loads((HERE/'source-check.json').read_text())
    assert source['train0_source_o_max_abs']<1e-4
    old=json.loads((BASE/'train-0-result.json').read_text())
    new=json.loads((HERE/'train-0-result.json').read_text())
    old_ratio=old['gqa_pair']['post_o_sse']/old['gqa_pair']['post_o_ref_sq']
    new_ratio=new['gqa_pair']['post_o_sse']/new['gqa_pair']['post_o_ref_sq']
    oldk=k_events(BASE/'train-0-flush.bin');newk=k_events(HERE/'train-0-flush.bin')
    assert oldk==newk and len(newk)==8
    assert new['preflush_peak_bytes']==old['preflush_peak_bytes']==52400
    assert new['postflush_final_bytes']==old['postflush_final_bytes']==46592
    admitted=new_ratio<old_ratio
    result={'train0_new_pair_o_relsq':new_ratio,'train0_original_pair_o_relsq':old_ratio,
            'train0_new_pair_o_sse':new['gqa_pair']['post_o_sse'],'train0_original_pair_o_sse':old['gqa_pair']['post_o_sse'],
            'identical_original_k_flush_events':True,'admitted':admitted,
            'rule':'strictly smaller pair-O relative SSE than frozen original KIVI train0; complete source/byte/K parity required'}
    (HERE/'gate.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':{'source':source_check,'gate':gate}[sys.argv[1]]()
