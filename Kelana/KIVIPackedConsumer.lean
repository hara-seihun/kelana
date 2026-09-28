import Std

/-! Exact rational semantics of the packed KIVI score/value continuation.
Fields and labels are arbitrary. A common deterministic normalization can be
softmax; the theorem does not assume offsets from different chunks cancel. -/
namespace Kelana.KIVIPackedConsumer

private def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

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

private def coords (n : Nat) : List (Fin n) := List.finRange n

/-- The metadata is indexed by the token's own K chunk, not replaced by a
single row-global offset. This definition also accepts arbitrary token fields. -/
def conventionalScore {d : Nat} (q origin step digit : Fin d → Rat) : Rat :=
  total (coords d) (fun i => q i * (origin i + step i * digit i))

def packedScore {d : Nat} (q origin step digit : Fin d → Rat) : Rat :=
  total (coords d) (fun i => q i * origin i) +
  total (coords d) (fun i => (q i * step i) * digit i)

theorem score_identity {d : Nat} (q origin step digit : Fin d → Rat) :
    conventionalScore q origin step digit = packedScore q origin step digit := by
  unfold conventionalScore packedScore
  calc
    total (coords d) (fun i => q i * (origin i + step i * digit i)) =
        total (coords d) (fun i => q i * origin i + (q i * step i) * digit i) := by
          apply total_congr
          intro i _
          grind +ring
    _ = _ := total_add (coords d)
      (fun i => q i * origin i) (fun i => (q i * step i) * digit i)

/-- Value metadata varies per token and 32-coordinate group. -/
def conventionalValue {t d g : Nat} (p : Fin t → Rat)
    (origin step : Fin t → Fin g → Rat) (digit : Fin t → Fin d → Rat)
    (group : Fin d → Fin g) (coord : Fin d) : Rat :=
  total (coords t) (fun j => p j * (origin j (group coord) +
                                                step j (group coord) * digit j coord))

def packedValue {t d g : Nat} (p : Fin t → Rat)
    (origin step : Fin t → Fin g → Rat) (digit : Fin t → Fin d → Rat)
    (group : Fin d → Fin g) (coord : Fin d) : Rat :=
  total (coords t) (fun j => p j * origin j (group coord)) +
  total (coords t) (fun j => (p j * step j (group coord)) * digit j coord)

theorem value_identity {t d g : Nat} (p : Fin t → Rat)
    (origin step : Fin t → Fin g → Rat) (digit : Fin t → Fin d → Rat)
    (group : Fin d → Fin g) (coord : Fin d) :
    conventionalValue p origin step digit group coord =
    packedValue p origin step digit group coord := by
  unfold conventionalValue packedValue
  calc
    total (coords t) (fun j => p j * (origin j (group coord) +
                                   step j (group coord) * digit j coord)) =
        total (coords t) (fun j => p j * origin j (group coord) +
                                   (p j * step j (group coord)) * digit j coord) := by
          apply total_congr
          intro j _
          grind +ring
    _ = _ := total_add (coords t)
      (fun j => p j * origin j (group coord))
      (fun j => (p j * step j (group coord)) * digit j coord)

/-- Any deterministic normalized attention map consumes the same complete
score row, then the value's exact fields and the complete O column agree.
This includes both heads independently with their own query/probabilities. -/
theorem whole_observer {t d g o : Nat} (q : Fin d → Rat)
    (korigin kstep kdigit : Fin t → Fin d → Rat)
    (vorigin vstep : Fin t → Fin g → Rat) (vdigit : Fin t → Fin d → Rat)
    (group : Fin d → Fin g) (normalizer : (Fin t → Rat) → Fin t → Rat)
    (readout : Fin o → Fin d → Rat) (output : Fin o) :
    total (coords d) (fun coord => readout output coord *
      conventionalValue
        (normalizer (fun token => conventionalScore q (korigin token)
                                                     (kstep token) (kdigit token)))
        vorigin vstep vdigit group coord) =
    total (coords d) (fun coord => readout output coord *
      packedValue
        (normalizer (fun token => packedScore q (korigin token)
                                               (kstep token) (kdigit token)))
        vorigin vstep vdigit group coord) := by
  have hs : (fun token => conventionalScore q (korigin token) (kstep token) (kdigit token)) =
            (fun token => packedScore q (korigin token) (kstep token) (kdigit token)) := by
    funext token
    exact score_identity q (korigin token) (kstep token) (kdigit token)
  rw [hs]
  apply total_congr
  intro coord _
  rw [value_identity]

end Kelana.KIVIPackedConsumer
