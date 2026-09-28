# Coded binary input blocks: a near miss against the lookup comparator

An eight-channel binary input block has 256 possible sign patterns. The NanoQuant first factor stores one byte per block and rank, and a native lookup consumer can build the 256 activation responses once per block. We tried replacing each block's byte with a short label into a learned block-local sign dictionary, then fitting the binary output plane. A second construction keeps high-impact input blocks exact and codes only the quiet ones. Both have an executable packed-sign, label, dictionary and scale image. Neither beats NanoQuant after giving its binary output factor the same activation fit.

## Stored map and fitting

For an `N×K` matrix with rank `R`, group each input into `G=K/8` blocks. Store `U in {-1,+1}^{N×R}`, FP16 input/output scales, and for each input group `g` a dictionary of `C` eight-sign patterns and one `log2(C)`-bit label per rank. For one activation, compute the `C` responses to its eight scaled inputs once, gather one response per rank, and apply `U` by a second eight-sign response table. The binary factor is never expanded into a dense arithmetic matrix online. `fit.py` supports 8, 16, 32, 64 and 128 patterns per group; its rank allocator counts all dictionaries and chooses the largest byte-aligned rank below .55 matrix BPW.

Initialize from the same pinned upstream NanoQuant ADMM factorization used by the [binary-factor comparator](../binary-factors/README.md), but at the larger rank allowed by the new representation. Cluster each eight-sign block's patterns with binary majority updates. Refit the output signs, input labels, dictionaries and output scales by weight-space coordinate descent. For fixed scales, the output sign coordinate is the exact minimizer of its conditional squared error; with other labels fixed, each label chooses the dictionary entry with the best quadratic residual score. Each dictionary sign is likewise a conditional optimum given assignments. The input dictionaries and assignment together are not globally optimized. Finally fit the binary output signs and scales for four sweeps on all 2,048 train activations. The 1,024 validation activations are never used for fitting. Each known BF16 weight matrix is available to quantization. The saved image rounds scales to FP16 and packs the binary plane before held-out scoring.

The mixed construction in `mixed.py` stores an eight-sign byte for ordinary groups. It chooses 16 or 32 least-sensitive groups for a sixteen-entry dictionary and four-bit labels, using either weighted matrix error or the exact *single-group* train-response distortion induced by replacing that group. A group mask, every dictionary, all labels and both scale streams count. The group selection is not a global joint optimum because simultaneous group errors can interact. Refit the output signs and coded input labels, then fit the output signs on train activations. No hidden rotation or permutation is free.

## Held-out results and matched control

These are relative squared errors on real validation-token projection outputs, not language-model loss. Q is `2048×1024`; O is `1024×2048`. NanoQuant ADMM alone has payload .53906 BPW and rank 352 on both shapes. `control.py` starts from its *same exported packed image* and gives its output signs/scales the exact same four activation-fitting sweeps. That is the meaningful control for the extra calibration stage, even though our coded factors also use more fitting work than the control. The rates below include all matrix-specific codes, dictionaries, scales and masks.

| Map | Matrix BPW | Layer 0 Q | Layer 27 Q | Layer 0 O | Layer 27 O |
| --- | ---: | ---: | ---: | ---: | ---: |
| NanoQuant ADMM-only | .53906 | .09666 | .11579 | .29092 | .48098 |
| NanoQuant plus four activation output sweeps | .53906 | .06962 | .10438 | .26672 | .50783 |
| 16 patterns per block, then four activation sweeps | .54883 Q / .54688 O | .08506 | .13418 | .30536 | .57464 |
| 32 patterns per block, then four activation sweeps | .54150 Q / .54688 O | .08113 | .12579 | .29537 | .55775 |
| 64 patterns per block, then four activation sweeps | .54883 Q | .07677 | .11896 | not run | not run |
| 128 patterns per block, then four activation sweeps | .54639 Q | .07595 | .11545 | not run | not run |
| Mixed, 16 groups coded, activation-aware group choice | .54083 Q | .07234 | .10950 | not run | not run |
| Mixed, 32 groups coded, activation-aware group choice | .54205 Q | .07347 | .11267 | not run | not run |

A sixteen-pattern dictionary destroys too much of the dense first factor even with 424 Q ranks. Before activation refitting, early Q is .16204 versus NanoQuant ADMM's .09666. With 128 patterns and 328 ranks, the input approximation is better; early Q falls to .07595 after fitting activation responses, beating the ADMM-only .09666 but **not** its equally activation-fitted .06962. Late Q .11545 barely passes ADMM-only .11579 but loses to .10438 with equal activation fitting. The best mixed candidate is closer to the strong control at .07234/.10950 and only slightly above its .53906 BPW, but still loses .06962/.10438. Early O with 32 patterns is .29537 versus .29092 before any comparator refit, and late O loses by more. This is a bounded negative, not a native throughput result or a whole-model quality claim.

The table intentionally reports the four-sweep NanoQuant late-O regression too; the best unchanged comparator image there remains .48098. On Q the activation fit raises unweighted weight error while lowering held-out response error, a direct reminder that the relevant activation geometry is not diagonal weight reconstruction. Full JSON reports retain intermediate fit errors and timings. `fit.py` took roughly 9 to 14 CPU seconds per uniform case; `mixed.py` took roughly 5 to 7 seconds per case, eight CPU threads. The upstream ADMM at each new rank gets 400 outer and five inner iterations. A head-to-head with exactly matched fitting compute has not been established; the comparator actually receives *less* total work here.

