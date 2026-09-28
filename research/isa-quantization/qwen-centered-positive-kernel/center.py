"""Charge once the already fixed train-causal-pair key gauge in FP16."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'qwen-kernel-gauge-screen/train-causal-pair-center-f64.npy'
SOURCE_SHA='0f73d862603b687cc41ef4f37574cf7d87f13dd98bec4443386bed773fdb3023'
IMAGE=HERE/'shared-key-center-f16.bin'

def main(source=SOURCE):
    assert hashlib.sha256(source.read_bytes()).hexdigest()==SOURCE_SHA
    c=np.load(source)
    assert c.dtype==np.float64 and c.shape==(128,)
    rounded=c.astype('<f2')
    assert np.isfinite(rounded).all() and rounded.nbytes==256
    IMAGE.write_bytes(rounded.tobytes())
    record={'train_center_sha256':SOURCE_SHA,
            'center_image_sha256':hashlib.sha256(IMAGE.read_bytes()).hexdigest(),
            'center_bytes':256,
            'max_abs_fp16_rounding':float(np.max(np.abs(c-rounded.astype(np.float64))))}
    (HERE/'center.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record,indent=2))

if __name__=='__main__':main(Path(sys.argv[1]) if len(sys.argv)>1 else SOURCE)
