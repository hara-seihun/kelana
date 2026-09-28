import Kelana.PairedWMMA

namespace Kelana.GuidedPacking
open PairedWMMA

-- A packed scalar need not preserve both outputs by itself. A cheaper side map
-- may locate the low component, leaving only its bounded residual to recover.
def pack (a b : Int) : Int := a + 2047*b
def high (p estimate : Int) : Int := (p-estimate+1023)/2047
def low (p estimate : Int) : Int := p-2047*high p estimate

theorem decode_with_side_map {a b estimate : Int}
    (h : -1023 ≤ a-estimate ∧ a-estimate ≤ 1023) :
    low (pack a b) estimate = a ∧ high (pack a b) estimate = b := by
  unfold low high pack
  omega

-- The estimate itself may have a much larger range than the packing radix.
example : high (pack 16000 2) 15872 = 2 ∧ low (pack 16000 2) 15872 = 16000 := by decide
example : high (pack 16000 2) 0 ≠ 2 := by decide

def coarseDigit (x : Int) : Int := x/16
def residual (x : Int) : Int := x-(16*coarseDigit x+8)

theorem coarse_digit_fits_i4 {x : Int} (hx : -128 ≤ x ∧ x ≤ 127) :
    -8 ≤ coarseDigit x ∧ coarseDigit x ≤ 7 := by unfold coarseDigit; omega

theorem residual_bound (x : Int) : -8 ≤ residual x ∧ residual x ≤ 7 := by
  unfold residual coarseDigit
  omega

def estimate (ws xs : List Int) : Int :=
  16*dot ws (xs.map coarseDigit) + 8*dot ws (xs.map (fun _ => 1))

theorem residual_dot (ws xs : List Int) :
    dot ws xs - estimate ws xs = dot ws (xs.map residual) := by
  induction ws generalizing xs with
  | nil => simp [dot, estimate]
  | cons w ws ih =>
    cases xs with
    | nil => simp [dot, estimate]
    | cons x xs =>
      have ht := ih xs
      simp only [estimate, List.map_cons, dot] at *
      have hr : residual x = x-(16*coarseDigit x+8) := rfl
      grind (ematch := 0)

theorem sparse_estimate_bound (ws xs : List Int)
    (hw : ∀ w ∈ ws, -1 ≤ w ∧ w ≤ 1) (hs : l1 ws ≤ 127) :
    -1023 ≤ dot ws xs - estimate ws xs ∧ dot ws xs - estimate ws xs ≤ 1023 := by
  rw [residual_dot]
  have hr : ∀ r ∈ xs.map residual, -8 ≤ r ∧ r ≤ 8 := by
    intro r hr
    obtain ⟨x, _, rfl⟩ := List.mem_map.mp hr
    have := residual_bound x
    omega
  have := sparse_dot_bound ws (xs.map residual) hw hr
  omega

theorem guided_dot_decodes (ws xs : List Int) (b : Int)
    (hw : ∀ w ∈ ws, -1 ≤ w ∧ w ≤ 1) (hs : l1 ws ≤ 127) :
    let a := dot ws xs
    low (pack a b) (estimate ws xs) = a ∧ high (pack a b) (estimate ws xs) = b := by
  exact decode_with_side_map (sparse_estimate_bound ws xs hw hs)

-- This is integer algebra. It does not establish exact floating WMMA evaluation
-- of the larger packed accumulator, nor the cost of computing the side map.
#print axioms guided_dot_decodes
end Kelana.GuidedPacking
