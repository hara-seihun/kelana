"""Exact 64-byte cache-line layout search for the frozen 192-coordinate V/O images.

Each group's BF16 coordinates stay contiguous and in order. A group can be moved
as a unit, and whole 8-byte slots may be left empty. No duplication or splitting.
"""
from functools import lru_cache
import json
from pathlib import Path

ROOT = Path('/path/to/workspace/data/kelana-subbit/value-observer')
LINE_SLOTS = 8  # one slot is four BF16 coordinates


def solve(ranks, max_lines):
    widths = tuple(r // 4 for r in ranks)
    assert len(widths) == 8 and all(0 < w <= 8 for w in widths)
    full = (1 << len(widths)) - 1

    @lru_cache(None)
    def best(mask, pos):
        if mask == full:
            return (0, 0, ())
        choices = []
        for group, width in enumerate(widths):
            if mask & (1 << group):
                continue
            for start in range(pos, ((pos + 7) // 8) * 8 + 1):
                end = start + width
                if end > max_lines * 8:
                    continue
                crossing = int(start // 8 != (end - 1) // 8)
                sub = best(mask | (1 << group), end)
                if sub is not None:
                    choices.append((crossing + sub[0], end if not sub[2] else sub[1],
                                    ((group, start * 8, width * 8),) + sub[2]))
        return min(choices) if choices else None

    result = best(0, 0)
    if result is None:
        return None
    crossings, end, layout = result
    return {'lines': (end + 7) // 8, 'crossings': crossings,
            'separate_head_requests': 2 * (8 + crossings),
            'paired_head_requests': 8 + crossings,
            'layout': [{'group': g, 'offset': start, 'bytes': size} for g, start, size in layout],
            'visited_states': best.cache_info().currsize}


def main():
    output = {'grammar': 'eight unsplit BF16 GQA groups; 8-byte slot alignment; reorder groups and insert 8-byte gaps; 64-byte lines; two heads per group'}
    for layer in (0, 14):
        receipt = json.loads((ROOT / f'layer{layer:02d}-causal-prune.json').read_text())
        output[f'layer{layer:02d}'] = {}
        for arm in ('uniform_24', 'train_causal_optimum', 'full_28'):
            ranks = receipt['arms'][arm]['ranks']
            image_sha = receipt['arms'][arm]['image_sha256']
            if arm != 'full_28':
                fitted = json.loads((ROOT / f'layer{layer:02d}-causal-refit-{arm}.json').read_text())
                assert fitted['ranks'] == ranks
                image_sha = fitted['image_sha256']
            pos = 0
            current_crossings = 0
            for rank in ranks:
                width = rank * 2
                current_crossings += int(pos // 64 != (pos + width - 1) // 64)
                pos += width
            output[f'layer{layer:02d}'][arm] = {
                'ranks': ranks, 'image_sha256': image_sha,
                'current_order_crossings': current_crossings,
                'by_max_lines': {str(n): solve(ranks, n) for n in range(6, 9) if n * 32 >= sum(ranks)}
            }
    print(json.dumps(output, indent=2))


if __name__ == '__main__':
    main()
