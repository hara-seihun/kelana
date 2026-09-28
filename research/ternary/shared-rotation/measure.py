#!/usr/bin/env python3
"""Construct and check one exact prefix-shared sign stream for the paid ternary model."""
import hashlib
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit/ternary')
SOURCE = DATA / 'fresh-duration32'
PAID = DATA / 'fresh-duration32-code-page-16384'
OUTPUT = DATA / 'fresh-duration32-shared-rotation'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    parent = json.loads((PAID / 'receipt.json').read_text())
    records = []
    signs = {}
    for item in parent['matrices']:
        name = item['name']
        with np.load(SOURCE / name) as original:
            sign = original['signs'].tobytes()
            shape = original['shape'].astype('<i4').tobytes()
            rotation = original['rotation_block'].astype('<i4').tobytes()
            code_length = original['codes'].nbytes
            n = int(original['shape'][1])
        assert len(sign) == (n + 7) // 8 and n % 8 == 0
        key = 'embedding' if name == 'model_embed_tokens_weight.npz' else n
        if key in signs:
            assert signs[key] == sign, name
        signs[key] = sign
        source = PAID / name.replace('.npz', '.tern')
        payload = source.read_bytes()
        prefix = shape + rotation
        code_end = len(prefix) + item['paid_code_bytes']
        assert payload.startswith(prefix)
        assert code_length == item['original_code_bytes']
        assert payload[code_end:code_end + len(sign)] == sign, name
        output = OUTPUT / source.name
        output.write_bytes(payload[:code_end] + payload[code_end + len(sign):])
        stored = output.read_bytes()
        assert stored[:code_end] + sign + stored[code_end:] == payload
        records.append(dict(name=source.name, input_sha256=digest(source), output_sha256=digest(output),
                            shape=[int(x) for x in np.frombuffer(shape, dtype='<i4')],
                            rotation_block=int(np.frombuffer(rotation, dtype='<i4')[0]),
                            sign_bytes=len(sign), output_bytes=len(stored)))
    largest = signs[3072]
    for n in (1024, 2048):
        assert signs[n] == largest[:len(signs[n])], n
    dictionary = largest + signs['embedding']
    (OUTPUT / 'signs.bin').write_bytes(dictionary)
    norm_source = PAID / 'norms.bin'
    (OUTPUT / 'norms.bin').write_bytes(norm_source.read_bytes())
    assert digest(OUTPUT / 'norms.bin') == digest(norm_source)
    assert len(records) == 197
    saved = sum(item['sign_bytes'] for item in records) - len(dictionary)
    total = sum(item['output_bytes'] for item in records) + len(dictionary) + norm_source.stat().st_size
    assert total == parent['paid_payload_bytes'] - saved
    receipt = dict(source_script_sha256=digest(Path(__file__)), parent_receipt_sha256=digest(PAID / 'receipt.json'),
                   source_manifest_sha256=digest(SOURCE / 'manifest.json'), parent_paid_bytes=parent['paid_payload_bytes'],
                   paid_payload_bytes=total, saved_bytes=saved, unique_parameters=parent['unique_parameters'],
                   paid_bpw=8*total/parent['unique_parameters'], sign_sha256=digest(OUTPUT / 'signs.bin'),
                   signs_by_input_width={str(n):len(value) for n,value in signs.items()},
                   format='One 384-byte packed sign stream shared by 196 transformer matrices, plus 128 distinct embedding signs. Transformer matrices infer the prefix length from existing shape; embedding selects the trailing 128 bytes. Other matrix bytes are unchanged from the independently decoded code/scale-page image. No per-matrix pointer.',
                   matrices=records)
    (OUTPUT / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k:v for k,v in receipt.items() if k != 'matrices'}, indent=2))


if __name__ == '__main__':
    main()
