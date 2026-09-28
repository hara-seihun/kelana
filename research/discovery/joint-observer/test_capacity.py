import unittest
import numpy as np
from capacity import capacity_bounds
from trained import centered_basis, fiber_basis, family_basis, residual_energy, quantize, dequantize


def partitions(n):
    def extend(labels):
        if len(labels) == n:
            yield labels
        else:
            for k in range(max(labels)+2):
                yield from extend(labels+[k])
    yield from extend([0])


class CapacityTests(unittest.TestCase):
    def test_lower_bound_against_every_small_partition(self):
        for seed in range(4):
            y = np.random.default_rng(seed).normal(size=(5, 3))
            y -= y.mean(axis=0)
            g = y@y.T
            opt = {m: float("inf") for m in range(1, 6)}
            for labels in partitions(5):
                error = sum(np.sum((y[np.array(labels) == k]-y[np.array(labels) == k].mean(axis=0))**2)
                            for k in set(labels))/np.trace(g)
                for m in range(len(set(labels)), 6):
                    opt[m] = min(opt[m], error)
            for row in capacity_bounds(g, range(1, 6)):
                self.assertLessEqual(row["nearest_neighbor_dual_squared_error_lower_bound"],
                                     opt[row["capacity"]]+1e-12)
                self.assertGreaterEqual(row["nearest_neighbor_dual_squared_error_lower_bound"]+1e-12,
                                        row["closest_pair_squared_error_lower_bound"])

    def test_simplex_is_tight(self):
        y = np.eye(5)-np.ones((5, 5))/5
        for row in capacity_bounds(y@y.T, range(1, 6)):
            self.assertAlmostEqual(row["nearest_neighbor_dual_squared_error_lower_bound"],
                                   (5-row["capacity"])/4)

    def test_duplicate_outputs_and_two_states(self):
        for y in (np.array([[0.], [0.], [1.], [1.]]), np.array([[0.], [1.]])):
            y -= y.mean(axis=0)
            bound = capacity_bounds(y@y.T, (1, 2))
            self.assertAlmostEqual(bound[0]["relative_rms_lower_bound"], 1)
            self.assertAlmostEqual(bound[1]["relative_rms_lower_bound"], 0)

    def test_projection_error_decomposition(self):
        h = np.repeat(np.arange(-5, 6), 2).astype(float)
        y = np.random.default_rng(73).normal(size=(22, 4))
        y -= y.mean(axis=0)
        b, f = family_basis(h), fiber_basis(h)
        restricted = b@(b.T@y)
        arbitrary = f@(f.T@y)
        np.testing.assert_allclose(np.sum((y-restricted)**2),
                                   np.sum((y-arbitrary)**2)+np.sum((arbitrary-restricted)**2))
        self.assertAlmostEqual(residual_energy(y@y.T, b), np.sum((y-restricted)**2))

    def test_quantizer_grid_and_zero_block(self):
        x = np.zeros((2, 128)); x[1] = np.linspace(-1, 1, 128)
        q, s = quantize(x, 127)
        self.assertTrue(np.isfinite(s).all())
        np.testing.assert_array_equal(q[0], 0)
        np.testing.assert_array_equal(np.max(np.abs(q), axis=1), [0, 127])
        np.testing.assert_allclose(dequantize(x, 127), q*s)


if __name__ == "__main__":
    unittest.main()
