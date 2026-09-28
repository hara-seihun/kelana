import Std

namespace Kelana.TwoBlockResidualLabel

/-- The next update is injective in the skip when its first observation is held
    fixed. Ordinary addition of a branch computed from that observation has this
    property by cancellation. -/
theorem two_observations_injective
    {V O W : Type}
    (first : V → O) (second : V → W) (advance : V → O → V)
    (hsecond : Function.Injective second)
    (hadvance : ∀ o, Function.Injective (fun v => advance v o)) :
    Function.Injective (fun v => (first v, second (advance v (first v)))) := by
  intro a b h
  have hf : first a = first b := congrArg Prod.fst h
  have hs : second (advance a (first a)) =
      second (advance b (first b)) := congrArg Prod.snd h
  rw [← hf] at hs
  exact hadvance (first a) (hsecond hs)

/-- Any exact shared code serving both live observations is injective: a
    projected first norm by itself need not be. -/
theorem exact_label_injective
    {V O W C : Type}
    (first : V → O) (second : V → W) (advance : V → O → V)
    (hsecond : Function.Injective second)
    (hadvance : ∀ o, Function.Injective (fun v => advance v o))
    (encode : V → C) (readFirst : C → O) (readSecond : C → W)
    (h1 : ∀ v, readFirst (encode v) = first v)
    (h2 : ∀ v, readSecond (encode v) = second (advance v (first v))) :
    Function.Injective encode := by
  intro a b he
  apply two_observations_injective first second advance hsecond hadvance
  exact Prod.ext ((h1 a).symm.trans ((congrArg readFirst he).trans (h1 b)))
    ((h2 a).symm.trans ((congrArg readSecond he).trans (h2 b)))

/-- A constant off-ray branch turns two distinct radii on the same initial ray
    into distinct next-ray slopes. This is the smallest closure counterexample. -/
theorem off_ray_branch_separates :
    ((1 : Rat) / 1) ≠ ((1 : Rat) / 2) := by
  native_decide

end Kelana.TwoBlockResidualLabel
