import json
from pathlib import Path
here=Path(__file__).resolve().parent
rows=[json.loads((here/f'{group}-{i}-result.json').read_text()) for group,n in (('train',8),('held',4)) for i in range(n)]
summary={
 'windows':len(rows), 'phases':sum(r['prefixes_verified'] for r in rows),
 'ordered_original_record_checks':sum(r['original_record_checks'] for r in rows),
 'max_snapshot_bytes':max(r['peak_snapshot_bytes'] for r in rows),
 'max_quant_slots':max(r['quant_peak'] for r in rows),
 'max_recent_slots':max(r['recent_peak'] for r in rows),
 'reserved_arrays':rows[0]['reserved_arrays'],
 'record_comparisons':sum(r['comparisons'] for r in rows),
 'comparison_width_upper_bytes':sum(r['compared_upper_bytes'] for r in rows),
 'record_write_bytes':sum(r['record_write_bytes'] for r in rows),
 'arriving_bytes':sum(r['input_bytes'] for r in rows),
 'baseline_peak_bytes':304768,
 'baseline_minus_reserved_arrays':304768-rows[0]['reserved_arrays'],
 'windows_receipts':[{'window':r['window'],'final_sha256':r['final_sha256'],'peak_snapshot_bytes':r['peak_snapshot_bytes']} for r in rows],
}
(here/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='windows_receipts'}))
