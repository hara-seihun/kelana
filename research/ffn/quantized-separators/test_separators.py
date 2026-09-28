#!/usr/bin/env python3
"""Small independent boundary cases for the separation certificate."""
import unittest
import numpy as np
from separators import certificate


class Separators(unittest.TestCase):
    def test_one(self):
        result = certificate(np.array([[0], [1], [2]]))
        self.assertEqual(result['minimum'], 1)

    def test_two(self):
        result = certificate(np.array([[0, 0], [0, 1], [1, 0], [1, 1]]))
        self.assertEqual(result['minimum'], 2)

    def test_three(self):
        result = certificate(np.array([[n >> b & 1 for b in range(3)] for n in range(8)]))
        self.assertEqual(result['minimum'], 3)

    def test_collision(self):
        result = certificate(np.array([[0, 1], [0, 1], [1, 0]]))
        self.assertFalse(result['separable'])


if __name__ == '__main__':
    unittest.main()
