#!/usr/bin/env python3
"""Run one bounded full-model fit group with durable input/source/output identity."""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

from fit import rank_for_rate

DEFAULT_MANIFEST = Path('/path/to/workspace/data/kelana-subbit/full-model/fit-inputs/manifest.json')
DEFAULT_OUT = Path('/path/to/workspace/data/kelana-subbit/full-model/binary055')
WRAPPER = '/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare'
PYTHON = '/path/to/workspace/data/fish-s2-pro/venv/bin/python'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(args):
    manifest=json.loads(args.manifest.read_text())
    task=manifest['tasks'][args.task]
    output=args.out/task['name']
    output.mkdir(parents=True,exist_ok=True)
    inputs=[Path(p) for p in task['inputs']]
    expected={Path(x['input']):x['input_sha256'] for x in manifest['matrices']}
    if len(inputs)>16 or any(p not in expected for p in inputs):
        raise ValueError('task must contain at most 16 declared input paths')
    source_hash=sha(args.source)
    for p in inputs:
        if sha(p)!=expected[p]: raise ValueError(f'input changed: {p}')
    prior=output/'run.json'
    if prior.exists():
        result=json.loads(prior.read_text())
        if result.get('complete'):
            same_inputs={Path(e['input']):e['input_sha256'] for e in result['entries']}=={p:expected[p] for p in inputs}
            same_fit=result['source_sha256']==source_hash and result['rank']==rank_for_rate(*result['normalized_shape'],args.rate)
            same_outputs=len(result['entries'])==len(inputs) and all(
                Path(e['image']).exists() and sha(Path(e['image']))==e['image_sha256'] for e in result['entries'])
            if not (same_inputs and same_fit and same_outputs):
                raise ValueError(f'{output}: completed receipt differs from requested fit; use a new output directory')
            print(json.dumps({'task':task['name'],'status':'already complete','entries':len(inputs)}),flush=True)
            return
    command=[WRAPPER,'--runtime-max','45s','--memory-gib','12','--pin-clock','--clock-log',str(output/'clock.json'),
             '--exec','env','OPENBLAS_NUM_THREADS=4',PYTHON,str(args.source),'--graph','--rate',str(args.rate),
             '--out',str(output),*[str(p) for p in inputs]]
    identity={'task_index':args.task,'task_name':task['name'],'rate':args.rate,
              'source':str(args.source),'source_sha256':source_hash,
              'input_manifest':str(args.manifest),'input_manifest_sha256':sha(args.manifest),
              'input_sha256':{str(p):expected[p] for p in inputs},'command':command}
    (output/'invocation.json').write_text(json.dumps(identity,indent=2)+'\n')
    with (output/'run.log').open('w') as log:
        try:
            result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=180,
                                  env={**os.environ,'OPENBLAS_NUM_THREADS':'4'})
        except subprocess.TimeoutExpired:
            raise RuntimeError(f'{task["name"]}: GPU admission/restoration wrapper exceeded 180s; read {output / "run.log"}')
    if result.returncode:
        raise RuntimeError(f'{task["name"]}: wrapper exited {result.returncode}; read {output / "run.log"}')
    report=json.loads((output/'run.json').read_text())
    if not report['complete'] or report['source_sha256']!=source_hash or len(report['entries'])!=len(inputs):
        raise RuntimeError(f'{task["name"]}: incomplete or mismatched run.json')
    for record in report['entries']:
        if record['input_sha256']!=expected[Path(record['input'])] or sha(Path(record['image']))!=record['image_sha256']:
            raise RuntimeError(f'{task["name"]}: input or output hash mismatch')
    print(json.dumps({'task':task['name'],'status':'complete','entries':len(inputs),
                      'solve_seconds':sum(c['solve_seconds'] for c in report['chunks']),
                      'total_seconds':report['total_seconds']}),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--task',type=int,required=True)
    p.add_argument('--manifest',type=Path,default=DEFAULT_MANIFEST)
    p.add_argument('--out',type=Path,default=DEFAULT_OUT)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--rate',type=float,default=.55)
    main(p.parse_args())
