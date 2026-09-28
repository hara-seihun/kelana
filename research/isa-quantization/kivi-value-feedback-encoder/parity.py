"""CPU byte-and-state correspondence against the frozen chronological donor, without scoring."""
import ctypes
import hashlib
import json
import struct
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
DONOR=Path(sys.argv[1]).resolve()
sha=lambda b:hashlib.sha256(b).hexdigest()
lib=ctypes.CDLL(str(HERE/'encoder.so'))
lib.encode.argtypes=(ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int)
checks={'source':{},'donor':{},'encoder_cpp_sha256':sha((HERE/'encoder.cpp').read_bytes()),'encoder_shared_sha256':sha((HERE/'encoder.so').read_bytes()),'donor_commit':'da88542','events':0,'prefixes':0,'fields':0,'digits':0,'residual_states':0}
for w in range(4):
    name=f'held-{w}'
    arrival=(ROOT/'kivi-value-intern'/f'{name}-events.bin').read_bytes()
    source_manifest_bytes=(ROOT/'kivi-value-intern'/f'{name}-manifest.json').read_bytes()
    source_manifest=json.loads(source_manifest_bytes)
    assert sha(arrival)==source_manifest['events_sha256']
    donor_bytes=(DONOR/f'{name}-manifest.json').read_bytes()
    donor=json.loads(donor_bytes)
    baseline_manifest_bytes=(ROOT/'kivi-two-bit-causal'/f'{name}-manifest.json').read_bytes()
    assert sha(source_manifest_bytes)==donor['arrival_manifest_sha256']
    assert sha(baseline_manifest_bytes)==donor['baseline_manifest_sha256']
    assert sha(arrival)==donor['arrival_sha256']
    checks['source'][name]=sha(arrival);checks['donor'][name]=sha(donor_bytes)
    for h in range(8):
        original=(ROOT/'kivi-two-bit-causal'/f'{name}-head{h}-events.bin').read_bytes()
        assert sha(original)==donor['arms']['feedback']['heads'][h]['original_event_sha256']
        feedback=(DONOR/f'{name}-feedback-head{h}-events.bin').read_bytes()
        head=donor['arms']['feedback']['heads'][h]
        assert sha(feedback)==head['events_sha256']
        def parse(data):
            p=0;v={}
            while p<len(data):
                kind=chr(data[p]);t=int.from_bytes(data[p+1:p+3],'little');length=1536 if kind=='K' else 48
                if kind=='V':v[t]=data[p+3:p+3+length]
                p+=3+length
            assert p==len(data) and len(v)==224
            return v
        old=parse(original);expected=parse(feedback)
        residual=(ctypes.c_float*128)();nxt=(ctypes.c_float*128)()
        for t in range(1,257):
            prefix=head['prefixes'][t-1]
            before=bytes(residual)
            assert sha(before)==prefix['residual_before'],(w,h,t,'before')
            checks['residual_states']+=1
            if t>=33:
                source=arrival[(t-33)*4098+2050+h*256:(t-33)*4098+2050+(h+1)*256]
                assert len(source)==256
                original_record=(ctypes.c_ubyte*48)()
                source_input=(ctypes.c_ubyte*256).from_buffer_copy(source)
                lib.encode(source_input,residual,original_record,nxt,0)
                assert bytes(original_record)==old[t],(w,h,t,'original')
                record=(ctypes.c_ubyte*48)()
                lib.encode(source_input,residual,record,nxt,1)
                actual=bytes(record)
                assert actual[32:]==expected[t][32:]==old[t][32:],(w,h,t,'fields')
                assert actual[:32]==expected[t][:32],(w,h,t,'digits')
                checks['events']+=1;checks['fields']+=16;checks['digits']+=128
                residual=nxt;nxt=(ctypes.c_float*128)()
            assert sha(bytes(residual))==prefix['residual_after'],(w,h,t,'after')
            checks['residual_states']+=1;checks['prefixes']+=1
        assert sha(bytes(residual))==head['residual_final']
Path(HERE/'parity-receipt.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:v for k,v in checks.items() if isinstance(v,int)}))
