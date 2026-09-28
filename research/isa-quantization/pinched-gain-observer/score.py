"""Fixed source-derived gain pinching at the original BF16 final-head boundary."""
import hashlib
import json
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
CAP=Path('/path/to/workspace/data/kelana-subbit/tied-head/final-head.npz')
MAN=CAP.parent/'capture.json'
TOK=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/tokens.npz')
MODEL_SHA='f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b'


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(4*1024*1024),b''):h.update(block)
    return h.hexdigest()


def metrics(teacher,candidate,labels):
    t=teacher.astype(np.float64);c=candidate.astype(np.float64)
    mt=t.max(axis=1);mc=c.max(axis=1)
    logzt=mt+np.log(np.exp(t-mt[:,None]).sum(axis=1))
    logzc=mc+np.log(np.exp(c-mc[:,None]).sum(axis=1))
    p=np.exp(t-logzt[:,None])
    kl=np.sum(p*(t-c),axis=1)+logzc-logzt
    assert np.min(kl)>-1e-9
    gold=np.arange(len(labels))
    return {'positions':len(labels),
            'teacher_gold_nll':float(np.mean(logzt-t[gold,labels])),
            'candidate_gold_nll':float(np.mean(logzc-c[gold,labels])),
            'gold_nll_change':float(np.mean((logzc-c[gold,labels])-(logzt-t[gold,labels]))),
            'teacher_to_candidate_kl':float(np.mean(kl)),
            'max_teacher_to_candidate_kl':float(np.max(kl)),
            'p95_teacher_to_candidate_kl':float(np.percentile(kl,95)),
            'top1_changes':int(np.count_nonzero(np.argmax(t,axis=1)!=np.argmax(c,axis=1))),
            'changed_gold_nll_positions':int(np.count_nonzero((logzc-c[gold,labels])>(logzt-t[gold,labels])))}


