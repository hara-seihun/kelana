# An argmax certificate for the output head

A candidate-and-bound consumer can preserve the greedy result without producing every logit, but the tested bounds save almost no head work on two reproducible inputs. At 39 of 40 K-blocks evaluated for every vocabulary row, 1,261 or 3,426 rows remain. The best possible weight-read saving in this measured schedule is about 2.2% before candidate generation, decoding, metadata and another launch. A reference-query score image is even less useful on the second input: with the winning score supplied for free, its bound excludes zero of 248,320 rows. No serving code changed.

## Observation and numerical boundary

The output head has 248,320 rows and 5,120 input coordinates, stored as 32-row HALO tiles of forty 128-coordinate blocks. One row-block stores 26 code bytes plus a 16-bit scale. The packed image occupies 278,118,400 bytes. The native kernel produces an exact signed integer dot for each block, multiplies it by that row-block's FP16 scale and the activation's FP32 block scale, then accumulates with FP32 `fmaf` in eight five-block chains. It adds the eight chains in wave order. `head_argmax_slices` and `head_argmax_final` select the smallest vocabulary index on equal finite logits. A NaN fails both their `>` and `==` comparisons and is ignored; an all-NaN or all-minus-infinity slice starts from `-INFINITY` and index zero. A usable serving certificate must cover that behavior or reject non-finite inputs and scores explicitly.

This study fixes activation block scales to exactly 1 and uses real HALO weights with two signed-int8 query vectors. It certifies the *exact scaled-integer real sum*, with all FP16 scales represented as integers in units of 2^-24. It also computes a CPU FP32 `std::fma` proxy in the head's eight-chain order for candidate selection. The source, compiler and host runs do not establish last-bit equality with gfx1151. Applying real Bonsai activation scales, reproducing the deployed FP32 rounding for every row, and bounding each GPU logit's numerical error would be necessary before this certificate could skip a row in serving. A proof about integer sums is not an FP32 argmax proof.

Both queries come from the first 5,120 coordinates of the first two captured layer-10 FFN input rows (`r8/xq_ff.i8`, each 17,408 coordinates). They are reproducible, full-range int8 vectors, **not final-head captures**. This is a test of the real head weight geometry against plausible captured integer values, not evidence about the distribution of actual final-head inputs.

## What the certificate checks

For a row `i`, let `P_i(c)` be its exactly evaluated first `c` blocks in integer units of 2^-24. With a block's nonzero trit count `m`, query absolute sum `A` and maximum absolute coordinate `M`, the omitted block's absolute dot is bounded by `min(A, m*M)`. Multiply by that block's nonnegative FP16 scale and sum over the remaining blocks to get `R_i(c)`. Thus `S_i <= P_i(c)+R_i(c)` for the exact scaled-integer score. The runner verifies that inequality against **all 248,320 fully decoded scores** at every cut. It discards an earlier index only when its upper bound is strictly below the candidate's exact score, and a later index when its bound is at most that score. It then computes the maximum among the survivors and checks it against the all-row exact winner. The candidate comes from scoring the first 4,096 complete rows with the CPU FP32 proxy; it is allowed to be wrong.

[Kelana/ArgmaxObserver.lean](../../Kelana/ArgmaxObserver.lean) proves the generic prefix-plus-suffix upper rule, transfer given an independently established numerical error interval, and the strict-earlier/non-strict-later tie rule for a finite ordered integer score family. No numerical error interval for the GPU is supplied or claimed here. The executable checks the real-image decoding against Bonsai's independent `halo::decode_block` on every row-block, plus both signs of every qh tail-position basis vector. It then checks integer bounds and the all-row winner. Lean does not verify the HALO decoder or native FP behavior. The [final-head follow-up](final-head/README.md) captures actual deployed head operands and FP32 logits.

| Input | Candidate in first 4,096 | Exact winner | Survive after 24 blocks | After 36 | After 39 | After 40 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| First captured proxy | 3,974 | 151,278 | 248,320 | 235,590 | 1,261 | 2 |
| Second captured proxy | 1,862 | 161,956 | 248,320 | 247,660 | 3,426 | 33 |

Neither proposed candidate is the winner. Evaluating the remaining two or 33 exact scores selects the all-row winner. Both runs check every excluded row and retain the exact winner at all cuts. The plain bound `sum |x|` and the support-aware `min(sum |x|, count_nonzero*max |x|)` produce the same survivor counts here. The support information costs a byte per row-block without buying a discard on either input.

A genuinely different information source was also tried. Prepare every row's exact response to the first query as an anchor, then bound a new response by `anchor_i + sum_b scale_i,b * ||q1_b-q0_b||_1`. This is an exact scaled-integer Lipschitz certificate. It stores 1,986,560 bytes of anchor scores and reads 19,865,600 bytes of scales plus those scores for each new query, doing 9,932,800 scale-bound products. Against the second input, **all 248,320 rows survive even when the true winner and its score are given for free**. The two queries differ by L1 distance 263,661. Memorizing one input is not a useful general head consumer here.

## Price of the staged approach

