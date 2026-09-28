# Canonical bytes are an observation, not the required live addresses

The [accepted resident program](../kivi-resident-cache/README.md) establishes exact native update closure. It also exposes the cost of treating a compact serialization as the execution layout: its single-lane flat maintainer repeatedly shifts live records. At the measured K-flush boundaries the dictionary program is slower in all eight comparisons, with median matched-state event ratio5.100. This is not an obstruction to exact record sharing; it identifies a requirement imposed by that physical representation.

## Decode equivalence, not physical equality

Let a physical state consist of a heap `H : A → V` and a chronological reference list `r : List A`. Its logical state is

\[
D(H,r)=[H(r_0),\ldots,H(r_{n-1})].
\]

An address map `f : A → B` and heap `G : B → V` preserve the logical state whenever

\[
G(f(a))=H(a)\quad\text{for every address }a\text{ referenced by }r.
\]

No global bijection is required. Live addresses may merge precisely when their decoded records agree; unreferenced heap contents are invisible. Conversely, if two live names merge under this condition, their records must agree. This is more general than permuting canonical first-use IDs, but it does not authorize hash collisions, approximate equality or dropping chronological references.

Any deterministic reader of the same ordered decoded records produces the same result. In particular, this includes the *original ordered floating-point reader* if the decoder preserves its exact bytes and reduction order. Grouping probability by value is a separate floating reassociation, not a consequence that must be used by a stable-address implementation.

## Local transitions

For a value `v` arriving at a phase boundary:

1. If a live address `a` already contains exactly `v`, append its handle to `r`. No payload write is required.
2. Otherwise choose an address `a` absent from **all live references in its storage region**, write `v` there and append `a`. Every prior live lookup is unchanged; the decoded list is `D(H,r) ++ [v]`.
3. Retiring the oldest occurrence removes one chronological handle. The record may be reclaimed only after its final remaining reference disappears. Clearing on first retirement is wrong when a second reference survives.
4. Typed aging applies the exact original quantizer to the oldest recent record, interns those resulting bytes in the aged-record store, and removes the recent occurrence. Recent BF16 and quantized records have separate decoding types; equal source values alone do not justify sharing incompatible stored representations.

If a maintained reference counter equals the actual chronological multiplicity, append increments the selected handle's count and retiring its occurrence decrements it by one. The resulting count is zero exactly when no reference remains. `reference_increment`, `reference_decrement`, `references_zero` and `reclaim_count_zero` derive this last-use rule in Lean; they do not assume that an arbitrary program's counters are accurate. The independent byte audits check the actual count/reference multiset equality at each phase.

These local transitions need not canonicalize every other handle or relocate every live payload. A canonical serialization can be produced for audit by traversing chronological references after the fact. It is not an online operation unless the consumer actually requires those byte positions.

[`Kelana/StableRecordCoordinates.lean`](../../../Kelana/StableRecordCoordinates.lean) proves lookup-preserving renaming (including merging), necessity of equal values for live merges, dead-slot write invariance, fresh/shared insertion, last-reference reclamation, typed fresh/shared aging and deterministic-query congruence. A concrete duplicate-reference witness proves that premature reclamation changes the remaining output. These identities supply local premises of the [phased cache simulation](RESIDENCY.md); they are not a proof of an actual byte allocator or GPU implementation.

## Source locality of the sharing opportunity

The source is specifically the original **layer-0** attention. The [producer identity](../quip-token-producer/README.md) already established that its input on the token-ID path is embedding→RMSNorm, before any history-dependent attention. The [captured-source rank study](../rotary-score-factor/README.md) found1,247 distinct token IDs and exactly1,247 distinct input vectors in3,072 positions. A deterministic V projection and per-token V quantizer therefore preserve identical input repetitions; RoPE acts on Q/K, not V. This explains a real structural source for value-record sharing without a vocabulary oracle in the encoder. Different inputs may also share quantized records; the accepted implementations compare actual bytes and make no injectivity assumption.

Later-layer V inputs depend on history. Repeated token IDs do not guarantee equal later V records, so the measured per-layer savings cannot be multiplied by the model depth. Likewise, externally supplied embeddings need not follow the finite token map. A universal recent-capacity33 bound and exact accepted decoding remain valid independent of repetition, but the panel's148 aged-slot capacity and its byte savings do not become general source guarantees. The [source-capacity witness](../value-record-source-capacity/README.md) now makes the coverage boundary concrete: existing token/arrival/packed-event bytes supply149 distinct reachable records, causing rejection after the t181 flush. `Kelana/ValueRecordCapacity.lean` proves the exact finite repeatable-source occupancy maximum and phase crossing. At256, reserving the224 worst-case aged records in the same fixed layout would erase its memory advantage and exceed the conventional reservation by532B. This is not a no-go for arbitrary cross-record/source-coded compression or dynamic allocation. No new layer capture or model evaluation was needed.

## What the representation must still pay

A total-function heap is a semantic model, not an infinite free allocation. The implementation owes:

- physical record extents, alignment, a finite allocation policy and capacity rejection;
- handle widths, ordered lists/rings, live-reference ownership and any freelist/bitmap;
- exact equality tests after any lookup acceleration;
- a safe staging extent for quantization and possible coexistence of retiring/new records;
- address dereferences and gathers in the complete query, not just storage savings;
- reserved capacity and fragmentation, not merely the occupied record bytes;
- byte traffic, code and execution resources for the actual update and reader.

Using an unreferenced name does not prove that a sufficiently large contiguous free extent exists. A panel-fitting partial allocator is useful evidence but not a worst-case capacity guarantee. Handles into different typed pools cannot overlap in physical memory merely because their abstract names differ. An exact-key hash table can speed lookup, but its buckets, collision chains, rebuilds and full equality checks are real state/work.

The [stable-slot CPU study](../kivi-stable-records/README.md) now implements this change: fixed148 quantized and33 recent value slots, paid u8 references/counts, in-place per-head key slabs. All6144 phases match every original logical record. Its286648B fixed arrays are1974B larger than the previous in-place CPU arrays, while key/record write traffic is12.636MB with no whole-cache suffix shift, versus3.362GB of moves in the canonical maintainer. Those are distinct counters, not an elapsed-time ratio; equality scans and scratch writes remain additional work. The148-slot quant bound uses the previously published panel occupancy and is not universal. The [complete cooperative native program](../kivi-stable-resident/README.md) now supplies that comparison: exact4096 device phases and byte-identical eight arm outputs,28728B fewer explicit global buffers, but median matched flush-step event ratio1.612. Its conventional arm uses the same cooperative K/V quantization instead of the prior serial placement. Locality removes whole-image shifts but does not make equality scans, indirections, extra launches or other maintenance free. No quantizer refit, source change, token vocabulary oracle or repeated flat GPU probe is involved.
