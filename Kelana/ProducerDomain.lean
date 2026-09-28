import Std

/-!
# Affine generated producer domains

An integer producer domain consists of a center and finitely many generators.
Each generator has its own nonnegative integer radius. The representation keeps
full vectors until a row is projected, so the scalar support coefficients are
derived rather than assumed.
-/

namespace Kelana.ProducerDomain

abbrev Vector := Nat → Int

structure Generator where
  vector : Vector
  radius : Nat

/-- Dot product over the first `dimension` coordinates. -/
def dot : Nat → Vector → Vector → Int
  | 0, _, _ => 0
  | n + 1, a, b => a n * b n + dot n a b

/-- The generated offset. Mismatched lists denote no domain point because
`CoefficientsBounded` below rejects them. -/
def offset : List Generator → List Int → Vector
  | g :: gs, z :: zs => fun i => g.vector i * z + offset gs zs i
  | _, _ => fun _ => 0

def realize (center : Vector) (generators : List Generator)
    (coefficients : List Int) : Vector :=
  fun i => center i + offset generators coefficients i

/-- Coefficients have the same shape as the generator list and obey each
individual radius. -/
def CoefficientsBounded : List Generator → List Int → Prop
  | [], [] => True
  | g :: gs, z :: zs => z.natAbs ≤ g.radius ∧ CoefficientsBounded gs zs
  | _, _ => False

def InDomain (center : Vector) (generators : List Generator) (x : Vector) : Prop :=
  ∃ coefficients, CoefficientsBounded generators coefficients ∧
    x = realize center generators coefficients

/-- Scalar coefficient obtained by projecting a full generator through a row. -/
def projectedCoefficient (dimension : Nat) (row : Vector)
    (generator : Generator) : Int :=
  dot dimension row generator.vector

/-- Projection of the generated offset with the supplied scalar choices. -/
def projectedOffset (dimension : Nat) (row : Vector) :
    List Generator → List Int → Int
  | g :: gs, z :: zs => projectedCoefficient dimension row g * z +
      projectedOffset dimension row gs zs
  | _, _ => 0

/-- Support radius after projection. -/
def supportRadius (dimension : Nat) (row : Vector) : List Generator → Nat
  | [] => 0
  | g :: gs => g.radius * (projectedCoefficient dimension row g).natAbs +
      supportRadius dimension row gs

@[simp] theorem dot_zero (dimension : Nat) (row : Vector) :
    dot dimension row (fun _ => 0) = 0 := by
  induction dimension with
  | zero => rfl
  | succ n ih => simp [dot, ih]

@[simp] theorem dot_add (dimension : Nat) (row x y : Vector) :
    dot dimension row (fun i => x i + y i) =
      dot dimension row x + dot dimension row y := by
  induction dimension with
  | zero => simp [dot]
  | succ n ih =>
      simp only [dot, Int.mul_add, ih]
      omega

@[simp] theorem dot_scale (dimension : Nat) (row x : Vector) (z : Int) :
    dot dimension row (fun i => x i * z) = dot dimension row x * z := by
  induction dimension with
  | zero => simp [dot]
  | succ n ih =>
      simp only [dot, Int.mul_assoc, ih, Int.add_mul]

/-- This is the bridge from vector generator semantics to scalar support
coefficients. -/
theorem dot_offset (dimension : Nat) (row : Vector) (generators : List Generator)
    (coefficients : List Int) :
    dot dimension row (offset generators coefficients) =
      projectedOffset dimension row generators coefficients := by
  induction generators generalizing coefficients with
  | nil => simp [offset, projectedOffset]
  | cons g gs ih =>
      cases coefficients with
      | nil => simp [offset, projectedOffset]
      | cons z zs =>
          simp only [offset, projectedOffset, projectedCoefficient]
          rw [dot_add, dot_scale, ih]

