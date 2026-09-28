#!/usr/bin/env python3
"""Fit a rank-row constant correction to a paid binary first factor."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
SOURCE = Path(__file__)
OUT = ROOT / 'binary-weight-center/receipt.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ladder(a, threshold=.75):
    words = np.asarray(a, dtype=np.float64).reshape(a.shape[0], -1, 32)
    gm = np.max(np.abs(words), axis=2)
    top = np.maximum(gm.max(axis=1), 1e-30)
    exponent = np.clip(np.floor(np.log2(top[:, None] / np.maximum(gm, 1e-30))).astype(np.int32), 0, 8)
    upper = top[:, None] / 63 * np.exp2(-exponent.astype(np.float64))
    choose = (gm / 63 <= upper * threshold) & (exponent < 8)
    steps = np.where(choose, upper * .75, upper)
    weight = np.where(choose, 3 << (7 - exponent), 1 << (9 - exponent)).astype(np.int32)
    q = np.clip(np.rint(words / steps[:, :, None]), -64, 63).astype(np.int32)
    return q, weight, top / 63 * 2 ** -9


def stage(signs, x, threshold=.75):
    q, weights, base = ladder(x, threshold)
    out = np.zeros((len(x), len(signs)), dtype=np.int32)
    for g in range(q.shape[1]):
        out += (q[:, g] @ signs[:, 32*g:32*(g+1)].T) * weights[:, g, None]
    return out, base


def rms(a, b):
    return float(np.linalg.norm(a-b) / np.linalg.norm(b))


def digest(a):
    return hashlib.sha256(np.ascontiguousarray(a).tobytes()).hexdigest()


def run(layer):
    image = ROOT / f'binary-factors/fixtures/model_layers_{layer}_mlp_up_proj_weight_0.55.npz'
    fixture = ROOT / f'fixtures/qwen3-0.6b-wikitext/layer{layer:02d}-mlp_up_proj.npz'
    with np.load(image) as data:
        n, k, rank = map(int, data['dimensions'])
        v = 2*np.unpackbits(data['V'], axis=1, count=k, bitorder='little').astype(np.int32)-1
        u = 2*np.unpackbits(data['U'], axis=1, count=rank, bitorder='little').astype(np.int32)-1
        pre = data['scale_pre'].astype(np.float64)
        post = data['scale_post'].astype(np.float64)
    with np.load(fixture) as data:
        train = data['train'][512:640].astype(np.float64) * pre
        held = data['validation'][576:704].astype(np.float64) * pre
    x = np.concatenate([train, held]); count = len(train)
    h, b1 = stage(v, x)
    real_h = x @ v.T.astype(np.float64)
    sumx = np.sum(x, axis=1)
    approx_h = h.astype(np.float64)*b1[:, None]
    # A constant correction per packed sign row is learned from training response.
    # The factor is genuinely a new real weight (sign + center) but the sign reader stays packed.
    denom = np.dot(sumx[:count], sumx[:count])
    center = sumx[:count] @ (real_h[:count]-approx_h[:count]) / denom
    center16 = center.astype(np.float16).astype(np.float64)
    truth = (real_h @ u.T.astype(np.float64))*post
    arms = {}
    for label, c in [('symmetric', np.zeros(rank)), ('fitted_fp16', center16)]:
        # A direct consumer adds the learned center after the first sign dot; there is
        # no materialized int4 weight image. The second ladder sees those new coordinates.
        intermediate = approx_h + sumx[:, None]*c[None, :]
        z, b2 = stage(u, intermediate)
        y = z.astype(np.float64)*b2[:, None]*post
        # Also isolate whether the correction improves the first-stage ideal response.
        arms[label] = dict(train_rms=rms(y[:count], truth[:count]),
                           held_rms=rms(y[count:], truth[count:]),
                           held_first_rms=rms(intermediate[count:], real_h[count:]),
                           held_per_input=[rms(y[i],truth[i]) for i in range(count,len(x))],
                           held_second_integer_sha256=digest(z[count:]),
                           held_intermediate_sha256=digest(intermediate[count:]))
    # A second, direct route fits the same shared activation statistic at the
    # observed output instead of routing it through the discontinuous A7 ladder.
    baseline_z, baseline_b2 = stage(u, approx_h)
    baseline = baseline_z.astype(np.float64)*baseline_b2[:, None]*post
    output_center = (sumx[:count] @ (truth[:count]-baseline[:count]) / denom).astype(np.float16)
    corrected = baseline + sumx[:, None]*output_center.astype(np.float64)[None, :]
    arms['output_center_fp16'] = dict(train_rms=rms(corrected[:count],truth[:count]),
        held_rms=rms(corrected[count:],truth[count:]),
        held_per_input=[rms(corrected[i],truth[i]) for i in range(count,len(x))],
        held_response_sha256=digest(corrected[count:]))
    oracle = sumx[count:] @ (truth[count:]-baseline[count:]) / np.dot(sumx[count:],sumx[count:])
    oracle_y = baseline[count:] + sumx[count:,None]*oracle[None,:]
    arms['held_output_center_oracle'] = dict(held_rms=rms(oracle_y,truth[count:]),
        held_response_sha256=digest(oracle_y))
    output_cosine = float(np.dot(output_center.astype(np.float64),oracle) /
        (np.linalg.norm(output_center.astype(np.float64))*np.linalg.norm(oracle)))
    return dict(layer=layer, image_sha256=sha(image), fixture_sha256=sha(fixture),
                dimensions=[n,k,rank], train_rows=[512,640], held_rows=[576,704],
                first_integer_sha256=digest(h), fitted_center_fp16_sha256=digest(center.astype(np.float16)),
                output_center_fp16_sha256=digest(output_center),
                train_held_output_center_cosine=output_cosine,
                center_fp16_max=float(np.abs(center16).max()),
                sumx_train_rms=float(np.sqrt(np.mean(sumx[:count]**2))),
                sumx_held_rms=float(np.sqrt(np.mean(sumx[count:]**2))), arms=arms)


def main():
    entries = [run(i) for i in (0,7,14,27)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(dict(source_sha256=sha(SOURCE), numpy_version=np.__version__,
        contract='Paid .55 binary U/V, FP64 input/result with signed-seven-bit two-choice integer ladders; train original-producer rows 512:640, disjoint validation rows 576:704. FP16 rank-row constant weight correction fits first-stage reconstruction; FP16 output correction fits complete response. Held-output oracle bounds the latter unrestricted real rank-one-statistic family on these held inputs, not deployable. Reference is unmodified same-image FP64 response. Both arms change the model map and consume the shared first-factor input sum without expanding weights. No native or whole-model result.', entries=entries), indent=2)+'\n')
    for e in entries:
        print(e['layer'], {k:(v.get('train_rms'), v['held_rms']) for k,v in e['arms'].items()}, flush=True)
    print(OUT)

if __name__ == '__main__':
    main()
