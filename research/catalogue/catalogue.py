#!/usr/bin/env python3
"""Build and query Kelana's evidence-backed model research catalogue."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
CATEGORIES = {
    'promising': ('Promising but not yet', 'promising.md'),
    'better-than-sota': ('Better than SOTA on something', 'better-than-sota.md'),
    'strictly-bad': ('Strictly bad under the tested conditions', 'strictly-bad.md'),
}
DOMAINS = {
    'conversion': 'Model conversion and quantization representations',
    'subbit': 'Sub-bit models, attention and cache representations',
    'moe-speculation': 'Mixture of experts and speculative decoding',
    'foundations': 'Packed computation, proofs and native building blocks',
    'runtime': 'Bonsai and Qwen runtime research',
    'isa-quantization': 'ISA-aware quantization and executable-map search',
}
FIELDS = {'id', 'title', 'category', 'evidence', 'summary', 'comparison', 'limitation', 'next', 'links', 'source_roots'}


def source_path(value):
    """Resolve sibling projects from their canonical owner, including in writers."""
    base = value.split('#', 1)[0]
    if base.startswith('../'):
        return Path('/path/to/workspace/projects') / base[3:]
    return ROOT / base


def load():
    entries, errors = [], []
    seen = set()
    for domain in DOMAINS:
        path = HERE / f'{domain}.json'
        if not path.exists():
            errors.append(f'missing domain {path.name}')
            continue
        rows = json.loads(path.read_text())
        if not isinstance(rows, list):
            errors.append(f'{path.name} must be an array')
            continue
        for row in rows:
            if set(row) != FIELDS:
                errors.append(f'{path.name}: invalid fields for {row.get("id")}: {set(row) ^ FIELDS}')
                continue
            if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', row['id']) or row['id'] in seen:
                errors.append(f'invalid/duplicate id {row["id"]}')
            seen.add(row['id'])
            if row['category'] not in CATEGORIES:
                errors.append(f'invalid category {row["id"]}')
            for key in FIELDS - {'links', 'source_roots'}:
                if not isinstance(row[key], str) or not row[key].strip():
                    errors.append(f'empty/non-text {key} in {row["id"]}')
            for field in ('links', 'source_roots'):
                if not isinstance(row[field], list) or not row[field]:
                    errors.append(f'{field} must have paths in {row["id"]}')
                    continue
                for value in row[field]:
                    path = source_path(value)
                    if not path.exists():
                        errors.append(f'{row["id"]}: missing {field} path {value}')
            entries.append(dict(row, domain=domain))
    return sorted(entries, key=lambda r: (r['domain'], r['title'].lower())), errors


def link(path, label=None):
    base, marker, anchor = path.partition('#')
    relative = os.path.relpath(ROOT / base, HERE).replace(' ', '%20')
    return f'[{label or Path(base).name}]({relative}{marker}{anchor})'


def owners(path, entries):
    exact = [e for e in entries if path in [p.split('#', 1)[0] for p in e['links']]]
    if exact:
        return exact
    matches = [(len(root), e) for e in entries for root in e['source_roots']
               if path == root.rstrip('/') or path.startswith(root.rstrip('/') + '/')]
    if not matches:
        return []
    length = max(n for n, _ in matches)
    unique = {e['id']: e for n, e in matches if n == length}
    return list(unique.values())


def render_entry(entry):
    lines = [f'<a id="{entry["id"]}"></a>', f'## {entry["title"]}', '',
             f'Category: {CATEGORIES[entry["category"]][0]}. Evidence: {entry["evidence"]}.', '',
             entry['summary'], '', f'Comparison: {entry["comparison"]}', '',
             f'Boundary: {entry["limitation"]}', '', f'Next decision: {entry["next"]}', '',
             'Sources: ' + ', '.join(link(p, p) for p in entry['links']) + '.', '']
    return '\n'.join(lines)


def outputs(entries):
    count = Counter(e['category'] for e in entries)
    files = {}
    for category, (title, filename) in CATEGORIES.items():
        lines = [f'# {title}', '', '[Research desk](README.md) · [All source documents](inventory.md)', '',
                 'Generated from the domain JSON records. Edit those records, then run `catalogue.py build`.', '']
        selected = [e for e in entries if e['category'] == category]
        if not selected:
            lines += ['No result currently meets this classification. Local wins remain in the promising category until their stronger comparison is established.', '']
        for domain, heading in DOMAINS.items():
            group = [e for e in selected if e['domain'] == domain]
            if group:
                lines += [f'## {heading}', '']
                for e in group:
                    lines += [f'- [{e["title"]}]({domain}.md#{e["id"]}): {e["summary"]}']
                lines.append('')
        files[filename] = '\n'.join(lines)
    for domain, title in DOMAINS.items():
        group = [e for e in entries if e['domain'] == domain]
        files[f'{domain}.md'] = f'# {title}\n\n[Research desk](README.md)\n\nGenerated from `{domain}.json`; the JSON owns classifications.\n\n' + '\n'.join(render_entry(e) for e in group)
    docs = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'research').rglob('*.md')
                  if HERE not in p.parents and not any(part.startswith('.') for part in p.relative_to(ROOT).parts))
    lines = ['# Model research source inventory', '', '[Research desk](README.md)', '',
             'Every Markdown research document in Kelana appears below. Exact source links take precedence; otherwise the longest owning research directory supplies its catalogue entries. Supporting plans and method notes inherit an owner, not a new experimental claim.', '',
             '| Source document | Classified research entries |', '| --- | --- |']
    uncovered = []
    for path in docs:
        matches = owners(path, entries)
        if not matches:
            uncovered.append(path)
        references = ', '.join(f'[{e["title"]}]({e["domain"]}.md#{e["id"]})' for e in matches) or '**Unclassified**'
        lines.append(f'| {link(path, path)} | {references} |')
    lines += ['', '## External implementation and acceptance owners', '',
              'Research decisions live in this catalogue. Runtime code, deployment instructions and detailed native acceptance receipts stay with the component that executes them.', '']
    external = sorted({p for e in entries for p in e['links'] if p.startswith('../')})
    lines += [f'- {link(p, p)}' for p in external]
    lines += ['', f'{len(entries)} classified research entries; {len(docs)} Kelana research documents; {len(uncovered)} without an owner.', '']
    files['inventory.md'] = '\n'.join(lines)
    status = dict(entries=len(entries), categories=dict(count), documents=len(docs), unclassified=uncovered,
                  domains={d: sum(e['domain'] == d for e in entries) for d in DOMAINS})
    files['status.json'] = json.dumps(status, indent=2) + '\n'
    return files, uncovered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['build', 'check', 'list'])
    parser.add_argument('--category', choices=CATEGORIES)
    parser.add_argument('--query', default='')
    args = parser.parse_args()
    entries, errors = load()
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    if args.action == 'list':
        selected = [e for e in entries if (not args.category or e['category'] == args.category)
                    and args.query.lower() in json.dumps(e).lower()]
        print(json.dumps(selected, indent=2))
        return 0
    files, uncovered = outputs(entries)
    stale = []
    for name, text in files.items():
        path = HERE / name
        if args.action == 'build':
            path.write_text(text)
        elif not path.exists() or path.read_text() != text:
            stale.append(name)
    print(f'{len(entries)} entries; {len(uncovered)} unclassified documents; {len(stale)} stale generated files')
    if uncovered:
        print('\n'.join(uncovered), file=sys.stderr)
    if stale:
        print('Regenerate: ' + ', '.join(stale), file=sys.stderr)
    return int(bool(uncovered or stale))


if __name__ == '__main__':
    raise SystemExit(main())
