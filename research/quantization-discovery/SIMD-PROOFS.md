# SIMD ternary-consumer proofs

`Kelana/SimdTernaryConsumer.lean` proves the integer range and byte-layout contract used by the native sign-folded consumer. It imports `FiberRank.response` and the sign-orbit results in `SignOrbitConsumer`.

## Dot-response range

For ternary weights `w_i` and integer query coordinates `q_i`, `response_natAbs_le` proves

```text
|response(w, q)| <= B * length(w)
```

when the lists have equal length and every `|q_i| <= B`. Here `|x|` is Lean's exact natural-number magnitude, `Int.natAbs`. The theorem has no fixed vector length.

`response_prefix_natAbs_le` applies the same result to `take k` for every `k`. It is not limited to chunk boundaries.

`SignedInt8 x` means `-128 <= x <= 127`. The negative endpoint matters: the uniform magnitude bound is 128, not 127. `response_128_signedInt8_bound` proves that every ternary response over at most 128 signed-int8 coordinates satisfies

```text
|response| <= 128 * 128 = 16384.
```

Thus the complete response lies in `[-16384, 16384]`, strictly inside the signed-16 range `[-32768, 32767]`.

## Chunk accumulation

A `Chunk` pairs a ternary weight chunk with its query chunk. `Chunk.ValidSignedInt8` records equal lengths and the signed-int8 coordinate bound. `accumulatedResponse` adds each chunk response, while `accumulatedWidth` counts original coordinates.

`accumulatedResponse_bound` proves

```text
|accumulatedResponse(chunks)| <= 128 * accumulatedWidth(chunks).
```

`every_chunk_prefix_128_bound` applies this theorem to every `chunks.take k`. If the complete chunk list covers at most 128 coordinates, every intermediate sum has magnitude at most 16384. `forty_three_chunk_prefix_bound` states the concrete 43-chunk, 128-coordinate case. The intended partition has 42 chunks of width 3 and one chunk of width 2.

The chunk count itself does not establish the range. The proof uses the total original width. This avoids the incorrect `43 * 3 = 129` bound for the shorter final chunk.

## Fourteen sign representatives

`SignOrbitConsumer.three_trit_table` proves that all 27 three-trit codes fold to indices below 14. `SignOrbitConsumer.response_flip` proves that flipping all three trits negates the response. `lookup_fold_applySign` connects the existing table-fold theorem to the Boolean sign consumed by the SIMD operation.

The runtime may therefore store 14 representative responses for a three-trit query chunk, select one representative, and apply the separately computed orbit sign. The proof does not require reconstructing the three individual weights.

## Signed-16 bytes

`wordFromBytes low high` joins two `BitVec 8` values in little-endian order. The byte types enforce `0 <= byte < 256`; `byte_value_lt_256` exposes that fact as a theorem. `wordFromBytes_parts` proves that splitting any 16-bit word into its low and high bytes and joining them returns the original word.

`signed16FromBytes` interprets the joined word as a signed two's-complement integer. `signed16_bytes_exact` proves exact reconstruction for every value in `[-16384, 16384]`. `response_signed16_bytes_exact` applies this to a complete bounded dot response. `every_chunk_prefix_signed16_exact` applies it to every intermediate chunk sum. No cast or narrowing step is left implicit in those results.

The separate sign uses the standard lane identity

```text
(word XOR mask) - mask
```

where `mask` is `0x0000` for a positive orientation and `0xffff` for a negative orientation. `xorSubtractSign_eq` proves that this is respectively `word` or the 16-bit two's-complement negation of `word`. `xorSubtractSign_exact` proves that signed interpretation produces `r` or `-r` throughout `[-16384, 16384]`. `folded_signed16_bytes_exact` composes byte reconstruction with this sign operation.

Byte shuffles and native 16-bit permutes are two possible ways to obtain the proved low and high byte pair. The Lean file specifies the value those operations must return. It does not claim that a particular instruction sequence implements the specification.

## Formal boundary

Lean proves these facts with `Std` only:

* ternary response bounds for arbitrary list lengths;
* bounds for every coordinate prefix and every chunk prefix;
* the 128-column and 43-chunk signed-16 consequences;
* exact little-endian reconstruction of a signed-16 value;
* exact XOR/subtract sign application; and
* agreement between the Boolean sign and the sign-orbit table theorem.

The native C++ implementation is outside the formal model. The proofs do not certify its parser, packed-code extraction, shuffle selectors, permute operands, vector lane ordering, loads, stores, compiler lowering, or instruction selection. Native fixtures compare that implementation against scalar reference results. Those fixture runs are implementation evidence, not Lean theorems.
