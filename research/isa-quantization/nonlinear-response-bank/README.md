# A complete captured MLP, not an anchor-grid table

**Outcome:** A compact bank of selected real nonlinear channels has enough *in-sample capacity* to be interesting at the full-MLP Q4 byte budget, but this constructed bank **does not transfer** to actual held producer states. At 4.82 MB its best train-selected fitted response has .604 held relative RMS versus .163 for an exported 4.87 MB scalar Q4 control. There is no surviving bank image to export or GPU program to time. This rejects the tested selection-and-readout procedure, not all joint nonlinear programs: a separately optimized free readout on the held states gets .135, proving that representational capacity alone does not account for the failure.

## Boundary, source and held split

Qwen3-0.6B **layer 0** with all 1,024 captured input dimensions, 3,072 original BF16 hidden channels and **all 1,024 down outputs**. The target is the complete local nonlinear map `down(SiLU(gate*x) ⊙ (up*x))` in FP32 BLAS arithmetic with original BF16 matrix coefficients. The inputs are actual BF16 states captured from the selected ternary model's MLP producer, four disjoint 256-token train windows and four different validation windows. They are not synthetic perturbations; no individual source weight or hidden channel is a requirement on a general replacement. Both panels have 1,024 full-width inputs. The separate validation targets were inspected during the capacity screen to decide which ranks merited fitting, so this is **not** an untouched final test panel. Ridge choice within those banks uses only the fourth train window. Source and capture hashes, plus the control's stored-image hashes, are in [`results.json`](results.json).

The strong scalar control decodes existing packed independent **group-128 Q4 gate, up *and down*** images from the full-scalar model. Its 4,866,096-byte model payload includes all three nibble planes, group scales and shape descriptors. Its scales were calibrated with four clipping starts and five alternating code/scale steps, not naive single-pass rounding. Every element of both panels is evaluated through the decoded image; Q4 scores .16455 on train, **.16253** on held against the complete original BF16 MLP. This is a local response score, not whole-model NLL or a native serving timing. An optimized scalar Q4 trained for the full nonlinear endpoint could do better; the control is competent but not an optimum certificate.

## A paid bank and the geometry screen

The initial executable family retains `K` original BF16 gate/up channel pairs, evaluates their actual SiLU×up responses, then applies a fitted **dense FP16 output readout plus FP16 output bias**. Selecting source channels is a means to generate nonlinear features, not an assumption that general executable-map search must preserve channels. A deterministic train-only score orders source channels by `||hidden_j - mean(hidden_j)|| * ||down[:,j]||`. A second selection uses hidden variation alone. Both feature orderings see train states and the model, never validation targets; the subsequent rank/capacity screen does inspect validation targets. The generic reader would compute two length-1,024 projections per selected channel, K nonlinearities and 1,024K readout terms: roughly `3,072K` projection/readout FMAs per input, versus 9,437,184 for three dense original projections, plus the nonlinear evaluations and memory accesses. This is an arithmetic count, **not a measured speedup**. The bank's model bytes pay 4,096K BF16 gate/up coefficient bytes, 2,048K FP16 readout bytes, a 2,048-byte FP16 output bias, 2K bytes of uint16 channel IDs and a 7-byte image header. Generic code and launch machinery remain unmeasured in both arms.

For each *fixed selected-feature bank*, [`screen.py`](screen.py) orthogonally projects each panel's target onto the span of that panel's hidden features plus an intercept. In particular, the held projection **refits its own arbitrary FP64 readout after seeing the held targets**. Its residual is an optimistic held lower bound for this fixed feature family, not a deployable fit; rounding, training-only selection and actual learning can only raise that panel's error. The output SVD in the receipt is likewise a diagnostic of the 1,024 observed train rows, not a global producer rank bound. All values below are relative RMS, not squared error.

| Selected channels | Model payload | Weighted selection: train/held free-readout floors | Variation-only held floor |
| ---: | ---: | ---: | ---: |
| 128 | 788,743 B | .663/.674 | .680 |
| 256 | 1,575,431 B | .523/.534 | .538 |
| 512 | 3,148,807 B | .297/.318 | .322 |
| 640 | 3,935,495 B | .204/.226 | .227 |
| 768 | 4,722,183 B | .129/.144 | .146 |
| 784 | 4,820,519 B | .121/.135 | .136 |
| 788 | 4,845,103 B | .119/.133 | .134 |
| All-three scalar Q4 | **4,866,096 B** | measured .165/.163 | — |

Below K=768, **even the held oracle readout** of either explicitly selected source-feature set loses to Q4; spending fit queries is unnecessary there. The K≥768 floors cross Q4 and fit work is justified, but their margin is narrow. At K=788 only 20,993 bytes remain under Q4 before generic code, framing or other metadata. A separately selected trained output SVD basis illustrates the danger of reading capacity from train alone: rank 768 has .025 train residual yet .282 held residual *even with free held coordinates*, as measured for this train-selected output subspace. That is a property of this finite panel and basis, not a universal minimum bank rank.

## Full-response fitting and negative transfer

For K=768/784/788 weighted-feature banks, [`fit.py`](fit.py) starts the output readout from the corresponding original BF16 down columns. It fits a standardized, ridge-corrected **entire 1,024-output response**, using the first three train windows (768 states) to select a ridge coefficient on the fourth (256 states). It refits on all 1,024 train states, rounds the readout and bias to actual stored FP16, and scores the separate 1,024 validation states already inspected by the rank screen. Ridge strengths `0,.01,.1,1,10,100,1000,10000,100000,1000000` are all recorded, but validation response scores do not choose a ridge hyperparameter. In each case the internal check selects 1,000.

| K | Train fitted RMS | Held fitted RMS | Held same-feature FP64 oracle | Q4 held |
| ---: | ---: | ---: | ---: | ---: |
| 768 | .36562 | .60756 | .14434 | .16253 |
| 784 | .36025 | .60406 | .13517 | .16253 |
| 788 | .35901 | .60304 | .13277 | .16253 |

A zero-ridge solution at K=768 has *39.4* internal-check RMS from poorly constrained hidden correlations, not a meaningful native bank. Ridge regularizes it but cannot close the large train-to-held gap. More fitted target queries, an alternative nonlinear feature map, a different channel selection, a sparse/different readout, output-aware optimization or a shared cross-region feature bank could change the result. This experiment proves no global lower bound on all K nonlinear features, and finite validation does not certify unseen histories. It does answer the requested immediate decision: **do not substitute more table-reader benchmarks or a stored source-channel bank for a missing transferable full-response fit.** None of the train-selected banks beats the scalar Q4 image, so no candidate image was emitted. The JSON fit receipts report `stored_image: null` explicitly.

## Reproduce (CPU only)

Using the existing source/capture and one BLAS thread, from this directory:

```sh
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for split in train held; do
  for chunk in 0 1 2 3; do
    OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" prepare.py --split "$split" --chunk "$chunk"
  done
done
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" screen.py
for rank in 768 784 788; do
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" fit.py --rank "$rank"
done
```

Every command is individually under one minute. `train-*.npz` and `held-*.npz` are generated response caches and ignored by Git; source and exact full-response hashes in the small generated JSON are summarized in the committed receipt. `prepare.py`'s Q4 decoder reads physically stored image codes/scales; its decoded matrices and all producer inputs are used numerically, not expanded storage secretly available to the hypothetical bank. The bank's learned FP16 readout is only evaluated as a hypothetical image because the fitted candidate fails. No GPU timing, GPU upload, exact-real SiLU theorem or whole-model quality claim is made.
