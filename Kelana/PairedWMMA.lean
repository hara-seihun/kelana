import Std

/-!
Exact integer representation algebra, not a proof of gfx1151 WMMA execution.
Native probes in research/ffn/packed-wmma/ report fractional deviations even on
integer-valued FP16 operands. The rounded native decoder passes the recorded
cases, but a sufficient hardware error bound has not been established.
-/
namespace Kelana.PairedWMMA

def low (x : Int) : Int := (x + 8) % 16 - 8
def high (x : Int) : Int := (x - low x) / 16

theorem radix16 (x : Int) : low x + 16 * high x = x := by
  simp only [high, low]
  omega

theorem digit_bounds {x : Int} (hx : -128 ≤ x ∧ x ≤ 127) :
    (-8 ≤ low x ∧ low x ≤ 7) ∧ (-8 ≤ high x ∧ high x ≤ 8) := by
  simp only [high, low]
  omega

def l1 (xs : List Int) : Nat := (xs.map Int.natAbs).sum

theorem sum_bounded (xs : List Nat) (cap : Nat) (h : ∀ x ∈ xs, x ≤ cap) :
    xs.sum ≤ xs.length * cap := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    have hx := h x (by simp)
    have ht : ∀ y ∈ xs, y ≤ cap := by intro y hy; exact h y (by simp [hy])
    have := ih ht
    simp only [List.sum_cons, List.length_cons]
    grind

theorem sum_maximal (xs : List Nat) (cap : Nat)
    (h : ∀ x ∈ xs, x ≤ cap) (hs : xs.sum = xs.length * cap) :
    ∀ x ∈ xs, x = cap := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    have hx := h x (by simp)
    have ht : ∀ y ∈ xs, y ≤ cap := by intro y hy; exact h y (by simp [hy])
    have hb := sum_bounded xs cap ht
    simp only [List.sum_cons, List.length_cons] at hs
    have he : x = cap := by grind
    have hs' : xs.sum = xs.length * cap := by grind
    intro y hy
    simp only [List.mem_cons] at hy
    rcases hy with hy | hy
    · omega
    · exact ih ht hs' y hy

theorem l1_bounded {xs : List Int} (hlen : xs.length = 128)
    (hb : ∀ x ∈ xs, x.natAbs ≤ 8) : l1 xs ≤ 1024 := by
  have h := sum_bounded (xs.map Int.natAbs) 8 (by
    intro y hy
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hy
    exact hb x hx)
  simpa [l1, hlen] using h

theorem l1_edge {xs : List Int} (hlen : xs.length = 128)
    (hb : ∀ x ∈ xs, x.natAbs ≤ 8) (he : l1 xs = 1024) :
    ∀ x ∈ xs, x = 8 ∨ x = -8 := by
  have h := sum_maximal (xs.map Int.natAbs) 8 (by
    intro y hy
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hy
    exact hb x hx) (by simpa [l1, hlen] using he)
  intro x hx
  have ha : x.natAbs = 8 := h x.natAbs (List.mem_map.mpr ⟨x, hx, rfl⟩)
  omega

def factor (xs : List Int) : Int := if l1 xs = 1024 then 8 else 1
def normalized (xs : List Int) : List Int :=
  if l1 xs = 1024 then xs.map (fun x => x / 8) else xs

theorem normalization_exact {xs : List Int} (hlen : xs.length = 128)
    (hb : ∀ x ∈ xs, x.natAbs ≤ 8) :
    (normalized xs).map (fun x => factor xs * x) = xs := by
  unfold normalized factor
  split <;> rename_i he
  · simp only [List.map_map]
    have heq := List.map_congr_left (l := xs) (g := id) (f := fun x : Int => 8 * (x / 8)) (by
      intro x hx
      have h := l1_edge hlen hb he x hx
      rcases h with rfl | rfl <;> decide)
    simpa [Function.comp_def] using heq
  · simp

theorem normalized_bound {xs : List Int} (hlen : xs.length = 128)
    (hb : ∀ x ∈ xs, x.natAbs ≤ 8) : l1 (normalized xs) ≤ 1023 := by
  unfold normalized
  split <;> rename_i he
  · have hsmall : ∀ y ∈ xs.map (fun x => x / 8), y.natAbs ≤ 1 := by
      intro y hy
      obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hy
      have h := l1_edge hlen hb he x hx
      rcases h with rfl | rfl <;> decide
    have h := sum_bounded ((xs.map (fun x => x / 8)).map Int.natAbs) 1 (by
      intro y hy
      obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hy
      exact hsmall x hx)
    have : l1 (xs.map (fun x => x / 8)) ≤ 128 := by simpa [l1, hlen] using h
    omega
  · have := l1_bounded hlen hb
    omega

