"""Exact finite response/frontier oracle for the declared four-point byte grammar."""
from itertools import product
import json

X = range(4)
TEACHERS = ((0, 1, 0, 1), (0, 1, 0, 1), (0, 1, 0, 2))
CODE = {'constant': 1, 'affine': 2, 'direct': 2, 'shared': 3}
PER_TILE = {'constant': (1, 1), 'affine': (2, 2), 'direct': (4, 2), 'shared': (1, 2)}
TABLES = tuple(product(range(3), repeat=4))


def error(a, b):
    return sum((x-y)**2 for x, y in zip(a, b))


def variants(teacher, table):
    c = min(((error(teacher, (v,)*4), v) for v in range(3)))
    a = min(((error(teacher, tuple(s*x+b for x in X)), s, b)
             for s in range(-2, 3) for b in range(-2, 3)))
    return (('constant', c[0], c[1]), ('affine', a[0], (a[1], a[2])),
            ('direct', 0, teacher), ('shared', error(teacher, table), table))


def options(teachers=TEACHERS):
    out = {}
    for table in TABLES:
        choices = [variants(t, table) for t in teachers]
        for assignment in product(*choices):
            used = frozenset(c[0] for c in assignment)
            if 'shared' not in used and table != TABLES[0]:
                continue
            e = sum(c[1] for c in assignment)
            b = sum(PER_TILE[c[0]][0] for c in assignment) + sum(CODE[k] for k in used)
            if 'shared' in used:
                b += 4  # One serialized signed-byte dictionary response.
            w = sum(PER_TILE[c[0]][1] for c in assignment)
            p = 4 if 'shared' in used else 0  # Additional prepared live dictionary bytes.
            key = (e, b, w, p)
            witness = {'table': table if 'shared' in used else None,
                       'tiles': [(k, payload) for k, _, payload in assignment]}
            out.setdefault(key, witness)
    return out


def frontier(points):
    keys = tuple(points)
    return {k: points[k] for k in keys if not any(
        all(a <= b for a, b in zip(q, k)) and q != k for q in keys)}


def run():
    all_points = options()
    front = frontier(all_points)
    output = {'teachers': TEACHERS,
              'grammar': {'code_bytes': CODE, 'tile_bytes_work': PER_TILE,
                          'dictionary_bytes': 4, 'dictionary_prepared_bytes': 4},
              'feasible_vectors': len(all_points),
              'frontier': [{'error': k[0], 'bytes': k[1], 'work': k[2],
                            'prepared_bytes': k[3], **front[k]}
                           for k in sorted(front)]}
    print(json.dumps(output, separators=(',', ':'), sort_keys=True))


if __name__ == '__main__':
    run()
