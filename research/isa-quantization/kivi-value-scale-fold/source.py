"""Decode paid folded V/O image and recompute full original source observer."""
import hashlib,importlib.util,json,sys
from pathlib import Path
import numpy as np
import torch
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
spec=importlib.util.spec_from_file_location('fixed_full_qwen_source_for_fold',ROOT/'skvq-global-gqa/source.py')
base=importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

def sha(data):return hashlib.sha256(data).hexdigest()

def physical():
 receipt=json.loads((HERE/'source-fields.json').read_text())
 raw=(HERE/'replacement-v-o.bf16').read_bytes()
 assert len(raw)==receipt['replacement_image_bytes']==6291456 and sha(raw)==receipt['replacement_image_sha256']
 bits=np.frombuffer(raw,dtype='<u2')
 v=torch.from_numpy(bits[:1024*1024].copy()).view(torch.bfloat16).reshape(1024,1024).float()
 o=torch.from_numpy(bits[1024*1024:].copy()).view(torch.bfloat16).reshape(1024,2048).float()
 return v,o

def arrays(panel,window):
 torch.set_num_threads(1)
 original=base.arrays(panel,window)
 with np.load(base.original.FIX) as fixture:
  raw=fixture['train' if panel=='train' else 'validation'][window*256:(window+1)*256]
 x=torch.from_numpy(raw.astype(np.float32).copy())
 v,o=physical()
 value=(x@v.T).to(torch.bfloat16).float().reshape(256,8,128)
 probability=original['teacher_logp'].exp()
 mixed=torch.bmm(probability,value.permute(1,0,2).repeat_interleave(2,dim=0))
 output=mixed.permute(1,0,2).reshape(256,2048)@o.T
 return {'original':original,'value':value.to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy(),
         'o':o,'output':output,'source_v':v}

def check(panel,window):
 src=arrays(panel,window)
 original=src['original']
 scale=np.power(2.0,np.asarray(json.loads((HERE/'source-fields.json').read_text())['exponents'],dtype=np.int16)).astype(np.float32)
 old=original['value'].reshape(256,8,128)
 oldfp=torch.from_numpy((old.astype(np.uint32)<<16).view(np.float32).copy())
 new=src['value']
 newfp=torch.from_numpy((new.astype(np.uint32)<<16).view(np.float32).copy())
 expected=oldfp*torch.from_numpy(scale)[None]
 vr_drift=float((newfp-expected).abs().max())
 oldoutput=original['teacher'];newoutput=src['output']
 diff=newoutput-oldoutput
 result={'panel':panel,'window':window,
         'exact_bf16_v_coordinate_equivalence':bool(torch.equal(newfp,expected)),
         'max_abs_bf16_v_coordinate_difference':vr_drift,
         'max_abs_full_uncompressed_o_difference':float(diff.abs().max()),
         'full_uncompressed_o_rel_sq':float(diff.square().sum()/oldoutput.square().sum()),
         'full_uncompressed_o_bitwise_equal':bool(torch.equal(newoutput,oldoutput)),
         'source_teacher_square':float(oldoutput.square().sum())}
 (HERE/f'{panel}-{window}-source.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result))
if __name__=='__main__':check(sys.argv[1],int(sys.argv[2]))
