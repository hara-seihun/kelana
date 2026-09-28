"""Finite packed-coordinate identities and real-state integer-boundary control (CPU only)."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'quip-e8p-local'
sys.path.insert(0,str(SOURCE))
import replay

EXPECTED={
    'quip-rvq3-r0.bin':'89e2e0b5b07fb749db77a7d94efbbdb9c34b83d7d111633401fdc92d315bc597',
    'e8p-abs-grid.bin':'efc2c03c60acd955dc812ff2bade9ec6cc31259807e48473506161f3a9a230ce',
    'e81b-grid.bin':'d65cecfd0258df8b7aaabfe7ce66ac5b0ec9385274c60b83f3fe3714321337eb',
}
for name,digest in EXPECTED.items():
    assert hashlib.sha256((SOURCE/name).read_bytes()).hexdigest()==digest,name
assert hashlib.sha256(replay.FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
image=(SOURCE/'quip-rvq3-r0.bin').read_bytes()
code=np.frombuffer(image,dtype='<u2',count=2048).reshape(128,16)
indices=np.frombuffer(image,dtype='u1',count=2048,offset=4096).reshape(128,16)
su=1-2*np.unpackbits(np.frombuffer(image[6144:6160],dtype='u1'),bitorder='little').astype(np.int16)
sv=1-2*np.unpackbits(np.frombuffer(image[6160:6176],dtype='u1'),bitorder='little').astype(np.int16)
scale=float(np.frombuffer(image[6176:6178],dtype='<f2')[0])
absolute=np.frombuffer((SOURCE/'e8p-abs-grid.bin').read_bytes(),dtype='<u4')
residual=np.frombuffer((SOURCE/'e81b-grid.bin').read_bytes(),dtype='<f2').astype(np.float64).reshape(256,8)
assert np.all(residual*2==np.rint(residual*2)) and np.max(np.abs(residual))==2
G=(residual*2).astype('i1')
(HERE/'e81b-twice-i8.bin').write_bytes(G.tobytes())
assert len(G.tobytes())==2048
parity=(np.unpackbits((code&255).astype('u1')[...,None],axis=-1,bitorder='little').sum(axis=-1)%2).astype(np.int16)
sign=((code&255)^parity).astype(np.uint32)
perm=np.array([0,4,1,5,2,6,3,7],dtype=np.uint32)
nibble=np.stack([(absolute[code>>8]>>(4*i))&15 for i in perm],axis=-1).astype(np.int16)
sgn=1-2*((sign[...,None]>>perm)&1).astype(np.int16)
B=(2*(nibble-8)*sgn+(1-2*parity[...,None])).astype(np.int8)
assert B.min()>=-17 and B.max()<=17
R=G[indices]

with np.load(replay.FIX) as f:
    x=f['validation'][:,:128].astype(np.float64)
    teacher=f['weight'][:128,:128].astype(np.float64)
z=replay.hadamard(x*su).reshape(-1,16,8)
# The two integer dot coordinates are multiplied by live FP64 transformed states.
base=np.einsum('rcj,ncj->nr',B.astype(np.float64),z,optimize=True)
res=np.einsum('rcj,ncj->nr',R.astype(np.float64),z,optimize=True)
packed_output=replay.hadamard((base/4+res*(25/102))*scale)*sv
w,_=replay.decode_rvq3()
ideal=x@w.T
assert np.max(np.abs(packed_output-ideal))<1e-14
# One shared dynamic symmetric byte scale per 8-input group, incurred after the input transform.
alpha=np.max(np.abs(z),axis=-1,keepdims=True)/127
byte=np.rint(z/alpha).clip(-127,127).astype(np.int8)
base_i=np.einsum('rcj,ncj->nrc',B.astype(np.int32),byte.astype(np.int32),optimize=True)
res_i=np.einsum('rcj,ncj->nrc',R.astype(np.int32),byte.astype(np.int32),optimize=True)
approx_rows=np.sum((base_i/4+res_i*(25/102))*alpha[:,:,0][:,None,:],axis=-1)*scale
approx=replay.hadamard(approx_rows)*sv
energy=np.sum((x@teacher.T)**2)
err=lambda y:float(np.sum((y-x@teacher.T)**2)/energy)
receipt={
 'images_sha256':EXPECTED,
 'packed_i8_grid_sha256':hashlib.sha256(G.tobytes()).hexdigest(),
 'n_distinct_absolute_codes':int(np.unique(code>>8).size),
 'n_distinct_residual_codes':int(np.unique(indices).size),
 'n_distinct_abs_residual_pairs':len(set(zip((code>>8).flat,indices.flat))),
 'distinct_full_codes_per_column_block': [int(np.unique(code[:,i]).size) for i in range(16)],
 'distinct_sign_codes_per_column_block': [int(np.unique(code[:,i]&255).size) for i in range(16)],
 'distinct_absolute_codes_per_column_block': [int(np.unique(code[:,i]>>8).size) for i in range(16)],
 'codebook_integer_ranges':{'base_quarter': [int(B.min()),int(B.max())], 'residual_twice': [int(G.min()),int(G.max())]},
 'held_state_count':len(x),
 'finite_held_exact_identity_max_abs':float(np.max(np.abs(packed_output-ideal))),
 'held_relative_squared_response_error':{'ideal_quip':err(ideal),'byte_input_quip':err(approx)},
 'byte_input_max_abs_from_ideal':float(np.max(np.abs(approx-ideal))),
 'byte_input_max_abs_over_int8':int(np.max(np.abs(byte))),
 'byte_input_fp32_group_scale_count_per_state':16,
 'integer_dot4_per_state':128*16*4,
}
(HERE/'results.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
