import Std

namespace Kelana.E8MainProgram

private def slots : List (Fin 8) := List.finRange 8

def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

def dot (coeff z : Fin 8 → Rat) : Rat := total slots (fun i => coeff i * z i)

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
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_zero (xs : List I) :
    total xs (fun _ => (0 : Rat)) = 0 := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    change 0 + total xs (fun _ => (0 : Rat)) = 0
    grind

private theorem delta_sum [DecidableEq I] (xs : List I) (nodup : xs.Nodup)
    (i : I) (hi : i ∈ xs) (value : Rat) :
    total xs (fun j => if i = j then value else 0) = value := by
  induction xs with
  | nil => simp at hi
  | cons j ys ih =>
    have hn := (List.nodup_cons.mp nodup)
    simp only [List.mem_cons] at hi
    rcases hi with heq | hmem
    · subst i
      have hz : total ys (fun k => if j = k then value else 0) = 0 := by
        calc
          _ = total ys (fun _ => (0 : Rat)) := by
            apply total_congr ys; intro k hk
            have h : j ≠ k := by intro eq; exact hn.1 (eq ▸ hk)
            simp [h]
          _ = 0 := total_zero ys
      simp only [total, List.map_cons, List.sum_cons] at *
      grind
    · have hne : i ≠ j := by grind
      simp only [total, List.map_cons, List.sum_cons, if_neg hne]
      have htail := ih hn.2 hmem
      simp only [total] at htail
      grind

/-- Parity of eight sign bits. The final sign byte remains separate from the
    absolute-pattern byte, and its correction touches only slot zero. -/
def parityBits (bits : Fin 8 → Bool) : Bool :=
  slots.foldl (fun acc i => acc ^^ bits i) false

def parityByte (s : Fin 256) : Bool :=
  parityBits (fun i => Nat.testBit s.val i.val)

def correctedBit (s : Fin 256) (i : Fin 8) : Bool :=
  if i.val = 0 then Nat.testBit s.val 0 ^^ parityByte s
  else Nat.testBit s.val i.val

def signed (b : Bool) : Rat := if b then -1 else 1

/-- The corrected signs are even parity for *each* of the 256 sign bytes. -/
theorem corrected_even (s : Fin 256) :
    parityBits (correctedBit s) = false := by
  decide +kernel +revert

/-- Arbitrary masks support the algebra; source acceptance separately checks
    disjointness and that only the documented 256 absolute patterns appear. -/
def magnitude (threes fives : Fin 8 → Bool) (i : Fin 8) : Rat :=
  1 + 2 * (if threes i then 1 else 0) +
      4 * (if fives i then 1 else 0)

def lastFlip (threes : Fin 8 → Bool) (i : Fin 8) : Rat :=
  if i.val = 7 then signed (parityBits threes) else 1

def coefficient (threes fives : Fin 8 → Bool)
    (s : Fin 256) (i : Fin 8) : Rat :=
  (1 / 2 : Rat) * lastFlip threes i * magnitude threes fives i *
      signed (correctedBit s i) +
    (1 / 4 : Rat) * signed (parityByte s)

/-- The last-slot reversal on odd three-count is a real additional correction.
    Omitting it while retaining an even-sign half-root base would be wrong. -/
def lastCorrection (threes fives : Fin 8 → Bool)
    (s : Fin 256) (z : Fin 8 → Rat) : Rat :=
  if parityBits threes then
    -(magnitude threes fives (Fin.last 7) *
      signed (correctedBit s (Fin.last 7)) * z (Fin.last 7))
  else 0

private theorem scalar_expansion (h : Rat) (three five : Bool)
    (σ τ x : Rat) :
    ((1 / 2 : Rat) * h *
        (1 + 2 * (if three then 1 else 0) + 4 * (if five then 1 else 0)) * σ +
        (1 / 4 : Rat) * τ) * x =
      (1 / 2 : Rat) * σ * x +
      (if three then σ * x else 0) +
      2 * (if five then σ * x else 0) +
      (1 / 2 : Rat) * (h-1) *
        (1 + 2 * (if three then 1 else 0) + 4 * (if five then 1 else 0)) * σ * x +
      (1 / 4 : Rat) * τ * x := by
  cases three <;> cases five <;> grind +ring

/-- Full arbitrary-input reconstruction: even-sign half root, selected
    signed three/five corrections, the mandatory last-slot parity adjustment,
    and ONE shared quarter offset sum. No table data or floating arithmetic
    participates in this identity. -/
