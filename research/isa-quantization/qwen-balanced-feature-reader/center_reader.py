"""Independent 256-byte balanced key-center image decoder."""
from pathlib import Path
import hashlib
import numpy as np

HERE=Path(__file__).resolve().parent
IMAGE=HERE/'balanced-center-f16.bin'
SHA='3e9fa69a8942b762f0cd041e6a70bfa0c7833957f0d960a6032b0775058cd6a2'

def decode():
    image=IMAGE.read_bytes()
    assert len(image)==256 and hashlib.sha256(image).hexdigest()==SHA
    center=np.frombuffer(image,dtype='<f2').astype(np.float32)
    assert center.shape==(128,) and np.isfinite(center).all()
    return center
