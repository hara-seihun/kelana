# The tied Qwen head and input embedding below one bit

Qwen3-0.6B has 596,049,920 unique parameters. Its 151,936-by-1,024 embedding and output head are bitwise identical BF16 tensors and account for 155,582,464 of them, 26.10%. Keeping that shared matrix at BF16 would defeat a whole-model sub-bit goal. This study asks whether one packed image can give a useful input embedding and an approximate final-head score without expanding the entire matrix. It does not modify the model.

The answer is mixed. A model-specific 0.8953-bit image beats plain group-128 scalar RTN2 at 2.125 bits on this head sample, but still raises next-token NLL by 0.819 nats relative to the unquantized model and leaves substantial input-embedding error. Its direct-consumer program is clear enough to price. The quality is not ready for a whole-model trial.

## Actual inputs, distinct selection data

[`capture.py`](capture.py) ran the pinned BF16 Qwen3-0.6B revision `c1899de289a04d12100db370d81485cdf75e47ca` through Bonsai's bounded GPU wrapper. A pre-head hook saved the **final normalized input** from four separate 256-token WikiText-2 raw train windows and two validation windows. It retained every normalized input, plus all 151,936 actual BF16-model head logits on 64 fixed validation positions, their next-token labels, and model NLL. The selected reference NLL is **3.61026** over those 64 positions. This is a smaller selection than the [whole-model pilot](../PILOT.md), not its full 1,020-prediction validation loss. The wrapper restored the resident service. The source weights, capture script, model revision, token fixture, array hashes, PyTorch/HIP versions and device are in [`capture.json`](/path/to/workspace/data/kelana-subbit/tied-head/capture.json).

[`frequency.py`](frequency.py) tokenized the *entire* pinned WikiText raw train text, 2,518,423 tokens, to rank vocabulary rows for exact retention. Its separate validation text has 262,337 tokens and is used only to evaluate embedding error and token coverage. Model-specific dictionaries, head correction and row selection use training weights and train final inputs; validation inputs and logits never fit the representations. Test text is untouched. The frequency receipt and arrays live at [`frequency.json`](/path/to/workspace/data/kelana-subbit/tied-head/frequency.json) and [`frequency.npz`](/path/to/workspace/data/kelana-subbit/tied-head/frequency.npz).

The head NLL, categorical `KL(original || candidate)`, and top-token agreement below use fixed *original-model* final hidden inputs. The candidate input embeddings are not fed back through the 28 layers. The row-weighted embedding RMS uses actual token counts from the held validation corpus, not Gaussian proxies. These are useful separate head and input boundaries, not whole-model perplexity.

## A shared image, two consumers

`fit.py` learns one 16-coordinate, K64 or K256 signed-byte codebook. It fits 8,192 weight vectors using the average train-final-input second moment, then selects each row's vector labels with that vector position's full train second moment. Each 128-weight row block has one FP16 scale. The 64 labels per row occupy 48 bytes for K64 or 64 bytes for K256. The codebook has one paid FP32 coefficient unit. Little-endian packing round trips every row in [`codec.py`](codec.py). `evaluate.py` also checks packed-table responses against independently decoded dense products at rows 0, 63, 2,048, 8,191 and 151,935.

For a head input `x`, the direct consumer prepares `T_s[c] = dot(x_(16s:16s+16), codeword_c)` and adds 64 indexed table responses per vocabulary row, each with its FP16 block scale. It never creates an int4 matrix. The common train-frequency rows are stored as exact BF16 values with four-byte IDs; they replace the same rows' approximate logits and provide exact input embeddings. The base image still carries their redundant labels and scales, and **both** are charged. For a rare input token, the embedding consumer decodes its one 1,024-coordinate row from 64 labels, scales and codewords. That row must be materialized for the next model layer. Shared storage does not mean the two consumers have the same execution cost.

`calibrate.py` explored FP16 per-row head-only affine corrections and paid for them. `tune.py` instead fits just two FP32 numbers on 128 train positions: a multiplier and an offset for non-retained head logits. They cost eight bytes for the entire matrix and leave input embeddings unchanged. These are approximate head-specific observations, not new tied weights. `allocate.py` tests exact rows chosen from train softmax discrepancy or train next-token loss as alternatives to frequency alone. The former improves held KL but sacrifices some input-embedding coverage; the latter overfits and loses on validation.

## Held-out result and paid rate

All NLLs and KLs are on the same 64 validation positions. Top-token agreement is with the captured BF16 model's argmax. Embedding RMS is weighted by the validation corpus's token counts. The RTN controls use exactly the pilot's symmetric mid-rise group-128 nearest rounding with FP16 scales, and their codes are bit-packed in saved images. RTN2 is a **plain scalar control**, not GPTQ or a strong sub-bit competitor. RTN4 brackets the remaining quality gap.

