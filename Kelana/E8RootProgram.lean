import Std

namespace Kelana.E8RootProgram

def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

def dot (coeff input : Fin 8 → Rat) : Rat :=
  total (List.finRange 8) (fun j => coeff j * input j)

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

private theorem total_map (xs : List I) (f : I → J) (g : J → Rat) :
    total (xs.map f) g = total xs (fun i => g (f i)) := by
  simp only [total, List.map_map, Function.comp_def]

private theorem total_append (xs ys : List I) (f : I → Rat) :
    total (xs ++ ys) f = total xs f + total ys f := by
  simp [total, List.map_append, List.sum_append]

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

/-- The same basis coordinate may be used twice; the case i=j yields a
    doubled axis (or cancellation), not an implicit distinctness assumption. -/
def sparseCoefficient (i j : Fin 8) (s t : Rat) (k : Fin 8) : Rat :=
  s * ((if k = i then 1 else 0) + t * (if k = j then 1 else 0))

theorem sparse_dot (i j : Fin 8) (s t : Rat) (input : Fin 8 → Rat) :
    dot (sparseCoefficient i j s t) input =
      s * (input i + t * input j) := by
  have hi := List.mem_finRange i
  have hj := List.mem_finRange j
  have hn := List.nodup_finRange 8
  have hfirst : total (List.finRange 8)
      (fun k => (if k = i then input i else 0)) = input i := by
    calc
      _ = total (List.finRange 8) (fun k => if i = k then input i else 0) := by
        apply total_congr (List.finRange 8); intro k hk
        by_cases h : k = i
        · subst k; simp
        · have h' : i ≠ k := fun eq => h eq.symm
          simp only [if_neg h, if_neg h']
      _ = input i := delta_sum _ hn i hi _
  have hsecond : total (List.finRange 8)
      (fun k => (if k = j then t * input j else 0)) = t * input j := by
    calc
      _ = total (List.finRange 8) (fun k => if j = k then t * input j else 0) := by
        apply total_congr (List.finRange 8); intro k hk
        by_cases h : k = j
        · subst k; simp
        · have h' : j ≠ k := fun eq => h eq.symm
          simp only [if_neg h, if_neg h']
      _ = t * input j := delta_sum _ hn j hj _
  unfold dot sparseCoefficient
  calc
    _ = s * total (List.finRange 8) (fun k =>
        (if k = i then input i else 0) +
        (if k = j then t * input j else 0)) := by
      rw [← total_mul]
      apply total_congr (List.finRange 8); intro k hk
      by_cases hki : k = i <;> by_cases hkj : k = j <;> simp [hki, hkj]
      all_goals grind +ring
    _ = _ := by rw [total_add, hfirst, hsecond]

/-- Each low byte encodes two 3-bit axes, a branch sign, and an overall sign.
    Code 127 is explicitly reserved as zero. -/
def lowI (code : Fin 256) : Fin 8 :=
  ⟨code.val % 8, Nat.mod_lt _ (by decide)⟩

def lowJ (code : Fin 256) : Fin 8 :=
  ⟨(code.val / 8) % 8, Nat.mod_lt _ (by decide)⟩

def lowSign (code : Fin 256) : Rat :=
  if (code.val / 64) % 2 = 0 then 1 else -1

def lowDifference (code : Fin 256) : Rat :=
  if (lowI code).val ≤ (lowJ code).val then 1 else -1

def lowCoefficient (code : Fin 256) : Fin 8 → Rat :=
  if code.val = 127 then fun _ => 0
  else sparseCoefficient (lowI code) (lowJ code)
    (lowSign code) (lowDifference code)

theorem low_dot (code : Fin 256) (input : Fin 8 → Rat) :
    dot (lowCoefficient code) input =
      if code.val = 127 then 0 else
        lowSign code *
          (input (lowI code) + lowDifference code * input (lowJ code)) := by
  by_cases h : code.val = 127
  · simp only [lowCoefficient, h, ↓reduceIte, dot]
    have hz : total (List.finRange 8) (fun _ => (0 : Rat)) = 0 := by
      induction (List.finRange 8) with
      | nil => rfl
      | cons k ks ih =>
        change 0 + total ks (fun _ => (0 : Rat)) = 0
        grind
    simpa using hz
  · simp only [lowCoefficient, h, ↓reduceIte]
    exact sparse_dot _ _ _ _ input

/-- The seven input bits choose signs; the eighth sign is their product, so
    the eight signs have even parity. -/
def signBit (bits index : Nat) : Rat :=
  if (bits / 2 ^ index) % 2 = 0 then 1 else -1

def paritySign (bits : Nat) : Rat :=
  ((List.finRange 7).map fun j => signBit bits j.val).prod

def halfSign (bits : Nat) (j : Fin 8) : Rat :=
  if j.val = 7 then paritySign bits else signBit bits j.val

def halfCoefficient (bits : Nat) (j : Fin 8) : Rat :=
  (1 / 2 : Rat) * halfSign bits j

theorem sign_bit_square (bits index : Nat) :
    signBit bits index * signBit bits index = 1 := by
  by_cases h : (bits / 2 ^ index) % 2 = 0
  · simp only [signBit, h, ↓reduceIte]
    decide +kernel
  · simp only [signBit, h, ↓reduceIte]
    decide +kernel

private theorem product_sign_square (bits : Nat) (indices : List (Fin 7)) :
    ((indices.map fun j => signBit bits j.val).prod) *
    ((indices.map fun j => signBit bits j.val).prod) = 1 := by
  induction indices with
  | nil => simp
  | cons j rest ih =>
    simp only [List.map_cons, List.prod_cons]
    have hb := sign_bit_square bits j.val
    grind +ring

theorem parity_sign_square (bits : Nat) :
    paritySign bits * paritySign bits = 1 := by
  exact product_sign_square bits (List.finRange 7)

/-- This is the all-input direct dot; the final coordinate uses the product
    parity sign. The seven data signs can be evaluated directly from bits. -/
theorem half_dot (bits : Nat) (input : Fin 8 → Rat) :
    dot (halfCoefficient bits) input =
      (1 / 2 : Rat) *
        (total (List.finRange 7) (fun j =>
            signBit bits j.val * input (Fin.castSucc j)) +
          paritySign bits * input (Fin.last 7)) := by
  unfold dot halfCoefficient
  rw [show List.finRange 8 =
      (List.finRange 7).map Fin.castSucc ++ [Fin.last 7] by decide +kernel]
  rw [total_append, total_map]
  have hseven : total (List.finRange 7) (fun j =>
      (1 / 2 : Rat) * halfSign bits (Fin.castSucc j) * input (Fin.castSucc j)) =
      (1 / 2 : Rat) * total (List.finRange 7) (fun j =>
        signBit bits j.val * input (Fin.castSucc j)) := by
    rw [← total_mul]
    apply total_congr (List.finRange 7); intro j hj
    simp only [halfSign, Fin.val_castSucc]
    have hj7 : j.val ≠ 7 := by have h := j.isLt; omega
    simp [hj7, Rat.mul_assoc]
  rw [hseven]
  simp only [total, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
  have hlast : halfSign bits (Fin.last 7) = paritySign bits := by
    have hv : (Fin.last 7).val = 7 := Fin.val_last 7
    simp only [halfSign, hv, ↓reduceIte]
  rw [hlast]
  grind

/-- The code selects sparse integer/axis or half-sign branch without a table.
    The upstream 256-entry table's equality to this decoder is a separate
    exhaustive exact-data check, not assumed or asserted here. -/
def codeCoefficient (code : Fin 256) : Fin 8 → Rat :=
  if code.val < 128 then lowCoefficient code else halfCoefficient (code.val - 128)

theorem code_dot (code : Fin 256) (input : Fin 8 → Rat) :
    dot (codeCoefficient code) input =
      if code.val < 128 then
        (if code.val = 127 then 0 else
          lowSign code *
            (input (lowI code) + lowDifference code * input (lowJ code)))
      else
        (1 / 2 : Rat) *
          (total (List.finRange 7) (fun j =>
            signBit (code.val - 128) j.val * input (Fin.castSucc j)) +
            paritySign (code.val - 128) * input (Fin.last 7)) := by
  by_cases h : code.val < 128
  · simp only [codeCoefficient, h, ↓reduceIte]
    exact low_dot code input
  · simp only [codeCoefficient, h, ↓reduceIte]
    exact half_dot (code.val - 128) input

end Kelana.E8RootProgram
