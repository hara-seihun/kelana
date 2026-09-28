#!/usr/bin/env python3
"""Sub-minute exact-domain experiments; no GPU or inference service changes."""
import hashlib
import itertools
import json
from pathlib import Path
import time
from producer_search import Domain, Choice, Assignment, compile_domain, frontier_dp, exhaustive, coordinate_search, dot, replay_dual
from codec import encode, decode

HERE = Path(__file__).resolve().parent


def hadamard(values):
    out = list(values)
    step = 1
    while step < len(out):
        for start in range(0, len(out), 2*step):
            for j in range(start, start+step):
                a, b = out[j], out[j+step]
                out[j], out[j+step] = a+b, a-b
        step *= 2
    return out


def checks():
    support_cases = 0
    for k in range(12):
        d = Domain(tuple((i+k)%3-1 for i in range(4)),
                   tuple(tuple((i*j+k)%5-2 for i in range(4)) for j in range(3)), (1, 0, 2, 1))
        e = tuple((i*3+k)%7-3 for i in range(4))
        generators = d.generators + tuple(tuple(d.residual[i] if j == i else 0 for j in range(4))
                                          for i in range(4))
        truth = max(abs(dot(e, tuple(d.center[i]+sum(z*g[i] for z, g in zip(signs, generators))
                                     for i in range(4))))
                    for signs in itertools.product((-1, 1), repeat=len(generators)))
        assert d.support(e) == truth
        assert abs(dot(e, d.witness(e)['numerator'])) == truth
        support_cases += 1
    for k in range(24):
        blocks = []
        for i in range(6):
            choices = []
            for a in range(3):
                factors = tuple(((i+2*a+k)*(j+1))%7-3 if k%2 or j in (i, i+1) else 0
                                for j in range(7))
                choices.append(Choice(str(a), (i+a+k)%5, factors))
            blocks.append(tuple(choices))
        p = Assignment(tuple(blocks), k%3, k%4)
        r = frontier_dp(p)
        truth = exhaustive(p)
        assert r['status'] == 'optimal' and r['objective_numerator'] == truth
        probes = tuple((j+k)%7-3 for j in range(7))
        assert replay_dual(p, 3, probes)['lower_numerator'] <= truth
    try:
        replay_dual(p, 3, (4,)*7)
    except AssertionError:
        pass
    else:
        raise AssertionError('out-of-range dual accepted')
    return dict(support_corner_oracles=support_cases, frontier_dp_exhaustive_oracles=24,
                dual_exhaustive_oracles=24, malformed_dual_rejected=True)


