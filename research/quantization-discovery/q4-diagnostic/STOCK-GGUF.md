# Stock GGUF comparison

On the same Qwen3-0.6B text and BF16 scoring backend, stock **Q4_K_M gets 40.824 test perplexity**, versus **44.514 for our calibrated four-bit image** and 38.062 for BF16. The stock image has better quality and a larger weight payload, 478.27 MB versus 316.75 MB. A stock image near our actual byte budget, IQ2_M at 325.81 MB, gets 124.351 perplexity.

These are measurements of the actual downloaded images. They are not a claim that our quantizer dominates GGUF formats generally. The stock near-size image allocates much of its budget to separately stored embedding and output matrices and uses lower-bit body tensors. Our image retains a single tied matrix. Both the allocation and quantizers differ.

The [native executable comparison](EXECUTABLE.md) adds seven pinned stock
formats and the published imatrix for matched re-quantization controls. Those
full wikitext-2 512-token chunk scores use llama.cpp HIP and are a distinct
panel from the 256-token BF16 HF numbers below. `stock_gguf.py` derives file
names, sizes and LFS SHA-256 values from the saved repository inventory pinned
to the exact revision, including its `Qwen_Qwen3-0.6B.imatrix` file.

## Pinned source and rates

The stock source is [bartowski/Qwen_Qwen3-0.6B-GGUF](https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF), revision `60b85c0e3d8fe0f6474f406922a26d12aca4550d`. The model card identifies Qwen/Qwen3-0.6B as the base and imatrix quantization. GGUF metadata names `/training_dir/calibration_datav3.txt`, 196 imatrix entries and 137 chunks. We downloaded the recommended conventional Q4_K_M and IQ2_M, the published file nearest our calibrated image's byte budget in this repository. No stock codes or scales were fitted to our text.

| Image | Tensor payload bytes | Full GGUF file bytes | Payload bits per source-unique parameter | Bits per stored coefficient |
| --- | ---: | ---: | ---: | ---: |
| Our calibrated affine four-bit | 316,749,352 | Not a GGUF | 4.25131 | 4.25131 |
| Stock Q4_K_M | 478,268,416 | 484,220,320 | 6.41917 | 5.09045 |
| Stock IQ2_M | 325,809,152 | 331,761,056 | 4.37291 | 3.46775 |

The source model has 596,049,920 unique parameters. Each stock GGUF stores 751,632,384 coefficients because the 155,582,464-element embedding/head matrix appears twice. The two stored copies use different quantizers and cannot be deduplicated without changing the model. Q4_K_M uses Q4_K for the input embedding and Q6_K for the output. IQ2_M uses IQ3_S for the embedding and Q5_K for the output. The stock files also retain norms as F32 rather than BF16. We charge all of these bytes.

The last column uses the GGUF's stored coefficient count, while the preceding column divides by the original model's unique parameter count, the denominator used for our images. Giving both prevents a nominal quantization label or a changed denominator from masquerading as equal storage. Each stock container adds 5,951,904 bytes of tokenizer metadata, tensor directory and alignment beyond the weight payload. The comparison's payload column excludes container overhead for both our NPZ images and the GGUF.

Q4_K_M spends 127,626,240 bytes on the output and 87,515,136 on the embedding. Its remaining tensors include Q4_K and Q6_K body matrices. IQ2_M spends 106,962,944 and 66,851,840 respectively, leaving a much lower-rate body. Stock Q4_K_M therefore costs about 51% more weight bytes than our image. IQ2_M costs about 2.86% more, but is not a four-bit-body control.

## Matched quality

| Image | Validation NLL | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: |
| Original BF16 | 3.668815 | 3.639218 | 38.062 |
| Our calibrated four-bit | 3.851346 | 3.795795 | 44.514 |
| Stock Q4_K_M | 3.724224 | 3.709265 | 40.824 |
| Stock IQ2_M | 5.032208 | 4.823108 | 124.351 |

Validation uses the same eight 256-token windows, 2,040 predictions. Test uses the same 32 windows, 8,160 predictions. [evaluate_gguf.py](evaluate_gguf.py) verifies all 151,669 named tokenizer IDs against our local tokenizer and checks all 113 unquantized norm tensors exactly against the pinned BF16 checkpoint. It checks model dimensions, GQA heads, RoPE base and RMSNorm epsilon, maps every tensor once, and records representative Q/K/MLP weight discrepancies to expose a layout mismatch.

The evaluator decodes the actual GGUF tensors with llama.cpp's `gguf-py` decoder, copies them into the same BF16 HF SDPA model used for our images, and preserves the stock GGUF's separate output matrix. Forcing HF's original tie would discard a stock tensor and produce a different model. Every parameter is covered; there is no uncompressed body hidden behind the GGUF arm.

This isolates quantized-weight quality under the same arithmetic, token IDs, context and loss convention. It is **not native llama.cpp perplexity or a speed measurement**. Native GGUF kernels can use different activation quantization and reduction arithmetic. The package-power/clock panels are not used to claim speed. All GPU panels went through the shared wrapper and restored resident Bonsai.

## Source, receipts and reproduction

[stock-results.json](stock-results.json) retains the source revision, tensor census, quantizer byte totals, imatrix metadata and hashed loss receipts. Full files, repository listing, pinned source card and per-window results live in `/path/to/workspace/data/kelana-subbit/q4-diagnostic/stock-gguf/`.

- Q4_K_M SHA256: `9acfc1e001311f34b4252001b626f2e466d592a42065f66571bff3790d4e1b14`.
- IQ2_M SHA256: `d129244d6f5285594084390f05ca5c3f7d194fd82f9d63f76c47e64725cf3b07`.

`stock_gguf.py` acquires pinned immutable files with upstream size and SHA checks, resumes partial downloads and records actual tensor payloads. `--gguf-source` defaults to the maintained HIP llama.cpp source at `/path/to/workspace/work/clones/bonsai-hip/gguf-py`; it can point at another checkout, with decoder hashes recorded. The measured `quants.py` hash is `2c927a1b3d9f0920dcf4007fb686e1b0999333e9f65ce43dcc689900c0beae8b`.

```bash
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/q4-diagnostic
OPENBLAS_NUM_THREADS=1 "$PY" "$D/stock_gguf.py" --name Q4_K_M
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2 /path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 55s --memory-gib 20 --host-reserve-gib 4 --exec "$PY" "$PWD/$D/evaluate_gguf.py" --name Q4_K_M --split test --windows 32
```

The evaluator rejects an existing receipt. Retain the published panel and use `--label FRESH_NAME` for an independent repetition rather than deleting evidence. Acquisition reuses an already verified file. The stock model is not installed as a service.
