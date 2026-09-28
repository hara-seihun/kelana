"""One bounded signed-input fit at rank 96 with the previously screened Q4 readout."""
import hashlib
import json
from pathlib import Path

import numpy as np
from screen import FIXTURE, q4_readout_grid, relerr

RANK = 96
IMAGE = Path(__file__).with_name('signed-carrier96.bin')
OUT = Path(__file__).with_name('sign-results.json')


def fit_gains(h, w, s, q):
    c = q.T @ q
    shs = s @ h @ s.T
    lhs = shs * c
    rhs = np.sum((s @ h @ w.T) * q.T, axis=1)
    return np.linalg.solve(lhs, rhs)


def save_image(s, gain, records):
    image = bytearray()
    image.extend(np.packbits((s > 0).astype('u1'), axis=1, bitorder='little').tobytes())
    for codes, scale in records:
        nibble = codes.astype('uint8') & 15
        image.extend((nibble[0::2] | (nibble[1::2] << 4)).tobytes())
        image.extend(np.asarray([scale], dtype='<f2').tobytes())
    image.extend(np.asarray(gain, dtype='<f2').tobytes())
    IMAGE.write_bytes(image)
    assert len(image) == 8128
    return bytes(image)


def load_image(image):
    signs = np.unpackbits(np.frombuffer(image, dtype='u1', count=16*RANK).reshape(RANK, 16),
                          axis=1, bitorder='little').astype('float64') * 2 - 1
    q = np.empty((128, RANK), dtype='float64')
    start = 16 * RANK
    for row in range(128):
        offset = start + row * (RANK//2 + 2)
        packed = np.frombuffer(image, dtype='u1', count=RANK//2, offset=offset)
        codes = np.empty(RANK, dtype='int8')
        codes[0::2] = packed & 15
        codes[1::2] = packed >> 4
        codes[codes >= 8] -= 16
        scale = float(np.frombuffer(image, dtype='<f2', count=1, offset=offset + RANK//2)[0])
        q[row] = codes.astype('float64') * scale
    gain = np.frombuffer(image, dtype='<f2', count=RANK, offset=start + 128*(RANK//2+2)).astype('float64')
    return signs, gain, q


def main():
    with np.load(FIXTURE) as f:
        w = f['weight'][:128, :128].astype('float64')
        x = f['train'][:, :128].astype('float64')
        held = f['validation'][:, :128].astype('float64')
    target = x @ w.T
    basis = np.linalg.svd(target, full_matrices=False)[2][:RANK].T
    q, records = q4_readout_grid(basis)
    h = x.T @ x
    a = w.T @ q @ np.linalg.inv(q.T @ q)
    signs = np.where(a.T >= 0, 1., -1.)
    gains = fit_gains(h, w, signs, q)
    initial = relerr(x @ (signs.T * gains) @ q.T, target)
    initial_free_readout = relerr(x @ signs.T @ np.linalg.lstsq(x @ signs.T, target, rcond=None)[0], target)
    # Exact single-sign-flip quadratic changes; each greedy choice is train improving.
    # Refit all real gains after each group of 40 flips. No held data enters selection.
    flips = 0
    for batch in range(4):
        gains = fit_gains(h, w, signs, q)
        c = q.T @ q
        m = h @ w.T @ q - (h @ signs.T * gains) @ c
        for _ in range(40):
            delta = 4 * gains[:, None] * signs * m.T + 4 * (gains[:, None]**2) * np.diag(h)[None, :] * np.diag(c)[:, None]
            j, k = np.unravel_index(np.argmin(delta), delta.shape)
            if delta[j, k] >= -1e-10:
                break
            change = 2 * gains[j] * signs[j, k]
            m += change * h[:, k, None] * c[j, None, :]
            signs[j, k] *= -1
            flips += 1
    gains = fit_gains(h, w, signs, q)
    image = save_image(signs, gains, records)
    decoded_s, decoded_g, decoded_q = load_image(image)
    assert np.array_equal(decoded_s, signs) and np.array_equal(decoded_q, q)
    assert np.array_equal(decoded_g, np.asarray(gains, dtype='float16').astype('float64'))
    matrix = (decoded_s.T * decoded_g) @ decoded_q.T
    final_free_readout = relerr(x @ signs.T @ np.linalg.lstsq(x @ signs.T, target, rcond=None)[0], target)
    result = dict(rank=RANK, image=IMAGE.name, bytes=len(image), sha256=hashlib.sha256(image).hexdigest(),
                  signed_flip_steps=flips, initial_train_relerr=initial,
                  initial_free_readout_train_relerr=initial_free_readout,
                  final_free_readout_train_relerr=final_free_readout,
                  final_train_relerr=relerr(x @ matrix, target),
                  final_held_relerr=relerr(held @ matrix, held @ w.T),
                  free_input_fixed_readout_train_relerr=relerr(target @ np.linalg.qr(q)[0] @ np.linalg.qr(q)[0].T, target))
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
