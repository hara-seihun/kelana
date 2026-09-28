#!/usr/bin/env python3
"""Merge fitted output gains into existing FP16 factor scales, with no new runtime bytes."""
import argparse
import json
import shutil
from pathlib import Path

import numpy as np

from fit import DATA, SEED, HERE, sha


def run(step):
    checkpoint=DATA/f'checkpoint{step:02}.npz'
    receipt=json.loads((DATA/f'checkpoint{step:02}.json').read_text())
    seed_manifest=SEED/'manifest.json'
    if sha(checkpoint)!=receipt['image_sha256'] or sha(seed_manifest)!=receipt['seed_manifest_sha256']:
        raise ValueError('source checkpoint or seed differs')
    original=json.loads(seed_manifest.read_text())
    destination=DATA/f'image-gain{step:02}'
    if destination.exists():raise FileExistsError(f'choose new candidate directory: {destination}')
    destination.mkdir(parents=True)
    for name in ('head.json','tied.npz','norms.npz','config.json'):
        shutil.copy2(SEED/name,destination/name)
    updated=[]
    with np.load(checkpoint) as gains:
        for i,entry in enumerate(original['body']):
            source=SEED/entry['path']
            if sha(source)!=entry['sha256']:raise ValueError(f'changed input image {source}')
            with np.load(source) as z:arrays={k:z[k].copy() for k in z.files}
            old=arrays['scale_post'].astype(np.float32)
            gain=gains[f'g{i}'].copy()
            if len(gain)!=len(old) or not np.isfinite(gain).all() or gain.min()<0.5 or gain.max()>2.:
                raise ValueError(f'invalid fitted factor multiplier: {i}')
            merged=(old*gain).astype(np.float16)
            if not np.isfinite(merged).all() or (merged<0).any():raise ValueError('FP16 scale overflow')
            arrays['scale_post']=merged
            target=destination/entry['path']
            np.savez(target,**arrays)
            updated.append({**entry,'sha256':sha(target),'container_bytes':target.stat().st_size,
                            'payload_bytes':sum(v.nbytes for v in arrays.values())})
    new={**original,'format':'qwen-subbit-model-calibrated-image/1',
         'source_sha256':sha(HERE/'publish.py'),
         'seed_manifest_sha256':sha(seed_manifest),'checkpoint_receipt_sha256':sha(DATA/f'checkpoint{step:02}.json'),
         'checkpoint_image_sha256':sha(checkpoint),
         'body':updated,
         'payload_bytes':sum(e['payload_bytes'] for e in updated)+original['tied']['payload_bytes']+original['norms']['payload_bytes']}
    new['payload_bpw']=8*new['payload_bytes']/new['unique_parameters']
    new['container_bytes_without_manifest']=sum(p.stat().st_size for p in destination.iterdir() if p.is_file())
    new['calibration']='196 frozen U/V factors; original scale_pre and norm bits unchanged; original FP16 scale_post multiplied by trained per-output gain and rounded back to FP16'
    if new['payload_bytes']!=original['payload_bytes'] or new['payload_bpw']!=original['payload_bpw']:
        raise ValueError('new runtime bytes in zero-byte calibration')
    (destination/'manifest.json').write_text(json.dumps(new,indent=2)+'\n')
    report={'format':'qwen-model-scale-image/1','source_sha256':sha(HERE/'publish.py'),
            'image_manifest_sha256':sha(destination/'manifest.json'),
            'seed_manifest_sha256':sha(seed_manifest),'checkpoint_sha256':sha(checkpoint),
            'payload_bytes':new['payload_bytes'],'payload_bpw':new['payload_bpw'],
            'changed_body_images':sum(a['sha256']!=b['sha256'] for a,b in zip(updated,original['body'])),
            'model_norm_bytes_changed':False,'head_bytes_changed':False,
            'output':str(destination)}
    (DATA/f'image-gain{step:02}.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('step',type=int)
    run(p.parse_args().step)