| Shared tied-matrix representation | Paid bits/weight | Head NLL | KL | Top token | Embedding RMS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original BF16 | 16 | 3.610 | 0 | 64/64 | 0 |
| K256 codebook, no exact rows | 0.6252 | 5.897 | 2.424 | 19/64 | 0.839 |
| K256 + 2,048 frequent exact rows + train rare-logit correction | 0.8413 | 4.492 | 0.924 | 52/64 | 0.435 |
| K256 + 2,560 frequent exact rows + train rare-logit correction | 0.8953 | **4.429** | 0.917 | 50/64 | 0.416 |
| K256 + 1,024 frequent and 1,024 train-softmax-error exact rows + correction | 0.8413 | 4.534 | **0.815** | 52/64 | 0.457 |
| K64 + 3,584 frequent exact rows + correction | 0.8782 | 4.894 | 1.412 | 54/64 | **0.411** |
| Group-128 scalar RTN2 | 2.125 | 4.886 | 1.375 | 21/64 | 0.507 |
| Group-128 scalar RTN4 | 4.125 | 3.571 | 0.038 | 58/64 | 0.102 |

The original-model FP32 weight/head recomputation differs from its captured BF16 logits by 0.0060 RMS, 0.00021 categorical KL and 0.00385 nats of NLL. It agrees on every selected top token. That isolates the much larger representation errors above from the BF16-to-FP32 study boundary. The RTN4 sample NLL happens to fall just below the reference; its KL remains positive. No model-level quality claim follows.

The K256 2,560-row image is 9,723,904 packed label bytes, 2,430,976 FP16 scale bytes, 4,100 codebook/unit bytes, 5,253,120 exact-row BF16/ID bytes and eight correction bytes: **17,412,108 bytes**, or 0.895325 bits per tied weight. [`results.json`](results.json) lists every measured plan, source hash and data receipt. The encoded images and raw captures are under [`/path/to/workspace/data/kelana-subbit/tied-head/`](/path/to/workspace/data/kelana-subbit/tied-head/), outside Git. NPZ container bytes are separate from this explicit runtime payload.

A fresh head input prepares 64×256 FP32 entries, 65,536 transient bytes and 262,144 codeword/input products for K256. Scoring all vocabulary rows then performs 9,723,904 indexed responses plus scales. The 2,560 exact rows need another 2,621,440 BF16-weight/input products; 151,936 output logits occupy 607,744 FP32 bytes. The frequency-retained rows cover 78.16% of held validation corpus token occurrences. To retain 90% of *train* token occurrences exactly requires 7,412 rows; with the smaller K64 base image that alone costs **1.282 bits/weight** and covers 88.81% of validation occurrences. More frequent exact rows cannot solve the input boundary within the sub-bit budget.

The 64 KiB K256 response table is not a free per-wave register array on gfx1151. Table construction, divergent indexed reads, row reduction, exact-row dot products, FP boundary, launch cost and input embedding decode all remain online. There is no native GPU timing for this representation. If only this tied matrix is compressed to 0.8953 bits and every other unique parameter stays BF16, the model is still **12.0573 bits per unique parameter**. Compressing this head alone is not a whole-model sub-bit result.

## Decision and reproduction

A frequency-aware exact subset plus direct table scores preserves many top predictions with fewer bits than scalar RTN2, but its NLL and validation embedding error remain far from RTN4. Moving another 0.05 bits into frequent rows does little for KL. The rare-vocabulary codeword responses and rare-token embedding vectors need better information, not another table-lookup microbenchmark. A next construction should allocate quality to rare head rows by actual train softmax sensitivity while jointly reducing rare embedding error, or combine this exact frequent set with a stronger low-rank/factorized rare representation. Test that candidate through the model before giving it a GPU kernel.

Use the installed read-only ROCm PyTorch environment. The GPU capture is bounded by Bonsai's service-restoring wrapper; subsequent fitting and replay are foreground CPU commands. `record.py` checks the retained identities and writes the compact Git result.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=research/quantization-discovery/subbit/tied-head
D=/path/to/workspace/data/kelana-subbit/tied-head
$B --runtime-max 42s --exec "$P" "$S/capture.py" "$D"
$P "$S/frequency.py" "$D"
OPENBLAS_NUM_THREADS=2 $P "$S/fit.py" 256
OPENBLAS_NUM_THREADS=2 $P "$S/fit.py" 64
OPENBLAS_NUM_THREADS=2 $P "$S/calibrate.py" 256
OPENBLAS_NUM_THREADS=2 $P "$S/calibrate.py" 64
OPENBLAS_NUM_THREADS=2 $P "$S/allocate.py" 256 mixed
OPENBLAS_NUM_THREADS=2 $P "$S/allocate.py" 256 loss
OPENBLAS_NUM_THREADS=2 $P "$S/tune.py" 256 2048
OPENBLAS_NUM_THREADS=2 $P "$S/tune.py" 256 2560
OPENBLAS_NUM_THREADS=2 $P "$S/tune.py" 256 mixed2048
OPENBLAS_NUM_THREADS=2 $P "$S/tune.py" 64 3072
OPENBLAS_NUM_THREADS=2 $P "$S/tune.py" 64 3584
OPENBLAS_NUM_THREADS=2 $P "$S/evaluate.py" 256
OPENBLAS_NUM_THREADS=2 $P "$S/evaluate.py" 64
OPENBLAS_NUM_THREADS=2 $P "$S/scalar.py" 2
OPENBLAS_NUM_THREADS=2 $P "$S/scalar.py" 4
python3 "$S/record.py"
```

The original run used four training and two validation windows to keep one model capture inside the wrapper's 42-second payload ceiling. Every later command fits the session's 55-second foreground limit. No extra compute or serving code was provisioned.
