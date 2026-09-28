import random
import unittest

import sympy as sp

from joint import SourceSpace, polynomial_features, label_features, target_coefficients, collision_witness
from discover import producer, native_consumer


class JointTests(unittest.TestCase):
    def test_function_rank_not_coefficient_nullity(self):
        h = [-1, 0, 1]
        result = SourceSpace(sp.Matrix(h)).intersect(polynomial_features(h, [1, 2, 3]))
        self.assertEqual(result.coefficient_nullity, 2)
        self.assertEqual(result.dimension, 1)  # h^3-h is zero, not a second observable.

    def test_intersection_against_independent_dimension_formula(self):
        rng = random.Random(917)
        for _ in range(40):
            a = sp.Matrix(6, 4, [rng.randrange(-1, 2) for _ in range(24)])
            b = sp.Matrix(6, 3, [rng.randrange(-1, 2) for _ in range(18)])
            result = SourceSpace(a).intersect(b)
            self.assertEqual(result.dimension, a.rank()+b.rank()-a.row_join(b).rank())
            self.assertEqual(result.values, a*result.source_coefficients)
            self.assertEqual(result.values, b*result.consumer_coefficients)

    def test_singular_and_full_spaces(self):
        a = sp.Matrix([[1, 2], [2, 4], [3, 6]])
        result = SourceSpace(a).intersect(a)
        self.assertEqual(result.dimension, 1)
        self.assertEqual(SourceSpace(sp.zeros(3, 2)).intersect(a).dimension, 0)
        self.assertEqual(SourceSpace(sp.eye(3)).intersect(a).dimension, 1)

    def test_numeric_labels_matter_to_restricted_consumers(self):
        a = sp.Matrix([-1, 0, 1])
        self.assertEqual(SourceSpace(a).intersect(polynomial_features([-1, 0, 1], [1])).dimension, 1)
        self.assertEqual(SourceSpace(a).intersect(polynomial_features([2, 0, 1], [1])).dimension, 0)
        # Both labelings are injective, so unrestricted decoders can do it.
        self.assertEqual(SourceSpace(a).intersect(label_features([2, 0, 1])).dimension, 1)

    def test_target_membership_and_collision_obstruction(self):
        b = polynomial_features([-1, 0, 1], [1, 2, 3])
        self.assertIsNotNone(target_coefficients(b, [-1, 0, 1]))
        self.assertIsNone(target_coefficients(b, [1, 1, 1]))
        self.assertEqual(collision_witness([0, 0, 1], [2, 3, 2])["second"], 1)
        self.assertIsNone(collision_witness([0, 0, 1], [2, 2, 3]))

    def test_exact_rational_inputs(self):
        self.assertEqual(polynomial_features([sp.Rational(1, 2)], [2])[0], sp.Rational(1, 4))
        with self.assertRaises(ValueError):
            polynomial_features([0.5], [1])
        with self.assertRaises(ValueError):
            SourceSpace([[0.5]])
        with self.assertRaises(ValueError):
            target_coefficients([[1]], [0.5])

    def test_native_range_boundary_and_producer(self):
        self.assertEqual([producer(q) for q in range(27)], [27*q//64-5 for q in range(27)])
        self.assertEqual(native_consumer(5, [7]*5), 14241535)
        self.assertEqual(native_consumer(-5, [7]*5), -14241535)
        # Signed24 truncation really matters; the unlimited-Int theorem is not a hardware theorem.
        self.assertNotEqual(native_consumer(5, [100]*5), sum(100*5**p for p in (1, 3, 5, 7, 9)))


if __name__ == "__main__":
    unittest.main()
