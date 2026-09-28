"""CPU contract tests for lazy JSON token support."""
import gc
import importlib.util
import json
import unittest
import weakref
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('structured_grammar', HERE / 'grammar.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
StructuredRuntime = module.StructuredRuntime


def vocabulary(tokens):
    root = {'next': {}, 'ids': []}
    for token_id, spelling in enumerate(tokens):
        node = root
        for byte in spelling:
            node = node['next'].setdefault(byte, {'next': {}, 'ids': []})
        node['ids'].append(token_id)
    return root


class GrammarTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tokens = [bytes((i,)) for i in range(256)] + [
            b'[{"action":"call","name":"', b'AB', b'\\n', b'\\u0041',
            b'","id":', b'12', b'0', b']', b'{', b'"', b'\\',
        ]
        cls.runtime = StructuredRuntime(vocabulary(cls.tokens))

    def consume(self, data: bytes, ids=None):
        state = self.runtime.root
        if ids is None:
            ids = list(data)
        for token_id in ids:
            self.assertIn(token_id, self.runtime.allowed(state))
            state = self.runtime.allowed(state)[token_id]
        self.assertEqual(b''.join(self.tokens[i] for i in ids), data)
        return state

    def record(self, **kwargs):
        return {'action': 'call', 'name': 'AB', 'id': 12,
                'message': 'Hi', 'value': -7} | kwargs

    def test_full_valid_records_and_escapes(self):
        for count in (2, 3, 4):
            text = json.dumps([self.record(), self.record(action='notify', message='say "hi"\n')]
                              + [self.record(action='cancel', id=0)] * (count - 2),
                              separators=(',', ':'))
            self.assertTrue(self.runtime.accepting(self.consume(text.encode())))
        escaped = b'[{"action":"call","name":"\\u0041","id":0,"message":"\\n\\\\\\\"","value":-12},' \
                  b'{"action":"cancel","name":"B","id":4,"message":"x","value":0}]'
        self.assertTrue(self.runtime.accepting(self.consume(escaped)))
        self.assertEqual(len(json.loads(escaped)), 2)

    def test_all_ordinary_tokenizations_and_cross_field_edges(self):
        text = json.dumps([self.record(), self.record(action='notify')], separators=(',', ':')).encode()
        split = list(text)
        merged = []
        offset = 0
        while offset < len(text):
            matches = [(i, t) for i, t in enumerate(self.tokens[256:], 256) if text.startswith(t, offset)]
            if matches:
                i, t = max(matches, key=lambda pair: len(pair[1]))
                merged.append(i)
                offset += len(t)
            else:
                merged.append(text[offset])
                offset += 1
        self.assertTrue(self.runtime.accepting(self.consume(text, split)))
        self.assertTrue(self.runtime.accepting(self.consume(text, merged)))
        self.assertIn(256, merged)
        self.assertIn(260, merged)  # token crosses the name/value field boundary
        self.assertNotEqual(split, merged)
        # Two distinct IDs with identical bytes remain two distinct legal decisions.
        prefix = text[:text.index(b'"name":"') + len(b'"name":"')]
        state = self.consume_prefix(prefix)
        self.assertIn(256 + 1, self.runtime.allowed(state))

    def consume_prefix(self, data):
        at = self.runtime.root
        for byte in data:
            at = self.runtime.allowed(at)[byte]
        return at

    def test_rejections_and_exact_stop(self):
        valid = json.dumps([self.record(), self.record()], separators=(',', ':')).encode()
        self.assertTrue(self.runtime.accepting(self.consume(valid)))
        self.assertEqual(self.runtime.allowed(self.consume(valid)), {})
        for bad in (b'\xc3\xa9', b'01', b'-01', b'\\x', b'\\uD800', b'\\u0080'):
            if bad == b'\xc3\xa9':
                prefix = valid[:valid.index(b'Hi')]
            elif bad[:1] in (b'0', b'-'):
                prefix = valid[:valid.index(b'12')]
            else:
                prefix = valid[:valid.index(b'Hi')]
            state = self.consume_prefix(prefix)
            for byte in bad:
                if byte not in self.runtime.allowed(state):
                    break
                state = self.runtime.allowed(state)[byte]
            else:
                self.fail(f'bad fragment accepted: {bad!r}')
        with self.assertRaises(AssertionError):
            self.consume(valid + b',')
        short = json.dumps([self.record()], separators=(',', ':')).encode()
        self.assertFalse(self.runtime.accepting(self.consume(short[:-1])))
        self.assertIn(ord(','), self.runtime.allowed(self.consume_prefix(short[:-1])))

    def test_configured_bounds_and_cache_lifetime(self):
        short = StructuredRuntime(vocabulary(self.tokens), min_records=2, max_records=2,
                                  name_max=2, message_max=3)
        data = json.dumps([self.record(message='Hi'), self.record(message='Hi')],
                          separators=(',', ':')).encode()
        at = short.root
        for byte in data:
            at = short.allowed(at)[byte]
        self.assertTrue(short.accepting(at))
        self.assertGreater(short.cache_stats()['byte_transition_misses'], 0)
        ref = weakref.ref(short.grammar)
        del short, at
        gc.collect()
        self.assertIsNone(ref())

    def test_singleton_run_is_genuine_token_support(self):
        run = StructuredRuntime(vocabulary([bytes((i,)) for i in range(256)]))
        tokens, end = run.singleton_run(run.root)
        self.assertEqual(tokens, tuple(b'[{"action":"'))
        self.assertFalse(run.accepting(end))
        self.assertGreater(len(run.allowed(end)), 1)
        for token in tokens:
            self.assertIsInstance(token, int)
        # A longer ordinary token competes with the byte-level run.
        self.assertEqual(self.runtime.singleton_run(self.runtime.root)[0], ())


if __name__ == '__main__':
    unittest.main()
