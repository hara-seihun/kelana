"""Exact systematic within-G32 rounding risk from pinned independent-law mean receipts."""
import importlib.util
import json
import sys
import math
from pathlib import Path

import numpy as np
import torch
from threadpoolctl import threadpool_limits

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
INDEPENDENT = ROOT / 'kivi-value-rounding-risk'
sys.path.insert(0, str(ROOT / 'contextual-value-sharing'))
import screen as producer_screen
sys.path.insert(0, str(INDEPENDENT))
spec = importlib.util.spec_from_file_location('independent_rounding_screen', INDEPENDENT / 'screen.py')
independent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(independent)
bf16, checked, events, get_input, level_law, sha, unpack_records = (getattr(independent, name) for name in ('bf16','checked','events','get_input','level_law','sha','unpack_records'))


def probabilities(src, records):
    n = len(records)
    raw = np.frombuffer(b''.join(records), dtype='u1').reshape(n, 48)
    fields = np.frombuffer(raw[:, 32:].copy().tobytes(), dtype='<f2').astype('<f4').reshape(n, 4, 2)
    lo = np.repeat(fields[:, :, 0], 32, axis=1)
    step = np.repeat(fields[:, :, 1], 32, axis=1)
    levels = np.stack([np.add(lo, np.multiply(step, np.float32(j), dtype=np.float32), dtype=np.float32).astype(np.float64) for j in range(4)], axis=-1)
    v = bf16(src[:n]).astype(np.float64)
    low = np.zeros((n, 128), dtype=np.intp)
    high = np.zeros_like(low)
    for j in range(1, 4):
        interior = (v > levels[:, :, j - 1]) & (v < levels[:, :, j])
        low[interior] = j - 1
        high[interior] = j
    above = v > levels[:, :, 3]
    low[above] = 3
    high[above] = 3
    for j in range(3, -1, -1):
        equal = v == levels[:, :, j]
        low[equal] = j
        high[equal] = j
    row = np.arange(n)[:, None]
    col = np.arange(128)[None, :]
    a, b = levels[row, col, low], levels[row, col, high]
    width = b - a
    p = np.zeros_like(v)
    interior = width > 0
    p[interior] = (v[interior] - a[interior]) / width[interior]
    assert np.all((0 <= p) & (p <= 1))
    return p.reshape(n, 4, 32), width.reshape(n, 4, 32), a + p * width, p * (1 - p) * width**2


def overlap_covariance(p):
    # Z_j = 1 on the circular arc [(-S_{j+1}) mod 1, (-S_{j+1}) mod 1 + f_j).
    # Its two nonwrapping pieces are intersected independently, without sampling U.
    s = np.cumsum(p, axis=1, dtype=np.float64)
    before = np.concatenate((np.zeros_like(s[:, :1]), s[:, :-1]), axis=1)
    start = np.mod(-s, 1.)
    end = start + p
    first_end = np.minimum(end, 1.)
    second_end = np.maximum(end - 1., 0.)
    a = start[:, :, None]
    b = start[:, None, :]
    overlap = np.maximum(0., np.minimum(first_end[:, :, None], first_end[:, None, :]) - np.maximum(a, b))
    overlap += np.maximum(0., np.minimum(second_end[:, :, None], second_end[:, None, :]))
    overlap += np.maximum(0., np.minimum(first_end[:, :, None], second_end[:, None, :]) - a)
    overlap += np.maximum(0., np.minimum(second_end[:, :, None], first_end[:, None, :]) - b)
    covariance = overlap - p[:, :, None] * p[:, None, :]
    return covariance, s, before


def support_check(p, width, gram, covariance, s, before):
    thresholds = np.unique(np.concatenate(([0., 1.], np.mod(-s, 1.), np.mod(-before, 1.))))
    lengths = np.diff(thresholds)
    u = (thresholds[:-1] + thresholds[1:]) / 2
    z = np.floor(s[:, None] + u).astype(np.float64) - np.floor(before[:, None] + u).astype(np.float64)
    assert np.all((z == 0) | (z == 1))
    marginal = z @ lengths
    centered = z - marginal[:, None]
    support_cov = (centered * lengths) @ centered.T
    assert np.max(np.abs(marginal - p)) < 2e-13
    assert np.max(np.abs(support_cov - covariance)) < 3e-13
    assert np.max(np.abs(np.sum(z, axis=0) - np.sum(p))) < 1 + 1e-10
    # Support vectors give a constructive PSD witness for every output covariance.
    projection = gram @ (width[:, None] * centered)
    risk = np.sum(lengths * np.sum(projection**2, axis=0))
    contraction = np.einsum('ij,ij->', covariance * width[:, None] * width[None, :], gram.T @ gram)
    assert abs(risk - contraction) < 1e-10 * max(1, risk)
    return float(abs(risk - contraction)), len(lengths), float(np.max(np.abs(marginal - p)))


