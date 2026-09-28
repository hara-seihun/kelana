"""Replay one predeclared affine image alongside the canonical four frozen arms."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys

HERE=Path(__file__).resolve().parent
CANON=HERE.parent/'quip-complete-head-observer'
IMAGE=HERE/'normalized-affine-q2q3-50320.bin'
SHA='18fbba120a75f1788d674099ee82166e3509908c213021196df011ecea66b370'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod)
    return mod

def main(panel,window):
    assert hashlib.sha256(IMAGE.read_bytes()).hexdigest()==SHA
    canon=load('fixed_causal_head_observer',CANON/'measure.py')
    replay=load('normalized_affine_independent_reader',HERE/'replay.py')
    previous=canon.load_images()
    candidate,_,_=replay.decode(IMAGE.read_bytes())
    canon.ASSETS['normalized-affine-refit/normalized-affine-q2q3-50320.bin']=SHA
    canon.load_images=lambda:dict(previous,normalized_affine=candidate.astype('float32'))
    canon.HERE=HERE
    canon.measure(panel,window)

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
