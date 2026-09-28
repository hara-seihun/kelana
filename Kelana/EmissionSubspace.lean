import Std

namespace Kelana.EmissionSubspace

private theorem square_nonneg (z : Rat) : 0 ≤ z*z := by
  rcases (Rat.le_total (a := 0) (b := z)) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -z := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

private theorem scalar_error (a e x y : Rat) (he : 0 ≤ e)
    (hl : -e ≤ a) (hu : a ≤ e) :
    2 * a * x * y ≤ e * (x*x + y*y) := by
  by_cases hxy : 0 ≤ x*y
  · have h : 0 ≤ (e-a) * (x*y) := Rat.mul_nonneg (by grind) hxy
    have hs : 0 ≤ e * ((x-y)*(x-y)) :=
      Rat.mul_nonneg he (square_nonneg _)
    grind +ring
  · have hxy' : 0 ≤ -(x*y) := by grind
    have h : 0 ≤ (e+a) * (-(x*y)) := Rat.mul_nonneg (by grind) hxy'
    have hs : 0 ≤ e * ((x+y)*(x+y)) :=
      Rat.mul_nonneg he (square_nonneg _)
    grind +ring

def total {I : Type} (xs : List I) (f : I → Rat) : Rat :=
  (xs.map f).sum

private theorem total_le {I : Type} (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at *
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    have hrest := ih ht
    grind

private theorem total_add {I : Type} (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

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

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

/-- A rational error matrix enclosed entrywise by a symmetric nonnegative
    envelope has a quadratic form bounded by its maximum absolute row mass.
    This is the diagonal-dominance step of the spectral certificate; no
    numerical eigenvalue calculation enters the proof. -/
theorem row_error_bound {I : Type} (xs : List I)
    (error envelope : I → I → Rat) (x : I → Rat) (δ : Rat)
    (nonneg : ∀ i ∈ xs, ∀ j ∈ xs, 0 ≤ envelope i j)
    (symmetric : ∀ i ∈ xs, ∀ j ∈ xs, envelope i j = envelope j i)
    (lower : ∀ i ∈ xs, ∀ j ∈ xs, -envelope i j ≤ error i j)
    (upper : ∀ i ∈ xs, ∀ j ∈ xs, error i j ≤ envelope i j)
    (rows : ∀ i ∈ xs, total xs (envelope i) ≤ δ) :
    total xs (fun i => total xs (fun j => error i j * x i * x j)) ≤
      δ * total xs (fun i => x i * x i) := by
  have hpoint : ∀ i ∈ xs,
      2 * total xs (fun j => error i j * x i * x j) ≤
        total xs (fun j => envelope i j * (x i * x i + x j * x j)) := by
    intro i hi
    have h := total_le xs
      (fun j => 2 * (error i j * x i * x j))
      (fun j => envelope i j * (x i*x i + x j*x j))
      (by
        intro j hj
        have hs := scalar_error (error i j) (envelope i j)
          (x i) (x j) (nonneg i hi j hj) (lower i hi j hj) (upper i hi j hj)
        grind +ring)
    have heq : total xs (fun j => 2 * (error i j * x i * x j)) =
        2 * total xs (fun j => error i j * x i * x j) := total_mul xs _ _
    rw [heq] at h
    exact h
  have hsum := total_le xs
    (fun i => 2 * total xs (fun j => error i j * x i * x j))
    (fun i => total xs (fun j => envelope i j * (x i*x i + x j*x j))) hpoint
  rw [total_mul] at hsum
  have hrow : ∀ i ∈ xs,
      (x i*x i) * total xs (envelope i) ≤ δ * (x i*x i) := by
    intro i hi
    have hs := square_nonneg (x i)
    have h := Rat.mul_nonneg hs (by grind : 0 ≤ δ - total xs (envelope i))
    grind +ring
  have hrows := total_le xs
    (fun i => (x i*x i) * total xs (envelope i))
    (fun i => δ * (x i*x i)) hrow
  rw [total_mul] at hrows
  have hfirst : total xs (fun i => total xs (fun j => envelope i j * (x i*x i))) =
      total xs (fun i => (x i*x i) * total xs (envelope i)) := by
    apply total_congr xs
    intro i hi
    calc
      total xs (fun j => envelope i j * (x i*x i)) =
        total xs (fun j => (x i*x i) * envelope i j) := by
          apply total_congr xs; intro j hj; exact Rat.mul_comm _ _
      _ = (x i*x i) * total xs (envelope i) := total_mul xs _ _
  have hsecond : total xs (fun i => total xs (fun j => envelope i j * (x j*x j))) =
      total xs (fun i => (x i*x i) * total xs (envelope i)) := by
    rw [total_comm]
    apply total_congr xs
    intro j hj
    calc
      total xs (fun i => envelope i j * (x j*x j)) =
        total xs (fun i => (x j*x j) * envelope j i) := by
          apply total_congr xs; intro i hi
          rw [symmetric i hi j hj]; exact Rat.mul_comm _ _
      _ = (x j*x j) * total xs (envelope j) := total_mul xs _ _
  have hsplit :
      total xs (fun i => total xs (fun j => envelope i j * (x i*x i + x j*x j))) =
        total xs (fun i => (x i*x i) * total xs (envelope i)) +
        total xs (fun i => (x i*x i) * total xs (envelope i)) := by
    calc
      _ = total xs (fun i => total xs (fun j => envelope i j * (x i*x i)) +
          total xs (fun j => envelope i j * (x j*x j))) := by
            apply total_congr xs; intro i hi
            calc
              total xs (fun j => envelope i j * (x i*x i + x j*x j)) =
                  total xs (fun j => envelope i j * (x i*x i) +
                    envelope i j * (x j*x j)) := by
                    apply total_congr xs; intro j hj; exact Rat.mul_add _ _ _
              _ = _ := total_add xs _ _
      _ = _ := by rw [total_add, hfirst, hsecond]
  rw [hsplit] at hsum
  grind

private theorem total_zero (xs : List I) (f : I → Rat)
    (h : ∀ i ∈ xs, f i = 0) : total xs f = 0 := by
  induction xs with
  | nil => rfl
  | cons i ys ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ ys, f j = 0 := by grind
    simp only [total, List.map_cons, List.sum_cons, hi] at *
    grind [ih ht]

private theorem total_delta [DecidableEq I] (xs : List I) (hxs : xs.Nodup)
    (i : I) (hi : i ∈ xs) (a : Rat) :
    total xs (fun j => if i = j then a else 0) = a := by
  induction xs with
  | nil => simp at hi
  | cons j ys ih =>
    have hn := (List.nodup_cons.mp hxs)
    simp only [List.mem_cons] at hi
    rcases hi with heq | hmem
    · subst i
      have hnot : ∀ k ∈ ys, j ≠ k := by grind
      have hz : total ys (fun k => if j = k then a else 0) = 0 :=
        total_zero ys _ (by intro k hk; simp [hnot k hk])
      simp only [total, List.map_cons, List.sum_cons] at *
      grind
    · have hne : i ≠ j := by grind
      simp only [total, List.map_cons, List.sum_cons, if_neg hne]
      have htail := ih hn.2 hmem
      simp only [total] at htail
      grind

private theorem total_mul_right (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i * a) = total xs f * a := by
  calc
    _ = total xs (fun i => a * f i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = a * total xs f := total_mul xs _ _
    _ = _ := Rat.mul_comm _ _

private theorem rank_one (xs : List I) (u : I → Rat) :
    total xs (fun i => total xs (fun j => u i * u j)) = total xs u * total xs u := by
  calc
    _ = total xs (fun i => u i * total xs u) := by
      apply total_congr xs; intro i hi; exact total_mul xs _ _
    _ = total xs (fun i => total xs u * u i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = _ := total_mul xs _ _

private theorem total_gram (xs : List I) (cols : List K)
    (B : I → K → Rat) (x : I → Rat) :
    total xs (fun i => total xs (fun j =>
      total cols (fun k => B i k * B j k) * x i * x j)) =
    total cols (fun k =>
      (total xs (fun i => B i k * x i)) *
      (total xs (fun i => B i k * x i))) := by
  calc
    _ = total xs (fun i => total xs (fun j =>
        total cols (fun k => (B i k * x i) * (B j k * x j)))) := by
      apply total_congr xs; intro i hi
      apply total_congr xs; intro j hj
      calc
        total cols (fun k => B i k * B j k) * x i * x j =
          total cols (fun k => (B i k * B j k) * x i * x j) := by
            rw [total_mul_right, total_mul_right]
        _ = _ := by apply total_congr cols; intro k hk; grind +ring
    _ = total cols (fun k => total xs (fun i => total xs (fun j =>
        (B i k * x i) * (B j k * x j)))) := by
      calc
        _ = total xs (fun i => total cols (fun k => total xs (fun j =>
            (B i k * x i) * (B j k * x j)))) := by
          apply total_congr xs; intro i hi; exact total_comm xs cols _
        _ = _ := total_comm xs cols _
    _ = _ := by
      apply total_congr cols; intro k hk; exact rank_one xs _

def quadratic (xs : List I) (A : I → I → Rat) (x : I → Rat) : Rat :=
  total xs (fun i => total xs (fun j => A i j * x i * x j))

private theorem quadratic_add (xs : List I) (A D : I → I → Rat) (x : I → Rat) :
    quadratic xs (fun i j => A i j + D i j) x =
      quadratic xs A x + quadratic xs D x := by
  unfold quadratic
  calc
    _ = total xs (fun i => total xs (fun j => A i j * x i * x j) +
      total xs (fun j => D i j * x i * x j)) := by
        apply total_congr xs; intro i hi
        calc
          _ = total xs (fun j => A i j * x i * x j + D i j * x i * x j) := by
            apply total_congr xs; intro j hj; grind +ring
          _ = _ := total_add xs _ _
    _ = _ := total_add xs _ _

private theorem quadratic_diagonal [DecidableEq I] (xs : List I)
    (hxs : xs.Nodup) (t : Rat) (x : I → Rat) :
    quadratic xs (fun i j => if i = j then t else 0) x =
      t * total xs (fun i => x i * x i) := by
  unfold quadratic
  calc
    _ = total xs (fun i => t * (x i * x i)) := by
      apply total_congr xs; intro i hi
      calc
        _ = total xs (fun j => if i = j then t * (x i * x i) else 0) := by
          apply total_congr xs; intro j hj
          by_cases heq : i = j
          · subst j; simp; grind +ring
          · simp [heq]
        _ = _ := total_delta xs hxs i hi _
    _ = _ := total_mul xs _ _

/-- Exact rational PSD domination via an explicit Gram factor and a
    symmetric absolute-row residual. A rational verifier checks the entrywise
    identity and row sums; algebraic density interval enclosures need a separate
    bridge to this rational statement. The conclusion holds for *every* rational test
    vector; neither positivity nor symmetry of the input density is assumed. -/
theorem gram_row_certificate [DecidableEq I] (xs : List I) (cols : List K)
    (hxs : xs.Nodup) (ρ Berror envelope : I → I → Rat)
    (B : I → K → Rat) (x : I → Rat) (t δ : Rat)
    (enclosure : ∀ i ∈ xs, ∀ j ∈ xs,
      ρ i j = (if i = j then t else 0) +
        total cols (fun k => B i k * B j k) + Berror i j)
    (nonneg : ∀ i ∈ xs, ∀ j ∈ xs, 0 ≤ envelope i j)
    (symmetric : ∀ i ∈ xs, ∀ j ∈ xs, envelope i j = envelope j i)
    (lower : ∀ i ∈ xs, ∀ j ∈ xs, -envelope i j ≤ Berror i j)
    (upper : ∀ i ∈ xs, ∀ j ∈ xs, Berror i j ≤ envelope i j)
    (rows : ∀ i ∈ xs, total xs (envelope i) ≤ δ) :
    quadratic xs ρ x ≤
      (t + δ) * total xs (fun i => x i * x i) +
        total cols (fun k =>
          total xs (fun i => B i k * x i) * total xs (fun i => B i k * x i)) := by
  have hρ : quadratic xs ρ x =
      quadratic xs (fun i j => (if i = j then t else 0) +
        total cols (fun k => B i k * B j k) + Berror i j) x := by
    unfold quadratic
    apply total_congr xs; intro i hi
    apply total_congr xs; intro j hj
    rw [enclosure i hi j hj]
  rw [hρ, quadratic_add, quadratic_add, quadratic_diagonal xs hxs]
  have hg := total_gram xs cols B x
  have he := row_error_bound xs Berror envelope x δ
    nonneg symmetric lower upper rows
  unfold quadratic at *
  grind +ring

/-- Any selected finite family of shared emission laws factors through
    coordinates indexed by the laws. These are explicit coefficients for its
    at-most-`cols.length` span. In the application the laws are the *candidate*
    square-root emissions, not square roots of teacher mixtures. -/
theorem shared_emission_coordinates [DecidableEq C]
    (states : List S) (cols : List C) (hcols : cols.Nodup)
    (state : S → C) (hstate : ∀ s ∈ states, state s ∈ cols)
    (emission : C → O → Rat) (weight : S → Rat) (o : O) :
    total states (fun s => weight s * emission (state s) o) =
      total cols (fun c =>
        total states (fun s => if state s = c then weight s else 0) * emission c o) := by
  calc
    _ = total states (fun s => total cols (fun c =>
        if state s = c then weight s * emission c o else 0)) := by
      apply total_congr states; intro s hs
      have h := total_delta cols hcols (state s) (hstate s hs)
        (weight s * emission (state s) o)
      calc
        _ = total cols (fun c => if state s = c then
            weight s * emission (state s) o else 0) := h.symm
        _ = _ := by apply total_congr cols; intro c hc
                    by_cases hsc : state s = c
                    · subst c; simp
                    · simp [hsc]
    _ = total cols (fun c => total states (fun s =>
        if state s = c then weight s * emission c o else 0)) :=
      total_comm states cols _
    _ = _ := by
      apply total_congr cols; intro c hc
      calc
        _ = total states (fun s =>
          (if state s = c then weight s else 0) * emission c o) := by
            apply total_congr states; intro s hs
            by_cases hsc : state s = c
            · simp [hsc]
            · simp [hsc]
        _ = _ := total_mul_right states _ _

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  have h := total_le xs (fun _ => 0) f (by intro i hi; exact hf i hi)
  have hz : total xs (fun _ => (0 : Rat)) = 0 :=
    total_zero xs _ (by intro i hi; rfl)
  rw [hz] at h
  exact h

/-- The negative Gram factor is not charged against the row-error allowance.
    It is dropped only after proving that its quadratic form is a sum of
    nonnegative squares. Thus a large Bminus has no effect on the upper bound. -/
theorem two_gram_row_certificate [DecidableEq I]
    (xs : List I) (plusCols : List Kplus) (minusCols : List Kminus)
    (hxs : xs.Nodup) (ρ E envelope : I → I → Rat)
    (Bplus : I → Kplus → Rat) (Bminus : I → Kminus → Rat)
    (x : I → Rat) (t δ : Rat)
    (enclosure : ∀ i ∈ xs, ∀ j ∈ xs,
      ρ i j = (if i = j then t else 0) +
        total plusCols (fun k => Bplus i k * Bplus j k) -
        total minusCols (fun k => Bminus i k * Bminus j k) + E i j)
    (nonneg : ∀ i ∈ xs, ∀ j ∈ xs, 0 ≤ envelope i j)
    (symmetric : ∀ i ∈ xs, ∀ j ∈ xs, envelope i j = envelope j i)
    (lower : ∀ i ∈ xs, ∀ j ∈ xs, -envelope i j ≤ E i j)
    (upper : ∀ i ∈ xs, ∀ j ∈ xs, E i j ≤ envelope i j)
    (rows : ∀ i ∈ xs, total xs (envelope i) ≤ δ) :
    quadratic xs ρ x ≤
      (t + δ) * total xs (fun i => x i * x i) +
        total plusCols (fun k =>
          total xs (fun i => Bplus i k * x i) *
          total xs (fun i => Bplus i k * x i)) := by
  have hbound := gram_row_certificate xs plusCols hxs
    (fun i j => ρ i j + total minusCols (fun k => Bminus i k * Bminus j k))
    E envelope Bplus x t δ
    (by
      intro i hi j hj
      have h := enclosure i hi j hj
      grind)
    nonneg symmetric lower upper rows
  rw [quadratic_add] at hbound
  have hminus : quadratic xs (fun i j =>
      total minusCols (fun k => Bminus i k * Bminus j k)) x =
      total minusCols (fun k =>
        total xs (fun i => Bminus i k * x i) *
        total xs (fun i => Bminus i k * x i)) :=
    total_gram xs minusCols Bminus x
  rw [hminus] at hbound
  have hpositive : 0 ≤ total minusCols (fun k =>
      total xs (fun i => Bminus i k * x i) *
      total xs (fun i => Bminus i k * x i)) :=
    total_nonneg minusCols _ (by intro k hk; exact square_nonneg _)
  grind

end Kelana.EmissionSubspace
