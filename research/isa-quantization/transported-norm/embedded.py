#!/usr/bin/env python3
"""Fixed 8,704-byte Q4-coordinate grammar, with pair labels in redundant FP16 signs.

The grammar requires strictly negative origins and strictly positive steps.
Each pair uses origin_i, step_i and origin_(i+64) sign bits for a three-bit
angle code 0..4. All other bits, including FP16 exponents and mantissas, are
preserved. The reader restores the canonical signs before scalar Q4 decoding.
"""
import hashlib
from pathlib import Path

import numpy as np

from observer import Q4, q4_decode
from replay import main

HERE = Path(__file__).resolve().parent
PAIR_COUNT = 64
ROW_BYTES = 68
IMAGE_BYTES = 128 * ROW_BYTES


def sign_positions(pair):
    return (pair * ROW_BYTES + 65, pair * ROW_BYTES + 67,
            (pair + PAIR_COUNT) * ROW_BYTES + 65)


def constrained_fields(q4):
    if len(q4) != IMAGE_BYTES:
        raise ValueError('Q4 payload must be 8,704 bytes')
    scalars = np.stack([np.frombuffer(q4, dtype='<f2', count=2,
                                      offset=row * ROW_BYTES + 64).astype(np.float32)
                        for row in range(128)])
    if not np.isfinite(scalars).all() or not np.all(scalars[:, 0] < 0) or not np.all(scalars[:, 1] > 0):
        raise ValueError('This image is outside the negative-origin/positive-step grammar')
    return {'origin_min': float(scalars[:, 0].min()),
            'origin_max': float(scalars[:, 0].max()),
            'step_min': float(scalars[:, 1].min()),
            'step_max': float(scalars[:, 1].max())}


def serialize(q4, angles):
    constrained_fields(q4)
    if len(angles) != PAIR_COUNT or any(int(code) not in range(5) for code in angles):
        raise ValueError('64 angle labels in 0..4 required')
    image = bytearray(q4)
    for pair, code in enumerate(angles):
        for bit, position in enumerate(sign_positions(pair)):
            if (int(code) >> bit) & 1:
                image[position] ^= 0x80
    return bytes(image)


def deserialize(image):
    if len(image) != IMAGE_BYTES:
        raise ValueError('Coordinate image must be exactly 8,704 bytes')
    q4 = bytearray(image)
    choices = np.empty(PAIR_COUNT, dtype=np.uint8)
    for pair in range(PAIR_COUNT):
        first, second, third = sign_positions(pair)
        code = ((q4[first] >> 7) ^ 1) | ((q4[second] >> 7) << 1) | (((q4[third] >> 7) ^ 1) << 2)
        if code >= 5:
            raise ValueError('Unused angle label')
        choices[pair] = code
        q4[first] |= 0x80
        q4[second] &= 0x7f
        q4[third] |= 0x80
    constrained_fields(q4)
    return q4_decode(q4), choices, bytes(q4)


def encode_and_read(q4, choices):
    encoded = serialize(q4, choices)
    target = HERE / 'q4-coordinate-embedded.bin'
    target.write_bytes(encoded)
    reader_image = target.read_bytes()
    decoded, read_choices, restored = deserialize(reader_image)
    if restored != q4 or not np.array_equal(read_choices, choices):
        raise AssertionError('Serialized coordinates did not reproduce source payload')
    metadata = {'embedded_image_bytes': len(reader_image),
                'embedded_image_sha256': hashlib.sha256(reader_image).hexdigest(),
                'restored_q4_sha256': hashlib.sha256(restored).hexdigest(),
                'scalar_field_ranges': constrained_fields(restored),
                'exported_q4_control_field_ranges': constrained_fields(Q4.read_bytes()),
                'angle_code_counts': np.bincount(read_choices, minlength=5).tolist(),
                'storage': 'three FP16 sign bits per RoPE pair; sign restoration and label extraction paid by reader'}
    return decoded, read_choices, metadata


if __name__ == '__main__':
    main(codec=encode_and_read)
