# Two paid four-bit regions inside the ternary model

Replacing one independently calibrated seven-layer region with scalar four-bit weights had made the selected Qwen3-0.6B ternary model worse on the eight-window validation panel. Is the failure repaired when two regions change together, letting their boundary activations come from the same four-bit family? We measured the adjacent 7–13 plus 14–20 pair and the separated 0–6 plus 14–20 pair. The latter tests whether the answer depends on adjacency.

`mixed-interaction.py` starts from the complete `expanded-scale384` packed image, checks all 197 ternary matrix hashes and the scalar image hashes, substitutes both regions at once, and scores the entire model on the same frozen validation windows as the earlier singleton experiment. The tied head stays ternary. Each pair substitutes 98 matrices. Its paid payload is **194,721,353 bytes, 2.613491 BPW**, against 128,678,649 bytes and 1.727086 BPW for the ternary image. The 66,042,704 extra bytes are exactly twice the previous singleton increment. Forward execution expands weights to BF16 and does not measure native packed inference.

| Four-bit layer groups | Payload BPW | Validation NLL | Delta from ternary | Interaction above additive singleton deltas | Windows worse than ternary |
| --- | ---: | ---: | ---: | ---: | ---: |
| none | 1.727086 | 4.733112 | 0 | 0 | 0/8 |
| 7–13 only | 2.170288 | 4.786242 | +.053131 | | 8/8 |
| 14–20 only | 2.170288 | 4.772191 | +.039079 | | 5/8 |
| 0–6 only | 2.170288 | 4.826601 | +.093489 | | 7/8 |
| 7–13 and 14–20 | 2.613491 | **4.836586** | +.103474 | **+.011264** | 6/8 |
| 0–6 and 14–20 | 2.613491 | **4.908159** | +.175047 | **+.042479** | 8/8 |

The interaction is `NLL(pair) - NLL(first singleton) - NLL(second singleton) + NLL(ternary)`, computed on matching windows, not an independent-matrix response fit. It is positive on 5/8 and 6/8 windows respectively; individual-window interaction spans −.09476 to +.10972 for the adjacent pair and −.09444 to +.14395 for the separated pair. The aggregate is a concrete nonadditivity measurement, not a monotonicity theorem. The observed pairs do not rescue the singleton failures, even after paying another .4432 BPW. Do not extrapolate the complete four-bit model's quality gain by summing independently substituted region gains, and do not spend native-kernel time on either mixed image.

The existing ternary scales were trained through the ternary complete model; the scalar-four-bit regions were fitted separately. Both pairs retain ternary scales outside their substitutions. The next useful quality experiment retrains those retained scales *with a fixed paid mixed image*, with a new train split and fresh held selection. That tests co-adaptation, which this substitution deliberately omits. A separate converter diagnosis may identify a stronger four-bit starting image; these receipts do not rule it out. The previously inspected validation panel selected these two diagnostic pairs; it is not a fresh blind quality result. The 32-window test panel was not spent on losing validation candidates.

The full per-window losses and image/model/source hashes are in `/path/to/workspace/data/kelana-subbit/ternary/quality/mixed-interaction-validation-0-8-1-2.json` and `mixed-interaction-validation-0-8-0-2.json`; singleton controls are the two `layer-rate-validation-8-*.json` receipts in the same directory. Both GPU calls used Bonsai's exclusive `tools/run-batch-compare` wrapper with a 47-second payload bound, 24 GiB process memory and 4 GiB host reserve. The wrapper restored the resident service after each call. No serving image, engine or selected ternary image changed.

Run each pair with the registered writer checkout's absolute script path, since the wrapper sets its own working directory:

```sh
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=/path/to/workspace/projects/kelana/research/ternary/mixed-interaction.py
$B --runtime-max 47s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S" --groups 1,2 --split validation --windows 8
$B --runtime-max 47s --memory-gib 24 --host-reserve-gib 4 --exec "$P" "$S" --groups 0,2 --split validation --windows 8
```

The script refuses to overwrite retained receipts. Choose a new output identity when rerunning a changed method.
