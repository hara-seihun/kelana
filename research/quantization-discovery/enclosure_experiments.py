#!/usr/bin/env python3
"""Replay source-aware local producer envelopes and a guarded exact assignment."""
import hashlib
import itertools
import json
from fractions import Fraction
from pathlib import Path
import time
import numpy as np
from fp_enclosure import Interval, Affine, scale_domain, project, silu, hadamard, quantize, up, sum_up
from producer_search import Choice, Assignment, frontier_dp
from codec import encode, decode

HERE = Path(__file__).resolve().parent
FIXTURE = HERE/'instances/bonsai-layer00-producer-chunk0.npz'


def primitive_checks():
    values = [np.ldexp(float(k), power) for power in (-130, -60, -2, 0, 30, 90) for k in (-7, -1, 1, 3)]
    checked = 0
    for a, b in itertools.product(values, repeat=2):
        ia, ib = Interval.point(a), Interval.point(b)
        qa, qb = Fraction.from_float(a), Fraction.from_float(b)
        for interval, exact in ((ia+ib, qa+qb), (ia-ib, qa-qb), (ia*ib, qa*qb)):
            assert Fraction.from_float(float(interval.lo)) <= exact <= Fraction.from_float(float(interval.hi))
            checked += 1
        if b > 0:
            interval, exact = ia/ib, qa/qb
            assert Fraction.from_float(float(interval.lo)) <= exact <= Fraction.from_float(float(interval.hi))
            checked += 1
    radii = np.array([2., 1., 3.])
    a = Affine(np.array([2., -1.]), np.array([[1., -2., 3.], [0., 1., -2.]]), np.array([1., 2.]), radii)
    b = Affine(np.array([-3., 2.]), np.array([[2., 1., -1.], [-2., 1., 1.]]), np.array([2., 1.]), radii)
    product = a.multiply(b)
    corners = 0
    for latent in itertools.product((-2., 0., 2.), (-1., 0., 1.), (-3., 0., 3.)):
        box = product.at(np.array(latent))
        for left, right in itertools.product((-1., 1.), repeat=2):
            exact = (a.center+a.generators@latent+left*a.residual)*(b.center+b.generators@latent+right*b.residual)
            assert np.all((box.lo <= exact) & (exact <= box.hi))
            corners += 1
    return dict(exact_fraction_interval_checks=checked, affine_product_cases=corners)


def enclose(data, row, radius):
    assert np.all(np.isin(data['signs'], (-1., 1.)))
    assert np.all(np.abs(data['q'][row].astype(np.int16)) <= 127)
    assert np.array_equal(data['q'][row].astype(np.int32).sum(axis=-1), data['input_sums'][row])
    domain = scale_domain(data['input_scales'][row], radius)
    gate = project(data['gate_dot'][row], data['gate_scales'], domain)
    upper = project(data['up_dot'][row], data['up_scales'], domain)
    for name, affine in (('gate', gate), ('up', upper)):
        interval = affine.at(domain['captured_latent'])
        observed = data[name+'_observed'][row]
        assert np.all((interval.lo <= observed) & (observed <= interval.hi)), name
    product = silu(gate).multiply(upper).source_round().scale(data['signs'])
    transformed = hadamard(product)
    output = quantize(transformed)
    codes = data['hidden_codes'][row].reshape(8, 128).astype(np.int32)
    assert np.all((output['codes_lo'] <= codes) & (codes <= output['codes_hi']))
    assert np.all((output['xsum_lo'] <= data['hidden_sums'][row]) & (data['hidden_sums'][row] <= output['xsum_hi']))
    scales = data['hidden_scales'][row]
    assert np.all((output['scale_lo'] <= scales) & (scales <= output['scale_hi']))
    actual = (codes*scales[:, None].astype(np.float64)).ravel()
    interval = output['dequantized'].at(domain['captured_latent'])
    assert np.all((interval.lo <= actual) & (actual <= interval.hi))
    return domain, output


def first_block(affine):
    return Affine(affine.center[:128], affine.generators[:128], affine.residual[:128], affine.radii)


def independent_support(affine, error):
    center = Interval.point(0.)
    for c, e in zip(affine.center, error):
        center = center+Interval.point(c)*Interval.point(e)
    return float(up(center.absmax()+sum_up(up(np.abs(error)*affine.total_radius()))))


