# A few real response modes plus a binary residual

The [binary-factor comparator](../binary-factors/README.md) showed that matrix Frobenius error is a weak proxy for the response seen by Qwen3-0.6B. This construction reserves two or four FP16 rank-one directions for large observed responses, then spends the rest of the **same matrix payload budget** on a packed binary factorization. It improves all nine three-rate pilot validation points over NanoQuant's original ADMM-scale images and 14 of 16 supplied matrices at target .55 BPW. The fairer control fits those binary images' output scales to the same train responses without spending a bit or refitting signs. That zero-byte change wins on **all 16** matrices. The real modes beat this stronger control on only **8 of 16** at .55 BPW and **11 of 22** total measured points. These are isolated projections, not model perplexity or a gfx1151 latency claim.

The model is pinned to `Qwen/Qwen3-0.6B` revision `c1899de289a04d12100db370d81485cdf75e47ca`. The [shared fixture manifest](/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/manifest.json) identifies disjoint WikiText-2 raw train and validation windows, original float32 weight matrices and BF16-producer activation inputs. Each fit sees 2,048 training vectors; response error uses 1,024 held-out validation vectors. The untouched fixture test windows play no role. NanoQuant's source [arXiv:2602.06694](https://arxiv.org/abs/2602.06694) and byte-identical, Apache-2.0 licensed [pinned ADMM initializer](../binary-factors/nanoquant_admm.py) supply the binary residual. **The real response modes and post-scale least-squares step are ours, not published NanoQuant.** The full published gradient calibration, block reconstruction, factor tuning and model KD are absent.

## Construction and fit cost

With original matrix `W` of shape `N×K` and training inputs `X`, form `Y = X Wᵀ`. A seeded randomized top-output singular subspace of `Yᵀ`, using oversampling 8 and four power iterations, gives `L` of shape `N×s`. Set `R = Lᵀ W`, round both `L` and `R` to FP16, and subtract their *rounded* product from `W`. This realizes `L R` as the optimal input-response map for the chosen output span before FP16 rounding. It is an approximate singular subspace, not an exact full SVD. Run 400 outer and 5 inner iterations of upstream ADMM on the residual, with the training inputs' 0.4-shrunk squared channel norms and uniform output norms. Hard-sign the factors. Finally, keep signs and input scale fixed while choosing each binary output scale by least squares against all training residual responses, then round that scale to FP16. The response-aware scale update needs no extra payload; the unrounded train fit is not used to score validation.

The independent binary-only control uses exactly the same [matrix comparator](../binary-factors/README.md) and fixtures. `binary_postfit.py` takes the comparator's stored sign planes and input scales, fits each output scale to the full train-response covariance by the same least-squares rule as the hybrid, and rounds them to FP16. It runs **no ADMM**, consumes zero extra bits, and leaves factor images unchanged. The binary ranks are `352/512/640` for Q projections and `384/576/736` for the down projection. The hybrid rank is `b = b_control − 16s`, so its binary bits plus `16s(N+K)` real-factor bits plus `16(N+K)` scale bits exactly equal the control's packed payload. Rank 2 is chosen for layer-14 down and layer-27 Q; rank 4 for layer-0 Q. This choice came from comparing ranks 2 and 4 on these validation matrices. It is **selection on validation**, not a frozen policy tested on unseen matrices. For Q, the exact rates are `.5390625/.7734375/.9609375` BPW; for down, `.5208333/.7708333/.9791667` BPW. Nothing here is a full-model BPW.

Fits ran on 8 CPU threads with seed 0. The nine three-rate pilot ADMM calls totaled **71.93 wall seconds**; their three randomized response-subspace fits took **0.42 seconds** in total, once per matrix. The complete 16-matrix .55-BPW sweep, using rank 2 except for the pilot's layer-0 Q rank 4, took **92.48 wall seconds** in its ADMM calls. Response-scale solves and image serialization are outside those timed sections. Calibration consumed 2,048 train vectors per matrix, not NanoQuant's 128 sequences of length 2048 and its other tuning stages. `fit.py` stores a report with per-rate timing and separate train/validation errors.

## Held-out response at equal physical matrix payload

Entries are squared relative response errors `||X_val(Ŵ−W)ᵀ||² / ||X_val Wᵀ||²`. The hybrid column uses *redecoded* packed signs and FP16-rounded real factors and scales. The table includes one winner at each original target budget; selecting rank using these validation values does not establish transfer to another layer or split.

| Matrix | Target | Physical BPW | Binary ADMM scales | Binary train-response scales | Spectral + binary train-response scales | Binary/spectral ranks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| layer 0 Q | .55 | .53906 | .09666 | .09296 | **.08818** | 288/4 |
| layer 0 Q | .80 | .77344 | .07368 | .07092 | **.06868** | 448/4 |
| layer 0 Q | 1.00 | .96094 | .06025 | .05817 | **.05553** | 576/4 |
| layer 14 MLP down | .55 | .52083 | .44383 | .44002 | **.43426** | 352/2 |
| layer 14 MLP down | .80 | .77083 | .31712 | .31404 | **.31355** | 544/2 |
| layer 14 MLP down | 1.00 | .97917 | .24136 | **.23900** | .24126 | 704/2 |
| layer 27 Q | .55 | .53906 | .11579 | **.11050** | .11155 | 320/2 |
| layer 27 Q | .80 | .77344 | .08859 | **.08472** | .08561 | 480/2 |
| layer 27 Q | 1.00 | .96094 | .07104 | **.06816** | .06844 | 608/2 |

