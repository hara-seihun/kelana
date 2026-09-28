import Std

namespace Kelana.NormalizedRatioRange

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

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i+g i) = total xs f+total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_sub (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i-g i) = total xs f-total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

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

private theorem total_zero (xs : List I) :
    total xs (fun _ => (0:Rat)) = 0 := by
  induction xs with
  | nil => rfl
  | cons i rest ih =>
    change 0+total rest (fun _ => (0:Rat)) = 0
    rw [ih]
    grind

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    change f i+total xs f ≤ g i+total xs g
    grind [ih ht]

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

/-- Chord of |x−μ| over a positive interval. Its gap is an actual product
    of nonnegative distances to an endpoint and the mean. -/
theorem absolute_chord (L U μ x : Rat)
    (hLμ : L ≤ μ) (hμU : μ ≤ U)
    (hLx : L ≤ x) (hxU : x ≤ U) :
    (x-μ).abs*(U-L) ≤
      (U-x)*(μ-L)+(x-L)*(U-μ) := by
  by_cases h : μ ≤ x
  · have hnonneg : 0 ≤ x-μ := by grind
    rw [Rat.abs_of_nonneg hnonneg]
    have hgap : 0 ≤ 2*(U-x)*(μ-L) :=
      Rat.mul_nonneg (Rat.mul_nonneg (by decide) (by grind)) (by grind)
    grind +ring
  · have hnonpos : x-μ ≤ 0 := by grind
    rw [Rat.abs_of_nonpos hnonpos]
    have hgap : 0 ≤ 2*(x-L)*(U-μ) :=
      Rat.mul_nonneg (Rat.mul_nonneg (by decide) (by grind)) (by grind)
    grind +ring

/-- Actual finite chord assembly, with μ obtained from p and r rather than
    postulated independently. -/
theorem mean_absolute_chord (xs : List I) (p r : I → Rat)
    (L U : Rat) (hp : ∀ i ∈ xs, 0 ≤ p i)
    (hsum : total xs p = 1)
    (hrange : ∀ i ∈ xs, L ≤ r i ∧ r i ≤ U) :
    let μ := total xs (fun i => p i*r i)
    L ≤ μ ∧ μ ≤ U ∧
      total xs (fun i => p i*(r i-μ).abs)*(U-L) ≤
        2*(U-μ)*(μ-L) := by
  dsimp only
  let μ := total xs (fun i => p i*r i)
  have hlow : L ≤ μ := by
    have h := total_le xs (fun i => L*p i) (fun i => p i*r i)
      (by intro i hi
          have hm := Rat.mul_le_mul_of_nonneg_left (hrange i hi).1 (hp i hi)
          simpa only [Rat.mul_comm] using hm)
    rw [total_mul, hsum] at h
    simpa only [Rat.mul_one] using h
  have hhigh : μ ≤ U := by
    have h := total_le xs (fun i => p i*r i) (fun i => U*p i)
      (by intro i hi
          have hm := Rat.mul_le_mul_of_nonneg_left (hrange i hi).2 (hp i hi)
          simpa only [Rat.mul_comm] using hm)
    rw [total_mul, hsum] at h
    simpa only [Rat.mul_one] using h
  refine ⟨hlow, hhigh, ?_⟩
  have hpoint : ∀ i ∈ xs,
      p i*((r i-μ).abs*(U-L)) ≤
        p i*((U-r i)*(μ-L)+(r i-L)*(U-μ)) := by
    intro i hi
    exact Rat.mul_le_mul_of_nonneg_left
      (absolute_chord L U μ (r i) hlow hhigh (hrange i hi).1 (hrange i hi).2)
      (hp i hi)
  have hsumineq := total_le xs
    (fun i => p i*((r i-μ).abs*(U-L)))
    (fun i => p i*((U-r i)*(μ-L)+(r i-L)*(U-μ))) hpoint
  have hleft : total xs (fun i => p i*((r i-μ).abs*(U-L))) =
      total xs (fun i => p i*(r i-μ).abs)*(U-L) := by
    calc
      _ = total xs (fun i => (U-L)*(p i*(r i-μ).abs)) := by
        apply total_congr xs; intro i hi; grind +ring
      _ = (U-L)*total xs (fun i => p i*(r i-μ).abs) := total_mul _ _ _
      _ = _ := Rat.mul_comm _ _
  have hright : total xs (fun i =>
      p i*((U-r i)*(μ-L)+(r i-L)*(U-μ))) =
      2*(U-μ)*(μ-L) := by
    calc
      _ = (μ-L)*total xs (fun i => p i*(U-r i)) +
          (U-μ)*total xs (fun i => p i*(r i-L)) := by
        calc
          _ = total xs (fun i =>
              (μ-L)*(p i*(U-r i))+(U-μ)*(p i*(r i-L))) := by
            apply total_congr xs; intro i hi; grind +ring
          _ = _ := by rw [total_add, total_mul, total_mul]
      _ = (μ-L)*(U-μ)+(U-μ)*(μ-L) := by
        have hfirst : total xs (fun i => p i*(U-r i)) = U-μ := by
          calc
            _ = total xs (fun i => U*p i-p i*r i) := by
              apply total_congr xs; intro i hi; grind +ring
            _ = U*total xs p - total xs (fun i => p i*r i) := by
              rw [total_sub, total_mul]
            _ = _ := by rw [hsum]; grind +ring
        have hsecond : total xs (fun i => p i*(r i-L)) = μ-L := by
          calc
            _ = total xs (fun i => p i*r i-L*p i) := by
              apply total_congr xs; intro i hi; grind +ring
            _ = total xs (fun i => p i*r i)-L*total xs p := by
              rw [total_sub, total_mul]
            _ = _ := by rw [hsum]; grind +ring
        rw [hfirst, hsecond]
      _ = _ := by grind +ring
  rw [hleft, hright] at hsumineq
  exact hsumineq

