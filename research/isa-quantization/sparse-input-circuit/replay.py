"""Read the stored two-layer circuit, not the optimizer, and score both panels."""
import hashlib
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
BASE=HERE.parent/'producer-screen'/'affine-q4.bin'


def score(a,b):return float(np.sum((a-b)**2)/np.sum(b*b))


def main():
    receipt=json.loads((HERE/'two-layer-results.json').read_text())
    image=(HERE/'two-layer-q4.bin').read_bytes()
    assert hashlib.sha256(image).hexdigest()==receipt['image_sha256']
    assert len(image)==96+4*(receipt['pre_edges']+receipt['fan_edges'])+128*52
    kept=np.frombuffer(image,dtype='u1',count=96).astype(int)
    assert len(np.unique(kept))==96
    removed=np.array(sorted(set(range(128))-set(kept)))
    s=np.eye(32); a=np.zeros((32,96)); position=96
    for _ in range(receipt['pre_edges']):
        src,dest=image[position:position+2]
        coefficient=np.frombuffer(image,dtype='<f2',count=1,offset=position+2)[0]
        assert src<32 and dest<32 and src!=dest
        s[src,dest]+=float(coefficient)
        position+=4
    for _ in range(receipt['fan_edges']):
        src,dest=image[position:position+2]
        coefficient=np.frombuffer(image,dtype='<f2',count=1,offset=position+2)[0]
        assert src<32 and dest<96
        a[src,dest]+=float(coefficient)
        position+=4
    t=np.zeros((128,96));t[kept,np.arange(96)]=1;t[removed]=s@a
    output=np.zeros((96,128));control=np.zeros((128,128))
    original=BASE.read_bytes()
    assert len(original)==8704
    for row in range(128):
        packed=np.frombuffer(image,dtype='u1',offset=position+52*row,count=48)
        codes=np.empty(96);codes[::2]=packed&15;codes[1::2]=packed>>4
        origin,step=np.frombuffer(image,dtype='<f2',offset=position+52*row+48,count=2).astype(float)
        output[:,row]=origin+step*codes
        packed=np.frombuffer(original,dtype='u1',offset=68*row,count=64)
        codes=np.empty(128);codes[::2]=packed&15;codes[1::2]=packed>>4
        origin,step=np.frombuffer(original,dtype='<f2',offset=68*row+64,count=2).astype(float)
        control[row]=origin+step*codes
    with np.load(FIX) as f:
        w=f['weight'][:128,:128].astype(float)
        train=f['train'][:,:128].astype(float)
        held=f['validation'][:,:128].astype(float)
    replay=dict(bytes=len(image),sha256=hashlib.sha256(image).hexdigest(),
                train=score(train@t@output,train@w.T),
                held=score(held@t@output,held@w.T),
                q4_train=score(train@control.T,train@w.T),
                q4_held=score(held@control.T,held@w.T))
    for key,field in [('train','decoded_train'),('held','decoded_held')]:
        assert abs(replay[key]-receipt[field])<1e-14
    assert abs(replay['q4_train']-0.005173614377259471)<1e-14
    print(json.dumps(replay,indent=2))

if __name__=='__main__':main()
