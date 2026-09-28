#!/usr/bin/env python3
import json
from dataclasses import asdict
from itertools import product
from pathlib import Path
from observer import (Machine, Instruction, decoder_search, distinguishing_word,
                      factor, fibers, stable_quotient, suffix_observations)


def run():
    bits = list(product(range(2), repeat=2))
    bad = factor([a & b for a, b in bits], [a | b for a, b in bits])

    states = list(product((-1, 0, 1), repeat=2))
    index = {state: i for i, state in enumerate(states)}
    observation = tuple(max(g, 0) * u for g, u in states)
    transitions = {
        "neg_gate": tuple(index[-g, u] for g, u in states),
        "neg_up": tuple(index[g, -u] for g, u in states),
        "swap": tuple(index[u, g] for g, u in states),
    }
    gated = Machine(observation, transitions)
    q = stable_quotient(gated)
    rotate = {-1: 0, 0: 1, 1: -1}
    richer = Machine(observation, {**transitions,
                     "rotate_gate": tuple(index[rotate[g], u] for g, u in states)})
    qr = stable_quotient(richer)
    a, b = index[-1, -1], index[-1, 1]
    word = distinguishing_word(gated, a, b)

    pairs = list(product(range(4), repeat=2))
    idx = {state: i for i, state in enumerate(pairs)}
    sums = tuple((x + y) % 4 for x, y in pairs)
    compound = Machine(sums, {
        "double_y": tuple(idx[x, (2 * y) % 4] for x, y in pairs),
        "double_x": tuple(idx[(2 * x) % 4, y] for x, y in pairs),
    })
    first_target = tuple(sums[s] for s in compound.transitions["double_y"])
    suffixes = suffix_observations(compound, ("double_y", "double_x"))
    first = factor(sums, first_target)
    whole = factor(sums, suffixes[0])
    cq = stable_quotient(compound)

    domain = tuple(range(8))
    instructions = (Instruction("and_1", tuple(x & 1 for x in domain)),
                    Instruction("xor_1", tuple(x ^ 1 for x in domain)))
    target = tuple(x & 1 for x in domain)
    identity = decoder_search(domain, target, instructions, 3)
    relabeled = decoder_search(tuple(x ^ 1 for x in domain), target, instructions, 3)
    impossible = decoder_search(tuple(0 for _ in domain), target, instructions, 3)
    capped = decoder_search(domain, target, instructions, 3, max_states=1)

    return {
        "contract": "finite exact semantic exploration; no GPU speed claim",
        "equal_output_cardinality_is_insufficient": {
            "inputs": bits, "carrier": "and", "target": "or",
            "collision": asdict(bad.collision),
        },
        "gated_observation": {
            "states": states, "observation": "relu(g)*u", "values": observation,
            "fixed_final_classes": len(set(observation)),
            "sign_swap_continuation_classes": len(set(q.classes)),
            "sign_swap_partition": q.classes,
            "refinement_sizes": q.refinement_sizes,
            "add_gate_rotation_classes": len(set(qr.classes)),
            "initially_equal_states": [states[a], states[b]],
            "shortest_distinguishing_continuation": word,
            "outputs_after_continuation": [observation[gated.after(s, word)] for s in (a, b)],
            "quotient_transitions": dict(q.machine.transitions),
            "quotient_observation": q.machine.observation,
        },
        "compound_closure": {
            "domain": "(Z/4)^2", "entry_carrier": "x+y modulo 4",
            "source_steps": ["(x,y)->(x,2y)", "(x,y)->(2x,y)"],
            "first_stage_sufficient": first.sufficient,
            "first_stage_collision": asdict(first.collision),
            "whole_region_sufficient": whole.sufficient,
            "whole_region_decoder": dict(whole.decoder),
            "replacement": "double the carrier modulo 4",
            "fixed_suffix_class_counts": [len(set(v)) for v in suffixes],
            "all_continuations_class_count": len(set(cq.classes)),
            "scope": "Requiring closure under both individual source steps forbids the smaller whole-region representation.",
        },
        "numeric_labels_have_cost": {
            "register_domain": "3-bit word", "input": "x already in one register",
            "target": "x & 1", "grammar": [i.name for i in instructions],
            "cost": "one unit per listed instruction; no free output relabeling",
            "same_fibers": fibers(domain) == fibers(tuple(x ^ 1 for x in domain)),
            "identity_carrier": asdict(identity),
            "xor_1_carrier": asdict(relabeled),
            "lost_information": asdict(impossible),
            "budget_exhaustion_is_not_impossibility": asdict(capped),
        },
    }


if __name__ == "__main__":
    result = run()
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
