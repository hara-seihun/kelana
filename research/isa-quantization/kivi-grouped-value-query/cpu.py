"""Replay immutable KIVI2 arrivals/events; independently parse packed image in reader.cpp."""
import ctypes as ct
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
import torch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'kivi-value-intern'))
from encode import image
sys.path.insert(0,str(ROOT/'skvq-global-gqa'))
from source import arrays,FIX_SHA


def sha(x):return hashlib.sha256(x).hexdigest()


def run(panel,window):
    torch.set_num_threads(1)
    tag=f'{panel}-{window}'
    intern=ROOT/'kivi-value-intern'
    original=ROOT/'kivi-two-bit-causal'
    native=ROOT/'kivi-two-bit-dot-native'
    evidence=json.loads((intern/f'{tag}-manifest.json').read_text())
    donor=json.loads((original/f'{tag}-manifest.json').read_text())
    assert evidence['source_fixture_sha256']==donor['fixture_sha256']==FIX_SHA
    assert evidence['baseline_manifest_sha256']==sha((original/f'{tag}-manifest.json').read_bytes())
    src=arrays(panel,window)
    keys=src['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
    vals=src['value'].reshape(256,8,128)
    streams=[(original/f'{tag}-head{h}-events.bin').read_bytes() for h in range(8)]
    assert [sha(x) for x in streams]==evidence['baseline_events_sha256']
    log=(intern/f'{tag}-events.bin').read_bytes()
    assert len(log)==256*4098 and sha(log)==evidence['events_sha256']
    lib=ct.CDLL(str(HERE/'reader.so'))
    lib.response.argtypes=[ct.POINTER(ct.c_uint8),ct.c_size_t,ct.POINTER(ct.c_float),ct.POINTER(ct.c_float),ct.POINTER(ct.c_float),ct.POINTER(ct.c_uint64)]
    kq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vq=[];vr=[];offset=[0]*8
    o=src['o'].T.contiguous();teacher=src['teacher'];den=float(teacher.square().sum())
    assert sha(src['o'].to(torch.bfloat16).contiguous().view(torch.uint16).numpy().astype('<u2').tobytes())==json.loads((native/'snapshots.json').read_text())['original_o_sha256']
    results=[[],[]];maxdiff=0.;diffsum=0.;counts=np.zeros(3,dtype=np.uint64);lengths=[]
    with torch.no_grad():
      for t in range(1,257):
        kb=keys[t-1].astype('<u2').tobytes();vb=vals[t-1].astype('<u2').tobytes()
        assert log[(t-1)*4098:t*4098]==t.to_bytes(2,'little')+kb+vb
        for h in range(8):kr[h].append(kb[h*256:(h+1)*256])
        vr.append(vb)
        blob,ledger=image(t,0,kq,kr,vq,vr)
        expected=evidence['prefixes'][t-1]['before']
        assert ledger==expected and sha(blob)==expected['sha256']
        q=src['qrot'][:,t-1].numpy().astype('<f4').copy()
        a=np.empty(2048,dtype='<f4');b=np.empty_like(a);bits=np.frombuffer(blob,dtype='u1')
        code=lib.response(bits.ctypes.data_as(ct.POINTER(ct.c_uint8)),len(blob),q.ctypes.data_as(ct.POINTER(ct.c_float)),a.ctypes.data_as(ct.POINTER(ct.c_float)),b.ctypes.data_as(ct.POINTER(ct.c_float)),counts.ctypes.data_as(ct.POINTER(ct.c_uint64)))
        assert code==0,(t,code)
        # Both modes use unchanged source BF16 O in original FP32 matmul.
        ya=torch.from_numpy(a.copy())@o;yb=torch.from_numpy(b.copy())@o
        results[0].append(ya);results[1].append(yb)
        delta=(ya-yb).abs();maxdiff=max(maxdiff,float(delta.max()));diffsum+=float(delta.square().sum())
        lengths.append({'t':t,'quant_unique':ledger['quant_unique'],'recent_unique':ledger['recent_unique'],'quant_positions':len(vq),'recent_positions':len(vr)})
        pieces=[]
        for h in range(8):
          stream=streams[h];pos=offset[h]
          if len(kr[h])==32:
            assert stream[pos:pos+3]==b'K'+t.to_bytes(2,'little')
            kq[h].append(stream[pos+3:pos+1539]);pos+=1539;kr[h].clear()
          if len(vr)>32:
            assert stream[pos:pos+3]==b'V'+t.to_bytes(2,'little')
            quant=stream[pos+3:pos+51];pos+=51
            pieces.append(quant)
          offset[h]=pos
        if len(vr)>32:
          assert len(pieces)==8
          vq.append(b''.join(pieces));vr.pop(0)
        after,after_ledger=image(t,1,kq,kr,vq,vr)
        assert after_ledger==evidence['prefixes'][t-1]['after']
    assert all(offset[h]==len(streams[h]) for h in range(8))
    assert after==(intern/f'{tag}-final.bin').read_bytes()
    outputs=[torch.stack(r) for r in results]
    sse=[float(((r-teacher)**2).sum()) for r in outputs]
    owner=json.loads((original/f'{tag}-result.json').read_text())
    receipt={'panel':panel,'window':window,'placement':'PLAN.md','fixture_sha256':FIX_SHA,
             'intern_manifest_sha256':sha((intern/f'{tag}-manifest.json').read_bytes()),
             'original_events_sha256':[sha(s) for s in streams],
             'source_o_sha256':sha((native/'original-o.bf16').read_bytes()),
             'prefixes_checked':256,'last_image_sha256':sha(after),
             'ordered_full_o_sse':sse[0],'grouped_full_o_sse':sse[1],'teacher_full_o_sq':den,
             'ordered_normalized_sse':sse[0]/den,'grouped_normalized_sse':sse[1]/den,
             'original_owner_normalized_sse':owner['full_o_sse']/owner['full_o_ref_sq'],
             'max_abs_output_difference':maxdiff,'output_difference_l2':diffsum**0.5,
             'per_head_reference_mass_reads':int(counts[0]),'per_head_grouped_record_mixes':int(counts[1]),
             'per_head_control_reference_reads':int(counts[2]),'states':lengths}
    (HERE/f'{tag}-result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:receipt[k] for k in ('panel','window','ordered_normalized_sse','grouped_normalized_sse','max_abs_output_difference','output_difference_l2')}),flush=True)

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
