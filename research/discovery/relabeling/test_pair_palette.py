"""Regression: locally numbered refinement colors do not carry their meaning."""
import unittest
from itertools import permutations
from relabeling import Family, pair_refinement


class PairPaletteTests(unittest.TestCase):
    def test_point_plane_actions_separate_in_one_round(self):
        source = Family(7, (("a", (1, 3, 5, 2, 0, 6, 4)), ("b", (2, 6, 3, 4, 5, 1, 0))))
        target = Family(7, (("a", (2, 3, 6, 0, 1, 4, 5)), ("b", (4, 6, 1, 2, 5, 3, 0))))
        self.assertEqual(pair_refinement(source, rounds=0), pair_refinement(target, rounds=0))
        self.assertNotEqual(pair_refinement(source, rounds=1), pair_refinement(target, rounds=1))
        self.assertNotEqual(pair_refinement(source), pair_refinement(target))

    def test_palette_history_is_relabeling_invariant(self):
        source = Family(4, (("a", (1, 2, 3, 0)), ("b", (0, 0, 2, 1))))
        for p in permutations(range(4)):
            inverse = tuple(p.index(i) for i in range(4))
            moved = Family(4, tuple((name, tuple(p[t[inverse[x]]] for x in range(4)))
                                    for name, t in source.ops))
            self.assertEqual(pair_refinement(source), pair_refinement(moved))


if __name__ == "__main__":
    unittest.main()
