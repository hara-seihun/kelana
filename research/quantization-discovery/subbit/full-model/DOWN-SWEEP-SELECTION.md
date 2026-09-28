# Early stopping the damaged-producer down-code fit

The [two-sweep down-code fit](MLP-QUANTIZED-CODES.md) lowered held endpoint error but raised six-window test loss. Was its second sweep simply too much fitting? I saved the image **after the first train-only coordinate sweep**, before inspecting model loss, and compared it to the scale-only and two-sweep images on exactly the same windows.

The producer is layer 0 with binary Q/K and norms plus shared rank-28 V/O. Gate/up codes and all paid scales come from the damaged-producer scale fit. Only the down output signs and their FP16 row scales change. All three MLP images use 614,436 payload bytes and the same online factor operations. The first sweep changes 61,378 signs; the two-sweep image changes a further 25,227. The fit uses 2,048 train positions and FP32 squared endpoint response. The held 1,024-position capture was already inspected in the prior experiment.

| Image | Train endpoint relative squared error | Held endpoint relative squared error | Six later test windows NLL | Eight later validation windows NLL |
| --- | ---: | ---: | ---: | ---: |
| Scale-only | .709531 | .830638 | **11.56619** | 11.29725 |
| One sign sweep | .633567 | **.819203** | 11.61623 | 11.25014 |
| Two sign sweeps | **.610369** | .821403 | 11.83990 | **11.21527** |

One sweep beats two on five of six test windows, but only three of eight validation windows. Against scale-only it wins three of six test and four of eight validation windows. The first sweep's superior held endpoint error does **not** restore a test NLL win over scale-only, though it cuts the second sweep's test penalty from .274 to .050 nats. The validation ordering goes the other way. These windows have been inspected repeatedly, so this is an ablation of optimizer duration, not a fresh selection set.

The negative has a narrow contract. It rejects the explanation that merely stopping this frozen-hidden squared-response down-U fit after one sweep selects a robust full-model image. It says nothing about a jointly trained gate/up/down code image, new V/O coordinates, or gold/teacher loss. The next useful experiment should backpropagate gold or teacher continuation on independent quantized-producer text through the *joint* layer-0 V/O and MLP image; spending another endpoint-squared-error sweep is not the missing ingredient. Keep the scale-only image as the equal-byte baseline.

`mlp_quantized_code_fit.py fit --one-sweep --sweeps 1` saved the image and source/input/output hashes to `/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-one-sweep.json` and `mlp-quantized-one-sweep-image/`. Its source SHA-256 is `0028cb7b5c4043f01340e8d9d70662345da0e8c7e96b34aaf7a5779c1e7ee0e4`; the down image SHA-256 is `af912d549ad0dcf2d58b14ff22728dd21df0b41bfa7c27b86bfe9d2c8daef2e7`. Four `evaluate --one-sweep` panels ran under Bonsai's `tools/run-batch-compare --runtime-max 45s --exec ...`, with test starts 56/2 and 58/4 and validation starts 24/4 and 28/4. Their `mlp-quantized-one-sweep-{test,validation}-*.json` receipts hold per-window NLL, tokens, source, model and image hashes. The existing two-sweep receipts match every token hash and the scale-only NLL on each window. Each GPU panel restored the active resident service. This is BF16-expanded complete-prefix model loss, not native compressed-inference timing; no Bonsai runtime changed.
