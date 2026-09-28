#!/usr/bin/env python3
"""Bind a head capture to its linked inputs, executable, and saved query bytes."""
import hashlib
import json
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE / 'build'
BONSAI = Path('/path/to/workspace/projects/bonsai-halo')
MODEL = Path('/path/to/workspace/data/bonsai2/PTQ1_0.gguf')
CACHE = Path(str(MODEL) + '.halo')
HEAD_OFFSET = 24576
HEAD_BYTES = 278118400
OBJECTS = (
    'src/chat.o', 'src/q8.o', 'src/tokenizer.o', 'src/repack.o', 'src/engine.o',
    'src/batch.o', 'src/gguf.o', 'src/server.o', 'src/serve_batch.o',
    'kernels/halo_draft.o', 'kernels/head_batch.o', 'kernels/attn_batch.o',
    'kernels/halo_rows.o', 'kernels/halo_kernels.o', 'kernels/prep_batch.o',
    'kernels/ffn_batch.o', 'kernels/sequence_batch.o', 'vendor/cpp-httplib/httplib.o',
)
FILES = ('query.i8', 'scales.f32', 'sums.i32', 'logits.f32', 'input.txt')


def digest(path, offset=0, length=None):
    h = hashlib.sha256()
    with path.open('rb') as f:
        f.seek(offset)
        while length is None or length > 0:
            data = f.read(1 << 20 if length is None else min(length, 1 << 20))
            if not data:
                break
            h.update(data)
            if length is not None:
                length -= len(data)
    if length is not None:
        assert length == 0
    return h.hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def require_hash(path, expected):
    actual = digest(path)
    if actual != expected:
        raise ValueError(f'{path}: sha256 {actual}, expected {expected}')


def read_cache(model):
    cache = Path(str(model) + '.halo')
    with cache.open('rb') as f:
        magic, size, mtime, n, _ = struct.unpack('<8sQQQQ', f.read(40))
    if magic != b'HALOCAC2' or n != 402 or (size, mtime) != (model.stat().st_size, int(model.stat().st_mtime)):
        raise ValueError('HALO cache and model disagree')
    return {'model_path': str(model.resolve()), 'model_bytes': size,
            'model_mtime_seconds': mtime, 'halo_head_offset': HEAD_OFFSET,
            'halo_head_bytes': HEAD_BYTES,
            'halo_head_sha256': digest(cache, HEAD_OFFSET, HEAD_BYTES)}


def record_inputs(bonsai=BONSAI, root=ROOT):
    """Snapshot source and linked object bytes before compiling and linking."""
    result = {
        'format': 'kelana-capture-build/1', 'origin': 'build-time',
        'bonsai_root': str(bonsai.resolve()),
        'bonsai_source_commit': subprocess.check_output(
            ['git', '-C', str(bonsai), 'rev-parse', 'HEAD'], text=True).strip(),
        'capture_source_sha256': digest(HERE / 'capture.cpp'),
        'linked_object_order': list(OBJECTS),
        'linked_object_sha256': {name: digest(bonsai / name) for name in OBJECTS},
        'halo_decoder_source_sha256': digest(bonsai / 'src/halo_format.h'),
    }
    save(root / 'capture-inputs.json', result)
    return result


def record_build(bonsai=BONSAI, root=ROOT):
    """Reject changed inputs, then attach the produced object and executable hashes."""
    result = json.loads((root / 'capture-inputs.json').read_text())
    if result['bonsai_root'] != str(bonsai.resolve()) or result['origin'] != 'build-time':
        raise ValueError('build inputs belong to another source tree')
    if result['bonsai_source_commit'] != subprocess.check_output(
            ['git', '-C', str(bonsai), 'rev-parse', 'HEAD'], text=True).strip():
        raise ValueError('Bonsai HEAD moved while linking')
    require_hash(HERE / 'capture.cpp', result['capture_source_sha256'])
    require_hash(bonsai / 'src/halo_format.h', result['halo_decoder_source_sha256'])
    for name in result['linked_object_order']:
        require_hash(bonsai / name, result['linked_object_sha256'][name])
    result['capture_object_sha256'] = digest(root / 'capture.o')
    result['capture_binary_sha256'] = digest(root / 'capture')
    save(root / 'capture-build.json', result)
    return result


