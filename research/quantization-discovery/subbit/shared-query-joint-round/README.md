# Joint rounding of the shared three-dot query

The [shared-base score](../shared-query-base/README.md) independently rounds its base head to signed eight bits and the other head's difference to signed four bits. The second score contains both rounding errors. I tested whether choosing those two integers *together* recovers enough causal attention quality to justify more query preparation, while keeping exactly the same three signed-nibble key dots and 128-byte key cache.

On frozen paid Q/K, the exact coordinatewise weighted-lattice choice improves four previously inspected original-producer Qwen3-0.6B validation windows at both layers. The improvement over independent rounding is small.

| Layer | Independent shared three dots | Joint rounded three dots | Four dots | Joint improvement |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .278608 | .278049 | .275431 | .000559 |
| 14 | .334929 | .333448 | .332396 | .001481 |

These are teacher-to-candidate causal attention KL averaged over two heads, eight GQA groups and four 256-token windows. The train selection uses eight distinct windows. The joint arm improves all four inspected held windows against independent shared rounding in each layer. Its layer-14 gap to four dots falls from .002533 to .001052, but the layer-0 gap remains .002618. Train means are .257970 to .257119 at layer 0 and .299321 to .298489 at layer 14.

## Conditional optimum and its price

For each prepared query coordinate, write the real base and other-head values as `a0,a1`. Fix the existing dynamic scales `d=max|a0|/119` and `e=max|a1-a0|/7`. A base integer `u∈[-119,119]` and difference nibble `v∈[-7,7]` represent the pair `(du,du+ev)`. At a fixed positive head weight `lambda`, minimize

```
(a0 - d*u)^2 + lambda*(a1 - d*u - e*v)^2.
```

For any fixed `v`, completing the square gives the unique continuous minimizer `u*=(a0+lambda*(a1-e*v))/((1+lambda)*d)`. Rounding `u*` to the nearest integer and clipping to `[-119,119]` is an exact integer minimizer for that `v`; checking all fifteen possible `v` proves the returned pair globally optimal for this coordinatewise squared-error objective at the fixed scales. Ties can choose either minimizer. Coordinates separate, so this also solves the sum over the entire query. The proof is for a diagonal query-error surrogate, not for causal KL, key covariance, or a globally optimal choice of dynamic scales. Train windows select `lambda` from `{.25,1,4}` and which head is the base per group.

The base integer splits exactly into `lo+16*hi`, where both digits fit `[-8,7]`. The selected difference already fits one signed nibble. Dot the two base digits and one difference digit against each stored 32-coordinate signed-nibble key. Reusing the base score and adding the difference score gives both heads' real-valued scores. The script checks the digit identity for every measured query; FP32 dot order and softmax are not promised bit identity with the four-dot map.

Relative to independent shared rounding, this leaves **768 logical signed-nibble products/key/layer**, the same 128 key-cache bytes/token/layer, 512 key-step query multiplies, two dynamic maxima per group, score additions and full raw K normalization. It adds a fifteen-choice fit on each of `8*32=256` base coordinates per query, **3,840 candidate evaluations/token/layer**, each with a projection, rounding, clipping, two residual squares, comparison and selection. No native kernel, whole-model loss or hardware time was measured. The result is a conditional representational bound: that much online selection buys only .000559/.001481 KL on these captures, even before selection instructions and register lifetime are charged.

I also restricted `v` to its ordinary independently rounded value or the three neighboring values and jointly optimized `u`. Training chose among those two restricted radii and base heads. Held KL was .279552/.333478 on layers 0/14. Three candidates recover nearly all the layer-14 full-search gain but *lose* to independent rounding at layer 0. Coordinate SSE and causal KL do not rank query rounding rules consistently. There is no measured native reason to add this fit to the selected consumer. Change the paid Q/K producer, key labels or query coordinate and fit against composed causal or model loss; do not spend a fifteen-way per-query search to rescue this frozen coordinate.

## Reproduce

`measure.py` replays the same paid binary factors, frozen key codes, original weights and 8-train/4-validation captures as the parent study. Each layer receipt under `/path/to/workspace/data/kelana-subbit/shared-query-joint-round/` contains every group and window score, train-selected policies, conditional coordinate errors and SHA-256 hashes of source, parent receipts, model, captures and factor images. With the installed CPU PyTorch environment:

```sh
cd /path/to/workspace/projects/kelana
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
    research/quantization-discovery/subbit/shared-query-joint-round/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/shared-query-joint-round/layer$(printf '%02d' "$layer").json"
done
```

This is CPU quality replay on original-producer hidden states and a proof within fixed dynamic scales and a diagonal error surrogate. It is not a weight-BPW improvement, quantized-upstream result, native timing or quality-matched int4 comparison.