/-- Projection of an actual generated vector is the center projection plus the
sum of its projected generators. -/
theorem dot_realize (dimension : Nat) (row center : Vector)
    (generators : List Generator) (coefficients : List Int) :
    dot dimension row (realize center generators coefficients) =
      dot dimension row center +
        projectedOffset dimension row generators coefficients := by
  unfold realize
  rw [dot_add, dot_offset]

/-- Triangle inequality for all bounded generator choices. -/
theorem projectedOffset_le (dimension : Nat) (row : Vector)
    (generators : List Generator) (coefficients : List Int)
    (bounded : CoefficientsBounded generators coefficients) :
    (projectedOffset dimension row generators coefficients).natAbs ≤
      supportRadius dimension row generators := by
  induction generators generalizing coefficients with
  | nil =>
      cases coefficients <;> simp_all [CoefficientsBounded, projectedOffset, supportRadius]
  | cons g gs ih =>
      cases coefficients with
      | nil => simp_all [CoefficientsBounded]
      | cons z zs =>
          rcases bounded with ⟨hz, hzs⟩
          have htail := ih zs hzs
          have hterm :
              (projectedCoefficient dimension row g * z).natAbs ≤
                g.radius * (projectedCoefficient dimension row g).natAbs := by
            rw [Int.natAbs_mul]
            simpa [Nat.mul_comm] using
              Nat.mul_le_mul_right (projectedCoefficient dimension row g).natAbs hz
          calc
            (projectedOffset dimension row (g :: gs) (z :: zs)).natAbs
                ≤ (projectedCoefficient dimension row g * z).natAbs +
                    (projectedOffset dimension row gs zs).natAbs := by
                  simpa [projectedOffset] using Int.natAbs_add_le
                    (projectedCoefficient dimension row g * z)
                    (projectedOffset dimension row gs zs)
            _ ≤ g.radius * (projectedCoefficient dimension row g).natAbs +
                    supportRadius dimension row gs := Nat.add_le_add hterm htail
            _ = supportRadius dimension row (g :: gs) := by
                  simp [supportRadius]

/-- Every point in the affine generated domain obeys its support bound. -/
theorem domain_upper (dimension : Nat) (row center : Vector)
    (generators : List Generator) (x : Vector)
    (member : InDomain center generators x) :
    (dot dimension row x).natAbs ≤
      (dot dimension row center).natAbs + supportRadius dimension row generators := by
  rcases member with ⟨coefficients, bounded, rfl⟩
  rw [dot_realize]
  exact Nat.le_trans (Int.natAbs_add_le _ _)
    (Nat.add_le_add_left (projectedOffset_le dimension row generators coefficients bounded) _)

private def positiveCoefficients (dimension : Nat) (row : Vector) :
    List Generator → List Int
  | [] => []
  | g :: gs => (projectedCoefficient dimension row g).sign * (g.radius : Int) ::
      positiveCoefficients dimension row gs

private def negativeCoefficients (dimension : Nat) (row : Vector) :
    List Generator → List Int
  | [] => []
  | g :: gs => -((projectedCoefficient dimension row g).sign * (g.radius : Int)) ::
      negativeCoefficients dimension row gs

private theorem positive_bounded (dimension : Nat) (row : Vector)
    (generators : List Generator) :
    CoefficientsBounded generators (positiveCoefficients dimension row generators) := by
  induction generators with
  | nil => simp [positiveCoefficients, CoefficientsBounded]
  | cons g gs ih =>
      constructor
      · rw [Int.natAbs_mul]
        have hs : (projectedCoefficient dimension row g).sign.natAbs ≤ 1 := by
          by_cases hp : 0 < projectedCoefficient dimension row g
          · simp [Int.sign_eq_one_of_pos hp]
          · by_cases hn : projectedCoefficient dimension row g < 0
            · simp [Int.sign_eq_neg_one_of_neg hn]
            · have hz : projectedCoefficient dimension row g = 0 := by omega
              simp [hz]
        simpa using Nat.mul_le_mul_right g.radius hs
      · exact ih

