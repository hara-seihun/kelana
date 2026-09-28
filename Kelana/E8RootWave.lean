import Kelana.E8RootProgram

namespace Kelana.E8RootWave

open Kelana.E8RootProgram

/-- Three signed sums in each of the two 3-coordinate groups, two final-pair
    sums, and the original eight values are represented by 8+8+2+8 entries.
    Values depend on the input; this is not a model dictionary. -/
structure Wave where
  first : Fin 8 → Rat
  second : Fin 8 → Rat
  last : Fin 2 → Rat
  original : Fin 8 → Rat

def parity3 (mask : Fin 8) : Fin 2 :=
  ⟨((mask.val % 2) + ((mask.val / 2) % 2) + ((mask.val / 4) % 2)) % 2,
    Nat.mod_lt _ (by decide)⟩

def tripleFirst (mask : Fin 8) (z : Fin 8 → Rat) : Rat :=
  signBit mask.val 0 * z ⟨0, by decide⟩ +
  signBit mask.val 1 * z ⟨1, by decide⟩ +
  signBit mask.val 2 * z ⟨2, by decide⟩

def tripleSecond (mask : Fin 8) (z : Fin 8 → Rat) : Rat :=
  signBit mask.val 0 * z ⟨3, by decide⟩ +
  signBit mask.val 1 * z ⟨4, by decide⟩ +
  signBit mask.val 2 * z ⟨5, by decide⟩

def prepare (z : Fin 8 → Rat) : Wave where
  first := fun a => tripleFirst a z
  second := fun b => tripleSecond b z
  last := fun p => if p.val = 0 then z ⟨6, by decide⟩ + z ⟨7, by decide⟩
    else z ⟨6, by decide⟩ - z ⟨7, by decide⟩
  original := z

/-- Complementing all seven sign bits when bit 6 is set makes the canonical
    mask smaller than 64. The final x₆ sign is then positive. -/
def highPayload (code : Fin 256) : Nat := code.val - 128

def negated (code : Fin 256) : Bool := 64 ≤ highPayload code

def canonicalMask (code : Fin 256) : Nat :=
  if negated code then 127 - highPayload code else highPayload code

def groupA (code : Fin 256) : Fin 8 :=
  ⟨canonicalMask code % 8, Nat.mod_lt _ (by decide)⟩

def groupB (code : Fin 256) : Fin 8 :=
  ⟨(canonicalMask code / 8) % 8, Nat.mod_lt _ (by decide)⟩

def groupParity (code : Fin 256) : Fin 2 :=
  ⟨((parity3 (groupA code)).val + (parity3 (groupB code)).val) % 2,
    Nat.mod_lt _ (by decide)⟩

def observe (code : Fin 256) (w : Wave) : Rat :=
  if code.val < 128 then
    if code.val = 127 then 0 else
      lowSign code * (w.original (lowI code) +
        lowDifference code * w.original (lowJ code))
  else
    (if negated code then -(1 / 2 : Rat) else 1 / 2) *
      (w.first (groupA code) + w.second (groupB code) +
        w.last (groupParity code))

/-- This checked equality compares the two coefficient systems at each
    code/axis. The check expands only byte arithmetic and signs, never reads
    an upstream source table. Its finite quantified proof is kernel-checked. -/
theorem basis_coefficients :
    ∀ code : Fin 256, ∀ axis : Fin 8,
      observe code (prepare (fun i => if i = axis then 1 else 0)) =
        codeCoefficient code axis := by
  decide +kernel

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

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

private theorem basis_expansion (z : Fin 8 → Rat) (j : Fin 8) :
    total (List.finRange 8) (fun i => z i * (if j = i then 1 else 0)) = z j := by
  calc
    _ = total (List.finRange 8) (fun i => if j = i then z j else 0) := by
      apply total_congr (List.finRange 8); intro i hi
      by_cases h : j = i
      · subst i; simp
      · simp [h]
    _ = z j := delta_sum (List.finRange 8) (List.nodup_finRange 8) j
      (List.mem_finRange j) _

private theorem observe_add (code : Fin 256) (x y : Fin 8 → Rat) :
    observe code (prepare (fun i => x i + y i)) =
      observe code (prepare x) + observe code (prepare y) := by
  by_cases low : code.val < 128
  · by_cases zero : code.val = 127
    · simp only [observe, zero, ↓reduceIte]
      grind
    · simp only [observe, low, zero, ↓reduceIte, prepare]
      grind +ring
  · by_cases p : (groupParity code).val = 0
    · simp only [observe, low, ↓reduceIte, prepare, tripleFirst, tripleSecond, p]
      grind +ring
    · simp only [observe, low, ↓reduceIte, prepare, tripleFirst, tripleSecond, p]
      grind +ring

