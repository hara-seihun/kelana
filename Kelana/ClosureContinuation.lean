import Std

namespace Kelana.ClosureContinuation

/-- A response carried on a producer code, with no obligation to retain source gates. -/
def Factors {X Z : Type} (code : X → Z) (f : X → Int) : Prop :=
  ∃ table : Z → Int, ∀ x, f x = table (code x)

theorem factors_constant {X Z : Type} (code : X → Z) (value : Int) :
    Factors code (fun _ => value) := by
  exact ⟨fun _ => value, fun _ => rfl⟩

theorem factors_add {X Z : Type} {code : X → Z} {f g : X → Int}
    (hf : Factors code f) (hg : Factors code g) :
    Factors code (fun x => f x + g x) := by
  obtain ⟨ft, hf⟩ := hf
  obtain ⟨gt, hg⟩ := hg
  refine ⟨fun z => ft z + gt z, ?_⟩
  intro x
  change f x + g x = ft (code x) + gt (code x)
  rw [hf x, hg x]

theorem factors_mul {X Z : Type} {code : X → Z} {f g : X → Int}
    (hf : Factors code f) (hg : Factors code g) :
    Factors code (fun x => f x * g x) := by
  obtain ⟨ft, hf⟩ := hf
  obtain ⟨gt, hg⟩ := hg
  refine ⟨fun z => ft z * gt z, ?_⟩
  intro x
  change f x * g x = ft (code x) * gt (code x)
  rw [hf x, hg x]

theorem factors_nonlinear {X Z : Type} {code : X → Z} {f : X → Int}
    (hf : Factors code f) (nonlinearity : Int → Int) :
    Factors code (fun x => nonlinearity (f x)) := by
  obtain ⟨ft, hf⟩ := hf
  refine ⟨fun z => nonlinearity (ft z), ?_⟩
  intro x
  change nonlinearity (f x) = nonlinearity (ft (code x))
  rw [hf x]

/-- An encoded state update needs only an update on the code, not on decoded states. -/
theorem factors_after_shift {X Z : Type} {code : X → Z} {f : X → Int}
    (hf : Factors code f) (shift : X → X) (step : Z → Z)
    (commutes : ∀ x, code (shift x) = step (code x)) :
    Factors code (fun x => f (shift x)) := by
  obtain ⟨ft, hf⟩ := hf
  refine ⟨fun z => ft (step z), ?_⟩
  intro x
  change f (shift x) = ft (step (code x))
  rw [hf (shift x), commutes x]

/-- Distinctions lost inside a producer fiber cannot be reconstructed by any table. -/
theorem fiber_disagreement {X Z : Type} {code : X → Z} {f : X → Int}
    {x y : X} (sameCode : code x = code y) (different : f x ≠ f y) :
    ¬ Factors code f := by
  intro ⟨table, factor⟩
  apply different
  calc
    f x = table (code x) := factor x
    _ = table (code y) := congrArg table sameCode
    _ = f y := (factor y).symm


private def addMap {X : Type} (f g : X → Rat) : X → Rat := fun x => f x + g x
private def subMap {X : Type} (f g : X → Rat) : X → Rat := fun x => f x - g x
private def mulMap {X : Type} (f g : X → Rat) : X → Rat := fun x => f x * g x

/-- The algebraic laws of conditioning onto a quotient code. `module_left` and
`module_right` say an already encoded branch can be taken outside the
conditional projection. No analytic or probabilistic dependencies are needed. -/
structure ConditionalProjection (X : Type) where
  apply : (X → Rat) → (X → Rat)
  map_add : ∀ f g, apply (addMap f g) = addMap (apply f) (apply g)
  map_sub : ∀ f g, apply (subMap f g) = subMap (apply f) (apply g)
  idempotent : ∀ f, apply (apply f) = apply f
  module_left : ∀ f g, apply (mulMap (apply f) g) = mulMap (apply f) (apply g)
  module_right : ∀ f g, apply (mulMap f (apply g)) = mulMap (apply f) (apply g)

