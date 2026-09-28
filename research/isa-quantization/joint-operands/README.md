# A shared integer shear for both operands

A non-diagonal, unimodular change of coordinates can make a correlated activation pair fit in two signed two-bit fields while leaving every gate/up weight in signed int8. This is an exact integer construction with one shared input code for all consumers, not another expert-specific diagonal fit. It saves two packed input bytes per 16 pairs against exact independent scalar fields, but adds 16 subtractions per token and four static descriptor bytes. It does not beat an int8 input on execution or establish a useful model replacement.

## The map and the finite certificate

For each pair let `x=(a,a+d)`, where `a,d ∈ {-1,0,1}`. Every pair has nine legal states. Use the same integer basis for every consumer:

```
U = [[1, 0], [-1, 1]]
y = U x = (a,d)
U^-1 = [[1, 0], [1, 1]]
w' = w U^-1 = (w0+w1, w1)
w · x = w' · y
```

The input fields each need two bits and decode directly to signed bytes in `{-1,0,1}`. The original independent numeric coordinates have three and five values respectively, requiring two plus three fixed-width bits for an *exact separable scalar* input code. The matrix changes both dynamic input and every static row. No output relabeling, weight reconstruction, or decoder table is involved. The identity holds over all integers, not just the nine states, whenever the static result remains representable.

For the signed int8 experiment, each original weight is independently drawn from `[-63,63]`. Hence `w0+w1 ∈ [-126,126]` and both new coefficients are signed int8. This argument covers arbitrary rows in that box, not only the sampled rows. With 16 independent pairs, the full sum's absolute value is at most `16*2*127=4064`, well inside signed int32. All eight rows, representing gate and up for each of four experts, consume the **same** `y`; no expert-specific input code or per-expert descriptor exists. The weight image is 8 rows times 32 signed bytes, 256 bytes before and after. Store `U` as four signed bytes, once for the bank. Its inverse is a preparation calculation, not extra online model data.

[`search.py`](search.py) enumerates all 104 determinant-±1 2×2 matrices with entries in `[-2,2]`. Eight have at most four numeric states per transformed input coordinate and retain signed-byte coefficients for every sampled row. The minimum sum of fixed field widths is four bits per pair. It checks the identity for every one of the nine states on every row and pair, then checks 256 deterministic complete 16-pair inputs against all eight outputs. [`results.json`](results.json) records the seed, coefficients, rank witness and costs. This is a small exact search reduction: reject a common basis using activation-state counts and the **union** of consumers' weight-range constraints before fitting a single quantizer. Search time is a tiny local Python run, not a trained-model fit.

The first pair's rows 0 and 1 have determinant 4156, so its live two-output map has rank two. If an arithmetic reader forms `W * (q0(x0),q1(x1))` from independent scalar numeric reconstructions and must exactly match these outputs, full rank forces both reconstructions to equal the original coordinates on the domain. The second coordinate visits five values, so a two-bit independent numeric field cannot do it. This lower bound does **not** cover a four-bit *joint* index for the nine legal states with an arbitrary decoder. Such an index exists; its decoder and consumer work must be charged. Nor does it say that an approximate four-bit scalar fit is bad.

## What would execute

Prepare 16 differences `x1-x0` once per token, quantize or pack the 32 resulting ternary lanes into eight bytes, then expand signed lanes for dots. Prepare transformed signed-byte weights offline. On a four-lane signed-byte dot instruction, 32 inputs take eight dot instructions per output row, or 64 dots across the eight rows, in either coordinate system. The arithmetic identity and operand bounds establish signed-byte/int32 *instruction semantics* if lanes are supplied. There is no assembled gfx1151 program, packing schedule, or native timing here. The stored compact input is not the register format: after expansion both paths present 32 signed bytes to each dot, and the transformed path pays subtraction. A direct Q8 activation uses 32 input bytes but avoids these subtractions and bit unpacking. At 16 pairs, exact scalar fields use ten packed bytes and the shared shear uses eight; both use the same 256 weight bytes. The shear pays four descriptor bytes, so even one token's combined static-plus-input byte count is higher. With `T` uses of the same bank it saves `2T-4` bytes in that narrow stored-byte accounting, without claiming lower latency or total model BPW.

The source input must be available before its conventional quantizer clips `x1`; transforming already clipped fields cannot restore the lost states. The router or other observers may continue using the original producer input while this one preparation feeds the covered experts. An application across all experts must check signed-byte headroom for **all** their gate/up rows, and must keep one preparation shared across all routed slots. In a complete model the nine-state producer restriction is the major missing premise. Without it `x1-x0` need not fit two bits. A real-input test should first measure residual-coordinate cardinalities/error and the range growth of the transformed weights across the whole live bank, then compare response and native time to unchanged weights with Q8 input and a calibrated scalar quantizer. The existing [shared-diagonal study](../../quantization-discovery/representations/joint-operands/README.md) already shows GGUF/Q8 winning decisively; this exact toy neither refutes nor replaces that result.

Run `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/isa-quantization/joint-operands/search.py` from the Kelana root. The script uses only the standard library and rewrites the compact JSON certificate.
