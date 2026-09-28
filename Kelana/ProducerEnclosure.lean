import Std

/-!
# Producer enclosure calculus

This module gives integer interval rules for source-level producer evaluation.
A scaled interval also gives the same endpoints rational meaning through
cross-multiplied inequalities. Approximate intrinsics enter through local error
contracts, rather than an assumption about the final producer output.
-/

namespace Kelana.ProducerEnclosure

structure Interval where
  lower : Int
  upper : Int
  deriving Repr, DecidableEq

namespace Interval

/-- An integer lies between both endpoints. Empty intervals contain nothing. -/
def Contains (interval : Interval) (value : Int) : Prop :=
  interval.lower ≤ value ∧ value ≤ interval.upper

/-- Endpoint order. This is needed when an enclosure must be inhabited. -/
def Valid (interval : Interval) : Prop :=
  interval.lower ≤ interval.upper

@[simp] def singleton (value : Int) : Interval := ⟨value, value⟩

@[simp] theorem singleton_contains (value : Int) : (singleton value).Contains value :=
  ⟨Int.le_refl value, Int.le_refl value⟩

@[simp] def add (left right : Interval) : Interval :=
  ⟨left.lower + right.lower, left.upper + right.upper⟩

@[simp] def sub (left right : Interval) : Interval :=
  ⟨left.lower - right.upper, left.upper - right.lower⟩

theorem add_valid {left right : Interval} (hleft : left.Valid)
    (hright : right.Valid) : (add left right).Valid :=
  Int.add_le_add hleft hright

theorem sub_valid {left right : Interval} (hleft : left.Valid)
    (hright : right.Valid) : (sub left right).Valid :=
  Int.sub_le_sub hleft hright

private def min4 (a b c d : Int) : Int := min (min a b) (min c d)
private def max4 (a b c d : Int) : Int := max (max a b) (max c d)

/-- Four-endpoint integer product enclosure. -/
@[simp] def mul (left right : Interval) : Interval :=
  ⟨min4 (left.lower * right.lower) (left.lower * right.upper)
      (left.upper * right.lower) (left.upper * right.upper),
    max4 (left.lower * right.lower) (left.lower * right.upper)
      (left.upper * right.lower) (left.upper * right.upper)⟩

private theorem min4_le_one (a b c d : Int) : min4 a b c d ≤ a :=
  Int.le_trans (Int.min_le_left _ _) (Int.min_le_left _ _)

private theorem min4_le_two (a b c d : Int) : min4 a b c d ≤ b :=
  Int.le_trans (Int.min_le_left _ _) (Int.min_le_right _ _)

private theorem min4_le_three (a b c d : Int) : min4 a b c d ≤ c :=
  Int.le_trans (Int.min_le_right _ _) (Int.min_le_left _ _)

private theorem min4_le_four (a b c d : Int) : min4 a b c d ≤ d :=
  Int.le_trans (Int.min_le_right _ _) (Int.min_le_right _ _)

private theorem one_le_max4 (a b c d : Int) : a ≤ max4 a b c d :=
  Int.le_trans (Int.le_max_left _ _) (Int.le_max_left _ _)

private theorem two_le_max4 (a b c d : Int) : b ≤ max4 a b c d :=
  Int.le_trans (Int.le_max_right _ _) (Int.le_max_left _ _)

private theorem three_le_max4 (a b c d : Int) : c ≤ max4 a b c d :=
  Int.le_trans (Int.le_max_left _ _) (Int.le_max_right _ _)

private theorem four_le_max4 (a b c d : Int) : d ≤ max4 a b c d :=
  Int.le_trans (Int.le_max_right _ _) (Int.le_max_right _ _)

theorem mul_valid (left right : Interval) : (mul left right).Valid := by
  simp only [mul, Valid]
  exact Int.le_trans (min4_le_one _ _ _ _) (one_le_max4 _ _ _ _)

theorem add_contains {left right : Interval} {x y : Int}
    (hx : left.Contains x) (hy : right.Contains y) :
    (add left right).Contains (x + y) := by
  constructor <;> simp only [add]
  · exact Int.add_le_add hx.1 hy.1
  · exact Int.add_le_add hx.2 hy.2

