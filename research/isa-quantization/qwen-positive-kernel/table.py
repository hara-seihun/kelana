"""Fixed generic (non-model-fitted) 64×128 FP16 Gaussian feature table."""
from pathlib import Path
import hashlib
import numpy as np

HERE=Path(__file__).resolve().parent
TABLE=HERE/'gaussian-features-64x128-f16.bin'
SEED=20260924

def main():
    omega=np.random.default_rng(SEED).standard_normal((64,128)).astype('<f2')
    assert omega.nbytes==16384
    TABLE.write_bytes(omega.tobytes())
    print(hashlib.sha256(TABLE.read_bytes()).hexdigest())

if __name__=='__main__':main()
