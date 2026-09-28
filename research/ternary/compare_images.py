#!/usr/bin/env python3
"""Count real trit and FP16 scale changes between two paid complete images."""
import argparse
import json
from pathlib import Path
import numpy as np
from pilot import ROOT, sha


def compare(source, candidate):
    left=json.loads((source/'manifest.json').read_text())
    right=json.loads((candidate/'manifest.json').read_text())
    a={r['key']:r for r in left['matrices']};b={r['key']:r for r in right['matrices']}
    if set(a)!=set(b) or not left['complete'] or not right['complete']:raise ValueError('Need matching complete images')
    records=[]
    for key in sorted(a):
        name=key.replace('.','_')+'.npz'
        if sha(source/name)!=a[key]['sha256'] or sha(candidate/name)!=b[key]['sha256']:raise ValueError('Changed image hash')
        with np.load(source/name) as x,np.load(candidate/name) as y:
            if not np.array_equal(x['shape'],y['shape']) or not np.array_equal(x['signs'],y['signs']):raise ValueError('Shape/signs changed')
            if int(x['rotation_block'])!=int(y['rotation_block']):raise ValueError('Rotation changed')
            differs=x['codes']!=y['codes']
            p=np.array([1,3,9,27,81],dtype=np.int16)
            xc=(x['codes'][differs,None].astype(np.int16)//p)%3
            yc=(y['codes'][differs,None].astype(np.int16)//p)%3
            records.append(dict(key=key,changed_trits=int((xc!=yc).sum()),
                                changed_scales=int((x['scales'].view(np.uint16)!=y['scales'].view(np.uint16)).sum()),
                                source_payload=a[key]['payload_bytes'],candidate_payload=b[key]['payload_bytes']))
    return dict(source=str(source),candidate=str(candidate),source_manifest_sha256=sha(source/'manifest.json'),
                candidate_manifest_sha256=sha(candidate/'manifest.json'),
                source_payload_bytes=left['payload_bytes'],candidate_payload_bytes=right['payload_bytes'],
                changed_trits=sum(r['changed_trits'] for r in records),
                changed_scales=sum(r['changed_scales'] for r in records),matrices=records)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('candidate')
    a=p.parse_args();result=compare(ROOT/a.source,ROOT/a.candidate)
    out=ROOT/a.candidate/'image-difference.json';out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='matrices'}))
