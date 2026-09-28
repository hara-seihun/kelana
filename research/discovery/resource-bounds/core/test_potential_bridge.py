import copy
import json
from pathlib import Path
import unittest

from replay import replay


class PotentialBridgeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifact = json.loads(Path(__file__).with_name("potential-results.json").read_text())

    def test_independent_source_replay(self):
        result = replay(self.artifact)
        self.assertTrue(result["accepted"], result)
        for case in result["results"]:
            self.assertTrue(case["checks"]["semantic_source"]["budget_is_family_restriction"])
            self.assertEqual(case["checks"]["relaxation"]["lower_bound"], "2")

    def test_source_and_semantic_binding(self):
        for edit in (
            lambda c: c["semantic_source"].update(sha256="0"*64),
            lambda c: c["problem"].update(goal={"kind": "refines"}),
            lambda c: c["family"]["obligations"].pop(0),
            lambda c: c["family"]["obligations"][1].update(minimum=3),
        ):
            artifact = copy.deepcopy(self.artifact)
            edit(artifact["cases"][0])
            result = replay(artifact)
            self.assertFalse(result.get("accepted", False), result)
            self.assertFalse(result.get("valid", False), result)


if __name__ == "__main__":
    unittest.main()
