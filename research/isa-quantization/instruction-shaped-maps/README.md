# Quantizing toward a one-dot response family

The ternary 2×2 radix-64 result packs several integer outputs into one dot on a restricted source domain. Here the target is instead a generic rational 2-output, 4-input linear map. The cheapest useful one-dot family is a shared integer response, followed by two output scales. It wins decisively near a shared-response map and fails decisively on a noncollinear control at the same eight static bytes. This is a finite-domain construction and obstruction, not a native latency result.

Let the dynamic producer supply `u ∈ {0,1,2}^4` in four unsigned byte lanes, and let the teacher be `F(u)=Tu`. Store four signed byte coefficients `k` and two FP16 numbers `d`. One `V_DOT4_I32_IU8` computes `r=k·u`, and the output boundary computes `(d0*r,d1*r)`. The stored image is four code bytes plus four decoder bytes. The baseline stores eight signed four-bit codes in four bytes and two FP16 row scales in four bytes. It computes one nibble dot per row and scales both results. Both routes require the producer's byte/nibble packing, integer-to-float conversion and two final multiplies; the one-dot route does **not** get those operations for free. The exact counts of pack and conversion instructions and native time are not measured. The comparison is one signed-byte dot against two signed-nibble dots, not a claim that one is faster.

For uniform `u`, mean squared output error is `Σ_i (Ti−d_i k)^T M (Ti−d_i k)`, where `M=E[uu^T]=(2/3)I+11^T`. This is a consumer-aware fit: ordinary weight Frobenius error would omit the nonzero input mean. Given a proposed `k`, the best real decoder is `d_i=(Ti M k)/(k^T M k)` before FP16 rounding. Searching `k` is a short integer-lattice direction search, not independent weight rounding. More generally for `m` outputs and `n≤4` byte inputs, the same dot shares one integer response across all outputs. The four-byte operand and `2m` decoder bytes are paid; a wider layer must reuse this family in blocks and account for every output scale.

A concrete perturbed rational teacher is

```
k = (1,3,9,27)
T0 = k
T1 = (3/4)k + (0,1,-1,2)/64
one-dot decoder d = (1,3/4), both exactly FP16
```

Its exact uniform-domain output MSE is `1/512 = .001953125`. The strong scalar control exhausts all `16^4=65,536` signed-q4 vectors **per row**, permitting an arbitrary real least-squares scale for each candidate, which is stronger than the charged FP16 scales. Its optimum is `644/435 + 381269/445440 = 2.3363977191` MSE. Both winning q4 rows use `(0,-1,-3,-8)`, at respective ideal real scales `-483/145` and `-23209/9280`. Even giving q4 uncharged infinite scale precision cannot bridge the gap. The first row's wide integer ratio is what q4 cannot represent at eight total bytes; the shared-response assumption saves a dot while buying larger per-coordinate integers. This is a deliberately near-rank-one witness, not evidence that generic matrices have this structure.

The noncollinear control replaces `T1` with `(7,-4,13,-2)`. Its independently optimized q4 control has MSE `644/435 + 103/249 = 1.8941143886`. The displayed one-dot `k,d` has MSE `664.1666666667`, but this is not merely a poor search: **every** shared-response one-dot map with any real `k` and real decoder has MSE at least `173.0685143957`. This follows by taking the smaller squared singular value of `T M^(1/2)`, equivalently the smaller eigenvalue of

```
T M T^T = (1/3) [[6440, 1796], [1796, 1064]].
```

The byte/FP16 restrictions can only raise that lower bound. It excludes every one-dot *linear two-scale endpoint* on this unstructured teacher, not one-dot carriers with nonlinear lookup decoders, nonlinear input preparation or additional dots.

There is a revealing catch. Here `k=(1,3,9,27)` is an injective base-three code for all 81 inputs. An arbitrary decoder could reproduce **either** teacher exactly after the same dot. For a generic two-output table of FP16 responses that decoder occupies `81×2×2=324` bytes, requires a lookup, and no longer competes with the eight-byte image. Thus rank-one is a boundary restriction, not an information-theoretic property of the dot. Fitting the decoder and charging its storage and operations is essential. Conversely, a real shared output response can make the tiny linear decoder genuinely cheaper.

[`experiment.py`](experiment.py) exhausts the q4 control with integer arithmetic and cross-multiplied rational losses, then reports the rank-one spectral bound. [`result.json`](result.json) is its output. Run from the repository root with `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/isa-quantization/instruction-shaped-maps/experiment.py`. No fit queries to a model or stochastic calibration are used: the 81 inputs determine `M` exactly. The numeric singular value and shown one-dot losses use ordinary float64 evaluation; the q4 optimum is exact rational arithmetic and the planted one-dot loss follows directly from `(0,1,-1,2)^T M (0,1,-1,2)/64²=1/512`.

This construction differs from radix-64's fixed integer endpoint. It quantizes the *entire real map* toward a shared-response subfamily and spends its output precision in FP16 decoder coefficients. The next credible transfer test would fit `k,d` on actual quantized-producer activations and compare against a calibrated scalar format at equal complete bytes and full consumer loss. A table decoder, different producer packing or cheap continuation could change the frontier, but each needs its own bill.
