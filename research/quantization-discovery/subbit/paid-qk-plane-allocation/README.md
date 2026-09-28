# Reassign the paid Q/K planes before refitting their consumer

The preceding paid Q/K fit adjusted only the selected key affine. Its 112 RoPE planes had been selected on *original* Q/K. I kept both actual binary Q/K images and each group's plane count frozen, exchanged planes on the paid-producer finite causal score, then fitted the already-paid BF16 group key affine again. The layer-14 held teacher-to-candidate attention KL falls from **.421567 to .338360** at the same 448-byte affine, 224 logical key coordinates and 448 score products per key across both heads. Layer 0 falls from .263541 to .260143. No int4 expansion is part of the proposed consumer, though this experiment expands the binary images to BF16 to assess quality on CPU.

| Layer | Previous folded paid fit | Exchanged mask with unit gains | New FP16 post-gain diagnostic | New BF16 folded affine | Full paid Q/K, all planes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .263541 | .275786 | .260116 | **.260143** | .162115 |
| 14 | .421567 | .432085 | .338585 | **.338360** | .288208 |

On the four previously inspected held windows, the new folded layer-14 scores are `[.325117, .343474, .323470, .361381]`, versus `[.431019, .410846, .414724, .429678]` for the previous folded image. All four improve. Layer 0's new scores are `[.265307, .274652, .246860, .253752]` against `[.264675, .284793, .249116, .255581]`; the first worsens slightly. The full paid control uses 1,024 logical K coordinates and 2,048 score products/key, so it is a quality ceiling at a different cost, not an equal-price competitor.

For each GQA group, both observing Q heads contribute to a sampled-train objective `mean_q [logsumexp_k(s_qk) - E_teacher(s_qk)]`. Sixteen strided causal queries per 256-token train window across eight windows use every preceding key. At most five downhill exchanges, with 16 gradient-shortlisted remove/add candidates per step, minimize the exact finite objective for unit plane gains. The selected mask retains the original group's cardinality. Next, bounded L-BFGS-B fits nonnegative gains between .25 and 4 with ridge .002, and the gains round to FP16 before multiplying the old affine and rounding into its existing BF16 table. Four separate held windows score *every* causal row and both heads. The exchange search is neither exhaustive nor globally optimal. It optimizes the sampled train score, not held KL. The previous folded control is taken from the hashed preceding receipt; the script also recomputes its unit and FP16 post-gain controls on exactly these paid projections.

The difference between the mask-only and refitted results matters. Changing the selected coordinates alone gives .432085 at layer 14, while refitting their consumer reaches .338360. The previously learned original-producer mask is the wrong coordinate system for paid projections. Yet these are still original-producer hidden captures with frozen binary Q/K, full raw 128-row K norm denominator and already inspected text. There is no quantized-upstream gold loss, new paid selected-row projection, native latency or whole-model claim. Before implementing the sparse score path, train selected-row binary Q/K and its norm under the quantized upstream, then freeze on disjoint text and compare an equally charged full-score binary control. In particular, a 224-coordinate cache is not a 224-row K producer while RMSNorm still requires all raw rows.

`measure.py` and `/path/to/workspace/data/kelana-subbit/paid-qk-plane-allocation/layer{00,14}.json` retain masks, every accepted exchange, per-group train losses, fitted gains, the exact BF16 tables, four individual held KLs, cost counts and source/model/capture/paid-image/previous-receipt hashes. Run each CPU panel from the Kelana root in under a minute:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/paid-qk-plane-allocation
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 0 --output /path/to/workspace/data/kelana-subbit/paid-qk-plane-allocation/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --output /path/to/workspace/data/kelana-subbit/paid-qk-plane-allocation/layer14.json
```

No GPU lock, Bonsai executable or service changed.
