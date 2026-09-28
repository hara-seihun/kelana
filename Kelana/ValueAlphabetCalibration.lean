import Kelana.SharedSketchCovariance

namespace Kelana.ValueAlphabetCalibration

open ValueCoordinateGauge (total)
open SharedSketchCovariance

def mass (rows : List I) (w : I → Rat) := total rows w
def firstMoment (rows : List I) (w z : I → Rat) := total rows (fun i => w i*z i)
def secondMoment (rows : List I) (w z : I → Rat) := total rows (fun i => w i*z i*z i)
def cost (rows : List I) (w z : I → Rat) (c : Rat) :=
  total rows (fun i => w i*(z i-c)*(z i-c))

theorem cost_expansion (rows : List I) (w z : I → Rat) (c : Rat) :
    cost rows w z c = secondMoment rows w z-2*c*firstMoment rows w z+c*c*mass rows w := by
  calc
    _ = total rows (fun i => w i*z i*z i+(-2*c)*(w i*z i)+(c*c)*w i) := by
      apply total_congr rows; intro i hi; grind +ring
    _ = _ := by
      rw [total_add, total_add, total_mul, total_mul]
      unfold secondMoment firstMoment mass
      grind +ring

/-- Exact source centroid optimality; no stochastic rounding premise. -/
theorem centroid_gap (rows : List I) (w z : I → Rat) (c d : Rat)
    (hc : mass rows w*c = firstMoment rows w z) :
    cost rows w z d-cost rows w z c = mass rows w*(d-c)*(d-c) := by
  rw [cost_expansion, cost_expansion]
  rw [← hc]
  grind +ring

theorem centroid_minimum (rows : List I) (w z : I → Rat) (c d : Rat)
    (hw : 0 ≤ mass rows w) (hc : mass rows w*c = firstMoment rows w z) :
    cost rows w z c ≤ cost rows w z d := by
  have h := centroid_gap rows w z c d hc
  have hn := Rat.mul_nonneg hw (square_nonneg (d-c))
  grind +ring

theorem explicit_centroid (rows : List I) (w z : I → Rat)
    (hw : mass rows w ≠ 0) :
    mass rows w*(firstMoment rows w z/mass rows w) = firstMoment rows w z := by
  have h := Rat.div_mul_cancel (a := firstMoment rows w z) hw
  grind +ring

/-- Normalizing by the original affine fields preserves the source-diagonal
objective exactly under the stated arithmetic relation. -/
theorem affine_normalization (v a b z c kappa : Rat) (hz : b*z = v-a) :
    kappa*(v-(a+b*c))*(v-(a+b*c)) =
      (b*b*kappa)*(z-c)*(z-c) := by grind +ring

/-- Stored-word or decoder rounding is an explicit defect, not part of the
ideal fitted centroid theorem. -/
theorem decoded_defect (v ideal defect kappa : Rat) :
    kappa*(v-(ideal+defect))*(v-(ideal+defect))-
      kappa*(v-ideal)*(v-ideal) =
    kappa*defect*defect-2*kappa*(v-ideal)*defect := by grind +ring

theorem cost_append (xs ys : List I) (w z : I → Rat) (c : Rat) :
    cost (xs++ys) w z c = cost xs w z c+cost ys w z c := by
  exact ValueCoordinateGauge.total_append xs ys _

/-- The between-cluster variance formula follows from actual weighted rows.
Multiplication avoids assuming an inverse when a chunk can have zero mass. -/
theorem merged_chunks (xs ys : List I) (w z : I → Rat) (x y c : Rat)
    (hx : mass xs w*x = firstMoment xs w z)
    (hy : mass ys w*y = firstMoment ys w z)
    (hc : (mass xs w+mass ys w)*c = mass xs w*x+mass ys w*y) :
    (mass xs w+mass ys w)*(cost (xs++ys) w z c-cost xs w z x-cost ys w z y) =
      mass xs w*mass ys w*(x-y)*(x-y) := by
  rw [cost_append]
  have h0 := centroid_gap xs w z x c hx
  have h1 := centroid_gap ys w z y c hy
  grind +ring

/-- Nearest-centroid regions are ordered intervals for ordered levels. This
is the elementary exchange law behind contiguous one-dimensional partitions. -/
theorem ordered_cell_difference (a b x y : Rat) :
    ((y-a)*(y-a)-(y-b)*(y-b))-((x-a)*(x-a)-(x-b)*(x-b)) =
      2*(b-a)*(y-x) := by grind +ring

theorem ordered_cells (a b x y : Rat) (hab : a ≤ b) (hxy : x ≤ y)
    (hx : (x-b)*(x-b) ≤ (x-a)*(x-a)) :
    (y-b)*(y-b) ≤ (y-a)*(y-a) := by
  have h := ordered_cell_difference a b x y
  have hn := Rat.mul_nonneg (a := b-a) (b := y-x) (by grind) (by grind)
  grind +ring

