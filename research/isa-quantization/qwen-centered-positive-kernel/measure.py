"""One fixed paid FP16 key gauge with unchanged rank64 table and consumer."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
PRIMARY=HERE.parent/'qwen-positive-kernel/measure.py'
PRIMARY_SHA='a9e5ee5de5666759964bc93a619a1c78038eff072f18c81c0f55636c3b953c86'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module)
    return module

def main(panel,window):
    assert hashlib.sha256(PRIMARY.read_bytes()).hexdigest()==PRIMARY_SHA
    reader=load('paid_center_reader',HERE/'center_reader.py')
    center=reader.decode()
    primary=load('frozen_positive_kernel',PRIMARY)
    original=primary.log_features
    calls=[]
    def one_key_change(rot,omega):
        calls.append(rot.shape)
        if len(calls)==1:
            a=rot*128**-.25-center[None,:]
            return (a@omega.T-.5*np.sum(a*a,axis=-1,keepdims=True)).astype(np.float32)
        return original(rot,omega)
    primary.log_features=one_key_change
    primary.HERE=HERE
    primary.main(panel,window)
    assert calls==[(256,128)]*3,'unexpected key/query feature call order'
    path=HERE/f'{panel}-{window}.json'
    receipt=json.loads(path.read_text())
    receipt['shared_key_center_image_sha256']=reader.SHA
    receipt['source_reader_sha256']=PRIMARY_SHA
    receipt['key_feature_coordinate']='original rotated normalized key /128^(1/4), minus the independently decoded shared FP16 train-causal-pair center'
    path.write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
