# Fresh loss changes the value-rank decision

The 192-coordinate, .466797-BPW shared V/O image selected by train causal squared error beats a refitted uniform rank-24 image on every one of twelve fresh layer-0 test windows. It does **not** beat it on mean fresh validation NLL. One validation window reverses the aggregate: selected NLL 9.49308 against uniform 5.32291. An independent run reproduced those numbers. This is a real loss tail, not a claim that all train-selected rank allocations fail. Layer 14 has no meaningful fresh NLL separation at this sample size.

Both 192-coordinate images were frozen before these windows were chosen. Each was trained for two left-code/scale sweeps on original-producer causal outputs. The selected ranks are 28,28,28,28,28,4,28,20 at layer 0 and 28,28,28,8,28,16,28,28 at layer 14. The equal-rate uniform image retains 24 in every group. The full rank-28, 224-coordinate joint image is a higher-rate context, not an equal-rate control.

| Single replaced V/O layer, fresh 256-token windows | Reference NLL | Uniform 192 NLL | Selected 192 NLL | Full 224 NLL | Selected minus uniform NLL, paired 95% interval | Selected minus uniform teacher KL |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0, test, 12 windows | 3.67308 | 5.46697 | **5.21125** | 5.15425 | -.25572 [-.34023, -.18744], 12/12 better | -.28372 |
| 0, validation, 8 windows | 3.53745 | 5.79216 | 6.05061 | **5.03494** | +.25845 [-.33279, +1.39014], 7/8 better | +.22433 |
| 14, test, 8 windows | 3.64353 | 3.65297 | 3.65465 | 3.65785 | +.00168 [-.00689, +.00998], 3/8 better | -.00023 |
| 14, validation, 8 windows | 3.53745 | 3.55300 | 3.54960 | 3.55270 | -.00340 [-.01005, +.00343], 5/8 better | -.00084 |

The 95% intervals resample entire paired windows with 10,000 seeded draws. Layer-0 test has 3,060 predictions; each other panel has 2,040. The eight fresh validation windows are not the four earlier pilot validation windows. Window 0 alone contributes +4.17017 nats/token to the layer-0 selected-minus-uniform validation difference; the other seven favor selected. Window 5 is also hard for both pruned images (8.75260 uniform, 8.42758 selected), where the full rank-28 image scores 4.56639. The selected rank-4 group at layer 0 is a plausible source of fragile behavior, but this panel does not isolate group causality. No text-window choice or image selection was made using these results.

The actual Qwen3-0.6B model is forwarded with one V/O layer replaced and every other matrix, including that layer's Q/K, original BF16. Paid factors expand into BF16 weights for the common HF quality evaluator. This is neither a direct narrow-cache timing nor a simultaneously quantized-producer result. Each selected and uniform image stores 183,552 parameter bytes over 3,145,728 original V/O weights, with the same 589,824 factor terms and 384 logical BF16 value-cache bytes per token. The full-rank image stores 208,640 bytes, 688,128 terms and 448 value-cache bytes. A BF16 original V/O layer stores 6,291,456 bytes. The single-layer whole-model paid rate is in each raw record, including all untouched BF16 parameters.

The result changes the next optimization question. Mean original-producer post-O error selected the low-rate image on both previous layers, yet its layer-0 language loss has a severe fresh tail. Test a train objective that limits per-window or per-token excess gold loss, and fit a new right basis using *quantized-producer* captures; retain the full-rank and uniform images as explicit controls. Diagnose the rank-4 group by a paid equal-rate group exchange on train inputs, then evaluate on new text rather than optimizing this validation window. At layer 14, a stronger objective needs a larger sample to resolve millinat differences. A native consumer is premature while the quality ranking is unstable.

`evaluate_fresh.py` uses the frozen, disjoint [fresh fixture](../fresh-evaluation/README.md), checks its manifest hash, checks both selected image hashes against their original fit receipts, records model/source/image/token hashes and writes every window's NLL, teacher KL and argmax agreement. The raw records are `/path/to/workspace/data/kelana-subbit/value-observer/fresh-layer{00,14}-{test,validation}-*.json`; the layer-0 validation-window-0 repeat lives beside them. [`fresh-loss-results.json`](fresh-loss-results.json) binds every included raw receipt hash and keeps the paired scores. `summarize_fresh.py` regenerates that compact result. All model forwards ran under Bonsai's GPU reservation; it restored the resident service. No Bonsai executable or serving map changed.

From Kelana, a bounded panel is:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
D=research/quantization-discovery/subbit/value-observer
OPENBLAS_NUM_THREADS=1 "$B" --runtime-max 46s --exec "$P" "$D/evaluate_fresh.py" \
  --layer 0 --split test --start 0 --count 4 \
  --out /path/to/workspace/data/kelana-subbit/value-observer/fresh-layer00-test-000-003.json
"$P" "$D/summarize_fresh.py"
```

The four included panels use test indices 0..11 and validation 0..7 at layer 0, test and validation 0..7 at layer 14. The repeat is independent evidence, not counted twice. The fixture provides 64 fresh test and 32 fresh validation windows, so this study is a bounded sample rather than its exhaustive use.
