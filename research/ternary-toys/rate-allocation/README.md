# A paid two-block allocation oracle

The cheap image need not approximate either matrix. It needs to approximate their composition. In this finite two-block example, independently choosing the best image for each block has **26.8 times** the output error of a joint choice at the same seven bytes. The winning images are individually quite bad: the second block even changes the sign of one matrix entry. This is a gauge-like cancellation across the intervening residual boundary, not an improvement in local rounding.

## Experiment

For a two-coordinate residual network, let

```text
z = (I + A)x                 y = (I + B)z
A = [[ .625, 1.5],           B = [[-.5, -.5],
     [-.5,   .25]]                [ .25, -.5]]
x is either (2, 0) or (0, 1)
```

Both inputs are scored, with squared error summed over their two output coordinates. Equivalently, for an image pair `(a,b)`, the objective is `||(I+b)(I+a)D - (I+B)(I+A)D||²_F`, with `D=diag(2,1)`. Thus the first input coordinate matters four times as much in squared error. The target map is `[[1.0625,.125],[.15625,1]]`. This is a complete composed-map objective, not an isolated matrix norm. The dyadic source weights and all tested scales have exact FP16 representations; the oracle computes the resulting linear map in float64.

The exhaustive finite catalogue has 4,621 images **per matrix**:

- Four ternary codes in `{-1,0,1}`, with one of five FP16 scales `.5,.75,1,1.5,2`: 405 images. Four trits fit in one byte.
- Two four-symbol alphabets, `{-2,-1,0,1}` and `{-1,0,1,2}`, at the same scales: 2,560 images. Four symbols fit in one byte.
- One original FP16 weight substituted at any of four positions in each ternary image: 1,620 images. Its position costs one byte and its value two bytes.
- A conventional signed four-bit image, with the four nearest-rounded nibbles at each scale `.25,.375,.5,.75,1,1.5,2`, plus one-exception versions: 35 images. Four nibbles occupy two bytes. This four-bit control searches scales but not all `16^4` codes.
- The exact four-weight BF16 matrix, eight bytes.

A single byte stores the two matrix modes as a radix-seven pair, leaving no uncharged alphabet or exception-mode selector. Each low-bit image has a two-byte FP16 scale. The complete seven-byte image has two code bytes, four scale bytes and the mode byte. A four-bit pair uses nine bytes. One four-bit exception plus one four-bit image uses twelve. The two dense matrices use seventeen bytes including the mode byte. There are no learned tables, rotations or uncharged rank factors. A rank-one correction with four FP16 factor entries already adds eight bytes to a matrix's low-bit image, more than replacing that entire 2x2 matrix with its eight-byte dense image; it cannot improve this finite storage frontier.

## Exact paid frontier

| Maximum image bytes | Joint oracle error | Isolated-response allocation error | Best all-ternary pair | Joint all-low-bit alphabet pair | Four-bit pair |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 7 | .03515625 | .94140625 | .05078125 | .03515625 | unavailable |
| 8 | .03515625 | .09765625 | .05078125 | .03515625 | unavailable |
| 9 | .01953125 | .01953125 | .05078125 | .03515625 | .01953125 |
| 12 | 0 | 0 | .05078125 | .03515625 | .01953125 |

"Isolated-response allocation" gives each candidate its *exact* error through the rest of the original network: `||(I+B)(a-A)D||²_F` for A, and `||(b-B)(I+A)D||²_F` for B. It chooses both candidates and their byte split to minimize the sum of those scores. This is a stronger local control than unweighted matrix rounding. The joint oracle enumerates every allowed pair at each byte bound and evaluates its actual composed output. Both are allowed to choose the four-bit and exception images. At nine bytes the standard four-bit pair already catches up; at twelve bytes a paid exception to the four-bit A image and an ordinary four-bit B image reproduce the exact map. No claim of a universal ternary advantage survives that comparison.

At seven bytes, the joint oracle chooses

```text
a = [[ .5,  .5],             b = [[  0, -.75],
     [ .5, -.5]]                 [-.75, 1.5]]
```

A uses a ternary half-unit scale; B uses the four-symbol positive alphabet and a three-quarter-unit scale. Its isolated A and B squared errors are 2.55078125 and 32.26953125. Their *linearized combined* error is 19.3984375, yet the exact composed error is .03515625. Writing `E_A=(I+B)(a-A)D` and `E_B=(b-B)(I+A)D`, the missing term is `(b-B)(a-A)D`. Its own squared norm is 18.80078125; it cancels the other terms. The locally selected pair has isolated errors .09765625 and .80078125, but its composed error is .94140625. Even a coupled **linearized** sensitivity estimate around the source misses the winning seven-byte pair. The exact pair search finds a different factorization of nearly the same map.

These rates are 7, 9 and 12 bits per original weight, respectively, because the matrices have only four elements each and scale/header overhead is large. They must not be compared numerically with Qwen's 1.727-BPW image. The toy preserves anisotropic inputs, two residual boundaries, per-matrix scales, byte-exact side information and the interaction between downstream and upstream errors. It omits nonlinearities, normalization, changing activation distributions and token loss. Large deviations of hidden state might fail immediately at any of those omitted boundaries.

The quality computation expands the packed images and uses ordinary floating-point matrix products. A direct low-bit consumer would read the mode byte, two packed code bytes and two FP16 scales for the seven-byte case, decode up to eight codes, perform two 2x2 matvecs, four output-scale multiplications and four residual additions. An exception additionally reads its coordinate and FP16 replacement and requires an override. Input, hidden and output remain ordinary two-coordinate activations; an FP16 implementation has four bytes at each boundary, and spilling the hidden state writes and rereads four bytes. Materializing both expanded 2x2 matrices would add sixteen bytes of transient BF16 weights. Neither inference speed nor FP16-rounded composed quality is measured here. The oracle pays *stored model bytes*, not an imaginary free decoder.

This counterexample argues for testing joint code/scale allocation against the **full** composed loss, with the four-bit image in the candidate pool. A discriminating Qwen transfer is to take adjacent residual blocks from the fixed ternary image, allow jointly exchanged trits/scales and paid high-precision exceptions under a fixed complete-image byte cap, and select on fresh training text while checking held next-token NLL. Record hidden-state drift and compare with independent downstream-weighted allocations and a matched four-bit allocation. If normalization or gating destroys the apparent compensating pair on held text, this toy has identified the boundary of the trick rather than a conversion method.

Run from the checkout with `OPENBLAS_NUM_THREADS=1 python research/ternary-toys/rate-allocation/oracle.py`. The script regenerates [results.json](results.json), including winning codewords, scales, byte counts, and seven-byte error decompositions. NumPy is the only dependency. It enumerates all pairs in this declared catalogue, not all possible scales, continuous corrections, four-bit codewords or network functions.
