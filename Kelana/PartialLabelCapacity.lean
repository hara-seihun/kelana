import Std

namespace Kelana.PartialLabelCapacity

/-- Finite rational sums deliberately preserve repeated family members: two
    identical subsets with different cover weights are separate charges. -/
def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind [ih ht]

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
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

/-- Charge only the observations in a subset, using the global source list to
    avoid multiplying a source's charge if the subset representation repeats it. -/
def subsetLoss [DecidableEq S] (sources : List S) (T : List S)
    (loss : S → Rat) : Rat :=
  total sources (fun s => if s ∈ T then loss s else 0)

def coverage [DecidableEq S] (families : List (List S))
    (weight : List S → Rat) (s : S) : Rat :=
  total families (fun T => if s ∈ T then weight T else 0)

/-- Fractional packing of arbitrary overlapping source subsets. Floors on
    subsets may be added only to the extent that the nonnegative weights
    cover each source at most once. There is no disjointness assumption on the
    subsets and no assumption of the desired total inequality. -/
theorem weighted_cover_floor [DecidableEq S]
    (sources : List S) (families : List (List S))
    (loss : S → Rat) (floor weight : List S → Rat)
    (loss_nonneg : ∀ s ∈ sources, 0 ≤ loss s)
    (weight_nonneg : ∀ T ∈ families, 0 ≤ weight T)
    (local_floor : ∀ T ∈ families, floor T ≤ subsetLoss sources T loss)
    (at_most_once : ∀ s ∈ sources, coverage families weight s ≤ 1) :
    total families (fun T => weight T * floor T) ≤ total sources loss := by
  have hlocal : total families (fun T => weight T * floor T) ≤
      total families (fun T => weight T * subsetLoss sources T loss) := by
    apply total_le families
    intro T hT
    have h := Rat.mul_nonneg (weight_nonneg T hT)
      (by grind : 0 ≤ subsetLoss sources T loss - floor T)
    grind +ring
  have hswap : total families (fun T => weight T * subsetLoss sources T loss) =
      total sources (fun s => coverage families weight s * loss s) := by
    calc
      _ = total families (fun T => total sources (fun s =>
          weight T * (if s ∈ T then loss s else 0))) := by
        apply total_congr families; intro T hT
        exact (total_mul sources (weight T) _).symm
      _ = total sources (fun s => total families (fun T =>
          weight T * (if s ∈ T then loss s else 0))) := total_comm families sources _
      _ = total sources (fun s => total families (fun T =>
          (if s ∈ T then weight T else 0) * loss s)) := by
        apply total_congr sources; intro s hs
        apply total_congr families; intro T hT
        by_cases hmem : s ∈ T
        · simp [hmem]
        · simp [hmem]
      _ = _ := by
        apply total_congr sources; intro s hs
        calc
          _ = loss s * total families (fun T => if s ∈ T then weight T else 0) := by
            calc
              _ = total families (fun T => loss s *
                  (if s ∈ T then weight T else 0)) := by
                apply total_congr families; intro T hT; exact Rat.mul_comm _ _
              _ = _ := total_mul families _ _
          _ = _ := Rat.mul_comm _ _
  have hfinal : total sources (fun s => coverage families weight s * loss s) ≤
      total sources loss := by
    apply total_le sources
    intro s hs
    have h := Rat.mul_nonneg (loss_nonneg s hs)
      (by grind : 0 ≤ 1 - coverage families weight s)
    grind +ring
  calc
    _ ≤ total families (fun T => weight T * subsetLoss sources T loss) := hlocal
    _ = total sources (fun s => coverage families weight s * loss s) := hswap
    _ ≤ _ := hfinal

private theorem nodup_map_on (T : List S) (f : S → L)
    (hT : T.Nodup)
    (inj : ∀ s ∈ T, ∀ t ∈ T, f s = f t → s = t) :
    (T.map f).Nodup := by
  induction T with
  | nil => simp
  | cons s ss ih =>
    obtain ⟨hnot, htail⟩ := List.nodup_cons.mp hT
    apply List.nodup_cons.mpr
    constructor
    · intro hmember
      obtain ⟨t, ht, heq⟩ := List.mem_map.mp hmember
      have same := inj s (by simp) t (by simp [ht]) heq.symm
      exact hnot (by simpa [same] using ht)
    · apply ih htail
      intro u hu v hv eq
      exact inj u (by simp [hu]) v (by simp [hv]) eq

/-- Restrict any exact candidate labeling to a source subset. Its distinct
    teacher laws force an injection into that subset's allowed-label union. -/
theorem deficient_subset_forces_error [DecidableEq L]
    (T : List S) (hT : T.Nodup) (allowedUnion : List L)
    (possible : S → List L) (label : S → L)
    (law : S → Y) (readout : L → Y)
    (allowed : ∀ s ∈ T, ∀ c ∈ possible s, c ∈ allowedUnion)
    (selected : ∀ s ∈ T, label s ∈ possible s)
    (distinct : ∀ s ∈ T, ∀ t ∈ T, law s = law t → s = t)
    (exact : ∀ s ∈ T, readout (label s) = law s)
    (deficient : allowedUnion.length < T.length) : False := by
  have hmap : (T.map label).Nodup := nodup_map_on T label hT (by
    intro s hs t ht same
    apply distinct s hs t ht
    rw [← exact s hs, ← exact t ht, same])
  have hsubset : ∀ c ∈ T.map label, c ∈ allowedUnion := by
    intro c hc
    obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hc
    exact allowed s hs (label s) (selected s hs)
  have hbound := hmap.length_le_of_subset hsubset
  simp only [List.length_map] at hbound
  omega

end Kelana.PartialLabelCapacity
