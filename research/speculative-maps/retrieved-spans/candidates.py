"""Exact token-ID copy proposals from the visible prefix and a training-only corpus.

The retained first target token is an explicit input. Neither labels nor target hidden
states enter the search. Returned paths start with that retained token.
"""
from dataclasses import dataclass
from time import perf_counter

import numpy as np


@dataclass(frozen=True)
class SearchStats:
    postings_examined: int
    tokens_compared: int
    seconds: float


class SpanIndex:
    def __init__(self, train_tokens):
        self.tokens = np.asarray(train_tokens, dtype=np.int32)
        begun = perf_counter()
        self.order = np.argsort(self.tokens, kind='stable').astype(np.int32)
        counts = np.bincount(self.tokens)
        self.offsets = np.empty(len(counts) + 1, dtype=np.int32)
        self.offsets[0] = 0
        np.cumsum(counts, out=self.offsets[1:])
        self.build_seconds = perf_counter() - begun

    @property
    def bytes(self):
        return self.tokens.nbytes + self.order.nbytes + self.offsets.nbytes

    def propose(self, prompt, retained_first, *, horizon=6, max_matches=8, max_postings=4096):
        """Return independently sourced paths, with no target continuation supplied.

        Scan recent corpus occurrences of the retained token, then take the longest
        backward match against the visible prefix. Ties prefer prompt copies and
        recent occurrences. `max_postings` bounds worst-case work on common tokens.
        """
        begun = perf_counter()
        visible = tuple(map(int, prompt)) + (int(retained_first),)
        root = visible[-1]
        rows = []
        examined = comparisons = 0

        for position in range(len(visible) - 1):
            if visible[position] != root or position + horizon > len(visible):
                continue
            matched = 1
            while matched < min(position + 1, len(visible)) and visible[position - matched] == visible[-1 - matched]:
                matched += 1
                comparisons += 1
            rows.append((matched, 1, position, tuple(visible[position:position + horizon])))

        lo = int(self.offsets[root]) if 0 <= root < len(self.offsets) else len(self.order)
        hi = int(self.offsets[root + 1]) if 0 <= root < len(self.offsets) - 1 else len(self.order)
        postings = self.order[max(lo, hi - max_postings):hi]
        examined = len(postings)
        usable = postings[postings + horizon <= len(self.tokens)]
        matched = np.ones(len(usable), dtype=np.int16)
        active = np.arange(len(usable), dtype=np.int32)
        for back in range(1, len(visible)):
            eligible = active[usable[active] >= back]
            if len(eligible) == 0:
                break
            comparisons += len(eligible)
            equal = self.tokens[usable[eligible] - back] == visible[-1 - back]
            active = eligible[equal]
            matched[active] += 1

        unique = []
        seen = set()

        def add(match, local, position, path):
            if path not in seen:
                unique.append({'path': path, 'matched_prefix': int(match),
                               'source': 'prompt' if local else 'train', 'position': int(position)})
                seen.add(path)

        rows.sort(key=lambda row: (-row[0], -row[1], -row[2]))
        corpus_rank = np.lexsort((-usable, -matched))
        cursor = 0
        for match, local, position, path in rows:
            while cursor < len(corpus_rank) and int(matched[corpus_rank[cursor]]) > match:
                p = int(usable[corpus_rank[cursor]])
                add(matched[corpus_rank[cursor]], 0, p, tuple(map(int, self.tokens[p:p + horizon])))
                cursor += 1
                if len(unique) == max_matches:
                    return unique, SearchStats(examined, comparisons, perf_counter() - begun)
            add(match, local, position, path)
            if len(unique) == max_matches:
                return unique, SearchStats(examined, comparisons, perf_counter() - begun)
        while cursor < len(corpus_rank) and len(unique) < max_matches:
            i = corpus_rank[cursor]
            p = int(usable[i])
            add(matched[i], 0, p, tuple(map(int, self.tokens[p:p + horizon])))
            cursor += 1
        return unique, SearchStats(examined, comparisons, perf_counter() - begun)


def copy_tree(retained_first, proposals, budget, *, learned=()):
    """Spend one node per unique token prefix; use learned ordering for spare slots."""
    nodes = [(int(retained_first),)]
    selected = set(nodes)
    for path in [p['path'] for p in proposals] + list(learned):
        for length in range(2, len(path) + 1):
            prefix = tuple(path[:length])
            if prefix in selected:
                continue
            if len(selected) == budget:
                return nodes
            assert prefix[:-1] in selected
            nodes.append(prefix)
            selected.add(prefix)
    return nodes
