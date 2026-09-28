import copy
import itertools
import random
import unittest
from fractions import Fraction

from certificates import (binding, digest, propose, verify_dual, verify_primal,
                          verify_infeasible, verify_relaxation_pair)
from examples import xor_case, parallel_case, plan, node, operation, cut
from schedule import verify_schedule, compare


class CertificateTests(unittest.TestCase):
    def setUp(self):
        self.m, self.p, self.f, self.attaining, self.competitor = xor_case()
        self.solution = propose(self.m, self.p, self.f)
        self.assertEqual(self.solution["status"], "checked")
        self.dual = self.solution["dual"]

    def test_optimum_and_strict_domination_are_different(self):
        self.assertEqual(compare(self.m, self.p, self.f, self.dual, self.attaining)["status"],
                         "family_optimum_under_premises")
        self.assertEqual(compare(self.m, self.p, self.f, self.dual, self.competitor)["status"],
                         "family_strictly_dominated_under_premises")

    def test_parallel_ports_do_not_add(self):
        m, p, f, schedule = parallel_case()
        solution = propose(m, p, f)
        result = compare(m, p, f, solution["dual"], schedule)
        self.assertEqual(result["lower_bound"], "1")
        self.assertEqual(result["upper_bound"], "1")
        m, p, f, schedule = parallel_case(4)
        solution = propose(m, p, f)
        result = compare(m, p, f, solution["dual"], schedule)
        self.assertEqual(result["status"], "bounds_leave_gap")
        self.assertEqual(result["upper_bound"], "4")

    def test_dual_rejects_bad_weights_and_binding(self):
        for mutation in (lambda c: c["lambda"].update(low="-1"),
                         lambda c: c["lambda"].update(low="100"),
                         lambda c: c["mu"].update(valu="0"),
                         lambda c: c["mu"].update(unknown="1"),
                         lambda c: c["lambda"].update(low=0.5),
                         lambda c: c["binding"].update(problem="wrong")):
            cert = copy.deepcopy(self.dual)
            mutation(cert)
            self.assertFalse(verify_dual(self.m, self.p, self.f, cert)["valid"])

    def test_fractional_count_relaxation_is_not_a_program(self):
        f = copy.deepcopy(self.f)
        f["obligations"] = [cut("fractional", {"xor1": 2}, 3, "Deliberate restricted-count example", "class_restriction")]
        proposed = propose(self.m, self.p, f)
        self.assertTrue(proposed["verification"]["relaxation_optimal"])
        self.assertEqual(proposed["primal"]["counts"]["xor1"], "3/2")
        self.assertFalse(proposed["verification"]["proves_program_optimality"])

    def test_correct_program_can_refute_a_bad_semantic_premise(self):
        f = copy.deepcopy(self.f)
        f["obligations"][0]["minimum"] = 2
        proposed = propose(self.m, self.p, f)
        result = compare(self.m, self.p, f, proposed["dual"], self.attaining)
        self.assertEqual(result["status"], "correct_program_refutes_stated_count_obligation")
        f["obligations"][0]["role"] = "class_restriction"
        proposed = propose(self.m, self.p, f)
        result = compare(self.m, self.p, f, proposed["dual"], self.attaining)
        self.assertEqual(result["status"], "family_strictly_dominated_under_premises")

    def test_infeasible_count_certificate(self):
        f = copy.deepcopy(self.f)
        f["obligations"] = [cut("impossible", {}, 1, "Required observation is invariant under every allowed operation.")]
        cert = {"binding": binding(self.m, self.p, f), "lambda": {"impossible": 1}}
        self.assertTrue(verify_infeasible(self.m, self.p, f, cert)["valid"])
        cert["lambda"]["impossible"] = 0
        self.assertFalse(verify_infeasible(self.m, self.p, f, cert)["valid"])

    def test_dependency_and_endpoint_errors(self):
        s = copy.deepcopy(self.attaining)
        s["nodes"][1]["start"] = 0
        self.assertFalse(verify_schedule(self.m, self.p, s)["valid"])
        s = copy.deepcopy(self.attaining)
        s["outputs"] = ["a"]
        self.assertIn("endpoint mismatch", verify_schedule(self.m, self.p, s)["reason"])
        s = copy.deepcopy(self.attaining)
        s["nodes"][0]["args"] = ["b"]
        self.assertFalse(verify_schedule(self.m, self.p, s)["valid"])

    def test_reservations_and_latency_are_separate(self):
        m, p, f, s = parallel_case()
        m["operations"]["xor2"]["reservations"][0]["resource"] = "left"
        m["operations"]["xor2"]["demand"] = {"left": 1}
        s["binding"]["model"] = digest(m)
        self.assertIn("overbooked", verify_schedule(m, p, s)["reason"])
        m, p, f, s = parallel_case()
        m["operations"]["xor1"]["demand"]["left"] = 2
        s["binding"]["model"] = digest(m)
        self.assertIn("underpays", verify_schedule(m, p, s)["reason"])
        m, p, f, s = parallel_case()
        m["operations"]["xor1"]["reservations"][0]["offset"] = 5
        s["binding"]["model"] = digest(m)
        self.assertEqual(verify_schedule(m, p, s)["upper_bound"], "6")

    def test_retained_input_counts_toward_register_pressure(self):
        m = copy.deepcopy(self.m)
        m["operations"]["xor"] = {"arity": 2, "table": [a ^ b for b in range(4) for a in range(4)],
                                  "demand": {"valu": 1}, "latency": 1,
                                  "reservations": [{"resource": "valu", "offset": 0, "duration": 1, "amount": 1}]}
        p = {"inputs": ["x"], "cases": [{"inputs": [x], "outputs": [3, x ^ 1]} for x in range(4)]}
        s = plan(m, p, [node("a", "xor1", ["x"], 0), node("b", "xor2", ["x"], 1),
                        node("c", "xor1", ["x"], 2), node("d", "xor", ["a", "b"], 3)], ["d", "c"])
        self.assertIn("register capacity exceeded", verify_schedule(m, p, s)["reason"])
        m["register_capacity"] = 3
        s["binding"]["model"] = digest(m)
        result = verify_schedule(m, p, s)
        self.assertTrue(result["valid"], result)
        self.assertEqual(result["register_peak"], 3)

    def test_duals_against_independent_bounded_count_enumeration(self):
        rng = random.Random(614)
        for _ in range(16):
            m, p, f, _ = parallel_case()
            for op in m["operations"].values():
                op["demand"] = {"left": rng.randrange(4), "right": rng.randrange(4)}
            m["resources"] = {"left": rng.randrange(1, 4), "right": rng.randrange(1, 4)}
            f["obligations"] = [cut("work", {"xor1": rng.randrange(1, 4), "xor2": rng.randrange(1, 4)},
                                    rng.randrange(1, 6), "Synthetic count class", "class_restriction")]
            result = propose(m, p, f)
            self.assertEqual(result["status"], "checked", result)
            lower = Fraction(result["verification"]["lower_bound"])
            c = f["obligations"][0]
            for n, k in itertools.product(range(7), repeat=2):
                if c["coefficients"]["xor1"]*n+c["coefficients"]["xor2"]*k < c["minimum"]:
                    continue
                time = max(Fraction(m["operations"]["xor1"]["demand"][r]*n+
                                    m["operations"]["xor2"]["demand"][r]*k, cap)
                           for r, cap in m["resources"].items())
                self.assertLessEqual(lower, time)

    def test_exact_vertex_regression_and_bounded_search_status(self):
        m, p, f, _ = parallel_case()
        m["resources"] = {"left": 2, "right": 1}
        m["operations"]["xor1"]["demand"] = {"left": 3, "right": 0}
        m["operations"]["xor2"]["demand"] = {"left": 0, "right": 2}
        f["obligations"] = [cut("work", {"xor1": 1, "xor2": 3}, 4, "Regression count class", "class_restriction")]
        result = propose(m, p, f)
        self.assertEqual(result["verification"]["lower_bound"], "24/13")
        self.assertEqual(result["primal"]["counts"], {"xor1": "16/13", "xor2": "12/13"})
        self.assertTrue(result["verification"]["relaxation_optimal"])
        bounded = propose(m, p, f, max_bases=0)
        self.assertEqual(bounded["status"], "no_witness_pair")
        self.assertFalse(bounded["proves_infeasibility"])
        self.assertFalse(bounded["search"]["dual"]["enumeration_complete"])

    def test_saved_reports_are_not_trusted_by_replay(self):
        from examples import run
        from replay import replay
        artifact = run()
        artifact["cases"][0]["proposal"]["verification"] = {"lower_bound": "100000"}
        checked = replay(artifact)
        self.assertTrue(checked["accepted"])
        self.assertEqual(checked["results"][0]["checks"]["relaxation"]["lower_bound"], "2")
        artifact["cases"][0]["proposal"]["dual"]["lambda"]["low"] = "100000"
        self.assertFalse(replay(artifact)["accepted"])
        self.assertFalse(replay({"format": "kelana-resource-certificates/1", "cases": []})["valid"])

    def test_feasible_schedule_without_semantics_cannot_prove_domination(self):
        m = copy.deepcopy(self.m)
        del m["operations"]["xor3"]["table"]
        competitor = copy.deepcopy(self.competitor)
        competitor["binding"]["model"] = digest(m)
        solution = propose(m, self.p, self.f)
        self.assertFalse(verify_schedule(m, self.p, competitor)["correctness_replayed"])
        self.assertFalse(compare(m, self.p, self.f, solution["dual"], competitor)["valid"])


if __name__ == "__main__":
    unittest.main()
