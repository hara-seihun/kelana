"""Read frozen raw-completion prompts without a tokenizer or source checkout."""

import hashlib
import json
from pathlib import Path

MANIFEST = Path(__file__).with_name('manifest.json')


def load_cases(family=None, lengths=None, ids=None):
    """Return case dictionaries, each with exact Qwen token_ids and prompt text."""
    payload = json.loads(MANIFEST.read_text())
    cases = payload['cases']
    if family is not None:
        cases = [case for case in cases if case['family'] == family]
    if lengths is not None:
        cases = [case for case in cases if case['prompt_tokens'] in lengths]
    if ids is not None:
        cases = [case for case in cases if case['id'] in ids]
    for case in cases:
        if len(case['token_ids']) != case['prompt_tokens']:
            raise ValueError(f"wrong token count: {case['id']}")
        if hashlib.sha256(case['prompt'].encode()).hexdigest() != case['prompt_sha256']:
            raise ValueError(f"wrong prompt hash: {case['id']}")
    return cases
