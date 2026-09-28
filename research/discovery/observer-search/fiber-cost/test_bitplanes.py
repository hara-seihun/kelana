import math
import unittest
from itertools import product

from bitplanes import TRITS, WEIGHTS, bfe, code, masks, packed, record


class PackedSignTest(unittest.TestCase):
    def test_every_family_against_independent_silu(self):
        for g, u in product(WEIGHTS, repeat=2):
            pos, neg = masks(g, u)
            self.assertEqual(pos & neg, 0)
            for x in TRITS:
                z = sum(a * b for a, b in zip(g, x))
                v = sum(a * b for a, b in zip(u, x))
                silu_product = z / (1 + math.exp(-z)) * v
                expected = (silu_product > 0) - (silu_product < 0)
                self.assertEqual(packed(x, g, u), expected, (g, u, x))
                self.assertEqual(bfe(pos, code(x)) - bfe(neg, code(x)), expected)

    def test_cost_scope_and_counts(self):
        result = record()
        self.assertEqual(result["checked_input_family_pairs"], 18_252)
        self.assertEqual(result["three_value_maps"], 432)
        self.assertEqual(result["distinct_endpoint_maps"], 182)
        self.assertEqual({code(x) for x in TRITS}, set(range(27)))


if __name__ == "__main__":
    unittest.main()
