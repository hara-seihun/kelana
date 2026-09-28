# Fit the first MLP where the compressed model actually runs

The original-producer input/output scale fit gave a large local gain, but layer 0 does not see that producer when its attention is compressed. I captured the actual BF16 layer-0 MLP input after binary Q/K and norms plus shared rank-28 narrow V/O, then refitted the same five already-paid scale vectors. This changes no binary signs, image payload slots or factor operations. The target is the *original layer-0 endpoint* minus the damaged producer's residual immediately before its MLP. Thus the fit asks the MLP to compensate the upstream attention error as well as its own error. It does not train on a quantized model's gold-token loss.

On 2,048 train positions, 16 full-batch Adam steps with the preceding fit's learning rate .025 and log-scale penalty .002, the held 1,024-position relative endpoint-response squared error is:

| MLP scales | Train | Held validation |
| --- | ---: | ---: |
| Refined binary image | .762695 | .858753 |
| Prior original-producer scale fit | .726536 | .843966 |
| Refit on the damaged producer | .709531 | **.830638** |

The comparison uses the same packed gate/up/down sign planes, FP16 scale slots and native factor program. The held capture comes from the repeatedly inspected four original validation windows, so this is a construction lead, not a blind selection result. The capture uses the original tied embedding, actual binary layer-0 Q/K and norms, frozen shared rank-28 V/O, and original MLP weights only while observing its input. The reference endpoint comes from the original first layer on the same token IDs. Capturing BF16 pre-MLP residual separately is essential: fitting `original MLP(x)` instead would silently discard the producer's residual error.

I then expanded the three stored MLP scale images to BF16 solely for a full-model quality comparison. Layers 0–13 use the refined binary body and norms, layer-0 V/O uses the same narrow image, and later layers plus tied endpoints stay original. Each 256-token window has 255 gold predictions. This continuation tests the effects of BF16 rounding and downstream composition; it does not time a compressed native consumer.

| Paid MLP arm | Six later test windows, NLL | Eight later validation windows, NLL |
| --- | ---: | ---: |
| Binary, narrow V/O | 12.14876 | 11.46525 |
| Original-producer scale fit | 11.82568 | **11.21059** |
| Damaged-producer scale fit | **11.56619** | 11.29725 |

The damaged-producer fit wins five of six test windows against the old fit, but only three of eight validation windows. A lower held response error does not give a reliable NLL winner at this damaged-model quality level. No serving default or native executable changed. The next experiment should fit against gold or teacher *continuation* loss on more independent train windows, jointly changing gate/up/down codes and narrow V/O coordinates rather than spending another scale-only squared-error sweep. The equal-byte original-producer fit is a necessary control there.

`mlp_quantized_scale_fit.py capture` runs under Bonsai's GPU wrapper. Before loading the model, it durably saves its own exact producer bytes as `full-model/sources/<source_sha256>.py` and binds that path and hash in the capture receipt; if an existing snapshot differs, it aborts. `fit --train-rows 2048` is CPU-only. `evaluate --split test --start 56 --count 2` and the matching four-window test and two four-window validation calls reproduce the continuation. All data are in `/path/to/workspace/data/kelana-subbit/full-model/`: `mlp-quantized-producer-capture.npz` and its manifest, `mlp-quantized-scale-2048.json` and its three packed image NPZs, plus `mlp-quantized-scale-{test,validation}-*.json`. The receipts include source, model, input, image and token hashes and each window's NLL. The original capture's exact 9,628-byte producer is `sources/42eae1e97b1a5a609022f62df15770c6f9ffb10505e46dcbc7987c74ffa5883d.py`, recovered from the persisted Pi write at 2026-09-23 05:20:30Z in thread `e0f4d8ea-fec8-42ec-9c7d-2d46dee607f4` (JSONL line 38, entry `16907bc3`); SHA-256 equals the original receipt's source hash. The later evaluation edit at 05:21:28Z changed the producer script before commit `8241bb9`, so the current source is not the original capture producer. The receipt now points to the recovered exact snapshot without changing its capture or source hashes. GPU reservations restored the resident service after each call.