theorem sub_contains {left right : Interval} {x y : Int}
    (hx : left.Contains x) (hy : right.Contains y) :
    (sub left right).Contains (x - y) := by
  constructor <;> simp only [sub]
  · exact Int.sub_le_sub hx.1 hy.2
  · exact Int.sub_le_sub hx.2 hy.1

theorem mul_contains {left right : Interval} {x y : Int}
    (hx : left.Contains x) (hy : right.Contains y) :
    (mul left right).Contains (x * y) := by
  constructor
  · simp only [mul]
    by_cases xpos : 0 ≤ x
    · have hxy : x * right.lower ≤ x * y :=
        Int.mul_le_mul_of_nonneg_left hy.1 xpos
      by_cases rpos : 0 ≤ right.lower
      · exact Int.le_trans
          (min4_le_one _ _ _ _)
          (Int.le_trans (Int.mul_le_mul_of_nonneg_right hx.1 rpos) hxy)
      · have rnonpos : right.lower ≤ 0 := by omega
        exact Int.le_trans
          (min4_le_three _ _ _ _)
          (Int.le_trans (Int.mul_le_mul_of_nonpos_right hx.2 rnonpos) hxy)
    · have xnonpos : x ≤ 0 := by omega
      have hxy : x * right.upper ≤ x * y :=
        Int.mul_le_mul_of_nonpos_left xnonpos hy.2
      by_cases rpos : 0 ≤ right.upper
      · exact Int.le_trans
          (min4_le_two _ _ _ _)
          (Int.le_trans (Int.mul_le_mul_of_nonneg_right hx.1 rpos) hxy)
      · have rnonpos : right.upper ≤ 0 := by omega
        exact Int.le_trans
          (min4_le_four _ _ _ _)
          (Int.le_trans (Int.mul_le_mul_of_nonpos_right hx.2 rnonpos) hxy)
  · simp only [mul]
    by_cases xpos : 0 ≤ x
    · have hxy : x * y ≤ x * right.upper :=
        Int.mul_le_mul_of_nonneg_left hy.2 xpos
      by_cases rpos : 0 ≤ right.upper
      · exact Int.le_trans hxy
          (Int.le_trans (Int.mul_le_mul_of_nonneg_right hx.2 rpos)
            (four_le_max4 _ _ _ _))
      · have rnonpos : right.upper ≤ 0 := by omega
        exact Int.le_trans hxy
          (Int.le_trans (Int.mul_le_mul_of_nonpos_right hx.1 rnonpos)
            (two_le_max4 _ _ _ _))
    · have xnonpos : x ≤ 0 := by omega
      have hxy : x * y ≤ x * right.lower :=
        Int.mul_le_mul_of_nonpos_left xnonpos hy.1
      by_cases rpos : 0 ≤ right.lower
      · exact Int.le_trans hxy
          (Int.le_trans (Int.mul_le_mul_of_nonneg_right hx.2 rpos)
            (three_le_max4 _ _ _ _))
      · have rnonpos : right.lower ≤ 0 := by omega
        exact Int.le_trans hxy
          (Int.le_trans (Int.mul_le_mul_of_nonpos_right hx.1 rnonpos)
            (one_le_max4 _ _ _ _))

structure ErrorAllowance where
  below : Nat
  above : Nat
  deriving Repr, DecidableEq

/-- `observed` differs from `exact` by the stated asymmetric allowance. -/
def Within (error : ErrorAllowance) (exact observed : Int) : Prop :=
  exact - (error.below : Int) ≤ observed ∧
    observed ≤ exact + (error.above : Int)

@[simp] def widen (interval : Interval) (error : ErrorAllowance) : Interval :=
  ⟨interval.lower - (error.below : Int),
    interval.upper + (error.above : Int)⟩

theorem widen_valid {interval : Interval} {error : ErrorAllowance}
    (valid : interval.Valid) : (widen interval error).Valid := by
  simp only [widen, Valid]
  exact Int.le_trans (Int.sub_le_self _ (Int.natCast_nonneg _))
    (Int.le_trans valid (Int.le_add_of_nonneg_right (Int.natCast_nonneg _)))

theorem widen_contains {interval : Interval} {error : ErrorAllowance}
    {exact observed : Int} (hexact : interval.Contains exact)
    (herror : Within error exact observed) :
    (widen interval error).Contains observed := by
  constructor
  · exact Int.le_trans (Int.sub_le_sub_right hexact.1 _) herror.1
  · exact Int.le_trans herror.2 (Int.add_le_add_right hexact.2 _)

