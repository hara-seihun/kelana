"""Pinned-seed execution of upstream bitshift.py quantlut_sym default Q=9,V=2 table fitting."""
from pathlib import Path
import numpy as np
import scipy.cluster.vq
import torch
HERE=Path(__file__).resolve().parent
seed=20260924
torch.manual_seed(seed)
init=torch.randn(512,2)
data=torch.randn(1<<20,2)
clusters=scipy.cluster.vq.kmeans(data,init)
tlut=torch.tensor(clusters[0])
tlut=(tlut/tlut.std(unbiased=False))*0.9682458365518543
(HERE/'hyb-tlut-f32.bin').write_bytes(tlut.numpy().astype('<f4').tobytes())
print('HYB upstream kmeans, seed',seed,'iterations',clusters[1],'rms',float((tlut**2).mean().sqrt()))
