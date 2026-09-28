import Std

namespace Kelana.RatioBoxSupport

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

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    change f i+total xs f ≤ g i+total xs g
    grind [ih ht]

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    change 0 ≤ f i+total xs f
    grind [ih ht]

private theorem total_pos (xs : List I) (f : I → Rat)
    (hne : xs ≠ []) (hf : ∀ i ∈ xs, 0 < f i) :
    0 < total xs f := by
  cases xs with
  | nil => contradiction
  | cons i rest =>
    have hi := hf i (by simp)
    have hrest := total_nonneg rest f (by
      intro j hj
      exact Rat.le_of_lt (hf j (by simp [hj])))
    change 0 < f i+total rest f
    grind

def Legal (xs : List I) (lo hi r : I → Rat) : Prop :=
  ∀ i ∈ xs, lo i ≤ r i ∧ r i ≤ hi i

def endpoint (lo hi v : I → Rat) (t : Rat) (i : I) : Rat :=
  if t ≤ v i then hi i else lo i

def support (xs : List I) (p lo hi v : I → Rat) (t : Rat) : Rat :=
  total xs (fun i => p i*endpoint lo hi v t i*(v i-t))

def denominator (xs : List I) (p r : I → Rat) : Rat :=
  total xs (fun i => p i*r i)

def numerator (xs : List I) (p r v : I → Rat) : Rat :=
  total xs (fun i => p i*r i*v i)

def output (xs : List I) (p r v : I → Rat) : Rat :=
  numerator xs p r v / denominator xs p r

/-- Every endpoint selected by the value sign is inside its coordinate box. -/
theorem endpoint_legal (xs : List I) (lo hi v : I → Rat) (t : Rat)
    (hbox : ∀ i ∈ xs, lo i ≤ hi i) :
    Legal xs lo hi (endpoint lo hi v t) := by
  intro i hi'
  unfold endpoint
  split
  · exact ⟨hbox i hi', Rat.le_refl⟩
  · exact ⟨Rat.le_refl, hbox i hi'⟩

private theorem endpoint_pointwise (p lo hi r v t : Rat)
    (hp : 0 ≤ p) (hrange : lo ≤ r ∧ r ≤ hi) :
    p*r*(v-t) ≤ p*(if t ≤ v then hi else lo)*(v-t) := by
  by_cases h : t ≤ v
  · rw [if_pos h]
    have hprod := Rat.mul_nonneg
      (Rat.mul_nonneg hp (by grind : 0 ≤ hi-r))
      (by grind : 0 ≤ v-t)
    grind +ring
  · rw [if_neg h]
    have hprod := Rat.mul_nonneg
      (Rat.mul_nonneg hp (by grind : 0 ≤ r-lo))
      (by grind : 0 ≤ t-v)
    grind +ring

/-- A finite sign split gives the exact maximum of the unnormalized
    value-aware objective, with no assumed optimization lemma. -/
