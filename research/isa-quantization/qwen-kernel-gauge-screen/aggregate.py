"""Combine equal-size causal-pair window geometry, without fitting/evaluating features."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent

def pool(rows):
    return {'min':min(r['min'] for r in rows),
            'max':max(r['max'] for r in rows),
            'equal_pair_mean':sum(r['mean'] for r in rows)/len(rows),
            'window_median_min_max':[min(r['median'] for r in rows),max(r['median'] for r in rows)],
            'window_p95_min_max':[min(r['p95'] for r in rows),max(r['p95'] for r in rows)]}

def main():
    center=json.loads((HERE/'center.json').read_text())
    assert hashlib.sha256((HERE/'train-causal-pair-center-f64.npy').read_bytes()).hexdigest()==center['center_sha256']
    result={'center':center,'panels':{}}
    for panel,count in (('train',8),('inspected_held',4)):
        prefix='held' if panel=='inspected_held' else 'train'
        rows=[json.loads((HERE/f'{prefix}-{i}.json').read_text()) for i in range(count)]
        assert all(r['panel']==prefix and r['window']==i and r['center_sha256']==center['center_sha256'] for i,r in enumerate(rows))
        data={'original_key_squared_norm':pool([r['key_squared_norm'] for r in rows]),
              'shifted_key_squared_norm':pool([r['centered_key_squared_norm'] for r in rows]),'heads':{}}
        for head in ('head0','head1'):
            data['heads'][head]={'uncentered_exponent':pool([r['heads'][head]['uncentered_exponent'] for r in rows]),
                'shifted_exponent':pool([r['heads'][head]['train_centered_exponent'] for r in rows])}
        data['mean_exponent_reduction_both_heads']=sum(
            data['heads'][h]['uncentered_exponent']['equal_pair_mean']-data['heads'][h]['shifted_exponent']['equal_pair_mean']
            for h in ('head0','head1'))/2
        if panel=='train':
            assert abs(data['mean_exponent_reduction_both_heads']-center['center_squared_norm'])<1e-7
        result['panels'][panel]=data
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
