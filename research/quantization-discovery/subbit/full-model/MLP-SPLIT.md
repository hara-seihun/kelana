# The first-layer MLP cannot be repaired one projection at a time

With the frozen rank-28 narrow V/O image in layer 0, replacing *all three* binary MLP projections by their BF16 originals lowers the damaged-prefix gold NLL from 11.465 to 8.819 on eight validation windows and from 12.149 to 10.579 on six test windows. Replacing any one or two does much less. The best two-projection mean leaves 1.092 validation and .854 test nats of the full MLP repair unrecovered. This closes the cheap diagnostic shortcut of keeping one MLP projection exact while compressing the others; it does not reject a learned compressed three-projection map.

The only changing weights in this panel are layer-0 gate, up and down. Layers 0–13 otherwise use the refined binary body and norms, layers 14–27 and the tied endpoints remain original, and layer-0 V/O always uses the same frozen joint rank-28 image. Q/K stay binary. Every MLP arm is an original BF16 or binary BF16-expanded matrix, not a fitted mixed-precision image. Each 256-token window contributes 255 gold predictions. The windows and image have appeared in previous panels, so this is a mechanism diagnosis, not blind model selection.

| Original layer-0 MLP projections | Extra bytes over narrow + binary MLP | Whole-model BPW increment | Validation NLL, 8 windows | Test NLL, 6 windows |
| --- | ---: | ---: | ---: | ---: |
| None | 0 | 0 | 11.465 | 12.149 |
| Gate | 6,086,644 | .081693 | 10.876 | 11.757 |
| Up | 6,086,644 | .081693 | 10.940 | 12.123 |
| Down | 6,086,644 | .081693 | 10.762 | 12.054 |
| Gate and up | 12,173,288 | .163386 | 10.393 | 11.750 |
| Gate and down | 12,173,288 | .163386 | 9.911 | 11.812 |
| Up and down | 12,173,288 | .163386 | 10.374 | 11.433 |
| All three | 18,259,932 | .245079 | 8.819 | 10.579 |

Each increment replaces one paid binary projection with its original 2-byte-per-weight copy. These are *additional* bytes in the same model with 596,049,920 unique parameters, not standalone image rates. On validation, the full MLP beats gate+up and up+down on every window, and gate+down on five of eight; on test it beats the respective pairs on four, five and five of six. No two-projection arm is a reliable surrogate for the three-projection map. The finite third-order loss difference, `L111 - L110 - L101 - L011 + L100 + L010 + L001 - L000`, is −.747 validation and −.631 test nats in the aggregate, but its per-window sign flips. Do not extrapolate this average as an invariant interaction coefficient or a model scaling law. Restoring an additional original matrix can even worsen an individual window's NLL.

The concrete fitting target is the *joint* post-MLP residual under narrow V/O and quantized later layers. A frozen mixed-exact projection is not a useful rate-allocation baseline here; compress all three gate/up/down matrices together, including their shared hidden-channel coordinate, and compare its paid rate and held gold NLL with the eight frozen substitutions. Gate and up multiply after SiLU, then down sums the products. A channel permutation shared by all three projections leaves the real-arithmetic map unchanged, and up/down have a reciprocal channel scale gauge; this is an opportunity for joint coding, not an assertion of BF16 bit identity or zero-cost native realization. Any proposed native consumer still has to price both factor stages, activation-dependent preparation and the boundary to the residual stream. In particular, exact MLP plus frozen narrow V/O still scores 8.819 validation versus 7.746 for original V/O plus MLP in the preceding paired panel, so after fitting the MLP the V/O right basis must be reconsidered.

`mlp_split.py` reproduces the eight substitutions. `/path/to/workspace/data/kelana-subbit/full-model/mlp-split-{validation-24-25,validation-26-27,validation-28-29,validation-30-31,test-56-57,test-58-59,test-60-61}.json` contain every per-window score, input/model/image/source SHA-256, split indices and paid bytes. Run each two-window panel through Bonsai's `tools/run-batch-compare --runtime-max 44s --exec /path/to/workspace/data/fish-s2-pro/venv/bin/python SCRIPT --split validation --start 24 --count 2 --out OUTPUT`, changing split/start/output for the other windows. All panels restored the active resident service. This is BF16-expanded model quality, not native compressed inference or runtime acceptance.
