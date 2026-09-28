import Std

/-!
A kernel-checked combinatorial step in the diagonal certificate ceiling:
the cheapest matching of four coordinate prices charges at most half their
sum. The spectral and PSD parts of the family theorem are separate paper
arguments, replayed for a rational instance by toy.py.
-/
namespace Kelana.PairCovariance

/-- For sorted diagonal prices, pair the two cheapest with the two most
expensive. The resulting two-edge cost is bounded by half the total. -/
theorem two_smallest_at_most_half (a b c d budget : Int)
    (hab : a ≤ b) (hbc : b ≤ c) (hcd : c ≤ d)
    (hsum : a + b + c + d ≤ 2 * budget) : a + b ≤ budget := by
  omega

end Kelana.PairCovariance
