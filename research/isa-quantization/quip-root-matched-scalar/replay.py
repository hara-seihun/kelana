"""Independent mixed Q2/Q3 image reader and train/held complete-response scores."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
PIN='e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15'

def scalar():
    data=(HERE/'refit-group-q2q3-50320.bin').read_bytes()
    assert len(data)==50320 and hashlib.sha256(data).hexdigest()==PIN
    modes=np.unpackbits(np.frombuffer(data[:128],dtype='u1'),bitorder='little').reshape(128,8)
    assert int(modes.sum())==191
    offset=128;rows=np.empty((128,1024),dtype=np.float64)
    for row in range(128):
        for group in range(8):
            bits=2 if modes[row,group] else 3
            payload=data[offset:offset+bits*16];offset+=bits*16
            digits=np.empty(128,dtype=np.float64)
            for i in range(128):
                pos=i*bits;digit=payload[pos//8]>>(pos%8)
                if pos%8+bits>8:digit|=payload[pos//8+1]<<(8-pos%8)
                digits[i]=digit&((1<<bits)-1)
            step,origin=np.frombuffer(data[offset:offset+4],dtype='<f2').astype(np.float64);offset+=4
            assert np.isfinite(step) and step>0 and np.isfinite(origin)
            rows[row,group*128:(group+1)*128]=digits*step+origin
    assert offset==len(data)
    return rows

def main():
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as f:
        w=f['weight'][:128].astype(np.float64)
        panels={'train':f['train'].astype(np.float64),'held':f['validation'].astype(np.float64)}
    q=scalar()
    score={name:float(np.sum((x@(q-w).T)**2)/np.sum((x@w.T)**2)) for name,x in panels.items()}
    result={'image_sha256':PIN,'bytes':50320,'q2_groups':191,'q3_groups':833,'coefficients':46096,'fp16_group_fields':4096,'mode_mask':128,'joint_refit_accepted_rows':128,'relative_squared_response_error':score}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
