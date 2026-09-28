#!/usr/bin/env python3
"""Exact token-level support for three deliberately finite byte languages."""

import hashlib
import json
import time
from collections import Counter, defaultdict
from pathlib import Path

from tokenizers import Tokenizer

MODEL = Path("/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/tokenizer.json")


def byte_alphabet():
    plain = set(range(ord("!"), ord("~") + 1)) | set(range(ord("¡"), ord("¬") + 1)) | set(range(ord("®"), ord("ÿ") + 1))
    source = sorted(plain) + [b for b in range(256) if b not in plain]
    encoded = sorted(plain) + [256 + i for i, b in enumerate(b for b in range(256) if b not in plain)]
    return {chr(u): b for b, u in zip(source, encoded)}


def languages():
    json_records = []
    for space_a in ("", " "):
        for kind in ('"ok"', '"o\\u006b"'):
            for space_b in ("", " "):
                for value in ("0", "1"):
                    before = '{"kind":' + space_a + kind + ',"value":' + space_b
                    json_records.append((before + value + "}", (len(before.encode()),)))
    code_records = []
    for indent in ("", "    "):
        for space in ("", " "):
            for value in ("true", "false"):
                before = indent + "return {\"ok\":" + space
                code_records.append((before + value + "}\n", (len(before.encode()),)))
    repeat_records = []
    for a in ("0", "1"):
        for b in ("0", "1"):
            before = '{"items":['
            middle = before + a + ","
            repeat_records.append((middle + b + "]}", (len(before.encode()), len(middle.encode()))))
    return {"json": json_records, "code": code_records, "repeated": repeat_records}


def vocabulary(raw):
    alphabet = byte_alphabet()
    root = {"next": {}, "ids": []}
    data = {}
    for spelling, token_id in raw["model"]["vocab"].items():
        token = bytes(alphabet[c] for c in spelling)
        data[token_id] = token
        node = root
        for byte in token:
            node = node["next"].setdefault(byte, {"next": {}, "ids": []})
        node["ids"].append(token_id)
    assert set(bytes((b,)) for b in range(256)).issubset(set(data.values()))
    return root, data


def grammar(records):
    root = {"next": {}, "edges": [], "end": False, "prefix": b""}
    nodes = [root]
    boundaries = defaultdict(set)
    for text, offsets in records:
        bs = text.encode()
        assert bs.decode() == text
        node = root
        for index, byte in enumerate(bs):
            if byte not in node["next"]:
                child = {"next": {}, "edges": [], "end": False, "prefix": bs[:index + 1]}
                nodes.append(child)
                node["next"][byte] = child
            node = node["next"][byte]
        node["end"] = True
        for offset in offsets:
            boundaries[bs[:offset]].add(bs)
    return nodes, boundaries


def product(nodes, token_root):
    visits = 0
    for start in nodes:
        stack = [(start, token_root)]
        while stack:
            grammar_node, vocab_node = stack.pop()
            visits += 1
            for byte, next_vocab in vocab_node["next"].items():
                next_grammar = grammar_node["next"].get(byte)
                if next_grammar is not None:
                    for token_id in next_vocab["ids"]:
                        start["edges"].append((token_id, next_grammar))
                    stack.append((next_grammar, next_vocab))
        start["edges"].sort(key=lambda x: x[0])
    return visits


def singleton_chain(node):
    ids = []
    while len(node["edges"]) == 1:
        token_id, node = node["edges"][0]
        ids.append(token_id)
    return ids, node


def path_counts(nodes):
    counts = {}
    for node in sorted(nodes, key=lambda x: len(x["prefix"]), reverse=True):
        counts[node["prefix"]] = int(node["end"]) + sum(counts[nxt["prefix"]] for _, nxt in node["edges"])
    return counts


def macro_graph(root, counts, nodes, token_bytes):
    graph = {}
    todo = [root]
    contracted_tokens = 0
    while todo:
        node = todo.pop()
        prefix = node["prefix"]
        if prefix in graph:
            continue
        transitions = []
        for token_id, successor in node["edges"]:
            known, destination = singleton_chain(successor)
            ids = (token_id, *known)
            assert prefix + b"".join(token_bytes[t] for t in ids) == destination["prefix"]
            transitions.append((ids, destination["prefix"]))
            contracted_tokens += len(known)
            todo.append(destination)
        graph[prefix] = transitions
    macro_counts = {}
    for prefix in sorted(graph, key=len, reverse=True):
        macro_counts[prefix] = int(not graph[prefix]) + sum(macro_counts[dest] for _, dest in graph[prefix])
    assert macro_counts[b""] == counts[b""]
    totals = {}
    for node in sorted(nodes, key=lambda x: len(x["prefix"]), reverse=True):
        total_tokens = 0
        total_singletons = 0
        for _, successor in node["edges"]:
            suffix_tokens, suffix_singletons = totals[successor["prefix"]]
            multiplicity = counts[successor["prefix"]]
            total_tokens += multiplicity + suffix_tokens
            total_singletons += (multiplicity if len(node["edges"]) == 1 else 0) + suffix_singletons
        totals[node["prefix"]] = (total_tokens, total_singletons)
    total, singleton = totals[b""]
    return {"reachable_macro_states": len(graph),
            "reachable_macro_edges": sum(len(edges) for edges in graph.values()),
            "macro_prepared_singleton_tokens_on_edges": contracted_tokens,
            "uniform_token_path_mean_tokens": round(total / counts[b""], 4),
            "uniform_token_path_mean_singletons": round(singleton / counts[b""], 4)}