def run(panel, window):
    name = f'{panel}-{window}'
    pinned = json.loads((INDEPENDENT / f'{name}-result.json').read_text())
    torch.set_num_threads(1)
    with threadpool_limits(1):
        arrays, queries, obits, donor, donor_sha, source_sha, _, _ = get_input(panel, window)
        assert (pinned['source_sha256'], pinned['donor_manifest_sha256'], pinned['original_o_sha256']) == (source_sha, donor_sha, sha(obits.tobytes()))
        o = bf16(obits).astype(np.float64).reshape(1024, 16, 128)
        # c00/c01/c11 per aged token, per shared KV head; a group is one fresh U.
        contractions = np.zeros((8, 224, 3), dtype=np.float64)
        checks = []
        keys = []
        for h in range(8):
            receipt = pinned['chronology'][h]
            path = (ROOT / 'kivi-two-bit-causal' / f'{name}-head{h}-events.bin') if panel == 'held' else (ROOT / 'contextual-value-feedback' / f'{name}-original-h{h}-events.bin')
            log = events(checked(path, receipt['event_sha256']))
            vs = [(t, b) for kind, t, b in log if kind == 'V']
            ks = [(t, b) for kind, t, b in log if kind == 'K']
            assert [t for t, _ in ks] == list(range(32, 257, 32))
            assert [t for t, _ in vs] == list(range(33, 257))
            keys.append((unpack_records([b for _, b in ks], 2, True).astype(np.float32), bf16(arrays['k'][:, h])))
            records = [b for _, b in vs]
            assert sha(b''.join(b[32:] for b in records)) == receipt['stored_v_fields_sha256']
            assert sha(arrays['v'][:, h].tobytes()) == receipt['source_v_sha256']
            p, width, means, variance = probabilities(arrays['v'][:, h], records)
            old_mean, old_variance, _, old_stat = level_law(arrays['v'][:, h], records)
            assert np.array_equal(means, old_mean) and np.array_equal(variance, old_variance)
            assert old_stat == pinned['law_statistics'][h]
            for g in range(4):
                pg = p[:, g, :]
                wg = width[:, g, :]
                cov, sums, before = overlap_covariance(pg)
                diag_error = float(np.max(np.abs(np.diagonal(cov, axis1=1, axis2=2) - pg * (1 - pg))))
                symmetry_error = float(np.max(np.abs(cov - cov.transpose(0, 2, 1))))
                assert diag_error < 2e-14 and symmetry_error < 2e-14
                cols0, cols1 = o[:, 2*h, g*32:(g+1)*32], o[:, 2*h+1, g*32:(g+1)*32]
                for k, (left, right) in enumerate(((cols0, cols0), (cols0, cols1), (cols1, cols1))):
                    gram = left.T @ right
                    contractions[h, :, k] += np.einsum('nij,ni,nj,ij->n', cov, wg, wg, gram, optimize=True)
                if h == 0 and g == 0:
                    # Two independent formulations on bounded records, across all windows.
                    for index in (0, 111, 223):
                        delta, outcomes, marg_error = support_check(pg[index], wg[index], cols0, cov[index], sums[index], before[index])
                        checks.append({'token':index + 33,'group':g,'head':h,'support_intervals':outcomes,'marginal_max_abs':marg_error,'projection_contraction_abs':delta})
                checks.append({'head':h,'group':g,'records':224,'diagonal_max_abs':diag_error,'symmetry_max_abs':symmetry_error,'psd_witness':'nonnegative interval support weights; covariance = sum weight * centered indicators outer product'})
        rows = []
        for old in pinned['rows']:
            t = old['t']
            n = old['aged_tokens']
            q, _ = queries[t]
            nkey = (t-1)//32*32
            key_array = np.stack([np.concatenate((quant[:nkey], recent[nkey:t])) for quant, recent in keys])
            qt = torch.from_numpy(np.array(q, copy=True))
            kt = torch.from_numpy(np.ascontiguousarray(key_array))
            prob = torch.bmm(qt[:, None, :], kt[torch.arange(16)//2].transpose(1, 2)).squeeze(1).div(math.sqrt(128)).softmax(-1).numpy().astype(np.float64)
            variance = 0.
            for h in range(8):
                a, b = prob[2*h, :n], prob[2*h+1, :n]
                c = contractions[h, :n]
                variance += float(np.sum(a*a*c[:, 0] + 2*a*b*c[:, 1] + b*b*c[:, 2]))
            assert variance >= -1e-11
            expected = old['mean_bias_sse'] + variance
            rows.append({'t':t,'aged_tokens':n,'mean_bias_sse':old['mean_bias_sse'],'deterministic_fp64_sse':old['deterministic_fp64_sse'],'original_cpu_sse':old['original_cpu_sse'],'teacher_sq':old['teacher_sq'],'variance_trace':variance,'expected_sse':expected})
        result = {'panel':panel,'window':window,'source_sha256':source_sha,'donor_manifest_sha256':donor_sha,'independent_receipt_sha256':sha((INDEPENDENT / f'{name}-result.json').read_bytes()),'checks':checks,'rows':rows}
        (HERE / f'{name}-result.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
        print(json.dumps({'name':name,'queries':len(rows),'variance':sum(x['variance_trace'] for x in rows),'expected':sum(x['expected_sse'] for x in rows)}),flush=True)
        return result


if __name__ == '__main__':
    run(sys.argv[1], int(sys.argv[2]))
