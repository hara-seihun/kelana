"""Aggregate exact threshold receipts; does not rerun encoder/source work."""
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
rows = [json.loads((HERE / f'{panel}-{window}-{t}.json').read_text())
        for panel, n in [('train', 8), ('held', 4)] for window in range(n) for t in (32, 256)]
assert len(rows) == 24 and all(x['different_bytes'] == 0 for x in rows)
widths = {k: max(x['maximum_observed_magnitude_bits'][k] for x in rows)
          for k in rows[0]['maximum_observed_magnitude_bits']}
result = {
    'chunks': len(rows), 'decisions': sum(x['decisions'] for x in rows),
    'binary_comparisons': sum(x['binary_comparisons'] for x in rows),
    'exact_boundary_ties': sum(x['exact_boundary_ties'] for x in rows),
    'changed_codes': sum(x['changed_codes'] for x in rows),
    'compared_output_bytes': 2560 * len(rows), 'different_bytes': 0,
    'field_source_exponents': sorted(set(x['field_source_common_exponent'] for x in rows)),
    'maximum_observed_magnitude_bits': widths,
    'scope': 'First and last saved32-key chunks from all12 original windows;24 of96 chunks. Exact integer choices, no GPU/lowering/timing.',
    'representation': {'factor_int32_bytes': 4096, 'diagonal_int64_bytes': 1024,
                       'optional_curvature_int64_bytes': 1024, 'original_FP16_metric_bytes': 2304},
    'receipts': [f"{x['panel']}-{x['window']}-{x['prefix']}.json" for x in rows]
}
(HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
