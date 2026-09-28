# Where the refined binary prefix breaks language loss

The layer-14 narrow-value experiment had an NLL near 13 even with original layer-14 V/O. We located the damage before refitting another late observer. On 20 contiguous 256-token WikiText test windows, indices 32–51 of the pinned fresh-evaluation fixture, restoring **only layer 0** of the first fourteen quantized layers reduces gold NLL from 13.10 to 7.63 on the sixteen windows where that arm was measured. All sixteen improve. Layer 0 alone, with every other layer original, already raises NLL from 3.68 to 8.91 on the twenty-window panel. The first layer is a much better composed-map target than layer 14.

This is a causal *substitution* experiment, not a decomposition of additive layer errors. Each arm replays the full model with the same original tied embedding/head and layers 14–27. The selected layers among 0–13 use the refined .55-bit binary body and its stored norm values; all other parameters are original. HF executes expanded BF16 weights, so no number below is native inference time. Each window has 255 teacher-forced gold targets. Mean NLL gives every window equal weight.

| Substitution | Windows | NLL | Gain against quantized layers 0–13 | Windows improved |
| --- | ---: | ---: | ---: | ---: |
| All original | 20 | 3.677 | 9.421 | 20/20 |
| Quantize layer 0 only | 20 | 8.907 | 4.191 | 20/20 |
| Quantize layers 0–1 | 20 | 9.415 | 3.683 | 20/20 |
| Quantize layers 0–3 | 20 | 12.315 | 0.783 | 16/20 |
| Quantize layers 0–7 | 20 | 14.300 | −1.202 | 2/20 |
| Quantize layers 0–13 | 20 | 13.098 | 0 | 0/20 |
| Restore original layers 0–1 in the quantized prefix | 20 | 6.916 | 6.183 | 20/20 |
| Restore original layers 2–3 | 20 | 12.494 | 0.604 | 15/20 |
| Restore original layers 4–7 | 20 | 12.678 | 0.420 | 15/20 |
| Restore original layers 8–13 | 20 | 14.300 | −1.202 | 2/20 |
| Restore original layer 0 alone | 16 | 7.626 | 5.388 | 16/16 |
| Restore original layer 1 alone | 16 | 13.286 | −0.273 | 4/16 |

Restoring layers 8–13 makes this prefix worse, exactly the loss of the prefix-8 arm. Later quantized layers can partly compensate earlier damage; a sum of per-layer errors would miss that interaction. The first two layers account for most of the *repair opportunity* under this frozen rest-of-model contract, not a universal fraction of model error.

We split the layer-0 repair on eight of those windows, indices 44–51. Restoring its original V/O matrices gives 11.298 NLL, a 1.736 gain over the paired 13.034 quantized-prefix mean, improving seven of eight. Restoring Q/K alone gains only 0.038; restoring all layer-0 attention including Q/K and Q/K norms gains 1.676; restoring its three MLP matrices gains 0.460. Restoring the **whole** layer 0 on those eight gives a 5.394 gain. The joint gain is larger than the separate repairs, so fitting a composed layer-0 residual or attention-plus-MLP continuation is more promising than ranking single matrices by their individual error. These subgroup arms retain every other quantized layer and the original tied endpoints. The norm arrays were included in the selected layer as stored, without charging a difference when their original and stored bits coincide.

## Rate and next construction

The seven layer-0 binary matrices occupy 1,036,372 payload bytes against 31,457,280 original BF16 bytes. Making that layer exact adds 30,420,908 bytes, or 0.40830 BPW across 596,049,920 unique model parameters. Applied to the complete .62454-BPW image, the *rate alone* would become 1.03284 BPW. This is not a complete-model quality claim: this diagnostic deliberately kept the tied image and later body original. Exact layer-0 restoration is therefore a useful upper-quality diagnostic but a poor sub-bit allocation. V/O alone would add 6,080,488 bytes, 0.08161 complete-model BPW, for an incomplete 1.736-nat local repair. The next experiment should learn a **paid layer-0 composed image** against its attention and post-MLP outputs on quantized-producer activations, then evaluate that image with the rest of the binary body and shared tied endpoint propagated. Use original layer-0 behavior as a teacher, with held gold loss deciding whether the retained coordinate is useful. The existing layer-0 shared narrow V/O basis is a candidate, but its original-producer one-layer gain is not proof it survives the quantized continuation.

`prefix_ablation.py` reproduces the substitutions. Raw per-window scores and fixture, model, image, source and norm hashes are in `/path/to/workspace/data/kelana-subbit/full-model/prefix-ablation-test-{32-35,36-39,40-43,44-47,48-51}.json`. The first file predates the two singleton and module arms, and the first three predate the module arms; their shared arms retain the same definitions. These windows are disjoint from the preceding layer-14 right-model panel's test indices 0–31, though the pinned fixture has served other studies. The script records no kernel latency, and no runtime or serving default changed. Each GPU panel ran under Bonsai's measurement wrapper and restored the resident service.

Reproduction, in four-window bounded panels from the Bonsai repository:

```sh
tools/run-batch-compare --exec /path/to/workspace/data/fish-s2-pro/venv/bin/python /path/to/workspace/projects/kelana/research/quantization-discovery/subbit/full-model/prefix_ablation.py --start 44 --count 4 --out /path/to/workspace/data/kelana-subbit/full-model/prefix-ablation-test-44-47.json
```
