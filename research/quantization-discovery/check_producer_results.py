#!/usr/bin/env python3
"""Replay the saved real-block robust optimum with integers, without SciPy."""
import hashlib
import json
from pathlib import Path
from producer_experiments import inverse_hadamard_box, menus_for, candidate, gate_up_support
from producer_search import compile_domain, replay_dual

HERE = Path(__file__).resolve().parent


def check():
    results = json.loads((HERE/'producer-results.json').read_text())
    for name, expected in results['source_sha256'].items():
        assert hashlib.sha256((HERE/name).read_bytes()).hexdigest() == expected, name
    assert gate_up_support() == results['gate_up']
    fixture_path = HERE/'instances/bonsai-layer00-block0.json'
    fixture = json.loads(fixture_path.read_text())
    real = results['bonsai']
    assert hashlib.sha256(fixture_path.read_bytes()).hexdigest() == real['source_fixture_sha256']
    weights = fixture['source_trits']
    domain, _, _ = inverse_hadamard_box(fixture['captured_integer_inputs'][:3])
    menus = menus_for(weights)
    problem = compile_domain(weights, menus, domain, static_bits=16)
    record = real['hadamard_box']
    upper = record['candidate']
    assert problem.evaluate(upper['path']) == upper['objective_numerator']
    assert candidate(weights, menus, domain, upper, fixture['input_provenance']['common_weight_scale']) == upper
    dual = record['dual']
    replay = replay_dual(problem, dual['dual_denominator'], tuple(dual['signed_probes']))
    assert replay['block_minima'] == dual['block_minima']
    assert replay['lower_numerator'] == dual['lower_numerator']
    assert replay['lower_numerator'] == upper['objective_numerator']
    return dict(valid=True, optimal_in_declared_family=True,
                lower_numerator=replay['lower_numerator'], upper_numerator=upper['objective_numerator'],
                denominator=domain.denominator, stored_bits=upper['bits'],
                source_codec_bits=record['original_codec_bits'],
                producer_containment=False)


if __name__ == '__main__':
    print(json.dumps(check(), indent=2))