def packed (a b : Int) : Int := a + 2047 * b
def decodeHigh (p : Int) : Int := (p + 1023) / 2047
def decodeLow (p : Int) : Int := p - 2047 * decodeHigh p

theorem decode {a b : Int} (ha : -1023 ≤ a ∧ a ≤ 1023) :
    decodeLow (packed a b) = a ∧ decodeHigh (packed a b) = b := by
  unfold decodeLow decodeHigh packed
  omega

theorem packed_bound {a b : Int}
    (ha : -1023 ≤ a ∧ a ≤ 1023) (hb : -1023 ≤ b ∧ b ≤ 1023) :
    -2095104 ≤ packed a b ∧ packed a b ≤ 2095104 := by
  unfold packed
  omega

theorem weight_alphabet {a b : Int}
    (ha : -1 ≤ a ∧ a ≤ 1) (hb : -1 ≤ b ∧ b ≤ 1) :
    packed a b = -2048 ∨ packed a b = -2047 ∨ packed a b = -2046 ∨
    packed a b = -1 ∨ packed a b = 0 ∨ packed a b = 1 ∨
    packed a b = 2046 ∨ packed a b = 2047 ∨ packed a b = 2048 := by
  unfold packed
  omega

def dot : List Int → List Int → Int
  | w :: ws, x :: xs => w * x + dot ws xs
  | _, _ => 0

def pairedWeights : List Int → List Int → List Int
  | a :: as, b :: bs => packed a b :: pairedWeights as bs
  | _, _ => []

theorem dot_bound (ws xs : List Int) (hw : ∀ w ∈ ws, -1 ≤ w ∧ w ≤ 1) :
    -(l1 xs : Int) ≤ dot ws xs ∧ dot ws xs ≤ (l1 xs : Int) := by
  induction ws generalizing xs with
  | nil => simp [dot]
  | cons w ws ih =>
    cases xs with
    | nil => simp [dot, l1]
    | cons x xs =>
      have hb := hw w (by simp)
      have ht := ih xs (by intro v hv; exact hw v (by simp [hv]))
      have hp : x ≤ (x.natAbs : Int) := Int.le_natAbs
      have hn : -(x.natAbs : Int) ≤ x := by
        have h := Int.le_natAbs (a := -x)
        simp only [Int.natAbs_neg] at h
        omega
      have wc : w = -1 ∨ w = 0 ∨ w = 1 := by omega
      simp only [dot, l1, List.map_cons, List.sum_cons, Int.natCast_add] at *
      rcases wc with rfl | rfl | rfl <;> simp only [Int.neg_mul, Int.one_mul, Int.zero_mul, Int.zero_add] <;> omega

theorem paired_dot (as bs xs : List Int) (hlen : as.length = bs.length) :
    dot (pairedWeights as bs) xs = packed (dot as xs) (dot bs xs) := by
  induction as generalizing bs xs with
  | nil =>
    have : bs = [] := by simpa using hlen.symm
    subst bs
    simp [pairedWeights, dot, packed]
  | cons a as ih =>
    cases bs with
    | nil => simp at hlen
    | cons b bs =>
      have ht : as.length = bs.length := by simpa using hlen
      cases xs with
      | nil => simp [pairedWeights, dot, packed]
      | cons x xs =>
        simp only [pairedWeights, dot]
        rw [ih bs xs ht]
        unfold packed
        grind

theorem paired_dot_decodes (as bs xs : List Int)
    (hlen : as.length = bs.length)
    (ha : ∀ w ∈ as, -1 ≤ w ∧ w ≤ 1)
    (hb : ∀ w ∈ bs, -1 ≤ w ∧ w ≤ 1)
    (hx : l1 xs ≤ 1023) :
    let p := dot (pairedWeights as bs) xs
    (decodeLow p = dot as xs ∧ decodeHigh p = dot bs xs) ∧
    (-2095104 ≤ p ∧ p ≤ 2095104) := by
  have boundA := dot_bound as xs ha
  have boundB := dot_bound bs xs hb
  dsimp
  rw [paired_dot as bs xs hlen]
  constructor
  · apply decode
    omega
  · apply packed_bound <;> omega

