import Std

/-! Finite algebraic custody for the selected-feature cross kernel. The Gaussian
identity in README.md is derived and checked independently; this file does not
certify a producer law or floating-point quadrature. -/

namespace Kelana.FunctionKernel

private theorem sumMapAdd {α : Type} (xs : List α) (f g : α → Int) :
    (xs.map (fun x => f x + g x)).sum = (xs.map f).sum + (xs.map g).sum := by
  induction xs with
  | nil => simp
  | cons x xs ih => simp [List.map_cons, List.sum_cons, ih, Int.add_assoc, Int.add_left_comm]

private theorem sumMapScale {α : Type} (xs : List α) (a : Int) (f : α → Int) :
    a * (xs.map f).sum = (xs.map (fun x => a * f x)).sum := by
  induction xs with
  | nil => simp
  | cons x xs ih => simp [List.map_cons, List.sum_cons, Int.mul_add, ih]

private theorem sumSwap {α β : Type} (xs : List α) (ys : List β) (f : α → β → Int) :
    (xs.map (fun x => (ys.map (fun y => f x y)).sum)).sum =
    (ys.map (fun y => (xs.map (fun x => f x y)).sum)).sum := by
  induction xs with
  | nil =>
      induction ys with
      | nil => rfl
      | cons y ys ih =>
          simp only [List.map_nil, List.sum_nil] at ih
          simp only [List.map_cons, List.sum_cons, List.map_nil, List.sum_nil]
          rw [← ih]
          decide
  | cons x xs ih =>
      simp only [List.map_cons, List.sum_cons]
      rw [ih]
      rw [← sumMapAdd ys (fun y => f x y) (fun y => (xs.map (fun x => f x y)).sum)]

/-- A finite producer law's selected-feature cross moments suffice to construct
all cross moments with any linear output readout; no all-to-all feature Gram is
needed. State multiplicities represent rational empirical probabilities. -/
theorem selectedCrossSuffices {α β γ : Type}
    (states : List α) (channels : List β)
    (feature : α → β → Int) (readout : γ → β → Int)
    (bank : β) (output : γ) :
    (states.map (fun state => feature state bank *
      (channels.map (fun channel => readout output channel * feature state channel)).sum)).sum =
    (channels.map (fun channel => readout output channel *
      (states.map (fun state => feature state bank * feature state channel)).sum)).sum := by
  calc
    (states.map (fun state => feature state bank *
      (channels.map (fun channel => readout output channel * feature state channel)).sum)).sum
        = (states.map (fun state =>
          (channels.map (fun channel => feature state bank *
            (readout output channel * feature state channel))).sum)).sum := by
              apply congrArg List.sum
              apply List.map_congr_left
              intro state _
              exact sumMapScale channels (feature state bank)
                (fun channel => readout output channel * feature state channel)
    _ = (channels.map (fun channel =>
          (states.map (fun state => feature state bank *
            (readout output channel * feature state channel))).sum)).sum :=
              sumSwap states channels (fun state channel =>
                feature state bank * (readout output channel * feature state channel))
    _ = (channels.map (fun channel => readout output channel *
          (states.map (fun state => feature state bank * feature state channel)).sum)).sum := by
              apply congrArg List.sum
              apply List.map_congr_left
              intro channel _
              rw [sumMapScale]
              apply congrArg List.sum
              apply List.map_congr_left
              intro state _
              simp only [Int.mul_comm, Int.mul_left_comm]

end Kelana.FunctionKernel
