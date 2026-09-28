import Std

namespace Kelana.FiberRank

/-- Ternary weights in the branch order used by the codec. -/
inductive Trit where
  | neg
  | zero
  | pos
  deriving DecidableEq, Repr

namespace Trit

def value : Trit → Int
  | neg => -1
  | zero => 0
  | pos => 1

end Trit

/-- Dot product of a ternary weight list and an integer probe. The codec
contracts below require equal lengths. -/
def response : List Trit → List Int → Int
  | trit :: weights, coefficient :: probe =>
      trit.value * coefficient + response weights probe
  | _, _ => 0

/-- Coordinatewise query residual `query - alpha * probe`. The linearity
theorem uses equal-length lists. -/
def queryResidual (alpha : Int) : List Int → List Int → List Int
  | coefficient :: probe, input :: query =>
      (input - alpha * coefficient) :: queryResidual alpha probe query
  | _, _ => []

/-- A query decomposes into its probe component and residual. This identity is
valid for signed probes, signed query coordinates, and any integer `alpha`. -/
theorem response_queryResidual (weights : List Trit) (probe query : List Int)
    (alpha : Int) (weights_probe : weights.length = probe.length)
    (probe_query : probe.length = query.length) :
    response weights query =
      alpha * response weights probe +
        response weights (queryResidual alpha probe query) := by
  induction weights generalizing probe query with
  | nil =>
      have probeNil : probe = [] := List.eq_nil_of_length_eq_zero (by simpa using weights_probe.symm)
      subst probe
      have queryNil : query = [] := List.eq_nil_of_length_eq_zero (by simpa using probe_query.symm)
      subst query
      simp [response]
  | cons trit weights ih =>
      cases probe with
      | nil => simp at weights_probe
      | cons coefficient probe =>
          cases query with
          | nil => simp at probe_query
          | cons input query =>
              have tailWeights : weights.length = probe.length := by
                simpa using weights_probe
              have tailQueries : probe.length = query.length := by
                simpa using probe_query
              have tailIdentity := ih probe query tailWeights tailQueries
              cases trit <;>
                simp [response, queryResidual, Trit.value, tailIdentity,
                  Int.mul_add, Int.mul_neg, Int.neg_mul] <;> omega

/-- Exact population of the suffix fiber with the requested response. -/
def count : List Int → Int → Nat
  | [], target => if target = 0 then 1 else 0
  | coefficient :: probe, target =>
      count probe (target + coefficient) + count probe target +
        count probe (target - coefficient)

/-- The suffix count obeys the three-way ternary recurrence, including when
the next probe coefficient is zero. -/
theorem count_cons (coefficient : Int) (probe : List Int) (target : Int) :
    count (coefficient :: probe) target =
      count probe (target + coefficient) + count probe target +
        count probe (target - coefficient) := rfl

/-- Rank a weight list inside a requested response fiber. Branches are ordered
`-1`, `0`, `+1`. -/
def rank : List Int → Int → List Trit → Nat
  | [], _, _ => 0
  | _ :: _, _, [] => 0
  | coefficient :: probe, target, Trit.neg :: weights =>
      rank probe (target + coefficient) weights
  | coefficient :: probe, target, Trit.zero :: weights =>
      count probe (target + coefficient) + rank probe target weights
  | coefficient :: probe, target, Trit.pos :: weights =>
      count probe (target + coefficient) + count probe target +
        rank probe (target - coefficient) weights

/-- Decode a bounded rank by selecting the count interval containing it. -/
def unrank : List Int → Int → Nat → List Trit
  | [], _, _ => []
  | coefficient :: probe, target, index =>
      let negativeCount := count probe (target + coefficient)
      if index < negativeCount then
        Trit.neg :: unrank probe (target + coefficient) index
      else
        let afterNegative := index - negativeCount
        let zeroCount := count probe target
        if afterNegative < zeroCount then
          Trit.zero :: unrank probe target afterNegative
        else
          Trit.pos :: unrank probe (target - coefficient)
            (afterNegative - zeroCount)

/-- Intrinsic evidence that a ternary list has the same length as its probe and
has the stated response. -/
inductive InFiber : List Trit → List Int → Int → Prop where
  | nil : InFiber [] [] 0
  | neg {weights probe tailResponse coefficient}
      (tail : InFiber weights probe tailResponse) :
      InFiber (Trit.neg :: weights) (coefficient :: probe)
        (tailResponse - coefficient)
  | zero {weights probe tailResponse coefficient}
      (tail : InFiber weights probe tailResponse) :
      InFiber (Trit.zero :: weights) (coefficient :: probe) tailResponse
  | pos {weights probe tailResponse coefficient}
      (tail : InFiber weights probe tailResponse) :
      InFiber (Trit.pos :: weights) (coefficient :: probe)
        (tailResponse + coefficient)

