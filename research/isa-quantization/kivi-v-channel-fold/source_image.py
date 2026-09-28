"""Independent byte-image reader for folded V/O (no builder imports)."""
import hashlib
import json
from pathlib import Path
import numpy as np
import torch

HERE=Path(__file__).resolve().parent

def read_source_images():
    receipt=json.loads((HERE/'source-image.json').read_text())
    v=(HERE/'v-replacement.bf16').read_bytes()
    o=(HERE/'o-replacement.bf16').read_bytes()
    assert len(v)==receipt['v_bytes']==262144 and hashlib.sha256(v).hexdigest()==receipt['v_sha256']
    assert len(o)==receipt['o_bytes']==524288 and hashlib.sha256(o).hexdigest()==receipt['o_sha256']
    vv=np.frombuffer(v,dtype='<u2').copy().reshape(128,1024)
    oo=np.frombuffer(o,dtype='<u2').copy().reshape(1024,256)
    # BF16 words are read directly, not a fresh affine/channel refit.
    vt=torch.from_numpy(vv.view(np.int16)).view(torch.bfloat16).float()
    ot=torch.from_numpy(oo.view(np.int16)).view(torch.bfloat16).float()
    return vt,ot
