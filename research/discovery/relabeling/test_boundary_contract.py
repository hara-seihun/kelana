import unittest
from boundary import BoundaryError, CostModel, synthesise, word_grammar, verify


class BoundaryContractTests(unittest.TestCase):
    def test_uniform_nonunit_charge_respects_cost_bound(self):
        grammar = word_grammar(3)
        target = tuple(x ^ 1 for x in range(8))
        model = CostModel(default=2)
        self.assertIsNone(synthesise(target, grammar, max_cost=1, model=model))
        result = synthesise(target, grammar, max_cost=2, model=model)
        self.assertEqual(result.cost, 2)
        self.assertEqual(result.searched_to, 2)
        self.assertTrue(verify(result, target, grammar))

    def test_invalid_costs_fail_before_search(self):
        for value in (0, -1, 1.5, True):
            with self.assertRaises(BoundaryError):
                CostModel(default=value)
            with self.assertRaises(BoundaryError):
                CostModel(charges=(("xor_constant", value),))
        with self.assertRaises(BoundaryError):
            CostModel(charges=(("xor_constant", 1), ("xor_constant", 2)))
        with self.assertRaises(BoundaryError):
            synthesise(tuple(range(8)), word_grammar(3), max_cost=-1)


if __name__ == "__main__":
    unittest.main()