/-- A local implementation contract for an approximate source intrinsic. -/
def ApproximationContract {Input : Type} (exact implementation : Input → Int)
    (error : ErrorAllowance) : Prop :=
  ∀ input, Within error (exact input) (implementation input)

/-- An interval transformer is sound for every value in its input interval. -/
def Maps (operation : Int → Int) (source target : Interval) : Prop :=
  ∀ value, source.Contains value → target.Contains (operation value)

theorem Maps.identity (interval : Interval) : Maps id interval interval := by
  intro value hvalue
  exact hvalue

theorem Maps.comp {first second : Int → Int} {a b c : Interval}
    (hfirst : Maps first a b) (hsecond : Maps second b c) :
    Maps (second ∘ first) a c := by
  intro value hvalue
  exact hsecond _ (hfirst value hvalue)

/-- A local exact enclosure and a local approximation contract give an
approximate enclosure. This is the intended entry point for `exp`, reciprocal,
and target-specific arithmetic instructions. -/
theorem maps_approximation {Input : Type} {exact implementation : Input → Int}
    {source : Input → Prop} {target : Interval} {error : ErrorAllowance}
    (exactEnclosure : ∀ input, source input → target.Contains (exact input))
    (contract : ApproximationContract exact implementation error) :
    ∀ input, source input → (widen target error).Contains (implementation input) := by
  intro input hinput
  exact widen_contains (exactEnclosure input hinput) (contract input)

/-- A monotone integer rounding map is enclosed by rounding both endpoints. -/
@[simp] def mapMonotone (round : Int → Int) (interval : Interval) : Interval :=
  ⟨round interval.lower, round interval.upper⟩

def IsMonotone (operation : Int → Int) : Prop :=
  ∀ ⦃a b⦄, a ≤ b → operation a ≤ operation b

theorem mapMonotone_contains {round : Int → Int} {interval : Interval}
    (monotone : IsMonotone round) {value : Int}
    (hvalue : interval.Contains value) :
    (mapMonotone round interval).Contains (round value) :=
  ⟨monotone hvalue.1, monotone hvalue.2⟩

end Interval

/-- The rational interval `[lower/scale, upper/scale]`, represented without a
rational-number library. -/
structure ScaledInterval where
  bounds : Interval
  boundsValid : bounds.Valid
  scale : Int
  scalePositive : 0 < scale

namespace ScaledInterval

/-- Cross-multiplied membership of `numerator/denominator`. -/
def ContainsRatio (interval : ScaledInterval) (numerator denominator : Int) : Prop :=
  0 < denominator ∧
    interval.bounds.lower * denominator ≤ numerator * interval.scale ∧
    numerator * interval.scale ≤ interval.bounds.upper * denominator

/-- Integer numerator membership at the interval's own scale agrees with the
ordinary integer interval semantics. -/
theorem containsRatio_same_scale (interval : ScaledInterval) (numerator : Int) :
    interval.ContainsRatio numerator interval.scale ↔
      interval.bounds.Contains numerator := by
  constructor
  · intro h
    exact ⟨Int.le_of_mul_le_mul_right h.2.1 interval.scalePositive,
      Int.le_of_mul_le_mul_right h.2.2 interval.scalePositive⟩
  · intro h
    refine ⟨interval.scalePositive, ?_, ?_⟩
    · exact Int.mul_le_mul_of_nonneg_right h.1
        (Int.le_of_lt interval.scalePositive)
    · exact Int.mul_le_mul_of_nonneg_right h.2
        (Int.le_of_lt interval.scalePositive)

/-- Every scaled interval contains its lower endpoint divided by its scale. -/
theorem lower_mem (interval : ScaledInterval) :
    interval.ContainsRatio interval.bounds.lower interval.scale :=
  (containsRatio_same_scale interval interval.bounds.lower).2
    ⟨Int.le_refl _, interval.boundsValid⟩

end ScaledInterval

/-- Center and preserved linear terms of a product. `linearA` and `linearB` may
each aggregate any number of shared affine generators. -/
def affineProductLinear (centerA centerB linearA linearB : Int) : Int :=
  centerA * centerB + centerA * linearB + centerB * linearA

