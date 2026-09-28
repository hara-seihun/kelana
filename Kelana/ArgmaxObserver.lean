import Std

namespace Kelana.ArgmaxObserver

/-- This is a scaled-integer score contract, not a claim about floating evaluation. -/
theorem upper_of_suffix {score evaluated suffix radius : Int}
    (decomposition : score = evaluated + suffix)
    (bounded : suffix ≤ radius) : score ≤ evaluated + radius := by
  omega

/-- An independently bounded numerical error transfers its upper endpoint.
    No GPU error interval is assumed by this theorem. -/
theorem upper_of_error {actual ideal evaluated suffix radius error : Int}
    (decomposition : ideal = evaluated + suffix)
    (bounded : suffix ≤ radius)
    (roundoff : actual ≤ ideal + error) :
    actual ≤ evaluated + radius + error := by
  omega

/-- Finite greedy comparison keeps the smallest index on equal scores.
    Earlier rows need strict exclusion; later rows need only non-strict exclusion. -/
theorem certified_smallest_argmax {n : Nat} (actual upper : Fin n → Int) (c : Fin n)
    (valid : ∀ i, actual i ≤ upper i)
    (earlier : ∀ i, i < c → upper i < actual c)
    (later : ∀ i, c < i → upper i ≤ actual c) :
    (∀ i, i < c → actual i < actual c) ∧
    (∀ i, c < i → actual i ≤ actual c) := by
  constructor
  · intro i hi
    exact Int.lt_of_le_of_lt (valid i) (earlier i hi)
  · intro i hi
    exact Int.le_trans (valid i) (later i hi)

/-- A candidate lower endpoint suffices to compare against each row's upper
    endpoint. The candidate generator itself may be approximate. -/
theorem certified_with_lower {n : Nat} (actual upper : Fin n → Int)
    (c : Fin n) (candidateLower : Int)
    (valid : ∀ i, actual i ≤ upper i)
    (lower : candidateLower ≤ actual c)
    (earlier : ∀ i, i < c → upper i < candidateLower)
    (later : ∀ i, c < i → upper i ≤ candidateLower) :
    (∀ i, i < c → actual i < actual c) ∧
    (∀ i, c < i → actual i ≤ actual c) := by
  apply certified_smallest_argmax actual upper c valid
  · intro i hi
    exact Int.lt_of_lt_of_le (earlier i hi) lower
  · intro i hi
    exact Int.le_trans (later i hi) lower

end Kelana.ArgmaxObserver
