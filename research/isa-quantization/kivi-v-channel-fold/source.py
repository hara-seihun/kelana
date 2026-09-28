"""Source owner for folded BF16 image; original K/Q/teacher remain immutable."""
from pathlib import Path
import importlib.util
import hashlib
import json
import numpy as np
import torch
from source_image import read_source_images

HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'kivi-causal-cache'
spec=importlib.util.spec_from_file_location('kivi_original_source',BASE/'source.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
FIX=original.FIX;FIX_SHA=original.FIX_SHA


def arrays(panel,window):
    src=original.arrays(panel,window)
    v,o=read_source_images()
    with np.load(FIX) as data:
        x=torch.from_numpy(data['train' if panel=='train' else 'validation'][window*256:(window+1)*256].astype(np.float32).copy())
    with torch.no_grad():
        vraw=(x@v.T).to(torch.bfloat16).float()
    src['value']=vraw.to(torch.bfloat16).view(torch.uint16).numpy().copy()
    src['vraw']=vraw
    src['o']=o
    return src
