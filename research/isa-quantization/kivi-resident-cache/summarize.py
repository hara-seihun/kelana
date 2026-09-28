"""Aggregate retained acceptance and timing receipts; never launches a model or GPU."""
import hashlib
import json
from pathlib import Path
import re
import statistics
import struct

here = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
accept, timing, phases, attempts = [], [], 0, []
for w in range(4):
    window = f'held-{w}'
    for phase, target in [('accept', accept), ('timing', timing)]:
        p = here / f'{phase}-{window}-receipt.json'
        r = json.loads(p.read_text())
        assert r['trace_sha256'] == sha(here / f'{phase}-{window}.jsonl')
        assert len(r['rows']) == 4
        target.extend(r['rows'])
        if phase == 'accept':
            assert r['phase_audit']['backend'] == 'device'
            phases += r['phase_audit']['phases']
        attempt = (here / f'attempt-{phase}-{window}.txt').read_text()
        before = re.search(r'resident_before=(\d+) state=active', attempt)
        after = re.search(r'gpu_run_exit=0 resident_after=(\d+) state=active', attempt)
        assert before and after and int(before[1]) > 0 and before[1] == after[1]
        attempts.append({'phase': phase, 'window': window, 'resident_pid': int(before[1]),
                         'receipt_sha256': sha(p)})
assert phases == 4096 and len(accept) == len(timing) == 16
compiled = json.loads((here / 'compile-receipt.json').read_text())
for r in accept + timing:
    assert 0 <= r['max_abs'] <= .005 and 0 <= r['relative_l2'] <= .005

metrics = ['step_event_us', 'input_span_us', 'compute_span_us', 'step_wall_us']
by_mode = {}
for mode, name in [(0, 'conventional'), (1, 'dictionary')]:
    rows = [r for r in timing if r['mode'] == mode]
    by_mode[name] = {'count': len(rows), 'median': {k: statistics.median(r[k] for r in rows) for k in metrics},
                     'by_t': {str(t): {k: statistics.median(r[k] for r in rows if r['t'] == t) for k in metrics}
                              for t in [128, 256]}}
pairs = []
for w in range(4):
    for t in [128, 256]:
        c, d = [next(r for r in timing if r['window'] == f'held-{w}' and r['t'] == t and r['mode'] == mode)
                for mode in [0, 1]]
        pairs.append({'window': f'held-{w}', 't': t,
                      'dictionary_over_conventional_event': d['step_event_us'] / c['step_event_us'],
                      'event_delta_us': d['step_event_us'] - c['step_event_us']})

# Retained eight source outputs only; no omitted source Q or teacher is generated.
outputs = []
for w in range(4):
    for t in [128, 256]:
        stem = f'held-{w}-t{t}'
        teacher = here.parent / 'kivi-two-bit-dot-native' / f'{stem}-teacher.f32'
        truth = struct.unpack('<1024f', teacher.read_bytes())
        denominator = sum(x*x for x in truth)
        actual = []
        for mode in [0, 1]:
            p = here / f'{stem}-mode{mode}-actual.f32'
            y = struct.unpack('<1024f', p.read_bytes())
            actual.append(y)
            outputs.append({'window': f'held-{w}', 't': t, 'mode': mode, 'output_sha256': sha(p),
                            'teacher_sha256': sha(teacher), 'teacher_sse': sum((a-b)**2 for a,b in zip(y,truth)),
                            'teacher_denominator': denominator,
                            'source_relative_squared': sum((a-b)**2 for a,b in zip(y,truth))/denominator})
        assert max(abs(a-b) for a,b in zip(*actual)) <= .005
source_quality = {}
for mode,name in [(0,'conventional'), (1,'dictionary')]:
    rows = [r for r in outputs if r['mode'] == mode]
    source_quality[name] = sum(r['teacher_sse'] for r in rows)/sum(r['teacher_denominator'] for r in rows)
result = {'status': 'complete_scoped_resident_acceptance_and_timing',
          'scope': 'four held arrival traces,256 transitions/trace/arm; only t128,t256 queries; no closed-loop generation',
          'phase_states': phases, 'acceptance_output_guards': len(accept), 'timing_observations': len(timing),
          'max_abs': max(r['max_abs'] for r in accept+timing), 'max_relative_l2': max(r['relative_l2'] for r in accept+timing),
          'attempts': attempts, 'timing': by_mode, 'pairs': pairs,
          'median_matched_state_event_ratio': statistics.median(r['dictionary_over_conventional_event'] for r in pairs),
          'dictionary_slower_states': sum(r['event_delta_us']>0 for r in pairs),
          'eight_snapshot_source_relative_squared': source_quality, 'actual_outputs': outputs,
          'explicit_global_buffers_bytes': {'conventional':4554948,'dictionary':4530180},
          'device_body_bytes': {'conventional':43792,'dictionary':55412},
          'query_lds_per_cta_bytes': {'conventional':5632,'dictionary':7688},
          'kernel_descriptors_per_arm_bytes':256, 'compile_receipt_sha256':sha(here/'compile-receipt.json'),
          'compressed_device_phase_files': {f'held-{w}-snapshots.bin.zst': {
              'compressed_sha256': sha(here/f'held-{w}-snapshots.bin.zst'),
              'compressed_bytes': (here/f'held-{w}-snapshots.bin.zst').stat().st_size,
              'decoded_sha256': json.loads((here/f'audit-held-{w}.json').read_text())['snapshots_sha256']}
              for w in range(4)},

          'timing_contract':'one fresh trace per window/arm,control then dictionary,not rotated/repeated; compute span append/query/flush; step includes input H2D; acceptance timing excluded'}
(here / 'results.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['phase_states','acceptance_output_guards','max_abs','max_relative_l2','timing','median_matched_state_event_ratio','dictionary_slower_states','eight_snapshot_source_relative_squared']},indent=2))
