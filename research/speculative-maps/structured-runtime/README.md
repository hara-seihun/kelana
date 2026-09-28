# Structured JSON token support

`grammar.py` builds a byte NFA for a JSON array of 2 to 4 tool records. It lazily constructs byte states and intersects each state with the ordinary-token vocabulary trie from [`tokenizer-spans/measure.py`](../tokenizer-spans/measure.py). It never lists complete JSON strings. States are hashable `frozenset[int]` values. At each step, `allowed(state)` returns every ordinary token ID whose full byte spelling remains a legal prefix, with its successor state. Different token IDs with identical bytes remain separate choices. A token can cross a field boundary.

```python
import importlib.util
import json
from pathlib import Path

# This example assumes the caller already loaded tokenizer-spans/measure.py
# as `spans`, and imported grammar.py as `structured`.
trie, token_bytes = spans.vocabulary(json.loads(Path(tokenizer_path).read_text()))
runtime = structured.StructuredRuntime(trie)
state = runtime.root
while not runtime.accepting(state):
    choices = runtime.allowed(state)
    if len(choices) == 1:
        token, state = next(iter(choices.items()))
    else:
        token = choose_target_greedy_id(choices.keys())
        state = choices[token]
```

Pass `min_records`, `max_records`, `name_max`, and `message_max` to `StructuredRuntime` to adjust fixture bounds. `cache_stats()` reports the number of prepared token-support states and byte-transition cache hits, misses, and entries. Both caches belong to the runtime instance, so a fresh runtime per measured arm frees its own preparation.

`singleton_run(state)` returns `(token_ids, destination)` for consecutive states with exactly one ordinary token edge. Batch only those edges. Every emitted token still needs a causal KV update. Acceptance is a separate grammar stop, not an EOS vocabulary token; once accepted, `allowed(state)` is empty. If a generation protocol requires EOS or log-probabilities, that is a different contract and needs its own target decision.

Each record has fixed keys in this order: `action`, `name`, `id`, `message`, `value`. Actions are `call`, `notify`, or `cancel`. `name` has 1 to 16 decoded characters, raw ASCII letters or JSON escapes; `message` has 1 to 64, raw printable ASCII or escapes. Both accept JSON single-character escapes and `\u0000` through `\u007f`. These Unicode escapes exclude surrogate code points. Raw non-ASCII UTF-8 is excluded by design. Integers have 1 to 6 decimal digits, optional minus sign, and no leading zeros. No whitespace occurs outside strings. Fixed field order and these bounds describe this fixture, not arbitrary JSON Schema.

This is a byte-language contract, not the canonical-token protocol from the earlier finite experiment. Constraining token IDs to one chosen tokenization would change the target law. `allowed` memoizes its generated support and the grammar memoizes subset transitions. Vocabulary trie construction, grammar construction, cache misses and logit selection have costs; the trace receipt prices the CPU parts and does not claim a GPU speedup.

Run from any directory:

```sh
python3 -m unittest -q /path/to/workspace/projects/kelana/research/speculative-maps/structured-runtime/test_grammar.py
/path/to/workspace/data/sglang-bonsai/env/bin/python /path/to/workspace/projects/kelana/research/speculative-maps/structured-runtime/measure.py
```

[`results.json`](results.json) records the pinned Qwen3-0.6B tokenizer SHA and two canonical-token traces through the all-token byte grammar. Both traces have zero singleton steps: 63 tokens for two records and 121 tokens for four. The largest allowed set has 89,933 token IDs. The index took 1.72 s to build, and the two lazy support traces took 2.85 s and 2.09 s respectively on this CPU run. A different vocabulary or different emitted text can have different singleton runs. This result says the realistic free-text fixture does not deliver the earlier canonical-protocol speedup for these paths.
