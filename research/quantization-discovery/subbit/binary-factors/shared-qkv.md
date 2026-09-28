# Joint Q/K/V first factors

The [matrix comparator](README.md) found that a similar weight error can produce very different activation errors. This experiment asks a more pointed question. The Q, K and V projections consume the same normalized vector. Can one packed first binary factor replace three separate first factors without sacrificing the output responses or merely moving the work to the second stage?

`shared.py` stacks the three real Qwen3-0.6B weight matrices and runs the [pinned upstream NanoQuant ADMM initializer](nanoquant_admm.py) once, so its first factor, FP16 input scale and intermediate are genuinely common. The second factor has separate Q/K/V row ranges and separate output scales. Independent controls run the same solver on each original matrix. One additional construction uses a smaller common first factor plus a rank-32 independent signed residual for each output, with separate FP16 input/output scales for each residual. All factors are packed row-wise into one-bit images and decoded from those images with FP16-rounded scales for measurement. No ADMM latent magnitudes remain in the response calculation.

Inputs are the exact 2,048 train and 1,024 validation projection inputs in the pinned fixture's layer-0 and layer-27 Q files. K and V have that identical normalized input. They use the pinned original K/V weights. Train squared channel norms with 0.4 shrinkage and uniform output norms feed ADMM. Each fit uses seed 0, 400 outer and 5 inner iterations on 8 CPU threads. There is **no gradient-norm calibration, factor tuning, block reconstruction, model KD or model-quality measurement**. The complete NanoQuant result is not being claimed.

## Matched storage and response

Each layer has `K=1024`, Q output `2048`, K and V outputs `1024` each, hence `4,194,304` original weight elements. Rates count the packed factor planes **and every FP16 input/output scale**, over all three matrices. Independent ranks are Q/K/V `352/256/256` at the .53516-BPW point and `320/192/192` at .44922 BPW. The common factor ranks are 416 and 352. The low point has exactly matched payload bytes, not just rounded target BPW. The high shared and hybrid points use slightly fewer bytes than the independent control.

| Construction | Packed factor bytes | Scale bytes | Total bytes | Matrix BPW | Signed accumulations / vector |
| --- | ---: | ---: | ---: | ---: | ---: |
| Independent 352/256/256 | 266,240 | 14,336 | 280,576 | .53516 | 2,129,920 |
| Shared 416 | 266,240 | 10,240 | 276,480 | .52734 | 2,129,920 |
| Shared 352 plus private 32/32/32 | 253,952 | 24,576 | 278,528 | .53125 | 2,031,616 |
| Independent 320/192/192 | 221,184 | 14,336 | 235,520 | .44922 | 1,769,472 |
| Shared 352 | 225,280 | 10,240 | 235,520 | .44922 | 1,802,240 |

The serialized `.npz` files have a further 1,256 bytes of ZIP/shape headers per file: three files for independent, one for plain shared, four for the shared/private construction. Those headers are not in matrix BPW. Images and JSON are under `/path/to/workspace/data/kelana-subbit/binary-factors/shared/`.

The numbers below are validation response **relative squared errors** for each projection. Lower is better. These are not perplexities.

| Layer | Construction | Q | K | V |
| ---: | --- | ---: | ---: | ---: |
| 0 | Independent .53516 | .09666 | .07289 | .55777 |
| 0 | Shared .52734 | .09921 | .07157 | .55924 |
| 0 | Shared + private .53125 | .10319 | .07234 | .56491 |
| 0 | Independent .44922 | .10320 | .08366 | .62521 |
| 0 | Shared .44922 | .10905 | .07799 | .60091 |
| 27 | Independent .53516 | .11579 | .09259 | .57009 |
| 27 | Shared .52734 | .11840 | .09769 | .55506 |
| 27 | Shared + private .53125 | .12257 | .09888 | .56622 |
| 27 | Independent .44922 | .12376 | .10989 | .64862 |
| 27 | Shared .44922 | .12904 | .10706 | .60355 |

At .44922 BPW, sharing cuts V error by .0243 on layer 0 and .0451 on layer 27, and cuts K error on both; Q error rises by .00585 and .00529. That is a real trade, not a win across all consumers. At the higher rate, sharing saves 4,096 bytes by removing two duplicate input-scale arrays but has **exactly the same total signed-accumulation count**. The hybrid saves 2,048 bytes and 98,304 signed accumulations against independent .53516, while worsening Q response on both layers; K and V changes are mixed. A residual fitted to weight error is a poor use of the budget. Extra scales, intermediate vectors and kernel launches also make the hybrid's 4.6% accumulation saving an unattractive inference claim.

There is no mysterious free saving in the common factor. The 416-rank shared first stage uses `416×1024 = 425,984` signed accumulations instead of independent `864×1024 = 884,736`, but its wider shared second stage uses `416×4096 = 1,703,936` rather than `1,245,184`. Their totals are identical. At exactly .44922 BPW, the shared first stage uses `360,448` instead of `720,896`, but the whole projection uses 1,802,240 rather than 1,769,472 signed accumulations, **1.85% more**. Its apparent first-stage saving is spent on the second factors. This count excludes sign extraction, scales, vector transfers and register pressure.

## Boundary and next construction

A gfx1151 consumer could compute `h = V_binary*(x*scale_pre)` once, keep its 352 or 416 BF16 intermediate values in registers or LDS if placement permits, then feed three output ranges without writing a separate `h` for Q, K and V. Otherwise one write/read of `h` costs `4R` bytes per vector. The outputs total 4,096 BF16 values, at least 8,192 bytes, before Qwen3's per-head Q/K RMSNorm and rotary-position transform, K/V cache writes and attention Q·K/V reductions. Those next operations do **not** consume a generic binary-factor rank label. A producer can carry the common `h` label across the three linear maps, but norm, RoPE and KV layout establish a real conversion boundary. The hybrid adds three private rank-32 intermediates and separate pre/post scales; fusing its additions into Q/K/V stage two would be essential even to *test* its work count as a latency hypothesis. There is no gfx1151 kernel or latency receipt in this study.

The next fit worth funding is an **activation/attention-aware common binary factor with private residuals selected by marginal held-out response gain per byte and per signed accumulation**, rather than the present weight-residual ADMM. In particular, train the common signs against the three matrices' response covariances and treat Q's head-normalized/rotary output and K/V cache consumers separately. Then allocate a private rank only where it repairs a measured response direction. Keep the same shared intermediate if those consumers can accept it; otherwise price the conversion explicitly. A wider weight-space ADMM sweep alone will not settle the Q-versus-K/V trade.

## Reproduce

```bash
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/binary-factors/shared.py
O=/path/to/workspace/data/kelana-subbit/binary-factors/shared
for layer in 0 27; do
  $P "$D" --layer "$layer" --out "$O/high"
  $P "$D" --layer "$layer" --shared-rank 352 --private-residual-rank 32 --out "$O/hybrid"
  $P "$D" --layer "$layer" --independent-ranks 320 192 192 --shared-rank 352 --out "$O/matched-low"
done
```

The retained initial high-rate reports are at `$O/layer00_qkv.json` and `$O/layer27_qkv.json`. The hybrid and matched-low reports are at their named subdirectories, with `rank352` in the filename. The low-rank shared-only result is also present inside both those reports. Solver fit time, train response and every packed image are in the JSON and NPZ outputs.
