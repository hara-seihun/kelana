# Layer-0 V/O and MLP interact inside the quantized prefix

Restoring the first layer's MLP alone barely helps this damaged model. Restoring its V/O alongside the MLP does. On eight validation windows, the binary prefix scores 12.743 NLL, original MLP alone 11.907, frozen narrow V/O alone 11.465, and their combination 8.819. The combined gain is 1.810 nats larger than the sum of the separate gains. This is the first paired continuation panel for the proposed coupled fit; it shows why separate projection rankings misallocate the next layer-0 training budget.

All arms use the same refined binary layers 0–13 and their stored norms, original layers 14–27 and original tied embedding/head. We replace only layer-0 modules. The narrow arm reuses the *frozen* shared rank-28, two-bit V/O image, without retraining. Original MLP and V/O are BF16 diagnostic exceptions, not proposed compressed solutions. The evaluator expands the stored binary and narrow images to BF16 for teacher-forced gold NLL, and does not measure native inference. Each window has 255 predictions. The test six-window subset is indices 56–61, validation eight-window subset 24–31. These fixtures were inspected in earlier work, so this panel diagnoses a mechanism rather than supplying blind selection evidence.

| Layer-0 V/O, MLP | Test NLL, 6 | Validation NLL, 8 | Added payload bytes vs binary | Added whole-model BPW |
| --- | ---: | ---: | ---: | ---: |
| Binary, binary | 12.975 | 12.743 | 0 | 0 |
| Narrow rank 28, binary | 12.149 | 11.465 | −2,328 | −.000031 |
| Binary, original | 12.640 | 11.907 | 18,259,932 | .245079 |
| Narrow rank 28, original | 10.579 | 8.819 | 18,257,604 | .245048 |
| Original, original | 6.804 | 7.746 | 24,340,420 | .326690 |
| Original whole layer 0 | 6.707 | 7.667 | 30,420,908 | .408300 |

The interaction `L(binary,binary) + L(narrow,original) − L(narrow,binary) − L(binary,original)` is −1.235 nats on test and −1.810 on validation. Negative means the joint loss reduction exceeds the additive prediction. It is negative on five of six test and six of eight validation windows. The rank-28 narrow image still trails original V/O by 3.775 test and 1.072 validation nats *when both use original MLP*. In other words, the best V/O representation under the binary MLP need not be the best one once MLP behavior is repaired.

With V/O and MLP original but Q/K binary, test NLL is only .097 above original whole layer 0; validation differs by .080. That comparison saves 6,080,488 bytes, .081610 whole-model BPW, against restoring all of layer 0. It does not establish that Q/K are universally dispensable: the observation includes the damaged later prefix and a specific text fixture. The BF16 MLP alone costs .245079 whole-model BPW over binary, so merely keeping exact MLP is not a sub-bit solution. The next construction should fit a **compressed coupled V/O-to-MLP layer-0 map** against post-MLP or gold continuation with the upstream tied embedding and later quantized layers present. In particular, refit the V/O right coordinates after choosing the MLP image; do not simply bolt the frozen rank-28 V/O onto an independent MLP repair. Q/K precision is a secondary budget candidate at this observed boundary. Evaluate the joint image at its paid rate and with a consumer carrying narrow value coordinates through attention.

`coupled_substitution.py` reproduces the six arms. Per-window gold NLL, exact source and image SHA-256, fixture tokens, weights and payload accounting are in `/path/to/workspace/data/kelana-subbit/full-model/coupled-{test-56-57,test-58-61,validation-24-27,validation-28-31}.json`. For example, from Bonsai's root:

```sh
tools/run-batch-compare --runtime-max 44s --exec /path/to/workspace/data/fish-s2-pro/venv/bin/python /path/to/workspace/projects/kelana/research/quantization-discovery/subbit/full-model/coupled_substitution.py --split validation --start 24 --count 4 --out /path/to/workspace/data/kelana-subbit/full-model/coupled-validation-24-27.json
```

All panels used the exclusive GPU wrapper; it restored the active resident service. Source revision and server defaults were not changed.