/-- The extra error inside each encoded fiber is its conditional covariance.
Unlike exact gate closure, this identity permits *both* source branches to
carry arbitrary residuals, including errors correlated within a fiber. -/
theorem conditional_covariance {X : Type} (Q : ConditionalProjection X)
    (f g : X → Rat) :
    Q.apply (mulMap (subMap f (Q.apply f)) (subMap g (Q.apply g))) =
      subMap (Q.apply (mulMap f g)) (mulMap (Q.apply f) (Q.apply g)) := by
  have expanded :
      mulMap (subMap f (Q.apply f)) (subMap g (Q.apply g)) =
        subMap
          (subMap (addMap (mulMap f g) (mulMap (Q.apply f) (Q.apply g)))
            (mulMap f (Q.apply g)))
          (mulMap (Q.apply f) g) := by
    funext x
    simp only [mulMap, subMap, addMap, Rat.sub_eq_add_neg,
      Rat.add_mul, Rat.mul_add, Rat.neg_mul, Rat.mul_neg, Rat.neg_add, Rat.neg_neg]
    ac_rfl
  rw [expanded, Q.map_sub, Q.map_sub, Q.map_add]
  simp only [Q.module_left, Q.module_right, Q.idempotent]
  funext x
  simp only [subMap, addMap, mulMap, Rat.sub_eq_add_neg]
  simp only [Rat.add_left_comm, Rat.add_comm]
  simp only [← Rat.add_assoc, Rat.add_neg_cancel, Rat.zero_add]

/-- The product of the projected branches differs from the teacher by its
unrepresentable residual plus the covariance correction. This is the signed
identity underlying the orthogonal squared-error decomposition. -/
theorem product_error_decomposition {X : Type} (Q : ConditionalProjection X)
    (f g : X → Rat) :
    subMap (mulMap f g) (mulMap (Q.apply f) (Q.apply g)) =
      addMap (subMap (mulMap f g) (Q.apply (mulMap f g)))
        (Q.apply (mulMap (subMap f (Q.apply f)) (subMap g (Q.apply g)))) := by
  rw [conditional_covariance]
  funext x
  simp only [subMap, addMap, mulMap, Rat.sub_eq_add_neg]
  simp only [Rat.add_assoc, Rat.add_left_comm, Rat.add_comm,
    Rat.add_neg_cancel, Rat.zero_add]

/-- A concrete uniform conditional expectation on the two-point fiber. Both
inputs receive positive weight, so unlike selecting a representative it can
have a nonzero conditional covariance. -/
def twoPointMean (f : Bool → Rat) : Bool → Rat :=
  fun _ => (f false + f true) * (1 / 2 : Rat)

private theorem two_halves : (1 / 2 : Rat) + (1 / 2 : Rat) = 1 := by decide +kernel

private theorem mean_duplicate (a : Rat) :
    (a + a) * (1 / 2 : Rat) = a := by
  rw [Rat.add_mul, ← Rat.mul_add, two_halves, Rat.mul_one]

private theorem twoPoint_module_left (f g : Bool → Rat) :
    twoPointMean (mulMap (twoPointMean f) g) =
      mulMap (twoPointMean f) (twoPointMean g) := by
  funext x
  simp only [twoPointMean, mulMap, Rat.add_mul, Rat.mul_add, Rat.mul_assoc]

/-- A nontrivial model of the projection laws: averaging a two-point fiber. -/
def twoPointProjection : ConditionalProjection Bool where
  apply := twoPointMean
  map_add := by
    intro f g
    funext x
    simp only [twoPointMean, addMap, Rat.add_mul]
    ac_rfl
  map_sub := by
    intro f g
    funext x
    simp only [twoPointMean, subMap, Rat.sub_eq_add_neg, Rat.neg_add, Rat.neg_mul, Rat.add_mul]
    ac_rfl
  idempotent := by
    intro f
    funext x
    simp only [twoPointMean]
    rw [mean_duplicate]
  module_left := twoPoint_module_left
  module_right := by
    intro f g
    have swapInput : mulMap f (twoPointMean g) =
        mulMap (twoPointMean g) f := by
      funext x
      exact Rat.mul_comm _ _
    rw [swapInput, twoPoint_module_left]
    funext x
    exact Rat.mul_comm _ _

/-- The two-point projection has genuinely nonzero conditional covariance:
zero-mean signs share one bit, whose product is constantly one. -/
theorem twoPoint_nonzero_covariance :
    twoPointMean (mulMap
      (subMap (fun b : Bool => if b then (1 : Rat) else -1)
        (twoPointMean (fun b : Bool => if b then (1 : Rat) else -1)))
      (subMap (fun b : Bool => if b then (1 : Rat) else -1)
        (twoPointMean (fun b : Bool => if b then (1 : Rat) else -1)))) false = 1 := by
  decide +kernel

end Kelana.ClosureContinuation
