#!/usr/bin/env python3
"""Exact finite-map synthesis by indexed composition across a small state separator."""

import json
import random
from collections import defaultdict
from time import perf_counter

STATES = tuple(range(16))
OPERATIONS = {
    "add1": lambda x: (x + 1) & 15,
    "xor5": lambda x: x ^ 5,
    "rol1": lambda x: ((x << 1) | (x >> 3)) & 15,
    "xor8": lambda x: x ^ 8,
    "xorshift1": lambda x: x ^ ((x << 1) & 15),
    "and7": lambda x: x & 7,
}
OP_TABLES = {name: tuple(op(x) for x in STATES) for name, op in OPERATIONS.items()}


def execute(word, inputs=STATES):
    result = tuple(inputs)
    for name in word:
        table = OP_TABLES[name]
        result = tuple(table[x] for x in result)
    return result


def shortest_semantics(max_depth):
    levels = [{STATES: ()}]
    seen = {STATES}
    transitions = 0
    for depth in range(max_depth):
        next_level = {}
        for function, word in levels[-1].items():
            for name, table in OP_TABLES.items():
                transitions += 1
                successor = tuple(table[x] for x in function)
                if successor not in seen and successor not in next_level:
                    next_level[successor] = word + (name,)
        seen.update(next_level)
        levels.append(next_level)
    return levels, transitions


def indexed_join(prefixes, suffixes, target, mismatch_budget=0):
    """Join the full machine maps with a total Hamming-distortion budget."""
    functions = tuple(prefixes)
    postings = [[0] * len(STATES) for _ in STATES]
    for index, function in enumerate(functions):
        flag = 1 << index
        for input_index, state in enumerate(function):
            postings[input_index][state] |= flag
    all_prefixes = (1 << len(functions)) - 1
    bitset_intersections = 0
    candidate_pairs = 0
    for suffix, suffix_word in suffixes.items():
        preimages = defaultdict(int)
        for state, output in enumerate(suffix):
            preimages[output] |= 1 << state
        choices = []
        for input_index, output in enumerate(target):
            state_mask = preimages[output]
            accepted = 0
            while state_mask:
                bit = state_mask & -state_mask
                state_mask -= bit
                accepted |= postings[input_index][bit.bit_length() - 1]
            choices.append(accepted)
        # The j-th bitset holds prefixes with at most j observed mismatches.
        # Complements refer only to reachable prefix ids, never arbitrary states.
        budgets = [all_prefixes] * (mismatch_budget + 1)
        for accepted in sorted(choices, key=int.bit_count):
            rejected = all_prefixes ^ accepted
            previous = budgets[0]
            budgets[0] &= accepted
            bitset_intersections += 1
            for j in range(1, len(budgets)):
                current = budgets[j]
                budgets[j] = (current & accepted) | (previous & rejected)
                previous = current
                bitset_intersections += 2
            if not budgets[-1]:
                break
        possible = budgets[-1]
        while possible:
            flag = possible & -possible
            possible -= flag
            candidate_pairs += 1
            prefix = functions[flag.bit_length() - 1]
            if sum(suffix[state] != output for state, output in zip(prefix, target)) <= mismatch_budget:
                return prefixes[prefix] + suffix_word, bitset_intersections, candidate_pairs
    return None, bitset_intersections, candidate_pairs


def synthesize(target, levels, mismatch_budget=0):
    intersections = 0
    candidate_pairs = 0
    for depth in range(2 * (len(levels) - 1) + 1):
        left = depth // 2
        right = depth - left
        if right >= len(levels):
            break
        solution, tested, pairs = indexed_join(levels[left], levels[right], target, mismatch_budget)
        intersections += tested
        candidate_pairs += pairs
        if solution is not None:
            assert sum(a != b for a, b in zip(execute(solution), target)) <= mismatch_budget
            return solution, intersections, candidate_pairs
    return None, intersections, candidate_pairs


def main():
    started = perf_counter()
    levels, transitions = shortest_semantics(4)
    rng = random.Random(241109)
    attempts = 0
    while True:
        attempts += 1
        word = tuple(rng.choice(tuple(OPERATIONS)) for _ in range(8))
        target = execute(word)
        optimum, intersections, candidate_pairs = synthesize(target, levels)
        if optimum is not None and len(optimum) == 8:
            break
        if attempts == 1000:
            raise RuntimeError("No depth-eight target in 1000 fixed-seed attempts")
    planted_word = word
    perturbed = list(target)
    perturbed[0] = (perturbed[0] + 1) & 15
    negative, negative_intersections, negative_pairs = synthesize(tuple(perturbed), levels)
    assert negative is None
    approximate, approximate_intersections, approximate_pairs = synthesize(tuple(perturbed), levels, 1)
    assert approximate is not None
    # Independent brute-force checker on a smaller depth: no semantic deduplication.
    shorter_target = execute(optimum[:5])
    brute_checks = 0
    brute_optimum = None
    frontier = [()]
    for depth in range(6):
        for word in frontier:
            brute_checks += 1
            if execute(word) == shorter_target:
                brute_optimum = word
                break
        if brute_optimum is not None:
            break
        frontier = [word + (op,) for word in frontier for op in OPERATIONS]
    short_solution, _, _ = synthesize(shorter_target, levels)
    assert short_solution is not None and len(short_solution) == len(brute_optimum)
    full_levels, full_transitions = shortest_semantics(8)
    assert full_levels[8][target] == optimum
    assert all(target not in level for level in full_levels[:8])
    assert all(tuple(perturbed) not in level for level in full_levels)
    best_mismatch_by_exact_depth = [
        min(sum(a != b for a, b in zip(function, perturbed)) for function in level)
        for level in full_levels
    ]
    assert min(best_mismatch_by_exact_depth[:8]) > 1
    assert best_mismatch_by_exact_depth[8] == 1
    print(json.dumps({ 
        "domain": "all 16 four-bit states; one register; unit-cost unary operations",
        "operations": list(OPERATIONS),
        "bfs_unique_functions_by_minimal_depth_0_to_4": [len(level) for level in levels],
        "bfs_transition_evaluations": transitions,
        "full_semantic_bfs_unique_functions_by_depth_0_to_8": [len(level) for level in full_levels],
        "full_semantic_bfs_transition_evaluations": full_transitions,
        "planted_word": planted_word,
        "target_table": target,
        "sampled_words_until_depth_eight": attempts,
        "optimum": optimum,
        "optimum_depth": len(optimum),
        "indexed_bitset_intersections_through_optimum": intersections,
        "joined_candidate_pairs_through_optimum": candidate_pairs,
        "plain_word_evaluations_through_depth_eight": sum(6 ** i for i in range(9)),
        "perturbed_table": perturbed,
        "perturbed_solution_depth_le_eight": negative,
        "perturbed_bitset_intersections": negative_intersections,
        "perturbed_joined_pairs": negative_pairs,
        "one_mismatch_optimum": approximate,
        "one_mismatch_optimum_depth": len(approximate),
        "one_mismatch_bitset_intersections": approximate_intersections,
        "one_mismatch_joined_pairs": approximate_pairs,
        "best_perturbed_hamming_loss_by_minimal_program_depth": best_mismatch_by_exact_depth,
        "independent_brute_depth_five_word_checks": brute_checks,
        "independent_brute_depth_five_witness": brute_optimum,
        "elapsed_seconds": round(perf_counter() - started, 3),
    }, indent=2))


if __name__ == "__main__":
    main()
