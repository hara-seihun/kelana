# Exact value-record sharing: state compression and an observer quotient

A stored value vector is read many times by causal attention, and equal vectors need not occupy distinct records. This is ordinary lossless dictionary sharing, not a new approximate quantizer. Its relevance here is that layer0 source repetition and repeated **actual packed records** can supply sharing without changing any code, affine field or attention score. The [fixed chronological KIVI2 study](../kivi-value-intern/README.md) is complete: all6144 before/after states have exact ordered-record correspondence, while held mean serialized peak falls304768→258917B. Its literal shadow/rebuild maintainer uses more working memory than baseline. A [separate in-place realization](../kivi-value-intern-maintenance/README.md) now derives every quantized update from encoded recent state, with284674B fixed buffers and299008B conservatively rounded writable ELF/stack budget on this panel. Its3.36GB move traffic and shared executable pages remain paid. This note separates the exact state contract, an optional grouped readout, and that memory/work bill.

## 1. Equality of decoded states is the continued-state contract

Let S be the conventional logical cache, U(S,x) its deterministic append/query-flush update, and Q(S,q) the existing query computation. An encoded state C has a dictionary D and per-position references, plus unchanged keys and chronological metadata. Decoding every reference gives a logical cache `decode(C)`.

The required invariant is not only current-output equality. It is

```
decode(C0) = S0,
decode(U'(C,x)) = U(decode(C),x).
```

Induction over the arriving input sequence then gives equality of every logical state. Consequently `Q(decode(C),q)` equals the original query response at every prefix. A reader may dereference records in the original per-position order and execute the identical arithmetic. If each dereferenced field/decoded value is bitwise identical and reduction order is retained, this representation change does not introduce a new arithmetic approximation. This is distinct from the grouped-sum transformation below.

Recent BF16 and aged quantized values have different update/readout contracts. On a scheduled flush the former record is replaced for that position by the original quantizer's latter record; other positions referring to the former do not change. An expired recent record may be removed only after its final live reference leaves. If canonical ordering compacts a dictionary, all affected indices change consistently. Equal current decoded vectors do not license merging records whose later legal updates would treat them differently without retaining the needed tags.

A lookup hash is an accelerator, not an equality oracle. Exact record equality must settle collisions. A causally constructed dictionary may use only arrived values; a vocabulary built from future tokens is a different source contract.

## 2. Group masses are sufficient for the current value observer

For one head, let `sigma(i)` select the stored value record at position i and `w_g=O_h V_g` its observed vector. For arbitrary rational weights p, not only probabilities,

```
sum_i p_i w_sigma(i) = sum_g P_g w_g,
P_g = sum_(i:sigma(i)=g) p_i.                              (1)
```

Thus any redistribution of attention mass within one equal-value class leaves its complete current O contribution unchanged. Summing heads preserves the identity. It does **not** mean that their key scores, future positions or next model state can be discarded; those remain separate live state.

The exact three-position [example](example.py), with [rational receipt](example.json), has values `(1,1,3)`, baseline probabilities `(1/3,1/3,1/3)` and changed probabilities `(1/12,7/12,1/3)`. Individual probability TV is1/4, but group masses stay `(2/3,1/3)` and output stays exactly5/3. This is an observer identity, not a model-quality improvement.

For positive score ratios r, define

```
U_g = sum_(i:sigma(i)=g) p_i r_i.
```

The perturbed normalized output is exactly `sum_g U_g w_g / sum_g U_g`. For nonempty groups with positive P, the effective group ratio is `R_g=U_g/P_g`. No division by an empty group's mass is needed in the U formula.

If each key ratio independently lies in `[lo_i,hi_i]`, then

```
L_g = sum_group p_i lo_i / P_g,
H_g = sum_group p_i hi_i / P_g
```

give the **exact** reachable interval for R_g. Indeed a common interpolation parameter within that group's input intervals traverses every value from L to H; disjoint groups choose independently. Therefore the [value-aware ratio-box support](../kivi-packed-consumer/RATIO_SUPPORT.md) may coalesce equal observed values before its scalar threshold scan without weakening that box optimization. For a real shared byte-query edit, the independent key intervals are still a relaxation; this result does not remove their correlations.

[`Kelana/ValueRecordQuotient.lean`](../../../Kelana/ValueRecordQuotient.lean) proves finite rational regrouping by actual partition/Fubini sums, equal-mass readout equality, separate per-head masses with the shared dictionary, exact normalized U regrouping and denominator identity, and generic decode/update induction followed by arbitrary deterministic readout. Unused addresses are permitted; the rational identity also holds under totalized division, while probability semantics require the positive denominators stated here. The integration writer's direct Lean check exits0. The exact record decoder, floating source correspondence, physical memory and native arithmetic are external obligations, not consequences of rational algebra.

## 3. Optional arithmetic reduction is not automatic

