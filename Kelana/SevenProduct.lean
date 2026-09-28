import Std

namespace Kelana.SevenProduct
open Lean.Grind

structure Blocks (R : Type) where
  a : R
  b : R
  c : R
  d : R

variable {R : Type} [Ring R]

def ordinary (x y : Blocks R) : Blocks R :=
  ⟨x.a*y.a+x.b*y.c, x.a*y.b+x.b*y.d,
   x.c*y.a+x.d*y.c, x.c*y.b+x.d*y.d⟩

/-- One Strassen level. R need not be commutative, so entries can be square
matrix blocks. This is ideal algebra, not a reassociation theorem for floats. -/
def seven (x y : Blocks R) : Blocks R :=
  let m1 := (x.a+x.d)*(y.a+y.d)
  let m2 := (x.c+x.d)*y.a
  let m3 := x.a*(y.b-y.d)
  let m4 := x.d*(y.c-y.a)
  let m5 := (x.a+x.b)*y.d
  let m6 := (x.c-x.a)*(y.a+y.b)
  let m7 := (x.b-x.d)*(y.c+y.d)
  ⟨m1+m4-m5+m7, m3+m5, m2+m4, m1-m2+m3+m6⟩

theorem seven_correct (x y : Blocks R) : seven x y = ordinary x y := by
  cases x; cases y
  unfold seven ordinary
  simp only [Blocks.mk.injEq]
  and_intros <;> grind

def rowScale (s t : R) (x : Blocks R) : Blocks R :=
  ⟨s*x.a, s*x.b, t*x.c, t*x.d⟩

def columnScale (s t : R) (x : Blocks R) : Blocks R :=
  ⟨x.a*s, x.b*t, x.c*s, x.d*t⟩

/-- Row and token scales need not agree with one another. When they are constant
along this K block they factor outside the unscaled seven-product computation. -/
theorem scaled_seven (x y : Blocks R) (r₀ r₁ c₀ c₁ : R) :
    ordinary (rowScale r₀ r₁ x) (columnScale c₀ c₁ y) =
      rowScale r₀ r₁ (columnScale c₀ c₁ (seven x y)) := by
  rw [seven_correct]
  cases x; cases y
  unfold ordinary rowScale columnScale
  simp only [Blocks.mk.injEq]
  and_intros <;> grind

/-- A3 sums and differences remain native signed-IU4 operands. -/
theorem a3_sum_difference_fit (x y : Int) (hx : -3 ≤ x ∧ x ≤ 3) (hy : -3 ≤ y ∧ y ≤ 3) :
    -8 ≤ x+y ∧ x+y ≤ 7 ∧ -8 ≤ x-y ∧ x-y ≤ 7 := by omega

/-- A4's extra precision crosses an instruction boundary under the same map. -/
theorem a4_can_escape_i4 : ¬ (-8 ≤ (7:Int)+7 ∧ (7:Int)+7 ≤ 7) := by decide +kernel

theorem ternary_sum_difference_fit (x y : Int)
    (hx : -1 ≤ x ∧ x ≤ 1) (hy : -1 ≤ y ∧ y ≤ 1) :
    -2 ≤ x+y ∧ x+y ≤ 2 ∧ -2 ≤ x-y ∧ x-y ≤ 2 := by omega

end Kelana.SevenProduct