/-- Residual bound for multiplication while preserving the two linear generator
contributions. The final product term bounds every interaction between the two
total deviations, including shared-generator products and input residuals. -/
theorem affineProduct_residual
    (valueA valueB centerA centerB linearA linearB errorA errorB : Int)
    (residualA residualB totalRadiusA totalRadiusB : Nat)
    (hvalueA : valueA = centerA + linearA + errorA)
    (hvalueB : valueB = centerB + linearB + errorB)
    (herrorA : errorA.natAbs ≤ residualA)
    (herrorB : errorB.natAbs ≤ residualB)
    (htotalA : (linearA + errorA).natAbs ≤ totalRadiusA)
    (htotalB : (linearB + errorB).natAbs ≤ totalRadiusB) :
    (valueA * valueB -
        affineProductLinear centerA centerB linearA linearB).natAbs ≤
      centerA.natAbs * residualB + centerB.natAbs * residualA +
        totalRadiusA * totalRadiusB := by
  have identity :
      valueA * valueB - affineProductLinear centerA centerB linearA linearB =
        centerA * errorB + centerB * errorA +
          (linearA + errorA) * (linearB + errorB) := by
    rw [hvalueA, hvalueB]
    simp only [affineProductLinear, Int.add_mul, Int.mul_add]
    rw [Int.mul_comm linearA centerB, Int.mul_comm errorA centerB]
    omega
  rw [identity]
  calc
    (centerA * errorB + centerB * errorA +
        (linearA + errorA) * (linearB + errorB)).natAbs
        ≤ (centerA * errorB).natAbs + (centerB * errorA).natAbs +
            ((linearA + errorA) * (linearB + errorB)).natAbs := by
          exact Nat.le_trans (Int.natAbs_add_le _ _)
            (Nat.add_le_add_right (Int.natAbs_add_le _ _) _)
    _ = centerA.natAbs * errorB.natAbs +
          centerB.natAbs * errorA.natAbs +
          (linearA + errorA).natAbs * (linearB + errorB).natAbs := by
          simp only [Int.natAbs_mul]
    _ ≤ centerA.natAbs * residualB + centerB.natAbs * residualA +
          totalRadiusA * totalRadiusB := by
          exact Nat.add_le_add
            (Nat.add_le_add
              (Nat.mul_le_mul_left centerA.natAbs herrorB)
              (Nat.mul_le_mul_left centerB.natAbs herrorA))
            (Nat.mul_le_mul htotalA htotalB)

abbrev Vector (dimension : Nat) := Fin dimension → Int
abbrev Box (dimension : Nat) := Fin dimension → Interval

namespace Box

def Contains {dimension : Nat} (box : Box dimension)
    (value : Vector dimension) : Prop :=
  ∀ coordinate, (box coordinate).Contains (value coordinate)

def Valid {dimension : Nat} (box : Box dimension) : Prop :=
  ∀ coordinate, (box coordinate).Valid

def lowerCorner {dimension : Nat} (box : Box dimension) : Vector dimension :=
  fun coordinate => (box coordinate).lower

/-- Every finite-dimensional valid box has a concrete member. -/
theorem lowerCorner_mem {dimension : Nat} {box : Box dimension}
    (valid : box.Valid) : box.Contains box.lowerCorner := by
  intro coordinate
  exact ⟨Int.le_refl _, valid coordinate⟩

/-- A transformation maps every vector in the source box into the target box. -/
def Maps {inputDimension outputDimension : Nat}
    (operation : Vector inputDimension → Vector outputDimension)
    (source : Box inputDimension) (target : Box outputDimension) : Prop :=
  ∀ value, source.Contains value → target.Contains (operation value)

theorem Maps.identity {dimension : Nat} (box : Box dimension) :
    Maps id box box := by
  intro value hvalue
  exact hvalue

theorem Maps.comp {a b c : Nat} {first : Vector a → Vector b}
    {second : Vector b → Vector c} {source : Box a} {middle : Box b}
    {target : Box c} (hfirst : Maps first source middle)
    (hsecond : Maps second middle target) :
    Maps (second ∘ first) source target := by
  intro value hvalue
  exact hsecond _ (hfirst value hvalue)

end Box

/-- Every output of an arbitrary-size producer lies in its box. -/
def Contained {Input : Type} {dimension : Nat}
    (producer : Input → Vector dimension) (box : Box dimension) : Prop :=
  ∀ input, box.Contains (producer input)

