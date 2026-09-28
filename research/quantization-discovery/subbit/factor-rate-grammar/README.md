# Does extra rank pay for a two-bit Q output factor?

The rank-88 attention-trained Q projection costs 118,176 bytes with three-bit left and four-bit right codes. At that byte ceiling, a two-bit left factor can reach rank 108. I tested whether spending the saved left-code bytes on 20 more response coordinates recovers the attention quality lost at two bits. On this particular spectral right-factor seed, it does not. Rank 108 slightly worsens held attention KL against rank 88 after the same fit, and both lose badly to the previously trained attention-aware rank-88 image. More rank is not a substitute for a right basis chosen for the attention consumer.

## Exact paid-rate frontier in this format

For output width 2,048, input width 1,024, group size 128, left precision 2 and right precision 4, the serialized array payload at rank `r` is

```
S(r) = 2048*ceil(2r/8) + 4096*ceil(r/128) + 528r + 32 bytes.
```

The terms are row-packed left codes, FP16 left group scales, right four-bit codes plus FP16 group scales, and two 16-byte descriptors. No padded factor coefficients are charged. `S(108)=116,448`, `S(109)=119,024`: the rank-109 row packing step breaches the 118,176-byte three/four-bit control. Thus 108 is the exact maximum rank **within this row-packed two/four-bit, group-128 format at that byte ceiling**. It is not a bound on learned codebooks or different scale placement.

The conventional two-pass factor program at rank 108 consumes `108*(1024+2048)=331,776` factor terms per query, 22.73% more than the rank-88 program's 270,336. With 16-wide padding, the rank-88 and rank-108 shapes require 96 and 112 factor lanes, a 16.67% increase. This is a work count for the two-pass grammar, not a GPU latency bound: short packed-code reads, extraction, scaling, launches and the intermediate must be measured. Rank 108 still uses 6.3 times fewer terms than the dense 2,097,152-term projection. Expanding into dense int4 is not part of this program.

## Fixed-input CPU experiment

`fit.py` takes the pre-existing rank-128 two/four-bit spectral-response image, retains its first 88 or 108 ordered coordinates and freezes the right codes/scales. Both arms initialize two-bit left codes and paid FP16 row scales from their own quantized seed and receive the same 30 straight-through Adam updates at learning rate .2. The objective is train attention KL plus twice post-O relative squared error plus half normalized-Q relative squared error. A train-only positive gain per head is folded into the paid left scales afterward. Eight 256-token train windows supply fit inputs; four distinct 256-token validation windows supply the held observations. Original K, V, O, norms and RoPE remain fixed. The code computes attention over original layer-0 hidden inputs and does not propagate quantized embeddings or measure a whole model.

| Q image | Stored bytes | Terms/query | Held KL | Held post-O squared error |
| --- | ---: | ---: | ---: | ---: |
| Spectral seed, rank 88, two/four, before fit | 95,648 | 270,336 | .36248 | .11874 |
| Spectral seed, rank 108, two/four, before fit | 116,448 | 331,776 | .33290 | .11034 |
| Spectral seed, rank 88, two/four, after fit and gauge | 95,648 | 270,336 | **.19934** | .03828 |
| Spectral seed, rank 108, two/four, after fit and gauge | 116,448 | 331,776 | .20130 | **.03738** |
| Separate attention-trained rank 88, two/four | 95,648 | 270,336 | .11290 | .02608 |
| Separate attention-trained rank 88, three/four | 118,176 | 270,336 | **.09242** | **.02181** |

The two fitted spectral arms use the same source basis and fitting procedure, so the extra 20 coordinates have a clean local comparison. They improve post-O error by .00090 but worsen KL by .00196 after fitting. The attention-trained arms use a different four-bit right basis and are **not** controlled rank ablations of it. Their large lead rules out promoting this spectral-seeded rank-108 image on the basis of byte/term arithmetic. It does not prove that all rank-108 two-bit constructions lose, nor that a more extensive optimizer could not help. In fact, its initialization improves both metrics before fitting: the optimizer spends the extra capacity in a way the held KL does not reward.

The next experiment should extend the attention-trained right factor with residual directions selected by *held-out-separated train attention gradients*, and refit both factor stages together. Frozen spectral directions plus left-only fit answer the narrower question here. A native lowering is premature for an image dominated on held quality by a lower-rate image. If a better image survives, compare the full two-pass kernel at one and sixteen queries against the matched three-bit image; the rank-108 arithmetic and padded-lane increases are its explicit cost hurdles.

## Reproduce and custody

The source, model and fixture SHA256s, original and trained metrics, optimizer trace, packed-image SHA256s and paid byte counts are in `/path/to/workspace/data/kelana-subbit/factor-rate-grammar/`. Rank-108 image SHA256 is `524b53723b26313c32c9911d59d73d7a30282fc7de6eba16f879d4f14ae3fbf7`. Raw foreground output is in `factor-rate-grammar-r88-run.log` and `factor-rate-grammar-r108-run.log` at the data root. This is CPU fitting, with no GPU reservation and no Bonsai runtime or service change.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/factor-rate-grammar
OPENBLAS_NUM_THREADS=1 "$P" "$D/fit.py" --rank 88 --steps 30
OPENBLAS_NUM_THREADS=1 "$P" "$D/fit.py" --rank 108 --steps 30
```
