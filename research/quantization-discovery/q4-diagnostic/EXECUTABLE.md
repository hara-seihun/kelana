# Executable Qwen3-0.6B affine image

The saved calibrated affine group-128 image now runs in upstream llama.cpp HIP on Radeon 8060S. `export_gguf.py` maps each original 128-code group to four Q4_1 groups, repeating the **exact FP16 scale and origin** four times and rearranging nibbles from adjacent-pair order to GGUF's low-16/high-16 order. All 197 tensor image hashes are checked; the GGUF decoder is compared element-for-element against each decoded research matrix. The output tensor is deliberately absent: llama.cpp ties the head to the quantized embedding just as the BF16 source does. All 113 norm tensors retain the source values, copied from the independently checked stock model. This is an exact *weight* image, not a bitwise-identical matrix arithmetic implementation.

The source's 316,749,352-byte tensor payload becomes 372,752,384 bytes in Q4_1, plus GGUF tokenizer/container overhead for a 378,704,000-byte file. This **56,003,032-byte** paid runtime expansion is the price of three redundant FP16 scale/origin pairs for every original 128 coefficients. Do not compare the native file's perplexity to the original research image's 316.75 MB as if they were an executable image of that size.

`export_gguf.py --format f16` also makes a fully expanded FP16 intermediate from the saved image. Upstream `llama-quantize --pure` then creates Q4_K and Q3_K secondary images. These are **lossy re-quantizations**, not exact Kelana images. `--format source-f16` makes a tied source-model control with the same metadata and tensor allocation for matched re-quantization. The external Bartowski images retain separately quantized output and embedding tensors and have a different allocation; actual file bytes, not the nominal GGUF type, govern comparisons.

## Full native perplexity panel

`llama-perplexity -c 512 -ngl 99 -fa on` over all 584 chunks of `/path/to/workspace/data/engine-shootout/corpus/wiki.test.raw`; the same upstream HIP binary at `84e76d8a23162eca70490da131945ebec1f09bf4`. Lower perplexity is better. Scores from the earlier 256-token BF16 HF panel are not numerically comparable to this contract.

| Image | GGUF bytes | Native PPL | Relation to Kelana image |
| --- | ---: | ---: | --- |
| Kelana calibrated exact Q4_1 | 378,704,000 | 25.4210 ± .22425 | Exact saved coefficients, scale/origin repeated four times |
| Kelana → pure Q4_K | 341,454,976 | 26.3772 ± .22868 | FP16 expansion followed by lossy Q4_K |
| Kelana → pure Q3_K | 262,300,800 | 59.9921 ± .60704 | FP16 expansion followed by lossy Q3_K |
| Stock Q4_K_M | 484,220,320 | 22.9438 ± .20117 | External imatrix quantization, duplicated head |
| Stock IQ4_XS | 450,456,992 | 23.7745 ± .20895 | External imatrix quantization, duplicated head |
| Stock Q3_K_S | 389,927,328 | 30.4647 ± .27330 | External imatrix quantization, duplicated head |
| Stock IQ3_XXS | 345,867,680 | 42.0381 ± .39002 | External imatrix quantization, duplicated head |
| Stock IQ2_M | 331,761,056 | 69.9511 ± .70049 | External imatrix quantization, duplicated head |
| Stock IQ3_M | 402,878,880 | 26.4931 ± .23112 | External imatrix quantization, duplicated head |
| Stock Q3_K_M | 413,979,040 | 25.7607 ± .22505 | External imatrix quantization, duplicated head |
| Stock Q3_K_L | 435,343,776 | 25.4119 ± .22247 | External imatrix quantization, duplicated head |
| Stock Q4_0 | 469,671,328 | 23.7392 ± .20535 | External quantization, duplicated head |
| BF16 source → pure tied Q4_1 | 378,704,000 | 27.5713 ± .24669 | Same allocation and bytes as Kelana Q4_1 |
| BF16 source → pure tied Q3_K + stock imatrix | 262,300,800 | 31.8092 ± .28637 | Matched imatrix/format/allocation control |
| Kelana → pure tied Q3_K + stock imatrix | 262,300,800 | 42.6399 ± .40278 | Loses matched quality control |

