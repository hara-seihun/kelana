#!/usr/bin/env python3
"""Export the saved calibrated affine group-128 Qwen image as exact Q4_1 GGUF.

GGUF Q4_1 has 32-value blocks with FP16 scale and origin. Repeating each
saved group-128 scale/origin four times preserves the codes and coefficients;
the paid expansion is 12 bytes per original 128-value group. The output head
is omitted so llama.cpp ties it to the embedding, as the source model does.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from evaluate_gguf import parameter_name

SOURCE = Path('/path/to/workspace/data/kelana-subbit/q4-diagnostic/calibrated/manifest.json')
STOCK = Path('/path/to/workspace/data/kelana-subbit/q4-diagnostic/stock-gguf/Qwen_Qwen3-0.6B-Q4_K_M.gguf')
GGUF_PY = Path('/path/to/workspace/work/clones/bonsai-hip/gguf-py')


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def pack_q4_1(image):
    rows, cols = (int(x) for x in image['shape'])
    source = image['codes']
    scale = image['scales']
    origin = image['origins']
    assert source.shape == (rows, cols // 2) and scale.shape == origin.shape == (rows, cols // 128)
    # Kelana packs adjacent pairs; GGUF packs positions 0..15 in the low
    # nibble and 16..31 in the high nibble of each 32-value block.
    pairs = source.reshape(-1, 16)
    digits = np.empty((len(pairs), 32), dtype=np.uint8)
    digits[:, 0::2] = pairs & 15
    digits[:, 1::2] = pairs >> 4
    packed = digits[:, :16] | (digits[:, 16:] << 4)
    blocks = np.empty((len(pairs), 20), dtype=np.uint8)
    blocks[:, :2] = np.repeat(scale.reshape(-1).view(np.uint8).reshape(-1, 2), 4, axis=0)
    blocks[:, 2:4] = np.repeat(origin.reshape(-1).view(np.uint8).reshape(-1, 2), 4, axis=0)
    blocks[:, 4:] = packed
    assert np.array_equal(blocks[:, 4:] & 15, digits[:, :16])
    assert np.array_equal(blocks[:, 4:] >> 4, digits[:, 16:])
    assert np.array_equal(blocks[:, :2].reshape(-1, 2), np.repeat(scale.reshape(-1).view(np.uint8).reshape(-1, 2), 4, axis=0))
    return blocks.reshape(rows, cols // 32 * 20)


def run(args):
    sys.path.insert(0, str(args.gguf_py))
    import gguf
    manifest = json.loads(args.manifest.read_text())
    entries = {item['key']: item for item in manifest['matrices']}
    if len(entries) != 197 or len(entries) != len(manifest['matrices']):
        raise ValueError('expected 197 unique images')
    stock = gguf.GGUFReader(args.stock)
    writer = gguf.GGUFWriter(args.output, 'qwen3', use_temp_file=True)
    for key, field in stock.fields.items():
        if key.startswith('GGUF.') or key == 'general.architecture' or key.startswith('quantize.imatrix.'):
            continue
        value = (3 if args.format == 'q4_1' else 1) if key == 'general.file_type' else field.contents()
        if key == 'general.name':
            value = f'Kelana Qwen3-0.6B calibrated affine {args.format.upper()} tied'
        writer.add_key_value(key, value, field.types[0], field.types[-1] if len(field.types) > 1 else None)
    seen = set()
    audit = []
    payload = 0
    reference = None
    if args.format == 'source-f16':
        from safetensors import safe_open
        reference = safe_open('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors',
                              framework='pt', device='cpu')
    for tensor in stock.tensors:
        if tensor.name == 'output.weight':
            continue
        key = parameter_name(tensor.name)
        if key in entries:
            entry = entries[key]
            image_path = Path(entry['path'])
            if args.format != 'source-f16' and sha(image_path) != entry['sha256']:
                raise ValueError(f'image hash mismatch {image_path}')
            if args.format == 'source-f16':
                packed = reference.get_tensor(key).to(dtype=__import__('torch').float16).numpy()
                shape = packed.shape
                writer.add_tensor(tensor.name, packed)
            else:
                with np.load(image_path) as image:
                    shape = tuple(map(int, image['shape']))
                    source = image['codes'].reshape(shape[0], shape[1] // 2)
                    digits = np.empty(shape, np.float32)
                    digits[:, 0::2] = source & 15
                    digits[:, 1::2] = source >> 4
                    expected = (digits.reshape(shape[0], -1, 128) * image['scales'].astype(np.float32)[:, :, None]
                                + image['origins'].astype(np.float32)[:, :, None]).reshape(shape)
                    if args.format == 'q4_1':
                        packed = pack_q4_1(image)
                        decoded = gguf.quants.dequantize(packed, gguf.GGMLQuantizationType.Q4_1).reshape(shape)
                        if not np.array_equal(decoded, expected):
                            raise ValueError(f'GGUF decoder differs from research image: {key}, max error {np.max(np.abs(decoded-expected))}')
                        writer.add_tensor(tensor.name, packed.view(np.int8), raw_shape=shape,
                                          raw_dtype=gguf.GGMLQuantizationType.Q4_1)
                    else:
                        packed = expected.astype(np.float16)
                        writer.add_tensor(tensor.name, packed)
                    del expected, digits
            audit.append(dict(key=key, source_sha256=entry['sha256'] if args.format != 'source-f16' else None,
                              shape=shape, gguf_bytes=packed.nbytes, exact=args.format == 'q4_1'))
            payload += packed.nbytes
            seen.add(key)
        else:
            if tensor.tensor_type != gguf.GGMLQuantizationType.F32:
                raise ValueError(f'unexpected non-matrix tensor {tensor.name}')
            writer.add_tensor(tensor.name, tensor.data.copy())
            payload += tensor.n_bytes
    if seen != set(entries) or len(audit) != 197:
        raise ValueError(f'incomplete matrices: {set(entries) - seen}')
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()
    receipt = dict(source_manifest=str(args.manifest), source_manifest_sha256=sha(args.manifest),
                   stock_metadata=str(args.stock), image=str(args.output), image_sha256=sha(args.output),
                   image_bytes=args.output.stat().st_size, payload_bytes=payload,
                   original_payload_bytes=manifest['payload_bytes'], tied_head=True,
                   format=('Q4_1, 4 repeated FP16 scale/origin pairs per saved 128-value group'
                           if args.format == 'q4_1' else f'{args.format}: intermediate for matched quantization'),
                   tensor_audit=audit)
    args.output.with_suffix('.receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k:v for k,v in receipt.items() if k != 'tensor_audit'}), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, default=SOURCE)
    p.add_argument('--stock', type=Path, default=STOCK)
    p.add_argument('--gguf-py', type=Path, default=GGUF_PY)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--format', choices=['q4_1', 'f16', 'source-f16'], default='q4_1')
    run(p.parse_args())