private theorem observe_scale (code : Fin 256) (q : Rat) (x : Fin 8 → Rat) :
    observe code (prepare (fun i => q * x i)) =
      q * observe code (prepare x) := by
  by_cases low : code.val < 128
  · by_cases zero : code.val = 127
    · simp only [observe, zero, ↓reduceIte]
      grind
    · simp only [observe, low, zero, ↓reduceIte, prepare]
      grind +ring
  · by_cases p : (groupParity code).val = 0
    · simp only [observe, low, ↓reduceIte, prepare, tripleFirst, tripleSecond, p]
      grind +ring
    · simp only [observe, low, ↓reduceIte, prepare, tripleFirst, tripleSecond, p]
      grind +ring

private def basis (i j : Fin 8) : Rat := if j = i then 1 else 0

private def combination (xs : List (Fin 8)) (z : Fin 8 → Rat) : Fin 8 → Rat :=
  fun j => total xs (fun i => z i * basis i j)

private theorem combination_all (z : Fin 8 → Rat) :
    combination (List.finRange 8) z = z := by
  funext j
  exact basis_expansion z j

/-- Linear maps on eight rational inputs are determined by their eight basis
    values. The induction really assembles the input from finite basis sums. -/
private theorem linear_basis (F : (Fin 8 → Rat) → Rat)
    (hadd : ∀ x y, F (fun j => x j + y j) = F x + F y)
    (hscale : ∀ q x, F (fun j => q * x j) = q * F x)
    (z : Fin 8 → Rat) :
    F z = total (List.finRange 8) (fun i => z i * F (basis i)) := by
  have hzero : F (fun _ => 0) = 0 := by
    have h := hscale (0 : Rat) (fun _ => 0)
    grind
  have aux : ∀ xs : List (Fin 8),
      F (combination xs z) = total xs (fun i => z i * F (basis i)) := by
    intro xs
    induction xs with
    | nil =>
      change F (fun _ => (0 : Rat)) = 0
      exact hzero
    | cons i xs ih =>
      have hs : combination (i :: xs) z =
          (fun j => z i * basis i j + combination xs z j) := by
        funext j
        simp only [combination, total, List.map_cons, List.sum_cons]
      rw [hs, hadd, hscale, ih]
      simp only [total, List.map_cons, List.sum_cons]
  calc
    F z = F (combination (List.finRange 8) z) := by rw [combination_all]
    _ = _ := aux (List.finRange 8)

/-- Full arbitrary-rational-input equality for every byte. `observe` reads
    exactly three prepared wave values on the high branch, and two original
    coordinates (or zero) on the low branch. Finite basis comparison is
    composed with the proved linearity of both readers; it is not assumed as
    an arbitrary-input equality. -/
theorem observe_eq_code_dot (code : Fin 256) (z : Fin 8 → Rat) :
    observe code (prepare z) = dot (codeCoefficient code) z := by
  let F : (Fin 8 → Rat) → Rat := fun x => observe code (prepare x)
  have h := linear_basis F (observe_add code) (observe_scale code) z
  calc
    _ = total (List.finRange 8) (fun i => z i * F (basis i)) := h
    _ = total (List.finRange 8) (fun i => codeCoefficient code i * z i) := by
      apply total_congr (List.finRange 8); intro i hi
      have hb := basis_coefficients code i
      change F (basis i) = codeCoefficient code i at hb
      rw [hb]
      exact Rat.mul_comm _ _
    _ = dot (codeCoefficient code) z := rfl

/-- Combined with the earlier arbitrary-input direct-dot theorem, this
    establishes the stated A[a]+B[b]+C[p] reader, not merely basis vectors. -/
theorem observe_eq_direct (code : Fin 256) (z : Fin 8 → Rat) :
    observe code (prepare z) =
      if code.val < 128 then
        (if code.val = 127 then 0 else
          lowSign code * (z (lowI code) + lowDifference code * z (lowJ code)))
      else
        (1 / 2 : Rat) *
          (total (List.finRange 7) (fun j =>
            signBit (code.val - 128) j.val * z (Fin.castSucc j)) +
            paritySign (code.val - 128) * z (Fin.last 7)) := by
  rw [observe_eq_code_dot, code_dot]

end Kelana.E8RootWave
