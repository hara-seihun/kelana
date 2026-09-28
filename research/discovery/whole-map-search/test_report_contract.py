import unittest
from emulate import check_index_partition, check_program
from report import matrix


class ReportContractTests(unittest.TestCase):
    def test_index_match_is_not_final_output_match(self):
        program = [{"op": "ds_bpermute_b32", "dst": "out", "args": ["q4"]}]
        inputs, targets = [[0, 4]], [0, 0]
        self.assertTrue(check_program(program, ["q4"], inputs, targets, table=[0]*32)["exact"])
        self.assertTrue(check_index_partition(program, ["q4"], inputs, targets, "refine")["valid"])
        self.assertFalse(check_index_partition(program, ["q4"], inputs, targets, "match")["valid"])
        self.assertTrue(check_index_partition(program, ["q4"], inputs, [0, 1], "match")["valid"])

    def test_incomplete_search_is_not_reported_as_impossibility(self):
        row = {"projection": "lane5", "network": "toy", "image": 2, "contract": "packed2",
               "counts": {"sat": 0, "timeout": 1}, "mode": "match", "valu": 1,
               "unexplored_multisets": [["multiply"]], "queue_total": 22, "queue_done": 1}
        text = matrix({"rows": [row]})
        self.assertIn("no hit", text)
        self.assertNotIn("none <=", text)
        self.assertIn("22", text)


if __name__ == "__main__":
    unittest.main()
