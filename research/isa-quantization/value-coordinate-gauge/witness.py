"""Exact paid value-coordinate permutation witness; no model/source fitting."""
from fractions import Fraction as F
from pathlib import Path
import hashlib
import json
import struct

HERE = Path(__file__).resolve().parent
PERM = (0, 2, 4, 1, 3, 5)
WEIGHT = (0, 10, 1, 11, 2, 12)
OUTPUT = (0, 0, 1, -1, 0, 0)
TOKENS = (1, 2)


def nearest_even(x):
    low = x.numerator // x.denominator
    fraction = x - low
    return low + int(fraction > F(1, 2) or (fraction == F(1, 2) and low % 2))


def pack_cache(values):
    codes = []
    fields = []
    for start in (0, 3):
        group = values[start:start + 3]
        lo, hi = min(group), max(group)
        step = hi - lo
        fields.extend((lo, step))
        codes.extend(0 if not step else nearest_even(F(v - lo, step)) for v in group)
    assert all(c in (0, 1) for c in codes)
    return bytes([sum(c << d for d, c in enumerate(codes))]) + struct.pack('<4e', *fields)


def build(name, perm):
    w = tuple(WEIGHT[d] for d in perm)
    o = tuple(OUTPUT[d] for d in perm)
    blob = struct.pack('<12b', *(w + o))
    blob += b''.join(pack_cache(tuple(x * z for z in w)) for x in TOKENS)
    assert len(blob) == 30
    path = HERE / name
    path.write_bytes(blob)
    return path


def read_image(path):
    blob = path.read_bytes()
    assert len(blob) == 30
    w = tuple(F(x) for x in struct.unpack_from('<6b', blob, 0))
    o = tuple(F(x) for x in struct.unpack_from('<6b', blob, 6))
    rows = []
    for pos, token in enumerate(TOKENS):
        offset = 12 + 9 * pos
        bits = blob[offset]
        assert bits < 64
        fields = tuple(F(x) for x in struct.unpack_from('<4e', blob, offset + 1))
        row = tuple(fields[2 * (d // 3)] + ((bits >> d) & 1) * fields[2 * (d // 3) + 1] for d in range(6))
        source = tuple(token * x for x in w)
        for g in (0, 1):
            lo, step = fields[2 * g:2 * g + 2]
            assert lo == min(source[3 * g:3 * g + 3])
            assert lo + step == max(source[3 * g:3 * g + 3])
            for d in range(3 * g, 3 * g + 3):
                code = (bits >> d) & 1
                assert code == nearest_even((source[d] - lo) / step)
        rows.append((source, row))
    return w, o, rows


def dot(x, y):
    return sum((a * b for a, b in zip(x, y)), F(0))


def main():
    identity = tuple(range(6))
    paths = [build('original.bin', identity), build('grouped.bin', PERM)]
    result = {'grammar': {'model_V_int8': 6, 'model_O_int8': 6,
                          'two_token_cache_codes': 2, 'two_token_cache_FP16_fields': 16,
                          'total_bytes_each': 30}, 'arms': []}
    decoded = []
    for path in paths:
        w, o, rows = read_image(path)
        assert dot(w, o) == -10
        outputs = [dot(row, o) for _, row in rows]
        sources = [dot(source, o) for source, _ in rows]
        key_independent_value_sse = sum((dot(tuple(a - b for a, b in zip(row, source)),
                                                tuple(a - b for a, b in zip(row, source)))
                                          for source, row in rows), F(0))
        probabilities = (F(1, 4), F(3, 4))
        teacher, observed = dot(probabilities, sources), dot(probabilities, outputs)
        assert teacher == F(-35, 2)
        result['arms'].append({'image': path.name, 'bytes': path.stat().st_size,
                              'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                              'per_token_teacher_output': list(map(str, sources)),
                              'per_token_quantized_output': list(map(str, outputs)),
                              'cache_value_squared_error': str(key_independent_value_sse),
                              'teacher_mixture': str(teacher), 'candidate_mixture': str(observed),
                              'mixture_squared_error': str((observed - teacher) ** 2)})
        decoded.append((w, o, rows))
    assert result['arms'][0]['cache_value_squared_error'] == result['arms'][1]['cache_value_squared_error'] == '10'
    assert result['arms'][0]['mixture_squared_error'] == '49/4'
    assert result['arms'][1]['mixture_squared_error'] == '0'
    original, grouped = decoded
    assert grouped[0] == tuple(original[0][d] for d in PERM)
    assert grouped[1] == tuple(original[1][d] for d in PERM)
    # Every possible later probability mixture remains exact for this finite
    # producer: each decoded grouped token already has the correct O response.
    assert all(dot(source, grouped[1]) == dot(row, grouped[1]) for source, row in grouped[2])
    # The exact multihead value response is linear; its Gram retains head cross terms.
    probability_heads = ((F(1, 4), F(3, 4)), (F(2, 3), F(1, 3)))
    output_heads = (OUTPUT, (0, 0, 0, 1, 0, 0))
    coefficient = tuple(sum((probability_heads[h][i] * output_heads[h][d] for h in range(2)), F(0))
                        for i in range(2) for d in range(6))
    error = tuple(row[d] - source[d] for source, row in original[2] for d in range(6))
    gram_energy = sum((coefficient[i] * coefficient[j] * error[i] * error[j]
                       for i in range(12) for j in range(12)), F(0))
    assert gram_energy == dot(coefficient, error) ** 2
    head_errors = tuple(sum((probability_heads[h][i] * output_heads[h][d] * error[6 * i + d]
                              for i in range(2) for d in range(6)), F(0)) for h in range(2))
    separate_head_squares = sum((z * z for z in head_errors), F(0))
    assert gram_energy == F(169, 36) and separate_head_squares == F(505, 36)
    result['gram_witness_squared_response'] = str(gram_energy)
    result['incorrect_separate_head_square_sum'] = str(separate_head_squares)
    result['scope'] = 'Exact finite rational source and paid group permutation; no real-model or native claim.'
    result['strong_control'] = 'Direct response -10*x, or one-bit token labels followed by that response, is exact and cheaper.'
    (HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
