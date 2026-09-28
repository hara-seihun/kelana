"""Independent exact BF16 gamma-image reader and power-of-two audit."""
from pathlib import Path
import hashlib
import numpy as np
from safetensors import safe_open
import torch

HERE=Path(__file__).resolve().parent
IMAGE=HERE/'balanced-qk-gamma-bf16.bin'
SHA='c8173158c88975e808804bb89a9e59b4cfa485a60f8d854fc4963ad89c830865'
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
ORIGINAL_SHA='cae8b69bdb89082b436e1d2c1a0314f245f051a2f17b6026a68dac5bb2b2e79f'

def decode():
    raw=IMAGE.read_bytes()
    assert len(raw)==512 and hashlib.sha256(raw).hexdigest()==SHA
    words=np.frombuffer(raw,dtype='<u2').astype(np.uint32)
    assert np.all((words&0x7f80)!=0) and np.all((words&0x7f80)!=0x7f80)
    values=(words<<16).view('<f4').copy().reshape(2,128)
    assert np.isfinite(values).all()
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        original=[f.get_tensor('model.layers.0.self_attn.'+name+'_norm.weight').clone() for name in ('q','k')]
    source=b''.join(g.view(torch.int16).numpy().astype('<i2').tobytes() for g in original)
    assert hashlib.sha256(source).hexdigest()==ORIGINAL_SHA
    baseline=np.stack([g.float().numpy() for g in original]).astype(np.float32)
    assert np.all(baseline!=0),'a zero gamma field would require an explicit exponent witness'
    ratio=values[0]/baseline[0]
    reciprocal=baseline[1]/values[1]
    exponent=np.rint(np.log2(ratio)).astype(np.int32)
    assert np.array_equal(ratio,np.exp2(exponent))
    assert np.array_equal(reciprocal,ratio)
    assert np.array_equal(exponent[:64],exponent[64:])
    assert np.array_equal(values[0],np.ldexp(baseline[0],exponent))
    assert np.array_equal(values[1],np.ldexp(baseline[1],-exponent))
    return values,baseline,exponent
