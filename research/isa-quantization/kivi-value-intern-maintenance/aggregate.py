"""Summarize independently accepted native maintenance receipts."""
import json
from pathlib import Path

here = Path(__file__).resolve().parent
names = [f'{p}-{i}' for p, count in (('train', 8), ('held', 4)) for i in range(count)]
results = [json.loads((here/f'{name}-result.json').read_text()) for name in names]
assert all(r['window'] == n and r['prefixes_verified'] == 512 and r['reserved_working_bytes'] == 284674
           for r, n in zip(results,names))
summary = {
    'windows': 12, 'prefixes_verified': sum(x['prefixes_verified'] for x in results),
    'original_record_checks': sum(x['original_record_checks'] for x in results),
    'arena_capacity': 266240, 'fixed_buffers_reserved_bytes': 284674,
    'maximum_image_used_bytes': max(x['arena_used_peak'] for x in results),
    'baseline_peak_bytes': 304768,
    'fixed_buffer_saving_vs_baseline_bytes': 304768-284674,
    'total_moved_bytes': sum(x['moved_bytes'] for x in results),
    'total_inserted_bytes': sum(x['inserted_bytes'] for x in results),
    'total_full_record_comparisons': sum(x['record_comparisons'] for x in results),
    'panels': {p: {'mean_image_used_peak_bytes': sum(x['arena_used_peak'] for x in results if x['window'].startswith(p))//count,
                    'total_moved_bytes': sum(x['moved_bytes'] for x in results if x['window'].startswith(p))}
               for p,count in (('train',8),('held',4))},
    'receipts': [f'{n}-result.json' for n in names],
}
(here/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for generated in ('maintain', 'maintain.su'):
    (here/generated).unlink(missing_ok=True)
print(json.dumps(summary))
