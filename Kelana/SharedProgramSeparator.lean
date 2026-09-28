import Std

namespace Kelana.SharedProgramSeparator

structure Span where
  first : Nat
  last : Nat

/-- Installed decisions for already introduced assets need be remembered only
when their legal support crosses the next tile. -/
def AgreesAtCut {α : Type} (span : α → Span)
    (cut : Nat) (left right : α → Bool) : Prop :=
  ∀ a, (span a).first < cut → cut ≤ (span a).last → left a = right a

/-- Decisions for not-yet-introduced assets are made identically in a common
continuation. A legal future option then has the same availability from both
histories, including options that need *several* assets simultaneously. -/
theorem future_option_eligibility {α : Type} (span : α → Span)
    (cut tile : Nat) (left right : α → Bool) (need : List α)
    (hcut : cut ≤ tile)
    (hcross : AgreesAtCut span cut left right)
    (hnew : ∀ a, cut ≤ (span a).first → left a = right a)
    (hlegal : ∀ a, a ∈ need →
      (span a).first ≤ tile ∧ tile ≤ (span a).last) :
    (∀ a, a ∈ need → left a = true) ↔
      (∀ a, a ∈ need → right a = true) := by
  have heq (a : α) (ha : a ∈ need) : left a = right a := by
    have h := hlegal a ha
    by_cases hfirst : (span a).first < cut
    · exact hcross a hfirst (by omega)
    · exact hnew a (by omega)
  constructor
  · intro h a ha
    rw [← heq a ha]
    exact h a ha
  · intro h a ha
    rw [heq a ha]
    exact h a ha

structure Charge where
  error : Nat
  bytes : Nat
  work : Nat
  prepared : Nat

def Charge.plus (a b : Charge) : Charge :=
  ⟨a.error + b.error, a.bytes + b.bytes,
   a.work + b.work, a.prepared + b.prepared⟩

def Charge.dominates (a b : Charge) : Prop :=
  a.error ≤ b.error ∧ a.bytes ≤ b.bytes ∧
  a.work ≤ b.work ∧ a.prepared ≤ b.prepared

/-- Once the crossing-asset state agrees, identical legal suffixes incur the
same future vector; componentwise dominance survives that common suffix. -/
theorem dominance_under_common_suffix (a b suffix : Charge)
    (h : a.dominates b) :
    (a.plus suffix).dominates (b.plus suffix) := by
  rcases h with ⟨he, hb, hw, hp⟩
  unfold Charge.dominates Charge.plus
  dsimp
  omega

/-- At even zero shared-asset width, independent binary tile choices can
produce an exponentially large frontier. For tile i choose (error,bytes) =
(2^i,0) or (0,2^i), so every realized vector has this shape. -/
def binaryTradeoff (total error : Nat) : Charge :=
  ⟨error, total - error, 0, 0⟩

theorem binary_tradeoff_antichain (total a b : Nat)
    (ha : a ≤ total) (hb : b ≤ total)
    (hdom : (binaryTradeoff total a).dominates (binaryTradeoff total b)) :
    a = b := by
  unfold binaryTradeoff Charge.dominates at hdom
  dsimp at hdom
  omega

end Kelana.SharedProgramSeparator
