import Std

/-! Exact rational identities for finite record-address partitions. Neither
byte-identical record decoding nor native floating-point reduction semantics
follow from these identities; those are obligations of an external codec. -/

namespace Kelana.ValueRecordQuotient

/-- A finite fiber sum. The key and record enumerations below need no ordering relation. -/
def fiber (keys : List I) (sigma : I → G) [DecidableEq G]
    (f : I → Rat) (g : G) : Rat :=
  (keys.map fun i => if sigma i = g then f i else 0).sum

private theorem sum_map_add (keys : List I) (f h : I → Rat) :
    (keys.map fun i => f i + h i).sum =
      (keys.map f).sum + (keys.map h).sum := by
  induction keys with
  | nil =>
    simp only [List.map_nil, List.sum_nil]
    grind +ring
  | cons i rest ih =>
    simp only [List.map_cons, List.sum_cons, ih]
    grind +ring

private theorem sum_map_mul (keys : List I) (f : I → Rat) (a : Rat) :
    (keys.map fun i => f i * a).sum = (keys.map f).sum * a := by
  induction keys with
  | nil => simp
  | cons i rest ih =>
    simp only [List.map_cons, List.sum_cons, ih]
    rw [Rat.add_mul]

private theorem sum_if_eq [DecidableEq G] (gs : List G) (x : G) (a : Rat)
    (unique : gs.Nodup) :
    (gs.map fun g => if x = g then a else 0).sum = if x ∈ gs then a else 0 := by
  induction gs with
  | nil => simp
  | cons g rest ih =>
    obtain ⟨notMem, uniqueRest⟩ := List.nodup_cons.mp unique
    by_cases hx : x = g
    · subst x
      have noRest : g ∉ rest := notMem
      simp only [List.map_cons, List.sum_cons, ih uniqueRest,
        if_neg noRest, List.mem_cons, true_or]
      grind +ring
    · simp only [List.map_cons, List.sum_cons, ih uniqueRest,
        List.mem_cons, eq_comm, if_neg hx]
      grind +ring

/-- Exchange the two finite sums by induction, without postulating a
    regrouping identity or using probability normalization. -/
private theorem exchange (keys : List I) (gs : List G) (f : I → G → Rat) :
    (gs.map fun g => (keys.map fun i => f i g).sum).sum =
      (keys.map fun i => (gs.map fun g => f i g).sum).sum := by
  induction keys with
  | nil =>
    simp only [List.map_nil, List.sum_nil]
    induction gs with
    | nil => rfl
    | cons g rest ih =>
      simp only [List.map_cons, List.sum_cons]
      rw [ih]
      grind +ring
  | cons i rest ih =>
    simp only [List.map_cons, List.sum_cons]
    calc
      (gs.map fun g => f i g + (rest.map fun j => f j g).sum).sum =
          (gs.map fun g => f i g).sum +
            (gs.map fun g => (rest.map fun j => f j g).sum).sum :=
              sum_map_add gs _ _
      _ = (gs.map fun g => f i g).sum +
          (rest.map fun j => (gs.map fun g => f j g).sum).sum := by rw [ih]

/-- The records list may contain unused addresses; its only obligations are
    uniqueness and coverage of the keys' addresses. In particular there is no
    division by a possibly zero fiber mass. -/
theorem regroup (keys : List I) (gs : List G) [DecidableEq G]
    (sigma : I → G) (p : I → Rat) (w : G → Rat)
    (unique : gs.Nodup) (covered : ∀ i ∈ keys, sigma i ∈ gs) :
    (keys.map fun i => p i * w (sigma i)).sum =
      (gs.map fun g => fiber keys sigma p g * w g).sum := by
  have fiberMul (g : G) : fiber keys sigma p g * w g =
      (keys.map fun i => if sigma i = g then p i * w g else 0).sum := by
    rw [fiber, ← sum_map_mul]
    apply congrArg List.sum
    apply List.map_congr_left
    intro i _
    split <;> simp
  simp only [fiberMul]
  rw [exchange]
  apply congrArg List.sum
  apply List.map_congr_left
  intro i hi
  have hsingle := sum_if_eq gs (sigma i) (p i * w (sigma i)) unique
  have hrewrite :
      (gs.map fun g => if sigma i = g then p i * w g else 0).sum =
        (gs.map fun g => if sigma i = g then p i * w (sigma i) else 0).sum := by
    apply congrArg List.sum
    apply List.map_congr_left
    intro g _
    by_cases h : sigma i = g
    · subst g; simp
    · simp [h]
  rw [hrewrite, hsingle, if_pos (covered i hi)]

