import Kelana.ValueCoordinateGauge

namespace Kelana.SharedSketchCovariance

open ValueCoordinateGauge (total finite_gram_identity)

theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a*f i) = a*total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

theorem total_mul_right (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i*a) = total xs f*a := by
  calc
    _ = total xs (fun i => a*f i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = a*total xs f := total_mul xs a f
    _ = _ := Rat.mul_comm _ _

theorem total_comm (xs : List I) (ys : List J) (f : I → J → Rat) :
    total xs (fun i => total ys (f i)) =
      total ys (fun j => total xs (fun i => f i j)) := by
  induction xs with
  | nil =>
    simp only [total, List.map_nil, List.sum_nil]
    induction ys with
    | nil => rfl
    | cons j ys ih => simp only [List.map_cons, List.sum_cons]; grind
  | cons i xs ih =>
    change total ys (f i) + total xs (fun k => total ys (f k)) =
      total ys (fun j => f i j + total xs (fun k => f k j))
    rw [ih, total_add]

theorem total_weighted_comm (xs : List I) (ys : List J)
    (w : I → Rat) (f : I → J → Rat) :
    total xs (fun i => w i*total ys (fun j => f i j)) =
      total ys (fun j => total xs (fun i => w i*f i j)) := by
  calc
    _ = total xs (fun i => total ys (fun j => w i*f i j)) := by
      apply total_congr xs
      intro i hi
      exact (total_mul ys (w i) (f i)).symm
    _ = _ := total_comm xs ys _

theorem total_zero (xs : List I) :
    total xs (fun _ => (0:Rat)) = 0 := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    change 0 + total xs (fun _ => (0:Rat)) = 0
    grind

theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    change 0 ≤ f i + total xs f
    grind [ih ht]

theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

/-- A shared random outcome drives *all* key errors in one output response.
    There is no iid-key premise and no Gaussian assumption. -/
def response (keys : List I) (A : O → I → Rat)
    (E : Ω → I → Rat) (ω : Ω) (o : O) : Rat :=
  total keys (fun i => A o i*E ω i)

def expectedSquared (outcomes : List Ω) (keys : List I) (outputs : List O)
    (μ : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) : Rat :=
  total outcomes (fun ω => μ ω *
    total outputs (fun o => response keys A E ω o*response keys A E ω o))

def mean (outcomes : List Ω) (μ : Ω → Rat) (E : Ω → I → Rat)
    (i : I) : Rat := total outcomes (fun ω => μ ω*E ω i)

def rawMoment (outcomes : List Ω) (μ : Ω → Rat)
    (E : Ω → I → Rat) (i j : I) : Rat :=
  total outcomes (fun ω => μ ω*(E ω i*E ω j))

def covariance (outcomes : List Ω) (μ : Ω → Rat)
    (E : Ω → I → Rat) (i j : I) : Rat :=
  total outcomes (fun ω => μ ω *
    ((E ω i-mean outcomes μ E i)*(E ω j-mean outcomes μ E j)))

def outputGram (outputs : List O) (A : O → I → Rat)
    (i j : I) : Rat :=
  total outputs (fun o => A o i*A o j)

/-- General finite pushforward identity: the sums over outcomes and all
    output rows are actually commuted after expanding each squared response
    by the existing finite Gram theorem. No target inequality is assumed. -/
theorem expectedSquared_eq_rawGram
    (outcomes : List Ω) (keys : List I) (outputs : List O)
    (μ : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) :
    expectedSquared outcomes keys outputs μ E A =
      total keys (fun i => total keys (fun j =>
        outputGram outputs A i j*rawMoment outcomes μ E i j)) := by
  unfold expectedSquared
  calc
    _ = total outcomes (fun ω => μ ω *
        total keys (fun i => total keys (fun j =>
          outputGram outputs A i j*E ω i*E ω j))) := by
      apply total_congr outcomes
      intro ω hω
      congr 1
      have h := finite_gram_identity keys outputs
        (fun i o => A o i) (E ω)
      simpa only [response, outputGram] using h
    _ = total keys (fun i => total outcomes (fun ω => μ ω *
        total keys (fun j => outputGram outputs A i j*E ω i*E ω j))) :=
      total_weighted_comm outcomes keys μ _
    _ = total keys (fun i => total keys (fun j =>
        total outcomes (fun ω => μ ω *
          (outputGram outputs A i j*E ω i*E ω j)))) := by
      apply total_congr keys
      intro i hi
      exact total_weighted_comm outcomes keys μ _
    _ = _ := by
      apply total_congr keys
      intro i hi
      apply total_congr keys
      intro j hj
      calc
        _ = total outcomes (fun ω =>
            (outputGram outputs A i j)*(μ ω*(E ω i*E ω j))) := by
          apply total_congr outcomes
          intro ω hω
          grind +ring
        _ = (outputGram outputs A i j)*
            total outcomes (fun ω => μ ω*(E ω i*E ω j)) := total_mul _ _ _
        _ = _ := rfl

/-- For zero-mean key errors, the actual centered covariance is precisely
    the second moment that occurs in the pushforward Gram. -/
theorem covariance_eq_raw_of_zero_mean
    (outcomes : List Ω) (μ : Ω → Rat) (E : Ω → I → Rat)
    (i j : I) (hi : mean outcomes μ E i = 0)
    (hj : mean outcomes μ E j = 0) :
    covariance outcomes μ E i j = rawMoment outcomes μ E i j := by
  unfold covariance rawMoment
  apply total_congr outcomes
  intro ω hω
  rw [hi, hj]
  grind +ring

/-- Probability weights summing to one and zero means make this the exact
    *complete-output* covariance formula. Normalization is stipulated for
    its probabilistic meaning; the finite algebra is valid more generally. -/
theorem expectedSquared_eq_covarianceGram
    (outcomes : List Ω) (keys : List I) (outputs : List O)
    (μ : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat)
    (_hμ : total outcomes μ = 1)
    (hzero : ∀ i ∈ keys, mean outcomes μ E i = 0) :
    expectedSquared outcomes keys outputs μ E A =
      total keys (fun i => total keys (fun j =>
        outputGram outputs A i j*covariance outcomes μ E i j)) := by
  rw [expectedSquared_eq_rawGram]
  apply total_congr keys
  intro i hi
  apply total_congr keys
  intro j hj
  rw [covariance_eq_raw_of_zero_mean outcomes μ E i j (hzero i hi) (hzero j hj)]

/-- The covariance is symmetric even for signed finite weights. -/
theorem covariance_symmetric (outcomes : List Ω) (μ : Ω → Rat)
    (E : Ω → I → Rat) (i j : I) :
    covariance outcomes μ E i j = covariance outcomes μ E j i := by
  unfold covariance
  apply total_congr outcomes
  intro ω hω
  grind +ring

/-- Nonnegative outcome weights make every complete output SSE nonnegative. -/
theorem expectedSquared_nonneg
    (outcomes : List Ω) (keys : List I) (outputs : List O)
    (μ : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat)
    (hμ : ∀ ω ∈ outcomes, 0 ≤ μ ω) :
    0 ≤ expectedSquared outcomes keys outputs μ E A := by
  unfold expectedSquared
  apply total_nonneg outcomes (fun ω =>
    μ ω * total outputs (fun o =>
      response keys A E ω o*response keys A E ω o))
  intro ω hω
  apply Rat.mul_nonneg (hμ ω hω)
  apply total_nonneg outputs
    (fun o => response keys A E ω o*response keys A E ω o)
  intro o ho
  exact square_nonneg _

/-- The centered covariance quadratic is the expected square of the
    corresponding linear key-error response; PSD is derived, not stipulated. -/
theorem covariance_quadratic_nonneg
    (outcomes : List Ω) (keys : List I)
    (μ : Ω → Rat) (E : Ω → I → Rat) (v : I → Rat)
    (hμ : ∀ ω ∈ outcomes, 0 ≤ μ ω) :
    0 ≤ total keys (fun i => total keys (fun j =>
      v i*covariance outcomes μ E i j*v j)) := by
  let centered : Ω → I → Rat := fun ω i => E ω i-mean outcomes μ E i
  let row : Unit → I → Rat := fun _ i => v i
  have hnonneg := expectedSquared_nonneg outcomes keys [()] μ centered row hμ
  have hidentity := expectedSquared_eq_rawGram outcomes keys [()] μ centered row
  have hcov : ∀ i j : I,
      rawMoment outcomes μ centered i j = covariance outcomes μ E i j := by
    intro i j
    rfl
  have hgram : ∀ i j : I, outputGram [()] row i j = v i*v j := by
    intro i j
    simp [outputGram, total, row]
    grind
  rw [hidentity] at hnonneg
  have heq : total keys (fun i => total keys (fun j =>
      outputGram [()] row i j*rawMoment outcomes μ centered i j)) =
      total keys (fun i => total keys (fun j =>
        v i*covariance outcomes μ E i j*v j)) := by
    apply total_congr keys
    intro i hi
    apply total_congr keys
    intro j hj
    rw [hcov i j, hgram i j]
    grind +ring
  rw [heq] at hnonneg
  exact hnonneg

/-- If every key receives the *same* random error and each output row sums
    to zero, complete output error vanishes for each outcome individually. -/
theorem common_mode_response_zero
    (keys : List I) (A : O → I → Rat)
    (E : Ω → I → Rat) (c : Ω → Rat)
    (ω : Ω) (o : O)
    (hcommon : ∀ i ∈ keys, E ω i = c ω)
    (hrow : total keys (fun i => A o i) = 0) :
    response keys A E ω o = 0 := by
  unfold response
  calc
    _ = total keys (fun i => A o i*c ω) := by
      apply total_congr keys
      intro i hi
      rw [hcommon i hi]
    _ = total keys (fun i => A o i)*c ω := total_mul_right keys _ _
    _ = 0 := by rw [hrow]; grind

theorem common_mode_squared_zero
    (outcomes : List Ω) (keys : List I) (outputs : List O)
    (μ : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat)
    (c : Ω → Rat)
    (hcommon : ∀ ω ∈ outcomes, ∀ i ∈ keys, E ω i = c ω)
    (hrow : ∀ o ∈ outputs, total keys (fun i => A o i) = 0) :
    expectedSquared outcomes keys outputs μ E A = 0 := by
  unfold expectedSquared
  calc
    _ = total outcomes (fun _ => (0:Rat)) := by
      apply total_congr outcomes
      intro ω hω
      have houtputs : total outputs (fun o =>
          response keys A E ω o*response keys A E ω o) = 0 := by
        calc
          _ = total outputs (fun _ => (0:Rat)) := by
            apply total_congr outputs
            intro o ho
            rw [common_mode_response_zero keys A E c ω o (hcommon ω hω) (hrow o ho)]
            grind
          _ = 0 := total_zero outputs
      rw [houtputs]
      grind
    _ = 0 := total_zero outcomes

end Kelana.SharedSketchCovariance
