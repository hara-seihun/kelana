#!/usr/bin/env python3
"""Compact committed index of pinned head evidence and paid rates."""
import hashlib
import json
from pathlib import Path

import numpy as np

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/tied-head')
ROWS=151936
COLS=1024
UNIQUE=596049920


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def load(name, expected_image=None):
    path=DATA/name
    record=json.loads(path.read_text())
    if expected_image is not None and sha(DATA/expected_image)!=record['image_sha256']:
        raise ValueError(f'{name} does not name its retained image')
    return record


def main():
    capture=load('capture.json')
    if sha(DATA/'final-head.npz')!=capture['capture_sha256']:raise ValueError('capture changed')
    frequency=load('frequency.json')
    if sha(DATA/'frequency.npz')!=frequency['frequency_sha256']:raise ValueError('frequencies changed')
    sources={'capture_source_sha256':'capture.py','codec_source_sha256':'codec.py',
             'fit_source_sha256':'fit.py','evaluate_source_sha256':'evaluate.py'}
    for receipt_path in DATA.glob('*.json'):
        receipt=json.loads(receipt_path.read_text())
        for field,file in sources.items():
            if field in receipt and receipt[field]!=sha(HERE/file):
                raise ValueError(f'{receipt_path.name}: stale {file} identity')
        if 'source_sha256' in receipt:
            name=receipt_path.name
            if name=='frequency.json':file='frequency.py'
            elif name.startswith('calibration'):file='calibrate.py'
            elif name.startswith('tune'):file='tune.py'
            elif name.startswith(('mixed','loss')):file='allocate.py'
            elif name.startswith('rtn'):file='scalar.py'
            elif name.startswith('evaluate'):file='evaluate.py'
            else:file=None
            if file is not None and receipt['source_sha256']!=sha(HERE/file):
                raise ValueError(f'{name}: stale {file} identity')
    fitted={str(k):load(f'codebook{k}.json',f'codebook{k}.npz') for k in (64,256)}
    scalar={str(k):load(f'rtn{k}.json',f'rtn{k}.npz') for k in (2,4)}
    evaluated={str(k):load(f'evaluate{k}.json') for k in (64,256)}
    for k in (64,256):
        if evaluated[str(k)]['image_sha256']!=fitted[str(k)]['image_sha256']:
            raise ValueError('evaluation used another image')
        if evaluated[str(k)]['capture_sha256']!=capture['capture_sha256']:
            raise ValueError('evaluation used another head capture')
        if sha(DATA/f'common{k}.npz')!=evaluated[str(k)]['common_image_sha256']:
            raise ValueError('exact common-row image changed')
        for kind,digest in evaluated[str(k)]['objective_selected_common_image_sha256'].items():
            if sha(DATA/f'{kind}{k}.npz')!=digest:
                raise ValueError(f'{kind} exact-row image changed')
        for plan in evaluated[str(k)]['plans'].values():
            tuned=plan['train_fitted_rare_head']
            if tuned is None:continue
            matching=[p for p in DATA.glob(f'tune{k}-*.json') if sha(p)==tuned['tune_receipt_sha256']]
            if len(matching)!=1:raise ValueError('train-only rare-head correction receipt missing')
    with np.load(DATA/'final-head.npz') as z:
        for key,details in capture['arrays'].items():
            if hashlib.sha256(z[key].tobytes()).hexdigest()!=details['sha256']:
                raise ValueError(f'capture array {key} changed')
    with np.load(DATA/'frequency.npz') as z:
        train=z['train'];validation=z['validation']
        for key,details in frequency['arrays'].items():
            if hashlib.sha256(z[key].tobytes()).hexdigest()!=details['sha256']:
                raise ValueError(f'frequency array {key} changed')
        order=np.lexsort((np.arange(ROWS),-train))
        cumulative=np.cumsum(train[order])
        coverage=[]
        for fraction in (.8,.9,.95):
            n=int(np.searchsorted(cumulative,train.sum()*fraction)+1)
            coverage.append({'train_target':fraction,'exact_rows':n,
                'validation_token_fraction':float(validation[order[:n]].sum()/validation.sum()),
                'paid_bits_per_weight_if_k64_codebook_plus_exact':fitted['64']['total_bits_per_tied_weight']+
                    8*n*(4+2*COLS)/(ROWS*COLS)})
    results={'format':'qwen3-tied-head-study/1','model_revision':capture['model_revision'],
        'model_safetensors_sha256':capture['model_safetensors_sha256'],
        'head_rows':ROWS,'head_width':COLS,'tied_parameter_count':ROWS*COLS,
        'all_unique_parameters':UNIQUE,'head_fraction_of_unique':ROWS*COLS/UNIQUE,
        'head_only_compressed_rest_bf16_all_unique_rate':
            (ROWS*COLS*evaluated['256']['plans']['2560']['bits_per_tied_weight']+
             (UNIQUE-ROWS*COLS)*16)/UNIQUE,
        'capture':{'path':str(DATA/'final-head.npz'),'sha256':capture['capture_sha256'],
                   'source_sha256':capture['capture_source_sha256'],
                   'python_executable_sha256':capture['python_executable_sha256'],
                   'gpu_wrapper_sha256':capture['gpu_wrapper_sha256'],
                   'train_hidden':capture['arrays']['train_hidden']['shape'],
                   'validation_hidden':capture['arrays']['validation_hidden']['shape'],
                   'held_logit_rows':capture['arrays']['selected_logits']['shape']},
        'frequencies':{'path':str(DATA/'frequency.npz'),'sha256':frequency['frequency_sha256'],
                       'source_sha256':frequency['source_sha256'],
                       'train_tokens':frequency['source']['train']['token_count'],
                       'validation_tokens':frequency['source']['validation']['token_count'],
                       'exact_frequency_thresholds':coverage},
        'reference':evaluated['256']['baseline'],
        'codebooks':{str(k):{'image_path':str(DATA/f'codebook{k}.npz'),
            'image_sha256':fitted[str(k)]['image_sha256'],
            'payload_bytes':fitted[str(k)]['total_payload_bytes'],
            'base_rate':fitted[str(k)]['total_bits_per_tied_weight'],
            'table_bytes_per_input':fitted[str(k)]['transient_table_bytes_per_query'],
            'float_products_per_input_table':fitted[str(k)]['online_float_products_per_query_table'],
            'row_lookups_per_input':fitted[str(k)]['row_lookups_per_query'],
            'plans':evaluated[str(k)]['plans']} for k in (64,256)},
        'scalar_controls':{str(k):{'image_path':str(DATA/f'rtn{k}.npz'),
            'image_sha256':scalar[str(k)]['image_sha256'],
            'rate':scalar[str(k)]['bits_per_tied_weight'],
            'head':scalar[str(k)]['head'],
            'embedding_relative_rms':scalar[str(k)]['validation_frequency_weighted_embedding_relative_rms']}
            for k in (2,4)},
        'data_receipts':{p.name:sha(p) for p in sorted(DATA.glob('*.json'))},
        'source_sha256':{p.name:sha(p) for p in sorted(HERE.glob('*.py'))},
        'scope':'fixed original-model final inputs and held validation logits; source tied embedding quantized only in geometry, not propagated through the transformer; no whole-model quality or GPU timing'}
    (HERE/'results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps({'result_sha256':sha(HERE/'results.json'),
        'tied_head_rate':results['codebooks']['256']['plans']['2560']['bits_per_tied_weight'],
        'all_unique_if_only_head_changed':results['head_only_compressed_rest_bf16_all_unique_rate'],
        'data_receipts':len(results['data_receipts'])}))


if __name__=='__main__':main()