def main():
    torch.set_num_threads(1)
    assert sha(MODEL)==MODEL_SHA
    capture=json.loads(MAN.read_text())
    assert capture['capture_sha256']==sha(CAP)
    assert capture['model_safetensors_sha256']==MODEL_SHA
    assert capture['tokens_sha256']==sha(TOK)
    with np.load(CAP) as data:
        arrays={key:data[key].copy() for key in capture['arrays']}
    for key,field in capture['arrays'].items():
        a=arrays[key]
        assert list(a.shape)==field['shape'] and str(a.dtype)==field['dtype']
        assert hashlib.sha256(a.tobytes()).hexdigest()==field['sha256']
    with np.load(TOK) as data:
        tokens={key:data[key].copy() for key in ('train','validation')}
    with safe_open(MODEL,framework='pt',device='cpu') as source:
        query=source.get_tensor('model.layers.0.self_attn.q_proj.weight')[:128].float().numpy().astype(np.float64)
        input_gain=source.get_tensor('model.layers.0.input_layernorm.weight').float().numpy().astype(np.float64)
        final_gain=source.get_tensor('model.norm.weight').float().numpy().astype(np.float64)
        embedding=source.get_tensor('model.embed_tokens.weight')
    assert embedding.shape==(151936,1024) and torch.all(embedding.isfinite())
    assert np.all(input_gain!=0) and np.all(final_gain!=0)
    # SVD computes only the rank-128 *source* row space; no head capture or
    # labels choose U. Singular values are nonzero on this checkpoint.
    _,singular,vt=np.linalg.svd(query*input_gain[None,:],full_matrices=False)
    assert singular.shape==(128,) and singular[-1]>1e-8
    u=vt.T
    c=final_gain[:,None]*u-u@(u.T@(final_gain[:,None]*u))
    assert np.max(np.abs(u.T@c))<1e-10
    delta_fro2=float(2*np.sum(c*c))
    delta_spectral=float(np.linalg.svd(c,compute_uv=False)[0])
    projection=u@u.T
    delta=c@u.T+u@c.T
    pinched=np.diag(final_gain)-delta
    assert np.max(np.abs(pinched-pinched.T))<1e-12
    assert np.max(np.abs(pinched@projection-projection@pinched))<1e-10
    assert abs(np.sum(delta*delta)-delta_fro2)<1e-8
    receipt={'checkpoint_sha256':MODEL_SHA,'capture_sha256':sha(CAP),
             'capture_manifest_sha256':sha(MAN),'tokens_sha256':sha(TOK),
             'source_boundary':'pinned BF16 source-model head-hook output before tied head; no changed upstream producer',
             'candidate_boundary':'BF16-round (h - Delta*(h/final_gamma)), then CPU torch BF16 matmul with original tied BF16 head',
             'rank':128,'minimum_source_singular_value':float(singular[-1]),
             'gain_delta_frobenius_squared':delta_fro2,'gain_delta_spectral':delta_spectral,
             'splits':{}}
    candidate_selected=[];teacher_selected=[];ideal_selected=[]
    for split,window_count in (('train',4),('validation',2)):
        hidden=arrays['train_hidden' if split=='train' else 'validation_hidden']
        assert hidden.shape==(window_count*256,1024)
        assert np.array_equal(torch.from_numpy(hidden).to(torch.bfloat16).float().numpy(),hidden)
        scores=[]
        for window in range(window_count):
            h=hidden[window*256:(window+1)*256].astype(np.float64)
            n=h/final_gain[None,:]
            correction=(n@u)@c.T+(n@c)@u.T
            replacement=h-correction
            if window==0:assert np.max(np.abs(n[:1]@pinched.T-replacement[:1]))<1e-10
            original_logits=(torch.from_numpy(h.astype(np.float32)).to(torch.bfloat16)@embedding.T).float().numpy()
            candidate_logits=(torch.from_numpy(replacement.astype(np.float32)).to(torch.bfloat16)@embedding.T).float().numpy()
            labels=tokens[split][window,1:256].astype(np.int64)
            assert np.all((labels>=0)&(labels<151936))
            result=metrics(original_logits[:255],candidate_logits[:255],labels)
            result['window']=window
            result['relative_pre_head_shift']=float(np.linalg.norm(correction)/np.linalg.norm(h))
            scores.append(result)
            if split=='validation':
                take=np.arange(3,255,8,dtype=int)
                candidate_selected.append(candidate_logits[take])
                teacher_selected.append(original_logits[take])
                ideal_selected.append((torch.from_numpy(replacement[take].astype(np.float32))@embedding.float().T).numpy())
        receipt['splits'][split]={'windows':scores,
            'positions':sum(row['positions'] for row in scores),
            'mean_teacher_gold_nll':float(np.mean([row['teacher_gold_nll'] for row in scores])),
            'mean_candidate_gold_nll':float(np.mean([row['candidate_gold_nll'] for row in scores])),
            'mean_gold_nll_change':float(np.mean([row['gold_nll_change'] for row in scores])),
            'mean_teacher_to_candidate_kl':float(np.mean([row['teacher_to_candidate_kl'] for row in scores])),
            'top1_changes':sum(row['top1_changes'] for row in scores)}
    selected=np.concatenate(candidate_selected)
    selected_ideal=np.concatenate(ideal_selected)
    selected_cpu=np.concatenate(teacher_selected)
    positions=arrays['selected_positions']
    assert np.array_equal(positions,np.asarray([(i,j) for i in range(2) for j in range(3,255,8)],dtype=np.int32))
    gold=arrays['selected_gold'].astype(np.int64)
    source_gpu=arrays['selected_logits']
    receipt['selected_captured_gpu_teacher']={
        'source_cpu_bf16_vs_captured_gpu_relative_logit_rms':float(np.linalg.norm(selected_cpu-source_gpu)/np.linalg.norm(source_gpu)),
        'source_cpu_bf16_vs_captured_gpu_max_absolute_logit':float(np.max(np.abs(selected_cpu-source_gpu))),
        'captured_gpu_reference_nll':float(np.mean(arrays['selected_reference_nll'])),
        'score':metrics(source_gpu,selected,gold),
        'ideal_fp32_head_score':metrics(source_gpu,selected_ideal,gold),
        'bf16_vs_ideal_candidate_relative_logit_rms':float(np.linalg.norm(selected-selected_ideal)/np.linalg.norm(selected_ideal))}
    (HERE/'results.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))

if __name__=='__main__':main()