/-- Producer containment survives any sound box transformation. -/
theorem Contained.map {Input : Type} {inputDimension outputDimension : Nat}
    {producer : Input → Vector inputDimension}
    {operation : Vector inputDimension → Vector outputDimension}
    {source : Box inputDimension} {target : Box outputDimension}
    (contained : Contained producer source)
    (mapped : Box.Maps operation source target) :
    Contained (operation ∘ producer) target := by
  intro input
  exact mapped _ (contained input)

structure ButterflyEnclosure where
  sum : Interval
  difference : Interval

namespace ButterflyEnclosure

@[simp] def ofInputs (left right : Interval)
    (sumError differenceError : Interval.ErrorAllowance) : ButterflyEnclosure :=
  ⟨Interval.widen (Interval.add left right) sumError,
    Interval.widen (Interval.sub left right) differenceError⟩

def Contains (enclosure : ButterflyEnclosure) (value : Int × Int) : Prop :=
  enclosure.sum.Contains value.1 ∧ enclosure.difference.Contains value.2

/-- Paired Hadamard butterfly enclosure with independent rounding allowances on
`x + y` and `x - y`. -/
theorem contains_ofInputs {left right : Interval} {x y sum difference : Int}
    {sumError differenceError : Interval.ErrorAllowance}
    (hx : left.Contains x) (hy : right.Contains y)
    (hsum : Interval.Within sumError (x + y) sum)
    (hdifference : Interval.Within differenceError (x - y) difference) :
    (ofInputs left right sumError differenceError).Contains (sum, difference) := by
  constructor
  · exact Interval.widen_contains (Interval.add_contains hx hy) hsum
  · exact Interval.widen_contains (Interval.sub_contains hx hy) hdifference

end ButterflyEnclosure

/-- Cross-product error contract for dynamic division. It avoids choosing a
rounding convention for `/`: the source evaluator proves these two integer
inequalities for its quotient instruction. -/
def DivisionWithin (error : Interval.ErrorAllowance)
    (numerator denominator quotient : Int) : Prop :=
  numerator - (error.below : Int) ≤ quotient * denominator ∧
    quotient * denominator ≤ numerator + (error.above : Int)

/-- A dynamic quotient interval. The two endpoint premises are executable
integer certificate checks. Singleton-times-denominator uses the same
four-endpoint multiplication rule as every other source operation. -/
theorem division_contains {numerators denominators : Interval}
    {numerator denominator quotient lower upper : Int}
    {error : Interval.ErrorAllowance}
    (hnumerator : numerators.Contains numerator)
    (hdenominator : denominators.Contains denominator)
    (denominatorPositive : 0 < denominators.lower)
    (division : DivisionWithin error numerator denominator quotient)
    (lowerCertificate :
      (Interval.mul (Interval.singleton lower) denominators).upper ≤
        numerators.lower - (error.below : Int))
    (upperCertificate :
      numerators.upper + (error.above : Int) ≤
        (Interval.mul (Interval.singleton upper) denominators).lower) :
    (Interval.mk lower upper).Contains quotient := by
  have denominatorActualPositive : 0 < denominator :=
    Int.lt_of_lt_of_le denominatorPositive hdenominator.1
  have hlowerProduct := Interval.mul_contains
    (Interval.singleton_contains lower) hdenominator
  have hupperProduct := Interval.mul_contains
    (Interval.singleton_contains upper) hdenominator
  constructor
  · apply Int.le_of_mul_le_mul_right _ denominatorActualPositive
    exact Int.le_trans hlowerProduct.2
      (Int.le_trans lowerCertificate
        (Int.le_trans (Int.sub_le_sub_right hnumerator.1 _) division.1))
  · apply Int.le_of_mul_le_mul_right _ denominatorActualPositive
    exact Int.le_trans division.2
      (Int.le_trans (Int.add_le_add_right hnumerator.2 _)
        (Int.le_trans upperCertificate hupperProduct.1))

#print axioms Interval.mul_contains
#print axioms Interval.mapMonotone_contains
#print axioms Interval.maps_approximation
#print axioms ScaledInterval.containsRatio_same_scale
#print axioms affineProduct_residual
#print axioms Contained.map
#print axioms ButterflyEnclosure.contains_ofInputs
#print axioms division_contains

end Kelana.ProducerEnclosure
