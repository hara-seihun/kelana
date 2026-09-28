"""Prepare real held states and independently decoded stored-image targets; never prepare weights."""
import hashlib
from pathlib import Path
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'quip-e8p-local'
sys.path.insert(0,str(SOURCE))
import replay

assert hashlib.sha256(replay.FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
for filename,expected in {
    'quip-rvq3-r0.bin':'89e2e0b5b07fb749db77a7d94efbbdb9c34b83d7d111633401fdc92d315bc597',
    'refit-mixed-q2q3-6176.bin':'ce94af65a0e7666e64778e23e05dd1325353d474cf7c8a239988ca1f4723bc63',
    'e8p-abs-grid.bin':'efc2c03c60acd955dc812ff2bade9ec6cc31259807e48473506161f3a9a230ce',
    'e81b-grid.bin':'d65cecfd0258df8b7aaabfe7ce66ac5b0ec9385274c60b83f3fe3714321337eb',
}.items():
    assert hashlib.sha256((SOURCE/filename).read_bytes()).hexdigest()==expected,filename
with np.load(replay.FIX) as f:
    x=f['validation'][:8,:128].astype(np.float32)
    teacher=f['weight'][:128,:128].astype(np.float64)
q,_=replay.decode_rvq3()
s,_=replay.scalar_image(6176,2,3,97)
for name,arr in [('inputs.f32',x),('quip-target.f32',x.astype(float)@q.T),('scalar-target.f32',x.astype(float)@s.T),('teacher-target.f32',x.astype(float)@teacher.T)]:
    (HERE/name).write_bytes(np.asarray(arr,dtype='<f4').tobytes())
print('8 distinct actual validation states, stored-image targets and teacher target; no decoded weight exported')
