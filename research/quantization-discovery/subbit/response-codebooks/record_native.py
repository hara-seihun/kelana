#!/usr/bin/env python3
"""Bind the paired CPU panel to its source, executable, fixture and inputs."""
import hashlib
import json
import platform
import statistics
import subprocess
from pathlib import Path

import study

here = Path(__file__).resolve().parent
build = here/'build'
raw = json.loads((build/'raw.json').read_text())
inputs = json.loads((build/'receipt.json').read_text())
if raw['rows'] != 5120 or raw['queries'] != 8:
    raise ValueError('unexpected measurement shape')
for name, sha in inputs['files'].items():
    if study.sha(build/name) != sha:
        raise ValueError(f'{name} changed since export')
archived = subprocess.check_output(['zstd','-dc',str(here/'native.zst')])
if hashlib.sha256(archived).hexdigest() != study.sha(build/'native'):
    raise ValueError('retained executable differs from timed build')
samples = raw['samples_us']
median = {name:statistics.median(values) for name,values in samples.items()}
record = {'format':'response-codebooks-cpu/1', 'cpu':platform.processor(),
          'host_model':next(line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')),
          'compiler':subprocess.check_output(['c++','--version'],text=True).splitlines()[0],
          'compile_command':'c++ -O3 -std=c++20 -mavx512vnni -mavx512bw -mavx512f native.cpp -o build/native',
          'native_source_sha256':study.sha(here/'native.cpp'),
          'fixture_export_source_sha256':study.sha(here/'native_fixture.py'),
          'native_binary_sha256':study.sha(build/'native'),
          'native_archive_sha256':study.sha(here/'native.zst'),
          'fixture_sha256':study.sha(study.FIXTURE),
          'input_file_sha256':inputs['files'],
          'repetitions_per_round':256,'rotated_rounds':9,
          'samples_us':samples,'median_us':median,
          'control_boundary':'exact int32 q dot decoded int8 codeword, 5120x128; unchanged FP16 row scales omitted for both',
          'control_extra_row_sum_bytes':5120*4,
          'compact_table_bytes':16*64*4,
          'compact_dictionary_bytes':64*8,
          'compact_label_bytes':5120*12,
          'dense_decoded_weight_bytes':5120*128}
(here/'native-results.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(median))
