#!/usr/bin/env python3
"""Executable checks for the composition toy. Writes result.json next to this file."""

from __future__ import annotations

import itertools
import json
import sys
from dataclasses import asdict
from pathlib import Path

from toy import (
    BYTE_MAX,
    DIGITS,
    INITIAL_BITS,
    LANE_MAX,
    UNKNOWN_INITIAL,
    ZERO_INITIAL,
    CostModel,
    Witness,
    all_ordinary,
    breaking_sequence_count,
    check_packed_exactness,
    decode,
    encode,
    first_winning_length,
    folding,
    fully_packed,
    greedy,
    greedy_entry_horizon,
    lane_overflow_counts,
    max_packed_run,
    packed_stage_valid,
    reachable,
    run_ordinary,
    run_packed,
    search,
)

COST = CostModel()
MAX_STAGES = 12
HEADROOM_RUN = (LANE_MAX - max(INITIAL_BITS)) // 2


def cost_table() -> list[dict]:
    rows = []
    for stages in range(1, MAX_STAGES + 1):
        ordinary = all_ordinary(stages, COST).cost
        best = search(stages, COST)
        ignored = search(stages, COST, enforce_validity=False)
        rows.append(
            {
                "stages": stages,
                "ordinary": ordinary,
                "best_valid": best.cost,
                "best_valid_plan": best.describe(),
                "packed_stages": best.packed_stages,
                "saving": ordinary - best.cost,
                "greedy": greedy(stages, COST).cost,
                "ignoring_validity": ignored.cost,
                "ignoring_validity_plan": ignored.describe(),
            }
        )
    return rows


def counterexample(initial, digits, failure: str, stages: int = 8) -> dict:
    sequence = tuple(digits for _ in range(stages))
    exact = run_ordinary(initial, sequence)
    byte = run_packed(initial, sequence)
    return {
        "stages": stages,
        "input": Witness(initial, sequence).as_json(),
        "true_state": list(exact),
        "packed_byte": byte,
        "unbounded_encoding": exact[0] + 16 * exact[1],
        "byte_max": BYTE_MAX,
        "decoded_state": list(decode(byte)),
        "failure": failure,
    }


def low_lane_counterexample() -> dict:
    return counterexample(
        (1, 0), (2, 0), "low lane reaches 17 and carries into the high lane"
    )


def high_lane_counterexample() -> dict:
    return counterexample((0, 1), (0, 2), "high lane reaches 17 and leaves the byte")


def boundary_edges() -> dict:
    reach = reachable(MAX_STAGES)
    edges = []
    for stage in range(MAX_STAGES):
        verdict = packed_stage_valid(reach, stage)
        witness = verdict.counterexample
        edges.append(
            {
                "stage": stage,
                "to_stage": stage + 1,
                "valid": verdict.ok,
                "max_reachable_lane": reach.max_lane(stage),
                "reason": verdict.reason,
                "counterexample_input": None if witness is None else witness.as_json(),
            }
        )
    return {"edges": edges, "last_valid_stage_index": HEADROOM_RUN - 1}


def headroom_reentry() -> list[dict]:
    reach = reachable(MAX_STAGES)
    rows = []
    for stage in range(MAX_STAGES):
        run = max_packed_run(reach, stage)
        entry = COST.enter_cost(reach.states(stage))
        rows.append(
            {
                "entry_stage": stage,
                "max_reachable_lane": reach.max_lane(stage),
                "max_valid_packed_run": run,
                "run_saving": run * COST.ordinary_stage
                - (entry + run * COST.packed_stage + COST.exit),
            }
        )
    return rows


def brute_force_lane_overflow(stages: int) -> int:
    return sum(
        1
        for start in INITIAL_BITS
        for digits in itertools.product(DIGITS, repeat=stages)
        if start + sum(digits) > LANE_MAX
    )


