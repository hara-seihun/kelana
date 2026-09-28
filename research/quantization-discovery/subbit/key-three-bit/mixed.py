#!/usr/bin/env python3
"""Allocate a sparse fourth key bit by its causal score effect on frozen paid Q/K."""
import argparse
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open
from three_bit import cache, codes, finite, lowering, paid, query_scores, sha, DATA, ROOT


def causal_kl_at_positions(candidate, teacher, positions):
    mask = torch.arange(256)[None,:] > torch.tensor(positions)[:,None]
    p = teacher.masked_fill(mask,-1e9).log_softmax(-1)
    q = candidate.masked_fill(mask,-1e9).log_softmax(-1)
    return (p.exp()*(p-q)).sum(-1).mean().item()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    torch.set_num_threads(4)
    suffix=f'layer{args.layer:02d}'
    three_path=DATA/f'key-three-bit/{suffix}.json'
    parent_path=DATA/f'key-nibble-cache/{suffix}.json'
    prior_path=DATA/f'paid-qk-cache-slack/{suffix}.json'
    three=json.loads(three_path.read_text())
    parent=json.loads(parent_path.read_text())
    prior=json.loads(prior_path.read_text())
    q_path=DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path=DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt',device='cpu') as model:
        prefix=f'model.layers.{args.layer}.self_attn.'
        original={n:model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights=dict(original)
    weights['q_proj']=paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj']=paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma=torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    projected=[]
    for split,count in (('train',8),('validation',4)):
        x=finite.load_capture(args.layer,split).reshape(count,256,1024)
        q,k=paid.projected(x,weights,gamma)
        tq,tk=paid.projected(x,original,original['k_norm'])
        projected.append((q,k,tq,tk))
    train,held=projected
    positions=list(range(64,256,12))
    groups=[]
    for g,(row,old) in enumerate(zip(three['groups'],parent['groups'])):
        idx=old['mask']+[p+64 for p in old['mask']]
        center=torch.tensor(old['train_center'],dtype=torch.float64).reshape(1,1,1,-1)
        choice=row['selected']
        step3=torch.tensor(choice['steps']).double().reshape(1,1,1,-1)
        origin3=center if choice['center']=='centered' else torch.zeros_like(center)
        arm=parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        step4=torch.tensor(old['int4'][arm]['steps']).double().reshape(1,1,1,-1)
        origin4=center if arm.startswith('centered') else torch.zeros_like(center)
        qt=train[0][:,2*g:2*g+2,:,idx].double()
        kt=train[1][:,g:g+1,:,idx].double()
        qh=held[0][:,2*g:2*g+2,:,idx].double()
        kh=held[1][:,g:g+1,:,idx].double()
        c3t=codes(kt,origin3,step3)
        c4t=((kt-origin4)/step4).round().clamp(-7,7)
        c3h=codes(kh,origin3,step3)
        c4h=((kh-origin4)/step4).round().clamp(-7,7)
        teacher_t=cache.scores(train[2][:,2*g:2*g+2],train[3][:,g:g+1],positions)
        teacher_h=cache.scores(held[2][:,2*g:2*g+2],held[3][:,g:g+1],list(range(256)))
        # The observation is key-position softmax. The different constant offsets
        # from the two codebooks disappear separately for each coordinate.
        s3=cache.scores(qt,c3t*step3,positions)
        ranks=[]
        for j in range(32):
            difference=(c4t[...,j]*step4[...,j]-c3t[...,j]*step3[...,j])
            delta=qt[:,:,positions,j].unsqueeze(-1)*difference.unsqueeze(2)/math.sqrt(128)
            ranks.append((causal_kl_at_positions(s3+delta,teacher_t,positions)-causal_kl_at_positions(s3,teacher_t,positions),j))
        order=[j for _,j in sorted(ranks)]
        arms={}
        for n in (0,8,16,24,32):
            selected=order[:n]
            st=step3.clone(); st[...,selected]=step4[...,selected]
            ct=c3t.clone(); ct[...,selected]=c4t[...,selected]
            ch=c3h.clone(); ch[...,selected]=c4h[...,selected]
            score_t=query_scores(qt,ct,st)[:,:,positions,:]
            score_h=query_scores(qh,ch,st)
            arms[str(n)]={'train_kl':causal_kl_at_positions(score_t,teacher_t,positions),
                          'held_by_window':lowering.causal_kl(score_h,teacher_h).tolist(),
                          'selected_coordinates':selected}
        groups.append({'group':g,'marginal_order':order,'single_swap_train_delta':[v for v,j in sorted(ranks)],'arms':arms})
        print('group',g, 'held', {n:sum(a['held_by_window'])/4 for n,a in arms.items()},flush=True)
    aggregate={n:[sum(group['arms'][n]['held_by_window'][w] for group in groups)/8 for w in range(4)] for n in ('0','8','16','24','32')}
    report={'layer':args.layer,'contract':'train-only single-swap finite causal KL ranking on signed-three-bit key coordinates; promote 0/8/16/24/32 selected coordinates per group to frozen nibble codebooks, shared by both heads; dynamic eight-bit query split into two nibble dots; original-producer paid Q/K',
            'groups':groups,'held_by_window':aggregate,'held_mean':{n:sum(v)/4 for n,v in aggregate.items()},
            'cost':{'cache_bytes_for_promoted_coordinates':{n:96+int(n) for n in aggregate},
                    'per_group_pack_bytes_for_promoted_coordinates':{n:12+int(n)//8 for n in aggregate},
                    'query_products_per_token_layer':512,'nibble_products_per_key_two_heads':1024,
                    'raw_k_norm_rows':1024,'steps_fp16_bytes_per_layer':512,
                    'coordinate_bit_positions_and_mixed_unpack_online_not_measured':True},
            'source_sha256':sha(Path(__file__)),'three_bit_sha256':sha(three_path),'parent_sha256':sha(parent_path),
            'prior_sha256':sha(prior_path),'model_sha256':sha(finite.MODEL),
            'capture_sha256':sha(finite.value_fit.CAPTURES/f'{suffix}.npz'),
            'paid_q_sha256':sha(q_path),'paid_k_sha256':sha(k_path)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print('aggregate',report['held_mean'],flush=True)


if __name__=='__main__':main()
