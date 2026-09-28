import Std

namespace Kelana.CodedSharedCorrection

/-- Re-encoding a coarse code around a fixed correction shifts the target
before quantization; it is not the same as quantizing the original source
and adding a post-hoc correction. -/
theorem shifted_target (weight code correction : Rat) :
    weight - (code + correction) = (weight - correction) - code := by
  simp only [Rat.sub_eq_add_neg, Rat.neg_add]
  ac_rfl

/-- A finite-grid witness where adapting the code to a shared correction
reduces source error relative to keeping the original nearest code. -/
theorem fixed_correction_can_change_best_code :
    ((8 / 10 : Rat) - ((0 : Rat) + 6 / 10)) ^ 2 <
      ((8 / 10 : Rat) - ((1 : Rat) + 6 / 10)) ^ 2 := by
  decide +kernel

end Kelana.CodedSharedCorrection
