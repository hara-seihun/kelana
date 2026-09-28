#!/usr/bin/env python3
"""Corpus token frequencies for tied input embeddings, split before selection."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from transformers import AutoTokenizer

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit')
MODEL=DATA/'models/qwen3-0.6b'
CORPUS=DATA/'corpus/wikitext-2-raw'
VOCAB=151936


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def main(output):
    output.mkdir(parents=True,exist_ok=True)
    tokenizer=AutoTokenizer.from_pretrained(MODEL,local_files_only=True)
    tokenizer.model_max_length=10**12
    arrays={};source={}
    for split in ('train','validation'):
        path=CORPUS/f'{split}.txt'
        tokens=np.asarray(tokenizer(path.read_text(),add_special_tokens=False)['input_ids'],np.int32)
        arrays[split]=np.bincount(tokens,minlength=VOCAB).astype('<i8')
        source[split]={'text_sha256':sha(path),'token_count':int(len(tokens)),
                       'unique_token_ids':int(np.count_nonzero(arrays[split])),
                       'max_token_id':int(tokens.max())}
    np.savez_compressed(output/'frequency.npz',**arrays)
    manifest={'format':'qwen3-tied-frequency/1',
              'model_revision':json.loads((MODEL/'source.json').read_text())['revision'],
              'tokenizer_sha256':sha(MODEL/'tokenizer.json'),
              'source_sha256':sha(Path(__file__)),
              'source':source,
              'arrays':{k:{'sha256':hashlib.sha256(v.tobytes()).hexdigest(),
                           'shape':list(v.shape)} for k,v in arrays.items()},
              'frequency_sha256':sha(output/'frequency.npz')}
    (output/'frequency.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(source))


if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('frequency.py OUTPUT_DIR')
    main(Path(sys.argv[1]))
