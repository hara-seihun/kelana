# Low-rank output metrics do not make one-nibble phase selection cheap

The [sixteen-phase value-mass grid](../value-phase-grid/README.md) spends roughly 27,000 scalar products and boundary operations per 256-key query/head before a single signed-nibble value dot. Can a narrow projection of the paid output metric choose nearly the same phase more cheaply? On the frozen Qwen3-0.6B value image, the answer is no at the rank that saves work. This also explains why retaining 92% of an output matrix's spectral energy is a poor phase-selection criterion.

## Construction and measurement

For code row `c_i` in 28 coordinates and paid output matrix `L`, let `G = D L^T L D`, with the frozen nibble steps in `D`. The existing sixteen-phase grid chooses the count vector `q(u)` that minimizes `||(q(u)/15 - p)c||_G²`. Replace `G` during *selection only* by `T_r T_r^T`. The actual error is always scored against the full paid `G` and the 4,095-count reference. Every arm keeps the same stored value codes, 15 mass units, candidate phases and direct one-nibble consumer.

Two static transforms were built without held responses. The spectral arm takes the leading `r` eigenvectors of `G`, multiplied by square-root eigenvalues. The response-error arm takes the leading `r` right singular vectors of all sixteen candidate errors on eight train windows after applying `G`'s square root. It is a train-only PCA of *errors*, not an oracle with held targets. Neither transform requires changing cache codes, but the consumer would have to form `c_i T_r` online or store an extra projected cache. The CPU replay forms it online.

Four previously inspected validation windows contribute four positions each. One Qwen3-0.6B original-producer head is measured per layer, head 7 at layer 0 and head 12 at layer 14. The following are relative squared post-O head response errors against the 4,095-count map. They are not complete-layer or model loss.

| Layer / split | Phase 0 | Full 16-phase `G` | Spectral rank 1 | Error-fit rank 1 | Spectral rank 4 | Error-fit rank 4 | Spectral rank 8 | Error-fit rank 8 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 train | .00060829 | .00024321 | .00024321 | .00060829 | .00024321 | .00024509 | .00024321 | .00024321 |
| 0 inspected held | .00006709 | .00006709 | .00019592 | .00006709 | .00007197 | .00006709 | .00006709 | .00006709 |
| 14 train | .00136620 | .00090861 | .00134467 | .00124783 | .00109315 | .00111259 | .00099740 | .00100480 |
| 14 inspected held | .00046388 | .00029828 | .00055583 | .00054255 | .00038834 | .00037066 | .00033477 | .00033823 |

At layer 14, the leading eigenvector accounts for 92.39% of `tr(G)`, yet both rank-one selectors are worse than phase zero on inspected held rows. The residual directions, not total output energy, decide the best phase. Response-error training helps rank four on that split, but its .00037066 recovers only 56.3% of the full grid's .00016560 improvement over phase zero. Rank eight recovers 75.9% to 78.0%, at far more preparation than the full grid. Layer 0 is harsher: the full sixteen-phase grid does not beat prefix on held rows, and the response-error rank-one selector loses its entire train improvement even though it matches prefix on held rows. There is no selected one-digit head at the prior 1e-4 full post-O switch budget.

## Online cost and a stop rule

At `n=256` keys and rank `r`, forming `c_i T_r` needs `28nr` scalar multiply-adds if the original nibble cache remains the only per-key payload. The projected floating target needs `nr` more products. Scoring sixteen candidates needs at most `16*15*r` nonzero count/coordinate products after constructing `16*(n-1)` prefix boundary comparisons. Thus rank one starts at 7,168 projection products plus 256 target products, 240 sparse products and 4,080 boundary comparisons, before normalization and phase selection. Rank four starts at 28,672 projection products; rank eight at 57,344. These are operation counts, not comparable native issue times. Caching projected values instead charges at least one more scalar/key/head for rank one, and therefore changes the cache-rate comparison.

The measured rank-one response fails where it would be cheap, and the ranks that recover substantial held benefit spend more than the full-grid selector's approximately 27,000 counted operations. This closes *fixed low-rank quadratic phase scoring on these frozen codes* as a native one-dot shortcut. It does not rule out jointly learned value codes and a compact phase policy on quantized-producer model loss. That is the next question: learn a phase decision from cheap score-side statistics or a small code-aware state, rather than projecting every key through an output metric each query. A candidate must beat both the paid full-grid selector and the ordinary 255/4,095-unit direct consumer on matched model quality and all online preparation.

The exact candidate enumeration is the sixteen-point grammar, not the continuous event optimum. The linear-algebra identity is over real response vectors; it claims no FP32 bit identity. No GPU, native timing, weight rate, full-model loss, executable or service changed.

`measure.py` replays both layers. The rowwise phase indices, train-only spectrum, actual full-metric errors, source/model/capture/factor/cache/parent hashes and split aggregates are in `/path/to/workspace/data/kelana-subbit/value-phase-lowrank/layer{00,14}.json`.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-phase-lowrank/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-phase-lowrank/measure.py --layer 14
```
