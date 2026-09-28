#!/usr/bin/env python3
"""Check learned image custody and write the small checked held-out comparison."""
import hashlib
import json
from pathlib import Path

import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=Path('/path/to/workspace/data/kelana-subbit')
DATA=ROOT/'model-tuning'
SEED=ROOT/'full-model/image-binary055-refined'
MODEL=ROOT/'models/qwen3-0.6b'
WRAPPER=Path('/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare')
PYTHON=Path('/path/to/workspace/data/fish-s2-pro/venv/bin/python')


def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for part in iter(lambda:f.read(1<<20),b''):h.update(part)
    return h.hexdigest()


def run():
    t=json.loads((DATA/'teacher.json').read_text())
    assert t['image_sha256']==sha(DATA/'teacher.npz')
    assert t['source_sha256']==sha(HERE/'fit.py')
    assert t['model_weights_sha256']==sha(MODEL/'model.safetensors')
    checkpoints=[]
    for step,begin,count in ((1,0,1),(3,1,2),(8,3,5)):
        c=json.loads((DATA/f'checkpoint{step:02}.json').read_text())
        if (c['image_sha256']!=sha(DATA/f'checkpoint{step:02}.npz') or
            c['seed_manifest_sha256']!=sha(SEED/'manifest.json') or
            c['source_sha256']!=sha(HERE/'fit.py') or
            c['teacher_sha256']!=t['image_sha256'] or
            c['start']!=begin or c['count']!=count):
            raise ValueError('training checkpoint provenance mismatch')
        checkpoints.append(c['image_sha256'])
    r=json.loads((DATA/'image-gain08.json').read_text())
    candidate=DATA/'image-gain08'
    if (r['image_manifest_sha256']!=sha(candidate/'manifest.json') or
        r['source_sha256']!=sha(HERE/'publish.py') or
        r['checkpoint_sha256']!=checkpoints[-1]):raise ValueError('candidate image receipt mismatch')
    before=json.loads((SEED/'manifest.json').read_text())
    after=json.loads((candidate/'manifest.json').read_text())
    if after['payload_bytes']!=before['payload_bytes'] or after['payload_bpw']!=before['payload_bpw']:
        raise ValueError('zero-byte rate invariant violated')
    for key in ('head.json','tied.npz','norms.npz','config.json'):
        if sha(candidate/key)!=sha(SEED/key):raise ValueError(f'nonfactor parameter changed: {key}')
    source_scales=0;changed_scales=0
    with np.load(DATA/'checkpoint08.npz') as gains:
        for i,(old,new) in enumerate(zip(before['body'],after['body'])):
            if old['key']!=new['key'] or old['payload_bytes']!=new['payload_bytes'] or sha(candidate/new['path'])!=new['sha256']:
                raise ValueError('changed body key, rate or image hash')
            with np.load(SEED/old['path']) as original,np.load(candidate/new['path']) as calibrated:
                if set(original.files)!=set(calibrated.files) or set(original.files)!={'U','V','scale_pre','scale_post','dimensions'}:
                    raise ValueError('unexpected binary image arrays')
                for name in ('U','V','scale_pre','dimensions'):
                    if not np.array_equal(original[name],calibrated[name]):raise ValueError('frozen code or input scale changed')
                expected=(original['scale_post'].astype(np.float32)*gains[f'g{i}']).astype(np.float16)
                if not np.array_equal(expected,calibrated['scale_post']):raise ValueError('merged output scale differs')
                source_scales+=len(expected)
                changed_scales+=int(np.count_nonzero(original['scale_post']!=calibrated['scale_post']))
    if source_scales!=344064:raise ValueError('unexpected output scale count')
    quality=json.loads((DATA/'quality-gain08.json').read_text())
    control=json.loads((ROOT/'full-model/binary055-refined-quality.json').read_text())
    if quality['manifest_sha256']!=sha(candidate/'manifest.json') or quality['head_receipt_sha256']!=sha(candidate/'head.json'):
        raise ValueError('quality evaluated a different image')
    if quality['tokens_sha256']!=control['tokens_sha256'] or quality['model_source_sha256']!=control['model_source_sha256']:
        raise ValueError('different pilot or source')
    evaluated={r['arm']:r for r in quality['arms']}
    prior={r['arm']:r for r in control['arms']}
    result={'format':'qwen-full-model-existing-scale-calibration/1',
            'source_sha256':{p.name:sha(p) for p in (HERE/'fit.py',HERE/'publish.py',HERE/'record.py')},
            'runner_python_sha256':sha(PYTHON.resolve()),'gpu_wrapper_sha256':sha(WRAPPER),
            'teacher_image_sha256':t['image_sha256'],'seed_manifest_sha256':sha(SEED/'manifest.json'),
            'learned_checkpoints_sha256':checkpoints,'candidate_manifest_sha256':sha(candidate/'manifest.json'),
            'full_evaluator_source_sha256':quality['source_hashes'],
            'candidate_payload_bytes':after['payload_bytes'],'unique_parameters':after['unique_parameters'],
            'candidate_bpw':after['payload_bpw'],'input_scale_and_factor_signs_unchanged':True,
            'fp16_output_scale_elements':source_scales,'changed_fp16_output_scale_elements':changed_scales,
            'held':{arm:{split:{'seed_nll':prior[arm]['splits'][split]['nll'],
                                 'calibrated_nll':evaluated[arm]['splits'][split]['nll'],
                                 'seed_teacher_kl':prior[arm]['splits'][split]['teacher_kl'],
                                 'calibrated_teacher_kl':evaluated[arm]['splits'][split]['teacher_kl']}
                         for split in ('validation','test')} for arm in ('body','complete')},
            'original':{split:evaluated['reference']['splits'][split]['nll'] for split in ('validation','test')},
            'training':'Eight distinct WikiText raw train windows; original BF16 teacher final-hidden reconstruction; one Adam update/window in three foreground jobs. Adam moments reset at job boundaries. No held data used in fitting.',
            'held_contract':'Four separate validation and four test windows, 1020 predictions each at context 256. Expanded BF16 quality reforward; mixed tied head and embedding in complete arm. No compressed runtime timing.'}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'result_sha256':sha(HERE/'results.json'),
        'complete_test_nll':result['held']['complete']['test']['calibrated_nll'],
        'payload_bpw':result['candidate_bpw']}))

if __name__=='__main__':run()
