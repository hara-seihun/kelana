import Kelana.ValuePairCoupling

namespace Kelana.ValuePairCode

open ValueCoordinateGauge (total)
open SharedSketchCovariance (total_congr total_add total_mul total_mul_right total_comm total_nonneg total_zero)

def pairEnergy (a b c x y : Rat) : Rat := a*x*x+2*b*x*y+c*y*y

/-- One actual finite minimum scan, with the earlier candidate winning ties. -/
def select (score : I → Rat) : I → List I → I
  | best, [] => best
  | best, x::xs => select score (if score x < score best then x else best) xs

theorem select_le_initial (score : I → Rat) (best : I) (xs : List I) :
    score (select score best xs) ≤ score best := by
  induction xs generalizing best with
  | nil => simp [select]
  | cons x xs ih =>
    simp only [select]
    have h := ih (if score x < score best then x else best)
    split at h <;> grind

theorem select_le_member (score : I → Rat) (best : I) (xs : List I)
    (x : I) (hx : x ∈ xs) : score (select score best xs) ≤ score x := by
  induction xs generalizing best with
  | nil => simp at hx
  | cons y ys ih =>
    simp only [List.mem_cons] at hx
    simp only [select]
    rcases hx with h | h
    · subst x
      have h0 := select_le_initial score (if score y < score best then y else best) ys
      split at h0 <;> grind
    · exact ih _ h

theorem select_mem (score : I → Rat) (best : I) (xs : List I) :
    select score best xs = best ∨ select score best xs ∈ xs := by
  induction xs generalizing best with
  | nil => exact Or.inl rfl
  | cons x xs ih =>
    simp only [select]
    have h := ih (if score x < score best then x else best)
    rcases h with h | h
    · split at h <;> grind
    · exact Or.inr (List.mem_cons_of_mem x h)

/-- The represented two-coordinate source metric is an exact Gram quadratic
when its three fields are these sums. Rounding the fields is separate. -/
theorem stacked_gram (rows : List O) (a b : O → Rat) (x y : Rat) :
    total rows (fun o => (a o*x+b o*y)*(a o*x+b o*y)) =
      pairEnergy (total rows (fun o => a o*a o))
        (total rows (fun o => a o*b o))
        (total rows (fun o => b o*b o)) x y := by
  calc
    _ = total rows (fun o => x*x*(a o*a o)+2*x*y*(a o*b o)+y*y*(b o*b o)) := by
      apply total_congr rows; intro o ho; grind +ring
    _ = _ := by
      rw [total_add, total_add, total_mul, total_mul, total_mul]
      unfold pairEnergy
      grind +ring

/-- Exhaustive selection includes the previous two digits, so local energy
cannot increase. This says nothing about unrepresented output interactions. -/
theorem grid_nonincrease (digits : List (I × J)) (initial : I × J)
    (left : I → Rat) (right : J → Rat) (a b c : Rat) :
    let score := fun ij : I × J => pairEnergy a b c (left ij.1) (right ij.2)
    score (select score initial digits) ≤ score initial := by
  dsimp only
  exact select_le_initial (fun ij : I × J => pairEnergy a b c (left ij.1) (right ij.2)) initial digits

/-- The exact two-coordinate conditional quadratic can be minimized by a
nearest one-dimensional residual for every fixed first digit. -/
theorem conditional_square (a b c x y : Rat) :
    c*pairEnergy a b c x y =
      (c*y+b*x)*(c*y+b*x)+(a*c-b*b)*x*x := by
  unfold pairEnergy
  grind +ring

def normSquared (outputs : List O) (x : O → Rat) := total outputs (fun o => x o*x o)
def dot (outputs : List O) (x y : O → Rat) := total outputs (fun o => x o*y o)
def response (outside : List I) (A : O → I → Rat) (r : I → Rat) (o : O) :=
  total outside (fun i => A o i*r i)

/-- The complete observer keeps cross-pair/token and fixed K/source effects.
Here x and y are the old/new changed block responses; A*r is everything else. -/
theorem complete_change (outputs : List O) (outside : List I)
    (A : O → I → Rat) (r : I → Rat) (x y : O → Rat) :
    normSquared outputs (fun o => response outside A r o+y o) -
      normSquared outputs (fun o => response outside A r o+x o) =
    normSquared outputs y-normSquared outputs x +
      2*total outside (fun i => r i*dot outputs (fun o => y o-x o) (fun o => A o i)) := by
  have point : ∀ o, (response outside A r o+y o)*(response outside A r o+y o) =
      (response outside A r o+x o)*(response outside A r o+x o) +
      (y o*y o-x o*x o) + 2*(y o-x o)*response outside A r o := by
    intro o; grind +ring
  have hsum := total_congr outputs _ _ (fun o _ => point o)
  have hdiff : total outputs (fun o => y o*y o-x o*x o) =
      normSquared outputs y-normSquared outputs x := by
    have h := total_add outputs (fun o => y o*y o-x o*x o) (fun o => x o*x o)
    have hc : total outputs (fun o => y o*y o-x o*x o+x o*x o) = normSquared outputs y := by
      apply total_congr outputs; intro o ho; grind +ring
    rw [hc] at h
    unfold normSquared at *
    grind
  rw [total_add, total_add, hdiff] at hsum
  have cross : total outputs (fun o => 2*(y o-x o)*response outside A r o) =
      2*total outside (fun i => r i*dot outputs (fun o => y o-x o) (fun o => A o i)) := by
    calc
      _ = 2*total outputs (fun o => total outside (fun i => r i*((y o-x o)*A o i))) := by
        rw [← total_mul]
        apply total_congr outputs
        intro o ho
        unfold response
        have h : total outside (fun i => r i*((y o-x o)*A o i)) =
            (y o-x o)*total outside (fun i => A o i*r i) := by
          rw [← total_mul]
          apply total_congr outside; intro i hi; grind +ring
        rw [h]
        grind +ring
      _ = _ := by
        rw [total_comm]
        congr 1
        apply total_congr outside
        intro i hi
        unfold dot
        exact total_mul outputs (r i) _
  rw [cross] at hsum
  unfold normSquared at *
  grind

