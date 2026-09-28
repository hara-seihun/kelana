"""Independent byte/phase/source-field argmin audit and complete original-O observer."""
import sys,json,math
from build import held,donor
import numpy as np
import torch
from common import HERE,CONTEXT,BASE,SNAP,ARRIVAL,PAIR,sha,checked,pairs,metrics,o_matrix
sys.path.insert(0,str(CONTEXT))
from custody import source
from replay import expect_k,expect_v,packed_digits,decode,score

def parse_stream(raw):
    result=[];cursor=0
    while cursor<len(raw):
        assert cursor+3<=len(raw)
        typ=raw[cursor:cursor+1];assert typ in (b'K',b'V')
        timestamp=int.from_bytes(raw[cursor+1:cursor+3],'little');assert 1<=timestamp<=256
        stop=cursor+3+(1536 if typ==b'K' else 48)
        assert stop<=len(raw)
        result.append((typ,timestamp,raw[cursor+3:stop]));cursor=stop
    assert cursor==len(raw)
    return result

def independent_choice(raw,original,actual,edges,gram):
    expect_v(raw,original,2,None)
    assert original[32:]==actual[32:] and len(actual)==48
    words=(np.asarray(raw,dtype='<u4')<<16).view('<f4').astype('<f8')
    field=np.frombuffer(actual[32:],dtype='<f2').astype('<f4').reshape(4,2)
    levels=np.empty((128,4),dtype='<f4')
    for g in range(4):
        for d in range(4):
            product=np.multiply(field[g,1],np.float32(d),dtype='<f4')
            levels[g*32:g*32+32,d]=np.add(field[g,0],product,dtype='<f4')
    codes=packed_digits(actual[:32],2,128);old=packed_digits(original[:32],2,128)
    local=[0.,0.]
    for p,(i,j) in enumerate(edges):
        a,b,c=map(float,gram[p]);v_i=words[i];v_j=words[j]
        choices=[]
        for x in range(4):
            for y in range(4):
                ei=v_i-float(levels[i,x]);ej=v_j-float(levels[j,y])
                choices.append((a*ei**2+2*b*ei*ej+c*ej**2,x,y))
        choice=min(choices)
        assert (int(codes[i]),int(codes[j]))==choice[1:]
        assert choice[0]<=choices[int(old[i])*4+int(old[j])][0]+1e-14
        local[0]+=choices[int(old[i])*4+int(old[j])][0];local[1]+=choice[0]
    return local

def query(q,teacher,cache,o):
    states=[decode(s,2) for s in cache]
    out=score(q,[s[0] for s in states],[s[1] for s in states],o).astype('<f4')
    err=out.astype('<f8')-teacher.astype('<f8')
    return {'sse':float(np.dot(err,err)),'output_sha256':sha(out.tobytes())}