def chain(n):
    # x_i = z_i-z_(i+1); the objective prices total variation of weight error.
    blocks = []
    for i in range(n):
        block = []
        for q, cost in ((0, 1), (1, 3)):
            error = q-(i//3+i//7)%2
            block.append(Choice(str(q), cost, tuple(error if j == i else -error if j == i+1 else 0
                                                    for j in range(n+1))))
        blocks.append(tuple(block))
    return Assignment(tuple(blocks), 0, 2)


def menus_for(weights):
    menus = []
    for start in range(0, len(weights), 8):
        menus.append([
            ('zero', [0]*8, 1), ('repeat-', [-1]*8, 3), ('repeat+', [1]*8, 3),
            ('alternating-', [-1, 1]*4, 4), ('alternating+', [1, -1]*4, 4),
            ('literal', weights[start:start+8], 16)])
    return menus


def candidate(weights, menus, domain, result, weight_scale=1.0):
    selected = [block[k] for block, k in zip(menus, result['path'])]
    values = sum((list(o[1]) for o in selected), [])
    error = [q-w for q, w in zip(values, weights)]
    bits = 16+sum(o[2] for o in selected)
    wire, meaningful_bits = encode([list(o[1]) for o in selected], weight_scale)
    decoded, scale, consumed = decode(wire, len(selected))
    assert meaningful_bits == bits == consumed and scale == weight_scale
    assert sum(decoded, []) == values
    return dict(bits=bits, wire_hex=wire.hex(), padded_bytes=len(wire), encoded_scale=scale,
                support_numerator=domain.support(error), denominator=domain.denominator,
                objective_numerator=result['objective_numerator'], path=result['path'],
                error_l1=sum(map(abs, error)), witness=domain.witness(error))


def inverse_hadamard_box(samples):
    """Empirical bounds in a source-aligned basis, NOT producer containment."""
    n = len(samples[0])
    transformed = [hadamard(x) for x in samples]
    lo = [min(row[j] for row in transformed) for j in range(n)]
    hi = [max(row[j] for row in transformed) for j in range(n)]
    center = tuple(hadamard([l+h for l, h in zip(lo, hi)]))
    generators = tuple(tuple(1 if (i&j).bit_count()%2 == 0 else -1
                             for i in range(n)) for j in range(n))
    return Domain(center, generators, (0,)*n, 2*n, tuple(h-l for l, h in zip(lo, hi))), lo, hi


def real_block():
    fixture = json.loads((HERE/'instances/bonsai-layer00-block0.json').read_text())
    weights, samples = fixture['source_trits'], fixture['captured_integer_inputs']
    menus = menus_for(weights)
    domain, lo, hi = inverse_hadamard_box(samples[:3])
    memberships = []
    for row in samples:
        transformed = hadamard(row)
        excess = [max(l-v, v-h, 0) for v, l, h in zip(transformed, lo, hi)]
        memberships.append(dict(inside=not any(excess), violated_coordinates=sum(e > 0 for e in excess),
                                max_transformed_excess=max(excess)))
    problem = compile_domain(weights, menus, domain, static_bits=16)
    found = coordinate_search(problem)
    weight_scale = fixture['input_provenance']['common_weight_scale']
    diagnostic = candidate(weights, menus, domain, found, weight_scale)
    # Every absolute factor admits either sign as a linear lower bound. Find a
    # replayable separable dual certificate, starting at the candidate's signs.
    # A zero-error literal solution needs a stronger subgradient than sign(0).
    dual = dual_bound(problem)
    # Different, rank-three domain: the symmetric zonotope generated by the
    # calibration points. Its exact support is sum, rather than max, of errors.
    tubes = []
    for radius in (0, 1, 2):
        d = Domain((0,)*128, tuple(tuple(x) for x in samples[:3]), (radius,)*128)
        p = compile_domain(weights, menus, d, static_bits=16)
        r = coordinate_search(p)
        tubes.append(dict(residual_radius=radius, **candidate(weights, menus, d, r, weight_scale)))
    prior = json.loads((HERE/'certificate-bonsai.json').read_text())['witness']
    prior_values = sum((menus[i][k][1] for i, k in enumerate(prior['path'])), [])
    prior_error = [q-w for q, w in zip(prior_values, weights)]
    prior_bound = domain.support(prior_error)
    return dict(scope='Integer hidden operands. Source-aligned empirical bounds, not a certified producer envelope.',
                source_fixture_sha256=hashlib.sha256((HERE/'instances/bonsai-layer00-block0.json').read_bytes()).hexdigest(),
                hadamard_box=dict(denominator=domain.denominator, calibration_rows=3,
                                  memberships=memberships, candidate=diagnostic, dual=dual,
                                  original_codec_bits=224, prior_candidate_support_numerator=prior_bound),
                calibration_generator_tubes=tubes)


def gate_up_support():
    path = HERE/'instances/bonsai-layer00-gate-up-block0.json'
    fixture = json.loads(path.read_text())
    gate, up = (fixture['weights'][name]['trits'] for name in ('gate', 'up'))
    domain = Domain((0, 0), tuple(zip(gate, up)), (0, 0), radii=(127,)*128)
    probes = []
    for probe in ((1, 1), (1, -1), (2, 1), (1, 2)):
        joint = domain.support(probe)
        split = 127*(abs(probe[0])*sum(map(abs, gate))+abs(probe[1])*sum(map(abs, up)))
        witness = domain.witness(probe)
        codes = witness['latent']
        assert all(abs(q) == 127 for q in codes)
        accumulators = [dot(gate, codes), dot(up, codes)]
        assert abs(dot(probe, accumulators)) == joint
        captured = [abs(probe[0]*dot(gate, q)+probe[1]*dot(up, q))
                    for q in fixture['captured_inputs']['q']]
        assert max(captured) <= joint <= split
        probes.append(dict(probe=list(probe), joint=joint, independent=split,
                           reduction_fraction=1-joint/split, attaining_codes=codes,
                           attaining_accumulators=accumulators, capture_max=max(captured)))
    return dict(fixture_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), probes=probes,
                scope='Exact integer gate/up accumulators for every q in [-127,127]^128; not the nonlinear continuation.')


