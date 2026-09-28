"""Source custody shared by producer, independent decoder and aggregator."""
import hashlib
import json
from pathlib import Path
from importlib.util import spec_from_file_location, module_from_spec

ROOT = Path(__file__).resolve().parent.parent
spec = spec_from_file_location('exchange_controls', ROOT / 'kivi-kv-rate-exchange/controls.py')
owner = module_from_spec(spec)
spec.loader.exec_module(owner)
EXCHANGE_SHA = owner.RESULTS_SHA256


def arrivals(window):
    owner = ROOT / 'kivi-value-intern'
    raw = (owner / f'held-{window}-events.bin').read_bytes()
    manifest = json.loads((owner / f'held-{window}-manifest.json').read_text())
    assert len(raw) == manifest['events_bytes'] == 256 * 4098
    assert hashlib.sha256(raw).hexdigest() == manifest['events_sha256']
    return raw


def exchange():
    return owner.read_results_bytes()


if __name__ == '__main__':
    here = Path(__file__).resolve().parent
    exchange()
    for window in range(4):
        raw = arrivals(window)
        manifest = json.loads((here / f'held-{window}-manifest.json').read_text())
        result = json.loads((here / f'held-{window}-result.json').read_text())
        assert hashlib.sha256(raw).hexdigest() == manifest['arrival_sha256'] == result['source_arrival_sha256']
        assert result['exchange_result_sha256'] == EXCHANGE_SHA
    print('Four source owners and unchanged eight-state control receipt match.')
