# Frequency-bucket calibration of the tied head

The K256 tied image's 2,560 exact frequent rows cost 0.895325 bits per tied weight. Its rare-row head logits share one train-fitted temperature and offset. I asked whether a few frequency-dependent offsets correct the rare logit partition without changing the input embedding image. On fixed original-model final-hidden inputs, they do: with a teacher-KL term, held next-token NLL falls from **4.40296 to 4.38285** and teacher KL changes from **0.89427 to 0.89642** against a freshly refitted global-offset control. Against the original published two-scalar image's 4.4291 NLL and 0.917 KL, this is a local improvement on both metrics. It is not a complete-model or native-inference result.

## Construction and paid image

The base K256 codebook, all labels and scales, and 2,560 frequent exact BF16 rows are unchanged. The frequency order comes only from the pinned train corpus. Divide the remaining rows into six bins by train-frequency rank: 2,560–5,119, 5,120–10,239, 10,240–20,479, 20,480–40,959, 40,960–81,919 and 81,920–151,935. The original exact rows form an anchored seventh group. The temperature is frozen at 1.2777578, from the earlier 128-train-position fit. A rare row's table response gets that multiplier and one group offset. The exact rows remain exact. This is a direct head consumer; the input embedding still decodes the same original shared image.

`groups.u3` stores one three-bit group ID per vocabulary row, 56,976 bytes. Six FP16 biases add 12 bytes. The image costs **17,469,088 bytes, 0.898255 BPW** including the original codebook, scales, redundant common-row codes, exact-row IDs/BF16 values and the extra 56,988 bytes. That is +0.002930 BPW over the original eight-byte global-calibration image. Online, every rare logit reads its three-bit row label and adds one bias after the existing multiply; no int4 weight matrix is produced. This extra irregular read has not been timed on gfx1151 and could erase the quality benefit in a latency-constrained setting. The group image and trained FP16 biases are retained in `/path/to/workspace/data/kelana-subbit/tied-bias/` with SHA256s in `result.json`.

## Fitting and result

The cached `gold-row/` matrices supply 128 train-fit and 32 disjoint train-calibration final-hidden inputs with their next-token labels. The same 64 held validation inputs and captured BF16 original logits assess every arm. All scores are for the same K256 base image with the same frequent exact rows. The global and bucket arms fit on the same 160 train positions; neither reads held labels or logits. The teacher distribution for the train KL term comes from the cached dense FP32 original-weight responses, not the held BF16 reference. The head image's earlier temperature fit overlaps train windows but is frozen for every arm. No quantized input embedding is forwarded through the model.

For offsets b with b_exact=0, let P_i,g be the summed candidate probability in group g after applying b, T_i,g the train original-weight probability, and G_i the gold-token group. The objective is gold NLL plus lambda times teacher KL. Its gradient in b_g is mean of `(1+lambda) P_i,g - 1[G_i=g] - lambda T_i,g`. Its Hessian is `(1+lambda)` times the mean categorical group covariance, positive semidefinite. Exact-row mass anchors the otherwise free common shift, so minimizing this small convex problem finds the family optimum at the fixed temperature and labels. The selected lambda=2 was among the three declared values 0, 0.5 and 2; the full panel, including the striking KL loss of unregularized buckets, is preserved below. NLLs use all 151,936 head logits for each position. Bucket metrics use the actually stored FP16 offsets.

| Train KL weight | Correction | Held NLL | Held teacher KL | Top-1 match /64 | Extra bytes |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | global FP32 | 4.44343 | 0.93021 | 51 | 4 |
| 0 | bucket FP16 | 4.39094 | **1.21737** | 52 | 56,988 |
| 0.5 | global FP32 | 4.42052 | 0.90964 | 51 | 4 |
| 0.5 | bucket FP16 | 4.38182 | 0.92344 | 53 | 56,988 |
| 2 | global FP32 | 4.40296 | 0.89427 | 51 | 4 |
| 2 | bucket FP16 | **4.38285** | 0.89642 | 51 | 56,988 |

At lambda=2 the two validation-window NLLs are in `result.json`; this is 64 selected positions, not a broad text evaluation. The unregularized fit drives the two rarest group offsets to -14.59 and -12.43, which suppresses teacher mass and explains why a lower gold NLL alone is misleading. Teacher regularization keeps them at -0.44 and -0.82 for lambda=2. The global FP32 comparator costs four bytes here because temperature is shared and fixed; bucket scores use FP16-round-tripped offsets. Frequency-weighted embedding RMS stays 0.41641, unchanged from the base image.

This is a useful cheaper quality correction within an existing consumer, but it adds one dependent label read per rare output and does not fix the large absolute loss against the 3.61026 original NLL. The next question is whether those group IDs can be derived from an existing row-code or exact-row index without an irregular read, and whether embedding-propagated loss keeps the head gain. Do not spend a GPU timing round until a larger fresh head sample establishes that gain.

Run the CPU replay with `OPENBLAS_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/tied-bias/study.py`. The script reads the retained captures, writes the paid images and `result.json`, and takes less than a minute. It does not touch the GPU or serving service.
