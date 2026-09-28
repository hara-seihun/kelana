# One extract for a complete SiLU-sign observer

The three-trit sign observer has a smaller *shared input coordinate* than the two-mask construction in [README.md](README.md). For real SiLU and nonzero ternary gate and up weights, let

```
F(g,u,x) = sign(SiLU(g·x) (u·x)),  x in {-1,0,1}³.
q(x) = (x₀+1) + 3(x₁+1) + 9(x₂+1).
r(x) = min(q(x), 26-q(x)).
```

The real sigmoid is strictly positive. Thus `F = sign((g·x)(u·x))` and `F(g,u,-x) = F(g,u,x)`. Base-three digit complement gives `q(-x) = 26-q(x)`. Every member of this 676-map family factors through `r`, which has 14 states. This is not a claim about SiLU magnitude or the trained A4/A8 quantizer.

Four bits are **necessary** for one fixed carrier serving the entire family. If two inputs have different nonzero-coordinate supports, choose `g=u=e_i` on a coordinate present in only one. Their observations are 1 and 0. If their supports agree, take one shared nonzero coordinate `i`. The observers `g=e_i,u=e_j` for every other supported `j` reveal all pairwise relative signs. Equal responses force the vectors to be identical or global negatives. Zero has its own support. The joint fibers are exactly the 14 sign orbits; no carrier with 13 or fewer states serves all 676 observers without other input-dependent state. This says nothing about a subset of the observers or a particular trained weight family.

For each fixed `(g,u)`, prepare one 28-bit word. Put `F(g,u,x) & 3` in bits `2r,2r+1`. Signed two-bit values `0,1,3` mean `0,+1,-1`. Then `v_bfe_i32 word, 2r, 2` returns the entire observed map. [`sign_orbit.py`](sign_orbit.py) checks all 18,252 weight/input cases against the existing independent target, checks every opposite-input pair and the complete joint-fiber partition. [`sign-orbit-results.json`](sign-orbit-results.json) retains the census. All 676 pairs yield 182 distinct literal words, the same number of distinct endpoint maps as the two-mask implementation.

[`sign_orbit.s`](sign_orbit.s) assembles on gfx1151. `v_bfe_i32` sign-extends the selected two-bit field; the example word `0x0130107c` is an inline 32-bit literal. Its instruction is 12 bytes. The previous two unsigned one-bit extracts and subtraction are 28 bytes total. The cost depends on where the input coordinate lives:

| Available at entry | New per-lane data instructions for N consumers | Old two-mask instructions | New code bytes versus old |
| --- | ---: | ---: | ---: |
| `o=2r` | `N` | `3N` | `12N` versus `28N` |
| `r` | `N+1` | `3N` | `12N+4` versus `28N` |
| original `q` | `N+3` | `3N` | `12N+12` versus `28N` |

From `q`, the shared preparation is `sub(26,q)`, unsigned `min(q,26-q)`, and left shift by one, all four-byte instructions. The one-consumer route is **four instructions instead of three** despite its smaller code size. Two consumers sharing `q` take five instead of six, before accounting for live registers, coefficient access, scheduling or construction of `q` itself. An upstream producer of the 4-bit orbit coordinate or a long family of observers is the natural place to test this. A subsequent operation that needs `x` rather than its orbit must carry more state or pay for a different boundary; no inverse exists.

This construction observes only a sign. It does not preserve Bonsai's floating SiLU amplitude, dynamic hidden scale, output-head logits or native FP32 operation order. No GPU timing or full-model benefit is claimed. The next native experiment should supply one `q` to several sign observers in one wave, measure register/code pressure against the two-mask path, and include the producer of `q`. For a trained hidden quantizer, first determine whether its entire required continuation is sign-invariant. The trained 27-state output tables are not assumed to be.

From this directory:

```
python3 sign_orbit.py
llvm-mc -triple=amdgcn-amd-amdhsa -mcpu=gfx1151 --show-encoding sign_orbit.s
```
