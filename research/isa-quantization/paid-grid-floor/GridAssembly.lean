import Std

namespace Kelana.PaidGrid

/-- One disjoint unmatched-column charge is additive to a pair charge; the
shared covariance and shifted-coordinate penalties are charged only once. -/
theorem additive_floor (energy penalty paired unmatched pairFloor gridFloor : Int)
    (minorant : paired + unmatched ≤ energy + penalty)
    (pair_bound : pairFloor ≤ paired)
    (grid_bound : gridFloor ≤ unmatched) :
    pairFloor + gridFloor - penalty ≤ energy := by
  omega

end Kelana.PaidGrid
