# Rearrangement bounds for the captured greedy head

The previous [actual-head study](../final-head/README.md) bounds an omitted 128-coordinate block by `min(sum(abs(q)), nonzeros*max(abs(q)))`. The sign pattern contains more information. Store the number of positive and negative trits in each row-block, not their positions. For a query block sorted as `q[0] <= ... <= q[127]`, the largest possible dot consistent with those counts is the sum of the `n+` largest values minus the sum of the `n-` smallest. These positions do not overlap because `n+ + n- <= 128`. Swapping a smaller positive with a larger unused coordinate cannot lower the dot; the analogous exchange applies to negative positions. Repeated exchanges prove this bound over **every** ternary row with the stored counts. It operates directly on the row's packed coordinate as offline metadata and makes no claim that a weight or intermediate must be reconstructed online.

The [CPU replay](grouped.cpp) uses the same production-independent HALO decoder and capture reader as the prior study, then checks all 744,960 reconstructed FP32 logit bits against the three saved GPU captures. It checks the candidate and final winner, and verifies every row's bound against its captured logit. All differences, bound failures and winner failures are zero. The certificate applies to finite, positive-scale captures and the recorded greedy smallest-index tie rule. Its real-sum bound adds `1e-4 * (absolute computed prefix terms + query-only absolute suffix cap) + 1e-12` for FP32 execution. The suffix cap needs only the query, row-block FP16 scale and ternary magnitude limit; it never reads the omitted dot. This is a conservative empirical native FP envelope for these captures, not a formal AMD FP semantics theorem. The candidate is still the best exact score among the first 4,096 rows, whose missing tail must be evaluated online.

## What the byte model says

At prefix cut 34, the plain nonzero-count certificate saved 10.55%, 7.47% and 9.49% of the 278.12 MB head image under its 64-byte-line completion model. Signed counts for an entire 128-coordinate block improve those numbers to 12.05%, 10.50% and 11.76%. They leave 1,659, 7,246 and 2,736 survivors versus 8,554, 23,456 and 13,266. The arithmetic matters: it gains 1.5 to 3.0 percentage points of *modeled head traffic*, not of inference time.

| Sign-count group size | Stored count and scale bytes per row-block | Sky survivors / saving | Fox | Arithmetic |
| ---: | ---: | ---: | ---: | ---: |
| 128 | 4 | 1,659 / 12.05% | 7,246 / 10.50% | 2,736 / 11.76% |
| 32 | 8 | 847 / 10.18% | 3,780 / 9.33% | 1,051 / 10.15% |
| 16 | 12 | 374 / 8.20% | 1,817 / 7.79% | 432 / 8.20% |
| 8 | 18 | 68 / 5.09% | 266 / 5.04% | 92 / 5.09% |

Each group count uses `ceil(log2(group_size+1))` bits, tightly packed, plus two bytes for the existing FP16 scale. All omitted blocks' metadata bytes are charged, even for rows that prune. Prefix reads are `N * cut * 28` bytes, and completion counts the union of actual HALO row segments on 64-byte aligned lines for survivors **and all 4,096 candidate rows**. Cut 34 is the best measured choice in every case at all four group sizes. [Raw cut-by-cut results](case0.json), [fox](case1.json), [arithmetic](case2.json) include cuts 20, 24, 26, 28, 30, 32, 34, 36 and 39; the reported percentage divides total modeled bytes by 278,118,400. The group-8 bound is sharper but loses to metadata. Sorting the query groups, survivor compaction, FP enclosure, extra launches, index construction and repeated transaction fetches are not charged. An online realization cannot borrow scores from the captured array.

This settles a useful limit for **per-row, per-block sign-count rearrangement metadata** on these three queries: making groups finer does not pay even before instruction and scheduling costs. The one-block count improves the certificate but leaves at most a 10.50% modeled head-traffic opportunity across the three captures, so it does not justify an immediate native kernel. The next useful question is a bound that *reuses prefix computation or a compact correlated response across many row-blocks*, rather than buying finer per-row suffix counts. It must beat this line-level model with construction and native bound cost included. This result says nothing about other queries, sampling, approximation, or an ISA-independent argmax lower bound.

## Reproduce

The inputs are the retained `captures.npz` and HALO output image from the actual-head study. The `package.py extract` step checks capture identities. Source SHA-256 for this run: `8dc9de95e1acb9357466bf5ed098e3822294874623e37cf98c07ad0feb0e096c`. Results hashes, cases 0 through 2: `4964443f7e55d92afe6bf757486a1532ad55a3a453963d16c5ab70087fa27416`, `a52c4d4733d665d82ead418373b32479820cbe6e2ef242a02a0355aba2963f9`, `54dadf56dc0649da0d8a3d9374d23400886bc8255c5174235825359e634a8f8d`.

```sh
cd research/argmax-observer/final-head
python3 package.py extract
cd ../grouped-certificate
c++ -O3 -std=c++20 -ffp-contract=off -I/path/to/workspace/projects/bonsai-halo/src grouped.cpp -o grouped
for c in 0 1 2; do
  ./grouped /path/to/workspace/data/bonsai2/PTQ1_0.gguf.halo ../final-head/build/captures/case$c case$c.json
done
```

The experiment includes the replay's source directly to share its decoder and capture parser. It renames the replay entry point at compile time and never invokes it. This is a CPU-only result; no GPU lock, service or runtime changed.