/-- Normalize the positive kernel ratios against their teacher mean. -/
def candidateWeight (xs : List I) (p r : I → Rat) (i : I) : Rat :=
  (p i*r i)/total xs (fun j => p j*r j)

private theorem absolute_normalized_diff (p r μ : Rat)
    (hp : 0 ≤ p) (hμ : 0 < μ) :
    ((p*r)/μ-p).abs*μ = p*(r-μ).abs := by
  have hd := Rat.div_mul_cancel (Rat.ne_of_gt hμ) (a := p*r)
  have hcross : ((p*r)/μ-p)*μ = p*(r-μ) := by grind +ring
  by_cases hr : μ ≤ r
  · have hplus : 0 ≤ r-μ := by grind
    have hpplus : 0 ≤ p*(r-μ) := Rat.mul_nonneg hp hplus
    have hx : 0 ≤ (p*r)/μ-p := by
      apply Rat.le_of_mul_le_mul_right (c := μ) ?_ hμ
      rw [Rat.zero_mul, hcross]
      exact hpplus
    rw [Rat.abs_of_nonneg hx, Rat.abs_of_nonneg hplus]
    exact hcross
  · have hminus : r-μ ≤ 0 := by grind
    have hpminus : p*(r-μ) ≤ 0 := by
      have h := Rat.mul_le_mul_of_nonneg_left hminus hp
      simpa only [Rat.mul_zero] using h
    have hx : (p*r)/μ-p ≤ 0 := by
      apply Rat.le_of_mul_le_mul_right (c := μ) ?_ hμ
      rw [Rat.zero_mul, hcross]
      exact hpminus
    rw [Rat.abs_of_nonpos hx, Rat.abs_of_nonpos hminus]
    grind +ring

/-- The factorization of the sharp gap, with a genuine nonnegative square;
    at μ=u*l the bound is attained by the endpoint law. -/
