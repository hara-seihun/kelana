#!/usr/bin/env python3
"""Trace exact byte-language token support for a few real tool batches."""
import hashlib
import importlib.util
import json
import time
from pathlib import Path

from tokenizers import Tokenizer

HERE = Path(__file__).resolve().parent
VOCAB = HERE.parent / 'tokenizer-spans' / 'measure.py'
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/tokenizer.json')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    vocab_module = load(VOCAB, 'tokenizer_spans')
    grammar_module = load(HERE / 'grammar.py', 'structured_runtime')
    start = time.perf_counter()
    model_bytes = MODEL.read_bytes()
    trie, token_bytes = vocab_module.vocabulary(json.loads(model_bytes))
    tokenizer = Tokenizer.from_file(str(MODEL))
    vocab_seconds = time.perf_counter() - start
    start = time.perf_counter()
    runtime = grammar_module.StructuredRuntime(trie)
    grammar_seconds = time.perf_counter() - start
    rows = []
    for count in (2, 4):
        text = json.dumps([{'action': ('call', 'notify', 'cancel')[i % 3],
                            'name': ('search', 'fetch', 'notify', 'summarize')[i],
                            'id': 1000 + 11 * i,
                            'message': ('Look up "docs" and report the key result',
                                        'Fetch /notes and list the changes',
                                        'Send a brief summary to the team',
                                        'Check the latest build status')[i],
                            'value': -3 + i} for i in range(count)], separators=(',', ':'))
        ids = tokenizer.encode(text, add_special_tokens=False).ids
        assert b''.join(token_bytes[i] for i in ids) == text.encode()
        at = runtime.root
        decisions = []
        started = time.perf_counter()
        for token in ids:
            choices = runtime.allowed(at)
            assert token in choices, (at, token, token_bytes[token])
            decisions.append(len(choices))
            at = choices[token]
        elapsed = time.perf_counter() - started
        assert runtime.accepting(at) and not runtime.allowed(at)
        rows.append({'records': count, 'bytes': len(text.encode()), 'canonical_tokens': len(ids),
                     'canonical_singleton_steps_under_byte_contract': decisions.count(1),
                     'canonical_branch_steps_under_byte_contract': sum(n > 1 for n in decisions),
                     'largest_allowed_set': max(decisions), 'trace_cpu_support_s': round(elapsed, 6),
                     'cached_states': len(runtime._allowed), 'example_json': text})
    result = {'contract': 'All ordinary Qwen tokenizer tokenizations of a 2–4 item bounded ASCII JSON batch, fixed field order. Acceptance stops outside ordinary vocabulary; no canonical-token restriction.',
              'tokenizer_sha256': hashlib.sha256(model_bytes).hexdigest(),
              'vocabulary_index_s': round(vocab_seconds, 6),
              'grammar_build_s': round(grammar_seconds, 6),
              'nfa_states': len(runtime.grammar.edges), 'ordinary_vocab_size': len(token_bytes),
              'root_allowed_tokens': len(runtime.allowed(runtime.root)), 'rows': rows}
    (HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
