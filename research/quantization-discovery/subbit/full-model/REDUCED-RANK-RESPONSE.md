# The frozen MLP hidden response was not exhausted by rank 32

The previous rank-32 correction got worse as the training sample grew, but it truncated the *coefficient* SVD after ridge fitting. That is the wrong metric for a response observed through a highly anisotropic hidden vector. Replacing it with the globally optimal continuous rank-constrained ridge solution changes the result on the same frozen layer-0 binary gate/up/down image. At 2,048 train positions, a paid FP16 rank-32 correction scores **.61904** held relative post-MLP squared error, versus **.66098** for coefficient truncation and **.65752** without correction. Rank 8 scores .63765, versus .65411 previously. More training positions improve rather than damage all three held ranks in this family.

| Train positions | Rank 8 held | Rank 16 held | Rank 32 held | Prior rank 32 held |
| ---: | ---: | ---: | ---: | ---: |
| 512 | .64647 | .64198 | .63467 | .65260 |
| 1,024 | .63788 | .63176 | .62194 | .65331 |
| 2,048 | .63765 | .63007 | **.61904** | .66098 |

The common held split contains 1,024 validation positions from the original-producer capture. The binary baseline scores .65752 there. Train errors for 512/1,024/2,048 positions at rank 32 are .39336/.42947/.44955, compared with their binary .56694/.56096/.55581. The larger training samples have different distributions, so compare held scores rather than ordering their train errors. This is an informative fixed-input response result, not language loss; this validation capture has already been inspected in preceding studies. No quantized producer, narrow V/O input, full-model forward or native timing is implied.

## Conditional optimum and its actual boundary

Let `X` contain centered frozen binary hidden vectors `silu(Gq x) * Uq x`, and let `Y` be the centered original-minus-binary MLP output. For the real-valued objective

`min_{rank(B) <= r} ||Y - X B||_F^2 + lambda ||B||_F^2`

set `A = X^T X + lambda I` and `C = A^(-1/2) X^T Y`. Completing the square leaves `||A^(1/2) B - C||_F^2` plus a constant. Eckart-Young therefore gives `B_r = A^(-1/2) C_r`, where `C_r` is the rank-r truncated SVD of `C`. This is a global optimum over **real linear rank-r corrections of the frozen hidden representation** for the stated regularized train objective, not an optimum over learned gate/up codes or model NLL. The script uses the nonzero singular space of the 512 to 2,048-row sample Gram to avoid a 3,072-dimensional inverse. The previous coefficient-SVD truncation is not equivalent unless hidden covariance is isotropic on its active subspace. Centering makes the intercept unpenalized; the ridge parameter is `0.01 trace(X X^T) / n`, matching the preceding panel.

After the continuous optimum, the program stores right and left factors and a fresh output intercept in FP16, then scores FP32 response products. FP16 rounding does not inherit the continuous optimality proof. The paid rank-8/16/32 increments are 67,584/133,120/264,192 bytes, or .000907/.001787/.003546 complete-model BPW over 596,049,920 unique parameters. Online work is 32,768/65,536/131,072 factor multiply-add terms plus output addition per token, on top of the existing frozen binary MLP. This is extra work, not cheaper inference yet, and the native layout, input casts and BF16 model rounding remain unpriced.

The result overturns the earlier claim that rank-32 capacity itself saturated. It does **not** make a frozen hidden patch a good final construction: .61904 is still large response error, and this correction cannot change which hidden directions gate/up produce or repair the narrow-value producer. Next fit the same covariance-aware rank family on MLP inputs produced *after* narrow V/O with later layers quantized, then test gold NLL before paying for a native factor consumer. In particular, compare it at equal bytes against jointly changed gate/up/down codes; the positive local result makes that comparison worth doing rather than dismissing rank from coefficient truncation.

`reduced_rank_response.py --train-rows {512,1024,2048}` regenerates `/path/to/workspace/data/kelana-subbit/full-model/mlp-optimal-response-{512,1024,2048}.json` with source, pinned capture and image hashes and all train/held scores. Run it with `/path/to/workspace/data/fish-s2-pro/venv/bin/python` from the Kelana root. This is a CPU panel, so GPU and Bonsai serving were untouched.