/-- Fiber evidence implies the ordinary equal-length and dot-product
conditions. -/
theorem InFiber.spec {weights : List Trit} {probe : List Int} {target : Int}
    (membership : InFiber weights probe target) :
    weights.length = probe.length ∧ response weights probe = target := by
  induction membership with
  | nil => simp [response]
  | neg tail ih =>
      constructor
      · simp [ih.1]
      · simp [response, Trit.value, ih.2]
        omega
  | zero tail ih =>
      constructor
      · simp [ih.1]
      · simp [response, Trit.value, ih.2]
  | pos tail ih =>
      constructor
      · simp [ih.1]
      · simp [response, Trit.value, ih.2]
        omega

/-- Equal lengths and the ordinary dot product reconstruct intrinsic fiber
evidence. -/
theorem inFiber_of_spec (weights : List Trit) (probe : List Int) (target : Int)
    (sameLength : weights.length = probe.length)
    (sameResponse : response weights probe = target) :
    InFiber weights probe target := by
  induction weights generalizing probe target with
  | nil =>
      cases probe with
      | nil =>
          have targetZero : target = 0 := by
            simpa [response] using sameResponse.symm
          subst target
          exact InFiber.nil
      | cons coefficient probe => simp at sameLength
  | cons trit weights ih =>
      cases probe with
      | nil => simp at sameLength
      | cons coefficient probe =>
          have tailLength : weights.length = probe.length := by
            simpa using sameLength
          cases trit with
          | neg =>
              have tail := ih probe (response weights probe) tailLength rfl
              have built := InFiber.neg (coefficient := coefficient) tail
              rw [← sameResponse]
              have headResponse :
                  response (Trit.neg :: weights) (coefficient :: probe) =
                    response weights probe - coefficient := by
                simp [response, Trit.value]
                omega
              rw [headResponse]
              exact built
          | zero =>
              have tail := ih probe (response weights probe) tailLength rfl
              have built := InFiber.zero (coefficient := coefficient) tail
              rw [← sameResponse]
              simpa [response, Trit.value] using built
          | pos =>
              have tail := ih probe (response weights probe) tailLength rfl
              have built := InFiber.pos (coefficient := coefficient) tail
              rw [← sameResponse]
              simpa [response, Trit.value, Int.add_comm] using built

/-- A valid fiber rank is strictly below the exact suffix-DP count. -/
theorem rank_lt_count {weights : List Trit} {probe : List Int} {target : Int}
    (membership : InFiber weights probe target) :
    rank probe target weights < count probe target := by
  induction membership with
  | nil => simp [rank, count]
  | @neg weights probe tailResponse coefficient tail ih =>
      simp only [rank, count]
      have normalized : tailResponse - coefficient + coefficient = tailResponse := by
        omega
      rw [normalized]
      omega
  | @zero weights probe tailResponse coefficient tail ih =>
      simp only [rank, count]
      omega
  | @pos weights probe tailResponse coefficient tail ih =>
      simp only [rank, count]
      have normalized : tailResponse + coefficient - coefficient = tailResponse := by
        omega
      rw [normalized]
      omega

/-- Decoding the rank of a member of a response fiber returns that exact
ternary weight list. -/
theorem unrank_rank {weights : List Trit} {probe : List Int} {target : Int}
    (membership : InFiber weights probe target) :
    unrank probe target (rank probe target weights) = weights := by
  induction membership with
  | nil => rfl
  | @neg weights probe tailResponse coefficient tail ih =>
      have normalized : tailResponse - coefficient + coefficient = tailResponse := by
        omega
      have hbound := rank_lt_count tail
      simp only [rank, unrank]
      simp only [normalized]
      rw [if_pos hbound]
      simp [ih]
  | @zero weights probe tailResponse coefficient tail ih =>
      have hbound := rank_lt_count tail
      have hnotNegative :
          ¬count probe (tailResponse + coefficient) + rank probe tailResponse weights <
            count probe (tailResponse + coefficient) := by omega
      simp only [rank, unrank]
      simp only [hnotNegative, Nat.add_sub_cancel_left, hbound, ih]
      simp
  | @pos weights probe tailResponse coefficient tail ih =>
      have normalized : tailResponse + coefficient - coefficient = tailResponse := by
        omega
      have hbound := rank_lt_count tail
      simp only [rank, unrank]
      simp only [normalized]
      let negativeCount := count probe (tailResponse + coefficient + coefficient)
      let zeroCount := count probe (tailResponse + coefficient)
      let tailRank := rank probe tailResponse weights
      change (if negativeCount + zeroCount + tailRank < negativeCount then _
        else if negativeCount + zeroCount + tailRank - negativeCount < zeroCount then _
        else Trit.pos :: unrank probe tailResponse
          (negativeCount + zeroCount + tailRank - negativeCount - zeroCount)) = _
      have hnotNegative : ¬negativeCount + zeroCount + tailRank < negativeCount := by
        omega
      rw [if_neg hnotNegative]
      have hremoveNegative :
          negativeCount + zeroCount + tailRank - negativeCount = zeroCount + tailRank := by
        omega
      rw [hremoveNegative]
      have hnotZero : ¬zeroCount + tailRank < zeroCount := by omega
      rw [if_neg hnotZero]
      have hremoveZero : zeroCount + tailRank - zeroCount = tailRank := by omega
      rw [hremoveZero]
      exact congrArg (Trit.pos :: ·) ih

