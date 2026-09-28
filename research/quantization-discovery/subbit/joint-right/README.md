# Jointly fitted Q basis at the equal-byte rank limit

A rank-108 two/four-bit Q factor fits under the 118,176-byte rank-88 three/four-bit ceiling, but the earlier frozen spectral right basis lost to an attention-trained rank-88 image. This experiment asks whether changing the right codes as well as the left codes makes the extra 20 dimensions useful. It does, but not enough to displace three-bit left codes. This is a fixed-original-input layer-0 attention study, not a whole-model or native timing result.

The starting rank-88 image is the attention-fitted two/four-bit image from `attention-radial`. Twenty right rows come from the previously fitted rank-128 spectral image. A train-input least-squares solve expresses the residual response in those 20 directions. Simply recomputing the common left scale across 108 coordinates damaged the initial rank-88 response: an early run started at held attention KL .19239 and ended at .19549. The format has **one group-128 scale per left row**. There is no independent scale for the extra 20 coordinates. Instead, a per-coordinate positive factor gauge moves their amplitude into the existing paid right scales, while preserving the original left codes and row scales for the first 88 coordinates. The added codes are then rounded to the two-bit odd grid. This has exactly the same serialized format and online two-pass program. It starts at held KL .14271 rather than .19239.

Both ranks then receive 20 straight-through Adam steps over left and right codes and their existing FP16 scales, at learning rates .05 and .20 respectively. Their objective is train attention KL plus twice post-O relative squared error plus half normalized-Q relative squared error. Eight 256-token WikiText train windows supply fit inputs; four disjoint 256-token validation windows supply the held observations. Original K, V, O, normalization and RoPE remain fixed. No quantized embedding propagates through the model. The rank-88 arm starts from the same attention-fitted image and receives the same optimizer, so the rank comparison does not credit the larger image for the optimizer alone.

| Q image | Stored bytes | Factor terms/query | Held attention KL | Held post-O squared error |
| --- | ---: | ---: | ---: | ---: |
| Rank 88 two/four, existing seed | 95,648 | 270,336 | .11290 | .02608 |
| Rank 88 two/four, joint fit | 95,648 | 270,336 | .10367 | .02451 |
| Rank 108 two/four, gauged extension before fit | 116,448 | 331,776 | .14271 | .03014 |
| Rank 108 two/four, joint fit | 116,448 | 331,776 | **.09985** | **.02365** |
| Rank 88 three/four, separately attention-fitted | 118,176 | 270,336 | **.09242** | **.02181** |

Adding rank under the joint training procedure improves held KL by .00382 and post-O error by .00086 against the rank-88 two-bit control. It costs 20,800 bytes and 61,440 factor terms per query. The rank-88 three-bit image takes 1,728 more bytes than the rank-108 two-bit image, but has better held attention KL and post-O error while using 18.5% fewer terms than rank 108. Storage alone does not justify native timing here; two-bit extraction may still have a different instruction cost from three-bit extraction, which these work counts do not measure. The older frozen-right rank-108 fit scored .20130 KL, so right-basis adaptation plus the common-scale gauge substantially changes that negative, without establishing a quality-matched win.

The trained rank-108 image has held raw-Q relative squared error 1.8763. The headwise positive radial gauge in `attention-radial` explains why raw amplitude can be poor while normalized Q and attention improve, but this run did not apply its post-fit amplitude correction. The consumer errors, not raw Q, are the comparison above. The straight-through fit also has a train/held gap: KL .04799/.09985 for rank 108 and .05168/.10367 for rank 88. Neither held panel substitutes for fresh full-model loss.

The exact rate formula for this row-packed group-128 format is in [the rank-cap report](../factor-rate-grammar/README.md). At rank 108, 116,448 bytes means .44421 matrix BPW. The factor program consumes 331,776 logical terms, scales and an intermediate. The 16-wide padded rank grows from 96 to 112; this is a work and resource estimate, not native latency. The next construction should spend extra rank on directions learned *against held-separated train attention residuals* rather than a spectral append, or allocate those bytes to selected high-sensitivity left groups. Test that against the three/four-bit rank-88 control and a fresh loss panel before building a GPU consumer.

`fit.py` writes images and JSON receipts under `/path/to/workspace/data/kelana-subbit/joint-right/`, with source, fixture, model, seed and image hashes, metrics and optimizer traces. The two raw command logs are `/path/to/workspace/data/kelana-subbit/joint-right-run88.log` and `joint-right-run108.log`. The initial common-scale failed arm had source SHA256 `0b8982e1694c8c2611c732b4c88a31d3cd696898b98aaafe6b7ccda52cf685be`, 20 steps and held KL .19239 to .19549; its post-O error moved .04538 to .03546. A right-code learning rate of .0125 left every right code unchanged and produced held KL .10656 after the gauge repair; the .20 right-code rate changes 53,867 of 110,592 codes and reaches .09985. These failures explain the scale and optimizer choices rather than being discarded as evidence of a bad family.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/joint-right
OPENBLAS_NUM_THREADS=1 "$P" "$D/fit.py" --rank 88 --steps 20
OPENBLAS_NUM_THREADS=1 "$P" "$D/fit.py" --rank 108 --steps 20
```

No GPU reservation, Bonsai executable or resident service changed.
