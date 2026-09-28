import Std

namespace Kelana.EmissionTensor

/-- Enumerate all ordered words of a fixed length over an output alphabet.
    This is a tensor index set, not an autoregressive process. -/
def words (alphabet : List I) : Nat → List (List I)
  | 0 => [[]]
  | k + 1 => alphabet.flatMap fun i => (words alphabet k).map (i :: ·)

/-- Product feature of independent copies of the same emission vector. -/
def tensorAmplitude (a : I → Rat) (word : List I) : Rat :=
  (word.map a).prod

def dot (alphabet : List I) (a b : I → Rat) : Rat :=
  ((alphabet.map fun i => a i * b i)).sum

def tensorDot (alphabet : List I) (k : Nat) (a b : I → Rat) : Rat :=
  (((words alphabet k).map fun w =>
    tensorAmplitude a w * tensorAmplitude b w)).sum

private def total (xs : List I) (f : I → Rat) : Rat :=
  (xs.map f).sum

private theorem total_flatMap (xs : List I) (f : I → List J) (g : J → Rat) :
    total (xs.flatMap f) g = total xs (fun i => total (f i) g) := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    simp only [total, List.flatMap_cons, List.map_append, List.sum_append,
      List.map_cons, List.sum_cons]
    simpa only [total] using
      congrArg (fun z : Rat => total (f i) g + z) ih

private theorem total_map (xs : List I) (f : I → J) (g : J → Rat) :
    total (xs.map f) g = total xs (fun i => g (f i)) := by
  simp only [total, List.map_map, Function.comp_def]

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

/-- For every power, the full tensor-coordinate inner product equals the
    corresponding power of the one-copy fidelity. This proof uses the actual
    Cartesian word list and multiplicative product features, not a definition
    of the tensor Gram by exponentiation. -/
theorem tensor_dot_power (alphabet : List I) (k : Nat) (a b : I → Rat) :
    tensorDot alphabet k a b = (dot alphabet a b) ^ k := by
  induction k with
  | zero => simp [tensorDot, words, tensorAmplitude]; grind
  | succ k ih =>
    have hstep : tensorDot alphabet (k + 1) a b =
        dot alphabet a b * tensorDot alphabet k a b := by
      change total (alphabet.flatMap fun i =>
          (words alphabet k).map (i :: ·))
          (fun w => tensorAmplitude a w * tensorAmplitude b w) =
        total alphabet (fun i => a i * b i) *
          total (words alphabet k) (fun w =>
            tensorAmplitude a w * tensorAmplitude b w)
      rw [total_flatMap]
      calc
        _ = total alphabet (fun i => (a i * b i) *
            total (words alphabet k) (fun w =>
              tensorAmplitude a w * tensorAmplitude b w)) := by
          apply total_congr alphabet; intro i hi
          rw [total_map]
          calc
            _ = total (words alphabet k) (fun w =>
              (a i * b i) *
                (tensorAmplitude a w * tensorAmplitude b w)) := by
              apply total_congr (words alphabet k); intro w hw
              simp only [tensorAmplitude, List.map_cons, List.prod_cons]
              grind +ring
            _ = _ := total_mul _ _ _
        _ = total alphabet (fun i =>
            total (words alphabet k) (fun w =>
              tensorAmplitude a w * tensorAmplitude b w) * (a i * b i)) := by
          apply total_congr alphabet; intro i hi; exact Rat.mul_comm _ _
        _ = total (words alphabet k) (fun w =>
              tensorAmplitude a w * tensorAmplitude b w) *
              total alphabet (fun i => a i * b i) := total_mul _ _ _
        _ = _ := Rat.mul_comm _ _

    rw [hstep, ih, Rat.pow_succ]
    exact Rat.mul_comm _ _

/-- Gram entry of weighted tensor features on the full Cartesian output
    alphabet. Its definition does not precompute or assume a power identity. -/
def sourceGram (alphabet : List I) (k : Nat)
    (emission : S → I → Rat) (weight : S → Rat) (s t : S) : Rat :=
  dot (words alphabet k)
    (fun w => weight s * tensorAmplitude (emission s) w)
    (fun w => weight t * tensorAmplitude (emission t) w)

/-- Every weighted source-Gram entry is the corresponding one-copy Gram
    entry raised to k, with weights outside the power. The source-index
    dimension stays fixed as the Cartesian output dimension grows. -/
theorem source_gram_power (alphabet : List I) (k : Nat)
    (emission : S → I → Rat) (weight : S → Rat) (s t : S) :
    sourceGram alphabet k emission weight s t =
      weight s * weight t * (dot alphabet (emission s) (emission t)) ^ k := by
  change total (words alphabet k) (fun w =>
      (weight s * tensorAmplitude (emission s) w) *
        (weight t * tensorAmplitude (emission t) w)) = _
  calc
    _ = total (words alphabet k) (fun w =>
        (weight s * weight t) *
        (tensorAmplitude (emission s) w * tensorAmplitude (emission t) w)) := by
      apply total_congr (words alphabet k); intro w hw; grind +ring
    _ = weight s * weight t * tensorDot alphabet k (emission s) (emission t) :=
      total_mul _ _ _
    _ = _ := by rw [tensor_dot_power]

end Kelana.EmissionTensor