theorem ratio_square_gap (l u μ : Rat)
    (hl : 0 < l) (hlu : l < u) (hμ : 0 < μ) :
    ((u*u-μ)*(μ-l*l))/(μ*(u*u-l*l)) ≤ (u-l)/(u+l) := by
  have hdiff : 0 < u-l := by grind
  have hsum : 0 < u+l := by grind
  have hUL : 0 < u*u-l*l := by
    have hm := Rat.mul_pos hdiff hsum
    have heq : (u-l)*(u+l)=u*u-l*l := by grind +ring
    rw [heq] at hm
    exact hm
  have hden : 0 < μ*(u*u-l*l) := Rat.mul_pos hμ hUL
  have hbig : 0 < (μ*(u*u-l*l))*(u+l) := Rat.mul_pos hden hsum
  have hleft := Rat.div_mul_cancel (Rat.ne_of_gt hden)
    (a := (u*u-μ)*(μ-l*l))
  have hright := Rat.div_mul_cancel (Rat.ne_of_gt hsum) (a := u-l)
  have hsquare := square_nonneg (μ-u*l)
  have hpositive := Rat.mul_nonneg (Rat.le_of_lt hsum) hsquare
  have hpoly : 0 ≤ (u-l)*μ*(u*u-l*l)-
      ((u*u-μ)*(μ-l*l))*(u+l) := by
    have heq : (u-l)*μ*(u*u-l*l)-
        ((u*u-μ)*(μ-l*l))*(u+l) =
        (u+l)*((μ-u*l)*(μ-u*l)) := by grind +ring
    rw [heq]
    exact hpositive
  apply Rat.le_of_mul_le_mul_right (c := (μ*(u*u-l*l))*(u+l)) ?_ hbig
  have hqleft :
      (((u*u-μ)*(μ-l*l))/(μ*(u*u-l*l)))*((μ*(u*u-l*l))*(u+l)) =
        ((u*u-μ)*(μ-l*l))*(u+l) := by
    calc
      _ = ((((u*u-μ)*(μ-l*l))/(μ*(u*u-l*l)))*(μ*(u*u-l*l)))*(u+l) := by
        grind +ring
      _ = _ := by rw [hleft]
  have hqright : ((u-l)/(u+l))*((μ*(u*u-l*l))*(u+l)) =
      (u-l)*μ*(u*u-l*l) := by
    calc
      _ = (((u-l)/(u+l))*(u+l))*(μ*(u*u-l*l)) := by grind +ring
      _ = _ := by rw [hright]; grind +ring
  rw [hqleft, hqright]
  grind +ring

/-- Sharp positive-ratio TV bound over an arbitrary finite teacher law.
    No exp/log or probabilistic independence is assumed. -/