private theorem negative_bounded (dimension : Nat) (row : Vector)
    (generators : List Generator) :
    CoefficientsBounded generators (negativeCoefficients dimension row generators) := by
  induction generators with
  | nil => simp [negativeCoefficients, CoefficientsBounded]
  | cons g gs ih =>
      simp only [negativeCoefficients, CoefficientsBounded]
      constructor
      · rw [Int.natAbs_neg]
        exact (positive_bounded dimension row (g :: gs)).1
      · exact ih

private theorem positive_projection (dimension : Nat) (row : Vector)
    (generators : List Generator) :
    projectedOffset dimension row generators
        (positiveCoefficients dimension row generators) =
      (supportRadius dimension row generators : Int) := by
  induction generators with
  | nil => simp [projectedOffset, supportRadius]
  | cons g gs ih =>
      simp only [positiveCoefficients, projectedOffset, supportRadius, Int.natCast_add,
        Int.natCast_mul]
      rw [ih]
      have hsign : projectedCoefficient dimension row g *
            ((projectedCoefficient dimension row g).sign * (g.radius : Int)) =
          ((projectedCoefficient dimension row g).natAbs : Int) * g.radius := by
        rw [← Int.mul_assoc, Int.mul_comm _ (Int.sign _), Int.sign_mul_self]
      rw [hsign]
      ac_rfl

private theorem negative_projection (dimension : Nat) (row : Vector)
    (generators : List Generator) :
    projectedOffset dimension row generators
        (negativeCoefficients dimension row generators) =
      -(supportRadius dimension row generators : Int) := by
  induction generators with
  | nil => simp [projectedOffset, supportRadius]
  | cons g gs ih =>
      simp only [negativeCoefficients, projectedOffset, supportRadius, Int.natCast_add,
        Int.natCast_mul]
      rw [ih]
      have hsign : projectedCoefficient dimension row g *
            (-((projectedCoefficient dimension row g).sign * (g.radius : Int))) =
          -((projectedCoefficient dimension row g).natAbs * g.radius) := by
        rw [Int.mul_neg, ← Int.mul_assoc, Int.mul_comm _ (Int.sign _), Int.sign_mul_self]
      rw [hsign, Int.neg_add]
      simp [Int.mul_comm]

/-- The support bound is attained. This packages both the universal inequality
and a concrete domain point attaining equality. -/
theorem exact_support (dimension : Nat) (row center : Vector)
    (generators : List Generator) :
    (∀ x, InDomain center generators x →
      (dot dimension row x).natAbs ≤
        (dot dimension row center).natAbs + supportRadius dimension row generators) ∧
    (∃ x, InDomain center generators x ∧
      (dot dimension row x).natAbs =
        (dot dimension row center).natAbs + supportRadius dimension row generators) := by
  constructor
  · exact fun x hx => domain_upper dimension row center generators x hx
  · by_cases hc : 0 ≤ dot dimension row center
    · let coefficients := positiveCoefficients dimension row generators
      refine ⟨realize center generators coefficients,
        ⟨coefficients, positive_bounded dimension row generators, rfl⟩, ?_⟩
      rw [dot_realize, positive_projection]
      have hsum : 0 ≤ dot dimension row center +
          (supportRadius dimension row generators : Int) := by omega
      have habsSum := Int.natAbs_of_nonneg hsum
      have habsCenter := Int.natAbs_of_nonneg hc
      omega
    · let coefficients := negativeCoefficients dimension row generators
      refine ⟨realize center generators coefficients,
        ⟨coefficients, negative_bounded dimension row generators, rfl⟩, ?_⟩
      rw [dot_realize, negative_projection]
      have hc' : dot dimension row center < 0 := by omega
      have hsum : dot dimension row center -
          (supportRadius dimension row generators : Int) ≤ 0 := by omega
      have habsSum := Int.natAbs_of_nonneg (show 0 ≤ -(dot dimension row center -
        (supportRadius dimension row generators : Int)) by omega)
      have habsCenter := Int.natAbs_of_nonneg
        (show 0 ≤ -(dot dimension row center) by omega)
      rw [← Int.natAbs_neg] at habsSum habsCenter
      omega