/-- Every index below the suffix count decodes to a member of that response
fiber. -/
theorem unrank_inFiber (probe : List Int) (target : Int) (index : Nat)
    (index_lt : index < count probe target) :
    InFiber (unrank probe target index) probe target := by
  induction probe generalizing target index with
  | nil =>
      by_cases targetZero : target = 0
      · subst target
        exact InFiber.nil
      · simp [count, targetZero] at index_lt
  | cons coefficient probe ih =>
      simp only [count] at index_lt
      by_cases inNegative : index < count probe (target + coefficient)
      · simp only [unrank, inNegative, if_pos]
        have tail := ih (target + coefficient) index inNegative
        have built := InFiber.neg (coefficient := coefficient) tail
        have normalized : target + coefficient - coefficient = target := by omega
        simpa only [normalized] using built
      · have afterNegativeBound :
            index - count probe (target + coefficient) <
              count probe target + count probe (target - coefficient) := by
          omega
        by_cases inZero :
            index - count probe (target + coefficient) < count probe target
        · simp only [unrank, inNegative, if_false, inZero, if_true]
          exact InFiber.zero (coefficient := coefficient)
            (ih target (index - count probe (target + coefficient)) inZero)
        · have inPositive :
              index - count probe (target + coefficient) - count probe target <
                count probe (target - coefficient) := by
            omega
          simp only [unrank, inNegative, if_false, inZero]
          have tail := ih (target - coefficient)
            (index - count probe (target + coefficient) - count probe target)
            inPositive
          have built := InFiber.pos (coefficient := coefficient) tail
          have normalized : target - coefficient + coefficient = target := by omega
          simpa only [normalized] using built

/-- Ranking every bounded decoded index recovers that same index. Together
with `unrank_rank`, this makes the count intervals an exact bijection. -/
theorem rank_unrank (probe : List Int) (target : Int) (index : Nat)
    (index_lt : index < count probe target) :
    rank probe target (unrank probe target index) = index := by
  induction probe generalizing target index with
  | nil =>
      simp only [count] at index_lt
      by_cases targetZero : target = 0
      · subst target
        simp [rank] at index_lt ⊢
        omega
      · simp [targetZero] at index_lt
  | cons coefficient probe ih =>
      simp only [count] at index_lt
      by_cases inNegative : index < count probe (target + coefficient)
      · simp only [unrank, inNegative, if_pos, rank]
        exact ih (target + coefficient) index inNegative
      · by_cases inZero :
            index - count probe (target + coefficient) < count probe target
        · have tailRank := ih target
            (index - count probe (target + coefficient)) inZero
          simp only [unrank, inNegative, if_false, inZero, if_true, rank]
          rw [tailRank]
          omega
        · have inPositive :
              index - count probe (target + coefficient) - count probe target <
                count probe (target - coefficient) := by
            omega
          have tailRank := ih (target - coefficient)
            (index - count probe (target + coefficient) - count probe target)
            inPositive
          simp only [unrank, inNegative, if_false, inZero, rank]
          rw [tailRank]
          omega

/-- Public rank bound stated with the ordinary matching-length and response
conditions. -/
theorem rank_lt_count_of_response (weights : List Trit) (probe : List Int)
    (sameLength : weights.length = probe.length) :
    rank probe (response weights probe) weights <
      count probe (response weights probe) := by
  exact rank_lt_count (inFiber_of_spec weights probe (response weights probe)
    sameLength rfl)

/-- Public round-trip theorem stated with the ordinary matching-length and
response conditions. -/
theorem unrank_rank_of_response (weights : List Trit) (probe : List Int)
    (sameLength : weights.length = probe.length) :
    unrank probe (response weights probe)
      (rank probe (response weights probe) weights) = weights := by
  exact unrank_rank (inFiber_of_spec weights probe (response weights probe)
    sameLength rfl)

end Kelana.FiberRank