The exact Q4_1 image improves both native perplexity and file bytes against pinned stock IQ3_M and Q3_K_M, while stock Q4_K_M buys further quality at higher rate. The matched tied-head Q4_1 source control scores **27.5713** at exactly the same 378,704,000 bytes, so the Kelana saved affine grids and calibration contribute a **2.1503-perplexity improvement** beyond head deduplication. At three bits, the conclusion reverses: with Bartowski's actual pinned imatrix and identical pure Q3_K format, source BF16 scores **31.8092** versus Kelana re-quantized **42.6399** at exactly 262,300,800 bytes. Without the imatrix, the source control scores 37.2302 versus Kelana's 59.9921. The low-byte Q3_K result is dominated by a simple source quantization; do not credit it as a Kelana frontier result.

## Native speed, Radeon 8060S

The same HIP binary and identical GGUF settings (`-ngl 99 -fa on`) processed the fixed Qwen3 text for S1/S3. S4 uses the fixed **128 distinct Qwen3 token-ID prompts** and 128 greedy argmax steps per stream, in the checked `fixed-batched-bench.patch` reader. Its generated-token boundary includes the CPU logits transfer and top-1 selection; this differs from the earlier, faster synthetic-token `llama-batched-bench` result. The host shared its package power with other work; the coordinator's quiet sweep owns headline clock-normalized numbers.

| Image | S1 depth-0 decode tok/s | S1 depth-4096 decode tok/s | S3 512 prefill tok/s | S3 4096 prefill tok/s | S4 8-stream aggregate tok/s | S4 64-stream aggregate tok/s | S4 128-stream aggregate tok/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Kelana exact Q4_1 | 266.3 | 169.8 | 7556.5 | 7454.3 | 1211.3 | 2412.8 | 2584.5 |
| Stock IQ3_M | 258.8 | 163.4 | 6947.0 | 7452.7 | 1128.0 | 2362.6 | 2340.6 |
| Stock Q3_K_M | 259.8 | 163.8 | 7052.7 | 7272.0 | 1053.3 | 2364.8 | 2571.9 |
| Stock Q4_K_M | 256.9 | 162.7 | 4972.0 | 7084.0 | 1071.2 | 2323.8 | 2530.7 |

The occupied-depth prompt concatenates the prepublished 4096- and 128-token texts. The Qwen3 tokenizer yields 4224 IDs **identical to the two original ID arrays concatenated**, so the generation starts at the requested depth. Against stock IQ3_M and Q3_K_M, the executable exact image wins on native perplexity and bytes and was faster in these S1 and most S4 runs; the 128-stream Q3_K_M difference is only 0.5%. Do not extrapolate this single shared-host sweep into a speed dominance claim across every batch. S5 HTTP and Q2 KL were not measured.

## Reproduce and custody

From the Kelana checkout, run the exporter with the pinned stock GGUF and saved manifest:

```sh
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/q4-diagnostic
OUT=/path/to/workspace/data/engine-shootout/runners/kelana-06b
$PY "$D/export_gguf.py" --output "$OUT/calibrated-Q4_1.gguf"
$PY "$D/shootout.py" --model kelana-q4-exact --scenario q1
```

`batch_q1.py` and `batch_speed.py` run several arms within one bounded GPU reservation and write one receipt per arm with binary/image hashes, full argv, revision/dirty state, pre-run host/GPU load, raw stdout/stderr and parsed result. The exact image and intermediate GGUFs are under `runners/kelana-06b/`; the complete tested HIP binary plus libraries live in `runners/kelana-06b/native-bin/`. To rebuild it, take upstream llama.cpp at commit `84e76d8a23162eca70490da131945ebec1f09bf4`, apply `fixed-batched-bench.patch`, configure HIP with `CMAKE_HIP_ARCHITECTURES=gfx1151` using the [machine ROCm prefix](/path/to/workspace/machine/rocm.md), and build `llama-perplexity llama-cli llama-bench llama-batched-bench llama-quantize`. The patched batch CLI adds `--prompt-ids-dir PATH` and records `fixed_greedy=1` in JSONL. All raw measurements stay under `receipts/kelana-06b/M3/`. The seven additionally downloaded stock files and Bartowski's imatrix are pinned by immutable repository revision and LFS SHA through `stock_gguf.py`; their files and tensor censuses remain with the existing stock data owner.

The recovered ternary image still has no honest compressed native route: its signed Hadamard rotation changes the input coordinate for all 197 matrices, while upstream TQ1_0 supplies one scale per 256 values rather than its FP16 scale per 128. Expanding to dense BF16 would only benchmark a 16-bit model, not its 1.65-BPW paid image; no ternary compressed-token/s claim follows.
