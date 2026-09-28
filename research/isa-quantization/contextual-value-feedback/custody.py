"""Require every contextual V record to match the earlier owning discriminator."""
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'contextual-value-sharing'
sys.path.insert(0,str(OWNER))
from screen import bf16_bits,fp32,quantize_v,MODEL

def sha(data):return hashlib.sha256(data).hexdigest()
def source(panel,w):
    path=HERE/f'{panel}-{w}-source.npz'
    record=json.loads((HERE/f'{panel}-{w}-source.json').read_text())
    assert sha(path.read_bytes())==record['source_file_sha256']
    assert sha((HERE/record['producer_snapshot']).read_bytes())==record['producer_source_sha256']
    with np.load(path) as f: arrays={k:f[k].copy() for k in f.files}
    for name,a in arrays.items():
        info=record['arrays'][name]
        assert list(a.shape)==info['shape'] and str(a.dtype)==info['dtype'] and sha(a.tobytes())==info['sha256']
    return arrays,record

def check():
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        gamma=f.get_tensor('model.layers.1.input_layernorm.weight').float().numpy().copy()
        weight=f.get_tensor('model.layers.1.self_attn.v_proj.weight').float().numpy().copy()
    receipts=[]
    for panel,n in (('train',8),('validation',4)):
        for w in range(n):
            arrays,rec=source(panel,w)
            x=fp32(arrays['residual'])
            normed=bf16_bits(x*np.reciprocal(np.sqrt(np.mean(x*x,axis=1,keepdims=True)+np.float32(1e-6))))
            normed=bf16_bits(fp32(normed)*gamma)
            prior=bf16_bits(fp32(normed)@weight.T).reshape(256,8,128)
            assert np.array_equal(arrays['v'],prior),(panel,w,'V BF16 mismatch')
            packed=b''.join(quantize_v(row) for row in prior)
            own=json.loads((OWNER/f'{panel}-{w}.json').read_text())
            assert own['full8_v_bf16']['total']==256 and own['full8_v_bf16']['unique']==256
            assert own['full8_g32_kivi2_v']['total']==256 and own['full8_g32_kivi2_v']['unique']==256
            receipts.append({'panel':panel,'window':w,'source_sha256':rec['source_file_sha256'],'v_sha256':sha(prior.tobytes()),'packed_g32_v_sha256':sha(packed),'owner_receipt_sha256':sha((OWNER/f'{panel}-{w}.json').read_bytes()),'correspondence':'byte-exact replay of owner screen.py V BF16/packed records; owner JSON has counts, not stored raw array hashes'})
    result={'owner_screen_sha256':sha((OWNER/'screen.py').read_bytes()),'records':receipts}
    (HERE/'custody.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'windows':len(receipts),'v_exact':True,'packed_exact':True}))
if __name__=='__main__':check()
