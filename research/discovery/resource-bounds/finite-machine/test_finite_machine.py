"""Contracts that can actually break: checker independence, and tamper rejection.

Run with `python3 test_finite_machine.py`. The point of a certificate is that it
survives a hostile file, so most of this file edits a valid certificate and
insists the checker says no.
"""

import base64
import copy
import json
import unittest
from pathlib import Path

import check
import machine
from certify import INF, Certificate, Space, backward_potential, forward_potential

RESULTS = Path(__file__).resolve().parent / "results"


def small() -> dict:
    space = Space.build(machine.Machine(2, 2, (0, 1, 3), (0,)), "full")
    cert = Certificate("tamper-target", space, "fixture")
    cert.reach("relu", {"kind": "exact", "observe": 0, "target": [0, 1, 0]})
    cert.through(
        "relu-through-negate",
        {"kind": "exact", "observe": 0, "target": [0, 1, 0]},
        {"target": [0, 3, 1], "registers": "any"},
        "relu",
    )
    cert.count_cut("relu-count-cut", {"kind": "exact", "observe": 0, "target": [0, 1, 0]}, "relu")
    return cert.as_json()


class CheckerIndependence(unittest.TestCase):
    def test_both_implementations_agree_on_every_instruction(self):
        for width, registers in ((2, 2), (2, 3), (3, 2)):
            for grammar, ops in machine.GRAMMARS.items():
                host = machine.Machine(width, registers, (0, 1), (0,) * (registers - 1))
                names = machine.instruction_names(host, ops)
                self.assertEqual(names, check.expected_names(ops, width, registers), grammar)
                for name in names:
                    self.assertEqual(
                        list(machine.instruction_table(name, width, registers)),
                        check.derive_table(name, width, registers),
                        name,
                    )

    def test_charge_tables_agree(self):
        self.assertEqual(dict(machine.CHARGES), dict(check.CHARGES))
        self.assertEqual({k: tuple(v) for k, v in machine.GRAMMARS.items()}, {k: tuple(v) for k, v in check.GRAMMARS.items()})


class TamperRejection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.valid = small()

    def assertRejected(self, mutate):
        cert = copy.deepcopy(self.valid)
        mutate(cert)
        with self.assertRaises(check.Rejected):
            check.check(cert)

    def test_valid_certificate_passes(self):
        report = check.check(copy.deepcopy(self.valid))
        self.assertEqual([row["name"] for row in report[:2]], ["relu", "relu-through-negate"])
        self.assertEqual([row["cost"] for row in report[:2]], [2, 3])
        cut = report[-1]
        self.assertEqual((cut["status"], cut["length_at_least"], cut["usable_families"]), ("count-cut", 2, ["addi", "shri"]))

    def test_cheaper_claim_rejected(self):
        self.assertRejected(lambda c: c["queries"][0]["claim"].__setitem__("cost", 1))

    def test_dropped_instruction_rejected(self):
        self.assertRejected(lambda c: c["grammar"]["instructions"].pop(7))

    def test_understated_charge_rejected(self):
        def mutate(cert):
            for ins in cert["grammar"]["instructions"]:
                if ins["charge"] > 1:
                    ins["charge"] = 1
                    return
            raise AssertionError("fixture has no multi-charge instruction")

        self.assertRejected(mutate)

    def test_rewritten_instruction_table_rejected(self):
        self.assertRejected(lambda c: c["grammar"]["instructions"][0]["table"].__setitem__(0, 1))

    def test_inflated_potential_rejected(self):
        def mutate(cert):
            raw = bytearray(base64.b64decode(cert["forward"]["u8"]))
            raw[next(i for i, v in enumerate(raw) if 0 < v < 200)] += 3
            cert["forward"]["u8"] = base64.b64encode(bytes(raw)).decode()

        self.assertRejected(mutate)

    def test_witness_edit_rejected(self):
        self.assertRejected(lambda c: c["queries"][0]["witness"].__setitem__(0, "addi r0 2"))

    def test_waypoint_skipping_witness_rejected(self):
        cert = copy.deepcopy(self.valid)
        cheap = cert["queries"][0]["witness"]
        cert["queries"][1]["witness"] = cheap
        cert["queries"][1]["claim"]["cost"] = 2
        with self.assertRaises(check.Rejected):
            check.check(cert)

    def test_understated_drop_rejected(self):
        def mutate(cert):
            drops = cert["cuts"][0]["drops"]
            drops[next(i for i, d in enumerate(drops) if d is not None and d > 0)] = 0

        self.assertRejected(mutate)

    def test_false_family_exclusion_rejected(self):
        def mutate(cert):
            drops = cert["cuts"][0]["drops"]
            drops[next(i for i, d in enumerate(drops) if d is not None)] = None

        self.assertRejected(mutate)

    def test_inflated_length_bound_rejected(self):
        self.assertRejected(lambda c: c["cuts"][0].__setitem__("length_at_least", 9))

    def test_float_and_bool_scalars_rejected(self):
        for path, value in (
            (("machine", "width"), 2.0),
            (("machine", "registers"), True),
            (("forward", "space"), 4096.0),
            (("forward", "infinity"), 255.0),
        ):
            with self.subTest(path=path, value=value):
                self.assertRejected(lambda c, p=path, v=value: c[p[0]].__setitem__(p[1], v))

    def test_float_and_bool_list_entries_rejected(self):
        for mutate in (
            lambda c: c["machine"]["domain"].__setitem__(0, 0.0),
            lambda c: c["machine"]["scratch"].__setitem__(0, False),
            lambda c: c["grammar"]["instructions"][0].__setitem__("charge", 1.0),
            lambda c: c["grammar"]["instructions"][0]["table"].__setitem__(0, 0.0),
            lambda c: c["queries"][0]["goal"]["target"].__setitem__(0, 0.0),
            lambda c: c["queries"][0]["goal"].__setitem__("observe", 0.0),
            lambda c: c["queries"][1]["through"]["waypoint"]["target"].__setitem__(0, 0.0),
            lambda c: c["cuts"][0].__setitem__("budget", 2.0),
            lambda c: c["cuts"][0]["drops"].__setitem__(0, True),
            lambda c: c["cuts"][0].__setitem__("length_at_least", 2.0),
        ):
            with self.subTest(mutate=mutate.__code__.co_firstlineno):
                self.assertRejected(mutate)

    def test_duplicate_backward_id_rejected(self):
        def mutate(cert):
            clone = copy.deepcopy(cert["backward"][0])
            clone["goal"]["target"] = [0, 0, 0]
            cert["backward"].append(clone)

        self.assertRejected(mutate)

    def test_duplicate_claim_name_rejected(self):
        self.assertRejected(lambda c: c["queries"][1].__setitem__("name", c["queries"][0]["name"]))

    def test_cut_name_colliding_with_a_query_rejected(self):
        self.assertRejected(lambda c: c["cuts"][0].__setitem__("name", c["queries"][0]["name"]))

    def test_dangling_potential_reference_rejected(self):
        self.assertRejected(lambda c: c["cuts"][0].__setitem__("potential", "absent"))
        self.assertRejected(lambda c: c["queries"][1]["through"].__setitem__("backward", "absent"))

    def test_missing_field_rejected(self):
        self.assertRejected(lambda c: c["cuts"][0].pop("length_at_least"))
        self.assertRejected(lambda c: c["machine"].pop("scratch"))

    def test_false_impossibility_rejected(self):
        def mutate(cert):
            cert["queries"][0]["claim"] = {"status": "impossible", "cost": None}
            cert["queries"][0]["witness"] = []

        self.assertRejected(mutate)


