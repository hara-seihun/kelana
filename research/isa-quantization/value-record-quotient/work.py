"""Price a potential grouped readout from committed counts; do not execute it."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'kivi-value-intern'
rows = []
for window in range(4):
    path = SOURCE / f'held-{window}-manifest.json'
    raw = path.read_bytes()
    record = json.loads(raw)['prefixes'][255]['before']
    t = record['quant_positions'] + record['recent_positions']
    distinct = record['quant_unique'] + record['recent_unique']
    assert t == 256
    rows.append({
        'window': window,
        'manifest_sha256': hashlib.sha256(raw).hexdigest(),
        'typed_distinct_records': distinct,
        'quantized_distinct': record['quant_unique'],
        'recent_distinct': record['recent_unique'],
        'ordinary_value_products': 16 * 128 * t,
        'grouped_value_products': 16 * 128 * distinct,
        'products_removed': 16 * 128 * (t - distinct),
        'group_mass_contributions': 16 * t,
        'fp32_group_mass_bytes': 16 * distinct * 4,
        'per_kv_group_mass_bytes': 2 * distinct * 4,
        'common_full_o_products': 1024 * 2048,
    })
out = {
    'scope': 'Count-only consequence of exact real regrouping; no grouped reader implemented or timed',
    'omitted_from_product_saving': 'score/softmax, group scatter or gather, initialization, barriers, reference loads, field decode, O, rounding acceptance',
    'rows': rows,
}
(HERE / 'work.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out, indent=2))
