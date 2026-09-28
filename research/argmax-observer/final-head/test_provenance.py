#!/usr/bin/env python3
"""Short contract check for build, run, and packaging identity boundaries."""
import hashlib
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import package


class ProvenanceContract(unittest.TestCase):
    def test_mutations_are_rejected_at_each_boundary(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            here = root / 'study'; here.mkdir()
            build_dir = here / 'build'; build_dir.mkdir()
            bonsai = root / 'bonsai'; bonsai.mkdir()
            (here / 'capture.cpp').write_bytes(b'capture source')
            decoder = bonsai / 'src/halo_format.h'; decoder.parent.mkdir()
            decoder.write_bytes(b'decoder')
            for name in package.OBJECTS:
                path = bonsai / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(name.encode())
            (build_dir / 'capture.o').write_bytes(b'compiled')
            executable = build_dir / 'capture'; executable.write_bytes(b'linked')
            with patch.object(package, 'HERE', here), patch.object(package, 'ROOT', build_dir), \
                    patch('package.subprocess.check_output', return_value='commit-1\n'):
                package.record_inputs(bonsai, build_dir)
                changed = bonsai / package.OBJECTS[7]
                changed.write_bytes(b'changed after input snapshot')
                with self.assertRaises(ValueError):
                    package.record_build(bonsai, build_dir)
                changed.write_bytes(package.OBJECTS[7].encode())
                build = package.record_build(bonsai, build_dir)
                package.verify_build(build, executable, check_inputs=True)
                changed.write_bytes(b'changed after linking')
                with self.assertRaises(ValueError):
                    package.verify_build(build, executable, check_inputs=True)
                # Packing uses the saved receipt and captured binary, not later
                # object files in the mutable Bonsai tree.
                output = build_dir / 'captures'; output.mkdir()
                for i in range(3):
                    case = output / f'case{i}'; case.mkdir()
                    for name in package.FILES:
                        (case / name).write_bytes(f'{i}:{name}'.encode())
                run = {'format': 'kelana-capture-run/1', 'origin': 'run-time',
                       'build': build, 'inputs': {'halo_head_offset': package.HEAD_OFFSET,
                                                 'halo_head_bytes': package.HEAD_BYTES},
                       'cases': package.case_hashes(output)}
                package.verify_run(run, output, executable)
                (output / 'case2/logits.f32').write_bytes(b'changed after run')
                with self.assertRaises(ValueError):
                    package.verify_run(run, output, executable)
                (output / 'case2/logits.f32').write_bytes(b'2:logits.f32')
                executable.write_bytes(b'changed binary')
                with self.assertRaises(ValueError):
                    package.verify_run(run, output, executable)

    def test_pack_and_extract_keep_the_current_run_receipt(self):
        source = Path(package.__file__).resolve().parent
        with tempfile.TemporaryDirectory() as temp:
            here = Path(temp)
            for name in ('captures.npz', 'capture.zst', 'capture-provenance.json',
                         'results.json', 'replay.cpp'):
                shutil.copyfile(source / name, here / name)
            root = here / 'build'
            with patch.object(package, 'HERE', here), patch.object(package, 'ROOT', root):
                package.extract()
                run_path = root / 'captures/capture-run.json'
                run = json.loads(run_path.read_text())
                run['test_run_id'] = 'next-capture'
                package.save(run_path, run)
                record = json.loads((here / 'results.json').read_text())
                for i, case in enumerate(record['cases']):
                    package.save(root / f'replay{i}.json', case['replay'])
                (root / 'replay').write_bytes(b'test replay executable')
                package.pack()
                self.assertEqual(json.loads((here / 'capture-provenance.json').read_text()), run)
                shutil.rmtree(root / 'captures')
                package.extract()
                self.assertEqual(json.loads(run_path.read_text()), run)

    def test_original_captures_keep_distinct_provenance(self):
        here = Path(package.__file__).resolve().parent
        receipt = json.loads((here / 'capture-provenance.json').read_text())
        original = json.loads((here / 'results.json').read_text())
        self.assertEqual(receipt['origin'], 'retrospective-from-original-results-and-extracted-fixture')
        self.assertIn('hardcoded', receipt['build']['source_commit_evidence'])
        self.assertEqual(receipt['build']['bonsai_source_commit'], original['bonsai_source_commit_at_capture'])
        self.assertEqual(receipt['build']['capture_binary_sha256'], original['capture_binary_sha256'])
        self.assertEqual(receipt['build']['linked_object_sha256'], original['linked_object_sha256'])
        binary = subprocess.check_output(['zstd', '-dc', str(here / 'capture.zst')])
        self.assertEqual(hashlib.sha256(binary).hexdigest(), receipt['build']['capture_binary_sha256'])
        for i, case in enumerate(receipt['cases']):
            self.assertEqual(case['query.i8'], original['cases'][i]['query_sha256'])
            self.assertEqual(case['logits.f32'], original['cases'][i]['logit_sha256'])


if __name__ == '__main__':
    unittest.main()
