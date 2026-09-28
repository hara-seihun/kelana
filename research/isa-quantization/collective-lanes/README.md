# A two-lane orbit code

A pair of output lanes can share one five-coordinate weight row if the second lane sees either the same input order or its reversal. Choose the row *and* the input placement to fit the two-output map. This gives a 16-bit executable-description candidate for ten five-level weights. The result is a finite rate/distortion construction, not a faster GPU kernel. In particular, the reversal costs input preparation that an independent-row dot does not need.

## Contract and exact reduction

The teacher has two integer rows `A,B ∈ {-2,-1,0,1,2}^5`. Dynamic inputs range over all `3^5` vectors in `{-1,0,1}^5`, uniformly for the distortion calculation. The candidate stores `q ∈ {-2,-1,0,1,2}^5` and a placement bit `p`. It computes

```
output lane 0:       q · x
output lane 1, p=0:  q · x
output lane 1, p=1:  q · reverse(x)
```

Thus its matrix is `(q, Pq)` where `P` is either identity or reversal. Both outputs are ordinary signed integer dots. The observed endpoint is **two separate scalar outputs in their original lane order**; no output relabeling is free. The input producer must deliver all five activation bytes to both lanes. If it does not, that delivery is another paid operation.

Write `D(T,Q)=E_x Σ_o ((T_o-Q_o)·x)^2`. Independence and `E[x_i x_j]=0` for `i≠j`, `E[x_i²]=2/3`, give

```
D(T,(q,Pq)) = (2/3) Σ_i [(A_i-q_i)² + (B_{P(i)}-q_i)²].
```

For either placement, **each `q_i` can be chosen separately**: take the nearest member of the allowed five-level alphabet to `(A_i+B_{P(i)})/2`, with the smaller level breaking ties. Then compare the two placements. This reduces `2·5^5` candidate evaluations to ten coordinate fits. It extends to unequal output weights by replacing the average with their weighted average. It does *not* extend as a coordinatewise rule to correlated input covariance; its off-diagonal terms couple the `q_i` choices. Placement is optimized against the same complete consumer distortion as the code, rather than selected from a nearest-weight row fit afterward.

Distinct `q,p` descriptions collide only when `q=reverse(q)`, for which the two placements are the same matrix. There are `2·5^5−5^3=6,125` distinct matrices. Since the full input domain contains each coordinate probe, distinct matrices are distinct observed maps. Any fixed-width exact code for this entire family needs at least 13 bits. Five signed three-bit levels plus one placement bit use 16 bits, so a two-byte payload suffices without a model-specific dictionary. Ten independent five-level weights need at least `ceil(log2(5^10))=24` bits for their *whole* family. This is a family-capacity fact, not a lower bound on coding a single model.

## Finite witnesses and fair controls

[`finite.py`](finite.py) searches the two placements, replays all 6,250 raw descriptions for each witness, and checks the selected output errors directly on all 243 inputs. It also fits stronger independent scalar controls with an **oracle-selected shared alphabet**, free of alphabet metadata. The three-level scalar has `ceil(log2(3^10))=16` index bits, so it fits two bytes using radix-3 packing. The four-level scalar has 20 index bits and needs three bytes. Allowing the controls to pick their best three or four values from all five for *each* teacher only favors them; implementing those per-teacher choices would require further stored metadata. Five-level independent scalar needs three bytes even with ideal 24-bit coding. Errors below are mean summed squared output error over the declared inputs.

| teacher | collective, 2 bytes | scalar 3, 2 bytes | scalar 4, 3 bytes |
| --- | ---: | ---: | ---: |
| `A=(-2,-1,0,1,2)`, `B=reverse(A)` | 0 | 8/3 | 4/3 |
| same, but middle entry of `B` changes from 0 to 1 | 2/3 | 6/3 | 2/3 |
| seeded unstructured pair in `results.json` | 10/3 | 6/3 | 2/3 |

The planted first row uses all five levels, each twice across the matrix. A scalar code with only three shared levels must miss two levels, giving at least four unit-squared weight errors; four levels must miss one, giving at least two. The complete-domain output error is `2/3` times that weight error. The reversal code represents it exactly. This is a deliberately structured witness, not evidence that real matrices contain these paired orbits. A one-coordinate perturbation retains a two-byte collective advantage over the three-level control, but the seeded unstructured pair reverses the ordering. The four-level control is a serious three-byte alternative, even on the perturbation.

Reproduce the deterministic witnesses and their exact brute-force comparison from the Kelana root with `python3 research/isa-quantization/collective-lanes/finite.py`. [`results.json`](results.json) is the captured output. The exhaustive replay is a check on the reduction for these three targets, not a search over all real-valued teachers or all instruction programs.

## Execution bill, not an opcode win

A plausible signed-byte reader expands the five three-bit `q` values into two dot4 operands. Put `u_i=x_i+1` into unsigned byte slots; initialize the signed dot accumulator with `-Σ_i q_i` so the result is `q·x`. One lane uses `(u0,u1,u2,u3)` then `u4`; its partner uses `(u4,u3,u2,u1)` then `u0` when `p=1`. Both need two four-byte dot groups and five weight-byte extractions, just as a five-coordinate independent scalar reader needs two groups per lane. The reversed lane needs a byte permutation spanning the first input word and the `u4` word, plus selection of the last input byte. A wave-level instruction doing this only in half the lanes still consumes issue capacity. If the inputs arrive one coordinate per lane, broadcasting all five into both output lanes is an additional cost. No step here presumes a free cross-lane shuffle.

The two-byte figure is **unique cold model payload** for the pair, not hot operand bytes or physical traffic. A decoder can prepare distinct hot signed-byte rows and remove the reversal, but then it stores or keeps ten expanded bytes rather than one five-byte row, and pays that decoding and placement at least once per reuse epoch. Alternately it can share `q` and prepare a reversed activation word at runtime. The independent two-byte ternary control also has a nontrivial radix-3 reader; its packing is not magically free. Per-teacher scalar alphabets and any model-specific lookup tables would add bytes to its control, whereas a globally fixed alphabet adds none. Neither a single static image nor a semantic orbit match establishes a native gain.

The relevant accounting for a tile of `R` row pairs used on `T` input vectors is: cold bytes per pair; prepared/hot bytes per pair; input packing and any reversal per vector (amortized across pairs only if the layout is genuinely shared); dot issue for `2R` output lanes; lane communication; occupancy/registers; and endpoint conversion if a subsequent consumer wants another layout. The candidate offers a rate/error option and a reduced search. Native adoption would require measuring this full tile against an independent scalar reader with the same input layout and accepted response error. With `p=0`, the communication charge vanishes but the two rows must fit a common `q`; the unstructured witness chooses that route and still loses.

This is different from the [radix-64 one-dot construction](../../toy2/radix64/README.md): it shares an approximated weight orbit across *outputs*, does not pack two results into a single dot accumulator, and preserves the two conventional scalar endpoints. It also does not use the [joint-observer carrier](../../discovery/joint-observer/README.md)'s eleven-state quotient. Here the matrix approximation is chosen inside a two-lane layout family, and the dot work remains unchanged.
