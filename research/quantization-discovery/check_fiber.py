#!/usr/bin/env python3
"""Replay complete weight custody and both query routes from the fiber image."""
import hashlib
import json
from pathlib import Path
import numpy as np
from fiber_codec import Image
from fiber_fast import FastImage

HERE = Path(__file__).resolve().parent


def check():
    record = json.loads((HERE/'fiber-results.json').read_text())
    for name, expected in record['source_sha256'].items():
        assert hashlib.sha256((HERE/name).read_bytes()).hexdigest() == expected, name
    path = HERE/'instances/bonsai-layer00-down-block0.fiber'
    blob = path.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == record['wire_sha256']
    fixture_path = HERE/'instances/bonsai-layer00-down-block0.npz'
    assert hashlib.sha256(fixture_path.read_bytes()).hexdigest() == record['fixture_sha256']
    fixture = np.load(fixture_path)
    image = Image(blob)
    weights = np.array([image.decode_weights(row) for row in range(image.rows)], dtype=np.int8)
    assert np.array_equal(weights, fixture['trits'])
    assert np.array_equal(np.asarray(image.scale_bits, dtype=np.uint16), fixture['scale_bits'])
    assert hashlib.sha256(weights.tobytes()).hexdigest() == record['full_roundtrip']['decoded_sha256']
    fast = FastImage(blob)
    assert fast.packed_prefix_index_bytes == record['prefix_index_bytes']
    for query in (fixture['queries'][0], -fixture['queries'][0], fixture['queries'][7]):
        result = fast.evaluate(query)
        expected = fixture['trits'].astype(np.int32)@query.astype(np.int32)
        assert result['accumulators'] == expected.tolist()
    assert len(blob) == record['serialized_bytes'] < record['source_halo_bytes']
    return dict(valid=True, reconstructed_trits=int(weights.size), exact_scale_bits=image.rows*16,
                all_inputs_supported=True, source_weight_fallback=False,
                encoded_bytes=len(blob), source_bytes=record['source_halo_bytes'],
                prefix_index_bytes=fast.packed_prefix_index_bytes,
                gpu_or_tps_acceptance=False)


if __name__ == '__main__':
    print(json.dumps(check(), indent=2))
