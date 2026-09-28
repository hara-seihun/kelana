from fractions import Fraction
import unittest

from certificates import binding
from export_lean import instance, render


class LeanExportTest(unittest.TestCase):
    def test_independent_row_and_price_scaling(self):
        model = {"unit": "ticks", "assumptions": ["test machine"],
                 "resources": {"r": "2/5"}, "operations": {"op": {"demand": {"r": "3/7"}}}}
        problem = {"id": "scaled-test"}
        family = {"allowed_operations": ["op"], "obligations": [
            {"id": "cut", "coefficients": {"op": "2/3"}, "minimum": "5/11",
             "role": "necessary_for_target", "premise": "declared test premise"}]}
        dual = {"binding": binding(model, problem, family), "lambda": {"cut": "9/14"}, "mu": {"r": 1}}
        case = {"name": "rational rows", "model": model, "problem": problem, "family": family,
                "proposal": {"dual": dual}}
        x = instance(case)
        self.assertEqual(x["A"], [[22]])
        self.assertEqual(x["b"], [15])
        self.assertEqual(x["D"], [[15]])
        self.assertEqual(x["c"], [14])
        self.assertEqual(Fraction(x["work"], x["service"]), Fraction(225, 308))
        for col in range(1):
            self.assertLessEqual(sum(a[col]*p for a,p in zip(x["A"], x["lambda"])),
                                 sum(d[col]*p for d,p in zip(x["D"], x["mu"])))
        self.assertIn("by decide", render([case]))


if __name__ == "__main__":
    unittest.main()
