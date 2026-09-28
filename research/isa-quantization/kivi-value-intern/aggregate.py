"""Summarize fixed-layout receipts; no selection or fitting."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
rows = []
for panel, count in (('train', 8), ('held', 4)):
    for window in range(count):
        path = HERE / f'{panel}-{window}'
        result = json.loads(path.with_name(path.name+'-result.json').read_text())
        manifest = json.loads(path.with_name(path.name+'-manifest.json').read_text())
        assert result['prefixes_verified'] == 512 and len(manifest['prefixes']) == 256
        peak_pair = max(p['before']['bytes']+p['after']['bytes'] for p in manifest['prefixes'])
        max_records = max(p[phase]['quant_positions']*384+p[phase]['recent_positions']*2048
                          for p in manifest['prefixes'] for phase in ('before','after'))
        rows.append({k:result[k] for k in ('panel','window','peak_bytes','final_bytes',
            'peak_saved_bytes','final_saved_bytes','max_quant_unique','max_recent_unique',
            'dictionary_record_comparisons')}
            | {'max_current_and_next_image_bytes':peak_pair,
               'max_conventional_v_shadow_bytes':max_records})
summary = {'layout': 'full8-V exact-first-occurrence u8 references, 5B header, unchanged K',
           'baseline_peak_bytes':304768, 'baseline_final_bytes':249856,
           'all_prefixes_verified':sum(256*2 for _ in rows),
           'windows':rows,
           'mean_peak_bytes_by_panel':{panel:sum(r['peak_bytes'] for r in rows if r['panel']==panel)//count
             for panel,count in (('train',8),('held',4))},
           'mean_final_bytes_by_panel':{panel:sum(r['final_bytes'] for r in rows if r['panel']==panel)//count
             for panel,count in (('train',8),('held',4))}}
(HERE/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({'mean_peak':summary['mean_peak_bytes_by_panel'],
                  'mean_final':summary['mean_final_bytes_by_panel'],
                  'ranges':{'peak':[min(x['peak_bytes'] for x in rows),max(x['peak_bytes'] for x in rows)],
                            'final':[min(x['final_bytes'] for x in rows),max(x['final_bytes'] for x in rows)]}}))
