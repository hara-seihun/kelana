import Std

namespace Kelana.CausalOddsRank

def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind [ih ht]

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_sub (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i - g i) = total xs f - total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul_right (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i * a) = total xs f * a := by
  calc
    _ = total xs (fun i => a * f i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = a * total xs f := total_mul xs _ _
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

private theorem total_constant (xs : List I) (a : Rat) :
    total xs (fun _ => a) = (xs.length : Rat) * a := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons, List.length_cons,
      Rat.natCast_add] at ih ⊢
    grind +ring

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    have hr := ih ht
    change 0 ≤ f i + total xs f
    grind

/-- For nonempty `keys` this is the ordinary rational row mean. The empty
    list is also defined, but has no keys to center and does not support
    dividing a nonzero error by its cardinality. -/
def mean (keys : List K) (f : K → Rat) : Rat :=
  total keys f * (keys.length : Rat)⁻¹

def centered (keys : List K) (f : K → Rat) (k : K) : Rat :=
  f k - mean keys f

def candidate (features : List F) (psi : F → Q → Rat)
    (phi : F → K → Rat) (bias : Q → Rat) (q : Q) (k : K) : Rat :=
  total features (fun f => psi f q * phi f k) + bias q

private theorem mean_add (keys : List K) (f g : K → Rat) :
    mean keys (fun k => f k + g k) = mean keys f + mean keys g := by
  unfold mean
  rw [total_add]
  grind +ring

private theorem mean_mul (keys : List K) (a : Rat) (f : K → Rat) :
    mean keys (fun k => a * f k) = a * mean keys f := by
  unfold mean
  rw [total_mul]
  grind +ring

private theorem mean_constant (keys : List K) (a : Rat)
    (h : keys ≠ []) : mean keys (fun _ => a) = a := by
  unfold mean
  rw [total_constant]
  have hn : (keys.length : Rat) ≠ 0 := by
    have hp : 0 < keys.length := by
      cases keys with
      | nil => exact False.elim (h rfl)
      | cons k ks => simp
    have hrat : (0 : Rat) < (keys.length : Rat) := by exact_mod_cast hp
    grind
  have hinv := Rat.mul_inv_cancel (keys.length : Rat) hn
  grind +ring

/-- For every nonempty finite key list, centering removes the per-query bias
    and preserves the SAME feature index set, with each feature centered over
    the key list. No factorization of the centered answer is hypothesized. -/
theorem centered_factorization (keys : List K) (features : List F)
    (psi : F → Q → Rat) (phi : F → K → Rat) (bias : Q → Rat)
    (nonempty : keys ≠ []) (q : Q) (k : K) :
    centered keys (candidate features psi phi bias q) k =
      total features (fun f => psi f q * centered keys (phi f) k) := by
  have hmean : mean keys (candidate features psi phi bias q) =
      total features (fun f => psi f q * mean keys (phi f)) + bias q := by
    unfold candidate
    rw [mean_add, mean_constant keys (bias q) nonempty]
    have hcomm : mean keys (fun k => total features (fun f => psi f q * phi f k)) =
        total features (fun f => psi f q * mean keys (phi f)) := by
      unfold mean
      rw [total_comm]
      rw [← total_mul_right]
      apply total_congr features; intro f hf
      rw [total_mul]
      grind +ring
    rw [hcomm]
  unfold centered
  rw [hmean]
  unfold candidate
  calc
    _ = total features (fun f => psi f q * phi f k) -
        total features (fun f => psi f q * mean keys (phi f)) := by grind
    _ = total features (fun f => psi f q *
        (phi f k - mean keys (phi f))) := by
      rw [← total_sub]
      apply total_congr features; intro f hf; grind +ring
    _ = _ := rfl

/-- Cleared-denominator row Pythagoras. `n*m=sum E` is the *actual mean*
    condition, not a premise about squared error. -/
theorem row_mean_pythagorean (keys : List K) (error : K → Rat)
    (m : Rat) (mean_equation : (keys.length : Rat) * m = total keys error) :
    total keys (fun k => (error k - m) * (error k - m)) +
      (keys.length : Rat) * m * m =
        total keys (fun k => error k * error k) := by
  have hsplit : total keys (fun k => (error k - m) * (error k - m)) =
      total keys (fun k => error k * error k) -
        2 * m * total keys error + (keys.length : Rat) * m * m := by
    calc
      _ = total keys (fun k => error k * error k -
          2 * m * error k + m * m) := by
        apply total_congr keys; intro k hk; grind +ring
      _ = _ := by
        have ha : total keys (fun k => error k * error k - 2 * m * error k + m * m) =
          total keys (fun k => error k * error k - 2 * m * error k) +
            total keys (fun _ => m * m) := by
          exact total_add keys
            (fun k => error k * error k - 2 * m * error k)
            (fun _ => m * m)
        have hb : total keys (fun k => error k * error k - 2 * m * error k) =
            total keys (fun k => error k * error k) -
              2 * m * total keys error := by
          calc
            _ = total keys (fun k => error k * error k + -(2*m) * error k) := by
              apply total_congr keys; intro k hk; grind +ring
            _ = total keys (fun k => error k * error k) +
                total keys (fun k => -(2*m) * error k) := total_add keys _ _
            _ = _ := by rw [total_mul]; grind +ring
        rw [ha, hb, total_constant]
        grind +ring
  rw [hsplit]
  grind +ring