def dual_bound(problem):
    """Small rational LP gives a proposed dual; integer replay supplies the bound."""
    import numpy as np
    from scipy.optimize import linprog
    count = len(problem.blocks[0][0].factors)
    rows, rhs = [], []
    for i, block in enumerate(problem.blocks):
        for option in block:
            row = [0.]*(count+len(problem.blocks))
            row[:count] = [-float(problem.price*v) for v in option.factors]
            row[count+i] = 1.
            rows.append(row)
            rhs.append(float(option.cost))
    objective = [0.]*count + [-1.]*len(problem.blocks)
    fit = linprog(objective, A_ub=np.array(rows), b_ub=np.array(rhs),
                  bounds=[(-1, 1)]*count+[(None, None)]*len(problem.blocks), method='highs')
    if not fit.success:
        return dict(status='no-dual', message=fit.message)
    denominator = 1 << 20
    probes = tuple(max(-denominator, min(denominator, round(v*denominator))) for v in fit.x[:count])
    replay = replay_dual(problem, denominator, probes)
    return dict(status='integer-replayed', **replay, objective_denominator=problem.denominator,
                dual_denominator=denominator, signed_probes=list(probes),
                proof='|probe_j| <= dual_denominator; each block minimum recomputed with integers')


def main():
    started = time.monotonic()
    results = dict(checks=checks())
    p = chain(160)
    results['chain'] = dict(assignments='2^160', eliminated=frontier_dp(p),
                           full_response=frontier_dp(p, max_states=4096, close_factors=False))
    # A nonzero consumer: the first 32 latent coordinates cancel; the last 32
    # retain coefficient 2. The source row is not the zero function.
    weights = [1, -1]*32+[1]*64
    generators = tuple(tuple(1 if i//2 == j else 0 for i in range(128)) for j in range(64))
    domain = Domain((0,)*128, generators, (0,)*128, radii=(127,)*64)
    menus = menus_for(weights)
    p = compile_domain(weights, menus, domain, static_bits=16)
    solved = frontier_dp(p)
    results['shared_producer'] = dict(assignments='6^16', domain='x_(2j)=x_(2j+1)=z_j, integer |z_j|<=127',
                                      solver=solved, candidate=candidate(weights, menus, domain, solved))
    results['bonsai'] = real_block()
    results['gate_up'] = gate_up_support()
    results['source_sha256'] = {name: hashlib.sha256((HERE/name).read_bytes()).hexdigest()
                               for name in ('producer_search.py', 'producer_experiments.py', 'check_producer_results.py', 'codec.py')}
    results['elapsed_seconds'] = time.monotonic()-started
    (HERE/'producer-results.json').write_text(json.dumps(results, indent=2)+'\n')
    print(json.dumps(dict(checks=results['checks'], chain=results['chain'],
                         shared={k: v for k, v in results['shared_producer']['candidate'].items() if k != 'witness'},
                         real_candidate={k: v for k, v in results['bonsai']['hadamard_box']['candidate'].items() if k != 'witness'},
                         real_lower=results['bonsai']['hadamard_box']['dual'].get('lower_numerator'),
                         memberships=results['bonsai']['hadamard_box']['memberships'],
                         gate_up=[{k: v for k, v in p.items() if k not in ('attaining_codes', 'attaining_accumulators')}
                                  for p in results['gate_up']['probes']],
                         elapsed_seconds=results['elapsed_seconds']), indent=2))


if __name__ == '__main__':
    main()