class PairEndpoint(unittest.TestCase):
    def test_pair_claim_and_target_tampering(self):
        cert = json.loads((RESULTS / "m1-full.cert.json").read_text())
        report = check.check(cert)
        self.assertEqual(
            [(row["name"], row["cost"]) for row in report if row["name"] in ("and-in-r0-xor-in-r1", "xor-in-r0-and-in-r1")],
            [("and-in-r0-xor-in-r1", 4), ("xor-in-r0-and-in-r1", 5)],
        )
        self.assertEqual(next(row["cost"] for row in report if row["name"] == "scaled-and-in-r0-or-in-r1"), 4)
        self.assertEqual(next(row["cost"] for row in report if row["name"] == "or-alone"), 3)
        for mutate in (
            lambda c: c["queries"][11]["claim"].__setitem__("cost", 3),
            lambda c: c["queries"][11]["goal"]["targets"][1].__setitem__(1, True),
            lambda c: c["queries"][11]["goal"]["targets"].pop(),
        ):
            edited = copy.deepcopy(cert)
            mutate(edited)
            with self.assertRaises(check.Rejected):
                check.check(edited)


class PotentialMath(unittest.TestCase):
    def test_backward_potential_is_the_exact_distance_to_the_goal(self):
        host = machine.Machine(2, 2, (0, 1, 3), (0,))
        space = Space.build(host, "full")
        goal = machine.goal_mask(host, {"kind": "exact", "observe": 0, "target": [0, 1, 0]})
        potential = backward_potential(space, goal)
        forward, _, _ = forward_potential(space)
        self.assertEqual(int(potential[space.init]), int(forward[goal].min()))

    def test_impossible_target_has_no_finite_forward_value(self):
        host = machine.Machine(2, 2, (0, 1, 2, 3), (0,))
        space = Space.build(host, "noshr")
        forward, _, _ = forward_potential(space)
        goal = machine.goal_mask(host, {"kind": "exact", "observe": 0, "target": [0, 0, 1, 1]})
        self.assertTrue(bool((forward[goal] >= INF).all()))


class PublishedCertificates(unittest.TestCase):
    def test_every_published_certificate_checks(self):
        paths = sorted(RESULTS.glob("*.cert.json"))
        self.assertTrue(paths, "run experiments.py first")
        for path in paths:
            with self.subTest(path.name):
                check.check(json.loads(path.read_text()))


if __name__ == "__main__":
    unittest.main(verbosity=2)
