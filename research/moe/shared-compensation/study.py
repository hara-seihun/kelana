#!/usr/bin/env python3
"""Free hindsight shared-expert gain when omitting one real routed contribution."""
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
CAP = BASE / 'route-capture'
MODEL = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
OUT = BASE / 'shared-compensation' / 'receipt.json'


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def capture(split, name, dtype, shape):
    path = CAP / f'{split}.0.{name}-0.bin'
    array = np.memmap(path, dtype, 'r', shape=shape)
    return np.asarray(array, dtype=np.float64), str(path), sha(path)


def shared_weights():
    inventory = BASE / 'traffic.json'
    data = json.loads(inventory.read_text())
    meta = {t['name']: t for t in data['tensors']}
    header = (data['header_bytes'] + 31) // 32 * 32
    library = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    fn = ctypes.CDLL(str(library)).dequantize_row_q8_0
    fn.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
    fn.restype = None
    matrices = {}
    for key, shape in [('gate', (512, 2048)), ('up', (512, 2048)), ('down', (2048, 512))]:
        t = meta[f'blk.0.ffn_{key}_shexp.weight']
        source = np.memmap(MODEL, np.uint8, 'r', offset=header+t['offset'], shape=(t['bytes'],))
        result = np.empty(shape, np.float32)
        fn(source.ctypes.data_as(ctypes.c_void_p), result.ctypes.data_as(ctypes.POINTER(ctypes.c_float)), result.size)
        matrices[key] = result.astype(np.float64)
    t = meta['blk.0.ffn_gate_inp_shexp.weight']
    w = np.memmap(MODEL, '<f4', 'r', offset=header+t['offset'], shape=(2048,)).astype(np.float64)
    return matrices, w, str(library), sha(library), sha(inventory)


def summarize(split, matrices, w):
    n = 113 if split == 'train' else 126
    x, xp, xh = capture(split, 'attn_post_norm', '<f4', (n, 2048))
    scores, sp, sh = capture(split, 'ffn_moe_weights_norm', '<f4', (n, 8))
    routed, rp, rh = capture(split, 'ffn_moe_down', '<f4', (n, 8, 2048))
    ids, ip, ih = capture(split, 'ffn_moe_topk', '<i4', (n, 8))
    gate = x @ matrices['gate'].T
    up = x @ matrices['up'].T
    hidden = (gate / (1 + np.exp(-gate))) * up
    shared = (hidden @ matrices['down'].T) * (1 / (1 + np.exp(-(x @ w))))[:, None]
    contributions = scores[:, :, None] * routed
    original = contributions.sum(axis=1) + shared
    denominators = np.sum(original * original, axis=1)
    s2 = np.sum(shared * shared, axis=1)
    dot = np.sum(contributions * shared[:, None, :], axis=2)
    v2 = np.sum(contributions * contributions, axis=2)
    omitted = np.sqrt(v2 / denominators[:, None])
    free_alpha = np.divide(dot, s2[:, None], out=np.zeros_like(dot), where=s2[:, None] > 0)
    # Existing shared coefficient is one; nonnegative adjusted coefficient means delta >= -1.
    viable_alpha = np.maximum(-1, free_alpha)
    def errors(alpha):
        squared = np.maximum(0, v2 - 2*alpha*dot + alpha*alpha*s2[:, None])
        return np.sqrt(squared / denominators[:, None])
    unconstrained = errors(free_alpha)
    nonnegative = errors(viable_alpha)
    # Re-evaluate selected minimum residuals by vector subtraction, avoiding cancellation in the quadratic.
    best = np.argmin(unconstrained, axis=1)
    rows = np.arange(n)
    actual = np.linalg.norm(contributions[rows, best] - free_alpha[rows, best, None]*shared, axis=1) / np.sqrt(denominators)
    assert np.max(abs(actual - unconstrained[rows, best])) < 1e-8
    def stats(err):
        selected = np.argmin(err, axis=1)
        minima = err[rows, selected]
        return dict(best_mean=float(np.mean(minima)), best_median=float(np.median(minima)),
                    best_min=float(np.min(minima)), best_max=float(np.max(minima)),
                    below_001=int((minima <= .01).sum()), below_005=int((minima <= .05).sum()),
                    below_010=int((minima <= .10).sum()),
                    aggregate_rms=float(np.sqrt(np.sum(minima**2 * denominators) / np.sum(denominators))),
                    selected_ids=[int(ids[i, selected[i]]) for i in rows])
    cosine = np.divide(dot, np.sqrt(v2 * s2[:, None]), out=np.zeros_like(dot), where=(v2*s2[:,None]) > 0)
    result = dict(n=n, omission=stats(omitted), free_signed_shared_gain=stats(unconstrained),
                  nonnegative_shared_gain=stats(nonnegative),
                  selected_omission_cosine_median=float(np.median(np.abs(cosine[rows, np.argmin(omitted, axis=1)]))),
                  all_candidate_abs_cosine_max=float(np.max(np.abs(cosine))),
                  shared_norm_to_complete_median=float(np.median(np.sqrt(s2 / denominators))),
                  free_gain_selected=[float(free_alpha[i,best[i]]) for i in rows],
                  shared_norm_to_complete=[float(v) for v in np.sqrt(s2 / denominators)],
                  input_files={p:h for p,h in [(xp,xh),(sp,sh),(rp,rh),(ip,ih)]})
    return result


def main():
    matrices, gate, libpath, libsha, inventorysha = shared_weights()
    result = dict(contract='Layer-0 actual Qwen GGUF routed score-weighted vectors plus offline decoded Q8 shared branch; free hindsight scalar adjustment of existing shared output when one routed contribution is omitted; real FP64 reconstruction, not native FP32 bits or complete-model quality',
                  model_sha256=sha(MODEL), inventory_sha256=inventorysha,
                  decoder_library=libpath, decoder_sha256=libsha,
                  script_sha256=sha(Path(__file__)),
                  train=summarize('train', matrices, gate), held=summarize('held', matrices, gate))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    for split in ('train', 'held'):
        r = result[split]
        print(split, {k:{a:b for a,b in v.items() if a not in ('selected_ids',)} for k,v in r.items() if k in ('omission','free_signed_shared_gain','nonnegative_shared_gain')})
    print('receipt', OUT, sha(OUT))


if __name__ == '__main__':
    main()
