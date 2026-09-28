"""Decode every raw device state into its original chronological records and donor residual receipts."""
import hashlib
import json
import struct
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SOURCE=ROOT/'kivi-value-intern'
BASE=ROOT/'kivi-two-bit-causal'
DONOR=ROOT/'kivi-value-error-moment'
SHA=lambda b: hashlib.sha256(b).hexdigest()
KC=18944
SIZE=305156

def audit(tag,path):
    arrival=(SOURCE/f'{tag}-events.bin').read_bytes()
    source=json.loads((SOURCE/f'{tag}-manifest.json').read_text())
    assert len(arrival)==256*4098 and SHA(arrival)==source['events_sha256']
    manifest=json.loads((DONOR/f'{tag}-manifest.json').read_text())
    assert SHA(arrival)==manifest['source_sha256']
    base=json.loads((BASE/f'{tag}-manifest.json').read_text())
    streams=[]
    for mode in range(2):
        histories=[]
        for h in range(8):
            file=BASE/f'{tag}-head{h}-events.bin'
            raw=file.read_bytes()
            receipt=base['groups'][f'kv{h}']
            assert SHA(raw)==receipt['events_sha256']
            k=[];v=[];at=0
            while at<len(raw):
                kind=raw[at:at+1];t=int.from_bytes(raw[at+1:at+3],'little');width=1536 if kind==b'K' else 48
                assert kind in (b'K',b'V') and at+3+width<=len(raw)
                payload=raw[at+3:at+3+width]
                if kind==b'K':assert t==32*(len(k)+1);k.append(payload)
                else:assert t==33+len(v);v.append(payload)
                at+=3+width
            assert len(k)==8 and len(v)==224
            histories.append((k,v,receipt))
        streams.append(histories)
    frames=0;records=0;residuals=0;digest=hashlib.sha256();size=0
    with open(path,'rb') as f:
        for mode in range(2):
            history=streams[mode]
            for t in range(1,257):
                event=arrival[(t-1)*4098:t*4098];assert int.from_bytes(event[:2],'little')==t
                for phase in range(2):
                    header=f.read(8);assert len(header)==8
                    arm,ph,stamp,n=struct.unpack('<BBHI',header)
                    assert (arm,ph,stamp,n)==(mode,phase,t,SIZE+mode*4096)
                    blob=f.read(n);assert len(blob)==n
                    digest.update(header);digest.update(blob);size+=8+n;frames+=1
                    cache,res=(blob[:SIZE],blob[SIZE:])
                    assert struct.unpack_from('<i',cache,SIZE-4)==(0,)
                    nq=max(0,t-33)+(phase if t>=33 else 0)
                    nchunk=(t-1)//32+(phase if t%32==0 else 0)
                    nkr=t-nchunk*32
                    nr=t-nq
                    qbase=8*KC;rbase=qbase+8*224*48
                    for h,(keys,values,receipt) in enumerate(history):
                        recentk=b''.join(arrival[(j-1)*4098+2+h*256:(j-1)*4098+2+(h+1)*256] for j in range(nchunk*32+1,t+1))
                        recentv=b''.join(arrival[(j-1)*4098+2050+h*256:(j-1)*4098+2050+(h+1)*256] for j in range(nq+1,t+1))
                        assert len(recentk)==nkr*256 and len(recentv)==nr*256
                        observedk=cache[h*KC:h*KC+nchunk*1536+nkr*256]
                        assert observedk==b''.join(keys[:nchunk])+recentk,(mode,t,phase,h,'K')
                        observedv=cache[qbase+h*224*48:qbase+h*224*48+nq*48]
                        assert observedv==b''.join(values[:nq]),(mode,t,phase,h,'V')
                        for j in range(nr):
                            ring=(nq+j)%33
                            got=cache[rbase+h*33*256+ring*256:rbase+h*33*256+(ring+1)*256]
                            assert got==recentv[j*256:(j+1)*256],(mode,t,phase,h,'recent')
                        logical=observedk[:nchunk*1536]+observedv+recentk+recentv
                        expected=receipt['prefixes'][t-1]['before_query_flush' if phase==0 else 'after_query_flush']
                        assert SHA(logical)==expected['sha256'] and len(logical)==expected['bytes'],(mode,t,phase,h,'prefix')
                        if mode:
                            trace=manifest['heads'][h]['trace'][t-1]
                            r=res[h*512:(h+1)*512]
                            assert SHA(r)==trace['before' if phase==0 else 'after'],(mode,t,phase,h,'moment')
                            residuals+=1
                        records+=nchunk+nq+nr+(bool(nkr))
                    if phase==0 and t in (128,256):
                        for h in range(8):
                            if mode==1:
                                image=manifest['snapshots'][str(t)][h]
                                assert SHA(res[h*512:(h+1)*512])==image['sha256']
        assert f.read(1)==b''
    receipt={'tag':tag,'frames':frames,'ordered_records':records,'moment_checks':residuals,'snapshot_bytes':size,'snapshot_sha256':digest.hexdigest()}
    assert frames==1024 and residuals==4096
    return receipt
if __name__=='__main__':print(json.dumps(audit(sys.argv[1],sys.argv[2])))
