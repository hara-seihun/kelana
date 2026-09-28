#!/usr/bin/env python3
"""Collect complete-image quality and accounting without rerunning a model."""
import argparse
import json
from pathlib import Path

from capture import ROOT, sha


def main(args):
    data=ROOT/'full-model'
    names=['head-reforward','mixed-head-reforward','binary055-quality','binary055-refined-quality',
           'binary055-affine-quality','attention-only-quality','mlp-only-quality',
           'query-key-quality','value-output-quality']
    runs=[]
    for path in [*(data/(n+'.json') for n in names),ROOT/'model-tuning/quality-gain08.json',*args.extra]:
        record=json.loads(path.read_text())
        runs.append({'path':str(path),'sha256':sha(path),'image':record['image'],
                     'body_scope':record.get('body_scope','all'),'tokens_sha256':record['tokens_sha256'],
                     'source_hashes':record['source_hashes'],'arms':record['arms']})
    images=[]
    for path in [data/'image-binary055',data/'image-binary055-refined',data/'image-binary055-affine',
                 ROOT/'model-tuning/image-gain08',*args.images]:
        record=json.loads((path/'manifest.json').read_text())
        serialized=sum(p.stat().st_size for p in path.iterdir() if p.is_file())
        images.append({'path':str(path),'manifest_sha256':sha(path/'manifest.json'),
                       'unique_parameters':record['unique_parameters'],'payload_bytes':record['payload_bytes'],
                       'payload_bpw':record['payload_bpw'],'serialized_bytes':serialized,
                       'serialized_bpw':8*serialized/record['unique_parameters'],
                       'body_matrices':len(record['body']),'body_parameters':sum(e['parameters'] for e in record['body']),
                       'body_payload_bytes':sum(e['payload_bytes'] for e in record['body']),
                       'tied_payload_bytes':record['tied']['payload_bytes'],'norm_payload_bytes':record['norms']['payload_bytes']})
    result={'format':'qwen-subbit-full-model-results/1','sources':{'summary':sha(Path(__file__))},
            'capture_manifest_sha256':sha(data/'capture/manifest.json'),
            'fit_inputs_manifest_sha256':sha(data/'fit-inputs/manifest.json'),'images':images,'runs':runs}
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'images':len(images),'quality_runs':len(runs),'out':str(args.out)}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--extra',type=Path,nargs='*',default=[])
    p.add_argument('--images',type=Path,nargs='*',default=[])
    p.add_argument('--out',type=Path,default=Path(__file__).with_name('results.json'))
    main(p.parse_args())
