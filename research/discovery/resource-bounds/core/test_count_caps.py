import unittest

from certificates import binding, count_caps
from examples import xor_case


class CountCapsTest(unittest.TestCase):
    def fixture(self):
        model, problem, family, _, _ = xor_case()
        model['operations']['waste'] = {'demand': {'valu': 3}}
        family['allowed_operations'].append('waste')
        dual = {'binding': binding(model, problem, family),
                'lambda': {'low': 1, 'high': 1}, 'mu': {'valu': 1}}
        return model, problem, family, dual

    def test_tight_and_near_optimal_vocabularies(self):
        args = self.fixture()
        tight = count_caps(*args, 2)
        self.assertTrue(tight['valid'])
        self.assertEqual(tight['counts_at_most'], {'waste': 0})
        self.assertEqual(set(tight['zero_slack_is_unconstrained']), {'xor1', 'xor2'})
        self.assertEqual(count_caps(*args, 5)['counts_at_most'], {'waste': 1})
        self.assertEqual(count_caps(*args, '49/10')['counts_at_most'], {'waste': 0})
        self.assertTrue(count_caps(*args, 1)['budget_infeasible'])
        for a in range(1, 5):
            for b in range(1, 5):
                for w in range(4):
                    caps = count_caps(*args, a+b+3*w)
                    self.assertLessEqual(w, caps['counts_at_most']['waste'])

    def test_rejects_changed_and_invalid_inputs(self):
        args = self.fixture()
        self.assertFalse(count_caps(*args, -1)['valid'])
        self.assertFalse(count_caps(*args, 2.0)['valid'])
        args[0]['resources']['valu'] = 2
        self.assertFalse(count_caps(*args, 2)['valid'])


if __name__ == '__main__':
    unittest.main()