/-- Equal address masses are a sufficient statistic for every exact rational
    coordinate readout sharing that address map. -/
theorem equal_masses_same_output
    (keys : List I) (gs : List G) [DecidableEq G]
    (sigma sigma' : I → G) (p p' : I → Rat)
    (unique : gs.Nodup)
    (covered : ∀ i ∈ keys, sigma i ∈ gs)
    (covered' : ∀ i ∈ keys, sigma' i ∈ gs)
    (equalMass : ∀ g ∈ gs, fiber keys sigma p g = fiber keys sigma' p' g)
    (w : O → G → Rat) (o : O) :
    (keys.map fun i => p i * w o (sigma i)).sum =
      (keys.map fun i => p' i * w o (sigma' i)).sum := by
  rw [regroup keys gs sigma p (w o) unique covered,
    regroup keys gs sigma' p' (w o) unique covered']
  apply congrArg List.sum
  apply List.map_congr_left
  intro g hg
  rw [equalMass g hg]

/-- A sum across any finite set of heads/output coordinates inherits the
    coordinatewise equality, without constraining how the readout is chosen. -/
theorem equal_masses_same_head_sum
    (keys : List I) (gs : List G) [DecidableEq G]
    (sigma sigma' : I → G) (p p' : I → Rat)
    (unique : gs.Nodup)
    (covered : ∀ i ∈ keys, sigma i ∈ gs)
    (covered' : ∀ i ∈ keys, sigma' i ∈ gs)
    (equalMass : ∀ g ∈ gs, fiber keys sigma p g = fiber keys sigma' p' g)
    (heads : List O) (w : O → G → Rat) :
    (heads.map fun o => (keys.map fun i => p i * w o (sigma i)).sum).sum =
      (heads.map fun o => (keys.map fun i => p' i * w o (sigma' i)).sum).sum := by
  apply congrArg List.sum
  apply List.map_congr_left
  intro o _
  exact equal_masses_same_output keys gs sigma sigma' p p' unique
    covered covered' equalMass w o

/-- Shared records need separate masses for every query head. This identity
    sums heads only after applying each head's own attention weights. -/
theorem grouped_head_output
    (keys : List I) (gs : List G) (heads : List H) [DecidableEq G]
    (sigma : I → G) (p : H → I → Rat) (w : H → G → Rat)
    (unique : gs.Nodup) (covered : ∀ i ∈ keys, sigma i ∈ gs) :
    (heads.map fun h => (keys.map fun i => p h i * w h (sigma i)).sum).sum =
      (heads.map fun h =>
        (gs.map fun g => fiber keys sigma (p h) g * w h g).sum).sum := by
  apply congrArg List.sum
  apply List.map_congr_left
  intro h _
  exact regroup keys gs sigma (p h) (w h) unique covered

/-- Base mass `P_g`, defined even for an unused address. -/
def baseMass (keys : List I) (sigma : I → G) [DecidableEq G]
    (p : I → Rat) (g : G) : Rat := fiber keys sigma p g

/-- Weighted ratio mass `U_g`, defined directly rather than through a fiber
    mean (which could be undefined for an empty or zero-mass fiber). -/
def ratioNumerator (keys : List I) (sigma : I → G) [DecidableEq G]
    (p r : I → Rat) (g : G) : Rat :=
  fiber keys sigma (fun i => p i * r i) g

theorem base_denominator (keys : List I) (gs : List G) [DecidableEq G]
    (sigma : I → G) (p : I → Rat)
    (unique : gs.Nodup) (covered : ∀ i ∈ keys, sigma i ∈ gs) :
    (keys.map p).sum = (gs.map fun g => baseMass keys sigma p g).sum := by
  simpa [baseMass] using
    regroup keys gs sigma p (fun _ => 1) unique covered

