"""Run the canonical complete causal observer unchanged except adding one frozen Q image."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'quip-complete-head-observer/measure.py'
spec=importlib.util.spec_from_file_location('canonical_complete_head',SOURCE)
base=importlib.util.module_from_spec(spec);sys.modules[spec.name]=base;spec.loader.exec_module(base)
from replay import decode,IMAGE_SHA
original_load=base.load_images
base.HERE=HERE
base.ASSETS={**base.ASSETS,'bitmask-root-map/bitmask-root-standalone.bin':IMAGE_SHA}

def images():
    result=original_load()
    data=(HERE/'bitmask-root-standalone.bin').read_bytes()
    assert hashlib.sha256(data).hexdigest()==IMAGE_SHA
    result['bitmask']=decode(data).astype(np.float32)
    return result
base.load_images=images


def aggregate():
    out={}
    for panel,count in (('train',8),('held',4)):
        records=[json.loads((HERE/f'{panel}-{i}.json').read_text()) for i in range(count)]
        assert all(r['source_rows']==[i*256,(i+1)*256] and r['capture_model_q_exact'] for i,r in enumerate(records))
        assert all(r['images_sha256']==records[0]['images_sha256'] for r in records)
        out[panel]={}
        for name in records[0]['modes']:
            group=[r['modes'][name] for r in records]
            totals={key:sum(g['counts'][key] for g in group) for key in group[0]['counts']}
            out[panel][name]={
                'raw_q_rel_sq_bf16':totals['raw_q_sse']/totals['raw_q_ref_sq'],
                'normalized_q_rel_sq':totals['normalized_q_sse']/totals['normalized_q_ref_sq'],
                'attention_kl':sum(g['attention_kl'] for g in group)/count,
                'post_o_rel_sq':totals['head0_post_o_sse']/totals['head0_post_o_ref_sq'],
                'gqa_pair_post_o_rel_sq':totals['gqa_pair_post_o_sse']/totals['gqa_pair_post_o_ref_sq'],
                'counts':totals,
                'per_window':[{'attention_kl':g['attention_kl'],'post_o_rel_sq':g['post_o_rel_sq']} for g in group],
            }
    (HERE/'observer-results.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({panel:{name:{k:v for k,v in m.items() if k not in ('counts','per_window')} for name,m in modes.items()} for panel,modes in out.items()},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('panel',choices=['train','held','aggregate']);p.add_argument('window',type=int,nargs='?')
    a=p.parse_args()
    if a.panel=='aggregate':aggregate()
    else:base.measure(a.panel,a.window)
