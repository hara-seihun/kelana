#!/usr/bin/env python3
"""Candidate headers must participate in benchmark source provenance."""
import contextlib
import io
from pathlib import Path
import runpy
import tempfile
import unittest

with contextlib.redirect_stdout(io.StringIO()):
    module = runpy.run_path(str(Path(__file__).with_name("fingerprint.py")))
closure, digest = module["source_closure"], module["sha_of"]


class FingerprintTest(unittest.TestCase):
    def test_transitive_header_change_changes_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "candidate.hip").write_text('#include "a.hpp"\n')
            (root / "a.hpp").write_text('#include "b.hpp"\n')
            (root / "b.hpp").write_text('int code = 1;\n')
            sources = closure([str(root / "candidate.hip")], [])
            self.assertEqual(len(sources), 3)
            before = digest(sources)
            (root / "b.hpp").write_text('int code = 2;\n')
            self.assertNotEqual(before, digest(sources))
            (root / "b.hpp").unlink()
            with self.assertRaises(RuntimeError):
                closure([str(root / "candidate.hip")], [])


if __name__ == "__main__":
    unittest.main()
