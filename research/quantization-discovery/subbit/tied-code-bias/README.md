# Can an existing tied-head code label replace the frequency ID?

No, within a four-segment, class-constant bias family on the pinned K256 image. A train-only selector chooses the global rare-row offset over every label-indexed table. On 64 held original-hidden Qwen3-0.6B head inputs, the global arm scores 4.402961 NLL and 0.894272 teacher KL. The best *label-only* arm by the 32-position train-calibration split uses segment 16 and scores 4.480830 NLL and 0.948166 KL. This is a useful stop on a tempting cheap correction, not a general rejection of code-aware head training. The [frequency-bucket correction](../tied-bias/README.md) scores 4.38285 NLL and 0.89642 KL on these held inputs, but reads an additional 56,976-byte per-row group image.

## Map and price

The frozen image has 64 eight-bit segment labels per vocabulary row, 2,560 exact BF16 rows, and a fixed rare-row temperature of 1.2777578. For one selected segment, an exact row keeps its original logit. Every other row adds `b[label]` after its existing codebook response and temperature. A 256-entry FP16 bias table costs 512 bytes, or 0.0000263 bits per tied weight beyond the 17,412,100-byte base image, against 56,988 bytes for the six-frequency-bin correction. Its online consumer reuses one label already fetched for that row, but adds a dependent table lookup and an add per rare logit. We have not measured that lookup on gfx1151. The input embedding continues to use the unchanged shared image.

One label is not a lossless representation of frequency or of the quantization residual. The four tested segments are 0, 16, 32 and 48, chosen before inspecting held results. The claim is conditional on this single-segment, class-constant table grammar, not a lower bound on combinations of segments or a refitted codebook.

## Fit and result

The standard `gold-row/` response captures supply 128 train-fit positions, 32 separate train-calibration positions and 64 held validation positions, all at fixed original final-hidden inputs. For each candidate, fit a 256-class bias on the 128 positions with gold NLL plus twice original-weight teacher KL, plus `0.01 * mean(b**2)` to keep rare classes finite. Compare the fit-only objective on the 32-position calibration set against the global-offset arm. Refit each arm on all 160 training positions before evaluating held logits. The 2,560 exact rows anchor bias zero. This objective is convex in the class biases, and the class partition reduces each softmax and its gradient to 257 masses per example; L-BFGS-B solves that finite objective. The table is FP16-round-tripped before held scoring. Teacher KL uses the captured original BF16 held logits, as in the frequency-bucket study.

| Arm | Train-calibration objective | Held NLL | Held teacher KL | Original top-1 agreement /64 |
| --- | ---: | ---: | ---: | ---: |
| Global rare-row offset | **43.803996** | **4.402961** | **0.894272** | 51 |
| Segment 0 label | 43.864970 | 4.461884 | 0.924823 | 51 |
| Segment 16 label | 43.856995 | 4.480830 | 0.948166 | 50 |
| Segment 32 label | 43.889205 | 4.490635 | 0.982634 | 54 |
| Segment 48 label | 43.969764 | 4.587203 | 0.989701 | 50 |

The objective includes teacher cross-entropy constants and is only comparable within this panel. The best label arm loses to the global arm on both held windows: 4.336134 versus 4.202176, and 4.625526 versus 4.603746. More fitted classes are not a free substitute for frequency information when each class mixes many rare rows. The selected arm remains the global offset, so no new head image is proposed for the runtime.

`study.py` reproduces the CPU replay in under a minute with `OPENBLAS_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/tied-code-bias/study.py`. The retained `data/kelana-subbit/tied-code-bias/result.json` records hashes for the source, codebook, frequency image, every capture, four FP16 tables, class counts and split metrics. No GPU, Bonsai executable or resident service changed.

The next worthwhile question is whether the frequency-bin gain survives embedding-propagated model loss on a fresh sample. If it does, try deriving a cheap group from row ID plus one small exception structure, or fold the group into labels during a new code fit; another freely fitted table on one frozen label is not the right next run.
