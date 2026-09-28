"""Compare retained train-only preparations against independent paid-image parse."""
from pathlib import Path
import numpy as np
import fit
import replay

here=Path(__file__).resolve().parent
image=(here/'bitmask-root-standalone.bin').read_bytes()
W=replay.decode(image)
source,teacher,X,Xh,target,scale=fit.sources()
prepared=[]
for first in range(0,128,8):
    with np.load(here/f'emit/round1-{first}-{first+8}.npz') as data:
        high,low,extra,gain=[data[k].copy() for k in ('high','low','root','gain')]
    prepared.append((fit.main_vectors(high,low)+fit.ROOT[extra]).reshape(8,4,256)*gain.astype(np.float64)[:,:,None])
T=np.concatenate(prepared).reshape(128,1024)*scale
su=1-2*np.unpackbits(np.frombuffer(image[49152:49280],dtype='u1'),bitorder='little').astype(np.int16)
sv=1-2*np.unpackbits(np.frombuffer(image[49280:49296],dtype='u1'),bitorder='little').astype(np.int16)
Wprepared=fit.root.had(fit.root.had(T).T).T*sv[:,None]*su[None,:]
diff=np.max(np.abs(W-Wprepared))
assert diff<1e-13,diff
assert np.array_equal(image[49152:49298],source[49152:49298])
print('max_image_vs_fit_weight',diff,'frozen_signs_scale_bytes',146,'rounds',2,'chunks',16)