## Online cost ledger

At `N=2048,K=1024`, the packed NanoQuant rank-352 image is 141,312 bytes. Its own eight-sign lookup lowering uses 128 input response tables, 45,056 first-stage reads, then 44 output tables and 90,112 second-stage reads. A full 256-entry table costs at most 255 incremental additions per input block after its base response; the two passes therefore need 32,640 plus 11,220 table additions and 135,168 reads. They can stream their tables, rather than materializing 65,536 plus 22,528 BF16 bytes simultaneously. Expanded signed arithmetic instead needs 1,081,344 terms and may use matrix hardware on a suitable batch. Neither is a strawman unpack-to-int4 competitor.

The uniform sixteen-pattern Q map at rank 424 reads 54,272 first-stage and 108,544 second-stage tables, 162,816 reads total, despite halving the table-build additions to an upper bound of 16,384 plus 13,515. It reads 143,872 model bytes. The 128-pattern Q map at rank 328 reads 41,984 plus 83,968 table values, 125,952 total. Its tables occupy 32,768 plus 20,992 BF16 bytes, and it reads 143,232 model bytes. Although evaluating each of 128 patterns independently takes at most 131,072 signed additions, the cheaper option is to build the full 256-entry input table by recurrence in 32,640 additions and retain the selected 128 responses. Add 10,455 output-table additions. Thus the 128-pattern map has around 7% fewer table reads than the NanoQuant lookup, but nearly the same table construction, a packed seven-bit label extraction cost, and slightly more model bytes. It has no demonstrated native speedup.

The mixed Q map with sixteen coded groups and rank 360 uses 16, 256 and 2,880 bytes for its group mask, dictionaries and labels. Its exact groups use 40,320 bytes of eight-sign patterns, the packed output uses 92,160 bytes, and scales use 6,144 bytes. Total payload is 141,776 bytes or .54083 BPW. Lookup needs 46,080 first-stage and 92,160 second-stage reads, plus at most 30,608 and 11,475 table additions. Input and output response tables occupy at most 57,856 and 23,040 BF16 bytes if fully materialized. Coded-group mask handling and nonuniform tables add control cost. A WMMA path, fusion, register placement, scratch, and batch-size dependence still need real measurements before any latency claim.

These are matrix payloads and per-vector logical work, not complete model BPW or observed gfx1151 time. Embeddings, tied head, retained tensors, padding, runtime scratch and KV must be added for a whole-model comparison.

## Decision and stronger capacity mechanism

Do not build a gfx1151 kernel for uniform sixteen-pattern blocks. At the same rate it loses quality and performs more lookups than NanoQuant's own table program. The mixed sixteen-group image is a more interesting research seed, but its few-percent quality gap and narrow lookup-cost difference do not warrant a kernel yet. The group-selection change itself mattered: on late Q, ranking sixteen compressed groups by train-response distortion gave .10950 after fitting, versus .11651 when ranking by weight distortion. A next representation should allocate group code rates *and* optimize their labels with the full train-activation covariance, allowing a small set of high-sensitivity groups to retain all 256 patterns while aggressively coding quiet groups. A label can be changed by the exact train-response quadratic over its eight activation channels, with all other labels fixed. Sparse accepted updates avoid the interference seen when changing hundreds simultaneously. Price variable-group addressing and table preparation during that search. If the high-sensitivity groups still need nearly all patterns and the saved groups cannot pay for a useful rank increase, the dense binary first factor's input geometry is the obstruction, and joint Q/K/V reuse is a better route than more single-matrix dictionary tuning.

## Reproduce and data custody

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/block-factor
F=/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext
$P "$D/fit.py" --fixture "$F/layer00-self_attn_q_proj.npz" --codes 128 --rounds 8 --activation-sweeps 4 --output "$D/layer00-q-c128-activation.json"
$P "$D/mixed.py" --fixture "$F/layer27-self_attn_q_proj.npz" --compressed-groups 16 --group-score activation --output "$D/mixed-layer27-q-g16-activation-score.json"
$P "$D/control.py" --layer 0 --projection q --output "$D/control-layer0-q.json"
$P "$D/decode.py" --image /path/to/workspace/data/kelana-subbit/block-factor/mixed-layer27-q-g16-activation-score.npz --fixture "$F/layer27-self_attn_q_proj.npz"
```

`decode.py` unpacks the factors for offline scoring, not for the proposed native table program. Unpacking the two named mixed and uniform images reproduced their JSON held-out errors exactly.

The JSON points and source are in this directory; packed images, including dictionary bits and all mask/index metadata, are under `/path/to/workspace/data/kelana-subbit/block-factor/`. The pinned model and fixture hashes are in the canonical fixture manifest. These images are data, not source files for Git.

The four activation-refined NanoQuant controls also have retained packed images there: `control-layer0-q.npz`, `control-layer27-q.npz`, `control-layer0-o.npz`, and `control-layer27-o.npz`. `control.py` preserves the source image's packed `V` and canonical `U`, `V`, `scale_pre`, `scale_post`, `dimensions` field names, repacks the fitted binary `U`, and writes the fitted FP16 post scale. Each corresponding `control-layer*.json` records the image's SHA256 and serialized ZIP size, so downstream studies can use the actual factor signs and scales rather than reconstructing a control from a printed error. The matrix payload remains .53906 BPW; each ZIP image is 142,568 bytes including its container.