/-- A producer is soundly enclosed when each output lies in the generated
domain. -/
def Contained {Input : Type} (producer : Input → Vector) (center : Vector)
    (generators : List Generator) : Prop :=
  ∀ input, InDomain center generators (producer input)

/-- Domain containment transports the exact domain support to a sound bound for
all outputs of a real producer. -/
theorem contained_upper {Input : Type} (producer : Input → Vector)
    (center row : Vector) (generators : List Generator) (dimension : Nat)
    (contained : Contained producer center generators) (input : Input) :
    (dot dimension row (producer input)).natAbs ≤
      (dot dimension row center).natAbs + supportRadius dimension row generators :=
  domain_upper dimension row center generators (producer input) (contained input)

/-- A row direction invisible on every producer output. -/
def ProducerNull {Input : Type} (dimension : Nat) (producer : Input → Vector)
    (direction : Vector) : Prop :=
  ∀ input, dot dimension direction (producer input) = 0

def sub (a b : Vector) : Vector := fun i => a i - b i

@[simp] theorem dot_sub (dimension : Nat) (a b x : Vector) :
    dot dimension (sub a b) x = dot dimension a x - dot dimension b x := by
  induction dimension with
  | zero => simp [dot]
  | succ n ih =>
      simp only [dot, sub, Int.sub_mul, ih]
      omega

/-- Equality modulo producer-null directions is exactly equality of every
producer projection. -/
theorem equivalent_iff_difference_null {Input : Type} (dimension : Nat)
    (producer : Input → Vector) (row₁ row₂ : Vector) :
    ProducerNull dimension producer (sub row₁ row₂) ↔
      ∀ input, dot dimension row₁ (producer input) =
        dot dimension row₂ (producer input) := by
  constructor <;> intro h input
  · have := h input
    rw [dot_sub] at this
    omega
  · rw [dot_sub, h input]
    omega

/-- Any absolute-error objective on actual producer outputs factors exactly
through rows modulo producer-null directions. -/
theorem natAbs_eq_of_difference_null {Input : Type} (dimension : Nat)
    (producer : Input → Vector) (row₁ row₂ : Vector)
    (null : ProducerNull dimension producer (sub row₁ row₂)) (input : Input) :
    (dot dimension row₁ (producer input)).natAbs =
      (dot dimension row₂ (producer input)).natAbs := by
  rw [(equivalent_iff_difference_null dimension producer row₁ row₂).mp null input]

/-- The `ℓ₁` mass of the first `dimension` factor coordinates. -/
def l1 : Nat → Vector → Nat
  | 0, _ => 0
  | n + 1, factors => (factors n).natAbs + l1 n factors

/-- A rational dual probe with denominator `Q` lies in the signed unit box. -/
def ProbeBounded (dimension Q : Nat) (probe : Vector) : Prop :=
  ∀ i, i < dimension → (probe i).natAbs ≤ Q

/-- Absolute form of the signed `ℓ₁` projection inequality. -/
theorem probe_dot_natAbs_le (dimension Q : Nat) (probe factors : Vector)
    (bounded : ProbeBounded dimension Q probe) :
    (dot dimension probe factors).natAbs ≤ Q * l1 dimension factors := by
  induction dimension with
  | zero => simp [dot, l1]
  | succ n ih =>
      have hprobe := bounded n (by omega)
      have htail := ih (fun i hi => bounded i (by omega))
      have hterm : (probe n * factors n).natAbs ≤ Q * (factors n).natAbs := by
        rw [Int.natAbs_mul]
        exact Nat.mul_le_mul_right (factors n).natAbs hprobe
      calc
        (dot (n + 1) probe factors).natAbs
            ≤ (probe n * factors n).natAbs +
                (dot n probe factors).natAbs := by
              simpa [dot] using
                Int.natAbs_add_le (probe n * factors n) (dot n probe factors)
        _ ≤ Q * (factors n).natAbs + Q * l1 n factors :=
              Nat.add_le_add hterm htail
        _ = Q * l1 (n + 1) factors := by
              simp [l1, Nat.mul_add]