theorem support_dominates (xs : List I) (p lo hi r v : I → Rat) (t : Rat)
    (hp : ∀ i ∈ xs, 0 < p i)
    (hlegal : Legal xs lo hi r) :
    total xs (fun i => p i*r i*(v i-t)) ≤
      support xs p lo hi v t := by
  unfold support
  apply total_le xs (fun i => p i*r i*(v i-t))
    (fun i => p i*endpoint lo hi v t i*(v i-t))
  intro i hi'
  exact endpoint_pointwise (p i) (lo i) (hi i) (r i) (v i) t
    (Rat.le_of_lt (hp i hi')) (hlegal i hi')

theorem endpoint_attains_support (xs : List I)
    (p lo hi v : I → Rat) (t : Rat) :
    total xs (fun i => p i*(endpoint lo hi v t i)*(v i-t)) =
      support xs p lo hi v t := rfl

/-- Positive p and positive lower ratio bounds force every legal
    normalizer to be strictly positive; zero-length support is excluded. -/
theorem denominator_pos (xs : List I) (p lo hi r : I → Rat)
    (hne : xs ≠ []) (hp : ∀ i ∈ xs, 0 < p i)
    (hlo : ∀ i ∈ xs, 0 < lo i) (hrange : Legal xs lo hi r) :
    0 < denominator xs p r := by
  unfold denominator
  apply total_pos xs (fun i => p i*r i) hne
  intro i hi'
  have hir : 0 < r i := by
    have h := (hrange i hi').1
    grind
  exact Rat.mul_pos (hp i hi') hir

/-- Numerator offset from t times the normalizer is the actual support
    objective. This is the bridge to a normalized ratio statement. -/
theorem numerator_offset (xs : List I) (p r v : I → Rat) (t : Rat) :
    numerator xs p r v-t*denominator xs p r =
      total xs (fun i => p i*r i*(v i-t)) := by
  unfold numerator denominator
  calc
    _ = total xs (fun i => p i*r i*v i - t*(p i*r i)) := by
      rw [total_sub, total_mul]
    _ = _ := by
      apply total_congr xs
      intro i hi
      grind +ring

private theorem output_le_iff (xs : List I) (p r v : I → Rat)
    (t : Rat) (hden : 0 < denominator xs p r) :
    output xs p r v ≤ t ↔
      total xs (fun i => p i*r i*(v i-t)) ≤ 0 := by
  have hc := Rat.div_mul_cancel (Rat.ne_of_gt hden)
    (a := numerator xs p r v)
  have hoff := numerator_offset xs p r v t
  constructor
  · intro h
    have hm := Rat.mul_le_mul_of_nonneg_right h (Rat.le_of_lt hden)
    unfold output at hm
    rw [hc] at hm
    grind +ring
  · intro h
    unfold output
    apply Rat.le_of_mul_le_mul_right (c := denominator xs p r) ?_ hden
    rw [hc]
    grind +ring

/-- Exact support certificate: F(t)≤0 if and only if **all** legal ratio
    fields have normalized scalar output at most t. No sorting, exp/log, or
    attention-preservation assumption appears. -/
theorem support_nonpos_iff_universal_bound
    (xs : List I) (p lo hi v : I → Rat) (t : Rat)
    (hne : xs ≠ []) (hp : ∀ i ∈ xs, 0 < p i)
    (hlo : ∀ i ∈ xs, 0 < lo i)
    (hbox : ∀ i ∈ xs, lo i ≤ hi i) :
    support xs p lo hi v t ≤ 0 ↔
      ∀ r, Legal xs lo hi r → output xs p r v ≤ t := by
  constructor
  · intro hs r hr
    have hd := denominator_pos xs p lo hi r hne hp hlo hr
    apply (output_le_iff xs p r v t hd).mpr
    exact Rat.le_trans (support_dominates xs p lo hi r v t hp hr) hs
  · intro hb
    have he := endpoint_legal xs lo hi v t hbox
    have hd := denominator_pos xs p lo hi (endpoint lo hi v t) hne hp hlo he
    have hh := (output_le_iff xs p (endpoint lo hi v t) v t hd).mp
      (hb (endpoint lo hi v t) he)
    simpa only [endpoint_attains_support] using hh

/-- At an exact support zero the selected endpoint ratio field attains t
    and globally maximizes the normalized output on the ratio box. -/
theorem zero_support_endpoint_global_max
    (xs : List I) (p lo hi v : I → Rat) (t : Rat)
    (hne : xs ≠ []) (hp : ∀ i ∈ xs, 0 < p i)
    (hlo : ∀ i ∈ xs, 0 < lo i)
    (hbox : ∀ i ∈ xs, lo i ≤ hi i)
    (hz : support xs p lo hi v t = 0) :
    output xs p (endpoint lo hi v t) v = t ∧
      ∀ r, Legal xs lo hi r → output xs p r v ≤
        output xs p (endpoint lo hi v t) v := by
  have he := endpoint_legal xs lo hi v t hbox
  have hd := denominator_pos xs p lo hi (endpoint lo hi v t) hne hp hlo he
  have hzero : numerator xs p (endpoint lo hi v t) v-
      t*denominator xs p (endpoint lo hi v t) = 0 := by
    rw [numerator_offset]
    exact hz
  have hc := Rat.div_mul_cancel (Rat.ne_of_gt hd)
    (a := numerator xs p (endpoint lo hi v t) v)
  have houtput : output xs p (endpoint lo hi v t) v = t := by
    unfold output
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := denominator xs p (endpoint lo hi v t)) ?_ hd
      rw [hc]
      grind
    · apply Rat.le_of_mul_le_mul_right (c := denominator xs p (endpoint lo hi v t)) ?_ hd
      rw [hc]
      grind
  refine ⟨houtput, ?_⟩
  intro r hr
  rw [houtput]
  exact (support_nonpos_iff_universal_bound xs p lo hi v t hne hp hlo hbox).mp
    (by rw [hz]; exact Rat.le_refl) r hr

/-- Negating the observed values negates the actual normalized output;
    it leaves the candidate ratio field and denominator unchanged. -/
theorem output_neg_values (xs : List I) (p r v : I → Rat) :
    output xs p r (fun i => -v i) = -(output xs p r v) := by
  have hn : numerator xs p r (fun i => -v i) =
      -(numerator xs p r v) := by
    unfold numerator
    calc
      _ = total xs (fun i => -(p i*r i*v i)) := by
        apply total_congr xs
        intro i hi
        grind +ring
      _ = -(total xs (fun i => p i*r i*v i)) := by
        have h := total_mul xs (-1:Rat) (fun i => p i*r i*v i)
        grind +ring
  unfold output
  rw [hn]
  grind +ring

/-- The lower-support certificate is the same exact sign-split theorem
    applied to negated values; it gives a symmetric universal minimum. -/
theorem minimum_support_nonpos_iff_universal_lower_bound
    (xs : List I) (p lo hi v : I → Rat) (t : Rat)
    (hne : xs ≠ []) (hp : ∀ i ∈ xs, 0 < p i)
    (hlo : ∀ i ∈ xs, 0 < lo i)
    (hbox : ∀ i ∈ xs, lo i ≤ hi i) :
    support xs p lo hi (fun i => -v i) (-t) ≤ 0 ↔
      ∀ r, Legal xs lo hi r → t ≤ output xs p r v := by
  have h := support_nonpos_iff_universal_bound xs p lo hi
    (fun i => -v i) (-t) hne hp hlo hbox
  constructor
  · intro hs r hr
    have hm := h.mp hs r hr
    rw [output_neg_values] at hm
    grind
  · intro hb
    apply h.mpr
    intro r hr
    have hm := hb r hr
    rw [output_neg_values]
    grind

/-- Exact zero lower support gives an endpoint attaining the global minimum. -/
theorem zero_minimum_support_endpoint
    (xs : List I) (p lo hi v : I → Rat) (t : Rat)
    (hne : xs ≠ []) (hp : ∀ i ∈ xs, 0 < p i)
    (hlo : ∀ i ∈ xs, 0 < lo i)
    (hbox : ∀ i ∈ xs, lo i ≤ hi i)
    (hz : support xs p lo hi (fun i => -v i) (-t) = 0) :
    output xs p (endpoint lo hi (fun i => -v i) (-t)) v = t ∧
      ∀ r, Legal xs lo hi r →
        output xs p (endpoint lo hi (fun i => -v i) (-t)) v ≤
          output xs p r v := by
  have h := zero_support_endpoint_global_max xs p lo hi
    (fun i => -v i) (-t) hne hp hlo hbox hz
  rw [output_neg_values] at h
  refine ⟨?_, ?_⟩
  · grind
  · intro r hr
    have hm := h.2 r hr
    rw [output_neg_values] at hm
    grind

end Kelana.RatioBoxSupport
