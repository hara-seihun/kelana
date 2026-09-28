# Four frozen full-Q-head images through causal attention, V and O

**The observation boundary changes the held ranking.** At near-equal standalone Q-head bytes, the H-fitted table-free QuIP# root image has *lower held raw-Q response error* than the H-fitted mixed group128 Q2/Q3 scalar image, yet **higher attention KL and post-O error** on the complete actual head-0 causal observer. Both frozen source-completed-M images have also been replayed without any consumer refit or held selection. M improves root's held raw-Q and attention KL somewhat; it does not overturn the held downstream loss against the H-fitted scalar. The changed metric and the consumer are distinct questions.

## Exact source and paid state

The fixed [128×1,024 Q-head fixture](../quip-full-row-slab/README.md) SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f` has 2,048 training and 1,024 held producer states. They form **eight and four 256-token source windows**, respectively; all twelve are replayed, not just the earlier attention-consumer study's first two per panel. `measure.py` checks the fixture's original 128×1,024 Q head is **elementwise identical** to `model.layers.0.self_attn.q_proj.weight[:128,:]` from the pinned Qwen3-0.6B BF16 checkpoint, source revision `c1899de289a04d12100db370d81485cdf75e47ca`, checkpoint SHA256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`. Thus these states, original Q and K/V/O share the actual layer-0 source coordinates. If that identity fails, replay stops rather than silently treating a different projection as the capture. The 256-token causal positions are those established by [`attention-consumer/measure.py`](../attention-consumer/measure.py). This is a source-window teacher-forced panel, not a continuing generation or full-model NLL test.

The four *frozen* Q-head images, each a complete 128×1,024 replacement with **no Q coefficients from the source checkpoint left in that head**, are:

| Image | Complete standalone Q-head bytes | SHA256 | Fit provenance |
| --- | ---: | --- | --- |
| `root_H` | 50,322 | `d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a` | original H fit, [root-coded reader](../e8-root-program/README.md) |
| `scalar_H` | 50,320 | `e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15` | original train-selected [Q2/Q3 control](../quip-root-matched-scalar/README.md) |
| `root_M` | 50,322 | `1375c3809f12a7484fba1a49d5573b529c6f0946e73408a2f0232a8dd61ae2b0` | [source-completed metric](../quip-completed-metric/README.md), fit fixed before held replay |
| `scalar_M` | 50,320 | `bbf25784aba49c5687c3af203471dc4f91d6beb14dc4eaddb4f7e3377bb323f5` | same M, same fixed scalar format/budget |

The old 54,418-byte FP16-RVQ-table QuIP image is exactly decoded to `root_H`'s full Q weight, so it yields the same ideal consumer and is not a fifth independent quality arm. This study does not retune Q, transform K, or adjust the observation loss. Both root images pay the once-billed **1,024-byte generic absolute table** within their 50,322 B and no residual table; both scalar images pay 4,096 B model-specific FP16 group fields and 128 B mode masks within 50,320 B. No offline covariance, captured history or decoded FP32 Q matrix is included as a compressed inference reader. Matrices are decoded **only in this CPU acceptance replay** to match the original attention-consumer numerical contract; its projection timing is not measured.

The shared source fields actually read by this two-head GQA observer are unchanged and equally paid in all four arms: original K head0 `128×1024×2 = 262,144 B`, V head0 another `262,144 B`, original peer Q head1 `262,144 B`, original O columns for these two heads `1024×256×2 = 524,288 B`, original BF16 Q/K norm gamma `256+256 B`. That is **1,311,232 B common affected-group state**, plus 50,322 or 50,320 B changed Q head, for **1,361,554 / 1,361,552 B** respectively before common programs, RoPE constants, KV cache or other unchanged heads/layers. These common bytes are not a proposed additional deployment allocation; they are the existing source checkpoint fields. K is unchanged, so the peer Q head sharing that K head produces *identical* logits and V/O contribution in all arms; its unchanged contribution is explicitly included in the combined two-head O denominator, not discarded. Other Q/K groups are untouched and do not consume changed K/V/O or Q state.

## Numerical consumer and complete observed losses

For every window, input capture FP32 states multiply the independently decoded FP32 image, then **Q, original K and original V projections are rounded to BF16** and converted back to FP32. The unchanged per-head Q/K RMSNorm uses BF16-rounded projections, FP32 square-mean/`rsqrt` with `epsilon=1e-6`, BF16-rounded normalized vectors and BF16 gamma. Position-dependent RoPE uses BF16-rounded sine and cosine on pairs `(i,i+64)`; score matrix, causal mask, FP32 softmax, V mixing and original O projection follow the prior [`attention-consumer/measure.py`](../attention-consumer/measure.py) implementation. All arms use the same rounding and shared K/V/O. This is a CPU FP32/Torch approximation of Qwen BF16/SDPA behavior, **not byte-identical emitted native GPU rounding**. There is no full-model speed or quality claim.

