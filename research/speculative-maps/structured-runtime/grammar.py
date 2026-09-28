"""Lazy byte grammar and exact ordinary-token support for a bounded JSON tool batch."""
from __future__ import annotations

from collections import defaultdict

class ByteGrammar:
    """Thompson NFA with lazy subset construction; states are hashable frozensets."""

    def __init__(self):
        self.edges: list[dict[int, set[int]]] = []
        self.epsilon: list[set[int]] = []
        self.start = self.node()
        self.end = -1
        self._closures: dict[frozenset[int], frozenset[int]] = {}
        self._steps: dict[tuple[frozenset[int], int], frozenset[int]] = {}
        self.step_hits = 0
        self.step_misses = 0

    def node(self) -> int:
        self.edges.append(defaultdict(set))
        self.epsilon.append(set())
        return len(self.edges) - 1

    def link(self, source: int, target: int) -> None:
        self.epsilon[source].add(target)

    def literal(self, text: str) -> tuple[int, int]:
        start = self.node()
        at = start
        for byte in text.encode('ascii'):
            dest = self.node()
            self.edges[at][byte].add(dest)
            at = dest
        return start, at

    def charset(self, chars: str) -> tuple[int, int]:
        start, end = self.node(), self.node()
        for byte in chars.encode('ascii'):
            self.edges[start][byte].add(end)
        return start, end

    def seq(self, *parts: tuple[int, int]) -> tuple[int, int]:
        if not parts:
            at = self.node()
            return at, at
        for (_, end), (start, _) in zip(parts, parts[1:]):
            self.link(end, start)
        return parts[0][0], parts[-1][1]

    def alt(self, *parts: tuple[int, int]) -> tuple[int, int]:
        start, end = self.node(), self.node()
        for a, b in parts:
            self.link(start, a)
            self.link(b, end)
        return start, end

    def repeat(self, factory, low: int, high: int) -> tuple[int, int]:
        assert 0 <= low <= high
        start = at = self.node()
        for _ in range(low):
            a, b = factory()
            self.link(at, a)
            at = b
        end = self.node()
        self.link(at, end)
        for _ in range(high - low):
            a, b = factory()
            self.link(at, a)
            at = b
            self.link(at, end)
        return start, end

    def finish(self, fragment: tuple[int, int]) -> None:
        self.link(self.start, fragment[0])
        self.end = fragment[1]

    def closure(self, states: frozenset[int]) -> frozenset[int]:
        if states not in self._closures:
            reached = set(states)
            todo = list(states)
            while todo:
                for nxt in self.epsilon[todo.pop()]:
                    if nxt not in reached:
                        reached.add(nxt)
                        todo.append(nxt)
            self._closures[states] = frozenset(reached)
        return self._closures[states]

    @property
    def root(self) -> frozenset[int]:
        return self.closure(frozenset((self.start,)))

    def step(self, state: frozenset[int], byte: int) -> frozenset[int]:
        key = state, byte
        if key in self._steps:
            self.step_hits += 1
        else:
            self.step_misses += 1
            following = frozenset(nxt for at in state for nxt in self.edges[at].get(byte, ()))
            self._steps[key] = self.closure(following) if following else following
        return self._steps[key]

    def accepting(self, state: frozenset[int]) -> bool:
        return self.end in state


def tool_batch_grammar(min_records: int = 2, max_records: int = 4,
                       name_max: int = 16, message_max: int = 64) -> ByteGrammar:
    """Compact JSON array with fixed field order, bounded values and 2–4 records.

    ASCII string characters are printable bytes except quote/backslash, plus all JSON
    single-character escapes and ASCII Unicode escapes (\\u0000–\\u007f).
    Bounds count decoded characters, not emitted bytes. Strings never emit raw UTF-8.
    """
    if not 1 <= min_records <= max_records:
        raise ValueError('record bounds must be positive and ordered')
    if name_max < 1 or message_max < 1:
        raise ValueError('string bounds must be positive')
    g = ByteGrammar()
    def string_char(alphabet: str):
        options = [g.charset(alphabet), g.seq(g.literal('\\'), g.charset('"\\/bfnrt'))]
        # Restrict Unicode escapes to ASCII scalar values: no surrogate ambiguity.
        options.append(g.seq(g.literal('\\u00'), g.charset('01234567'),
                             g.charset('0123456789abcdefABCDEF')))
        return g.alt(*options)

    letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    message_chars = ''.join(chr(i) for i in range(32, 127) if i not in (34, 92))
    def json_string(alphabet: str, minimum: int, maximum: int):
        return g.seq(g.literal('"'), g.repeat(lambda: string_char(alphabet), minimum, maximum), g.literal('"'))

    def integer():
        unsigned = g.alt(g.literal('0'), g.seq(g.charset('123456789'),
                                                g.repeat(lambda: g.charset('0123456789'), 0, 5)))
        return g.seq(g.repeat(lambda: g.literal('-'), 0, 1), unsigned)

    def record():
        return g.seq(g.literal('{"action":'),
                     g.alt(*(g.literal('"' + kind + '"') for kind in ('call', 'notify', 'cancel'))),
                     g.literal(',"name":'), json_string(letters, 1, name_max),
                     g.literal(',"id":'), integer(),
                     g.literal(',"message":'), json_string(message_chars, 1, message_max),
                     g.literal(',"value":'), integer(), g.literal('}'))

    g.finish(g.seq(g.literal('['), record(),
                   g.repeat(lambda: g.seq(g.literal(','), record()), min_records - 1, max_records - 1),
                   g.literal(']')))
    return g


class StructuredRuntime:
    """Byte-language support under every ordinary vocabulary tokenization.

    The input trie has the `{'next': {byte: child}, 'ids': [token_id]}` shape
    returned by tokenizer-spans/measure.py:vocabulary. `allowed` excludes special
    tokens; the caller stops only at `accepting(state)` (no implicit EOS edge).
    Preparation and cache misses run on CPU and belong in the timing ledger.
    """

    def __init__(self, token_root: dict, grammar: ByteGrammar | None = None, *,
                 min_records: int = 2, max_records: int = 4,
                 name_max: int = 16, message_max: int = 64):
        self.token_root = token_root
        self.grammar = grammar if grammar is not None else tool_batch_grammar(
            min_records, max_records, name_max, message_max)
        self.root = self.grammar.root
        self._allowed: dict[frozenset[int], dict[int, frozenset[int]]] = {}

    def accepting(self, state: frozenset[int]) -> bool:
        return self.grammar.accepting(state)

    def allowed(self, state: frozenset[int]) -> dict[int, frozenset[int]]:
        if state not in self._allowed:
            result = {}
            stack = [(state, self.token_root)]
            while stack:
                at, trie = stack.pop()
                for byte, child in trie['next'].items():
                    dest = self.grammar.step(at, byte)
                    if dest:
                        for token_id in child['ids']:
                            result[token_id] = dest
                        stack.append((dest, child))
            self._allowed[state] = result
        return self._allowed[state]

    def cache_stats(self) -> dict[str, int]:
        return {'allowed_states': len(self._allowed),
                'byte_transition_hits': self.grammar.step_hits,
                'byte_transition_misses': self.grammar.step_misses,
                'byte_transition_entries': len(self.grammar._steps)}

    def singleton_run(self, state: frozenset[int]) -> tuple[tuple[int, ...], frozenset[int]]:
        tokens = []
        while not self.accepting(state):
            choices = self.allowed(state)
            if len(choices) != 1:
                break
            token_id, state = next(iter(choices.items()))
            tokens.append(token_id)
        return tuple(tokens), state
