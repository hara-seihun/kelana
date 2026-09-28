# Actual final-head inputs and a bounded argmax replay

Three short prompts now have durable captures of the engine's final-head signed-int8 codes, 40 FP32 activation scales and sums, all 248,320 deployed FP32 logits, and the greedy token. The native replay recomputes **every logit bit exactly** from the committed capture and the real 278,118,400-byte HALO output image. It exposed and corrected the qh-tail decoding bug in the [previous proxy study](../README.md). No serving runtime changed.

The real head queries separate much better than those two FFN-input proxies. A prefix certificate at 34 of 40 blocks leaves 8,554, 23,456 or 13,266 rows for exact completion, depending on the prompt. In optimistic byte accounting it saves 12.88%, 11.98% or 12.59% of the 278 MB head weight stream. That is a useful research contrast, **not a measured GPU acceleration**. The certificate still decodes 85% of every row's K-blocks, reads scale/count metadata, and schedules thousands of remainder rows. It cannot replace the deployed head without a native implementation and numerical acceptance. A [sign-count rearrangement certificate](../grouped-certificate/README.md) tightens this cut on the captured queries, while finer sub-block counts cost more metadata than they save.

## Capture boundary

[`capture.cpp`](capture.cpp) links the existing Bonsai engine objects without modifying its runtime. With one model load and a 256-token context, it resets the same engine for each fixed prompt, runs the ordinary fused one-row path, asks for logits on the last prompt token, and copies `xq`, `xs`, `xsum` and `logits` only after the engine returns. The three prompts and token IDs are in [`prompts.txt`](prompts.txt) and [`results.json`](results.json). Query shape is 5,120 signed bytes; each 128-coordinate block has a separate FP32 activation scale and signed integer sum. Output shape is 248,320 FP32 values. Every scale and logit is finite; all activation scales are positive. The saved sums equal the sums of their corresponding signed query bytes. GPU argmax equals the smallest index of the maximum finite saved logit in each case.

[`captures.npz`](captures.npz) keeps the arrays bit-for-bit. `package.py extract` restores the four raw arrays and their SHA-256 checks per case. [`capture.zst`](capture.zst) retains the actual capture executable, because the Bonsai source tree and its linked objects may evolve. The manifest names that binary's SHA-256 `705bb9125ae492d93ead4f2ddd631db0310bd57be02299738b46ca7fc62cd4dc`, the 278 MB head image hash, model size and mtime, input hashes, and replay executable/source hashes. For these first three captures, the source commit label was a constant in the packaging script and object hashes were sampled at packaging, not linking. [`capture-provenance.json`](capture-provenance.json) records that distinction rather than inventing a build receipt. The retained executable and query/logit arrays are the direct artifacts. The capture ran through `tools/run-batch-compare --exec` with a 42-second payload ceiling. That wrapper reserved the GPU, paused and restored the resident service. The research tool never writes a serving artifact.

New builds snapshot source and ordered object identities before compilation, reject changes during linking, and bind the receipt to the executable. New runs check that identity around execution and bind a run receipt to each saved input/output file. Packaging consumes those receipts and preserves the current run receipt alongside the arrays. It does not scan whatever objects happen to be in Bonsai later.

## Arithmetic and greedy rule

A HALO row-block stores 26 packed ternary bytes and its FP16 scale. The matrix instruction makes an exact signed-int8/ternary block dot. Its source then computes `fmaf(float(dot), float(weight_scale) * activation_scale, chain)`. A row has eight chains of five blocks; the kernel adds the eight in wave order. The native replay performs the same binary32 operations. It checks every unpacked block against Bonsai's independent `halo::decode_block`, with both signs of a one-trit basis vector at each of the eight qh tail positions. Its 744,960 GPU-logit comparisons across three captures have **zero differing bits**. This checks the deployed FP map for these inputs. It is not a Lean proof of HIP instruction semantics.

For a finite score family, Bonsai chooses the smallest index on a tie. The source initialises each argmax slice to `-INFINITY` and index zero; NaNs lose both `>` and `==`. This study rejects any non-finite captured logit or nonpositive activation scale rather than silently treating a NaN as a small finite score. The generic strict-earlier/non-strict-later certificate is in [`Kelana/ArgmaxObserver.lean`](../../../Kelana/ArgmaxObserver.lean).

The replay forms a mathematical real sum `S_i` of exact integer block dots times the FP16 and FP32 scales. For an uncomputed block with `m` nonzero trits, `A=sum(abs(q))`, and `M=max(abs(q))`, the block response magnitude is at most `min(A,m*M) * weight_scale * activation_scale`. The sum of the remaining caps is a valid real-sum upper bound. To transfer to the deployed FP32 result, the replay bounds the absolute term sum by `M_i(c) = sum(abs(computed prefix terms)) + sum(suffix caps)` and adds `10^-4 * M_i(c) + 10^-12`. Both quantities are available without decoding the skipped suffix. The initial replay used actual suffix dots to form this guard; integration replaced that inaccessible information and regenerated every cut. This slightly increases the survivor counts.

The guard is deliberately loose. Each of the 40 FP32 scale products, 40 FMAs and seven final adds rounds at most once. With unit roundoff `2^-24`, the conservative 87-operation relative allowance is below `6*10^-6` of the absolute term sum on this finite, non-overflow domain. The extra factor covers long-double bound arithmetic; the fixed absolute slack exceeds accumulated binary32 subnormal/flush error. The runner rejects any cut with `M_i(c)` over one million and checks its proposed upper against **every deployed GPU logit**. The source and captures establish the arithmetic and domain for this experiment, not a formal proof of the emitted compiler object across all possible inputs.