Mean teacher-to-candidate causal attention KL is averaged over all query positions (2,048 train / 1,024 held); head-0 post-O relative squared error sums its squared output differences across all windows before dividing by its teacher head-0 O contribution norm. The GQA-pair O error similarly divides by the *sum of original head-0 and peer-head-1* contributions. `raw-Q` is after BF16 projection rounding; `normalized-Q` after BF16 RMSNorm+gamma and before RoPE. The centered-score diagnostic subtracts the per-query **uniform visible-key** mean, not the teacher-probability mean. All numbers come from the complete emitted `256×256` causal score and V/O paths, not raw Q alone.

| Panel | Image | Raw-Q rel sq | Normalized-Q rel sq | Head-0 attention KL | Head-0 post-O rel sq | GQA-pair post-O rel sq |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| train | `root_H` | .00384632 | .00650720 | **.00577451** | **.00603990** | **.00053854** |
| train | `scalar_H` | .01234937 | .01510696 | .01320982 | .01510679 | .00134698 |
| train | `root_M` | .00504594 | .00856307 | .00734618 | .00738219 | .00065823 |
| train | `scalar_M` | .01303836 | .01640287 | .01394225 | .01567009 | .00139721 |
| held | `root_H` | **.01310947** | .02141683 | .02416825 | .02784225 | .00285930 |
| held | `scalar_H` | .01462970 | **.01812619** | **.01821224** | **.02185195** | **.00224412** |
| held | `root_M` | **.01261853** | .02097905 | .02312622 | .02603103 | .00267330 |
| held | `scalar_M` | .01468692 | .01908079 | .01923350 | .02319559 | .00238211 |

The raw-Q advantage of both root images **reverses already at normalized-Q** on held states. RMSNorm suppresses radial error and changes how pairwise angular errors matter; K geometry, causal probabilities and value/O mapping further determine the exact downstream loss. This table does **not** isolate one of those stages as the sole cause. `root_M` improves over `root_H` on held attention KL (.02312622 versus .02416825), but `scalar_H` still wins held KL and both O metrics. Train ranks root ahead, so choosing only train's observed consumer would also give the wrong held ranking. Individual windows and absolute squared-error numerators/denominators are retained in `train-N.json`, `held-N.json` and [`results.json`](results.json). On held windows the root-H KL exceeds scalar-H KL in all four; head-0 post-O reverses on one window but the summed error still favors scalar-H.

[`observation-loss/README.md`](../observation-loss/README.md) supplies the exact finite-edit KL variance bounds. Here, on every observed causal query, the complete score error's teacher-probability variance `v` and visible-key oscillation `r` give `v(r−1+exp(−r))/r² ≤ KL ≤ min(v(exp(r)−1−r)/r², r²/8)`. The held mean teacher-score variance for `root_H`, `scalar_H`, `root_M`, `scalar_M` is **.04885048, .03631441, .04703565, .03884637**, respectively; their held mean score oscillations are **1.1334, 1.2431, 1.1832, 1.3063**. The larger root teacher-weighted variance is consistent with its larger exact KL despite a sometimes smaller oscillation. The measured lower/upper mean intervals (`root_H` .013418/.062073; `scalar_H` .010983/.039054; `root_M` .013293/.057565; `scalar_M` .011881/.039253) **overlap**, so the bounds do not certify a cross-arm ranking. The direct softmax KL does establish the observed ranking. These are diagnostics of frozen images, not a new fitting objective or selection loop.

## Reproduction

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for i in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/quip-complete-head-observer/measure.py train "$i"; done
for i in 0 1 2 3; do $PY research/isa-quantization/quip-complete-head-observer/measure.py held "$i"; done
$PY research/isa-quantization/quip-complete-head-observer/aggregate.py
```

Each measurement invocation completes within a minute on the existing CPU. No GPU is used. `measure.py` imports the canonical image readers and consumer math rather than duplicating their projection/norm/RoPE rules; its independent scalar byte parser cross-checks the canonical H scalar decoder. It loads all four pinned images and never fits or selects on held inputs. `aggregate.py` requires every panel window, checks capture source-row coverage and image hashes, averages KL over queries and combines O/score/Q squared errors by summing absolute numerators and denominators. The offline model/fixture source paths and hashes remain with their owners. Nothing here establishes native inference adoption or whole-model NLL.