/-- Exact Monge gap after the within-chunk errors cancel. l and r are the
ordered gaps between three successive chunk means. No source sample is fit here. -/
theorem monge_gap_identity (a b c l r : Rat)
    (hab : a+b ≠ 0) (hbc : b+c ≠ 0) (ht : a+b+c ≠ 0) :
    (a*b*l*l+a*c*(l+r)*(l+r)+b*c*r*r)/(a+b+c) -
      a*b*l*l/(a+b)-b*c*r*r/(b+c) =
    a*c/(a+b+c)*(a/(a+b)*l*l+2*l*r+c/(b+c)*r*r) := by
  have h0 := Rat.div_mul_cancel (a := a*b*l*l+a*c*(l+r)*(l+r)+b*c*r*r) ht
  have h1 := Rat.div_mul_cancel (a := a*b*l*l) hab
  have h2 := Rat.div_mul_cancel (a := b*c*r*r) hbc
  have h3 := Rat.div_mul_cancel (a := a*c) ht
  have h4 := Rat.div_mul_cancel (a := a) hab
  have h5 := Rat.div_mul_cancel (a := c) hbc
  have hcancel : ∀ x y : Rat, (a+b+c)*(a+b)*(b+c)*x = (a+b+c)*(a+b)*(b+c)*y → x=y := by
    intro x y h
    have hn : (a+b+c)*(a+b)*(b+c) ≠ 0 := by
      intro hz
      rcases Rat.mul_eq_zero.mp hz with hz | hz
      · rcases Rat.mul_eq_zero.mp hz with hz | hz
        · exact ht hz
        · exact hab hz
      · exact hbc hz
    have eq : ((a+b+c)*(a+b)*(b+c))*(x-y) = 0 := by grind +ring
    rcases Rat.mul_eq_zero.mp eq with h0 | h0
    · exact False.elim (hn h0)
    · grind
  apply hcancel
  grind +ring

private theorem divide_nonnegative (x y : Rat) (hx : 0 ≤ x) (hy : 0 < y) :
    0 ≤ x/y := by
  have h := Rat.div_mul_cancel (a := x) (Rat.ne_of_gt hy)
  apply Rat.le_of_mul_le_mul_left (c := y) _ hy
  grind +ring

theorem monge_gap_nonnegative (a b c l r : Rat)
    (ha : 0 < a) (hb : 0 ≤ b) (hc : 0 < c) (hl : 0 ≤ l) (hr : 0 ≤ r) :
    0 ≤ (a*b*l*l+a*c*(l+r)*(l+r)+b*c*r*r)/(a+b+c) -
      a*b*l*l/(a+b)-b*c*r*r/(b+c) := by
  have hab : 0 < a+b := by grind
  have hbc : 0 < b+c := by grind
  have ht : 0 < a+b+c := by grind
  rw [monge_gap_identity a b c l r (by grind) (by grind) (by grind)]
  have h0 := divide_nonnegative (a*c) (a+b+c) (Rat.mul_nonneg (by grind : 0 ≤ a) (by grind : 0 ≤ c)) ht
  have h1 := divide_nonnegative a (a+b) (by grind) hab
  have h2 := divide_nonnegative c (b+c) (by grind) hbc
  have h3 := Rat.mul_nonneg h1 (square_nonneg l)
  have h4 := Rat.mul_nonneg h2 (square_nonneg r)
  have h5 := Rat.mul_nonneg hl hr
  have hsum : 0 ≤ a/(a+b)*l*l+2*l*r+c/(b+c)*r*r := by grind +ring
  exact Rat.mul_nonneg h0 hsum

/-- The previous DP layer adds a row constant and preserves Monge. -/
theorem add_row_potential (C : Nat → Nat → Rat) (p : Nat → Rat)
    (a b j k : Nat) (h : C a j+C b k ≤ C a k+C b j) :
    (p a+C a j)+(p b+C b k) ≤ (p a+C a k)+(p b+C b j) := by grind

/-- Earliest minimizing cuts cannot move backwards in a Monge interval
matrix. Feasibility of both comparisons is explicit, not an optimizer oracle. -/
theorem earliest_minimum_monotone (C : Nat → Nat → Rat) (a b j k : Nat)
    (monge : a < b → C a j+C b k ≤ C a k+C b j)
    (earlierStrict : a < b → C b j < C a j)
    (laterMinimum : C a k ≤ C b k) : b ≤ a := by
  by_cases h : a < b
  · have hm := monge h
    have he := earlierStrict h
    grind
  · omega

def bit (b : Bool) : Rat := if b then 1 else 0

def level (c0 c1 c2 c3 : Rat) (lo hi : Bool) : Rat :=
  if hi then (if lo then c3 else c2) else (if lo then c1 else c0)

/-- A four-label alphabet is a map of its two physical bits. It need not be
recovered as a conventional uniform integer before a consumer uses it. -/
theorem four_level_bits (c0 c1 c2 c3 : Rat) (lo hi : Bool) :
    level c0 c1 c2 c3 lo hi = c0+(c1-c0)*bit lo+(c2-c0)*bit hi+
      (c3-c2-c1+c0)*bit lo*bit hi := by
  cases lo <;> cases hi <;> unfold level bit <;> simp only [Bool.false_eq_true, ↓reduceIte] <;> grind +ring

/-- Complete scalar value mixing can consume three weighted bit statistics
and an affine offset directly. This exact relabeling does not price or assert
floating/native equivalence for that possible implementation. -/
theorem mixed_bit_reader (tokens : List I) (p a b : I → Rat) (lo hi : I → Bool)
    (c0 c1 c2 c3 : Rat) :
    total tokens (fun i => p i*(a i+b i*level c0 c1 c2 c3 (lo i) (hi i))) =
      total tokens (fun i => p i*(a i+b i*c0))+
      (c1-c0)*total tokens (fun i => p i*b i*bit (lo i))+
      (c2-c0)*total tokens (fun i => p i*b i*bit (hi i))+
      (c3-c2-c1+c0)*total tokens (fun i => p i*b i*bit (lo i)*bit (hi i)) := by
  rw [← total_mul, ← total_mul, ← total_mul, ← total_add, ← total_add, ← total_add]
  apply total_congr tokens
  intro i ht
  rw [four_level_bits]
  grind +ring

end Kelana.ValueAlphabetCalibration
