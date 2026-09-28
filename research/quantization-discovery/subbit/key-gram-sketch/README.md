# The paid key norm has no exact low-rank PSD shortcut

The [row-sampling result](../key-norm-sketch/README.md) left a specific question: could a factor-coordinate quadratic recover the omitted key RMS energy with fewer products than making omitted raw rows? I tried the frozen `.6245`-BPW binary K image at layers 0 and 14. A low-rank quadratic is remarkably good at layer 0. It does not transfer to layer 14, and an exact construction in this grammar cannot save dense projection terms at all.

## Exact rank and online bill

For a group, write its paid real-arithmetic raw key as `a = diag(post) U z`, with `z = V diag(pre) x` and rank 256. The score consumer already makes rows `S`, so the missing norm energy is `||a_M||²/128 = zᵀ G_M z`, with `G_M = U_Mᵀ diag(post_M²) U_M/128`. The pinned signed `V` has rank 256 modulo 65521 and all input pre-scales are nonzero, so its map from unrestricted real activations `x` reaches every real `z`. On that domain, an exact sum of `r` squared linear forms requires `r >= rank(G_M) = rank(U_M)` when every post scale is nonzero. Equality of quadratic values on all `z` forces matrix equality by polarization; the sum of `r` outer products has rank at most `r`. The omitted rows themselves attain that rank. This is a lower bound for this **sum-of-squares dense-linear-form grammar** on unrestricted real activations, not for a structured instruction, approximate norm, a restricted activation distribution, or the BF16-rounded denominator.

The script checks the actual signed `U` matrices' full row rank modulo 65521, which certifies full row rank over the reals. Every group has rank 128, and each omitted submatrix has exactly its row count in rank, 96–114 depending on the fixed score-plane mask. All sixteen group post-scale vectors are nonzero. Across eight groups, exact omitted energy needs at least **800** linear forms and hence **204,800 scalar products** at dense rank 256, precisely the **204,800 signed terms** in producing the 800 omitted raw rows. The existing 224 selected rows cost 57,344 terms; the full output factor costs 262,144, and the common input factor costs 262,144. Dense arbitrary sketch forms cost floating products rather than signed additions, and an FP16 table of 800 by 256 coefficients adds 409,600 bytes per layer, against 25,600 binary-code bytes for those U rows. This count does not establish equal native time; it says the exact dense PSD family has no arithmetic-count opening here. BF16 rounding before the norm also prevents an exact real Gram from reproducing the evaluator's map.

## Approximate held causal scores

I then tried two real factor-coordinate sketches. The fixed spectral arm keeps `alpha ||z||²` and the largest absolute eigenvalue deviations from `alpha I` in the complete Gram. The second arm uses the *already computed selected BF16 raw energy*, projects `z` along leading eigenvectors of the omitted Gram, and fits nonnegative squared-projection coefficients plus a nonnegative `||z||²` coefficient to train missing energy. A fixed `.01` standardized ridge term controls that NNLS fit. Its predicted missing energy cannot be negative. An unconstrained ridge fit of selected energy, `||z||²` and spectral features was also run; it produces near-zero/negative denominators on layer 14 and catastrophic KL, so it is retained in the receipt but not proposed as an inference map.

The same four previously inspected validation windows and eight original-producer training windows as the preceding studies are used. The raw paid-K selected numerators and group BF16 affine are unchanged; original Q supplies candidate scores and original Q/K supply the teacher. Each group scores both heads against every causal key. This is BF16-expanded CPU quality, not a native factor kernel or model loss. The spectral and NNLS denominators use FP32 factor coordinates and FP32 coefficients; FP16 table rounding remains unpaid in quality. A factor-full denominator matches the expanded full arm's mean KL to within 0.000001 here, and its mean relative squared-energy error is below 0.00001. The same-run full arm differs slightly from the preceding script's full control because of CPU floating execution order, so compare arms within this receipt.

| Denominator | Added forms/group | Added dense products/layer | FP16 form bytes/layer | Layer 0 held KL | Layer 14 held KL |
| --- | ---: | ---: | ---: | ---: | ---: |
| Expanded full K | 800 raw rows | 204,800 signed missing-row terms | 0 | .263366 | .478457 |
| Fixed spectral deviations | 8 | 16,384 plus shared 256-square norm | 32,768 | .269932 | .899136 |
| Train NNLS on omitted energy | 8 | 16,384 plus shared 256-square norm | 32,768 | .262943 | .637352 |
| Train NNLS on omitted energy | 16 | 32,768 plus shared 256-square norm | 65,536 | .263273 | .609934 |
| Train NNLS on omitted energy | 32 | 65,536 plus shared 256-square norm | 131,072 | .262834 | .631848 |
| Train NNLS on omitted energy | 64 | 131,072 plus shared 256-square norm | 262,144 | .261946 | .649690 |

Every layer-0 held window with the eight-form NNLS map is within .001 of full; its mean is slightly better. It is an actual low-rank, consumer-compatible candidate at this local quality point, though it uses 32,768 extra FP16 table bytes per layer and dense multiplies. At layer 14 its four-window means are all worse. The earlier 32-extra-row stratified map scores .480677 on layer 14 at 65,536 extra *signed* terms and roughly 320 index/weight bytes, whereas the 32-form dense NNLS map scores .631848 at 65,536 extra *floating* products and 131,072 form bytes. Even its best tested 16-form arm scores .609934, versus .559160 for 16 stratified extra rows at the same term count. The row study uses independently drawn maps, not this deterministic train fit; it is still a decisive warning against native lowering the current spectral image.

The useful change in the next question is specific: do not truncate the frozen full Gram by eigenvalue magnitude or fit its missing energy by squared-error regression and expect layer-14 causal quality. The eight-form layer-0 result suggests that a low-rank norm coordinate can work, but layer 14 needs a **jointly trained selected score and normalization observer** on quantized producer states. Select by causal/post-O or gold loss, constrain positive energy, and compare an equal-paid-rate raw-row or binary-factor control on disjoint text before pricing a native form table. A learned sketch should share coordinates with the score producer if its 32–131 kB of extra vectors are to be justified.

The source is [`measure.py`](measure.py). Per-group/modular-rank, per-window loss and energy-error records with source/model/capture/image/prior hashes are under `/path/to/workspace/data/kelana-subbit/key-gram-sketch/layer{00,14}.json`. One CPU layer runs in a bounded command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/key-gram-sketch
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 0 --output /path/to/workspace/data/kelana-subbit/key-gram-sketch/layer00.json
```

No GPU lock, Bonsai executable or resident service changed.
