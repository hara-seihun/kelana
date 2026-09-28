#!/usr/bin/env python3
"""Warm fiber-image reader with a serialized response-prefix index."""

import struct

from fiber_codec import HEADER, FiberBook, Image, query_plan, read_bits

INDEX_MAGIC = b"KELPFX01"
INDEX_HEADER = struct.Struct("<8sH")
GROUP_HEADER = struct.Struct("<HHII")
RUN = struct.Struct("<iI")


class FastImage:
    __slots__ = (
        "blob",
        "rows",
        "columns",
        "bits",
        "plane_width",
        "scale_offset",
        "planes",
        "prefix_index",
        "_index_groups",
        "_prefix_lengths",
    )

    def __init__(self, blob):
        ordinary = Image(blob)
        self.blob = ordinary.blob
        self.rows = ordinary.rows
        self.columns = ordinary.columns
        self.bits = ordinary.bits
        self.plane_width = ordinary.plane_width
        self.scale_offset = ordinary.scale_offset
        self.planes = tuple(ordinary.planes)

        book = ordinary.book
        prefix_lengths = set()
        for row in range(self.rows):
            slot, _ = book.locate(ordinary.full_code(row))
            prefix_lengths.add(self.bits - slot.fiber_bits)
        self.prefix_index = self._compile_index(book, prefix_lengths)
        self._index_groups, self._prefix_lengths = self._index_directory(self.prefix_index)

        for row in range(self.rows):
            slot, _ = book.locate(ordinary.full_code(row))
            response, _, _ = self._response(row)
            if response != slot.response:
                raise AssertionError("packed prefix index disagrees with validated fiber slot")
        del book, ordinary

    @property
    def packed_prefix_index_bytes(self):
        return len(self.prefix_index)

    @staticmethod
    def _compile_index(book, needed_lengths):
        groups = []
        for prefix_length in sorted(needed_lengths):
            slots = [slot for slot in book.slots
                     if book.payload_bits - slot.fiber_bits == prefix_length]
            if not slots:
                raise AssertionError("required prefix length has no fiber slots")
            prefixes = [slot.offset >> slot.fiber_bits for slot in slots]
            if any(right != left + 1 for left, right in zip(prefixes, prefixes[1:])):
                raise AssertionError("equal-length canonical prefixes are not consecutive")

            runs = []
            for slot in slots:
                if runs and slot.response == runs[-1][0] + runs[-1][1]:
                    runs[-1][1] += 1
                else:
                    runs.append([slot.response, 1])
            if sum(count for _, count in runs) != len(slots):
                raise AssertionError("response runs do not cover prefix group")

            prefix_bytes = (prefix_length + 7) // 8
            group = bytearray(GROUP_HEADER.pack(
                prefix_length, prefix_bytes, len(slots), len(runs)
            ))
            group += prefixes[0].to_bytes(prefix_bytes, "big")
            for response, count in runs:
                group += RUN.pack(response, count)
            groups.append(group)

        result = bytearray(INDEX_HEADER.pack(INDEX_MAGIC, len(groups)))
        for group in groups:
            result += group
        return bytes(result)

    @staticmethod
    def _index_directory(blob):
        magic, group_count = INDEX_HEADER.unpack_from(blob)
        if magic != INDEX_MAGIC:
            raise AssertionError("invalid packed prefix index")
        offset = INDEX_HEADER.size
        groups = {}
        for _ in range(group_count):
            group_offset = offset
            prefix_length, prefix_bytes, entries, run_count = GROUP_HEADER.unpack_from(blob, offset)
            offset += GROUP_HEADER.size + prefix_bytes + run_count * RUN.size
            if prefix_length in groups or entries == 0 or run_count == 0:
                raise AssertionError("invalid packed prefix group")
            groups[prefix_length] = group_offset
        if offset != len(blob):
            raise AssertionError("truncated or appended packed prefix index")
        return groups, tuple(sorted(groups))

    def _lookup(self, prefix_length, prefix):
        group_offset = self._index_groups.get(prefix_length)
        if group_offset is None:
            return None, 0
        _, prefix_bytes, entries, run_count = GROUP_HEADER.unpack_from(
            self.prefix_index, group_offset
        )
        offset = group_offset + GROUP_HEADER.size
        first = int.from_bytes(self.prefix_index[offset:offset + prefix_bytes], "big")
        offset += prefix_bytes
        delta = prefix - first
        comparisons = 1
        if not 0 <= delta < entries:
            return None, comparisons
        for _ in range(run_count):
            response, count = RUN.unpack_from(self.prefix_index, offset)
            offset += RUN.size
            comparisons += 1
            if delta < count:
                return response + delta, comparisons
            delta -= count
        raise AssertionError("packed response runs do not cover their declared entries")

    def _response(self, row):
        if not 0 <= row < self.rows:
            raise AssertionError("row out of bounds")
        prefix = known = 0
        touched = []
        comparisons = 0
        previous_known = -1
        for prefix_length in self._prefix_lengths:
            if prefix_length != 0:
                break
            response, used = self._lookup(0, 0)
            comparisons += used
            if response is not None:
                return response, touched, comparisons
        previous_known = 0

        for offset, width in self.planes:
            word, begin, count = read_bits(self.blob, offset * 8 + row * width, width)
            touched.append((begin, count))
            prefix = (prefix << width) | word
            known += width
            for prefix_length in self._prefix_lengths:
                if not previous_known < prefix_length <= known:
                    continue
                canonical = prefix >> (known - prefix_length)
                response, used = self._lookup(prefix_length, canonical)
                comparisons += used
                if response is not None:
                    return response, touched, comparisons
            previous_known = known
        raise AssertionError("validated row has no packed response prefix")

    def evaluate(self, query):
        supplied = tuple(query)
        query = tuple(int(value) for value in supplied)
        if any(original != integer for original, integer in zip(supplied, query)):
            raise AssertionError("query must contain integer values")
        if len(query) != self.columns or any(not -127 <= value <= 127 for value in query):
            raise AssertionError("query is outside the encoded int8 block contract")
        probe = struct.unpack_from(f"{self.columns}b", self.blob, HEADER.size)
        orientation = 1 if query == probe else -1 if query == tuple(-value for value in probe) else 0
        if not orientation:
            length, _, _ = query_plan(probe, query)
            ordinary = Image(self.blob, FiberBook(probe, retain_depth=length))
            try:
                result = ordinary.evaluate(query)
                result["temporary_workspace"] = ordinary.book.workspace()
            finally:
                del ordinary
            result["packed_prefix_index_bytes"] = self.packed_prefix_index_bytes
            return result

        values = []
        touched = []
        comparisons = 0
        for row in range(self.rows):
            response, loads, used = self._response(row)
            values.append(orientation * response)
            touched.extend(loads)
            comparisons += used
        touched.append((self.scale_offset, 2 * self.rows))
        byte_addresses = {
            address
            for begin, count in touched
            for address in range(begin, begin + count)
        }
        cache_lines = {address // 64 for address in byte_addresses}
        return {
            "path": "response-prefix",
            "accumulators": values,
            "row_data_bytes": len(byte_addresses),
            "row_data_cache_lines_64": len(cache_lines),
            "payload_word_loads": len(touched) - 1,
            "guard_input_bytes": self.columns,
            "guard_reference_bytes": self.columns,
            "stored_image_bytes": len(self.blob),
            "packed_prefix_index_bytes": self.packed_prefix_index_bytes,
            "prefix_index_comparisons": comparisons,
            "caveat": "Logical row-data footprint. The 128-byte source guard is already in the main image; index bytes are reported separately. Excludes cold-load validation and hardware cache behavior.",
        }