The candidate is the highest deployed logit among the first 4,096 rows. It can miss the true winner. An earlier row survives when `upper >= candidate_logit`; a later row survives only when `upper > candidate_logit`. The runner scores the survivor set against the saved exact GPU logits, checks the winning index, and reports a zero count for any violated upper. An online version must evaluate candidate scores itself rather than read the saved full-logit array. The byte accounting below gives it the favorable assumption that candidate work overlaps the prefix.

| Prompt case | Deployed greedy index | First-4,096 candidate | Survive after 32 blocks | After 34 | After 36 | After 39 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sky | 760 | 760 | 146,426 | 8,554 | 28 | 1 |
| Fox | 4,639 | 1,919 | 171,323 | 23,456 | 77 | 2 |
| Arithmetic | 16 | 16 | 149,770 | 13,266 | 48 | 3 |

The fox candidate is wrong; both surviving rows at cut 39 include the true index 4,639. At every cut, the replay verifies the winner and the upper against all 248,320 deployed logits. [`results.json`](results.json) records each cut, raw identities and the zero mismatch counts.

## Cost, not a speed claim

At cut `c` the optimistic program reads `248320*c*28` bytes of prefix weights, `(40-c)*248320*3` bytes of precomputed one-byte nonzero counts and existing two-byte scales, and `(40-c)*survivors*28` bytes to finish survivors. The count image occupies 9,932,800 bytes and takes an offline full-image decode to prepare. Charging exactly three metadata bytes per remaining row-block assumes a separate tightly packed count-and-scale index, adding another 19,865,600 copied scale bytes. Reading scales from their current interleaved HALO image instead costs extra transaction bytes. A separate exact first-4,096 candidate pass reads another 4,587,520 bytes; fusion with the prefix could reuse most of them but still needs those rows' omitted blocks before pruning the others. Prefix sums, the FP envelope, survivor compaction, synchronization and extra launches cost more than this byte model includes.

| Cut | Sky optimistic bytes | Fox | Arithmetic | Saving versus full 278.12 MB |
| ---: | ---: | ---: | ---: | ---: |
| 32 | 261.25 MB | 266.83 MB | 262.00 MB | 4.06–6.06% |
| 34 | 242.31 MB | 244.81 MB | 243.10 MB | 11.98–12.88% |
| 36 | 253.29 MB | 253.30 MB | 253.29 MB | 8.93% |
| 39 | 271.91 MB | 271.91 MB | 271.91 MB | 2.23% |

A row is not a memory transaction. The replay also counts the union of HALO byte segments touched by all surviving rows and all 4,096 candidate rows. It rounds those segments to aligned 32-, 64- and 128-byte lines. This preserves the actual row arrangement rather than assuming surviving bytes pack themselves together. Prefix and three-byte metadata traffic are included; repeat fetches, instruction issue, temporary storage and launches are still free.

| Assumed line bytes, cut 34 | Sky total MB / saving | Fox | Arithmetic |
| ---: | ---: | ---: | ---: |
| 32 | 245.60 / 11.69% | 251.43 / 9.60% | 247.50 / 11.01% |
| 64 | 248.78 / 10.55% | 257.35 / 7.47% | 251.73 / 9.49% |
| 128 | 253.62 / 8.81% | 264.51 / 4.89% | 257.61 / 7.37% |

These are transaction-size models, not measured cache behavior. No GPU timing for a certificate kernel exists here. The index still performs 34/40 of every row's matrix arithmetic. Prefix absolute-value accumulation, a native conservative FP bound and survivor scheduling have not been lowered. This family offers a modest head-only opportunity and does not justify a full-model speedup claim. Sampling or log-probability requests need different observations.

A reference-query score image also fails on the real captures. Anchoring all row scores from the sky prompt costs 1,986,560 bytes of FP64 values and 19,865,600 scale bytes per new query, plus 9,932,800 scale terms. Its safe `sum(weight_scale * sum(abs(q_new*xs_new - q_anchor*xs_anchor)))` radius discards **zero rows** for the fox and arithmetic prompts, even when supplied the true winning real score for free. [`anchor-results.json`](anchor-results.json) contains the two checked full-row comparisons. This rejects that one-anchor schedule, not every representation of correlated row responses.

## Replay

On this machine, under a 55-second foreground command limit:

```sh
cd research/argmax-observer/final-head
mkdir -p build
python3 package.py extract
c++ -O3 -std=c++20 -ffp-contract=off -I/path/to/workspace/projects/bonsai-halo/src replay.cpp -o build/replay
for c in 0 1 2; do
  build/replay /path/to/workspace/data/bonsai2/PTQ1_0.gguf.halo build/captures/case$c 4096 build/replay$c.json build/score$c.f64
done
OPENBLAS_NUM_THREADS=1 python3 anchor.py
```

For a fresh GPU capture, remove the generated `build/captures` directory, then run `./build-capture.sh` and `./run-capture.sh`. The build script uses the recorded object order and writes a new receipt for the current object bytes. Missing or changed inputs stop the build. The run script uses Bonsai's `tools/run-batch-compare --runtime-max 42s --exec` with the model, `prompts.txt` and an empty output directory. After replaying the new cases with the loop above, `python3 package.py pack` validates the run receipt, retained executable and arrays, then publishes their identities together. `python3 test_provenance.py` checks object/binary/output mutation rejection and the pack/extract receipt roundtrip in seconds. The NPZ and compressed executable are research evidence, not runtime dependencies. No serving acceleration is proposed.
