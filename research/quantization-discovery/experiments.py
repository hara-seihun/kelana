#!/usr/bin/env python3
"""Sub-minute, deterministic experiments for the quantization search theorems."""
import argparse
import copy
import hashlib
import itertools
import json
from pathlib import Path
import struct
import time
from search import Problem, search, seed, exact_dp, exhaustive, progression_distance
from check_certificate import check
from codec import encode, decode

HERE = Path(__file__).resolve().parent


def opt(label, response, bits, ops=0, **extras):
    return dict(label=label, response=list(response), bits=bits, ops=ops, **extras)


def family(n, name):
    if name == 'collision':
        options = [opt('zero', [0, 0], 1), opt('one', [1, 1], 1)]
        target, price = [n//2]*2, 1
    elif name == 'paid-dominance':
        options = [opt('zero', [0], 1), opt('two', [2], 6)]
        target, price = [2*n], 2
    elif name == 'suffix-endpoints':
        options = [opt('zero', [0], 1), opt('one', [1], 1)]
        target, price = [2*n], 1
    elif name == 'residue':
        options = [opt('zero', [0], 1), opt('two', [2], 1)]
        target, price = [n+1], 1
    else:
        raise ValueError(name)
    return dict(name=f'{name}-{n}', blocks=[options for _ in range(n)], target=target,
                error_price=price, static_bits=0)


def checks():
    progression_cases = 0
    for step in range(1, 7):
        for base in range(-3, 4):
            for lo in range(-6, 3):
                for hi in range(lo, 7):
                    values = [v for v in range(lo, hi+1) if (v-base) % step == 0]
                    if not values:
                        continue
                    for target in range(-9, 10):
                        assert progression_distance(target, lo, hi, base, step) == min(abs(target-v) for v in values)
                        progression_cases += 1
    codec_cases = 0
    for pattern in itertools.product((-1, 0, 1), repeat=8):
        wire, length = encode([list(pattern)], 1.0)
        blocks, scale, consumed = decode(wire, 1)
        assert blocks == [list(pattern)] and scale == 1.0 and consumed == length
        codec_cases += 1
    oracle_cases = endpoint_prunes = 0
    for index in range(12):
        blocks = []
        for i in range(6):
            block = [opt(str(k), [((i+2)*(k+1)+index)%7-3,
                                  ((i+1)*(k+2)+2*index)%5-2],
                         1+(i+2*k+index)%4) for k in range(3)]
            blocks.append(block)
        p = Problem(dict(blocks=blocks, target=[index%5-2, index%3-1], error_price=1+index%3))
        if index >= 6:
            p = Problem(dict(blocks=[[dict(o, response=o['response'][:1]) for o in b]
                                     for b in blocks], target=[index%5-2], error_price=1+index%3))
        truth = exhaustive(p)
        assert exact_dp(p)['optimum'] == truth
        assert exact_dp(p, metric=True)['optimum'] == truth
        assert exact_dp(p, metric=True, endpoints=True)['optimum'] == truth
        for residues, dominance in itertools.product([False, True], repeat=2):
            for budget in [0, 3, 31, 1000]:
                r = search(p, budget, 3, residues=residues, dominance=dominance, certificate=True)
                assert check(p, r)['valid']
                assert r['lower'] <= truth <= r['upper'], (index, truth, r)
                if r['stop'] == 'optimal':
                    assert r['lower'] == truth == r['upper']
                oracle_cases += 1
                endpoint_prunes += r['endpoint_prunes']
    corrupt = copy.deepcopy(r)
    corrupt['lower'] = truth+1
    try:
        check(p, corrupt)
    except ValueError:
        pass
    else:
        raise AssertionError('checker accepted false optimum')
    endpoint_blocks = [
        [(-17, 1), (14, 7), (19, 2)], [(-4, 2), (-6, 2), (-1, 6)],
        [(7, 3), (-17, 9), (9, 1)], [(18, 2), (5, 4), (-4, 6)],
        [(10, 3), (-7, 1), (-10, 3)], [(1, 9), (-4, 2), (18, 8)],
        [(-9, 1), (10, 7), (16, 9)], [(-1, 6), (4, 5), (-11, 9)],
    ]
    p = Problem(dict(blocks=[[opt(str(k), [value], cost) for k, (value, cost) in enumerate(b)]
                             for b in endpoint_blocks], target=[38], error_price=2))
    r = search(p, 256, 3, residues=False, dual=False, certificate=True)
    assert r['endpoint_prunes'] > 0 and check(p, r)['valid']
    assert r['lower'] <= exhaustive(p) <= r['upper']
    endpoint_prunes += r['endpoint_prunes']
    oracle_cases += 1
    return dict(progression_cases=progression_cases, search_intervals_against_exhaustive=oracle_cases,
                certificates_replayed=oracle_cases, endpoint_prunes_replayed=endpoint_prunes,
                corrupted_floor_rejected=True,
                codec_patterns_roundtripped=codec_cases)


def capture_bonsai():
    """Extract one scaled block's integer subproblem, not a whole FFN claim."""
    base = Path('/path/to/workspace/data/kelana-ffn/ptq1_0/layer00')
    weights_path = Path('/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00/down.halo')
    input_path = base/'r8/xq_ff.i8'
    with weights_path.open('rb') as f:
        tile = f.read(896)
    qs = tile[:16]+tile[512:520]
    tail = tile[768:772]
    w = [None]*128
    def peel(byte, count):
        values = []
        for _ in range(count):
            byte *= 3
            values.append((byte >> 8)-1)
            byte &= 255
        return values
    for d in range(6):
        for j in range(4):
            t = peel(qs[4*d+j], 5)
            p, half = 2*d+(j&1), j>>1
            for position, value in zip([8*p+2*half, 8*p+2*half+1,
                                        8*p+4+2*half, 8*p+4+2*half+1, 96+4*d+j], t):
                w[position] = value
    for h in range(2):
        for position, value in zip([120+2*h, 121+2*h, 124+2*h, 125+2*h], peel(tail[h], 4)):
            w[position] = value
    raw = input_path.read_bytes()
    inputs = [list(struct.unpack('128b', raw[r*17408:r*17408+128])) for r in range(8)]
    assert all(x in (-1, 0, 1) for x in w)
    blocks = []
    for start in range(0, 128, 8):
        patterns = [('zero', [0]*8, 1, 0), ('repeat-', [-1]*8, 3, 2),
                    ('repeat+', [1]*8, 3, 2),
                    ('alternating-', [-1, 1]*4, 4, 3),
                    ('alternating+', [1, -1]*4, 4, 3),
                    ('literal', w[start:start+8], 16, 8)]
        options = []
        for label, pattern, bits, ops in patterns:
            responses = [sum(a*b for a, b in zip(pattern, x[start:start+8])) for x in inputs]
            options.append(opt(label, responses[:3], bits, ops,
                               heldout_response=responses[3:], trits=pattern))
        blocks.append(options)
    target = [sum(a*b for a, b in zip(w, x)) for x in inputs]
    return dict(name='bonsai-layer00-down-row0-block0',
                scope='128 trits of one real down-projection row; three captured integer input observations; five held-out observations. Not full-model quality.',
                blocks=blocks, target=target[:3], heldout_target=target[3:], error_price=1,
                operation_price=0, static_bits=16,
                codec='prefix modes 0=zero; 10s=repeat; 110s=alternating; 111 + 13-bit base3 payload=literal eight trits. Fixed shared decoder, no learned dictionary. Includes one FP16 weight scale.',
                operations='Declared arithmetic-unit charges 0/2/3/8 for zero/repeat/alternating/literal, not GPU cycles.',
                input_provenance=dict(weights=str(weights_path), weight_tile_offset=0,
                    weight_tile_sha256=hashlib.sha256(tile).hexdigest(), captured_inputs=str(input_path),
                    captured_inputs_sha256=hashlib.sha256(raw).hexdigest(),
                    common_weight_scale=struct.unpack('<e', tail[2:])[0]),
                source_trits=w, captured_integer_inputs=inputs)


def heldout(record, result):
    values = [0]*len(record['heldout_target'])
    for block, k in zip(record['blocks'], result['witness']['path']):
        values = [a+b for a, b in zip(values, block[k]['heldout_response'])]
    errors = [a-b for a, b in zip(values, record['heldout_target'])]
    return dict(response=values, error=errors, max_abs=max(map(abs, errors)))


def robust_box(record, radius=127):
    """Globally optimal in this additive codec family on the ENTIRE input box.

BoxQuantization.robust_value and independent_minima justify the reduction.
The fixed shared decoder uses source-independent modes; literals carry trits.
"""
    source = record['source_trits']
    chosen = []
    option_scores = []
    for i, block in enumerate(record['blocks']):
        errors = [sum(abs(a-b) for a, b in zip(o['trits'], source[8*i:8*i+8]))
                  for o in block]
        scores = [o['bits'] + record['operation_price']*o['ops'] +
                  record['error_price']*radius*e for o, e in zip(block, errors)]
        chosen.append(min(range(len(block)), key=lambda k: scores[k]))
        option_scores.append(scores)
    p = Problem(record)
    robust = p.evaluate(chosen)
    robust['robust_objective'] = record['static_bits']+sum(min(s) for s in option_scores)
    sampled, _ = seed(p)
    represented = [w for b, k in zip(record['blocks'], sampled['path']) for w in b[k]['trits']]
    error = [a-b for a, b in zip(represented, source)]
    adversarial = [radius if e > 0 else -radius if e < 0 else 0 for e in error]
    exact = sum(e*x for e, x in zip(error, adversarial))
    assert exact == radius*sum(map(abs, error))
    return dict(radius=radius, input_domain_cardinality=f'{2*radius+1}^128',
                evaluated_options=sum(map(len, record['blocks'])), optimum=robust,
                original_halo_bits=224,
                sampled_candidate_bits=sampled['bits'], sampled_candidate_error=sampled['error'],
                sampled_candidate_exact_box_error=exact, adversarial_input=adversarial)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, default=HERE/'results.json')
    ap.add_argument('--capture', action='store_true')
    args = ap.parse_args()
    start = time.perf_counter()
    checked = checks()
    results = dict(format='kelana-quantization-discovery/1', checks=checked, families={})
    p = Problem(family(160, 'collision'))
    results['families']['collision'] = dict(choices='2^160', exact=exact_dp(p))
    p = Problem(family(160, 'paid-dominance'))
    results['families']['paid-dominance'] = dict(choices='2^160', exact=exact_dp(p),
                                               cost_funded=exact_dp(p, metric=True))
    p = Problem(family(160, 'suffix-endpoints'))
    results['families']['suffix-endpoints'] = dict(choices='2^160',
        metric=exact_dp(p, metric=True), exact_suffix=exact_dp(p, metric=True, endpoints=True))
    p = Problem(family(64, 'residue'))
    results['families']['residue'] = dict(interval=search(p, 10000, 3, residues=False, dual=False, endpoints=False),
                                          lattice=search(p, 10000, 3, residues=True, dual=False, endpoints=False))
    path = HERE/'instances/bonsai-layer00-block0.json'
    if args.capture:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(capture_bonsai(), indent=2)+'\n')
    record = json.loads(path.read_text())
    p = Problem(record)
    results['bonsai'] = []
    for budget in [0, 32, 256, 2048]:
        r = search(p, budget, 4, certificate=True)
        r['certificate_check'] = check(p, r)
        if budget == 2048:
            (HERE/'certificate-bonsai.json').write_text(json.dumps(r, separators=(',', ':'))+'\n')
        del r['certificate']
        r['heldout'] = heldout(record, r)
        results['bonsai'].append(r)
    results['bonsai_no_dual'] = search(p, 2048, 4, dual=False)
    full = copy.deepcopy(record)
    full['target'] += full['heldout_target']
    for block in full['blocks']:
        for o in block:
            o['response'] += o['heldout_response']
    results['bonsai_all_eight_observations'] = search(Problem(full), 256, 4)
    results['robust_box'] = robust_box(record)
    witness = results['bonsai'][-1]['witness']
    patterns = [b[k]['trits'] for b, k in zip(record['blocks'], witness['path'])]
    wire, length = encode(patterns, record['input_provenance']['common_weight_scale'])
    decoded, scale, consumed = decode(wire, len(patterns))
    assert decoded == patterns and length == consumed == witness['bits']
    results['codec_witness'] = dict(hex=wire.hex(), meaningful_bits=length,
                                    stored_bytes=len(wire), decoded_scale=scale,
                                    meaningful_bpw=length/128, byte_padded_bpw=len(wire)*8/128)
    results['elapsed_seconds'] = time.perf_counter()-start
    results['sources'] = {f.name: hashlib.sha256(f.read_bytes()).hexdigest()
                          for f in [HERE/'search.py', HERE/'check_certificate.py', HERE/'codec.py', Path(__file__), path]}
    args.out.write_text(json.dumps(results, indent=2)+'\n')
    print(json.dumps(dict(checks=checked, elapsed=results['elapsed_seconds'],
                         families=results['families'],
                         bonsai=[{k: r[k] for k in ['lower', 'upper', 'gap', 'expanded', 'elapsed_seconds', 'heldout']}
                                 for r in results['bonsai']]), indent=2))


if __name__ == '__main__':
    main()
