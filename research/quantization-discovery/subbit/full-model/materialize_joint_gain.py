#!/usr/bin/env python3
"""Write the train-selected paid V/O and MLP down image without changing its rate."""
import json
from pathlib import Path

import numpy as np

from joint_gain_fit import CHOICE, DOWN, NARROW, ROOT
from mlp_factor_response import digest
from narrow_prefix import sha


def main():
    choice = json.loads(CHOICE.read_text())
    assert sha(NARROW) == choice['input_vo_sha256']
    assert sha(DOWN) == choice['input_down_sha256']
    with np.load(NARROW) as data:
        narrow = {key: data[key].copy() for key in data.files}
    with np.load(DOWN) as data:
        down = {key: data[key].copy() for key in data.files}
    paid_vo = sum(value.nbytes for value in narrow.values())
    paid_down = sum(value.nbytes for value in down.values())
    narrow['left_scales'] = (narrow['left_scales'].astype(np.float32) * choice['selected_gain']).astype(np.float16)
    down['scale_post'] = (down['scale_post'].astype(np.float32) * choice['down_gain']).astype(np.float16)
    out_vo = ROOT / 'mlp-vo-joint-value.npz'
    out_down = ROOT / 'mlp-vo-joint-down.npz'
    np.savez_compressed(out_vo, **narrow)
    np.savez_compressed(out_down, **down)
    with np.load(out_vo) as data:
        assert sum(data[key].nbytes for key in data.files) == paid_vo
        assert all(np.array_equal(data[key], narrow[key]) for key in data.files)
    with np.load(out_down) as data:
        assert sum(data[key].nbytes for key in data.files) == paid_down
        assert all(np.array_equal(data[key], down[key]) for key in data.files)
    receipt = {'format': 'paid-vo-down-joint-image/1', 'source_sha256': digest(Path(__file__)),
        'choice_sha256': sha(CHOICE), 'vo_input_sha256': sha(NARROW), 'down_input_sha256': sha(DOWN),
        'vo_image_sha256': sha(out_vo), 'down_image_sha256': sha(out_down),
        'vo_payload_bytes': paid_vo, 'down_payload_bytes': paid_down,
        'online_terms_delta': 0, 'vo_gain': choice['selected_gain'], 'down_gain': choice['down_gain']}
    out = ROOT / 'mlp-vo-joint-image.json'
    out.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
