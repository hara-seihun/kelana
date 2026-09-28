"""Standalone paid-image decoder; no centroid preparation import."""
from pathlib import Path
import hashlib
import numpy as np

HERE=Path(__file__).resolve().parent
IMAGE=HERE/'shared-key-center-f16.bin'
SHA='7f991ba8b77dc6199ad8ffb3ca5c9d13c14a2997efed7ac7277de9c21f3f99ca'

def decode():
    blob=IMAGE.read_bytes()
    assert len(blob)==256 and hashlib.sha256(blob).hexdigest()==SHA
    c=np.frombuffer(blob,dtype='<f2').astype(np.float32)
    assert c.shape==(128,) and np.isfinite(c).all()
    return c
