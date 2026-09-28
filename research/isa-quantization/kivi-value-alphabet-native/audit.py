"""Independent physical K/V and code audit against original and frozen candidate logs."""
import hashlib,json,struct,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SOURCE=ROOT/'kivi-value-intern'
BASE=ROOT/'kivi-two-bit-causal'
CAND=ROOT/'kivi-value-alphabet'
SHA=lambda b:hashlib.sha256(b).hexdigest()
KC=18944
SIZE=305156

def events(raw):
    k=[];v=[];at=0
    while at<len(raw):
        kind=raw[at:at+1];t=int.from_bytes(raw[at+1:at+3],'little')
        width=1536 if kind==b'K' else 48
        assert kind in (b'K',b'V') and at+3+width<=len(raw)
        payload=raw[at+3:at+3+width];at+=3+width
        if kind==b'K':assert t==32*(len(k)+1);k.append(payload)
        else:assert t==33+len(v);v.append(payload)
    assert at==len(raw) and len(k)==8 and len(v)==224
    return k,v

def source(tag):
    arrival=(SOURCE/f'{tag}-events.bin').read_bytes()
    owner=json.loads((SOURCE/f'{tag}-manifest.json').read_text())
    assert len(arrival)==256*4098 and SHA(arrival)==owner['events_sha256']
    original=json.loads((BASE/f'{tag}-manifest.json').read_text())
    candidate=json.loads((CAND/f'{tag}-layer0-manifest.json').read_text())
    assert candidate['peak_dynamic_bytes']==304768 and candidate['shared_table_bytes']==16
    assert SHA((CAND/'layer0-alphabet.f32').read_bytes())==candidate['table_sha256']
    histories=[]
    for h in range(8):
        raw=(BASE/f'{tag}-head{h}-events.bin').read_bytes()
        own=original['groups'][f'kv{h}'];assert SHA(raw)==own['events_sha256']
        other=candidate['heads'][h];assert other['original_events_sha256']==SHA(raw)
        cand=(CAND/f'{tag}-layer0-h{h}-events.bin').read_bytes()
        assert SHA(cand)==other['events_sha256']
        ok,ov=events(raw);ck,cv=events(cand)
        assert ok==ck and all(a[32:]==b[32:] for a,b in zip(ov,cv))
        histories.append((ok,ov,cv,own,other))
    return arrival,histories

def audit(tag,path):
    arrival,histories=source(tag)
    frames=0;records=0;digits=0;digest=hashlib.sha256();size=0
    with open(path,'rb') as f:
        for mode in (0,1):
            for t in range(1,257):
                event=arrival[(t-1)*4098:t*4098];assert int.from_bytes(event[:2],'little')==t
                for phase in (0,1):
                    header=f.read(8);assert len(header)==8
                    arm,ph,stamp,n=struct.unpack('<BBHI',header)
                    assert (arm,ph,stamp,n)==(mode,phase,t,SIZE)
                    cache=f.read(n);assert len(cache)==n
                    digest.update(header);digest.update(cache);size+=8+n;frames+=1
                    assert struct.unpack_from('<i',cache,SIZE-4)==(0,)
                    nv=max(0,t-33)+(phase if t>=33 else 0)
                    nk=(t-1)//32+(phase if t%32==0 else 0)
                    nkr=t-nk*32;nr=t-nv
                    qbase=8*KC;rbase=qbase+8*224*48
                    for h,(keys,original_v,candidate_v,owner,other) in enumerate(histories):
                        kr=b''.join(arrival[(j-1)*4098+2+h*256:(j-1)*4098+2+(h+1)*256] for j in range(nk*32+1,t+1))
                        vr=b''.join(arrival[(j-1)*4098+2050+h*256:(j-1)*4098+2050+(h+1)*256] for j in range(nv+1,t+1))
                        assert len(kr)==nkr*256 and len(vr)==nr*256
                        key=cache[h*KC:h*KC+nk*1536+nkr*256]
                        assert key==b''.join(keys[:nk])+kr,(mode,t,phase,h,'key')
                        expected_v=(candidate_v if mode else original_v)[:nv]
                        value=cache[qbase+h*224*48:qbase+h*224*48+nv*48]
                        assert value==b''.join(expected_v),(mode,t,phase,h,'value/code/fields')
                        for j in range(nr):
                            ring=(nv+j)%33
                            got=cache[rbase+h*33*256+ring*256:rbase+h*33*256+(ring+1)*256]
                            assert got==vr[j*256:(j+1)*256],(mode,t,phase,h,'recent')
                        logical=key[:nk*1536]+value+kr+vr
                        if mode:
                            prefix=other['prefix'][t-1]
                            expected=prefix['before_sha256' if phase==0 else 'after_sha256']
                            length=prefix['before_bytes' if phase==0 else 'after_bytes']
                        else:
                            prefix=owner['prefixes'][t-1]['before_query_flush' if phase==0 else 'after_query_flush']
                            expected=prefix['sha256'];length=prefix['bytes']
                        assert len(logical)==length and SHA(logical)==expected,(mode,t,phase,h,'prefix')
                        records+=nk+nv+nr+bool(nkr)
                        if mode and phase and t>=33:digits+=128
        assert f.read(1)==b''
    assert frames==1024 and digits==8*224*128
    return {'tag':tag,'frames':frames,'ordered_records':records,'candidate_codes':digits,'snapshot_bytes':size,'snapshot_sha256':digest.hexdigest()}
if __name__=='__main__':print(json.dumps(audit(sys.argv[1],sys.argv[2])))
