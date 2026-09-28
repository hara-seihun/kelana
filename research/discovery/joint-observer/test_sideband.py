import unittest

from sideband import bits_needed, carrier, fibers, mask_witnesses, repair, report


class SidebandTest(unittest.TestCase):
    def test_minimality_and_inverse(self):
        groups = fibers()
        self.assertEqual(sum(map(len, groups.values())), 27)
        self.assertEqual(max(map(len, groups.values())), 3)
        self.assertEqual(bits_needed(), 2)
        self.assertEqual({len(v) for v in groups.values()}, {2, 3})
        inverse, collision = repair([q & 3 for q in range(27)])
        self.assertIsNone(collision)
        for q in range(27):
            self.assertEqual(inverse[carrier(q), q & 3], q)

    def test_all_one_bit_boolean_functions_are_insufficient(self):
        # The three inputs in one fiber force a collision for any assignment
        # into two values. Enumerate their eight assignments independently.
        group = fibers()[-5]
        for assignment in range(8):
            labels = [(assignment >> i) & 1 for i in range(3)]
            self.assertLess(len(set(labels)), len(group))
        self.assertEqual(repair([q & 1 for q in range(27)])[1], (0, 2))

    def test_five_bit_mask_grammar(self):
        for mask in range(32):
            _, collision = repair([q & mask for q in range(27)])
            self.assertEqual(collision is None, mask in mask_witnesses())
        self.assertEqual(mask_witnesses(), [m for m in range(32) if m & 3 == 3])
        self.assertEqual(len(report()["inverse"]), 27)

    def test_outside_domain(self):
        for q in (-1, 27, 32):
            with self.assertRaises(ValueError):
                carrier(q)


if __name__ == "__main__":
    unittest.main()
