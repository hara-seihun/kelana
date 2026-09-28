# Fresh loss after relearning the layer-14 value basis

The new right basis [lowered held layer-14 causal post-O error](RIGHT-TRANSFER.md) on four quantized-producer validation windows. I froze both new 192-coordinate images and the old-right, producer-refitted controls before evaluating 32 disjoint 256-token WikiText test windows. Layers 0 through 13 use the existing refined binary body and norms; the embedding, layer-14 Q/K, all later layers and the head remain original. Only layer-14 V/O changes within each window. All four packed V/O arms cost 183,552 bytes, .466797 BPW over those weights. The evaluator expands them to BF16 for language quality, not native timing.

| Layer-14 V/O on the same damaged producer | Gold NLL, 8,160 predictions | Teacher KL against original V/O on that producer |
| --- | ---: | ---: |
| Original V/O | 12.95867 | 0 |
| Old right basis, selected ranks, producer-refitted left | 13.15100 | 1.54852 |
| Old right basis, uniform rank 24, producer-refitted left | 13.16966 | 1.57591 |
| New right basis, selected ranks | **12.99620** | **1.21313** |
| New right basis, uniform rank 24 | 13.13847 | 1.25265 |

The new selected image lowers mean NLL by .15479 nat/token against its old-right matched-rate control, but wins only 16 of 32 windows. A window bootstrap with seed 20260922 and 100,000 resamples gives a paired 95% interval of [-.34260, +.03085]. The new uniform image changes NLL by -.03120 against its old-right control, 17 of 32 windows, interval [-.22949, +.17199]. Selected beats new uniform by .14226 mean, 22 of 32 windows, interval [-.27947, -.00067]. These exploratory intervals do not erase window heterogeneity, and they do not establish a broadly useful rank allocation. New selected differs from original V/O by +.03753, interval [-.09385, +.16905].

The important negative is upstream. The *original* layer-14 V/O scores 12.95867 after just the first fourteen layers' body/norm replacement. On the same first eight fresh windows, it scores 12.55379 versus 3.64353 for the all-original model in the existing fresh single-layer panel. No choice among these four layer-14 value images repairs the already-broken prefix. Lowering a local post-O response error from .48436 to .33655 is real, but does not make the composed model a useful language model. The next fit should target the earliest damaged producer region with held gold/teacher loss, or repair the complete binary prefix first, then revisit narrow V/O with a producer whose language behavior survives. A native narrow-cache implementation on this prefix would be premature.

The exact contract is BF16 Hugging Face SDPA, TF32 disabled, 255 teacher-forced predictions per fresh window. The teacher KL uses original V/O under the **same quantized upstream**; it is not KL against the original model. The quantized upstream uses the same image application as `producer_transfer.py capture`, with source SHA256, per-tensor image SHA256 and norms recorded in each receipt. Every panel records model, fixture, frozen V/O image, source and token-window hashes. The 32 per-window records are `right-model-test-{000,001-004,005-012,013-020,021-028,029-031}.json` in `/path/to/workspace/data/kelana-subbit/value-observer/`. The [data map](/path/to/workspace/data/kelana-subbit/README.md) owns those files. Regenerate in bounded panels from the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-observer/evaluate_right_model.py
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 48s --exec "$P" "$D" --split test --start 5 --count 8 --out /path/to/workspace/data/kelana-subbit/value-observer/right-model-test-005-012.json
```

The GPU wrapper restored the resident service after every panel. No Bonsai runtime or serving default changed.
