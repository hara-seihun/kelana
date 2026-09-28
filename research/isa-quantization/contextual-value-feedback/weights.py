"""Pin the original layer-1 BF16 O tensor shared by every source and reader."""
import json
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open
from prepare import HERE,MODEL,EXPECTED,file_sha,sha

O=HERE/'original-o.bf16'
RECEIPT=HERE/'original-o.json'
def materialize():
    assert file_sha(MODEL)==EXPECTED[MODEL]
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        original=f.get_tensor('model.layers.1.self_attn.o_proj.weight')
        assert original.shape==(1024,2048) and original.dtype==torch.bfloat16
        data=original.contiguous().view(torch.uint16).numpy().astype('<u2').tobytes()
    if O.exists():assert O.read_bytes()==data
    else:O.write_bytes(data)
    receipt={'checkpoint_sha256':EXPECTED[MODEL],'tensor':'model.layers.1.self_attn.o_proj.weight','dtype':'BF16 little-endian','shape':[1024,2048],'o_sha256':sha(data),'bytes':len(data)}
    if RECEIPT.exists(): assert json.loads(RECEIPT.read_text())==receipt
    else:RECEIPT.write_text(json.dumps(receipt,indent=2)+'\n')
    for path in HERE.glob('*-source.json'):
        item=json.loads(path.read_text())
        assert item['input_sha256'][str(MODEL)]==EXPECTED[MODEL]
        item['original_o_bf16_sha256']=receipt['o_sha256']
        path.write_text(json.dumps(item,indent=2)+'\n')
    print(json.dumps(receipt))
def load(expected):
    receipt=json.loads(RECEIPT.read_text())
    assert receipt['checkpoint_sha256']==EXPECTED[MODEL] and receipt['o_sha256']==expected
    data=O.read_bytes()
    assert len(data)==receipt['bytes']==4194304 and sha(data)==expected
    return torch.from_numpy(np.frombuffer(data,dtype='<u2').copy()).view(torch.bfloat16).float().reshape(1024,2048)
if __name__=='__main__':materialize()