A direct dictionary reader still visits each position, reading one reference and the selected value fields; it merely stores duplicates once. A grouped reader can instead accumulate per-head probability mass by value-record address, decode each distinct record once and multiply by its group mass. In exact arithmetic (1) removes repeated value-vector products. It pays scatter/reduction of token probabilities, storage for per-head group masses, and possible atomics/communication. Floating additions move, so this is a **separate numerical/native candidate** requiring its own acceptance; the lossless storage study does not silently claim its speed or bitwise result.

For GQA, all query heads sharing a KV group may reuse the same dictionary, but need different group masses because their probabilities differ. A whole-eight-KV-head record is a storage choice; each head consumes only its own 128 coordinates. Full O and cross-head summation remain present.

The count-only [work receipt](work.json), produced by [work.py](work.py) from the four committed held preflush256 manifests, finds143–165 distinct typed records. Exact-real grouped V mixing would reduce524288 weighted value products to292864–337920, removing186368–231424 products. It additionally requires4096 probability-mass contributions, initialization and addressing; FP32 group masses consume9152–10560B across all heads (1144–1320B per KV group). The unchanged O still costs2097152 products, and scores, softmax, field decode, scatter/gather synchronization and rounding acceptance remain. These are counted consequences, not a native speed estimate. The [separate complete query realization](../kivi-grouped-value-query/README.md) now implements a fixed serial per-head mass loop and grouped mixing, with all3072 CPU causal responses. Its max full-O difference from positional decoding is1.19e−6; compiled grouped body is1964B larger and LDS2056B higher. Those receipts discharge a numerical/compile obligation. The [separate native probe](../kivi-grouped-value-native/README.md) now passes24 numerical guards: at256 conventional/direct/grouped event medians are68.237/88.777/86.916µs. Grouping helps its direct dictionary control in27/32 adjacent pairs, not the original conventional reader. They retain the same finite record partition and per-head masses proved here; device maintenance is still a separate obligation.

## 4. A complete literal-state ledger

The fixed experiment uses a maximum256-token horizon, unchanged K2 cache records, and two kinds of full-eight-head V record:

- aged V2: **384 bytes**, including the original affine fields;
- recent BF16 V: **2048 bytes**;
- one **u8 reference per logical V position**;
- **5 bytes** of self-description: u16 time, u8 pre/post-flush phase, u8 aged-dictionary count, u8 recent-dictionary count.

With counts `(nq,nr)` and distinct payload counts `(dq,dr)`, the encoded V/state increment over unchanged K is

```
5 + 384 dq + nq + 2048 dr + nr.
```

The conventional V payload is `384 nq + 2048 nr`. The exact serialized difference is consequently

```
saving = 384(nq-dq) + 2048(nr-dr) - (nq+nr) - 5.           (2)
```

The overhead means a dictionary can lose when there is insufficient repetition. At a before-flush256 boundary, `nq=223,nr=33`; after the query it is224/32. The dictionary counts fit u8 for this fixed horizon. Extending the horizon needs a specified wider code or a different format, not a free unlimited address.

A literal dictionary needs at least one stored representative for each distinct record byte string in its class. This is a pigeonhole fact about an exact fixed-record reader, not an information lower bound over arbitrary programs, shared source recomputation or semantically equivalent affine encodings.

Crucially (2) is **not** the whole resident-peak comparison. A canonical rebuilding encoder can hold current and next images simultaneously, plus incoming values, original quantizer scratch, comparison buffers and temporary addresses. The conventional cache may update in place. Dictionary construction, record compaction and reference rewrites can erase the apparent memory or latency advantage. The operational study reports those allocations separately: current+next images alone reach522376B, with up to153216B of conventional V shadow and further K/source scratch. It calls the result a serialized saving only. The [completed dictionary-native maintainer](../kivi-value-intern-maintenance/README.md) removes both shadows and the second whole image. A266240B arena plus18434B explicit fixed buffers fits all6144 phases and preserves every logical record; adding native globals, initialized writable sections and a bounded stack gives291712B, or299008B under conservative page rounding. This is a fixed capacity for this measured panel, not an arbitrary-source256-token guarantee. The complete executable's read-only pages raise its code-plus-writable ledger to315392B before shared libraries; there is no compiled conventional-maintainer comparator. It also moves3361880540B over these windows. Thus writable state, serialized payload, shared code and execution traffic remain separate axes. The complete grouped-query implementation now earns CPU/native correspondence but loses query speed versus conventional. The [device-resident trace](../kivi-resident-cache/README.md) now closes those physical lifetimes without a host shadow: all4096 phases and16 output guards pass, with24768B fewer explicit global buffers but11620B more body code and much slower serial flush steps. The [resident-step contract](RESIDENCY.md) and `PhasedCacheSimulation.lean` distinguish accepted insert/query/flush correctness from capacity and physical residence. [Stable address coordinates](ADDRESSES.md) and `StableRecordCoordinates.lean` prove that canonical first-use byte positions are not required for local insertion, exact sharing or last-reference reclamation. A physical allocator/reader must still earn its finite capacity and execution costs. Model-specific weights, K cache, O scratch, reference loads and generic reader code are not removed by repeated values.
