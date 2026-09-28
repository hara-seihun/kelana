# Recovering a paid mixed ternary and four-bit image

The independently fitted four-bit layers 14–20 hurt Qwen3-0.6B validation loss when spliced into the selected ternary model. This experiment fixes those 49 four-bit matrices, then fits the *remaining* ternary scales against complete-model next-token loss. The matched control updates all ternary scales with the same data and optimizer. Co-adaptation reverses the splice penalty on the held panels, at a substantial byte cost.

| Complete image | Payload bytes | BPW | Validation NLL, 8 windows | Test NLL, 32 windows |
| --- | ---: | ---: | ---: | ---: |
| Selected ternary, before this update | 128,678,649 | 1.727086 | 4.733112 | 4.646432 |
| Ternary, matched eight-step update | 128,678,649 | 1.727086 | 4.725857 | 4.648968 |
| Frozen Q4 layers 14–20, before update | 161,700,001 | 2.170288 | 4.772191 | not measured here |
| Frozen Q4 layers 14–20, eight-step update | 161,700,001 | 2.170288 | **4.711406** | **4.604734** |

The mixed arm improves its own validation by .060785 nats; the matched ternary improves by .007254. Against the matched control it wins .014451 validation NLL and .044234 test NLL. Twenty-four of 32 test windows favor mixed, with paired per-window standard error .012879 nats. Validation is only five of eight windows in favor, with paired standard error .017112. Those windows have been reported in previous conversion rounds; this is not a fresh blind evaluation. At 33,021,352 additional payload bytes, the test improvement is real within this panel but too small to call an attractive rate-quality frontier without comparing better allocations and the stronger calibrated four-bit image, which scores 3.7958 test NLL at 4.2513 BPW. BF16 scores 3.6392.

## What was trained and saved

Both arms start from the same 197-matrix `expanded-scale384` radix-243 image. The mixed arm replaces seven projections per layer in layers 14–20 with the already saved symmetric four-bit scalar matrices; the remaining ternary codes, signs, and the tied embedding/head stay unchanged. Train windows 448–455 in `expanded-tokens.npz` have not entered the previous 512-step scale fit. Each arm takes eight Adam steps at learning rate .0003, one 256-token train window per step, with FP16-rounded ternary scales in every forward. The Q4 weights are frozen BF16 expansions of the existing paid image. The control fits the identical train rows, including scales in layers 14–20; the mixed arm has no such scales. No held window enters gradients or checkpoint choice; the last step is evaluated, not selected by held loss.

The composite mixed image is defined by the source packed ternary code/sign files with the saved FP16 scale replacements for the 148 retained matrices, plus the 49 immutable Q4 files identified in the receipt. It does not pay for both old and replacement scales. The NPZ scale companion is a custody format, not an extra inference payload. `mixed_recovery.py` checks each Q4 hash and the complete ternary manifest, then records source, fixture, model and script hashes, per-window losses, byte count and scale-companion hash. The actual quality forward uses these packed-code decoders through `tune.PaidScaleImage` and expands weights to BF16. This does not measure a packed native reader or throughput. A mixed reader must support both formats; the 33 MB byte increase is not itself a speed gain.

Raw receipts and the learned FP16 scale companions:

- `/path/to/workspace/data/kelana-subbit/ternary/quality/mixed-recovery-control-test-v1.json`, scales SHA-256 `b5048ec7f435910ecddabcb6e165cfdfcc6d80aae29d83df3848093651b22ecd`.
- `/path/to/workspace/data/kelana-subbit/ternary/quality/mixed-recovery-q4-14-20-test-v1.json`, scales SHA-256 `7fcccd1b0abda071b2a737f43fe4e78da808f8d43a828df5c051de5a7cc523d3`.
- Earlier eight-window screening receipts with the same outcome are retained as `mixed-recovery-{control,q4-14-20}-v1.json`. The test-panel receipts rerun the same deterministic training and include 32 separate test-window losses.

Each GPU call used `tools/run-batch-compare`, 24 GiB process budget and a 49-second runtime bound. Both test-panel calls finished within 39 seconds and restored `bonsai-halo.service`; the shared GPU lock is free. The resident Bonsai and Qwen executables were not changed.

## Untouched validation half reverses the seven-layer result

`mixed_fresh_validation.py` reconstructs both **frozen** eight-step paid images from their saved FP16 scale companions, checks scale bits and every Q4 image hash, and scores validation windows 8–15, which were not used in training, selection or the earlier reported panels. Its [source/image/model/fixture-hashed receipt](/path/to/workspace/data/kelana-subbit/ternary/quality/mixed-recovery-fresh-validation-v1.json), SHA-256 `a0927ea88829ac11eabcdfb3e4b0d2bd4f63cf41d89030ff87f367973cf430a9`, retains the eight individual losses per arm. Each image reads 2,040 matched next-token targets, expanded to BF16 for complete-model quality. The GPU wrapper restored the resident service.

| Validation rows | Matched ternary, 1.727086 BPW | Recovered symmetric Q4 14–20, 2.170288 BPW | Mixed minus ternary, paired SE | Mixed wins |
| --- | ---: | ---: | ---: | ---: |
| 0–7, previously inspected | 4.725857 | 4.711406 | −.014451 ± .017112 | 5/8 |
| **8–15, untouched** | **5.262661** | **5.289023** | **+.026362 ± .044097** | **3/8** |
| 0–15 combined | 4.994259 | 5.000214 | +.005955 ± .023448 | 8/16 |

The paid image's sign changes on fresh validation; the large fresh uncertainty comes especially from window 9, on which mixed loses .305640 nats. Excluding that window would change the fresh mean to −.013535, so this is a heterogeneity signal, not evidence that co-adaptation always hurts. Its previously inspected 32-window test gain of .044234 nats does not transfer to a reliable validation advantage. At seven extra layers and 33,021,352 bytes, this symmetric-Q4 allocation has **not** earned a reader or image selection. The separately tested calibrated single-layer splice at 1.793698 BPW gains .011877 ± .008433 on the same fresh half, a more favorable rate point, but neither is a selected serving model.

## Next experiment

Freeze these controls. Choose calibrated-Q4 layer and training duration on new training and validation text, then evaluate paid complete-model quality on an untouched panel. This transfer negative rules out promoting the seven-layer symmetric splice from its inspected test gain, not the value of co-adaptation itself. Keep the selected 1.727-BPW ternary image as the low-rate reference; native mixed execution follows only a quality/rate win.