theorem dot_scale_input (ws xs : List Int) (s : Int) :
    dot ws (xs.map (fun x => s * x)) = s * dot ws xs := by
  induction ws generalizing xs with
  | nil => simp [dot]
  | cons w ws ih =>
    cases xs with
    | nil => simp [dot]
    | cons x xs =>
      simp only [List.map_cons, dot]
      rw [ih]
      grind

theorem dot_normalized (ws xs : List Int) (hlen : xs.length = 128)
    (hb : ∀ x ∈ xs, x.natAbs ≤ 8) :
    dot ws xs = factor xs * dot ws (normalized xs) := by
  have he := congrArg (dot ws) (normalization_exact hlen hb)
  rw [dot_scale_input] at he
  exact he.symm

theorem dot_digits (ws xs : List Int) :
    dot ws xs = dot ws (xs.map low) + 16 * dot ws (xs.map high) := by
  induction ws generalizing xs with
  | nil => simp [dot]
  | cons w ws ih =>
    cases xs with
    | nil => simp [dot]
    | cons x xs =>
      simp only [List.map_cons, dot]
      have ht := ih xs
      have he := radix16 x
      grind

def pairedBlock (as bs xs : List Int) : Int × Int :=
  let lo := xs.map low
  let hi := xs.map high
  let weights := pairedWeights as bs
  let pL := dot weights (normalized lo)
  let pH := dot weights (normalized hi)
  (factor lo * decodeLow pL + 16 * factor hi * decodeLow pH,
   factor lo * decodeHigh pL + 16 * factor hi * decodeHigh pH)

theorem paired_block_correct (as bs xs : List Int)
    (hwlen : as.length = bs.length)
    (ha : ∀ w ∈ as, -1 ≤ w ∧ w ≤ 1)
    (hb : ∀ w ∈ bs, -1 ≤ w ∧ w ≤ 1)
    (hlen : xs.length = 128)
    (hx : ∀ x ∈ xs, -128 ≤ x ∧ x ≤ 127) :
    pairedBlock as bs xs = (dot as xs, dot bs xs) := by
  have hll : (xs.map low).length = 128 := by simpa using hlen
  have hhl : (xs.map high).length = 128 := by simpa using hlen
  have hlb : ∀ d ∈ xs.map low, d.natAbs ≤ 8 := by
    intro d hd
    obtain ⟨x, hi, rfl⟩ := List.mem_map.mp hd
    have := (digit_bounds (hx x hi)).1
    omega
  have hhb : ∀ d ∈ xs.map high, d.natAbs ≤ 8 := by
    intro d hd
    obtain ⟨x, hi, rfl⟩ := List.mem_map.mp hd
    have := (digit_bounds (hx x hi)).2
    omega
  have hl := (paired_dot_decodes as bs (normalized (xs.map low)) hwlen ha hb (normalized_bound hll hlb)).1
  have hh := (paired_dot_decodes as bs (normalized (xs.map high)) hwlen ha hb (normalized_bound hhl hhb)).1
  have al := dot_normalized as (xs.map low) hll hlb
  have ah := dot_normalized as (xs.map high) hhl hhb
  have bl := dot_normalized bs (xs.map low) hll hlb
  have bh := dot_normalized bs (xs.map high) hhl hhb
  have ad := dot_digits as xs
  have bd := dot_digits bs xs
  simp only [pairedBlock, hl.1, hl.2, hh.1, hh.2]
  apply Prod.ext <;> dsimp <;> grind

theorem sparse_dot_bound (ws xs : List Int)
    (hw : ∀ w ∈ ws, -1 ≤ w ∧ w ≤ 1)
    (hx : ∀ x ∈ xs, -8 ≤ x ∧ x ≤ 8) :
    -8 * (l1 ws : Int) ≤ dot ws xs ∧ dot ws xs ≤ 8 * (l1 ws : Int) := by
  induction ws generalizing xs with
  | nil => simp [dot, l1]
  | cons w ws ih =>
    have hb := hw w (by simp)
    have wt : ∀ v ∈ ws, -1 ≤ v ∧ v ≤ 1 := by
      intro v hv; exact hw v (by simp [hv])
    cases xs with
    | nil => simp [dot]; omega
    | cons x xs =>
      have xb := hx x (by simp)
      have ht := ih xs wt (by intro v hv; exact hx v (by simp [hv]))
      have wc : w = -1 ∨ w = 0 ∨ w = 1 := by omega
      simp only [dot, l1, List.map_cons, List.sum_cons, Int.natCast_add] at *
      rcases wc with rfl | rfl | rfl <;> simp at * <;> omega

