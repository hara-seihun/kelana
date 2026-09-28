"""Independent CPU control encoder and original-record FP32 moment replay, all phases."""
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path
import numpy as np
import audit
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-two-bit-causal'
MOMENT=ROOT/'kivi-value-error-moment'
SHA=lambda x:hashlib.sha256(x).hexdigest()

def run(tag):
    raw=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
    receipt=json.loads((MOMENT/f'{tag}-manifest.json').read_text())
    assert SHA(raw)==receipt['source_sha256']
    records=[]
    for h in range(8):
        stream=(BASE/f'{tag}-head{h}-events.bin').read_bytes()
        assert SHA(stream)==receipt['heads'][h]['donor_log_sha256']
        values=[];offset=0
        while offset<len(stream):
            kind=stream[offset:offset+1];width=1536 if kind==b'K' else 48
            if kind==b'V':values.append(stream[offset+3:offset+51])
            offset+=3+width
        assert len(values)==224
        records.append(values)
    output=HERE/f'{tag}-cpu-physical.tmp'
    with output.open('wb') as f:
        for mode in (0,1):
            moment=np.zeros((8,128),dtype='<f4')
            proc=subprocess.Popen([str(HERE/'cpu-reference'),str(ROOT/'kivi-value-intern'/f'{tag}-events.bin'),'control'],stdout=subprocess.PIPE)
            try:
                for t in range(1,257):
                    for phase in (0,1):
                        header=proc.stdout.read(8);assert len(header)==8
                        arm,ph,stamp,size=struct.unpack('<BBHI',header)
                        assert (arm,ph,stamp,size)==(0,phase,t,305156)
                        state=proc.stdout.read(size);assert len(state)==size
                        if mode:
                            if phase and t>=33:
                                j=t-33
                                event=raw[j*4098:(j+1)*4098]
                                for h in range(8):
                                    v=np.frombuffer(event[2050+256*h:2050+256*(h+1)],dtype='<u2').astype('<u4')
                                    source=(v<<16).view('<f4')
                                    record=records[h][j]
                                    code=np.frombuffer(record[:32],dtype='u1')
                                    digits=np.column_stack((code&3,(code>>2)&3,(code>>4)&3,code>>6)).reshape(4,32).astype('<f4')
                                    fields=np.frombuffer(record[32:],dtype='<f2').astype('<f4').reshape(4,2)
                                    decoded=np.add(fields[:,0,None],np.multiply(fields[:,1,None],digits,dtype='<f4'),dtype='<f4').reshape(128)
                                    error=np.subtract(source,decoded,dtype='<f4')
                                    moment[h]=np.add(moment[h],error,dtype='<f4')
                            for h in range(8):
                                expected=receipt['heads'][h]['trace'][t-1]['before' if phase==0 else 'after']
                                assert SHA(moment[h].tobytes())==expected,(tag,t,phase,h)
                            state+=moment.tobytes()
                            header=struct.pack('<BBHI',1,phase,t,len(state))
                        f.write(header);f.write(state)
                assert proc.stdout.read(1)==b'' and proc.wait(timeout=5)==0
            finally:
                if proc.poll() is None:proc.kill();proc.wait()
    try:return audit.audit(tag,output)
    finally:output.unlink()
if __name__=='__main__':print(json.dumps(run(sys.argv[1])))