theorem normalized_ratio_tv (xs : List I) (p r : I → Rat)
    (l u : Rat) (hl : 0 < l) (hlu : l < u)
    (hp : ∀ i ∈ xs, 0 < p i) (hsum : total xs p = 1)
    (hr : ∀ i ∈ xs, l*l ≤ r i ∧ r i ≤ u*u) :
    total xs (fun i => (candidateWeight xs p r i-p i).abs)/2 ≤
      (u-l)/(u+l) := by
  let μ := total xs (fun i => p i*r i)
  have hchord := mean_absolute_chord xs p r (l*l) (u*u)
    (by intro i hi; exact Rat.le_of_lt (hp i hi)) hsum hr
  dsimp only at hchord
  obtain ⟨hμlower, hμupper, hmean⟩ := hchord
  have hμ : 0 < μ := by
    have hsq := Rat.mul_pos hl hl
    grind
  have hdiff : 0 < u-l := by grind
  have hsum : 0 < u+l := by grind
  have hUL : 0 < u*u-l*l := by
    have hm := Rat.mul_pos hdiff hsum
    have heq : (u-l)*(u+l)=u*u-l*l := by grind +ring
    rw [heq] at hm
    exact hm
  have hden : 0 < μ*(u*u-l*l) := Rat.mul_pos hμ hUL
  have heq : total xs (fun i =>
      (candidateWeight xs p r i-p i).abs)*μ =
      total xs (fun i => p i*(r i-μ).abs) := by
    calc
      _ = total xs (fun i =>
          (candidateWeight xs p r i-p i).abs*μ) :=
        (total_mul_right xs (fun i => (candidateWeight xs p r i-p i).abs) μ).symm
      _ = _ := by
        apply total_congr xs
        intro i hi
        unfold candidateWeight
        exact absolute_normalized_diff (p i) (r i) μ
          (Rat.le_of_lt (hp i hi)) hμ
  have hfirst : total xs (fun i =>
      (candidateWeight xs p r i-p i).abs)/2 ≤
      ((u*u-μ)*(μ-l*l))/(μ*(u*u-l*l)) := by
    have houter : 0 < (2:Rat)*μ*(u*u-l*l) :=
      Rat.mul_pos (Rat.mul_pos (by decide) hμ) hUL
    have hc := Rat.div_mul_cancel (by decide : (2:Rat) ≠ 0)
      (a := total xs (fun i => (candidateWeight xs p r i-p i).abs))
    have hr := Rat.div_mul_cancel (Rat.ne_of_gt hden)
      (a := (u*u-μ)*(μ-l*l))
    apply Rat.le_of_mul_le_mul_right (c := (2:Rat)*μ*(u*u-l*l)) ?_ houter
    have hleft :
        (total xs (fun i => (candidateWeight xs p r i-p i).abs)/2)*
          ((2:Rat)*μ*(u*u-l*l)) =
          total xs (fun i => p i*(r i-μ).abs)*(u*u-l*l) := by
      calc
        _ = ((total xs (fun i => (candidateWeight xs p r i-p i).abs)/2)*2)*
            (μ*(u*u-l*l)) := by grind +ring
        _ = total xs (fun i => (candidateWeight xs p r i-p i).abs)*
            (μ*(u*u-l*l)) := by rw [hc]
        _ = _ := by rw [← Rat.mul_assoc, heq]
    have hright :
        (((u*u-μ)*(μ-l*l))/(μ*(u*u-l*l)))*((2:Rat)*μ*(u*u-l*l)) =
          2*((u*u-μ)*(μ-l*l)) := by
      calc
        _ = ((((u*u-μ)*(μ-l*l))/(μ*(u*u-l*l)))*(μ*(u*u-l*l)))*2 := by
          grind +ring
        _ = _ := by rw [hr]; grind +ring
    rw [hleft, hright]
    dsimp [μ]
    have := hmean
    grind +ring
  exact Rat.le_trans hfirst (ratio_square_gap l u μ hl hlu hμ)

/-- A common ratio is completely removed by normalization. -/
theorem constant_ratio_tv_zero (xs : List I) (p : I → Rat)
    (r : Rat) (hr : 0 < r) (hsum : total xs p = 1) :
    total xs (fun i => (candidateWeight xs p (fun _ => r) i-p i).abs)/2 = 0 := by
  have hmean : total xs (fun i => p i*r) = r := by
    calc
      _ = total xs (fun i => r*p i) := by
        apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
      _ = r*total xs p := total_mul _ _ _
      _ = r := by rw [hsum]; grind
  have hpoint : ∀ i ∈ xs, candidateWeight xs p (fun _ => r) i = p i := by
    intro i hi
    unfold candidateWeight
    rw [hmean]
    exact Rat.mul_div_cancel (Rat.ne_of_gt hr)
  calc
    _ = total xs (fun _ => (0:Rat))/2 := by
      congr 1
      apply total_congr xs; intro i hi
      rw [hpoint i hi]
      grind
    _ = 0 := by
      rw [total_zero]
      grind

/-- Two endpoint ratios attain the bound: the lower ratio carries
    probability u/(u+l), so the normalizing mean is exactly u*l. -/