def canonical(tokenizer, root, records, token_bytes):
    run_hist = Counter()
    tokens_total = 0
    ambiguous_positions = 0
    counterexample = None
    for text, _ in records:
        node = root
        ids = tokenizer.encode(text, add_special_tokens=False).ids
        assert b"".join(token_bytes[token_id] for token_id in ids) == text.encode()
        tokens_total += len(ids)
        run = 0
        for token_id in ids:
            candidates = dict(node["edges"])
            assert token_id in candidates, (text, token_id, node["prefix"])
            if len(candidates) == 1:
                run += 1
            else:
                ambiguous_positions += 1
                if run:
                    run_hist[run] += 1
                    run = 0
                if counterexample is None:
                    other = next((t for t in candidates if t != token_id), None)
                    if other is not None:
                        counterexample = {"text": text, "prefix": node["prefix"].decode(),
                                          "canonical_token": {"id": token_id, "bytes": token_bytes[token_id].decode("utf-8", "backslashreplace")},
                                          "other_legal_token": {"id": other, "bytes": token_bytes[other].decode("utf-8", "backslashreplace")},
                                          "allowed_count": len(candidates)}
            node = candidates[token_id]
        assert node["end"], text
        if run:
            run_hist[run] += 1
    return {"canonical_tokens": tokens_total, "canonical_ambiguous_steps": ambiguous_positions,
            "canonical_singleton_runs": dict(sorted(run_hist.items())), "counterexample": counterexample}


def canonical_policy(tokenizer, records):
    root = {}
    paths = []
    for text, _ in records:
        ids = tokenizer.encode(text, add_special_tokens=False).ids
        paths.append(ids)
        node = root
        for token_id in ids:
            node = node.setdefault(token_id, {})
    runs = Counter()
    singleton_steps = 0
    total_steps = 0
    for path in paths:
        node = root
        run = 0
        for token_id in path:
            total_steps += 1
            if len(node) == 1:
                singleton_steps += 1
                run += 1
            elif run:
                runs[run] += 1
                run = 0
            node = node[token_id]
        if run:
            runs[run] += 1
    return {"canonical_policy_root_allowed_tokens": len(root),
            "canonical_policy_singleton_steps": singleton_steps,
            "canonical_policy_total_steps": total_steps,
            "canonical_policy_singleton_runs": dict(sorted(runs.items()))}


def main():
    t0 = time.perf_counter()
    model_data = MODEL.read_bytes()
    raw = json.loads(model_data)
    trie, token_bytes = vocabulary(raw)
    tokenizer = Tokenizer.from_file(str(MODEL))
    prep = time.perf_counter() - t0
    result = {"model_revision": json.loads((MODEL.parent / "source.json").read_text())["revision"],
              "tokenizer_sha256": hashlib.sha256(model_data).hexdigest(),
              "vocab_tokens": len(token_bytes), "vocab_decoded_bytes": sum(map(len, token_bytes.values())),
              "vocab_index_seconds": round(prep, 4), "languages": {}}
    for name, records in languages().items():
        start = time.perf_counter()
        nodes, boundaries = grammar(records)
        visits = product(nodes, trie)
        counts = path_counts(nodes)
        support = Counter(len(n["edges"]) for n in nodes if not n["end"])
        macro_lengths = Counter()
        macro_starts = 0
        for node in nodes:
            ids, _ = singleton_chain(node)
            if ids:
                macro_starts += 1
                macro_lengths[len(ids)] += 1
        crossing = []
        for prefix, completions in boundaries.items():
            for node in nodes:
                p = node["prefix"]
                if len(p) >= len(prefix) or not prefix.startswith(p):
                    continue
                for token_id, target in node["edges"]:
                    if len(target["prefix"]) <= len(prefix):
                        continue
                    if any(text.startswith(target["prefix"]) for text in completions):
                        crossing.append({"from": p.decode(), "boundary": prefix.decode(),
                                         "token_id": token_id, "token_bytes": token_bytes[token_id].decode("utf-8", "backslashreplace")})
        canonical_result = canonical(tokenizer, nodes[0], records, token_bytes)
        result["languages"][name] = {
            "strings": len(records), "grammar_bytes": sum(len(s.encode()) for s, _ in records),
            "byte_states": len(nodes), "terminal_states": sum(n["end"] for n in nodes),
            "product_visits": visits, "token_edges": sum(len(n["edges"]) for n in nodes),
            "all_legal_token_paths": str(counts[b""]), "support_histogram_nonterminal": dict(sorted(support.items())),
            "singleton_states": support[1], "singleton_chain_starts": macro_starts,
            "singleton_chain_length_by_start": dict(sorted(macro_lengths.items())),
            "root_allowed_tokens": len(nodes[0]["edges"]), "root_singleton_run": len(singleton_chain(nodes[0])[0]),
            "boundary_crossing_edges": len(crossing), "boundary_crossing_examples": crossing[:4],
            "preparation_seconds": round(time.perf_counter() - start, 4),
            **canonical_result, **canonical_policy(tokenizer, records),
            **macro_graph(nodes[0], counts, nodes, token_bytes)}
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
