#!/usr/bin/env python3
"""Aggregate immutable fixed-cache diagnostic numerators, not window ratios."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
result = {'scope': 'Original frozen KIVI and source values with FP64 diagnostic contractions; no new fitted cache.', 'panels': {}}
for panel, count in [('train', 8), ('held', 4)]:
    paths = [HERE / f'{panel}-{i}.json' for i in range(count)]
    rows = [json.loads(path.read_text()) for path in paths]
    assert all(row['panel'] == panel and row['window'] == i for i, row in enumerate(rows))
    squared = {key: sum(row['squared_norms'][key] for row in rows) for key in rows[0]['squared_norms']}
    cross = {key: sum(row['twice_inner_products'][key] for row in rows) for key in rows[0]['twice_inner_products']}
    ref = squared['reference']
    result['panels'][panel] = {
        'windows': count, 'reference_squared_norm': ref,
        'relative_squared': {key: val/ref for key, val in squared.items() if key != 'reference'},
        'twice_inner_products_relative': {key: val/ref for key, val in cross.items()},
        'key_plus_value_separate_loss_relative': (squared['key']+squared['value'])/ref,
        'linear_prediction_loss_relative': sum(row['linear_prediction_squared_norm'] for row in rows)/ref,
        'linear_prediction_discrepancy_relative': sum(row['linear_prediction_discrepancy_squared'] for row in rows)/ref,
        'identity_max_abs': max(row['exact_identity_max_abs'] for row in rows),
        'receipts': [{'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in paths]}
(HERE / 'results.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
