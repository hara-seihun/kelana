# Nineteen observations determine the whole three-trit gated map

The rank 19 in [the whole-map search](README.md) came from random networks. Here it is exact for the entire declared family, with a 19-value construction and a lower-bound certificate. This applies to integer arithmetic on all 27 states of `{-1,0,1}^3` and arbitrary finite width:

```
F(x) = sum_i c_i relu(g_i · x) (u_i · x),
g_i,u_i in {-1,0,1}^3, c_i in {-1,+1}.
```

It says nothing about SiLU, scaled FP32 projections, quantizer cells or a complete Bonsai FFN.

## The construction

Choose one representative from each nonzero pair `{x,-x}`, taking the one whose first nonzero coordinate is positive. There are 13. Evaluate `F` at all 13 representatives and at the negatives of six of them:

```
e0, e1, e2, e0+e1, e0+e2, e1+e2.
```

That is 19 evaluations of the original gated network. No gate or hidden value must be retained at the observation boundary. For each of those six pairs, form `Q(x)=F(x)+F(-x)`. Since `relu(t)-relu(-t)=t`, for every `x`

```
F(x)+F(-x) = sum_i c_i (g_i · x)(u_i · x) = Q(x).
```

Write `q_i=Q(e_i)` and `q_ij=Q(e_i+e_j)-q_i-q_j`. Then for every three-trit input

```
Q(x) = sum_i q_i x_i² + sum_{i<j} q_ij x_i x_j.
F(-x) = Q(x)-F(x).
F(0) = 0.
```

The six measured sums reconstruct the six integer coefficients without division. The other eight negative-pair values follow by signed integer additions and subtractions. The executable [certificate](rank-certificate.py) checks this reconstruction for all 676 nonzero ternary gate/up atoms at every input, so linearity extends it to every width and every signed output coefficient. All arithmetic in this construction is unbounded integer arithmetic; a fixed-width lowering needs its own overflow bound.

## Why 19 cannot be reduced in this observation model

The reflection identity gives an upper bound of six independent homogeneous quadratic coefficients plus thirteen independent odd pair values. This is a 19-dimensional vector space over the rationals. The certificate scans the 676 atoms in lexicographic gate/up order, selects 19 independent columns over the prime field `F_1000003`, and computes the determinant of their 19 by 19 sample matrix. The determinant is **24 modulo 1000003**, so the columns are independent over the rationals. Combined with the upper bound, the rank is exactly 19. The checker prints every selected gate/up pair and recomputes the determinant from the defining map, not from a stored table.

Any scheme that observes fewer than 19 scalar values of `F` at fixed input states and must reconstruct every possible map in this unbounded-width family fails. Its evaluation map has rank at most 18, whereas the family contains the integer linear combinations of these 19 independent atoms. This is a bound on fixed state probes and linear-span information, not on all ISA programs: weight-aware algorithms can inspect coefficients, and a lookup instruction reads a wave-distributed table in one operation.

## Work saved and the next native question

For a fixed network whose 27-value lookup table is prepared from its weights, `F(0)` is already known. Direct construction evaluates 26 nonzero states; this scheme evaluates 19, saving **7/26 gated-network evaluations**, or 26.9%, then performs six pair sums, three cross-coefficient constructions and eight small quadratic reconstructions. At width 256, that is 1,792 fewer individual gated-atom evaluations before reconstruction. The table still holds 27 values and the wave lookup still needs all 27 lanes enabled. No hot-loop GPU instruction is removed by this identity alone.

A second construction can compute the six quadratic coefficients straight from the weights and evaluate `F` only on the 13 positive representatives. That trades 13 expensive network evaluations for six coefficient accumulations per hidden unit. The right construction depends on table preparation frequency, output width, integer overflow and whether the producer already has a quadratic representation. A useful native experiment would time both table builders against direct 26-state generation on equal sets of fixed weights, including materialization, and then pass the identical 27-word tables through the existing `ds_bpermute_b32` consumer. The arithmetic saved offline is not an inference throughput claim until a real repeated table-generation boundary is found.

Run `python3 research/discovery/whole-map-search/rank-certificate.py` from the Kelana root. It finishes in under a second.
