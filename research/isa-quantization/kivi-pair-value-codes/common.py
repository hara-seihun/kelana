"""Frozen layer-local pair and O-metric coordinates; no Q or fitted data."""
from pathlib import Path
import hashlib
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CONTEXT=ROOT/'contextual-value-feedback'
BASE=ROOT/'kivi-two-bit-causal'
SNAP=ROOT/'kivi-two-bit-dot-native'
PAIR=ROOT/'value-pair-covariance'
ARRIVAL=ROOT/'kivi-value-intern'
O_HASH=('803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499','677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48')
def sha(data):return hashlib.sha256(data).hexdigest()
def checked(path,digest):
    data=path.read_bytes();assert sha(data)==digest,(path,digest);return data
def pairs(layer):
    raw=checked(PAIR/'pair-map.bin','2e5a182308b17a2e6b417521a7937fd9b98037bb6bfb3df3269fabb02b3e35f3');assert len(raw)==3136
    entries=[];offset=layer*1568
    for h in range(8):
        group=[]
        for g in range(4):
            assert raw[offset]==16;offset+=1;seen=set()
            for p in range(16):
                i,j,sign=raw[offset:offset+3];offset+=3
                assert i<j<32 and sign in (0,1) and i not in seen and j not in seen
                seen.update((i,j));group.append((g*32+i,g*32+j))
            assert len(seen)==32
        entries.append(group)
    assert offset==(layer+1)*1568
    return entries
def o_matrix(layer):
    path=(SNAP if layer==0 else CONTEXT)/'original-o.bf16'
    words=np.frombuffer(checked(path,O_HASH[layer]),dtype='<u2')
    assert words.size==1024*2048
    return (words.astype('<u4')<<16).view('<f4').reshape(1024,2048)
def metrics(layer):
    raw=checked(HERE/'metric.bin','f085b14330bf738f91cb604467951bb2a46b7e27b0df3be0eb6ee098bad339c2');assert len(raw)==12288
    return np.frombuffer(raw[layer*6144:(layer+1)*6144],dtype='<f4').reshape(8,64,3)
def make_metric():
    output=bytearray()
    for layer in range(2):
        o=o_matrix(layer).astype('<f8');indices=pairs(layer)
        for h in range(8):
            for i,j in indices[h]:
                ci=(o[:,(2*h)*128+i],o[:,(2*h+1)*128+i])
                cj=(o[:,(2*h)*128+j],o[:,(2*h+1)*128+j])
                values=(sum(np.dot(x,x) for x in ci),sum(np.dot(x,y) for x,y in zip(ci,cj)),sum(np.dot(y,y) for y in cj))
                output.extend(np.asarray(values,dtype='<f4').tobytes())
    assert len(output)==12288
    (HERE/'metric.bin').write_bytes(output)
if __name__=='__main__':make_metric()
