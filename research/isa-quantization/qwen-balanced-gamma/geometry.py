"""Same pinned source geometry reader, substituting paid Q/K gamma fields only."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import torch

HERE=Path(__file__).resolve().parent
ORIGINAL=HERE.parent/'qwen-kernel-gauge-screen/screen.py'
SOURCE_SHA='4b154983865bda4d86214d9f675d5d559a3a5305ef5b390781d6faba4d479c27'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m)
    return m

def main(kind,index=None):
    assert hashlib.sha256(ORIGINAL.read_bytes()).hexdigest()==SOURCE_SHA
    geometry=load('pinned_gqa_source_geometry',ORIGINAL)
    reader=load('exact_gamma_image_reader',HERE/'reader.py')
    gamma,_,_=reader.decode()
    original=geometry.source
    def balanced_source():
        q,k,_,_,consumer=original()
        return q,k,torch.from_numpy(gamma[0]),torch.from_numpy(gamma[1]),consumer
    geometry.source=balanced_source
    geometry.HERE=HERE
    geometry.CENTER=HERE/'train-balanced-center-f64.npy'
    if kind=='center':
        geometry.center()
        path=HERE/'center.json'
        record=json.loads(path.read_text())
        record['gamma_image_sha256']=reader.SHA
        record['source_geometry_reader_sha256']=SOURCE_SHA
        path.write_text(json.dumps(record,indent=2)+'\n')
    else:
        assert kind in ('train','held') and index is not None
        record=json.loads((HERE/'center.json').read_text())
        assert record['gamma_image_sha256']==reader.SHA
        geometry.inspect(kind,index)
        path=HERE/f'{kind}-{index}.json'
        data=json.loads(path.read_text())
        data['gamma_image_sha256']=reader.SHA
        path.write_text(json.dumps(data,indent=2)+'\n')

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]) if len(sys.argv)>2 else None)
