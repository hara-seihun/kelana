"""One paid balanced-gamma + FP16-centered reader, fixed rank/table/source."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import numpy as np
import torch

HERE=Path(__file__).resolve().parent
PRIMARY=HERE.parent/'qwen-positive-kernel/measure.py'
PRIMARY_SHA='a9e5ee5de5666759964bc93a619a1c78038eff072f18c81c0f55636c3b953c86'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m)
    return m

class PaidGammaCheckpoint:
    def __init__(self,constructor,args,kwargs,gamma):
        self.context=constructor(*args,**kwargs)
        self.gamma=gamma
    def __enter__(self):
        self.checkpoint=self.context.__enter__()
        return self
    def __exit__(self,*arguments):
        return self.context.__exit__(*arguments)
    def get_tensor(self,name):
        if name=='model.layers.0.self_attn.q_norm.weight':
            return torch.from_numpy(self.gamma[0].copy()).to(torch.bfloat16)
        if name=='model.layers.0.self_attn.k_norm.weight':
            return torch.from_numpy(self.gamma[1].copy()).to(torch.bfloat16)
        return self.checkpoint.get_tensor(name)

def main(panel,window):
    assert hashlib.sha256(PRIMARY.read_bytes()).hexdigest()==PRIMARY_SHA
    center_reader=load('balanced_center_image_reader',HERE/'center_reader.py')
    gamma_reader=load('balanced_gamma_image_reader',HERE.parent/'qwen-balanced-gamma/reader.py')
    center=center_reader.decode()
    gamma,_,_=gamma_reader.decode()
    primary=load('frozen_unbalanced_positive_reader',PRIMARY)
    original_safe_open=primary.safe_open
    original_features=primary.log_features
    calls=[]
    primary.safe_open=lambda *a,**kw:PaidGammaCheckpoint(original_safe_open,a,kw,gamma)
    def feature(rot,omega):
        calls.append(rot.shape)
        if len(calls)==1:
            z=rot*128**-.25-center[None,:]
            return (z@omega.T-.5*np.sum(z*z,axis=-1,keepdims=True)).astype(np.float32)
        return original_features(rot,omega)
    primary.log_features=feature
    primary.HERE=HERE
    primary.main(panel,window)
    assert calls==[(256,128)]*3,'feature call sequence changed'
    path=HERE/f'{panel}-{window}.json'
    receipt=json.loads(path.read_text())
    receipt.update({'balanced_gamma_image_sha256':gamma_reader.SHA,
        'balanced_center_image_sha256':center_reader.SHA,
        'fixed_primary_reader_sha256':PRIMARY_SHA})
    path.write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