private theorem mean_equation (keys : List K) (error : K → Rat)
    (nonempty : keys ≠ []) :
    (keys.length : Rat) * mean keys error = total keys error := by
  unfold mean
  have hn : (keys.length : Rat) ≠ 0 := by
    cases keys with
    | nil => exact False.elim (nonempty rfl)
    | cons k ks =>
      have hp : 0 < (k :: ks).length := by simp
      have hrat : (0 : Rat) < (((k :: ks).length : Nat) : Rat) := by
        exact_mod_cast hp
      grind
  have hi := Rat.mul_inv_cancel (keys.length : Rat) hn
  grind +ring

theorem centered_mean_zero (keys : List K) (f : K → Rat)
    (nonempty : keys ≠ []) : mean keys (centered keys f) = 0 := by
  have hs : total keys (centered keys f) = 0 := by
    unfold centered
    rw [total_sub, total_constant]
    have h := mean_equation keys f nonempty
    grind
  unfold mean
  rw [hs]
  grind

/-- Centering a row cannot increase its squared norm. This uses a proved
    Pythagorean identity and positivity of the omitted mean square. -/
theorem row_centering_contraction (keys : List K) (error : K → Rat)
    (nonempty : keys ≠ []) :
    total keys (fun k => centered keys error k * centered keys error k) ≤
      total keys (fun k => error k * error k) := by
  have h := row_mean_pythagorean keys error (mean keys error)
    (mean_equation keys error nonempty)
  have hm : 0 ≤ (keys.length : Rat) * mean keys error * mean keys error := by
    have hn : 0 ≤ (keys.length : Rat) := by exact_mod_cast Nat.zero_le _
    have hs := square_nonneg (mean keys error)
    have hp := Rat.mul_nonneg hn hs
    grind +ring
  unfold centered
  grind

/-- Exact finite-matrix Pythagoras: the omitted energy is one row-mean
    square per query, each multiplied by the shared key count. -/
theorem matrix_mean_pythagorean (queries : List Q) (keys : List K)
    (error : Q → K → Rat) (nonempty : keys ≠ []) :
    total queries (fun q => total keys (fun k =>
      centered keys (error q) k * centered keys (error q) k)) +
      (keys.length : Rat) * total queries (fun q => mean keys (error q) * mean keys (error q)) =
    total queries (fun q => total keys (fun k => error q k * error q k)) := by
  rw [← total_mul, ← total_add]
  apply total_congr queries
  intro q hq
  have h := row_mean_pythagorean keys (error q) (mean keys (error q))
    (mean_equation keys (error q) nonempty)
  unfold centered
  grind +ring

/-- Row centering over arbitrary query/key lists contracts Frobenius error;
    no rank or probabilistic premise is involved. -/
theorem matrix_centering_contraction (queries : List Q) (keys : List K)
    (error : Q → K → Rat) (nonempty : keys ≠ []) :
    total queries (fun q => total keys (fun k =>
      centered keys (error q) k * centered keys (error q) k)) ≤
    total queries (fun q => total keys (fun k =>
      error q k * error q k)) := by
  exact total_le queries _ _ (by
    intro q hq
    exact row_centering_contraction keys (error q) nonempty)

def exampleOdds (q : Bool) (k : Fin 3) : Rat :=
  if q then
    (if k.val = 1 then 1 else if k.val = 2 then -1 else 0)
  else
    (if k.val = 0 then 1 else if k.val = 2 then -1 else 0)

theorem example_odds_centered (q : Bool) :
    mean (List.finRange 3) (exampleOdds q) = 0 := by
  cases q <;> decide +kernel

/-- Two centered query rows [1,0,-1] and [0,1,-1] cannot be represented by
    one scalar key feature plus arbitrary query biases. The contradiction is
    the exact nonzero 2×2 minor of the two row-difference vectors. -/
theorem two_query_three_key_rank_two :
    ¬∃ (psi : Bool → Rat) (phi : Fin 3 → Rat) (bias : Bool → Rat),
      (∀ q : Bool, ∀ k : Fin 3,
        exampleOdds q k = psi q * phi k + bias q) := by
  rintro ⟨psi, phi, bias, fits⟩
  have a₀ := fits false ⟨0, by decide⟩
  have a₁ := fits false ⟨1, by decide⟩
  have a₂ := fits false ⟨2, by decide⟩
  have b₀ := fits true ⟨0, by decide⟩
  have b₁ := fits true ⟨1, by decide⟩
  have b₂ := fits true ⟨2, by decide⟩
  simp only [exampleOdds, ↓reduceIte] at a₀ a₁ a₂ b₀ b₁ b₂
  have hdet :
      (psi false * (phi 0 - phi 2)) *
        (psi true * (phi 1 - phi 2)) =
      (psi false * (phi 1 - phi 2)) *
        (psi true * (phi 0 - phi 2)) := by grind +ring
  grind +ring

end Kelana.CausalOddsRank
