"""Emit one frozen deterministic V2 pair-code stream from original donor fields."""
import sys,json
import numpy as np
from common import HERE,CONTEXT,BASE,sha,pairs,metrics
sys.path.insert(0,str(CONTEXT))
from custody import source
from replay import packed_digits

def held(w):
    from common import ARRIVAL,checked
    name=f'held-{w}';manifest=json.loads((ARRIVAL/f'{name}-manifest.json').read_text())
    raw=checked(ARRIVAL/f'{name}-events.bin',manifest['events_sha256'])
    k=np.empty((256,8,128),dtype='<u2');v=np.empty_like(k)
    for t in range(1,257):
        row=raw[(t-1)*4098:t*4098];assert len(row)==4098 and int.from_bytes(row[:2],'little')==t
        k[t-1]=np.frombuffer(row[2:2050],dtype='<u2').reshape(8,128)
        v[t-1]=np.frombuffer(row[2050:],dtype='<u2').reshape(8,128)
    return {'k':k,'v':v},sha(raw)
def donor(panel,w,h):
    name=f'{panel}-{w}'
    if panel=='held':
        manifest=json.loads((BASE/f'{name}-manifest.json').read_text());meta=manifest['groups'][f'kv{h}'];path=BASE/f'{name}-head{h}-events.bin'
    else:
        manifest=json.loads((CONTEXT/f'{name}-manifest.json').read_text());meta=manifest['arms']['original']['heads'][h];path=CONTEXT/f'{name}-original-h{h}-events.bin'
    raw=path.read_bytes();assert sha(raw)==meta['events_sha256'];return raw,meta,sha((BASE if panel=='held' else CONTEXT).joinpath(f'{name}-manifest.json').read_bytes())
def events(raw):
    p=0
    while p<len(raw):
        typ=raw[p:p+1];size=1536 if typ==b'K' else 48
        assert typ in (b'K',b'V') and p+3+size<=len(raw)
        yield typ,int.from_bytes(raw[p+1:p+3],'little'),raw[p+3:p+3+size]
        p+=3+size
    assert p==len(raw)
def digits(source,blob,idx,gram):
    words=(np.asarray(source,dtype='<u4')<<16).view('<f4');field=np.frombuffer(blob[32:],dtype='<f2').astype('<f4').reshape(4,2)
    levels=np.empty((128,4),dtype='<f4')
    for g in range(4):
        for d in range(4):
            product=np.float32(field[g,1]*np.float32(d))
            levels[g*32:(g+1)*32,d]=np.float32(field[g,0]+product)
    out=np.empty(128,dtype='u1');before=after=0.
    original=packed_digits(blob[:32],2,128)
    for p,(i,j) in enumerate(idx):
        a,b,c=(float(v) for v in gram[p]);vi=float(words[i]);vj=float(words[j]);best=None
        for x in range(4):
            ei=vi-float(levels[i,x])
            for y in range(4):
                ej=vj-float(levels[j,y]);energy=a*ei*ei+2*b*ei*ej+c*ej*ej
                if best is None or energy<best[0]:best=(energy,x,y)
        out[i],out[j]=best[1:];after+=best[0]
        ei=vi-float(levels[i,int(original[i])]);ej=vj-float(levels[j,int(original[j])])
        before+=a*ei*ei+2*b*ei*ej+c*ej*ej
    packed=(out[::4]|(out[1::4]<<2)|(out[2::4]<<4)|(out[3::4]<<6)).tobytes()
    return packed+blob[32:],before,after

def run(panel,w):
    assert panel in ('train','validation','held')
    arrays,src=(held(w) if panel=='held' else source(panel,w))
    name=f'{panel}-{w}';layer=int(panel!='held');indices=pairs(layer);grams=metrics(layer)
    rows=[]
    for h in range(8):
        original,owner,donor_sha=donor(panel,w,h);kq=[];vq=[];kr=[];vr=[];out=bytearray();trace=[];ix=iter(events(original));energies=np.zeros(2,dtype='<f8');peak=0
        for t in range(1,257):
            kr.append(arrays['k'][t-1,h].tobytes());vr.append(arrays['v'][t-1,h].tobytes())
            pre=b''.join(kq+vq+kr+vr);peak=max(peak,len(pre));row={'pre':sha(pre),'pre_bytes':len(pre)}
            if t in (128,256):
                file=f'{name}-t{t}-h{h}.bin';(HERE/file).write_bytes(pre);row['image']=file
            if len(kr)==32:
                typ,at,blob=next(ix);assert (typ,at)==(b'K',t)
                kq.append(blob);out+=b'K'+t.to_bytes(2,'little')+blob;kr=[]
            if len(vr)==33:
                typ,at,blob=next(ix);assert (typ,at)==(b'V',t)
                changed,old,new=digits(np.frombuffer(vr.pop(0),dtype='<u2'),blob,indices[h],grams[h]);energies+=(old,new)
                vq.append(changed);out+=b'V'+t.to_bytes(2,'little')+changed
            post=b''.join(kq+vq+kr+vr);row.update(post=sha(post),post_bytes=len(post));trace.append(row)
        assert next(ix,None) is None and len(vq)==224 and peak==38096
        stem=f'{name}-h{h}';(HERE/f'{stem}-events.bin').write_bytes(out);(HERE/f'{stem}-final.bin').write_bytes(post)
        rows.append({'donor_sha256':sha(original),'donor_manifest_sha256':donor_sha,'events_sha256':sha(out),'final_sha256':sha(post),'peak_bytes':peak,'final_bytes':len(post),'represented_original_energy':float(energies[0]),'represented_candidate_energy':float(energies[1]),'trace':trace})
    receipt={'panel':panel,'window':w,'layer':layer,'source_sha256':src if panel=='held' else src['source_file_sha256'],'pair_sha256':sha((HERE.parent/'value-pair-covariance/pair-map.bin').read_bytes()),'metric_sha256':sha((HERE/'metric.bin').read_bytes()),'heads':rows,'peak_sequence_bytes':304768,'final_sequence_bytes':249856}
    (HERE/f'{name}-manifest.json').write_text(json.dumps(receipt,separators=(',',':'))+'\n')
    print(name,'represented',sum(x['represented_original_energy'] for x in rows),sum(x['represented_candidate_energy'] for x in rows))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
