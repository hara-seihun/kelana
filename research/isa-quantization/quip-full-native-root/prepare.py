"""Independent CPU stored-image targets for eight distinct held states; no expanded weight persisted."""
import hashlib
import sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
ASSETS={
    'e8-root-program/quip-root-standalone.bin':'d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a',
    'quip-full-row-slab/quip-rvq3-standalone.bin':'7234c67cc269f945b2826ad8686207336208ed531023ede0be7925c1c041ad43',
    'quip-root-matched-scalar/refit-group-q2q3-50320.bin':'e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15',
}
for name,expected in ASSETS.items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected,name
assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
sys.path.insert(0,str(ROOT/'quip-full-row-slab'))
import replay as full_replay
old,ledger=full_replay.quip()
assert np.all(np.isfinite(old))
# This parser is independent of the scalar fitter, modes, selection and packing code.
data=(ROOT/'quip-root-matched-scalar/refit-group-q2q3-50320.bin').read_bytes()
modes=np.unpackbits(np.frombuffer(data[:128],dtype='u1'),bitorder='little').reshape(128,8)
assert int(modes.sum())==191
scalar=np.empty((128,1024),dtype=np.float64);cursor=128
for row in range(128):
    for group in range(8):
        bits=2 if modes[row,group] else 3
        payload=data[cursor:cursor+bits*16];cursor+=bits*16
        digits=np.array([(payload[(i*bits)//8]>>((i*bits)%8) | (payload[(i*bits)//8+1]<<(8-(i*bits)%8) if (i*bits)%8+bits>8 else 0))&((1<<bits)-1) for i in range(128)])
        step,origin=np.frombuffer(data[cursor:cursor+4],dtype='<f2').astype(float);cursor+=4
        scalar[row,group*128:(group+1)*128]=step*digits+origin
assert cursor==len(data)
with np.load(FIX) as f:
    x=f['validation'][:8].astype(np.float64)
    teacher=f['weight'][:128].astype(np.float64)
for name,value in [('input.f32',x),('old-target.f32',x@old.T),('root-target.f32',x@old.T),('scalar-target.f32',x@scalar.T),('teacher-target.f32',x@teacher.T)]:
    (HERE/name).write_bytes(np.asarray(value,dtype='<f4').tobytes())
print('Eight distinct held input states; complete 128-output full-row targets, none from expanded native weights')