theorem ratio_denominator (keys : List I) (gs : List G) [DecidableEq G]
    (sigma : I → G) (p r : I → Rat)
    (unique : gs.Nodup) (covered : ∀ i ∈ keys, sigma i ∈ gs) :
    (keys.map fun i => p i * r i).sum =
      (gs.map fun g => ratioNumerator keys sigma p r g).sum := by
  simpa [ratioNumerator] using
    regroup keys gs sigma (fun i => p i * r i) (fun _ => 1) unique covered

theorem normalized_regroup (keys : List I) (gs : List G) [DecidableEq G]
    (sigma : I → G) (p r : I → Rat) (w : G → Rat)
    (unique : gs.Nodup) (covered : ∀ i ∈ keys, sigma i ∈ gs) :
    (keys.map fun i => p i * r i * w (sigma i)).sum /
        (keys.map fun i => p i * r i).sum =
      (gs.map fun g => ratioNumerator keys sigma p r g * w g).sum /
        (gs.map fun g => ratioNumerator keys sigma p r g).sum := by
  rw [ratio_denominator keys gs sigma p r unique covered]
  rw [show (keys.map fun i => p i * r i * w (sigma i)).sum =
      (gs.map fun g => ratioNumerator keys sigma p r g * w g).sum from
    regroup keys gs sigma (fun i => p i * r i) w unique covered]

/-- Equality of the weighted fiber masses `U_g` gives equality of all
    rational normalized readouts (including zero total mass, where `Rat`
    division retains its ordinary totalized meaning). -/
theorem equal_ratio_masses_same_output
    (keys : List I) (gs : List G) [DecidableEq G]
    (sigma sigma' : I → G) (p p' r r' : I → Rat)
    (unique : gs.Nodup)
    (covered : ∀ i ∈ keys, sigma i ∈ gs)
    (covered' : ∀ i ∈ keys, sigma' i ∈ gs)
    (equalU : ∀ g ∈ gs, ratioNumerator keys sigma p r g =
      ratioNumerator keys sigma' p' r' g)
    (w : G → Rat) :
    (keys.map fun i => p i * r i * w (sigma i)).sum /
        (keys.map fun i => p i * r i).sum =
      (keys.map fun i => p' i * r' i * w (sigma' i)).sum /
        (keys.map fun i => p' i * r' i).sum := by
  rw [normalized_regroup keys gs sigma p r w unique covered,
    normalized_regroup keys gs sigma' p' r' w unique covered']
  have h : (gs.map fun g => ratioNumerator keys sigma p r g) =
      (gs.map fun g => ratioNumerator keys sigma' p' r' g) := by
    apply List.map_congr_left
    intro g hg
    exact equalU g hg
  have hw : (gs.map fun g => ratioNumerator keys sigma p r g * w g) =
      (gs.map fun g => ratioNumerator keys sigma' p' r' g * w g) := by
    apply List.map_congr_left
    intro g hg
    rw [equalU g hg]
  rw [h, hw]

/-- An exact one-step simulation suffices for a cache codec: the decoder may
    be arbitrary and need not expose any mass or numeric representation. -/
theorem decode_run (decode : C → S) (update' : C → X → C)
    (update : S → X → S) (initial' : C) (initial : S)
    (initial_eq : decode initial' = initial)
    (step : ∀ c x, decode (update' c x) = update (decode c) x)
    (inputs : List X) :
    decode (inputs.foldl update' initial') = inputs.foldl update initial := by
  induction inputs generalizing initial' initial with
  | nil => simpa using initial_eq
  | cons x xs ih =>
    simp only [List.foldl_cons]
    exact ih (update' initial' x) (update initial x)
      (by rw [step initial' x, initial_eq])

theorem same_readout_after_run (decode : C → S) (update' : C → X → C)
    (update : S → X → S) (initial' : C) (initial : S)
    (initial_eq : decode initial' = initial)
    (step : ∀ c x, decode (update' c x) = update (decode c) x)
    (inputs : List X) (query : Q → S → Y) (q : Q) :
    query q (decode (inputs.foldl update' initial')) =
      query q (inputs.foldl update initial) := by
  rw [decode_run decode update' update initial' initial initial_eq step inputs]

end Kelana.ValueRecordQuotient
