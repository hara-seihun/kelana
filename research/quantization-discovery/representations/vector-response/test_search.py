"""Tiny independent composed-map check for discrete response search."""
import numpy as np
from search import fit


def main():
    rng = np.random.default_rng(913)
    x = rng.normal(size=(12, 7)).astype(np.float32)
    down = rng.normal(size=(3, 5)).astype(np.float32)
    table = rng.normal(size=(8, 2)).astype(np.float16)
    codes = rng.integers(0, 8, size=(5, 7), dtype=np.uint8)
    truth = rng.integers(0, 8, size=codes.shape, dtype=np.uint8)

    def direct(indices):
        weights = table.astype(np.float64)[indices]
        gate = x.astype(np.float64) @ weights[:, :, 0].T
        up = x.astype(np.float64) @ weights[:, :, 1].T
        return ((gate / (1 + np.exp(-gate))) * up) @ down.astype(np.float64).T

    target = direct(truth).astype(np.float32)
    chosen, history, changed = fit(codes.copy(), table, down, x, target, x, target, 2, 4)
    measured = np.linalg.norm(direct(chosen) - target) / np.linalg.norm(target)
    assert changed > 0
    assert measured < np.linalg.norm(direct(codes) - target) / np.linalg.norm(target)
    assert abs(measured - min(h['check_relative_rms'] for h in history)) < 2e-6
    assert all(b['train_relative_rms'] <= a['train_relative_rms'] + 2e-6 for a, b in zip(history, history[1:]))
    exact, _, edits = fit(codes.copy(), table, down, x, direct(codes).astype(np.float32),
                          x, direct(codes).astype(np.float32), 1, 4)
    assert edits == 0 and np.array_equal(exact, codes)
    print('discrete response search matches independent float64 map; exact image retained')


if __name__ == '__main__':
    main()
