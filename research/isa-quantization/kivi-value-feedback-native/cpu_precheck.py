"""Exercise device physical decoder on independent CPU-built control and donor feedback images."""
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'kivi-value-error-feedback'))
import replay
import audit

def value_records(path):
    data=path.read_bytes();records=[];p=0
    while p<len(data):
        kind=data[p:p+1];size=1536 if kind==b'K' else 48
        if kind==b'V':records.append(data[p+3:p+3+48])
        p+=3+size
    assert len(records)==224
    return records

def run(tag):
    raw=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
    original=[[value_records(ROOT/'kivi-two-bit-causal'/f'{tag}-head{h}-events.bin') for h in range(8)],
              [value_records(ROOT/'kivi-value-error-feedback'/f'{tag}-feedback-head{h}-events.bin') for h in range(8)]]
    output=HERE/f'{tag}-cpu-physical.tmp'
    with output.open('wb') as f:
        for mode in (0,1):
            residual=[np.zeros(128,dtype='<f4') for _ in range(8)]
            proc=subprocess.Popen([str(HERE/'cpu-reference'),str(ROOT/'kivi-value-intern'/f'{tag}-events.bin'),'control'],stdout=subprocess.PIPE)
            try:
                for t in range(1,257):
                    for phase in (0,1):
                        header=proc.stdout.read(8);assert len(header)==8
                        arm,ph,stamp,size=struct.unpack('<BBHI',header)
                        assert (arm,ph,stamp,size)==(0,phase,t,305156)
                        state=bytearray(proc.stdout.read(size));assert len(state)==size
                        if mode:
                            if phase and t>=33:
                                j=t-33
                                event=raw[(t-33)*4098:(t-32)*4098]
                                for h in range(8):
                                    source=event[2050+256*h:2050+256*(h+1)]
                                    encoded,next_r=replay.independent_value(source,residual[h],original[0][h][j])
                                    assert encoded==original[1][h][j],(tag,t,h)
                                    residual[h]=next_r
                            nq=max(0,t-33)+(phase if t>=33 else 0)
                            for h in range(8):
                                start=8*18944+h*224*48
                                state[start:start+nq*48]=b''.join(original[1][h][:nq])
                            state.extend(b''.join(x.tobytes() for x in residual))
                            header=struct.pack('<BBHI',1,phase,t,len(state))
                        f.write(header);f.write(state)
                assert proc.stdout.read(1)==b'' and proc.wait(timeout=5)==0
            finally:
                if proc.poll() is None:proc.kill();proc.wait()
    try:return audit.audit(tag,output)
    finally:output.unlink()
if __name__=='__main__':print(json.dumps(run(sys.argv[1])))
