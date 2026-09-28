"""Combine all original eight train and four inspected-held causal windows."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
CANON=HERE.parent/'quip-complete-head-observer'
FIELDS=('head0_post_o','gqa_pair_post_o','raw_q','normalized_q','centered_score')

def aggregate(panel,count):
    records=[json.loads((HERE/f'{panel}-{i}.json').read_text()) for i in range(count)]
    assert all(r['panel']==panel and r['window']==i and r['source_rows']==[256*i,256*(i+1)]
               and r['capture_model_q_exact'] for i,r in enumerate(records))
    assert all(r['images_sha256']==records[0]['images_sha256'] for r in records)
    assert set(records[0]['modes'])=={'root_H','scalar_H','root_M','scalar_M','normalized_affine'}
    aggregate={}
    for name in records[0]['modes']:
        metrics=[r['modes'][name] for r in records]
        assert all(m['counts']['query_tokens']==256 for m in metrics)
        summed={key:sum(m['counts'][key] for m in metrics) for key in metrics[0]['counts']}
        aggregate[name]={'attention_kl':sum(m['attention_kl'] for m in metrics)/count,
            **{f'{field}_rel_sq':summed[field+'_sse']/summed[field+'_ref_sq'] for field in FIELDS},
            'per_window_attention_kl':[m['attention_kl'] for m in metrics]}
    original=json.loads((CANON/'results.json').read_text())[panel]
    for name in ('root_H','scalar_H','root_M','scalar_M'):
        for k,v in aggregate[name].items():
            if k=='per_window_attention_kl':continue
            original_key={'raw_q_rel_sq':'raw_q_rel_sq_bf16',
                          'head0_post_o_rel_sq':'post_o_rel_sq',
                          'gqa_pair_post_o_rel_sq':'gqa_pair_post_o_rel_sq',
                          'normalized_q_rel_sq':'normalized_q_rel_sq',
                          'centered_score_rel_sq':'centered_score_rel_sq',
                          'attention_kl':'attention_kl'}[k]
            assert abs(v-original[name][original_key])<1e-9,(panel,name,k,v,original[name][original_key])
    return aggregate

if __name__=='__main__':
    result={'train':aggregate('train',8),'inspected_held':aggregate('held',4)}
    (HERE/'observer-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
