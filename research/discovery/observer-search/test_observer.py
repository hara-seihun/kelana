import unittest
from itertools import product
from cover import Feature, minimum_cover
from observer import (Machine, Instruction, decoder_search, distinguishing_word,
                      factor, fibers, stable_quotient, suffix_observations)


class ObserverTests(unittest.TestCase):
    def test_factor_exhaustively(self):
        for carrier in product(range(3), repeat=3):
            for target in product(range(2), repeat=3):
                result = factor(carrier, target)
                expected = all(carrier[i] != carrier[j] or target[i] == target[j]
                               for i in range(3) for j in range(3))
                self.assertEqual(result.sufficient, expected)
                if expected:
                    self.assertEqual(tuple(result.decoder[c] for c in carrier), target)
                else:
                    w = result.collision
                    self.assertEqual(carrier[w.left], carrier[w.right])
                    self.assertNotEqual(target[w.left], target[w.right])
        self.assertEqual(dict(factor([], []).decoder), {})
        with self.assertRaises(ValueError):
            factor([0], [])

    def test_all_three_state_two_transition_machines(self):
        words = [()] + [(a,) for a in ("a", "b")] + list(product(("a", "b"), repeat=2))
        tables = list(product(range(3), repeat=3))
        for observation in product(range(2), repeat=3):
            for a in tables:
                for b in tables:
                    machine = Machine(observation, {"a": a, "b": b})
                    q = stable_quotient(machine)
                    # At most n-1 strict refinements: all words through length 2 suffice here.
                    signatures = tuple(tuple(observation[machine.after(s, w)] for w in words)
                                       for s in range(3))
                    self.assertEqual(q.classes, fibers(signatures))
                    for i in range(3):
                        self.assertEqual(q.machine.observation[q.classes[i]], observation[i])
                        for name, table in machine.transitions.items():
                            self.assertEqual(q.machine.transitions[name][q.classes[i]], q.classes[table[i]])
                        for j in range(i, 3):
                            word = distinguishing_word(machine, i, j)
                            available = [w for w in words if observation[machine.after(i, w)] != observation[machine.after(j, w)]]
                            if available:
                                self.assertEqual(len(word), min(map(len, available)))
                                self.assertNotEqual(observation[machine.after(i, word)], observation[machine.after(j, word)])
                            else:
                                self.assertIsNone(word)

    def test_fixed_suffix_matches_direct_execution(self):
        machine = Machine((0, 1, 0, 1), {"shift": (0, 0, 1, 1), "inc": (1, 2, 3, 0)})
        word = ("inc", "shift", "inc")
        for k, observation in enumerate(suffix_observations(machine, word)):
            self.assertEqual(observation, tuple(machine.observation[machine.after(s, word[k:])] for s in range(4)))

    def test_validation_and_owned_tables(self):
        table = [1, 0]
        machine = Machine((0, 1), {"flip": table})
        table[0] = 0
        self.assertEqual(machine.transitions["flip"], (1, 0))
        with self.assertRaises(TypeError):
            machine.transitions["flip"] = (0, 1)
        for bad in ((0,), (0, 2), (0, -1), (0, 1.0)):
            with self.assertRaises(ValueError):
                Machine((0, 1), {"bad": bad})
        with self.assertRaises(ValueError):
            Machine((), {})
        with self.assertRaises(ValueError):
            machine.after(-1, ())

    def test_costed_decoder_keeps_numeric_labels(self):
        domain = tuple(range(8))
        instr = [Instruction("and1", tuple(x & 1 for x in domain)),
                 Instruction("xor1", tuple(x ^ 1 for x in domain))]
        target = tuple(x & 1 for x in domain)
        self.assertEqual(decoder_search(domain, target, instr, 3).cost, 1)
        other = tuple(x ^ 1 for x in domain)
        self.assertEqual(fibers(domain), fibers(other))
        self.assertEqual(decoder_search(other, target, instr, 3).cost, 2)
        self.assertEqual(decoder_search(other, target, instr, 1).status, "exhausted_bound")
        self.assertEqual(decoder_search(domain, target, instr, 3, 1).status, "state_limit")
        self.assertEqual(decoder_search(domain, domain, instr, 0).program, ())
        self.assertEqual(decoder_search([0]*8, target, instr, 3).status, "exhausted_bound")

    def test_feature_cover_against_all_subsets(self):
        menu = [Feature("parity", (0, 1, 1, 0), 1), Feature("carry", (0, 0, 0, 1), 1),
                Feature("left", (0, 0, 1, 1), 2), Feature("right", (0, 1, 0, 1), 2)]
        for target in product(range(3), repeat=4):
            costs = []
            for selected in product((False, True), repeat=len(menu)):
                chosen = [f for f, keep in zip(menu, selected) if keep]
                joint = [tuple(f.values[i] for f in chosen) for i in range(4)]
                if factor(joint, target).sufficient:
                    costs.append(sum(f.cost for f in chosen))
            result = minimum_cover(target, menu)
            self.assertEqual(result.cost, min(costs))
            chosen = [f for f in menu if f.name in result.features]
            self.assertTrue(factor([tuple(f.values[i] for f in chosen) for i in range(4)], target).sufficient)
        self.assertEqual(minimum_cover((0, 1, 1, 2), menu).cost, 2)
        self.assertEqual(minimum_cover((0, 1, 1, 2), menu[:1]).status, "insufficient_menu")
        self.assertEqual(minimum_cover((0, 1, 1, 2), menu, 1).status, "state_limit")

    def test_weighted_search_against_brute_programs(self):
        instr = [Instruction("inc", (1, 2, 3, 0), 1), Instruction("flip", (3, 2, 1, 0), 2),
                 Instruction("and1", (0, 1, 0, 1), 1)]
        known = {}
        for length in range(5):
            for program in product(instr, repeat=length):
                cost = sum(i.cost for i in program)
                if cost > 4:
                    continue
                values = tuple(range(4))
                for i in program:
                    values = tuple(i.table[v] for v in values)
                known[values] = min(cost, known.get(values, cost))
        for target in product(range(4), repeat=4):
            result = decoder_search(tuple(range(4)), target, instr, 4)
            self.assertEqual(result.cost, known.get(target))
            self.assertEqual(result.status == "found", target in known)
            if result.program is not None:
                actual = tuple(range(4))
                by_name = {i.name: i for i in instr}
                for name in result.program:
                    actual = tuple(by_name[name].table[v] for v in actual)
                self.assertEqual(actual, target)


if __name__ == "__main__":
    unittest.main()
