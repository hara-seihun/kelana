"""Validate reused successful control receipts without another observer replay."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
OWNER = HERE.parent / 'kivi-o-aware-values'
RESULTS_SHA256 = 'cb4154bab21c49f80dc10ea60ac0aa248f8535f8e5287a2b64540dc2b0aab6cc'


def read_results_bytes():
    """The frozen precision exchange is itself a control for later studies."""
    raw = (HERE / 'results.json').read_bytes()
    assert hashlib.sha256(raw).hexdigest() == RESULTS_SHA256
    return raw


def read_controls():
    controls = json.loads((HERE / 'controls.json').read_text())
    for w in range(4):
        row = controls['records'][str(w)]
        for suffix, key in [('result', 'kivi2_receipt_sha256'),
                            ('kivi4-control', 'receipt_sha256')]:
            raw = (OWNER / f'held-{w}-{suffix}.json').read_bytes()
            assert hashlib.sha256(raw).hexdigest() == row[key]
            source = json.loads(raw)
            if suffix == 'result':
                assert source['retained'] == row['kivi2_retained']
            else:
                assert source == row['receipt']
    return controls


if __name__ == '__main__':
    read_controls()
    read_results_bytes()
    print('Eight reused control receipts and the frozen exchange match their owner bytes')