private theorem weighted_spike [DecidableEq I] (xs : List I) (c : I → Rat)
    (j : I) (lambda : Rat) (hn : xs.Nodup) (hj : j ∈ xs) :
    total xs (fun i => (if i = j then lambda else 0)*c i) = lambda*c j := by
  induction xs with
  | nil => simp at hj
  | cons i xs ih =>
    obtain ⟨hi, ht⟩ := List.nodup_cons.mp hn
    simp only [List.mem_cons] at hj
    rcases hj with h | h
    · subst i
      have hz : total xs (fun i => (if i = j then lambda else 0)*c i) = 0 := by
        calc
          _ = total xs (fun _ => (0 : Rat)) := by
            apply total_congr xs
            intro i hi'
            have hne : i ≠ j := by intro eq; subst i; exact hi hi'
            simp [hne]
          _ = 0 := total_zero xs
      change (if j = j then lambda else 0)*c j + total xs (fun i => (if i = j then lambda else 0)*c i) = lambda*c j
      rw [hz]
      grind
    · have hne : i ≠ j := by intro eq; subst i; exact hi h
      change (if i = j then lambda else 0)*c i + total xs (fun i => (if i = j then lambda else 0)*c i) = lambda*c j
      simp only [if_neg hne, Rat.zero_mul, Rat.zero_add]
      exact ih ht h

/-- A nonzero omitted coupling can reverse any fixed finite local gain.
The witness is an arbitrary rational outside coefficient, not a realizable
quantizer error claim. -/
theorem omitted_coupling_witness [DecidableEq I] (outside : List I)
    (c : I → Rat) (D : Rat) (j : I) (hn : outside.Nodup)
    (hj : j ∈ outside) (hc : c j ≠ 0) :
    ∃ r : I → Rat, D+2*total outside (fun i => r i*c i) = 1 := by
  let lambda : Rat := (1-D)/(2*c j)
  refine ⟨fun i => if i = j then lambda else 0, ?_⟩
  rw [weighted_spike outside c j lambda hn hj]
  have hz : 2*c j ≠ 0 := by grind +ring
  have hcancel : lambda*(2*c j) = 1-D := Rat.div_mul_cancel hz
  grind +ring

/-- Local response improvement is safe against every outside response in
this fixed linear span exactly when the change is orthogonal to that span.
No positive-definiteness or heuristic block-independence is assumed. -/
theorem all_outside_nonincrease_iff [DecidableEq I]
    (outputs : List O) (outside : List I) (A : O → I → Rat)
    (x y : O → Rat) (hn : outside.Nodup) :
    (∀ r : I → Rat,
      normSquared outputs (fun o => response outside A r o+y o) ≤
        normSquared outputs (fun o => response outside A r o+x o)) ↔
    normSquared outputs y ≤ normSquared outputs x ∧
      ∀ i ∈ outside, dot outputs (fun o => y o-x o) (fun o => A o i) = 0 := by
  let c := fun i => dot outputs (fun o => y o-x o) (fun o => A o i)
  let D := normSquared outputs y-normSquared outputs x
  constructor
  · intro safe
    have sz := safe (fun _ => 0)
    have dz := complete_change outputs outside A (fun _ => 0) x y
    have hz : total outside (fun i => (0 : Rat)*c i) = 0 := by
      simpa using total_zero (I := I) outside
    change _ = D+2*total outside (fun i => (0 : Rat)*c i) at dz
    rw [hz] at dz
    refine ⟨by dsimp [D] at dz; grind, ?_⟩
    intro i hi
    by_cases h : c i = 0
    · exact h
    · obtain ⟨r, hr⟩ := omitted_coupling_witness outside c D i hn hi h
      have hs := safe r
      have hd := complete_change outputs outside A r x y
      change _ = D+2*total outside (fun i => r i*c i) at hd
      rw [hr] at hd
      grind
  · rintro ⟨localGain, orthogonal⟩ r
    have h := complete_change outputs outside A r x y
    have hz : total outside (fun i => r i*dot outputs (fun o => y o-x o) (fun o => A o i)) = 0 := by
      calc
        _ = total outside (fun _ => (0 : Rat)) := by
          apply total_congr outside
          intro i hi
          rw [orthogonal i hi, Rat.mul_zero]
        _ = 0 := total_zero outside
    rw [hz] at h
    grind

end Kelana.ValuePairCode
