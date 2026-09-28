#!/usr/bin/env python3
"""Paid static RoPE-commuting key-coordinate correction for the signed Q image."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from measure import (FIX, MODEL, SIGNED, Q4, OUT, compare, head, normalized, rope,
                     signed_decode, q4_decode)


def features(q, k):
    qx, qy = q[:, :64], q[:, 64:]
    kx, ky = k[:, :64], k[:, 64:]
    straight = qx[:, None] * kx[None] + qy[:, None] * ky[None]
    twist = qy[:, None] * kx[None] - qx[:, None] * ky[None]
    return torch.cat((straight, twist), -1) / math.sqrt(128)


def fit(wq, signed, q4, inputs, wk, qgamma, kgamma):
    gram = np.zeros((128,128),np.float64)
    cross = np.zeros(128,np.float64)
    target_energy = 0.
    q4_error = 0.
    prior = np.r_[np.ones(64),np.zeros(64)]
    for window in inputs:
        x = torch.from_numpy(window.astype(np.float32))
        original = (x @ wq.T).to(torch.bfloat16).float()
        modified = wq.clone()
        modified[:, :128] = signed
        candidate = (x @ modified.T).to(torch.bfloat16).float()
        q4matrix = wq.clone()
        q4matrix[:, :128] = q4
        q4query = (x @ q4matrix.T).to(torch.bfloat16).float()
        key = (x @ wk.T).to(torch.bfloat16).float()
        qref = rope(normalized(original,qgamma))
        q = rope(normalized(candidate,qgamma))
        k = rope(normalized(key,kgamma))
        matrix = features(q,k)
        scores = qref @ k.T / math.sqrt(128)
        q4scores = rope(normalized(q4query,qgamma)) @ k.T / math.sqrt(128)
        for t in range(len(x)):
            feat = matrix[t,:t+1].numpy().astype(np.float64)
            target = scores[t,:t+1].numpy().astype(np.float64)
            logits = scores[t,:t+1]
            prob = logits.softmax(-1).numpy().astype(np.float64)
            feat -= prob @ feat
            target -= prob @ target
            gram += feat.T @ (prob[:,None]*feat)
            cross += feat.T @ (prob*target)
            target_energy += float(prob @ (target*target))
            q4diff=(q4scores[t,:t+1]-scores[t,:t+1]).numpy().astype(np.float64)
            q4diff -= prob @ q4diff
            q4_error += float(prob @ (q4diff*q4diff))
    free_coeff = np.linalg.lstsq(gram,cross,rcond=1e-12)[0]
    free_floor = target_energy - 2*float(free_coeff@cross)+float(free_coeff@gram@free_coeff)
    ridge = 1e-4 * np.trace(gram)/128
    fitted = np.linalg.solve(gram+ridge*np.eye(128),cross+ridge*prior)
    eig = np.linalg.eigvalsh(gram)
    certificate = dict(free_real_centered_score_floor=free_floor,
                       q4_centered_score_loss=q4_error,
                       teacher_centered_score_energy=target_energy,
                       free_floor_over_q4=free_floor/q4_error,
                       gram_rank=int(np.linalg.matrix_rank(gram)),
                       gram_min_eigenvalue=float(eig[0]),
                       gram_max_eigenvalue=float(eig[-1]),
                       normal_equation_relative_residual=float(np.linalg.norm(gram@free_coeff-cross)/np.linalg.norm(cross)))
    return torch.from_numpy(fitted.astype(np.float16).astype(np.float32)),ridge,certificate


def corrected_head(qraw,kraw,vraw,qgamma,kgamma,wo,coeff):
    q = rope(normalized(qraw,qgamma))
    k = rope(normalized(kraw,kgamma))
    alpha,beta = coeff[:64],coeff[64:]
    kx,ky = k[:, :64],k[:,64:]
    changed = torch.cat((alpha*kx-beta*ky,beta*kx+alpha*ky),-1)
    logits = q @ changed.T / math.sqrt(128)
    logits = logits.masked_fill(torch.ones_like(logits,dtype=torch.bool).triu(1),-1e9)
    logp = logits.log_softmax(-1)
    out = (logp.exp()@vraw)@wo.T
    return logp,out,logits


def main():
    torch.set_num_threads(1)
    with np.load(FIX) as fixture:
        train = fixture['train'].reshape(8,256,1024)[:2].copy()
        held = fixture['validation'].reshape(4,256,1024)[:2].copy()
        wq_all = torch.from_numpy(fixture['weight'][:256].astype(np.float32).copy())
        wq = wq_all[:128]
    with safe_open(MODEL,framework='pt',device='cpu') as image:
        wk = image.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        wv = image.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        wo_all = image.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        wo,wo_peer=wo_all[:,:128],wo_all[:,128:256]
        qgamma = image.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma = image.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    signed = torch.from_numpy(signed_decode(SIGNED.read_bytes()))
    q4 = torch.from_numpy(q4_decode(Q4.read_bytes()))
    with torch.no_grad():
        coeff,ridge,score_projection = fit(wq,signed,q4,train,wk,qgamma,kgamma)
        image = np.asarray(coeff.numpy(),dtype='<f2').tobytes()
        assert len(image) == 256
        image_path = Path(__file__).with_name('key-correction.bin')
        image_path.write_bytes(image)
        coeff = torch.from_numpy(np.frombuffer(image_path.read_bytes(),dtype='<f2').astype(np.float32))
        fitted = wq.clone(); fitted[:,:128] = signed
        q4_fitted = wq.clone(); q4_fitted[:,:128] = q4
        panels = {}
        for label,data in [('train',train),('held',held)]:
            metrics=[]
            peer_metrics=[]
            group_metrics=[]
            q4_group_metrics=[]
            for block in data:
                x=torch.from_numpy(block.astype(np.float32))
                qref=(x@wq.T).to(torch.bfloat16).float()
                qcandidate=(x@fitted.T).to(torch.bfloat16).float()
                k=(x@wk.T).to(torch.bfloat16).float()
                v=(x@wv.T).to(torch.bfloat16).float()
                teacher=head(qref,k,v,qgamma,kgamma,wo)
                modified=corrected_head(qcandidate,k,v,qgamma,kgamma,wo,coeff)
                metrics.append(compare(teacher,modified))
                peer=(x@wq_all[128:256].T).to(torch.bfloat16).float()
                peer_teacher=head(peer,k,v,qgamma,kgamma,wo_peer)
                peer_candidate=corrected_head(peer,k,v,qgamma,kgamma,wo_peer,coeff)
                peer_metrics.append(compare(peer_teacher,peer_candidate))
                group_metrics.append({
                    'attention_kl':(metrics[-1]['attention_kl']+peer_metrics[-1]['attention_kl'])/2,
                    'post_o_rel_sq':float((modified[1]+peer_candidate[1]-teacher[1]-peer_teacher[1]).square().sum() /
                                          (teacher[1]+peer_teacher[1]).square().sum())})
                q4raw=(x@q4_fitted.T).to(torch.bfloat16).float()
                q4result=head(q4raw,k,v,qgamma,kgamma,wo)
                q4metrics=compare(teacher,q4result)
                q4_group_metrics.append({
                    'attention_kl':q4metrics['attention_kl']/2,
                    'post_o_rel_sq':float((q4result[1]-teacher[1]).square().sum() /
                                          (teacher[1]+peer_teacher[1]).square().sum())})
            panels[label]={'head0':{key:sum(m[key] for m in metrics)/len(metrics) for key in metrics[0]},
                           'peer_head1':{key:sum(m[key] for m in peer_metrics)/len(peer_metrics) for key in peer_metrics[0]},
                           'gqa_group':{key:sum(m[key] for m in group_metrics)/len(group_metrics) for key in group_metrics[0]},
                           'q4_gqa_control':{key:sum(m[key] for m in q4_group_metrics)/len(q4_group_metrics) for key in q4_group_metrics[0]}}
    report=json.loads(OUT.read_text())
    report['joint_key_correction']={'static_fp16_bytes':256,'total_submatrix_plus_correction_bytes':8128+256,
         'correction': '64 complex per-pair key factors, applied after K norm and commuting with RoPE',
         'ridge':ridge,'score_projection':score_projection,'correction_image':image_path.name,
         'correction_sha256':hashlib.sha256(image).hexdigest(),
         'coefficients_fp16':coeff.tolist(),'panels':panels,
         'extra_online_per_key':'64 complex multiplications (4 real multiplications and 2 additions each)'}
    OUT.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report['joint_key_correction']['panels'],indent=2))

if __name__=='__main__':
    main()
