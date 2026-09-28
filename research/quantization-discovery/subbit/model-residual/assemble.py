#!/usr/bin/env python3
"""Build two paid complete images with nested FP16 response-residual body factors."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    base=json.loads((args.base/'manifest.json').read_text())
    if len(base['body'])!=196: raise ValueError('base needs 196 body matrices')
    by_key={}
    receipts={}
    for layer in range(28):
        path=args.fits/f'layer{layer:02d}'/'run.json'
        report=json.loads(path.read_text())
        if report['base_manifest_sha256']!=sha(args.base/'manifest.json') or len(report['records'])!=7:
            raise ValueError(f'incomplete or wrong-base fit receipt: {path}')
        receipts[str(path)]=sha(path)
        for record in report['records']:
            if record['key'] in by_key:raise ValueError('duplicate matrix fit')
            by_key[record['key']]={**record,'capture_sha256':report['capture_sha256']}
    if len(by_key)!=196:raise ValueError(f'need 196 unique fits, got {len(by_key)}')
    for rank in (8,16):
        destination=args.out/f'rank{rank}'
        destination.mkdir(parents=True,exist_ok=True)
        for name in ('tied.npz','head.json','norms.npz','config.json'):
            shutil.copy2(args.base/name,destination/name)
        head=dict(base['tied'])
        if sha(destination/head['path'])!=head['sha256']:
            raise ValueError('tied head changed during copy')
        entries=[]
        for entry in base['body']:
            original=args.base/entry['path']
            record=by_key[entry['key']]
            factor=Path(record['residual_image'])
            if sha(original)!=entry['sha256'] or sha(factor)!=record['residual_image_sha256']:
                raise ValueError(f'changed image or factor for {entry["key"]}')
            with np.load(original) as image,np.load(factor) as extra:
                arrays={k:image[k] for k in image.files}
                left=extra['residual_left'][:,:rank].copy()
                right=extra['residual_right'][:rank,:].copy()
            if left.shape!=(entry['parameters']//arrays['dimensions'][1],rank) or right.shape!=(rank,arrays['dimensions'][1]):
                raise ValueError(f'bad factor dimensions for {entry["key"]}')
            arrays.update(residual_left=left,residual_right=right)
            target=destination/entry['path']
            np.savez(target,**arrays)
            body=dict(entry)
            body.update(base_image_sha256=entry['sha256'],
                        residual_source_sha256=record['residual_image_sha256'],
                        train_capture_sha256=record['capture_sha256'],
                        residual_rank=rank,residual_payload_bytes=left.nbytes+right.nbytes,
                        payload_bytes=sum(a.nbytes for a in arrays.values()),
                        container_bytes=target.stat().st_size,
                        residual_train_response_error=record['train_validation']['train'][f'rank{rank}_relative_squared_error'],
                        residual_validation_response_error=record['train_validation']['validation'][f'rank{rank}_relative_squared_error'],
                        base_validation_response_error=record['train_validation']['validation']['baseline_binary_relative_squared_error'],
                        sha256=sha(target))
            entries.append(body)
        payload=sum(e['payload_bytes'] for e in entries)+head['payload_bytes']+base['norms']['payload_bytes']
        report={'format':base['format'],'source_sha256':sha(Path(__file__)),
                'base_manifest_path':str(args.base/'manifest.json'),
                'base_manifest_sha256':sha(args.base/'manifest.json'),
                'base_fit_receipts':base['fit_receipts'],'residual_fit_receipts':receipts,
                'model_source_sha256':base['model_source_sha256'],
                'body':entries,'tied':head,'norms':base['norms'],'config_sha256':base['config_sha256'],
                'unique_parameters':base['unique_parameters'],'payload_bytes':payload,
                'payload_bpw':8*payload/base['unique_parameters'],
                'base_payload_bytes':base['payload_bytes'],'base_payload_bpw':base['payload_bpw'],
                'added_residual_payload_bytes':payload-base['payload_bytes'],
                'residual_rank':rank,
                'online_per_projection':'two extra FP16 factor matmuls, one FP32 rank intermediate write/read and one FP32 output addition; base binary/head work remains paid',
                'container_bytes_without_manifest':sum(p.stat().st_size for p in destination.iterdir() if p.is_file() and p.name!='manifest.json')}
        if len(entries)!=196 or len({e['key'] for e in entries})!=196:
            raise ValueError('incomplete candidate body')
        (destination/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'image':str(destination),'rank':rank,'payload_bytes':payload,
                          'bpw':report['payload_bpw'],'added_bytes':report['added_residual_payload_bytes']}),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base',type=Path,required=True)
    p.add_argument('--fits',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    run(p.parse_args())
