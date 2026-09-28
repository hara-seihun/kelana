# First whole-model pilot

The first experiment loads the complete pinned Qwen3-0.6B model and measures fixed WikiText-2 raw windows through all 28 layers. It also supplies real activation matrices for the [binary-factor comparator](binary-factors/README.md) and response-codebook research.

The loaded model has 596,049,920 unique parameters. Its embedding and head share 155,582,464 parameters, 26.10% of the total. The source safetensors stores both names; the rate calculation does not count that tied storage twice.

## Loss observations

The pilot samples eight train windows and four each from validation and test, all 256 tokens. The test loss covers 1,020 predicted tokens. Train captures provide 2,048 vectors per selected projection; validation provides 1,024. These are fixed-window pilot losses, not full-corpus perplexities. [pilot-results.json](pilot-results.json) retains the starts, per-window losses and raw receipt paths.

| Representation | Logical bits / unique parameter | Validation NLL | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: | ---: |
| BF16 reference | 16.0000 | 3.9052 | 3.3108 | 27.406 |
| Group-128 four-bit mid-rise nearest rounding | 4.1263 | 4.9262 | 4.2423 | 69.570 |
| Signed Walsh-8 atom labels, shared group scale | 0.6267 | 14.4931 | 14.6257 | 2,248,317 |

Every matrix, including the tied embedding/head, receives the indicated quantizer. One-dimensional tensors stay BF16. The four-bit control has sixteen uniformly spaced half-integer levels and a per-128 FP16 scale. It is an inexpensive local rounding control, not GPTQ, AWQ or a strong competitor that would justify a superiority claim.

The Walsh construction chooses the best signed Hadamard row for each eight-weight vector and one least-squares FP16 scale per 128 weights. Its label costs four bits for eight weights; scale overhead adds 0.125 bits/weight. Unquantized norms bring the complete logical rate to 0.6267. A consumer can prepare eight Walsh responses in 24 additions/subtractions per input group, then use a three-bit index and sign per vector. There is no need to reconstruct an int4 matrix. However, that cheap response family destroys the model's language behavior. Neither a native kernel nor a larger sweep of the same isotropic atoms is justified by this result.

The rate column counts logical codes, scales and every unique parameter. This pilot does not serialize the candidate images, so container and layout overhead have no measured file-size claim. The quantized matrices are expanded to BF16 for quality evaluation. No timing from this script represents compressed inference.

## What changes next

The result distinguishes a cheap hardware map from a useful quantizer. The next constructions learn activation-sensitive response geometry and allocate limited exceptions, or use binary-factor compositions. They are compared on the same captured inputs against the pinned ADMM-only NanoQuant adaptation. That comparator already has nine rate/distortion points over early and late attention and a middle-layer FFN; they are isolated-layer results, not model perplexities.

A model-level trial needs a competitive layer construction, then sequential or block reconstruction and a separate training-budget axis. The tied embedding/head needs its own low-rate strategy; keeping it BF16 would erase the whole-model sub-bit claim. Weight error, real activation response error and final token loss remain separate measurements so we can learn where the surrogate stops predicting model quality.

## Run the pilot

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=research/quantization-discovery/subbit/pilot.py
$B --runtime-max 50s --exec "$P" "$S" --mode reference --capture
$B --runtime-max 50s --exec "$P" "$S" --mode rtn4
$B --runtime-max 50s --exec "$P" "$S" --mode walsh8
```

Run from the Kelana root with an outer timeout that includes reservation and service restoration. The first complete capture fits its 50-second payload allowance. `models.py` owns the pinned inputs and corpus conversion. The data map at `/path/to/workspace/data/kelana-subbit/README.md` owns downloads, sixteen projection fixtures and raw run receipts. CPU/GPU clock panels showed host activity during these runs; only quality, not throughput, is reported.
