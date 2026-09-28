# From a shared record to a resident causal program

The completed studies separate three things that a useful cache must eventually do together: retain a smaller state, update it without a second full cache, and answer a query efficiently. The [in-place CPU maintainer](../kivi-value-intern-maintenance/README.md) satisfies the first two on the fixed panel. The [native query](../kivi-grouped-value-native/README.md) satisfies numerical acceptance, but its dictionary readers are slower than the conventional reader. Putting the reports beside one another does not create a device-resident cache updater or eliminate the host/device transfer. The separate [resident program](../kivi-resident-cache/README.md) now implements that composition and accepts every tested device phase, but its flat serial maintenance is slower. This note gives the composition contract without requiring serialized first-use layout to survive into native state; [stable address coordinates](ADDRESSES.md) make that freedom constructive.

## A step has two different cache states

Write a logical post-flush cache as `S`. An arriving input `x` contains the already produced K/V and current Q. A complete step is

```
pre  = insert(S, x)
y    = observe(pre, x)
next = flush(pre)
```

For the fixed KIVI2 interface, the triggering query sees all32 recent K tokens before the K chunk is encoded, and all33 recent V tokens before the oldest V is encoded. Running `observe(next,x)` instead changes the quantized/recent boundary. The same after-flush image and the same list of completed flush events do not by themselves certify the outputs produced in between.

An encoded implementation may have any persistent representation `C`. Let `decode(C)` recover the logical byte records, not necessarily an expanded floating matrix. The sufficient phase obligations are

```
decode(insert'(C,x)) = insert(decode(C),x)
observe'(C,x)        = observe(decode(C),x)
decode(flush'(C))    = flush(decode(C)).
```

Insertion and flush may return a capacity or validity failure instead of a state. On every **accepted** input sequence, these identities imply equality of the final decoded cache and of the entire emitted output sequence. The proof is induction through insertion, observation and flush, not just a check of final cache bytes.

[`Kelana/PhasedCacheSimulation.lean`](../../../Kelana/PhasedCacheSimulation.lean) states the partial encoded transitions using `Option`, proves `accepted_run_sound` for arbitrary state/input/output types and every finite sequence, and includes a two-step phase witness: insertion by addition and flush by integer halving emits `[2,3]`, not the after-flush states. `rejecting_insert` explicitly shows that a perfectly sound partial implementation can reject every nonempty input. Therefore admission/capacity coverage remains separate from conditional correctness. The direct integration Lean command exits0; byte decoders, GPU arithmetic and memory safety are not supplied by this abstract proof.

For a direct dictionary reader, identical byte records and the same arithmetic can discharge the observation identity. Grouped FP32 accumulation changes that arithmetic. Its exact-real identity is proved in the companion [quotient note](README.md); the implemented floating reader instead has a measured output difference. A sound cache decoder does not erase that difference. With externally fixed source arrivals and Q, exact phase-state correspondence prevents cache drift across these queries; if later model states produce different arrivals because of output error, that closed-loop behavior needs its own acceptance.

The native layout is free to use stable record addresses, explicit descriptors, alignment or separate arrays. Canonical first occurrence is one serialization convention, not a necessary part of `decode`. What cannot be removed without a replacement is the update distinction between recent BF16 and aged quantized records, positional key chronology, or the live reference that keeps a record reachable.

## Count actual simultaneously resident allocations

At each event boundary, let `A(t)` be the set of physical allocations still live and `cap(a)` their reserved capacities. The storage bill is

```
peak = max_t sum_(a in A(t)) cap(a),
```

with scratch and code included in their own named domains. The set counts one physical allocation once when two views alias it; it counts two allocations when identical bytes are retained on host and device. This is about actual reservations, not the sum of serialized payload lengths and not a claim that CPU and GPU pools are interchangeable. A smaller `used` prefix of a fixed-capacity arena does not reduce its capacity.

The observed CPU maintainer reserves284674B of explicit arrays. Globals, initialized writable sections, stack and page rounding produce its299008B writable ledger; shared executable/read-only pages add16384B. The native query separately reserves a263429B maximum dictionary image, plus original O/Q/partial-output buffers. A pipeline retaining both cannot claim the device image aliases the CPU arena just because both decode to the same records. A zero-copy or genuinely device-resident path must establish that lifetime/addressing mechanism. Likewise, a scratch buffer can serve maintenance and query in disjoint phases only if the implementation actually reuses the allocation and has no outstanding accesses at the transition.

The conventional control should execute insertion and scheduled quantization too. Feeding it offline quantized events while timing a candidate's real quantizer would compare different work. Conversely, feeding donor events to the candidate would hide its encoding cost. The existing immutable events are excellent **acceptance targets**, while each timed updater must derive its new records from the arriving source and live recent state.

## Preserve the native result without mixing workloads

The completed native query used32 samples per arm, half at128 and half at256. Grouped reading is faster than direct dictionary reading in27/32 adjacent pairs, with paired median event ratio about0.98014. Both dictionary readers lose every adjacent comparison to conventional KIVI2. At256 the shape medians are68.237/88.777/86.916 microseconds for conventional/direct/grouped.

The pooled medians are59.037/73.097/75.817. Their grouped/direct ordering reverses the two shape-specific medians because the pooled statistic straddles two different latency populations and their tails. The ratio of pooled medians is not a paired speedup estimate. The retained [native summary](../kivi-grouped-value-native/timing-results.json) reports shapes, per-state medians and adjacent paired differences as well as the original aggregate statistic. No additional GPU experiment is used for that calculation.

The [completed resident-program study](../kivi-resident-cache/README.md) now resolves update/query lifetime for four held fixed-arrival traces: all4096 device pre/post phases and16 retained complete-output guards pass. Explicit global buffers are4530180B dictionary versus4554948B conventional, with extra dictionary code11620B and query LDS2056B/CTA paid separately. At t128/t256, full input+append/query/flush event medians are92.585/122.673ms dictionary versus18.970/20.908ms conventional. Both are K-flush boundaries and both mutations are single-lane; these numbers are not average token throughput. The exact serialized saving survives, but this fixed flat-placement latency is negative. The [stable-slot CPU successor](../kivi-stable-records/README.md) instead makes payload updates local with paid fixed addresses/counts; a complete native reader/update still has its own acceptance obligation. None of these results turns a query-only timing into a generation benchmark.