def verify_build(build, binary, check_inputs=False):
    if build['format'] != 'kelana-capture-build/1' or list(build['linked_object_sha256']) != build['linked_object_order']:
        raise ValueError('unrecognized or unordered build receipt')
    require_hash(binary, build['capture_binary_sha256'])
    if check_inputs:
        bonsai = Path(build['bonsai_root'])
        require_hash(HERE / 'capture.cpp', build['capture_source_sha256'])
        require_hash(bonsai / 'src/halo_format.h', build['halo_decoder_source_sha256'])
        require_hash(ROOT / 'capture.o', build['capture_object_sha256'])
        for name in build['linked_object_order']:
            require_hash(bonsai / name, build['linked_object_sha256'][name])


def case_hashes(output):
    cases = []
    for i in range(3):
        directory = output / f'case{i}'
        cases.append({name: digest(directory / name) for name in FILES})
    return cases


def verify_cases(output, expected):
    if len(expected) != 3:
        raise ValueError('expected exactly three captured cases')
    for i, files in enumerate(expected):
        if set(files) != set(FILES):
            raise ValueError(f'case{i}: incomplete file identity')
        for name in FILES:
            require_hash(output / f'case{i}' / name, files[name])


def capture(model, prompts, output):
    """Called inside run-batch-compare's GPU reservation."""
    build = json.loads((ROOT / 'capture-build.json').read_text())
    if build['origin'] != 'build-time':
        raise ValueError('new captures require a prospective build receipt')
    verify_build(build, ROOT / 'capture', check_inputs=True)
    if output.exists() and any(output.iterdir()):
        raise ValueError(f'capture output must be empty: {output}')
    output.mkdir(parents=True, exist_ok=True)
    inputs = read_cache(model)
    inputs['prompts_sha256'] = digest(prompts)
    subprocess.run([str(ROOT / 'capture'), str(model), str(prompts), str(output)], check=True)
    # Fail rather than attach a receipt to a binary, model, or prompt changed mid-run.
    verify_build(build, ROOT / 'capture', check_inputs=True)
    if inputs != dict(read_cache(model), prompts_sha256=digest(prompts)):
        raise ValueError('model, head cache, or prompts changed during capture')
    run = {'format': 'kelana-capture-run/1', 'origin': 'run-time',
           'build': build, 'inputs': inputs, 'cases': case_hashes(output)}
    save(output / 'capture-run.json', run)


def verify_run(run, output, archived_binary):
    if run['format'] != 'kelana-capture-run/1':
        raise ValueError('unrecognized capture receipt')
    verify_build(run['build'], archived_binary)
    verify_cases(output, run['cases'])
    if run['inputs']['halo_head_offset'] != HEAD_OFFSET or run['inputs']['halo_head_bytes'] != HEAD_BYTES:
        raise ValueError('unexpected HALO head layout')


