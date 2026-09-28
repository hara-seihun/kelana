"""Compare all 65,536 decoded values against pinned upstream pure functions."""
import argparse
import ast
from pathlib import Path
import numpy as np
import torch

HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('upstream',type=Path);a=p.parse_args()
source=a.upstream/'lib/codebook/bitshift.py'
tree=ast.parse(source.read_text())
functions=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in ('decode_3inst','quantlut_sym')]
assert len(functions)==2
ctx={'torch':torch,'np':np}
exec(compile(ast.Module(body=functions,type_ignores=[]),str(source),'exec'),ctx)
three=np.fromfile(HERE/'lut-f32.bin',dtype='<f4')
assert np.array_equal(three,ctx['decode_3inst'](torch.arange(65536)).numpy())
tlut=np.fromfile(HERE/'hyb-tlut-f32.bin',dtype='<f4').reshape(512,2)
hybrid=np.fromfile(HERE/'hyb-lut-f32.bin',dtype='<f4').reshape(65536,2)
assert np.array_equal(hybrid,ctx['quantlut_sym'](torch.tensor(tlut.copy()),16,9).numpy())
print('Pinned QTIP 3INST and HYB exhaustive decoded LUTs: zero mismatches')