theorem sparse_paired_dot_decodes (as bs xs : List Int)
    (hlen : as.length = bs.length)
    (ha : ∀ w ∈ as, -1 ≤ w ∧ w ≤ 1)
    (hb : ∀ w ∈ bs, -1 ≤ w ∧ w ≤ 1)
    (hs : l1 as ≤ 127 ∧ l1 bs ≤ 127)
    (hx : ∀ x ∈ xs, -8 ≤ x ∧ x ≤ 8) :
    let p := dot (pairedWeights as bs) xs
    (decodeLow p = dot as xs ∧ decodeHigh p = dot bs xs) ∧
    (-2095104 ≤ p ∧ p ≤ 2095104) := by
  have ba := sparse_dot_bound as xs ha hx
  have bb := sparse_dot_bound bs xs hb hx
  dsimp
  rw [paired_dot as bs xs hlen]
  constructor
  · apply decode; omega
  · apply packed_bound <;> omega

def sparsePairedBlock (as bs xs : List Int) : Int × Int :=
  let pL := dot (pairedWeights as bs) (xs.map low)
  let pH := dot (pairedWeights as bs) (xs.map high)
  (decodeLow pL + 16 * decodeLow pH,
   decodeHigh pL + 16 * decodeHigh pH)

theorem sparse_paired_block_correct (as bs xs : List Int)
    (hwlen : as.length = bs.length)
    (ha : ∀ w ∈ as, -1 ≤ w ∧ w ≤ 1)
    (hb : ∀ w ∈ bs, -1 ≤ w ∧ w ≤ 1)
    (hs : l1 as ≤ 127 ∧ l1 bs ≤ 127)
    (hx : ∀ x ∈ xs, -128 ≤ x ∧ x ≤ 127) :
    sparsePairedBlock as bs xs = (dot as xs, dot bs xs) := by
  have hlb : ∀ d ∈ xs.map low, -8 ≤ d ∧ d ≤ 8 := by
    intro d hd
    obtain ⟨x, hi, rfl⟩ := List.mem_map.mp hd
    have := (digit_bounds (hx x hi)).1
    omega
  have hhb : ∀ d ∈ xs.map high, -8 ≤ d ∧ d ≤ 8 := by
    intro d hd
    obtain ⟨x, hi, rfl⟩ := List.mem_map.mp hd
    exact (digit_bounds (hx x hi)).2
  have dl := (sparse_paired_dot_decodes as bs (xs.map low) hwlen ha hb hs hlb).1
  have dh := (sparse_paired_dot_decodes as bs (xs.map high) hwlen ha hb hs hhb).1
  simp only [sparsePairedBlock, dl.1, dl.2, dh.1, dh.2]
  rw [← dot_digits, ← dot_digits]

def reciprocalNumerator : Int := 4196353
def reciprocalDenominator : Int := 8589934592

theorem reciprocal_identity :
    2047 * reciprocalNumerator = reciprocalDenominator - 1 := by decide

-- A float32 product in this range is on the 2^-34 grid. A half-ulp error
-- of 2^-15 is 524288 grid units. Neither grid membership nor the hardware
-- rounding bound is established here; this theorem consumes those facts.
theorem reciprocal_decode {a b rounded : Int}
    (ha : -1023 ≤ a ∧ a ≤ 1023)
    (hb : -1023 ≤ b ∧ b ≤ 1023)
    (herr : -524288 ≤ rounded - 2 * packed a b * reciprocalNumerator ∧
       rounded - 2 * packed a b * reciprocalNumerator ≤ 524288) :
    (-8589934592 < rounded - b * 17179869184 ∧
      rounded - b * 17179869184 < 8589934592) ∧
    (rounded + 8589934592) / 17179869184 = b := by
  unfold packed reciprocalNumerator at herr
  omega

#print axioms reciprocal_decode
#print axioms sparse_paired_block_correct
#print axioms paired_block_correct
#print axioms paired_dot_decodes
#print axioms radix16
#print axioms normalization_exact
#print axioms normalized_bound
#print axioms decode
#print axioms packed_bound
#print axioms weight_alphabet

end Kelana.PairedWMMA
