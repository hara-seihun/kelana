# A calibrated four-bit layer in the ternary Qwen model

Layer 17 was chosen before scoring as the middle of the seven-layer region whose symmetric-Q4 substitution had survived matched scale recovery. This experiment replaces only its seven matrices with the saved sequentially calibrated affine-Q4 images, then updates the remaining 190 ternary scale providers through the complete Qwen3-0.6B gold loss. The baseline is the previously published all-ternary run with identical eight train windows, optimizer, steps and learning rate. Both use the same original ternary image and BF16 expansion for quality.

| Complete image | Payload bytes | BPW | Validation NLL, 8 windows | Test NLL, 32 windows |
| --- | ---: | ---: | ---: | ---: |
| Matched all-ternary recovery | 128,678,649 | 1.727086 | 4.725857 | 4.648968 |
| Calibrated Q4 layer 17, frozen before recovery | 133,641,689 | 1.793698 | 4.742404 | not scored |
| Calibrated Q4 layer 17, eight-step recovery | 133,641,689 | 1.793698 | 4.725945 | 4.625448 |
| Recovered symmetric Q4 layers 14–20 | 161,700,001 | 2.170288 | 4.711406 | 4.604734 |

The one-layer image buys .023520 test nats for 4,963,040 extra bytes, compared with .044234 nats for 33,021,352 extra bytes in the seven-layer symmetric-Q4 image. Its matched validation difference is +.000088 nats, effectively no validation gain. On test, 26/32 windows improve, with paired standard error .003792 nats for the mean difference. These test windows have been reported before; do not choose a serving image or another layer by looking at them. The full calibrated four-bit image is much better at 3.795795 test NLL but costs 4.251313 BPW. This experiment establishes an informative paid quality/rate point, not a Bonsai-quality ternary conversion or an inference speedup.

`calibrated_splice.py` verifies the 197-image ternary and calibrated-Q4 manifests, hashes every substituted Q4 file, checks shapes, counts replaced packed payloads once, and saves all retained FP16 scales beside the receipt. The matched train rows are 448–455 of `expanded-tokens.npz`; none of the validation or test rows enters gradients or checkpoint selection. Eight Adam updates use learning rate .0003. The script uses the existing packed-image decoders but expands weights to BF16 for complete-model loss. The NPZ scale companion is a custody representation of the retained paid scales, not extra inference bytes.

The receipt is `/path/to/workspace/data/kelana-subbit/ternary/quality/calibrated-splice-l17-v1.json`, SHA-256 `b3894cb902ed8ad04e9adfc538962624884f49e9ef0f5f5dd8289e0dd2bc5b1e`; its scale companion SHA-256 is `ff171423df29be8ed44304071f1dd1dd5af35bdcd962f3f6f42aa55dfef14f09`. The matched all-ternary and seven-layer controls are `mixed-recovery-control-test-v1.json` and `mixed-recovery-q4-14-20-test-v1.json` in the same directory. The receipt includes source, model, fixture, manifest, decoder and image hashes, per-window losses and paid bytes. The GPU wrapper restored `bonsai-halo.service`; no installed image or runtime changed.

## Untouched validation half, frozen-image replay

The unused validation windows 8–15 were scored **without another optimization step or image choice**. `fresh_validation.py` restores the two saved FP16 scale companions into the same packed-image providers, verifies every restored FP16 scale bit and every paid image hash, and expands the images to BF16 for complete-model gold NLL. Each arm reads the same 2,040 next-token targets. The [per-window, model/image/source-hashed receipt](/path/to/workspace/data/kelana-subbit/ternary/quality/calibrated-splice-fresh-validation-v1.json) has SHA-256 `8529bc0d181a2cabd8d31baa5f1bc80d8cf3e583bad283c585b7a98b1bbe7281`. The GPU wrapper restored the resident service.

| Validation rows | All ternary, 1.727086 BPW | Layer-17 Q4, 1.793698 BPW | Q4 minus ternary, paired SE | Q4 wins |
| --- | ---: | ---: | ---: | ---: |
| 0–7, previous exploratory panel | 4.725857 | 4.725945 | +.000088 ± .007221 | 5/8 |
| **8–15, untouched replay** | **5.262661** | **5.250784** | **−.011877 ± .008433** | **5/8** |
| 0–15 combined | 4.994259 | 4.988365 | −.005894 ± .005581 | 10/16 |

The fresh half favors the paid image but not decisively; its mean loss is much higher in both arms than the first half, so selecting on the first eight does not characterize validation difficulty. The earlier inspected test gain is larger (−.023520 over 32 windows). Neither image is an installed packed runtime; no speed claim follows.

## New disjoint validation text: the paid edge vanishes

`novel_text.py` froze sixteen more 256-token validation windows from WikiText-2 using seed 20260923, excluding every prior pilot, fresh-evaluation and ternary validation interval **before** scoring. It reused the same two saved images and scale companions, with no fitting, layer choice or checkpoint selection after seeing the text. The source/tokenizer and all excluded intervals are recorded in [the fixture manifest](/path/to/workspace/data/kelana-subbit/ternary/quality/novel-validation-v1.json); the fixture SHA-256 is `26d0317100a6e5292246875376767f4fa647d57590cfebcf7940f05496f270f8`. The [complete-model per-window receipt](/path/to/workspace/data/kelana-subbit/ternary/quality/novel-validation-v1-score.json), SHA-256 `56a36191f4ac94333a0bec2849dc932881e9846e5a3cd94a45ce30e868d2b93a`, hashes the source, original model, frozen paid images/scales and inputs. The wrapper restored `bonsai-halo.service`.

| Validation panel | All ternary, 1.727086 BPW | Layer-17 Q4, 1.793698 BPW | Q4 minus ternary, paired SE | Q4 wins |
| --- | ---: | ---: | ---: | ---: |
| Newly frozen, sixteen disjoint windows (4,080 predictions) | 4.592910 | 4.593013 | **+.000103 ± .006164** | 7/16 |
| All 32 validation windows (16 earlier, 16 new) | — | — | −.002896 ± .004125 | 17/32 |

Thus the extra 4,963,040 bytes buy no detectable improvement on the new independent panel, despite the earlier inspected 32-window test edge and the preceding eight-window validation gain. The new paired panel does not prove Q4 is intrinsically worse; it rejects promoting *this frozen layer-17 allocation* on those gains. Next choose a paid layer allocation and recovery duration using genuinely new **training and selection** text, then freeze one candidate for separate complete-model quality. Repeatedly scoring this same image will not rescue its rate advantage. The source remains a BF16-expanded quality experiment, not a native mixed reader or speed result.
