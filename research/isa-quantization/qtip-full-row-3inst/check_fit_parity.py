"""One bounded full-tile CPU Viterbi parity case against pinned upstream function bodies."""
import argparse
import ast
import math
import os
from pathlib import Path
import subprocess
import tempfile
import numpy as np
import torch
from torch import nn

HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('upstream',type=Path);p.add_argument('arm',choices=['3inst','hyb']);p.add_argument('binary',type=Path);a=p.parse_args()
torch.set_num_threads(1)
source=a.upstream/'lib/codebook/bitshift.py'
tree=ast.parse(source.read_text())
names={'decode_3inst','quantlut_sym','bitshift_codebook'}
nodes=[node for node in tree.body if isinstance(node,(ast.FunctionDef,ast.ClassDef)) and node.name in names]
assert len(nodes)==3
cls=next(node for node in nodes if isinstance(node,ast.ClassDef))
for method in cls.body:
    if isinstance(method,ast.FunctionDef) and method.name=='update':
        # Disable compilation only, leaving upstream transition body unchanged.
        method.decorator_list=[]
ctx={'torch':torch,'nn':nn,'np':np,'math':math,'os':os}
exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),str(source),'exec'),ctx)
tlut=np.frombuffer((HERE/'qtip-hyb-full-row.bin').read_bytes(),dtype='<f4',count=1024,offset=49298).copy().reshape(512,2)
cb=ctx['bitshift_codebook'](L=16,K=3,V=2,tlut_bits=9,decode_mode='quantlut_sym',tlut=torch.tensor(tlut)) if a.arm=='hyb' else ctx['bitshift_codebook'](L=16,K=3,V=1,tlut_bits=0,decode_mode='3inst')
rng=np.random.default_rng(1191)
target=rng.standard_normal(256).astype('<f4')
with torch.no_grad():
    expected=cb.quantize(torch.tensor(target).reshape(1,256))[1].numpy().reshape(-1)
with tempfile.TemporaryDirectory() as directory:
    tmp=Path(directory)
    (tmp/'parity-input.bin').write_bytes(target.tobytes())
    if a.arm=='hyb':(tmp/'hyb-tlut-f32.bin').write_bytes(tlut.astype('<f4').tobytes())
    subprocess.run([str(a.binary.resolve()),'fit-one',directory],check=True)
    actual=np.fromfile(tmp/'parity-states.bin',dtype='<u2')
assert len(actual)==len(expected)
different=np.flatnonzero(actual!=expected)
print(a.arm,'full 16x16-tile upstream-vs-CPU Viterbi state mismatches',len(different),'of',len(actual),'first',different[:8].tolist())
assert len(different)==0
