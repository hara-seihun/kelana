# Retrieved token spans after target handoff

A CPU proposal can copy token IDs from the current visible prefix or from the training corpus. This study uses the exact first token retained from the previous BF16 target decision, then retrieves up to eight six-token paths without reading any later target labels. A prefix-tree verifier could check those paths against the target. Retrieval itself does not certify the target continuation, save target-layer weight reads, or supply accepted KV state.

The immutable source is the WikiText-2 train split and the 64-token visible prefix reconstructed from the original validation/test start offsets. The candidate search never indexes either held split. The evaluator reads each held target trajectory only after constructing the candidate paths. It scores first-missing prefix plus the usual target exit token, with the retained first token occupying one node. The [candidate module](candidates.py) is importable without PyTorch or model weights. The [experiment](experiment.py) uses the same original 32 validation and 32 test target-greedy contexts as the direct and residual studies, not a new independent sample.

| Split | Nodes | Residual static | Direct only | Copy chain | Copy tree | One copy edge then direct |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Validation | 6 | 2.71875 | 2.46875 | 2.46875 | 2.46875 | 2.56250 |
| Validation | 18 | 2.84375 | 2.65625 | 2.46875 | 2.75000 | 2.75000 |
| Test | 6 | 2.40625 | 2.46875 | 2.31250 | 2.31250 | 2.50000 |
| Test | 18 | 2.53125 | 2.53125 | 2.31250 | 2.53125 | 2.59375 |

The residual-static figures come from the unchanged [residual study](../residual-drafter/README.md). A single copy chain cannot spend eighteen distinct nodes within the six-token horizon. The full-copy-then-direct arm, retained in the receipts, equals the copy tree in this panel because the eight copied paths use every available slot.

The one-edge graft wins by 0.03125 at six and 0.0625 at eighteen nodes on test. At six nodes it helps two contexts and harms one. The target's second token occurs as a retrieved second token on 14/32 validation and 12/32 test contexts. Those are candidate-support counts, not verified accepted spans. Full-path copies can crowd out useful learned alternatives. A graft is a useful low-cost candidate source but not an observed speedup.

The train token stream has 2,518,423 IDs. Corpus IDs, postings and direct vocabulary offsets occupy about 20.8 MB resident; the saved token-ID cache is 10,073,820 bytes on disk. Index build from token IDs takes about 0.11 seconds here, separate from loading/tokenizing the 11 MB train text. Each query scans the latest at most 4,096 occurrences of the retained token, compares backward against the visible prefix and ranks longest matches, preferring local prompt copies and later positions. It examined a mean 3,174 validation postings and 2,899 test postings. The optimized implementation groups backward comparisons by token offset and constructs six-token candidate tuples only for ranked finalists. Direct offsets replace two random accesses into the 2.5M-entry sorted-token array. [Paired timings](query-benchmark.json) across the same 64 held queries give 6.00 ms per scalar query versus 0.0625 ms with the exact same ordered results, about 96-fold faster. They exclude tokenizer construction, index build/load and the learned model. Python `tracemalloc` peaks for one query are 20,149,584 versus 127,902 temporary bytes. The output matches the committed scalar implementation for all 64 queries at four width/postings settings, plus nine synthetic repeated-token cases. Each held query yielded eight distinct paths; nine first-ranked candidates per split came from the prompt. The direct baseline still computes its learned backbone and shortlist; the graft also pays retrieval/index traffic. Target verification and scheduling were not timed.

The parent subsequently measured the optimized lookup in [continued FP32 generation](../online/COUPLED.md). Across eight prompts in two opposite-order panels, one copied edge in the same eighteen-node budget raises throughput from 36.75 to 38.35 tokens/s, versus paired serial 30.12. All emitted tokens and final next decisions match serial. Index preparation remains outside generation timing and is recorded separately; each cycle pays lookup and graft construction.

Reproduce from Kelana's root with the existing CPU Python environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$P research/speculative-maps/retrieved-spans/experiment.py validation --with-learned
$P research/speculative-maps/retrieved-spans/experiment.py test --with-learned
$P research/speculative-maps/retrieved-spans/benchmark.py
```

[Validation](validation.json) and [test](test.json) receipts record fixture/corpus/checkpoint/source hashes, per-context outcomes, index bytes and query work. `/path/to/workspace/data/kelana-speculative/retrieved-spans/train-token-ids.npy` is a regenerable cache of train token IDs, not a second corpus or new capture. The module can operate online on an already built training index and a current prefix plus retained token. A serving decision still needs a priced target verifier and a nonleaking dispatch contract; this small WikiText panel is too narrow to choose a production retrieval policy.
