#!/usr/bin/env python3
"""Lossless ternary rows with a directly readable dot-product prefix.

A row contains a response prefix and an enumerative rank within that response's
fiber. Dyadic slots make every row the same bit width. Sixteen-bit planes place
common prefixes together instead of fetching a full strided row on a match.
"""
from bisect import bisect_right
from dataclasses import dataclass
from math import gcd
import struct
import sys

MAGIC = b'KELFIB01'
HEADER = struct.Struct('<8sIHHHH')
ALPHABET = (-1, 0, 1)


def ceil_log2(value):
    assert value > 0
    return (value-1).bit_length()


@dataclass(frozen=True)
class Slot:
    response: int
    count: int
    fiber_bits: int
    offset: int

    @property
    def width(self):
        return 1 << self.fiber_bits


class FiberBook:
    def __init__(self, probe, retain_depth=None):
        self.probe = tuple(int(v) for v in probe)
        assert self.probe and all(-127 <= v <= 127 for v in self.probe)
        self.divisor = gcd(*self.probe) or 1
        self.steps = tuple(v//self.divisor for v in self.probe)
        n = len(self.probe)
        self.retained_depth = n if retain_depth is None else retain_depth
        assert 0 <= self.retained_depth <= n
        self.counts = [None]*(n+1)
        self.bounds = [0]*(n+1)
        following = [1]
        if n <= self.retained_depth:
            self.counts[n] = following
        for i in range(n-1, -1, -1):
            width = abs(self.steps[i])
            current = [0]*(len(following)+2*width)
            for j, count in enumerate(following):
                current[j] += count
                current[j+width] += count
                current[j+2*width] += count
            if i <= self.retained_depth:
                self.counts[i] = current
            following = current
            self.bounds[i] = self.bounds[i+1]+width
        root = self.counts[0]
        assert sum(root) == 3**n
        fibers = [(ceil_log2(count), (response-self.bounds[0])*self.divisor, count)
                  for response, count in enumerate(root) if count]
        fibers.sort(key=lambda item: (-item[0], item[1]))
        self.slots, offset = [], 0
        for bits, response, count in fibers:
            width = 1 << bits
            assert offset % width == 0
            self.slots.append(Slot(response, count, bits, offset))
            offset += width
        self.rounded_mass = offset
        self.payload_bits = ceil_log2(offset)
        self.offsets = [slot.offset for slot in self.slots]
        self.by_response = {slot.response: slot for slot in self.slots}
        assert self.rounded_mass < 2*3**n
        assert self.payload_bits <= ceil_log2(3**n)+1

    def count(self, depth, response):
        index = response+self.bounds[depth]
        table = self.counts[depth]
        assert table is not None, 'suffix table was not retained for this operation'
        return table[index] if 0 <= index < len(table) else 0

    def rank(self, weights):
        assert self.retained_depth == len(self.probe)
        weights = tuple(int(v) for v in weights)
        assert len(weights) == len(self.probe) and all(v in ALPHABET for v in weights)
        normalized = sum(w*q for w, q in zip(weights, self.steps))
        response = normalized*self.divisor
        remaining, rank = normalized, 0
        for i, (w, q) in enumerate(zip(weights, self.steps)):
            if w > -1:
                rank += self.count(i+1, remaining+q)
            if w > 0:
                rank += self.count(i+1, remaining)
            remaining -= w*q
        slot = self.by_response[response]
        assert remaining == 0 and 0 <= rank < slot.count
        return slot.offset+rank

    def locate(self, code):
        assert 0 <= code < (1 << self.payload_bits)
        index = bisect_right(self.offsets, code)-1
        assert index >= 0
        slot = self.slots[index]
        rank = code-slot.offset
        assert 0 <= rank < slot.count, 'unused dyadic rank is not a weight vector'
        return slot, rank

    def unrank(self, code, length=None):
        length = len(self.steps) if length is None else length
        assert 0 <= length <= self.retained_depth
        slot, rank = self.locate(code)
        remaining, weights = slot.response//self.divisor, []
        for i, q in enumerate(self.steps[:length]):
            for weight in ALPHABET:
                count = self.count(i+1, remaining-weight*q)
                if rank < count:
                    weights.append(weight)
                    remaining -= weight*q
                    break
                rank -= count
            else:
                raise AssertionError('fiber rank has no completion')
        if length == len(self.steps):
            assert remaining == 0 and rank == 0
        return weights

    def prefix_response(self, prefix, known_bits):
        assert 0 <= known_bits <= self.payload_bits
        shift = self.payload_bits-known_bits
        lower = prefix << shift
        upper = ((prefix+1) << shift)-1
        index = bisect_right(self.offsets, lower)-1
        if index < 0:
            return None
        slot = self.slots[index]
        if upper < slot.offset+slot.width:
            return slot.response
        return None

    def workspace(self):
        tables = [t for t in self.counts if t is not None]
        cells = sum(len(t) for t in tables)
        return dict(suffix_count_cells=cells, retained_depth=self.retained_depth,
                    suffix_count_integer_bytes=sum((v.bit_length()+7)//8 for t in tables for v in t),
                    python_count_list_and_int_bytes=sum(sys.getsizeof(t) for t in tables)+
                        sum(sys.getsizeof(v) for t in tables for v in t),
                    slots=len(self.slots),
                    python_slot_and_offset_bytes=sum(sys.getsizeof(s)+sys.getsizeof(s.offset)+sys.getsizeof(s.count)
                                                     for s in self.slots),
                    note='Logical list/int allocation estimate, not RSS; shared small integers may be counted repeatedly. Dictionaries and interpreter overhead are additional.')


def query_plan(probe, query):
    plans = []
    for alpha in (0, 1, -1):
        residual = tuple(x-alpha*q for x, q in zip(query, probe))
        length = max((i+1 for i, value in enumerate(residual) if value), default=0)
        plans.append((length, sum(v != 0 for v in residual), abs(alpha), alpha, residual))
    length, _, _, alpha, residual = min(plans)
    return length, alpha, residual


def pack_fixed(values, width):
    assert width > 0
    result = bytearray()
    accumulator = bits = 0
    for value in values:
        assert 0 <= value < (1 << width)
        accumulator = (accumulator << width) | value
        bits += width
        while bits >= 8:
            bits -= 8
            result.append((accumulator >> bits) & 255)
        accumulator &= (1 << bits)-1
    if bits:
        result.append(accumulator << (8-bits))
    return bytes(result)


def read_bits(blob, start, width):
    begin, intra = divmod(start, 8)
    count = (intra+width+7)//8
    value = int.from_bytes(blob[begin:begin+count], 'big')
    return (value >> (8*count-intra-width)) & ((1 << width)-1), begin, count


def encode(book, weights, scale_bits, plane_width=16):
    assert len(weights) == len(scale_bits) and weights
    assert plane_width == 16
    codes = [book.rank(w) for w in weights]
    blob = bytearray(HEADER.pack(MAGIC, len(weights), len(book.probe), book.payload_bits, plane_width, 2))
    blob += struct.pack(f'{len(book.probe)}b', *book.probe)
    blob += struct.pack(f'<{len(scale_bits)}H', *(int(v) for v in scale_bits))
    remaining = book.payload_bits
    while remaining:
        width = min(plane_width, remaining)
        remaining -= width
        blob += pack_fixed([(code >> remaining) & ((1 << width)-1) for code in codes], width)
    return bytes(blob)


class Image:
    def __init__(self, blob, book=None):
        self.blob = bytes(blob)
        magic, self.rows, self.columns, self.bits, self.plane_width, scale_bytes = HEADER.unpack_from(blob)
        assert magic == MAGIC and self.rows > 0 and self.columns > 0
        assert self.plane_width == 16 and scale_bytes == 2
        probe = struct.unpack_from(f'{self.columns}b', blob, HEADER.size)
        self.book = book if book is not None else FiberBook(probe)
        assert self.book.probe == probe and self.book.payload_bits == self.bits
        self.scale_offset = HEADER.size+self.columns
        self.scale_bits = struct.unpack_from(f'<{self.rows}H', blob, self.scale_offset)
        offset = self.scale_offset+2*self.rows
        self.planes = []
        remaining = self.bits
        while remaining:
            width = min(self.plane_width, remaining)
            remaining -= width
            self.planes.append((offset, width))
            offset += (self.rows*width+7)//8
        assert offset == len(blob), 'truncated or appended image'
        # Validate all row ranks once at load, without reconstructing weights.
        for row in range(self.rows):
            self.book.locate(self.full_code(row))

    def full_code(self, row):
        assert 0 <= row < self.rows
        code = 0
        for offset, width in self.planes:
            word, _, _ = read_bits(self.blob, offset*8+row*width, width)
            code = (code << width) | word
        return code

    def decode_weights(self, row):
        return self.book.unrank(self.full_code(row))

    def response(self, row):
        prefix = known = 0
        touched = []
        response = self.book.prefix_response(prefix, known)
        for offset, width in self.planes:
            if response is not None:
                break
            word, begin, count = read_bits(self.blob, offset*8+row*width, width)
            touched.append((begin, count))
            prefix = (prefix << width) | word
            known += width
            response = self.book.prefix_response(prefix, known)
        assert response is not None
        return response, touched

    def evaluate(self, query):
        supplied = tuple(query)
        query = tuple(int(v) for v in supplied)
        assert all(original == integer for original, integer in zip(supplied, query))
        assert len(query) == self.columns and all(-127 <= v <= 127 for v in query)
        orientation = 1 if query == self.book.probe else -1 if query == tuple(-v for v in self.book.probe) else 0
        if orientation:
            values, touched = [], []
            for row in range(self.rows):
                value, loads = self.response(row)
                values.append(orientation*value)
                touched.extend(loads)
            # Include FP16 scale loads needed at the existing consumer boundary.
            touched.append((self.scale_offset, 2*self.rows))
            byte_addresses = {a for begin, count in touched for a in range(begin, begin+count)}
            lines = {a//64 for a in byte_addresses}
            return dict(path='response-prefix', accumulators=values,
                        row_data_bytes=len(byte_addresses), row_data_cache_lines_64=len(lines),
                        payload_word_loads=len(touched)-1,
                        guard_input_bytes=self.columns, guard_reference_bytes=self.columns,
                        caveat='Logical row-data footprint. Excludes codebook/count-table accesses, cold-load validation and hardware cache behavior.')
        length, alpha, residual = query_plan(self.book.probe, query)
        values = []
        for row in range(self.rows):
            if length == 0 and alpha == 0:
                values.append(0)
                continue
            code = self.full_code(row)
            slot, _ = self.book.locate(code)
            prefix = self.book.unrank(code, length)
            values.append(alpha*slot.response+sum(w*x for w, x in zip(prefix, residual)))
        return dict(path='fiber-unrank', accumulators=values,
                    decoded_trits=self.rows*length, decoded_prefix_length=length, response_multiplier=alpha,
                    stored_image_bytes=len(self.blob),
                    caveat='Exact reconstruction from this image, not an original-weight fallback; no native GPU implementation.')
