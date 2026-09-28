#!/usr/bin/env python3
"""Retain true Qwen final normalized inputs and BF16 head logits on fixed windows."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit')
MODEL=DATA/'models/qwen3-0.6b'
TOKENS=DATA/'fixtures/qwen3-0.6b-wikitext/tokens.npz'


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def main(output):
    output.mkdir(parents=True,exist_ok=True)
    source=json.loads((MODEL/'source.json').read_text())
    fixture=json.loads((TOKENS.parent/'manifest.json').read_text())
    if sha(MODEL/'model.safetensors')!=source['files']['model.safetensors']['sha256']:
        raise ValueError('model bytes differ from pinned revision')
    if sha(TOKENS)!=fixture['tokens_sha256']:
        raise ValueError('window tokens differ from pinned fixture')
    with np.load(TOKENS) as z:
        windows={'train':z['train'][:4].copy(),'validation':z['validation'][:2].copy()}
    model=AutoModelForCausalLM.from_pretrained(MODEL,local_files_only=True,
        dtype=torch.bfloat16,attn_implementation='sdpa').eval().to('cuda')
    captured=[]
    def hook(_module,inputs):
        captured.append(inputs[0][0].detach().float().cpu().numpy().copy())
    handle=model.lm_head.register_forward_pre_hook(hook)
    hidden={};logits=[];gold=[];positions=[];reference_nll=[]
    with torch.inference_mode():
        for split,batches in windows.items():
            hidden[split]=[]
            for i,tokens in enumerate(batches):
                x=torch.as_tensor(tokens,device='cuda',dtype=torch.long).unsqueeze(0)
                before=len(captured)
                out=model(x,use_cache=False).logits
                if len(captured)!=before+1:raise ValueError('LM head was not called exactly once')
                hidden[split].append(captured.pop())
                if split=='validation':
                    take=np.arange(3,255,8,dtype=np.int64)
                    sample=out[0,torch.as_tensor(take,device='cuda')].float()
                    logits.append(sample.cpu().numpy().copy())
                    labels=tokens[take+1]
                    gold.append(labels.copy())
                    positions.extend([[i,int(p)] for p in take])
                    logz=torch.logsumexp(sample,dim=-1)
                    target=sample.gather(1,torch.as_tensor(labels,device='cuda',dtype=torch.long)[:,None]).squeeze(1)
                    reference_nll.extend((logz-target).cpu().numpy().astype(float).tolist())
                del out
    handle.remove()
    arrays={'train_hidden':np.concatenate(hidden['train']),
            'validation_hidden':np.concatenate(hidden['validation']),
            'selected_logits':np.concatenate(logits),
            'selected_gold':np.concatenate(gold),
            'selected_positions':np.asarray(positions,np.int32),
            'selected_reference_nll':np.asarray(reference_nll,np.float32)}
    target=output/'final-head.npz'
    np.savez_compressed(target,**arrays)
    manifest={'format':'qwen3-tied-head-capture/1',
        'model_repository':source['repository'],'model_revision':source['revision'],
        'model_safetensors_sha256':source['files']['model.safetensors']['sha256'],
        'tokens_sha256':sha(TOKENS),'capture_source_sha256':sha(Path(__file__)),
        'python_executable':sys.executable,
        'python_executable_sha256':sha(Path(sys.executable)),
        'gpu_wrapper_sha256':sha(Path('/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare')),
        'torch':torch.__version__,'hip':torch.version.hip,'device':torch.cuda.get_device_name(),
        'window_counts':{'train':4,'validation':2},'window_length':256,
        'validation_logit_positions':'per window 3,11,...,251; next-token labels follow',
        'numerical_contract':'model BF16 head output converted to FP32 and saved; hook observes final normalized BF16 input converted to FP32',
        'arrays':{k:{'shape':list(v.shape),'dtype':str(v.dtype),
                     'sha256':hashlib.sha256(v.tobytes()).hexdigest()} for k,v in arrays.items()},
        'capture_sha256':sha(target)}
    (output/'capture.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'capture_sha256':manifest['capture_sha256'],
        'validation_tokens':int(arrays['validation_hidden'].shape[0]),
        'selected_logits':int(arrays['selected_logits'].shape[0]),
        'selected_reference_nll':float(np.mean(arrays['selected_reference_nll']))}))


if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('capture.py OUTPUT_DIR')
    main(Path(sys.argv[1]))