def pack():
    output = ROOT / 'captures'
    run = json.loads((output / 'capture-run.json').read_text())
    # The executable retained in capture.zst is the one named by the run receipt.
    with tempfile.TemporaryDirectory() as temp:
        binary = Path(temp) / 'capture'
        with binary.open('wb') as f:
            subprocess.run(['zstd', '-dc', str(HERE / 'capture.zst')], stdout=f, check=True)
        verify_run(run, output, binary)
    arrays = {}; cases = []
    for i in range(3):
        d = output / f'case{i}'
        q = np.fromfile(d / 'query.i8', dtype=np.int8)
        xs = np.fromfile(d / 'scales.f32', dtype='<f4')
        sums = np.fromfile(d / 'sums.i32', dtype='<i4')
        logits = np.fromfile(d / 'logits.f32', dtype='<f4')
        assert q.size == 5120 and xs.size == 40 and sums.size == 40 and logits.size == 248320
        assert np.isfinite(xs).all() and (xs > 0).all() and np.isfinite(logits).all()
        assert np.array_equal(q.astype(np.int32).reshape(40, 128).sum(1), sums)
        lines = dict(line.split('=', 1) for line in (d / 'input.txt').read_text().splitlines())
        winner = int(lines['argmax'])
        assert winner == int(np.argmax(logits))
        arrays[f'q{i}'] = q; arrays[f'xs{i}'] = xs
        arrays[f'sums{i}'] = sums; arrays[f'logits{i}'] = logits
        cases.append({'prompt': lines['prompt'], 'tokens': [int(t) for t in lines['tokens'].split(',')],
                      'argmax': winner, 'logit_sha256': run['cases'][i]['logits.f32'],
                      'query_sha256': run['cases'][i]['query.i8'],
                      'scales_sha256': run['cases'][i]['scales.f32'],
                      'sums_sha256': run['cases'][i]['sums.i32'],
                      'input_sha256': run['cases'][i]['input.txt'],
                      'replay': json.loads((ROOT / f'replay{i}.json').read_text())})
    np.savez_compressed(HERE / 'captures.npz', **arrays)
    save(HERE / 'capture-provenance.json', run)
    build = run['build']; inputs = run['inputs']
    manifest = {
        'format': 'kelana-final-head/1', **inputs,
        'bonsai_source_commit_at_capture': build['bonsai_source_commit'],
        'capture_source_sha256': build['capture_source_sha256'],
        'capture_binary_sha256': build['capture_binary_sha256'],
        'capture_binary_zst_sha256': digest(HERE / 'capture.zst'),
        'linked_object_sha256': build['linked_object_sha256'],
        'halo_decoder_source_sha256': build['halo_decoder_source_sha256'],
        'capture_provenance_origin': run['origin'],
        'capture_provenance_sha256': digest(HERE / 'capture-provenance.json'),
        'capture_provenance_notes': {key: value for source in (run, build)
                                     for key, value in source.items() if key.endswith('_evidence')},
        'replay_source_sha256': digest(HERE / 'replay.cpp'),
        'replay_binary_sha256': digest(ROOT / 'replay'),
        'fixture_sha256': digest(HERE / 'captures.npz'),
        'cases': cases,
    }
    save(HERE / 'results.json', manifest)
    print(json.dumps({'winners': [c['argmax'] for c in cases],
                      'fixture_sha256': manifest['fixture_sha256'],
                      'capture_binary_sha256': manifest['capture_binary_sha256']}))


def extract():
    record = json.loads((HERE / 'results.json').read_text())
    require_hash(HERE / 'captures.npz', record['fixture_sha256'])
    with np.load(HERE / 'captures.npz') as z:
        for i, c in enumerate(record['cases']):
            d = ROOT / 'captures' / f'case{i}'
            d.mkdir(parents=True, exist_ok=True)
            for key, file in [('q', 'query.i8'), ('xs', 'scales.f32'),
                              ('sums', 'sums.i32'), ('logits', 'logits.f32')]:
                (d / file).write_bytes(z[f'{key}{i}'].tobytes())
            (d / 'input.txt').write_text('prompt=' + c['prompt'] + '\ntokens=' +
                                         ','.join(map(str, c['tokens'])) +
                                         '\nargmax=' + str(c['argmax']) + '\n')
            for file, key in [('query.i8', 'query_sha256'), ('scales.f32', 'scales_sha256'),
                              ('sums.i32', 'sums_sha256'), ('logits.f32', 'logit_sha256')]:
                require_hash(d / file, c[key])
    receipt = HERE / 'capture-provenance.json'
    require_hash(receipt, record['capture_provenance_sha256'])
    run = json.loads(receipt.read_text())
    verify_cases(ROOT / 'captures', run['cases'])
    shutil.copyfile(receipt, ROOT / 'captures' / 'capture-run.json')
    print('three bit-identical final-head captures extracted')


if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] in ('pack', 'extract'):
        {'pack': pack, 'extract': extract}[sys.argv[1]]()
    elif len(sys.argv) == 2 and sys.argv[1] == 'list-objects':
        print('\n'.join(OBJECTS))
    elif len(sys.argv) == 3 and sys.argv[1] in ('record-inputs', 'record-build'):
        {'record-inputs': record_inputs, 'record-build': record_build}[sys.argv[1]](Path(sys.argv[2]))
    elif len(sys.argv) == 5 and sys.argv[1] == 'capture':
        capture(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4]))
    else:
        raise SystemExit('package.py list-objects | record-inputs BONSAI_ROOT | record-build BONSAI_ROOT | capture MODEL PROMPTS OUTPUT | pack | extract')
