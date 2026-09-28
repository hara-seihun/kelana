"""Pool the eight frozen retained states and price the paid images."""
import hashlib
import json
from pathlib import Path
from inputs import arrivals as owned_arrivals, exchange as owned_exchange

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
EXCHANGE=ROOT/'kivi-kv-rate-exchange'
NATIVE=ROOT/'kivi-two-bit-dot-native'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    control=EXCHANGE/'results.json'
    exchange=json.loads(owned_exchange())
    snapshots=NATIVE/'snapshots.json'
    native=json.loads(snapshots.read_text())
    states=[]
    owners=[]
    for w in range(4):
        manifest=HERE/f'held-{w}-manifest.json'
        receipt=HERE/f'held-{w}-result.json'
        meta=json.loads(manifest.read_text())
        result=json.loads(receipt.read_text())
        assert meta['fixed_fields_bytes']==6144
        assert meta['bias_sha256']==digest(HERE/'bias-fp32.bin')
        assert meta['center_sha256']==digest(HERE/'center-fp16.bin')
        assert meta['original_o_sha256']==native['original_o_sha256']
        assert meta['arms']['translated']['peak_cache_bytes']==304768
        assert meta['arms']['translated']['final_cache_bytes']==249856
        assert meta['arms']['v35']['peak_cache_bytes']==309760
        assert meta['arms']['v35']['final_cache_bytes']==254848
        assert result['exchange_result_sha256']==digest(control)
        assert result['source_arrival_sha256']==meta['arrival_sha256']==hashlib.sha256(owned_arrivals(w)).hexdigest()
        assert result['bias_sha256']==meta['bias_sha256']
        assert len(result['states'])==2
        states.extend(result['states'])
        owners.append({'window':w,'manifest_sha256':digest(manifest),'reader_result_sha256':digest(receipt)})
    assert len(states)==8
    for r in states:
        donor=next(x for x in exchange['per_state'] if x['window']==r['window'] and x['t']==r['t'])
        assert abs(r['teacher_sq']-donor['teacher_sq'])<1e-4
        assert abs(r['k2v2_sse']-donor['K2V2_sse'])<2e-5
        assert r['k2v4_sse']==donor['K2V4_sse']
    teacher=sum(r['teacher_sq'] for r in states)
    assert abs(teacher-exchange['teacher_sq'])<1e-4
    named={'translated': 'translated_sse', 'v35':'v35_sse',
           'k2v2':'k2v2_sse','k2v4':'k2v4_sse',
           'source_rounding':'source_boundary_sse_vs_original_bf16_under_k2'}
    pooled={name:{'sse':sum(r[key] for r in states),
                  'relative_sq':sum(r[key] for r in states)/teacher}
            for name,key in named.items()}
    result={'scope':'four held streams x t128,t256 original retained 16Q/8KV/1024O',
            'teacher_sq':teacher,'exchange_results_sha256':digest(control),
            'native_snapshots_sha256':digest(snapshots),
            'center_sha256':digest(HERE/'center-fp16.bin'),
            'bias_sha256':digest(HERE/'bias-fp32.bin'),
            'paid_bytes':{'translated_cache_peak':304768,'translated_cache_final':249856,
                          'center':2048,'bias':4096,'translated_total_peak':310912,
                          'translated_total_final':256000,'v35_peak':309760,'v35_final':254848,
                          'k2v2_peak':304768,'k2v4_peak':361856},
            'owner_receipts':owners,'pooled':pooled,'states':states}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'teacher_sq':teacher,'pooled':pooled},indent=2))


if __name__=='__main__':
    main()
