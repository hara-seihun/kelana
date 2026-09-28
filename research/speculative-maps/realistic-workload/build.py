#!/usr/bin/env python3
"""Rebuild the fixed public-source prompts without using model outputs."""

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from tokenizers import Tokenizer

ROOT = Path(__file__).resolve().parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
TOKENIZER = DATA / 'models/qwen3-1.7b/tokenizer.json'
CORPUS = DATA / 'corpus/wikitext-2-raw/test.txt'
CODE_ROOT = Path('/path/to/workspace/projects/pi-stack')
CODE_REV = 'a72324174e194b9f7e7101ee0649583391b4d32d'
CORPUS_REV = 'b08601e04326c79dfdd32d625aee71d232d685c3'
EXPECTED_CORPUS_SHA = '696cca6b65a171b0a358a4be6732cdfdf2dd6164a32e20fd70e3c13fc4dfae83'
LENGTHS = (256, 1024, 2048, 256, 1024, 2048, 1024, 2048)
CODE_FILES = (
    'packages/orchestrator/src/threads/pi-session.ts',
    'apps/remote/web/src/DrawingCanvas.tsx',
    'apps/remote/server/messaging/signal.ts',
    'packages/orchestrator/src/anthropic-files.ts',
    'apps/remote/server/meet/server.ts',
    'packages/orchestrator/src/store.ts',
    'apps/remote/web/src/voice.ts',
    'apps/remote/server/router.ts',
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encode_case(tokenizer, family, index, length, text, source):
    tokens = tokenizer.encode(text, add_special_tokens=False).ids
    if len(tokens) < length + 128:
        raise ValueError(f'not enough source text for {family}/{index}: {len(tokens)}')
    prompt_ids = tokens[:length]
    prompt = tokenizer.decode(prompt_ids, skip_special_tokens=False)
    if tokenizer.encode(prompt, add_special_tokens=False).ids != prompt_ids:
        raise ValueError(f'token boundary does not round-trip for {family}/{index}')
    return {
        'id': f'{family}-{index + 1:02d}-{length}',
        'family': family,
        'source': source,
        'prompt_tokens': length,
        'continuation_tokens': 64,
        'prompt': prompt,
        'prompt_token_ids': prompt_ids,
        'prompt_sha256': sha(prompt.encode()),
    }


def build():
    tokenizer = Tokenizer.from_file(str(TOKENIZER))
    tokenizer_sha = sha(TOKENIZER.read_bytes())
    corpus_bytes = CORPUS.read_bytes()
    if sha(corpus_bytes) != EXPECTED_CORPUS_SHA:
        raise ValueError('WikiText test content changed')
    corpus = corpus_bytes.decode()
    headings = list(re.finditer(r'^ = [^=\n]+ =\s*$', corpus, re.M))
    cases = []
    for index, (file, length) in enumerate(zip(CODE_FILES, LENGTHS)):
        raw = subprocess.check_output(['git', '-C', str(CODE_ROOT), 'show', f'{CODE_REV}:{file}'])
        text = raw.decode()
        # A real source-code completion starts at an existing declaration, not at a task instruction.
        first = re.search(r'^(?:export |async function |function |class |const |interface |type )', text[1200:], re.M)
        start = 1200 + first.start() if first else 0
        source = {'repository': 'https://github.com/the project lead-seihun/pi-stack', 'revision': CODE_REV,
                  'license': 'MIT', 'path': file, 'file_sha256': sha(raw), 'character_start': start}
        cases.append(encode_case(tokenizer, 'code', index, length, text[start:], source))
    for index, length in enumerate(LENGTHS):
        heading = headings[32 if index == 4 else 7 * index]
        start = heading.start()
        source = {'repository': 'https://huggingface.co/datasets/Salesforce/wikitext',
                  'revision': CORPUS_REV, 'split': 'test', 'license': 'CC-BY-SA-3.0 / GFDL',
                  'text_sha256': EXPECTED_CORPUS_SHA, 'character_start': start,
                  'article_heading': heading.group().strip()}
        cases.append(encode_case(tokenizer, 'prose', index, length, corpus[start:], source))
    for index, length in enumerate(LENGTHS):
        article_index = {2: 18, 7: 56}.get(index, 3 + 7 * index)
        section = corpus[headings[article_index].start():headings[article_index + 1].start()]
        paragraphs = [p.strip() for p in re.split(r'\n\s*\n', section) if p.strip()]
        title = headings[article_index].group().strip(' =\n')
        tool = index % 2 == 1
        header = ({'task': 'JSON-RPC article.index calls', 'source': 'wikitext-2-raw-v1/test',
                   'method': 'article.index',
                   'params_schema': {'article': 'string', 'paragraph_number': 'integer', 'text': 'string'}}
                  if tool else {'task': 'index_encyclopedia_paragraphs',
                                'source': 'wikitext-2-raw-v1/test',
                                'schema': {'article': 'string', 'paragraph_number': 'integer', 'text': 'string'}})
        preamble = json.dumps(header, ensure_ascii=False, separators=(',', ':')) + '\n'
        records = ''.join(json.dumps({'jsonrpc': '2.0', 'method': 'article.index',
                                      'params': {'article': title, 'paragraph_number': i + 1, 'text': p},
                                      'id': i + 1} if tool else
                                     {'article': title, 'paragraph_number': i + 1, 'text': p},
                                     ensure_ascii=False, separators=(',', ':')) + '\n'
                          for i, p in enumerate(paragraphs))
        start = headings[article_index].start()
        source = {'repository': 'https://huggingface.co/datasets/Salesforce/wikitext',
                  'revision': CORPUS_REV, 'split': 'test', 'license': 'CC-BY-SA-3.0 / GFDL',
                  'text_sha256': EXPECTED_CORPUS_SHA, 'character_start': start,
                  'article_heading': headings[article_index].group().strip(),
                  'transformation': 'JSONL header and consecutive nonempty corpus paragraphs'}
        cases.append(encode_case(tokenizer, 'json', index, length, preamble + records, source))
    manifest = {
        'version': 1, 'selection': 'Eight fixed source positions per family; lengths fixed before target evaluation',
        'tokenizer': {'repository': 'https://huggingface.co/Qwen/Qwen3-1.7B',
                      'revision': '70d244cc86ccca08cf5af4e1e306ecf908b1ad5e',
                      'tokenizer_json_sha256': tokenizer_sha, 'special_tokens': False},
        'contract': {'generation': 'continue each raw prompt for continuation_tokens target token IDs',
                     'prompt_pretokenized': True, 'chat_template': False, 'stop_at_eos': False,
                     'measure': 'Prefill separately; compare same-context serial and candidate-verifier emitted IDs and elapsed continuation time',
                     'outputs_used_in_selection': False},
        'cases': [{**{k: v for k, v in c.items() if k != 'prompt_token_ids'},
                   'token_ids': c['prompt_token_ids']} for c in cases],
    }
    return (json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n').encode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    path = ROOT / 'manifest.json'
    content = build()
    if args.check:
        if path.read_bytes() != content:
            raise SystemExit(f'fixture mismatch: {path}')
    else:
        path.write_bytes(content)
    print(f'{path.name}: {len(content)} bytes, sha256 {sha(content)}')


if __name__ == '__main__':
    main()
