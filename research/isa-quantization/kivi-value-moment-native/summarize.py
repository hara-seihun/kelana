"""Reduce the single frozen native run; no device work or sample selection."""
import hashlib
import json
import math
import re
import statistics
from pathlib import Path

HERE = Path(__file__).resolve().parent
SHA = lambda b: hashlib.sha256(b).hexdigest()


def distribution(xs):
    return {'n': len(xs), 'median': statistics.median(xs), 'min': min(xs),
            'max': max(xs), 'mean': statistics.mean(xs)}


def paired(rows, field):
    pairs = {}
    for row in rows:
        value = row[field]
        assert math.isfinite(value) and value > 0
        key = (row['window'], row['round'], row['t'])
        assert row['mode'] not in pairs.setdefault(key, {})
        pairs[key][row['mode']] = value
    assert all(set(p) == {0, 1} for p in pairs.values())
    return {'control': distribution([p[0] for p in pairs.values()]),
            'moment': distribution([p[1] for p in pairs.values()]),
            'paired_ratio': distribution([p[1]/p[0] for p in pairs.values()]),
            'moment_faster': sum(p[1] < p[0] for p in pairs.values())}


def main():
    from prelaunch import receipt
    pre = receipt()
    assert pre == json.loads((HERE/'prelaunch-receipt.json').read_text())
    accept = []; timing = []; lifecycles = []; identities = []; pids = set()
    counts = dict(frames=0, ordered_records=0, moment_checks=0)
    for window in range(4):
        tag = f'held-{window}'
        for phase in ('accept', 'timing'):
            path = HERE/f'{phase}-{tag}-receipt.json'
            result = json.loads(path.read_text())
            raw = (HERE/f'{phase}-{tag}.jsonl').read_bytes()
            attempt = (HERE/f'attempt-{phase}-{tag}.txt').read_bytes()
            assert result['trace_sha256'] == SHA(raw)
            assert result['attempt_sha256'] == SHA(attempt)
            assert result['source_hash'] == pre['source_hash']
            assert result['binary_sha256'] == pre['binary_sha256']
            before = re.search(rb'resident_before=([1-9][0-9]*) state=active', attempt)
            after = re.search(rb'gpu_run_exit=0 resident_after=([1-9][0-9]*) state=active', attempt)
            assert before and after and before[1] == after[1]
            pids.add(int(before[1]))
            rows = result['rows']
            assert all(r['max_abs'] <= .005 and r['relative_l2'] <= .005 for r in rows)
            rounds = 1 if phase == 'accept' else 4
            assert {(r['round'], r['mode'], r['t']) for r in rows} == {
                (k, arm, t) for k in range(rounds) for arm in (0, 1) for t in (128, 256)}
            if phase == 'accept':
                audit = result['audit']
                assert SHA((HERE/f'{tag}-snapshots.bin.zst').read_bytes()) == audit['compressed_sha256']
                for name in counts: counts[name] += audit[name]
                for output in result['full_outputs']:
                    actual = HERE/f"{tag}-t{output['t']}-mode{output['mode']}-actual.f32"
                    assert actual.stat().st_size == 4096 and SHA(actual.read_bytes()) == output['actual_sha256']
                accept.extend(result['full_outputs'])
            else:
                timing.extend(rows)
                lifecycles.extend(result['lifecycle'])
            identities.append({'phase': phase, 'window': tag, 'receipt_sha256': SHA(path.read_bytes()),
                               'trace_sha256': SHA(raw), 'attempt_sha256': SHA(attempt)})
    assert len(accept) == 16 and len(timing) == 64 and len(lifecycles) == 32
    fields = ('step_event_us', 'compute_span_us', 'input_span_us', 'step_wall_us')
    sse = {name: sum(x['teacher_sse'] for x in accept if x['mode'] == arm)
           for arm, name in enumerate(('control', 'moment'))}
    result = {
        'scope': 'one frozen empty-start resident layer0 KIVI2/moment run; four held streams, t128/t256 only',
        'source_hash': pre['source_hash'], 'binary_sha256': pre['binary_sha256'],
        'resident_pids_before_and_after': sorted(pids), 'acceptance_counts': counts,
        'full_output_guards': len(accept), 'max_abs': max(x['max_abs'] for x in accept),
        'max_relative_l2': max(x['relative_l2'] for x in accept),
        'actual_teacher_sse': sse, 'sse_fraction_improvement': 1-sse['moment']/sse['control'],
        'timing': {key: paired(timing, key) for key in fields},
        'per_position': {str(t): {key: paired([r for r in timing if r['t'] == t], key) for key in fields}
                         for t in (128, 256)},
        'lifecycle_wall_us': {str(arm): {key: distribution([x[key] for x in lifecycles if x['mode'] == arm])
                                  for key in ('arm_allocation_us', 'replay_256_wall_us', 'arm_teardown_us', 'arm_total_wall_us')}
                              for arm in (0, 1)},
        'bill': pre['bill'], 'receipt_identities': identities,
        'limitations': 'Times are original two full-query flush-boundary steps, not average token throughput. Lifecycle has all256 updates but only two queries. No layer1 device result, kernel variant or resampling.'}
    (HERE/'results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'actual_sse': sse, 'event': result['timing']['step_event_us'], 'acceptance': counts}))


if __name__ == '__main__':
    main()
