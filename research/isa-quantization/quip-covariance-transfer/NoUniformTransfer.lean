import Std

namespace Kelana.QuipCovarianceTransfer

/-- A held-positive direction invisible to the training quadratic form
precludes every finite uniform held/train covariance transfer bound. -/
theorem noUniformFiniteTransfer {α : Type} (train held : α → Rat) (v : α)
    (invisible : train v = 0) (visible : 0 < held v) :
    ¬ ∃ C : Rat, ∀ x : α, held x ≤ C * train x := by
  rintro ⟨C, hC⟩
  have hv : held v ≤ 0 := by simpa [invisible] using hC v
  exact (Rat.not_le.mpr visible) hv

end Kelana.QuipCovarianceTransfer
