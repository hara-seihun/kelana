"""Use the owning full-covariance matched-rate control machinery for 6688 B."""
import importlib.util
import sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=Path(sys.argv[1]) if len(sys.argv)>1 else HERE.parent/'matched-rate-frontier/fit.py'
spec=importlib.util.spec_from_file_location('matched_rate_fit',SOURCE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
with np.load(mod.FIX) as f:
    x=f['train'][:,:128].astype(float);w=f['weight'][:128,:128].astype(float)
rows3=mod.response_refit(mod.quantize_rows(w,x,3),w,x)
rows4=mod.response_refit(mod.quantize_rows(w,x,4),w,x)
order=np.argsort(-np.array([r3[0]-r4[0] for r3,r4 in zip(rows3,rows4)]))
image=mod.control_image(rows3,rows4,order[:1])
assert len(image)==6688
(HERE/'refit-mixed-q3q4-6688.bin').write_bytes(image)
print('control 6688 B, Q4 upgraded row',int(order[0]))
rows2=mod.response_refit(mod.quantize_rows(w,x,2),w,x)
order23=np.argsort(-np.array([r2[0]-r3[0] for r2,r3 in zip(rows2,rows3)]))
selected=set(order23[:97]);mask=bytearray(16)
for row in selected:mask[row//8]|=1<<(row%8)
image=bytearray(mask)
for row in range(128):
    _,codes,step,origin=(rows3 if row in selected else rows2)[row]
    image.extend(mod.pack(codes,3 if row in selected else 2))
    image.extend(np.array([step,origin],dtype='<f2').tobytes())
assert len(image)==6176
(HERE/'refit-mixed-q2q3-6176.bin').write_bytes(image)
print('control 6176 B, Q3 upgraded rows',len(selected))