For a wider check, the same two-mode construction was fitted on every other supplied matrix at target .55 BPW, while layer-0 Q retained the four-mode pilot choice. Against **original** ADMM scales it improves 14/16, but the zero-byte binary-postfit control improves 16/16. Against that stronger control, spectral modes win 8/16. Medians across the 16 are `.31484` original, `.30430` binary-postfit, `.30035` hybrid. The held-out per-matrix errors are below; each cell is binary-postfit / hybrid.

| Layer | MLP down | MLP up | Attention Q | Attention O |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .45449 / .46325 | .44267 / .44464 | .09296 / .08818 | .27454 / .27822 |
| 7 | .44013 / .44116 | .41288 / .41684 | .12140 / .12386 | .46919 / .46758 |
| 14 | .44002 / .43426 | .32799 / .32247 | .09113 / .09219 | .28061 / .26194 |
| 27 | .03086 / .03059 | .14472 / .14317 | .47293 / .46163 | .11050 / .11155 |

Selection of the 2/4 split from the pilot validation results still limits how much to infer from the hybrid's aggregate win count. The fair result is that **most of the apparent gain over original NanoQuant initialization was the output-scale rule**, not the FP16 mode allocation. The real modes have pockets of value, especially layer-0 Q and the layer-14/27 attention outputs, but no consistent quality dominance. They reduce signed work while adding real FMA work; that trade needs a kernel receipt.

Without the response-scale update, the 4-mode down fit *loses* at all three rates, and the 2-mode down fit wins at .55/.80 but ties or loses by a hair at 1.00 against original binary scales. Train-fitted hybrid scales move its 1.00 error to `.24126`, but fitting the **same** scales on binary-only yields the better `.23900`. The zero-byte rule deserves to be applied to every binary-factor baseline before assigning any gain to real modes.

The packed image has binary U `[N,b]` and V `[b,K]`, FP16 input and output scales, and FP16 real L `[N,s]` and R `[s,K]`. Payload bytes are `ceil(b/8)*N + ceil(K/8)*b + 2*(N+K) + 2*s*(N+K)`. The `.npz` header adds 1,742 bytes to these tested files; it is counted separately from matrix payload. Stored hybrid images and JSON reports live at `/path/to/workspace/data/kelana-subbit/spectral-residual/`; the binary-postfit control's images and reports are in its `binary-postfit/` child. The binary-postfit `.npz` headers add 1,256 bytes per image, separately from the identical matrix payload.

## Online work, not a speedup claim

For batch-one gfx1151 inference, the binary branch needs `b(N+K)` signed accumulations after packed sign extraction. The real branch needs `s(N+K)` FP16 FMA terms, with an `s`-element intermediate. At target .55, layer-0 Q falls from `1,081,344` signed accumulations to `884,736` signed plus `12,288` real FMA terms; down14 falls from `1,572,864` to `1,441,792` signed plus `8,192` real FMA terms; layer-27 Q falls to `983,040` signed plus `6,144` real FMA terms. This is a work-composition change, not a measured latency reduction. In particular the extra branch needs a launch or fusion, output accumulation and a few real-factor reads even though the compressed bytes are unchanged.

A fused consumer can keep the real `s`-vector and binary `b`-vector locally and add both contributions before writing each output. An unfused design writes/reads another `2s` BF16 values and may read/write the `N`-element output twice, adding at least `4s + 4N` bytes per vector beyond the binary branch's intermediate traffic. Actual placement, sign masks, registers, matrix versus vector instructions, L2/DRAM transactions and attention/MLP boundary conversions need gfx1151 measurements. A small real rank can fit the output's large response directions while the binary residual handles the rest; there is no claim that the spectral labels pass through Q/K RMSNorm, RoPE or the down-projection residual add for free.

The result suggests a concrete next mathematical improvement: optimize the *binary signs and real span together* against a weighted train-response loss, rather than computing an FP16 response span first and factoring the leftover weight matrix by ADMM. Give each candidate mode its marginal reduction in held-out response error per stored bit **and** per online accumulation. Use a new frozen split or untouched model layers to decide if the 2/4-mode selection generalizes.

## Reproduce

```bash
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/spectral-residual/fit.py
F=/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext
O=/path/to/workspace/data/kelana-subbit/spectral-residual
$P "$D" --fixture "$F/layer00-self_attn_q_proj.npz" --spectral-rank 4 --fit-post-scales --out "$O"
$P "$D" --fixture "$F/layer14-mlp_down_proj.npz" --spectral-rank 2 --fit-post-scales --out "$O"
$P "$D" --fixture "$F/layer27-self_attn_q_proj.npz" --spectral-rank 2 --fit-post-scales --out "$O"
for fixture in "$F"/*.npz; do
  case "$fixture" in
    *layer00-self_attn_q_proj.npz|*layer14-mlp_down_proj.npz|*layer27-self_attn_q_proj.npz) continue ;;
  esac
  $P "$D" --fixture "$fixture" --spectral-rank 2 --rates .55 --fit-post-scales --out "$O"
done
for fixture in "$F"/*.npz; do
  $P research/quantization-discovery/subbit/spectral-residual/binary_postfit.py \
    --fixture "$fixture" --out "$O/binary-postfit"
done
```