theorem main_dot_decomposition (threes fives : Fin 8 → Bool)
    (s : Fin 256) (z : Fin 8 → Rat) :
    dot (coefficient threes fives s) z =
      (1 / 2 : Rat) * total slots (fun i => signed (correctedBit s i) * z i) +
      total slots (fun i => if threes i then signed (correctedBit s i) * z i else 0) +
      2 * total slots (fun i => if fives i then signed (correctedBit s i) * z i else 0) +
      lastCorrection threes fives s z +
      ((1 / 4 : Rat) * signed (parityByte s)) * total slots z := by
  let base : Fin 8 → Rat := fun i =>
    (1 / 2 : Rat) * signed (correctedBit s i) * z i
  let triple : Fin 8 → Rat := fun i =>
    if threes i then signed (correctedBit s i) * z i else 0
  let five : Fin 8 → Rat := fun i =>
    2 * (if fives i then signed (correctedBit s i) * z i else 0)
  let correction : Fin 8 → Rat := fun i =>
    if i = Fin.last 7 then
      (if parityBits threes then
        -(magnitude threes fives i * signed (correctedBit s i) * z i)
       else 0)
    else 0
  let quarter : Fin 8 → Rat := fun i =>
    ((1 / 4 : Rat) * signed (parityByte s)) * z i
  have hpoint : ∀ i : Fin 8,
      coefficient threes fives s i * z i =
        base i + triple i + five i + correction i + quarter i := by
    intro i
    have hs := scalar_expansion (lastFlip threes i) (threes i) (fives i)
      (signed (correctedBit s i)) (signed (parityByte s)) (z i)
    have hc : (1 / 2 : Rat) * (lastFlip threes i - 1) *
        magnitude threes fives i * signed (correctedBit s i) * z i =
        correction i := by
      by_cases hlast : i = Fin.last 7
      · subst i
        by_cases hp : parityBits threes
        · simp only [lastFlip, magnitude, correction, signed, Fin.val_last,
            hp, ↓reduceIte]
          grind +ring
        · simp only [lastFlip, magnitude, correction, signed, Fin.val_last,
            hp, ↓reduceIte]
          grind +ring
      · have hval : i.val ≠ 7 := by
          intro hv; apply hlast; apply Fin.ext
          simpa only [Fin.val_last] using hv
        simp only [lastFlip, correction, hlast, hval, ↓reduceIte]
        grind +ring
    change ((1 / 2 : Rat) * lastFlip threes i *
        magnitude threes fives i * signed (correctedBit s i) +
        (1 / 4 : Rat) * signed (parityByte s)) * z i =
      (1 / 2 : Rat) * signed (correctedBit s i) * z i +
      (if threes i then signed (correctedBit s i) * z i else 0) +
      2 * (if fives i then signed (correctedBit s i) * z i else 0) +
      correction i +
      (1 / 4 : Rat) * signed (parityByte s) * z i
    unfold magnitude at hc
    rw [← hc]
    exact hs
  have hcorrection : total slots correction = lastCorrection threes fives s z := by
    calc
      _ = total slots (fun i => if Fin.last 7 = i then
          lastCorrection threes fives s z else 0) := by
        apply total_congr slots; intro i hi
        by_cases h : i = Fin.last 7
        · subst i
          simp [correction, lastCorrection]
        · have hr : Fin.last 7 ≠ i := by intro eq; exact h eq.symm
          simp only [correction, if_neg h, if_neg hr]
      _ = _ := delta_sum slots (List.nodup_finRange 8)
        (Fin.last 7) (List.mem_finRange _) _
  have hsum : dot (coefficient threes fives s) z =
      total slots base + total slots triple + total slots five +
        total slots correction + total slots quarter := by
    unfold dot
    calc
      _ = total slots (fun i => base i + triple i + five i +
          correction i + quarter i) := total_congr slots _ _
            (by intro i hi; exact hpoint i)
      _ = _ := by
        rw [total_add, total_add, total_add, total_add]
  rw [hsum, hcorrection]
  change total slots base + total slots triple + total slots five +
      lastCorrection threes fives s z + total slots quarter = _
  have hbase : total slots base = (1 / 2 : Rat) *
      total slots (fun i => signed (correctedBit s i) * z i) := by
    calc
      _ = total slots (fun i => (1 / 2 : Rat) *
          (signed (correctedBit s i) * z i)) := by
        apply total_congr slots
        intro i hi
        exact Rat.mul_assoc _ _ _
      _ = _ := total_mul slots _ _
  rw [hbase]
  rw [show total slots five = 2 * total slots (fun i =>
      if fives i then signed (correctedBit s i) * z i else 0) from
      total_mul slots _ _]
  rw [show total slots quarter =
      ((1 / 4 : Rat) * signed (parityByte s)) * total slots z from
      total_mul slots _ _]

end Kelana.E8MainProgram