/-- A signed probe bounded by `Q` underestimates `Q` times the `ℓ₁` mass. -/
theorem signedL1Projection_le (dimension Q : Nat) (probe factors : Vector)
    (bounded : ProbeBounded dimension Q probe) :
    dot dimension probe factors ≤ (Q : Int) * (l1 dimension factors : Int) := by
  exact Int.le_trans Int.le_natAbs
    (Int.ofNat_le.mpr (probe_dot_natAbs_le dimension Q probe factors bounded))

/-- One selected option from a separable robust search. Its factors are the
option's contributions to the shared generated-domain factors. -/
structure BlockChoice where
  cost : Nat
  factors : Vector

def totalCost : List BlockChoice → Nat
  | [] => 0
  | block :: blocks => block.cost + totalCost blocks

def totalFactors : List BlockChoice → Vector
  | [] => fun _ => 0
  | block :: blocks => fun j => block.factors j + totalFactors blocks j

/-- Integer numerator contributed by one selected option under a signed rational
probe `probe / Q`. -/
def dualScore (dimension Q lambda : Nat) (probe : Vector)
    (block : BlockChoice) : Int :=
  (Q : Int) * block.cost +
    (lambda : Int) * dot dimension probe block.factors

def dualScoreSum (dimension Q lambda : Nat) (probe : Vector) :
    List BlockChoice → Int
  | [] => 0
  | block :: blocks => dualScore dimension Q lambda probe block +
      dualScoreSum dimension Q lambda probe blocks

/-- Supplied per-block minima bound the score of every selected option. The
recursive relation also records that the minima and block lists have the same
shape. -/
def ScoresLowerBound (dimension Q lambda : Nat) (probe : Vector) :
    List Int → List BlockChoice → Prop
  | [], [] => True
  | minimum :: minima, block :: blocks =>
      minimum ≤ dualScore dimension Q lambda probe block ∧
        ScoresLowerBound dimension Q lambda probe minima blocks
  | _, _ => False

theorem minima_sum_le_dualScoreSum (dimension Q lambda : Nat) (probe : Vector)
    (minima : List Int) (blocks : List BlockChoice)
    (bounds : ScoresLowerBound dimension Q lambda probe minima blocks) :
    minima.sum ≤ dualScoreSum dimension Q lambda probe blocks := by
  induction minima generalizing blocks with
  | nil =>
      cases blocks <;> simp_all [ScoresLowerBound, dualScoreSum]
  | cons minimum minima ih =>
      cases blocks with
      | nil => simp_all [ScoresLowerBound]
      | cons block blocks =>
          rcases bounds with ⟨hblock, hblocks⟩
          simp only [List.sum_cons, dualScoreSum]
          exact Int.add_le_add hblock (ih blocks hblocks)

/-- Summing option scores is exactly scoring the summed cost and factor vector. -/
theorem dualScoreSum_eq (dimension Q lambda : Nat) (probe : Vector)
    (blocks : List BlockChoice) :
    dualScoreSum dimension Q lambda probe blocks =
      (Q : Int) * (totalCost blocks : Int) +
        (lambda : Int) * dot dimension probe (totalFactors blocks) := by
  induction blocks with
  | nil => simp [dualScoreSum, totalCost, totalFactors]
  | cons block blocks ih =>
      simp only [dualScoreSum, dualScore, totalCost, totalFactors, Int.natCast_add,
        dot_add, ih, Int.mul_add]
      ac_rfl

def dualNumerator (Q static : Nat) (minima : List Int) : Int :=
  (Q : Int) * static + minima.sum