def exact_local_assignment(fixture, fixed_codes):
    weights = np.array(fixture['source_trits'], dtype=np.int32)
    blocks = []
    for i, menu in enumerate(fixture['blocks']):
        block = []
        for option in menu:
            error = np.array(option['trits'], dtype=np.int32)-weights[8*i:8*i+8]
            block.append(Choice(option['label'], option['bits'], (int(error@fixed_codes[8*i:8*i+8]),)))
        blocks.append(tuple(block))
    # Every literal is feasible with zero error for 272 bits. Any nonzero
    # integer error costs >=1000, so the exact minimum must have error zero.
    problem = Assignment(tuple(blocks), 16, 1000)
    result = frontier_dp(problem, max_states=30000)
    assert result['status'] == 'optimal' and result['objective_numerator'] < 1000
    selected = [fixture['blocks'][i][k] for i, k in enumerate(result['path'])]
    values = sum((o['trits'] for o in selected), [])
    assert int((np.array(values)-weights)@fixed_codes) == 0
    weight_scale = fixture['input_provenance']['common_weight_scale']
    wire, bits = encode([o['trits'] for o in selected], weight_scale)
    decoded, scale, consumed = decode(wire, 16)
    assert sum(decoded, []) == values and scale == weight_scale and consumed == bits
    assert bits == result['objective_numerator']
    return dict(solver=result, bits=bits, padded_bits=8*len(wire), wire_hex=wire.hex(),
                source_bits=224, source_trits=weights.tolist(), replacement_trits=values,
                fixed_hidden_codes=fixed_codes.tolist(), block_weight_scale=weight_scale,
                integer_dot_error=0,
                boundary='Same int32 dot result and same FP16 weight scale; existing outer down-projection arithmetic unchanged.')


def main():
    started = time.monotonic()
    tests = primitive_checks()
    data = np.load(FIXTURE)
    fixture = json.loads((HERE/'instances/bonsai-layer00-block0.json').read_text())
    previous = json.loads((HERE/'certificate-bonsai.json').read_text())['witness']['path']
    previous_weights = sum((fixture['blocks'][i][k]['trits'] for i, k in enumerate(previous)), [])
    error = np.array(previous_weights)-fixture['source_trits']
    panels = []
    local = None
    for radius in (0., 1e-6, 1e-3):
        for row in range(8):
            domain, output = enclose(data, row, radius)
            affine = first_block(output['dequantized'])
            same = output['codes_lo'] == output['codes_hi']
            panel = dict(row=row, relative_scale_radius=radius,
                         fixed_codes=int(same.sum()), fixed_first_block=int(same[0].sum()),
                         mean_code_interval_width=float((output['codes_hi']-output['codes_lo']).mean()),
                         previous_candidate_affine_error=affine.support(error),
                         previous_candidate_independent_error=independent_support(affine, error),
                         gate_up_capture_contained=True, hidden_capture_contained=True,
                         scale_capture_contained=True, code_sum_capture_contained=True,
                         dequantized_capture_contained=True)
            panels.append(panel)
            if row == 0 and radius == 1e-6:
                assert np.all(same[0]), 'selected local cell not certified'
                fixed_codes = output['codes_lo'][0]
                assert np.array_equal(fixed_codes, data['hidden_codes'][0, :128])
                local = exact_local_assignment(fixture, fixed_codes)
                lo_bits = domain['lo'].astype(np.float32).view(np.uint32)
                hi_bits = domain['hi'].astype(np.float32).view(np.uint32)
                counts = [int(h)-int(l)+1 for l, h in zip(lo_bits, hi_bits)]
                number = 1
                for count in counts:
                    number *= count
                local.update(literal_guard_bytes=5120+2*40*4, packet_plus_literal_guard_bytes=5120+2*40*4+local['padded_bits']//8,
                             input_scale_lo_bits=lo_bits.tolist(), input_scale_hi_bits=hi_bits.tolist(),
                             scale_values_per_block=counts, scale_tuples=number,
                             upstream_codes_sha256=hashlib.sha256(data['q'][0].tobytes()).hexdigest(),
                             relative_scale_radius=radius, source_row=0,
                             source_scope='Fixed 5120 upstream int8 codes; each of 40 source FP32 scales in its explicit bit interval.')
    assert local is not None
    files = ['fp_enclosure.py', 'enclosure_experiments.py', 'enclosure_fixture.py',
             'producer_search.py', 'codec.py', 'FLOAT-CONTRACT.md', 'check_enclosure.py',
             'instances/bonsai-layer00-producer-chunk0.json', 'instances/bonsai-layer00-block0.json']
    results = dict(checks=tests, fixture_sha256=hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
                   source_sha256={name: hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in files},
                   panels=panels, local_replacement=local, elapsed_seconds=time.monotonic()-started,
                   scope='Conditional producer enclosure; fixed upstream codes and bounded scales. No global model or quality claim.')
    (HERE/'enclosure-results.json').write_text(json.dumps(results, indent=2)+'\n')
    print(json.dumps(dict(checks=tests, rows0=[p for p in panels if p['row'] == 0],
                         replacement={k: v for k, v in local.items() if k in ('bits','padded_bits','wire_hex','scale_tuples','integer_dot_error')},
                         elapsed_seconds=results['elapsed_seconds']), indent=2))


if __name__ == '__main__':
    main()
