# Canonical within-group systematic rounding: exact complete-O expectation

This is one fixed ideal dependent law, specified in [LAW.md](LAW.md), on the original KIVI2 G32 V-flush bytes and source panels. The parent's [finite floor/count and covariance foundation](../value-rounding-risk/COUPLING.md) and `Kelana/ValueGroupRounding.lean` distinguish pointwise count balance from complete output risk. It does not optimize ordering, phase, group boundaries, bits or encoder state. The same coordinate's stochastic digit is shared by both Q heads; separate groups/events draw independently. Per-coordinate clipped means and all unchanged deterministic controls are read from source commit `0bed18b2`, not rescored. `evaluate.py` reconstructs only the original FP32 K2 attention probabilities and each aged V coordinate's actual adjacent level/probability/width for its new covariance.

| Panel | Queries | Original deterministic FP64 SSE | Reused mean-bias SSE | Systematic variance | Expected SSE | Expected/original | Independent expected SSE | Winning queries |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Layer1 train (8 windows) | 2048 | 209.016696 | 156.152406 | 93.389387 | **249.541793** | **1.193884** | 249.765157 | 58 |
| Layer1 inspected validation (4 windows) | 1024 | 107.923582 | 76.951085 | 50.731970 | **127.683055** | **1.183088** | 127.760254 | 45 |
| Layer0 held (4 arrivals × t128/t256) | 8 | 0.832658 | 0.179568 | 0.336459 | **0.516027** | **0.619735** | 0.516749 | 7 |

**Negative contextual result:** dependence gives a small variance improvement versus independent rounding, but the expected contextual risks still lose by 19.39% and 18.31% against deterministic V2. The distinct held layer0 panel improves in expectation. This is neither an impossibility claim for other couplings nor an implemented randomized runtime. The independent owner documents the unchanged CPU controls, FP64/CPU rounding boundary and source provenance.

Each `*-result.json` includes all per-query fixed-law expectations, source/manifest/prior-receipt hashes and original fields/event validation checks. For every record/group, circular-overlap covariance diagonal agrees with Bernoulli marginal variance to at most `1.67e-16`, is symmetric, and has the constructive interval-support PSD witness. On 48 bounded records across all panels, separately enumerated support yields marginals within `2.34e-15` and complete projected variance contractions within `3.61e-16` of overlap/Gram contraction. There are 114,688 inspected original G32 groups across 28,672 V records in total; no sampled draws, GPU, source projection, or teacher forward. `summary.json` carries panel/window totals, checks and the cost ledger.

The ideal encoder replaces 128 independent uniforms per original KV V record with four uniforms (one per original G32 group), computes 128 upper probabilities and 128 cumulative updates plus digit decisions, and leaves bit codes, four FP16 min/step pairs, K and recent storage, O, and V-flush timing unchanged. Uniform generation, arithmetic and rounding work are additional encoder costs, not a measured speedup or paid device result. Four groups per original 224 V events × eight KV heads give 7,168 uniforms per window, 114,688 over all 16 windows, with no specified additional cache fields in the ideal law. A concrete PRNG/seed state, threshold arithmetic and rounding are not implemented or priced as zero by this screen.

Reproduce bounded windows with the source owner's Python environment, then aggregate:

```sh
cd research/isa-quantization/kivi-group-rounding-risk
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python evaluate.py train 0
# likewise train 1..7, validation 0..3, held 0..3 (each window under 60 s)
/path/to/workspace/data/fish-s2-pro/venv/bin/python aggregate.py
```
