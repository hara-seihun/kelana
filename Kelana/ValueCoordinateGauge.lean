import Std

namespace Kelana.ValueCoordinateGauge

/-- Exact finite rational sums. `pairIndices` lists each token/coordinate (or
    time/output) pair once, retaining both indices in the Gram formula. -/
def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

def cartesian (xs : List I) (ys : List J) : List (I × J) :=
  xs.flatMap (fun i => ys.map (fun j => (i,j)))

def pairIndices (N M : Nat) : List (Fin N × Fin M) :=
  cartesian (List.finRange N) (List.finRange M)

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a*f i) = a*total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul_right (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i*a) = total xs f*a := by
  calc
    _ = total xs (fun i => a*f i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = a*total xs f := total_mul xs a f
    _ = _ := Rat.mul_comm _ _

private theorem total_comm (xs : List I) (ys : List J) (f : I → J → Rat) :
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

theorem total_append (xs ys : List I) (f : I → Rat) :
    total (xs ++ ys) f = total xs f + total ys f := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    change f i + total (xs ++ ys) f =
      f i + total xs f + total ys f
    rw [ih]
    grind

/-- Flattening the Cartesian product is an actual nested finite sum. -/
theorem total_pairs (xs : List I) (ys : List J) (f : I × J → Rat) :
    total (cartesian xs ys) f =
      total xs (fun i => total ys (fun j => f (i,j))) := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    change total ((ys.map (fun j => (i,j))) ++ cartesian xs ys) f =
      total ys (fun j => f (i,j)) +
        total xs (fun k => total ys (fun j => f (k,j)))
    rw [total_append, ih]
    simp [total, List.map_map, Function.comp_def]

theorem total_perm {xs ys : List I} (f : I → Rat)
    (hp : xs.Perm ys) : total xs f = total ys f := by
  induction hp with
  | nil => rfl
  | cons x hp ih =>
    change f x + total _ f = f x + total _ f
    rw [ih]
  | swap x y xs =>
    change f y + (f x + total xs f) =
      f x + (f y + total xs f)
    grind
  | trans _ _ ih1 ih2 => exact ih1.trans ih2

private theorem nodup_map_injective (xs : List I) (f : I → J)
    (hf : Function.Injective f) (hn : xs.Nodup) : (xs.map f).Nodup := by
  induction xs with
  | nil => simp
  | cons i xs ih =>
    obtain ⟨hnot, htail⟩ := List.nodup_cons.mp hn
    apply List.nodup_cons.mpr
    constructor
    · intro hm
      obtain ⟨j, hj, heq⟩ := List.mem_map.mp hm
      have same : i = j := hf heq.symm
      exact hnot (same ▸ hj)
    · exact ih htail

/-- A finite coordinate bijection and its inverse, stated without an
    external matrix/permutation library. -/
structure CoordinatePermutation (D : Nat) where
  forward : Fin D → Fin D
  backward : Fin D → Fin D
  left : ∀ d, backward (forward d) = d
  right : ∀ d, forward (backward d) = d

/-- An honest bijection of the listed finite coordinates supplies the list
    permutation witness used by the finite reindexing theorem. -/
theorem permutation_finRange {D : Nat} (σ : CoordinatePermutation D) :
    ((List.finRange D).map σ.forward).Perm (List.finRange D) := by
  have hinj : Function.Injective σ.forward := by
    intro i j h
    have hl := σ.left i
    have hr := σ.left j
    rw [h] at hl
    exact hl.symm.trans hr
  have hn : ((List.finRange D).map σ.forward).Nodup :=
    nodup_map_injective (List.finRange D) σ.forward hinj (List.nodup_finRange D)
  apply (List.perm_ext_iff_of_nodup hn (List.nodup_finRange D)).mpr
  intro i
  constructor
  · intro hi
    exact List.mem_finRange i
  · intro hi
    apply List.mem_map.mpr
    exact ⟨σ.backward i, List.mem_finRange _, σ.right i⟩

/-- Reindex an actual finite sum rather than assuming a permutation leaves
    the whole model output invariant. -/
theorem total_reindex {D : Nat} (σ : CoordinatePermutation D)
    (f : Fin D → Rat) :
    total (List.finRange D) (fun d => f (σ.forward d)) =
      total (List.finRange D) f := by
  calc
    _ = total ((List.finRange D).map σ.forward) f := by
      simp [total, List.map_map, Function.comp_def]
    _ = _ := total_perm f (permutation_finRange σ)

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    change 0 ≤ f i + total xs f
    grind [ih ht]

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

/-- A causal, possibly quantized-K probability tensor is fixed. Values are
    shared across heads; the output head matrix is head-specific. -/
def headOutput {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (V : Fin I → Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (t : Fin T) (o : Fin O) : Rat :=
  total (List.finRange H) (fun h =>
    total (List.finRange I) (fun i =>
      p h t i * total (List.finRange D) (fun d => W h o d * V i d)))

/-- Transport one value-coordinate permutation into the shared value table
    and into every head's corresponding output coordinate. -/
theorem value_coordinate_transport {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (V : Fin I → Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (σ : CoordinatePermutation D) (t : Fin T) (o : Fin O) :
    headOutput p (fun i d => V i (σ.forward d))
        (fun h o d => W h o (σ.forward d)) t o =
      headOutput p V W t o := by
  unfold headOutput
  apply total_congr (List.finRange H)
  intro h hh
  apply total_congr (List.finRange I)
  intro i hi
  rw [total_reindex σ (fun d => W h o d * V i d)]

/-- A common value translation has a query-independent observed correction
    when each head's probability row sums to one. -/
theorem headOutput_constant {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (c : Fin D → Rat) (W : Fin H → Fin O → Fin D → Rat)
    (t : Fin T) (o : Fin O)
    (hnorm : ∀ h, total (List.finRange I) (fun i => p h t i) = 1) :
    headOutput p (fun _ d => c d) W t o =
      total (List.finRange H) (fun h =>
        total (List.finRange D) (fun d => W h o d * c d)) := by
  unfold headOutput
  apply total_congr (List.finRange H)
  intro h hh
  rw [total_mul_right, hnorm h]
  simp

/-- Exact linearity in the shared V table; fixed probabilities and head
    matrices need not be small, normalized, or symmetric. -/
theorem headOutput_add {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (V e : Fin I → Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (t : Fin T) (o : Fin O) :
    headOutput p (fun i d => V i d + e i d) W t o =
      headOutput p V W t o + headOutput p e W t o := by
  unfold headOutput
  calc
    _ = total (List.finRange H) (fun h =>
        total (List.finRange I) (fun i =>
          p h t i * total (List.finRange D) (fun d => W h o d*V i d)) +
        total (List.finRange I) (fun i =>
          p h t i * total (List.finRange D) (fun d => W h o d*e i d))) := by
      apply total_congr (List.finRange H)
      intro h hh
      calc
        _ = total (List.finRange I) (fun i =>
            p h t i * total (List.finRange D) (fun d => W h o d*V i d) +
            p h t i * total (List.finRange D) (fun d => W h o d*e i d)) := by
          apply total_congr (List.finRange I)
          intro i hi
          have hcoord : total (List.finRange D) (fun d =>
              W h o d*(V i d+e i d)) =
              total (List.finRange D) (fun d => W h o d*V i d) +
                total (List.finRange D) (fun d => W h o d*e i d) := by
            calc
              _ = total (List.finRange D) (fun d =>
                  W h o d*V i d + W h o d*e i d) := by
                apply total_congr (List.finRange D)
                intro d hd
                grind +ring
              _ = _ := total_add _ _ _
          rw [hcoord]
          grind +ring
        _ = _ := total_add _ _ _
    _ = _ := total_add _ _ _

theorem headOutput_value_difference {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (V e : Fin I → Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (t : Fin T) (o : Fin O) :
    headOutput p (fun i d => V i d + e i d) W t o -
      headOutput p V W t o = headOutput p e W t o := by
  rw [headOutput_add]
  grind +ring

/-- Subtract once per arriving value and correct once after the summed-head
    output. No query or token-dependent correction is needed in exact Rat. -/
theorem value_translation_transport {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (V : Fin I → Fin D → Rat) (c : Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat) (t : Fin T) (o : Fin O)
    (hnorm : ∀ h, total (List.finRange I) (fun i => p h t i) = 1) :
    headOutput p (fun i d => V i d - c d) W t o +
      total (List.finRange H) (fun h =>
        total (List.finRange D) (fun d => W h o d * c d)) =
      headOutput p V W t o := by
  have h := headOutput_add p (fun i d => V i d - c d) (fun _ d => c d) W t o
  have hf : (fun i d => (V i d - c d) + c d) = V := by
    funext i d
    grind
  rw [hf, headOutput_constant p c W t o hnorm] at h
  exact h.symm

/-- The per-token/coordinate coefficient includes the complete *sum over
    heads* before any output error is squared. -/
def coefficient {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (t : Fin T) (o : Fin O) (i : Fin I) (d : Fin D) : Rat :=
  total (List.finRange H) (fun h => p h t i * W h o d)

def response {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (e : Fin I → Fin D → Rat)
    (t : Fin T) (o : Fin O) : Rat :=
  total (pairIndices I D) (fun a =>
    coefficient p W t o a.1 a.2 * e a.1 a.2)

/-- Fubini and distributivity identify the flattened response with actual
    summed-head output on the error table. -/
theorem response_eq_headOutput {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (e : Fin I → Fin D → Rat)
    (t : Fin T) (o : Fin O) :
    response p W e t o = headOutput p e W t o := by
  unfold response
  rw [pairIndices, total_pairs]
  have hcoord : ∀ i : Fin I,
      total (List.finRange D) (fun d => coefficient p W t o i d * e i d) =
      total (List.finRange H) (fun h =>
        p h t i * total (List.finRange D) (fun d => W h o d * e i d)) := by
    intro i
    calc
      _ = total (List.finRange D) (fun d =>
          total (List.finRange H) (fun h => (p h t i * W h o d)*e i d)) := by
        apply total_congr (List.finRange D)
        intro d hd
        unfold coefficient
        exact (total_mul_right (List.finRange H)
          (fun h => p h t i * W h o d) (e i d)).symm
      _ = total (List.finRange H) (fun h =>
          total (List.finRange D) (fun d => (p h t i * W h o d)*e i d)) :=
        total_comm _ _ _
      _ = _ := by
        apply total_congr (List.finRange H)
        intro h hh
        calc
          _ = total (List.finRange D) (fun d => p h t i * (W h o d * e i d)) := by
            apply total_congr (List.finRange D)
            intro d hd
            grind +ring
          _ = _ := total_mul _ _ _
  calc
    _ = total (List.finRange I) (fun i =>
        total (List.finRange H) (fun h =>
          p h t i * total (List.finRange D) (fun d => W h o d * e i d))) := by
      apply total_congr (List.finRange I)
      intro i hi
      exact hcoord i
    _ = _ := by
      rw [total_comm]
      rfl

/-- Total squared output error over the declared time/output sample pairs. -/
def squaredError {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (e : Fin I → Fin D → Rat) : Rat :=
  total (pairIndices T O) (fun s =>
    headOutput p e W s.1 s.2 * headOutput p e W s.1 s.2)

/-- Every (token,coordinate) Gram entry contracts over the *same* complete
    output response and therefore retains cross-head terms. -/
def gram {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (a b : Fin I × Fin D) : Rat :=
  total (pairIndices T O) (fun s =>
    coefficient p W s.1 s.2 a.1 a.2 *
      coefficient p W s.1 s.2 b.1 b.2)

theorem gram_symmetric {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (a b : Fin I × Fin D) : gram p W a b = gram p W b a := by
  unfold gram
  apply total_congr (pairIndices T O)
  intro s hs
  exact Rat.mul_comm _ _

def gramEnergy {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (e : Fin I → Fin D → Rat) : Rat :=
  total (pairIndices I D) (fun a =>
    total (pairIndices I D) (fun b =>
      gram p W a b * e a.1 a.2 * e b.1 b.2))

private theorem total_product (xs : List I) (ys : List J)
    (f : I → Rat) (g : J → Rat) :
    total xs f * total ys g =
      total xs (fun i => total ys (fun j => f i*g j)) := by
  calc
    _ = total xs (fun i => f i * total ys g) :=
      (total_mul_right xs f (total ys g)).symm
    _ = _ := by
      apply total_congr xs
      intro i hi
      exact (total_mul ys (f i) g).symm

/-- General finite Gram construction: the SSE of linear responses is exactly
    the full two-index Gram quadratic, with no PSD/equality assumption. -/
theorem finite_gram_identity (axes : List A) (samples : List S)
    (feature : A → S → Rat) (e : A → Rat) :
    total samples (fun s =>
      (total axes (fun a => feature a s*e a)) *
        (total axes (fun a => feature a s*e a))) =
    total axes (fun a => total axes (fun b =>
      (total samples (fun s => feature a s*feature b s)) *e a*e b)) := by
  calc
    _ = total samples (fun s => total axes (fun a =>
        total axes (fun b =>
          (feature a s*e a)*(feature b s*e b)))) := by
      apply total_congr samples
      intro s hs
      exact total_product axes axes _ _
    _ = total axes (fun a => total axes (fun b =>
        total samples (fun s => (feature a s*e a)*(feature b s*e b)))) := by
      rw [total_comm samples axes]
      apply total_congr axes
      intro a ha
      exact total_comm samples axes _
    _ = _ := by
      apply total_congr axes
      intro a ha
      apply total_congr axes
      intro b hb
      calc
        _ = total samples (fun s =>
            (e a*e b)*(feature a s*feature b s)) := by
          apply total_congr samples
          intro s hs
          grind +ring
        _ = (e a*e b)*total samples (fun s =>
            feature a s*feature b s) := total_mul _ _ _
        _ = _ := by grind +ring

/-- Exact complete multihead SSE as the requested token-coordinate Gram
    quadratic. In particular, all h≠g cross terms are present in `gram`. -/
theorem squaredError_eq_gramEnergy {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (e : Fin I → Fin D → Rat) :
    squaredError p W e = gramEnergy p W e := by
  unfold squaredError gramEnergy gram
  calc
    _ = total (pairIndices T O) (fun s =>
        response p W e s.1 s.2 * response p W e s.1 s.2) := by
      apply total_congr (pairIndices T O)
      intro s hs
      rw [response_eq_headOutput]
    _ = _ := finite_gram_identity (pairIndices I D) (pairIndices T O)
      (fun a s => coefficient p W s.1 s.2 a.1 a.2)
      (fun a => e a.1 a.2)

/-- The Gram energy is the SSE of the *actual output difference* caused
    by adding a shared value error table. This is exact in V with fixed p. -/
theorem actual_value_error_eq_gramEnergy {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (V e : Fin I → Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat) :
    total (pairIndices T O) (fun s =>
      (headOutput p (fun i d => V i d+e i d) W s.1 s.2 -
        headOutput p V W s.1 s.2) *
      (headOutput p (fun i d => V i d+e i d) W s.1 s.2 -
        headOutput p V W s.1 s.2)) = gramEnergy p W e := by
  calc
    _ = squaredError p W e := by
      apply total_congr (pairIndices T O)
      intro s hs
      rw [headOutput_value_difference]
    _ = _ := squaredError_eq_gramEnergy p W e

/-- PSD follows from the actual squared-response realization, not from a
    named PSD hypothesis on the Gram matrix. -/
theorem gramEnergy_nonneg {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (e : Fin I → Fin D → Rat) : 0 ≤ gramEnergy p W e := by
  rw [← squaredError_eq_gramEnergy]
  apply total_nonneg (pairIndices T O)
    (fun s => headOutput p e W s.1 s.2 * headOutput p e W s.1 s.2)
  intro s hs
  exact square_nonneg _

/-- A retained source value becomes quantized only after its causal flush.
    The same stored token error can therefore be multiplied by a time/token
    mask. Probabilities in the Gram need not sum to one, so this mask folds
    into its coefficients without changing the quadratic construction. -/
theorem masked_value_difference {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (mask : Fin T → Fin I → Rat)
    (V e : Fin I → Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat)
    (t : Fin T) (o : Fin O) :
    headOutput p (fun i d => V i d + mask t i * e i d) W t o -
      headOutput p V W t o =
      headOutput (fun h t i => p h t i * mask t i) e W t o := by
  rw [headOutput_value_difference]
  unfold headOutput
  apply total_congr (List.finRange H)
  intro h hh
  apply total_congr (List.finRange I)
  intro i hi
  have hcoord : total (List.finRange D) (fun d => W h o d * (mask t i * e i d)) =
      mask t i * total (List.finRange D) (fun d => W h o d * e i d) := by
    calc
      _ = total (List.finRange D) (fun d => mask t i * (W h o d * e i d)) := by
        apply total_congr (List.finRange D)
        intro d hd
        grind +ring
      _ = _ := total_mul _ _ _
  rw [hcoord]
  grind +ring

/-- Exact all-query Gram accounting for a fixed causal retention schedule. -/
theorem masked_actual_error_eq_gramEnergy {H T I D O : Nat}
    (p : Fin H → Fin T → Fin I → Rat)
    (mask : Fin T → Fin I → Rat)
    (V e : Fin I → Fin D → Rat)
    (W : Fin H → Fin O → Fin D → Rat) :
    total (pairIndices T O) (fun s =>
      (headOutput p (fun i d => V i d + mask s.1 i * e i d) W s.1 s.2 -
        headOutput p V W s.1 s.2) *
      (headOutput p (fun i d => V i d + mask s.1 i * e i d) W s.1 s.2 -
        headOutput p V W s.1 s.2)) =
      gramEnergy (fun h t i => p h t i * mask t i) W e := by
  calc
    _ = squaredError (fun h t i => p h t i * mask t i) W e := by
      apply total_congr (pairIndices T O)
      intro s hs
      rw [masked_value_difference]
    _ = _ := squaredError_eq_gramEnergy _ _ _

end Kelana.ValueCoordinateGauge
