"""Reconstruct only eight paid preflush dictionary images from immutable arrival/flush logs."""
import ctypes as ct
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT/'kivi-value-intern'))
from encode import image

def sha(b): return hashlib.sha256(b).hexdigest()

lib = ct.CDLL(str(HERE/'reader.so'))
lib.response.argtypes = [ct.POINTER(ct.c_uint8),ct.c_size_t,ct.POINTER(ct.c_float),ct.POINTER(ct.c_float),ct.POINTER(ct.c_float),ct.POINTER(ct.c_uint64)]
original = ROOT/'kivi-two-bit-dot-native'
manifest = json.loads((original/'snapshots.json').read_text())
o_bytes = (original/'original-o.bf16').read_bytes()
assert sha(o_bytes) == manifest['original_o_sha256']
o = torch.from_numpy((np.frombuffer(o_bytes, dtype='<u2').astype(np.uint32)<<16).view(np.float32).reshape(1024,2048).copy())
torch.set_num_threads(1)
receipts = []
for w in range(4):
    tag = f'held-{w}'
    intern = ROOT/'kivi-value-intern'
    donor = ROOT/'kivi-two-bit-causal'
    evidence = json.loads((intern/f'{tag}-manifest.json').read_text())
    baseline = json.loads((donor/f'{tag}-manifest.json').read_text())
    assert evidence['source_fixture_sha256'] == baseline['fixture_sha256'] == manifest['fixture_sha256']
    assert evidence['baseline_manifest_sha256'] == sha((donor/f'{tag}-manifest.json').read_bytes())
    log = (intern/f'{tag}-events.bin').read_bytes()
    assert len(log) == 256*4098 and sha(log) == evidence['events_sha256']
    streams = [(donor/f'{tag}-head{h}-events.bin').read_bytes() for h in range(8)]
    assert [sha(s) for s in streams] == evidence['baseline_events_sha256']
    kq,kr = [[] for _ in range(8)],[[] for _ in range(8)]
    vq,vr = [],[]
    offsets = [0]*8
    for t in range(1,257):
        at = (t-1)*4098
        assert log[at:at+2] == t.to_bytes(2,'little')
        kb,vb = log[at+2:at+2050],log[at+2050:at+4098]
        for h in range(8): kr[h].append(kb[h*256:(h+1)*256])
        vr.append(vb)
        if t in (128,256):
            blob,ledger = image(t,0,kq,kr,vq,vr)
            assert ledger == evidence['prefixes'][t-1]['before']
            snap = manifest['states'][w*2 + (t==256)]
            assert snap['window']==w and snap['position']==t
            qbytes = (original/f'{tag}-t{t}-q.f32').read_bytes()
            assert sha(qbytes)==snap['query_sha256']
            q=np.frombuffer(qbytes,dtype='<f4').copy()
            a,b=np.empty(2048,dtype='<f4'),np.empty(2048,dtype='<f4')
            counts=np.zeros(3,dtype=np.uint64)
            bits=np.frombuffer(blob,dtype=np.uint8)
            rc=lib.response(bits.ctypes.data_as(ct.POINTER(ct.c_uint8)),len(blob),q.ctypes.data_as(ct.POINTER(ct.c_float)),a.ctypes.data_as(ct.POINTER(ct.c_float)),b.ctypes.data_as(ct.POINTER(ct.c_float)),counts.ctypes.data_as(ct.POINTER(ct.c_uint64)))
            assert rc==0,(tag,t,rc)
            name=f'{tag}-t{t}'
            (HERE/f'{name}-image.bin').write_bytes(blob)
            for mode,vec in (('direct',a),('grouped',b)):
                target=(o@torch.from_numpy(vec.copy())).numpy().astype('<f4')
                assert np.isfinite(target).all()
                (HERE/f'{name}-{mode}-cpu.f32').write_bytes(target.tobytes())
            receipts.append({'tag':name,'image_sha256':sha(blob),'image_bytes':len(blob),'owner_manifest_sha256':sha((intern/f'{tag}-manifest.json').read_bytes()),'quant_unique':ledger['quant_unique'],'recent_unique':ledger['recent_unique'],'direct_cpu_sha256':sha((HERE/f'{name}-direct-cpu.f32').read_bytes()),'grouped_cpu_sha256':sha((HERE/f'{name}-grouped-cpu.f32').read_bytes()),'q_sha256':sha(qbytes)})
        pieces=[]
        for h in range(8):
            stream=streams[h];pos=offsets[h]
            if len(kr[h])==32:
                assert stream[pos:pos+3]==b'K'+t.to_bytes(2,'little')
                kq[h].append(stream[pos+3:pos+1539]);pos+=1539;kr[h].clear()
            if len(vr)>32:
                assert stream[pos:pos+3]==b'V'+t.to_bytes(2,'little')
                pieces.append(stream[pos+3:pos+51]);pos+=51
            offsets[h]=pos
        if len(vr)>32:
            vq.append(b''.join(pieces));vr.pop(0)
    assert all(offsets[h]==len(streams[h]) for h in range(8))
(HERE/'inputs.json').write_text(json.dumps({'original_o_sha256':sha(o_bytes),'original_snapshot_manifest_sha256':sha((original/'snapshots.json').read_bytes()),'reader_sha256':sha((ROOT/'kivi-grouped-value-query/reader.cpp').read_bytes()),'snapshots':receipts},indent=2)+'\n')
print('prepared eight exact images and independent direct/grouped CPU targets')