def run(panel,w):
    torch.set_num_threads(1)
    name=f'{panel}-{w}';m=json.loads((HERE/f'{name}-manifest.json').read_text());layer=int(panel!='held')
    assert m['layer']==layer and m['pair_sha256']==sha((PAIR/'pair-map.bin').read_bytes()) and m['metric_sha256']==sha((HERE/'metric.bin').read_bytes())
    arrays,src=(held(w) if panel=='held' else source(panel,w));assert m['source_sha256']==(src if panel=='held' else src['source_file_sha256'])
    o=torch.from_numpy(o_matrix(layer).copy());edges=pairs(layer);gram=metrics(layer)
    observation={t:{'candidate':[None]*8,'delay4':[None]*8,'original':[None]*8} for t in ((128,256) if panel=='held' else range(1,257))}
    sum_local=np.zeros(2,dtype='<f8');changed=0;prefixes=0
    for h,meta in enumerate(m['heads']):
        original,owner,donor_sha=donor(panel,w,h)
        assert meta['donor_sha256']==sha(original) and meta['donor_manifest_sha256']==donor_sha
        emitted=checked(HERE/f'{name}-h{h}-events.bin',meta['events_sha256'])
        donor_events=parse_stream(original);new_events=parse_stream(emitted);assert len(donor_events)==len(new_events)==232
        kq=[];vq=[];kr=[];vr=[];dvq=[];dvr=[];oi=ci=vi=0;peak=delay_peak=0;local=np.zeros(2,dtype='<f8')
        for t in range(1,257):
            kword=arrays['k'][t-1,h].tobytes();vword=arrays['v'][t-1,h].tobytes()
            kr.append(kword);vr.append(vword);dvr.append(vword)
            pre=b''.join(kq+vq+kr+vr);r=meta['trace'][t-1]
            assert (sha(pre),len(pre))==(r['pre'],r['pre_bytes']);peak=max(peak,len(pre))
            delay_peak=max(delay_peak,len(b''.join(kq+dvq+kr+dvr)));prefixes+=1
            donor_prefix=owner['prefixes'][t-1]['before_query_flush'] if panel=='held' else owner['prefix'][t-1]
            original_pre=b''.join(kq+[e[2] for e in donor_events if e[0]==b'V' and e[1]<t]+kr+vr)
            assert (sha(original_pre),len(original_pre))==((donor_prefix['sha256'],donor_prefix['bytes']) if panel=='held' else (donor_prefix['pre_sha256'],donor_prefix['pre_bytes']))
            if t in observation:
                observation[t]['candidate'][h]=(kq.copy(),vq.copy(),kr.copy(),vr.copy())
                observation[t]['delay4'][h]=(kq.copy(),dvq.copy(),kr.copy(),dvr.copy())
                observation[t]['original'][h]=(kq.copy(),[e[2] for e in donor_events if e[0]==b'V' and e[1]<t],kr.copy(),vr.copy())
            if 'image' in r:assert checked(HERE/r['image'],r['pre'])==pre
            if len(kr)==32:
                first=donor_events[oi];second=new_events[ci];oi+=1;ci+=1
                assert first==second and first[:2]==(b'K',t)
                expect_k(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128),second[2]);kq.append(second[2]);kr=[]
            if len(vr)==33:
                first=donor_events[oi];second=new_events[ci];oi+=1;ci+=1
                assert first[:2]==second[:2]==(b'V',t)
                srcword=np.frombuffer(vr.pop(0),dtype='<u2');assert np.array_equal(srcword,arrays['v'][t-33,h])
                pair=independent_choice(srcword,first[2],second[2],edges[h],gram[h]);local+=pair
                changed+=sum(a!=b for a,b in zip(first[2][:32],second[2][:32]));vq.append(second[2])
            if len(dvr)==37:
                donor_v=[e for e in donor_events if e[0]==b'V'][vi];vi+=1
                assert donor_v[1]==t-4 and dvr.pop(0)==arrays['v'][t-37,h].tobytes()
                dvq.append(donor_v[2])
            post=b''.join(kq+vq+kr+vr)
            assert (sha(post),len(post))==(r['post'],r['post_bytes'])
        assert (oi,ci,vi)==(232,232,220) and peak==meta['peak_bytes']==38096 and delay_peak==38928
        assert len(b''.join(kq+dvq+kr+dvr))==32064
        assert checked(HERE/f'{name}-h{h}-final.bin',meta['final_sha256'])==post
        assert len(post)==meta['final_bytes']==31232
        assert np.allclose(local,[meta['represented_original_energy'],meta['represented_candidate_energy']],rtol=1e-11,atol=1e-9)
        sum_local+=local
    assert m['peak_sequence_bytes']==304768 and m['final_sequence_bytes']==249856
    assert delay_peak*8==311424 and len(b''.join(kq+dvq+kr+dvr))*8==256512
    original_receipt=json.loads((CONTEXT if panel!='held' else HERE.parent/'kivi-value-error-moment').joinpath(f'{name}-result.json').read_text())
    snapshots=json.loads((SNAP/'snapshots.json').read_text()) if panel=='held' else None
    output=[]
    for t,arms in observation.items():
        if panel=='held':
            snap=next(s for s in snapshots['states'] if s['tag']==f'{name}-t{t}')
            q=np.frombuffer(checked(SNAP/f'{name}-t{t}-q.f32',snap['query_sha256']),dtype='<f4').copy().reshape(16,128)
            teacher=np.frombuffer(checked(SNAP/f'{name}-t{t}-teacher.f32',snap['teacher_sha256']),dtype='<f4').copy()
        else:q=arrays['q'][:,t-1,:];teacher=arrays['teacher'][t-1]
        row={'t':t,'teacher_sq':float(np.square(teacher.astype('<f8')).sum())}
        for arm in ('candidate','delay4','original'):row[arm]=query(q,teacher,arms[arm],o)
        prior=(original_receipt['rows'][0 if t==128 else 1] if panel=='held' else original_receipt['arms']['original'][t-1])
        prior_hash=prior['ordinary_output_sha256'] if panel=='held' else prior['output_sha256']
        assert row['original']['output_sha256']==prior_hash
        assert abs(row['original']['sse']-(prior['ordinary_sse'] if panel=='held' else prior['sse']))<1e-6
        output.append(row)
    receipt={'panel':panel,'window':w,'manifest_sha256':sha((HERE/f'{name}-manifest.json').read_bytes()),'source_sha256':m['source_sha256'],'query_count':len(output),'audited_prefixes':prefixes,'changed_code_bytes':changed,'represented_metric_energy':sum_local.tolist(),'rows':output}
    (HERE/f'{name}-result.json').write_text(json.dumps(receipt,separators=(',',':'))+'\n')
    print(name,len(output),[sum(r[a]['sse'] for r in output) for a in ('original','candidate','delay4')])
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