The prefix scheme needs 9,932,800 precomputed one-byte nonzero counts, prepared by reading and decoding the entire 278 MB head once offline. The existing 19,865,600 scale bytes remain part of the weight image. A separate tightly packed scale/count index duplicates those scale bytes to achieve the optimistic three-byte metadata read below; gathering scales from HALO's interleaved image costs more transaction bytes. At cut `c`, the bound reads three bytes of scale/count per remaining row-block and does one input-dependent minimum, multiply and sum per remaining block. Scoring each surviving row then reads and decodes the omitted 28-byte row-blocks. The table gives optimistic recurring bytes. It counts each evaluated code byte once, assumes contiguous perfectly scheduled reads, and gives the candidate score and all prefix values at no extra cost. Real tiled access, intermediate sums, selection, FP enclosures and launch overhead can only add work.

| Prefix blocks | First query survivors | First query total MB | Second query survivors | Second query total MB |
| ---: | ---: | ---: | ---: | ---: |
| 24 | 248,320 | 290.04 | 248,320 | 290.04 |
| 36 | 235,590 | 279.67 | 247,660 | 281.02 |
| 39 | 1,261 | 271.95 | 3,426 | 272.01 |
| All 40, no certificate | all | 278.12 | all | 278.12 |

At cut 39 the count/scale pass reads 744,960 bytes, all-row prefix reads 271,165,440 weight bytes, and the remaining exact row-blocks read 35,308 or 95,928 bytes. The 6.11 to 6.17 MB saved is 2.20 to 2.22% of head weight traffic in a favorable, exact-real arithmetic accounting. Most head matrix work remains: 39 of 40 block dots for every row. The first 4,096 complete candidate rows cost another 4,587,520 weight bytes if run as a separate pass. Even with perfect fusion they require at least the last block of those rows, 114,688 bytes, before the other rows can be certified. A GPU implementation would still need to carry the original scales and order while doing this metadata and survivor scheduling. The native full decode with the independent decoder check took about 1.27 seconds per proxy on one CPU run; it is an evidence-generation run, not a GPU speed baseline.

This is a negative for independent residual magnitude bounds and a one-query Lipschitz anchor on these inputs, not for all argmax observations. The next promising information source would be a small, reusable projection index that predicts *correlated signed residuals* across many rows and cheaply encloses its error for actual final-head inputs. It must beat the 278 MB direct stream after its index, candidate scoring and FP enclosure are paid. The [actual final-head capture](final-head/README.md) now answers the proxy-transfer question. It also supplied the independent native-logit check that revealed the qh-tail parser error corrected below.

## Custody and reproduction

The source model is `/path/to/workspace/data/bonsai2/PTQ1_0.gguf` (5,946,648,928 bytes). Its HALO cache has `output.weight` at byte 24,576, size 278,118,400, SHA-256 `1590e2218ba66c23f8c01e97bb09773516d2cfdcee30a3c2458b2762f1abd4c5`. The captured input source is `/path/to/workspace/data/kelana-ffn/ptq1_0/layer10/r8/xq_ff.i8`, SHA-256 `286c50eccacf9dee3b4c94c96b9e20659aa174ce89bf51dace65fd928e467d13`. Each result JSON records the exact probe source and executable hashes, query hash, cache geometry, candidate and full-winner indices, surviving counts, byte counts and elapsed host decode time. The complete scores and exported queries are disposable build data. The first record, integrated as Kelana `06bd8c0`, placed qh trits at `120+2*d+h` instead of HALO's `120+4*(d/2)+2*h+(d%2)`. Its earlier winners 3,974/161,956 and 609/2,181 survivors at cut 39 were computed against that same faulty parser. The present result files replace those counts; Git retains the original evidence as ordinary provenance. The final-head run found the defect by comparing every reconstructed FP32 logit against the deployed GPU output, and this replay now checks every decoded block against Bonsai's own decoder before trusting a certificate. There is no GPU work in this corrected proxy replay.

From this directory:

```sh
mkdir -p build
python3 - <<'PY'
from pathlib import Path
s = Path('/path/to/workspace/data/kelana-ffn/ptq1_0/layer10/r8/xq_ff.i8').read_bytes()
assert len(s) == 8 * 17408
Path('build/query.i8').write_bytes(s[:5120])
Path('build/query1.i8').write_bytes(s[17408:17408+5120])
PY
c++ -O3 -std=c++20 -ffp-contract=off -I/path/to/workspace/projects/bonsai-halo/src probe.cpp -o build/probe
build/probe /path/to/workspace/data/bonsai2/PTQ1_0.gguf.halo build/query.i8 build/results.json 4096 build/score0.f64
build/probe /path/to/workspace/data/bonsai2/PTQ1_0.gguf.halo build/query1.i8 build/results1.json 4096 build/score1.f64
OPENBLAS_NUM_THREADS=1 python3 anchor.py
python3 record.py
cd ../..
lake env lean Kelana/ArgmaxObserver.lean
```

Each foreground command fits the session's 55-second limit. `record.py` checks that the cache header names the same GGUF size and mtime before accepting its data. `build/` is disposable. It does not download a model or mutate the resident service.