theorem endpoint_tv_attains (l u : Rat) (hl : 0 < l) (hlu : l < u) :
    let xs : List Bool := [false, true]
    let p : Bool → Rat := fun i => if i then l/(u+l) else u/(u+l)
    let r : Bool → Rat := fun i => if i then u*u else l*l
    total xs (fun i => (candidateWeight xs p r i-p i).abs)/2 =
      (u-l)/(u+l) := by
  dsimp only
  let p : Bool → Rat := fun i => if i then l/(u+l) else u/(u+l)
  let r : Bool → Rat := fun i => if i then u*u else l*l
  have hu : 0 < u := by grind
  have hden : 0 < u+l := by grind
  have hμ : 0 < u*l := Rat.mul_pos hu hl
  have hdu := Rat.div_mul_cancel (Rat.ne_of_gt hden) (a := u)
  have hdl := Rat.div_mul_cancel (Rat.ne_of_gt hden) (a := l)
  have hmean : total [false,true] (fun i => p i*r i) = u*l := by
    simp only [total, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
      Rat.add_zero]
    change (u/(u+l))*(l*l)+(l/(u+l))*(u*u) = u*l
    have hcross :
        ((u/(u+l))*(l*l)+(l/(u+l))*(u*u))*(u+l) =
          (u*l)*(u+l) := by
      calc
        _ = ((u/(u+l))*(u+l))*(l*l)+
            ((l/(u+l))*(u+l))*(u*u) := by grind +ring
        _ = u*(l*l)+l*(u*u) := by rw [hdu, hdl]
        _ = _ := by grind +ring
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := u+l) ?_ hden
      rw [hcross]
      exact Rat.le_refl
    · apply Rat.le_of_mul_le_mul_right (c := u+l) ?_ hden
      rw [hcross]
      exact Rat.le_refl
  have hlow : candidateWeight [false,true] p r false = l/(u+l) := by
    unfold candidateWeight
    rw [hmean]
    change ((u/(u+l))*(l*l))/(u*l) = l/(u+l)
    have hleft := Rat.div_mul_cancel (Rat.ne_of_gt hμ)
      (a := (u/(u+l))*(l*l))
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := u*l) ?_ hμ
      grind +ring
    · apply Rat.le_of_mul_le_mul_right (c := u*l) ?_ hμ
      grind +ring
  have hhigh : candidateWeight [false,true] p r true = u/(u+l) := by
    unfold candidateWeight
    rw [hmean]
    change ((l/(u+l))*(u*u))/(u*l) = u/(u+l)
    have hleft := Rat.div_mul_cancel (Rat.ne_of_gt hμ)
      (a := (l/(u+l))*(u*u))
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := u*l) ?_ hμ
      grind +ring
    · apply Rat.le_of_mul_le_mul_right (c := u*l) ?_ hμ
      grind +ring
  have hneg : l/(u+l)-u/(u+l) ≤ 0 := by
    have hx := Rat.div_mul_cancel (Rat.ne_of_gt hden) (a := l)
    have hy := Rat.div_mul_cancel (Rat.ne_of_gt hden) (a := u)
    apply Rat.le_of_mul_le_mul_right (c := u+l) ?_ hden
    grind +ring
  have hpos : 0 ≤ u/(u+l)-l/(u+l) := by grind
  simp only [total, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    Rat.add_zero]
  change ((candidateWeight [false,true] p r false-p false).abs +
      (candidateWeight [false,true] p r true-p true).abs)/2 =
        (u-l)/(u+l)
  rw [hlow, hhigh]
  change ((l/(u+l)-u/(u+l)).abs+
      (u/(u+l)-l/(u+l)).abs)/2 = (u-l)/(u+l)
  rw [Rat.abs_of_nonpos hneg, Rat.abs_of_nonneg hpos]
  have hdiff : u/(u+l)-l/(u+l) = (u-l)/(u+l) := by
    have hd := Rat.div_mul_cancel (Rat.ne_of_gt hden) (a := u-l)
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := u+l) ?_ hden
      grind +ring
    · apply Rat.le_of_mul_le_mul_right (c := u+l) ?_ hden
      grind +ring
  rw [hdiff]
  have h2 := Rat.div_mul_cancel (by decide : (2:Rat) ≠ 0)
    (a := (u-l)/(u+l)+(u-l)/(u+l))
  grind +ring

end Kelana.NormalizedRatioRange