def checks() -> list[dict]:
    results: list[dict] = []

    def record(name: str, passed: bool, detail: str = "") -> None:
        results.append({"name": name, "passed": bool(passed), "detail": detail})

    reach = reachable(MAX_STAGES)

    record(
        "the entry state is unknown, so entering is a real pack of two input bits",
        reach.states(0) == UNKNOWN_INITIAL and len(UNKNOWN_INITIAL) == 4,
        f"initial states {sorted(UNKNOWN_INITIAL)}",
    )

    record(
        "a lane holds at most 1 + 2n after n stages",
        all(reach.max_lane(stage) == 1 + 2 * stage for stage in range(MAX_STAGES + 1)),
        f"max lane by stage {[reach.max_lane(s) for s in range(9)]}",
    )

    exactness = check_packed_exactness(MAX_STAGES)
    record(
        "packed stages 0..6 are exact for every reachable state and digit pair",
        exactness.first_failure_stage == HEADROOM_RUN,
        f"{exactness.state_digit_pairs} state/digit pairs checked; "
        f"first invalid stage {exactness.first_failure_stage}",
    )

    record(
        "the packed run from the entry state is capped at 7 stages",
        max_packed_run(reach, 0) == HEADROOM_RUN == 7,
        f"max_packed_run(0) = {max_packed_run(reach, 0)}",
    )

    low = low_lane_counterexample()
    record(
        "one initial bit and eight twos in the low lane misdecodes",
        low["decoded_state"] != low["true_state"],
        f"decoded {low['decoded_state']} instead of {low['true_state']}",
    )

    high = high_lane_counterexample()
    record(
        "one initial bit and eight twos in the high lane leaves the byte",
        high["unbounded_encoding"] > BYTE_MAX and high["decoded_state"] != high["true_state"],
        f"unbounded encoding {high['unbounded_encoding']} wraps to byte {high['packed_byte']}",
    )

    win = first_winning_length(COST)
    record(
        "a packed interval first beats ordinary lowering at 7 stages",
        win == 7,
        f"first winning length {win}",
    )

    six = search(6, COST)
    record(
        "at 6 stages packing only ties, so it is not selected",
        six.cost == all_ordinary(6, COST).cost and six.packed_stages == 0,
        f"best {six.cost} vs ordinary {all_ordinary(6, COST).cost}; "
        f"fully packed would cost {fully_packed(6, COST).cost}",
    )

    record(
        "greedy lowering never enters the representation",
        all(greedy(n, COST).packed_stages == 0 for n in range(1, MAX_STAGES + 1)),
        f"greedy cost at 7 stages {greedy(7, COST).cost}, global {search(7, COST).cost}",
    )

    record(
        "local lowering needs a 7-stage lookahead to find the win",
        greedy_entry_horizon(MAX_STAGES, COST) == 7,
        f"entry horizon {greedy_entry_horizon(MAX_STAGES, COST)}",
    )

    eight = search(8, COST)
    record(
        "at 8 stages the packed prefix of 7 is kept and the last stage is ordinary",
        eight.packed_runs == ((0, 7),) and eight.cost == 15,
        f"{eight.describe()} at cost {eight.cost}",
    )

    ignored = search(8, COST, enforce_validity=False)
    record(
        "dropping the validity precondition selects the invalid fully packed 8-stage plan",
        ignored.packed_stages == 8 and ignored.cost < eight.cost,
        f"{ignored.describe()} at cost {ignored.cost}, cheaper than the valid {eight.cost}",
    )

    savings = {
        n: all_ordinary(n, COST).cost - search(n, COST).cost for n in range(1, MAX_STAGES + 1)
    }
    record(
        "headroom pins the total saving at one unit for every length from 7 on",
        all(savings[n] == 1 for n in range(7, MAX_STAGES + 1)),
        f"savings {savings}",
    )

    record(
        "no packed stage remains universally valid after stage 7",
        all(max_packed_run(reach, stage) == 0 for stage in range(HEADROOM_RUN, MAX_STAGES)),
        "every later entry state can already hold 15 in a lane",
    )

    overflow, lane_total = lane_overflow_counts(8)
    breaking, total = breaking_sequence_count(8)
    record(
        "the 8-stage break set is the 10 lane inputs that pass 15, and nothing else",
        overflow == brute_force_lane_overflow(8) == 10
        and breaking == 2 * overflow * lane_total - overflow**2,
        f"{overflow} of {lane_total} lane inputs overflow, so {breaking} of {total} "
        "input pairs break",
    )

    folded = folding(COST)
    record(
        "folding applies only to a known entry state, and moves the boundary to 4 stages",
        folded.enter_cost(UNKNOWN_INITIAL) == COST.enter
        and folded.enter_cost(ZERO_INITIAL) == 0
        and first_winning_length(folded, ZERO_INITIAL) == 4
        and first_winning_length(folded, UNKNOWN_INITIAL) == 7,
        f"known-zero first win {first_winning_length(folded, ZERO_INITIAL)}, "
        f"unknown entry first win {first_winning_length(folded, UNKNOWN_INITIAL)}",
    )

    return results


