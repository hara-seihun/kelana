# Qwen token paths through small output grammars

The byte string `{"kind":"ok","value":0}` has many legal tokenizations under Qwen3-0.6B. A grammar can force its next byte without forcing its next token. This experiment computes the *entire* token support for three declared finite languages and contracts only singleton token edges. It extends [forced spans](../forced-spans/README.md), whose affine recurrence assumed known token IDs.

Run from the repository root with a Python environment containing `tokenizers`:

```sh
/path/to/workspace/data/sglang-bonsai/env/bin/python research/speculative-maps/tokenizer-spans/measure.py > research/speculative-maps/tokenizer-spans/results.json
```

The pinned local tokenizer is `/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/tokenizer.json`, SHA-256 `aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4`, model revision `c1899de289a04d12100db370d81485cdf75e47ca`. The script loads only tokenizer files; it does not load the model or call a GPU. [`measure.py`](measure.py) defines the languages and [`results.json`](results.json) records the run.

These are deliberately small *finite languages*, not JSON or Python parsers:

- `json`: 16 strings of the form `{"kind":<space>"ok"|"o\\u006b","value":<space>0|1}`, with each `<space>` independently empty or one ASCII space. The escape spells the same decoded value but different output bytes.
- `code`: eight strings, optional four-space indentation followed by `return {"ok":<space>true|false}\n`.
- `repeated`: four strings, `{"items":[a,b]}` with independent `a,b` in `{0,1}`. It repeats the same delimiter and has two variable boundaries.

A trie accepts exactly the UTF-8 bytes in each language. We invert Qwen's byte-level BPE alphabet to obtain the actual bytes of all 151,643 ordinary vocabulary IDs. From every reachable grammar byte prefix we intersect the vocabulary trie with the grammar trie; an edge exists for **every** token whose complete bytes remain a prefix of a valid output. Tokens may cross a literal/variable boundary. All paths end at a complete string, without an EOS token. No BPE-canonical restriction is imposed on the local masking law. The tokenizer's own encoder supplies a separate canonical path for comparison; byte concatenation of every such path is checked against its output string.

| Language | Byte states / token edges | Complete legal token paths | Token-singleton states | Canonical-path steps ambiguous under full support | Canonical-policy singleton steps |
| --- | ---: | ---: | ---: | ---: | ---: |
| JSON | 104 / 175 | 296,960 | 36 | 152 / 200 | 144 / 200 |
| Code | 85 / 218 | 874,640 | 22 | 52 / 52 | 36 / 52 |
| Repeated | 27 / 44 | 1,024 | 9 | 24 / 28 | 20 / 28 |

The last column enforces *one BPE encoding per complete string*, using a trie of all canonical ID sequences. That is a different constrained distribution: it preserves the finite set of output strings but excludes legal ID paths. It can force many more token decisions than the original byte-language mask. The preceding column follows those exact same canonical paths while admitting all locally legal tokenizations. For example, at the JSON root canonical BPE takes ID 4913, bytes `{"`. The full byte grammar also permits ID 90, bytes `{`; its allowed set has two IDs, not one. Restricting the first decision to 4913 changes the locally masked model's token law and continuation state, even though both IDs can begin the same output. The code grammar has 24 token edges crossing a declared variable start, including `:true`, `:false`, `:t` and `:f`. Stopping at the last literal byte would miss them.

There *are* real token-singleton opportunities deeper in the full grammar. On canonical paths the JSON language has sixteen singleton runs of length one and eight runs of length four; code has none, and repeated has four of length one. The root has zero guaranteed forced tokens in all three full-support grammars. Across **uniformly weighted complete token paths**, rather than model-weighted output, mean singleton steps / mean total steps are JSON `5.0517 / 19.4828`, code `2.4793 / 15.4573`, repeated `3 / 11`. This path weighting overrepresents strings with many tokenizations and should not be mistaken for observed model traffic.

A grammar-only contraction follows deterministic token edges to the next branching or terminal node. For JSON it reduces 104 byte states and 175 token edges to 68 reachable macro states and 139 macro edges; code goes from 85/218 to 63/196, repeated from 27/44 to 18/35. Each macro edge still carries its **complete token-ID sequence**. Its parser dispatch can jump through those states, and a target can consume the known IDs as a causal prefill chunk before the next choice. This does not contract the Qwen transformer state transition: every consumed token still needs its causal KV update. At a branch, a locally masked decoder must consult the model's probabilities over *all* supported IDs, and distinct histories cannot share KV merely because their grammar prefix matches.

Preparation decodes 975,969 bytes of ordinary vocabulary spellings and indexes 151,643 tokens. This run spent about 2.2 seconds loading/indexing the tokenizer, then intersected 301, 327 and 72 grammar/vocabulary trie-node pairs respectively; grammar construction includes 424, 176 and 60 bytes of listed output strings respectively. The per-language intersections and counting took roughly 2 ms or less on this CPU. This is offline work for reusable grammars, not free per-request parsing. An online decoder needs a grammar state, a precomputed allowed-ID list or its equivalent, and the emitted-byte/token bookkeeping; here those lists have 175, 218 and 44 total entries. The macro table saves parser dispatches and potentially head decisions, but emits the same token bytes and leaves target body FLOPs and KV writes unpriced. No serving latency or transformer speedup is claimed.

The next useful boundary is a larger practical schema with unrestricted strings and numbers, where a finite output-list trie cannot enumerate all completions. Its tokenizer/grammar intersection must handle accepting loops, UTF-8 fragments, escapes and termination without a finite list of full outputs. Trace actual request grammar states and model-weighted paths before attributing these small-language ratios to production workloads.
