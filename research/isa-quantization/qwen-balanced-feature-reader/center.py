"""One FP16 round of the fixed balanced-gamma train-causal-pair center."""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'qwen-balanced-gamma/train-balanced-center-f64.npy'
SOURCE_SHA='15ecf7b5a73b3cfe80ebcc08ab4f6ba286e852bff02ef180bf8b71622043a5b0'
IMAGE=HERE/'balanced-center-f16.bin'

def main():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_SHA
    center=np.load(SOURCE)
    assert center.dtype==np.float64 and center.shape==(128,)
    fields=center.astype('<f2')
    assert fields.nbytes==256 and np.isfinite(fields).all()
    IMAGE.write_bytes(fields.tobytes())
    record={'source_center_sha256':SOURCE_SHA,
        'center_image_sha256':hashlib.sha256(IMAGE.read_bytes()).hexdigest(),
        'model_specific_center_bytes':len(IMAGE.read_bytes()),
        'max_abs_fp16_rounding':float(np.max(np.abs(center-fields.astype(np.float64))))}
    (HERE/'center.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record,indent=2))

if __name__=='__main__':main()