def main() -> int:
    results = checks()
    failed = [check for check in results if not check["passed"]]
    folded = folding(COST)
    reach = reachable(MAX_STAGES)

    result = {
        "toy": "two-lane accumulator, nibble packing, seven-stage chain",
        "scope": (
            "Architecture test of representation-change composition. The cost model is "
            "synthetic, not a measured ISA, and nothing here claims a real FFN speedup or "
            "native optimality."
        ),
        "model": {
            "digits": list(DIGITS),
            "lanes": 2,
            "initial_state": "unknown input bits x0, y0 in {0,1}",
            "initial_states": [list(state) for state in sorted(UNKNOWN_INITIAL)],
            "encoding": "x + 16*y in one byte",
            "lane_bound_after_n_stages": "1 + 2n",
            "lane_max": LANE_MAX,
            "byte_max": BYTE_MAX,
            "stage": "both accumulators add one digit each",
        },
        "cost_model": {
            **asdict(COST),
            "units": "synthetic gateway charges, not instruction counts",
            "inputs": (
                "Dynamic digits and their packed form a + 16*b are common inputs; producing "
                "them is outside the toy and is not claimed free in a real FFN."
            ),
            "entry": (
                "The entry state is unknown input bits, so the 3-unit enter charge is not a "
                "foldable constant pack."
            ),
        },
        "results": {
            "first_winning_length": first_winning_length(COST),
            "tie_length": 6,
            "max_valid_packed_run_from_entry": max_packed_run(reach, 0),
            "saving_by_length": {
                str(n): all_ordinary(n, COST).cost - search(n, COST).cost
                for n in range(1, MAX_STAGES + 1)
            },
            "greedy_entry_horizon": greedy_entry_horizon(MAX_STAGES, COST),
            "eight_stage_valid_plan": search(8, COST).describe(),
            "eight_stage_plan_ignoring_validity": search(
                8, COST, enforce_validity=False
            ).describe(),
            "breaking_inputs_at_8": dict(zip(("breaking", "total"), breaking_sequence_count(8))),
            "overflowing_lane_inputs_at_8": dict(
                zip(("overflowing", "total"), lane_overflow_counts(8))
            ),
        },
        "cost_table": cost_table(),
        "boundary": boundary_edges(),
        "reentry_headroom": headroom_reentry(),
        "counterexamples": {
            "low_lane_carry": low_lane_counterexample(),
            "high_lane_byte_overflow": high_lane_counterexample(),
        },
        "constant_folding_variant": {
            "note": (
                "A separate model in which the initial state is the known constant (0,0). A "
                "lowering may then fold the entry to 0, and the first win moves to 4 stages. "
                "The main model does not admit this, because its entry state is input."
            ),
            "initial_states": [list(state) for state in sorted(ZERO_INITIAL)],
            "enter_cost": folded.enter_cost(ZERO_INITIAL),
            "first_winning_length": first_winning_length(folded, ZERO_INITIAL),
            "max_valid_packed_run": max_packed_run(reachable(MAX_STAGES, ZERO_INITIAL), 0),
            "eight_stage_plan": search(8, folded, initial=ZERO_INITIAL).describe(),
        },
        "checks": results,
        "all_checks_passed": not failed,
    }

    Path(__file__).with_name("result.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )

    for check in results:
        mark = "ok  " if check["passed"] else "FAIL"
        print(f"{mark} {check['name']}\n     {check['detail']}")
    print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