/-- Exact robust objective for selected blocks after their factor contributions
have been summed. -/
def robustObjective (dimension static lambda : Nat)
    (blocks : List BlockChoice) : Nat :=
  static + totalCost blocks + lambda * l1 dimension (totalFactors blocks)

/-- Per-option dual inequalities and a bounded signed probe give the cleared
integer lower bound used by certificate replay. No LP solver is trusted here. -/
theorem separableDual_lower (dimension Q static lambda : Nat) (probe : Vector)
    (minima : List Int) (blocks : List BlockChoice)
    (probeBounded : ProbeBounded dimension Q probe)
    (optionBounds : ScoresLowerBound dimension Q lambda probe minima blocks) :
    dualNumerator Q static minima ≤
      (Q : Int) * (robustObjective dimension static lambda blocks : Int) := by
  have hmin := minima_sum_le_dualScoreSum dimension Q lambda probe minima blocks
    optionBounds
  have hprobe := signedL1Projection_le dimension Q probe (totalFactors blocks)
    probeBounded
  have hscaled := Int.mul_le_mul_of_nonneg_left hprobe (Int.natCast_nonneg lambda)
  calc
    dualNumerator Q static minima
        ≤ (Q : Int) * static + dualScoreSum dimension Q lambda probe blocks :=
          Int.add_le_add_left hmin _
    _ = (Q : Int) * static + (Q : Int) * totalCost blocks +
          (lambda : Int) * dot dimension probe (totalFactors blocks) := by
          rw [dualScoreSum_eq]
          omega
    _ ≤ (Q : Int) * static + (Q : Int) * totalCost blocks +
          (lambda : Int) * ((Q : Int) * l1 dimension (totalFactors blocks)) :=
          Int.add_le_add_left hscaled _
    _ = (Q : Int) * (robustObjective dimension static lambda blocks : Int) := by
          simp only [robustObjective, Int.natCast_add, Int.natCast_mul, Int.mul_add]
          ac_rfl

/-- Natural-number ceiling division used after a nonnegative dual numerator is
replayed. -/
def ceilDiv (numerator denominator : Nat) : Nat :=
  (numerator + denominator - 1) / denominator

private theorem ceilDiv_le_of_le_mul {numerator denominator objective : Nat}
    (positive : 0 < denominator) (bounded : numerator ≤ denominator * objective) :
    ceilDiv numerator denominator ≤ objective := by
  unfold ceilDiv
  apply (Nat.div_le_iff_le_mul positive).2
  have reordered : numerator ≤ objective * denominator := by
    simpa [Nat.mul_comm] using bounded
  exact Nat.sub_le_sub_right (Nat.add_le_add_right reordered denominator) 1

/-- The executable certificate value
`ceil((Q * static + sum minima) / Q)` is a lower bound on the exact robust
objective. A certificate supplies positivity of `Q` and of its replayed
numerator. -/
theorem separableDual_ceiling_lower (dimension Q static lambda : Nat)
    (probe : Vector) (minima : List Int) (blocks : List BlockChoice)
    (positiveQ : 0 < Q)
    (numeratorNonnegative : 0 ≤ dualNumerator Q static minima)
    (probeBounded : ProbeBounded dimension Q probe)
    (optionBounds : ScoresLowerBound dimension Q lambda probe minima blocks) :
    ceilDiv (dualNumerator Q static minima).toNat Q ≤
      robustObjective dimension static lambda blocks := by
  apply ceilDiv_le_of_le_mul positiveQ
  rw [← Int.ofNat_le, Int.toNat_of_nonneg numeratorNonnegative]
  simpa using separableDual_lower dimension Q static lambda probe minima blocks
    probeBounded optionBounds

#print axioms exact_support
#print axioms contained_upper
#print axioms equivalent_iff_difference_null
#print axioms signedL1Projection_le
#print axioms separableDual_lower
#print axioms separableDual_ceiling_lower

end Kelana.ProducerDomain
