import Std

/-!
# Integer vectors for resource certificates

Finite lists of integers with zero padding beyond their length. Padding keeps
every operation total, so a short row behaves as a row of zeros instead of
failing somewhere unhelpful; `Obligations.Wf` and `Machine.Wf` in
`Kelana.ResourceBounds` are where matching lengths are actually insisted on.

Counts and dual weights are `Nat`, so nonnegativity is structural rather than a
side condition to discharge. Rational weights arrive here with denominators
already cleared: the bound proved downstream is homogeneous of degree one in the
weights, so scaling a rational certificate by a common denominator changes only
the units of the printed numerator.
-/

namespace Kelana.ResourceVectors

/-- Embedding of a count or weight vector into the signed vectors. -/
def emb (v : List Nat) : List Int := v.map (fun x : Nat => (x : Int))

/-- Inner product, truncating at the shorter list. Missing entries are zero. -/
def dot : List Int → List Int → Int
  | a :: as, b :: bs => a * b + dot as bs
  | _, _ => 0

/-- Inner product against a count vector. -/
def dotN (a : List Int) (n : List Nat) : Int := dot a (emb n)

/-- Pointwise sum, padding the shorter list with zeros. -/
def vadd : List Int → List Int → List Int
  | a :: as, b :: bs => (a + b) :: vadd as bs
  | [], bs => bs
  | as, [] => as

/-- Scalar multiple. -/
def smul (k : Int) (v : List Int) : List Int := v.map (fun x => k * x)

/-- Pointwise order with zero padding: `u ≤ v` at every index of either list. -/
def LeVec : List Int → List Int → Prop
  | a :: as, b :: bs => a ≤ b ∧ LeVec as bs
  | [], bs => ∀ b ∈ bs, 0 ≤ b
  | as, [] => ∀ a ∈ as, a ≤ 0

/-- Decision procedure for `LeVec`, so a certificate can be checked by `decide`
and mirrored by an external replay. -/
def leAll : List Int → List Int → Bool
  | a :: as, b :: bs => decide (a ≤ b) && leAll as bs
  | [], bs => bs.all (fun b => decide (0 ≤ b))
  | as, [] => as.all (fun a => decide (a ≤ 0))

/-- Weighted sum of rows: the `Aᵀλ` of a dual certificate. -/
def combine : List Nat → List (List Int) → List Int
  | k :: ws, r :: rs => vadd (smul (k : Int) r) (combine ws rs)
  | _, _ => []

/-- Every entry is nonnegative. -/
def NonNeg (v : List Int) : Prop := ∀ x ∈ v, 0 ≤ x

theorem emb_nil : emb [] = [] := rfl

theorem emb_cons (x : Nat) (xs : List Nat) : emb (x :: xs) = (x : Int) :: emb xs := rfl

theorem leVec_nil_left (v : List Int) : LeVec [] v ↔ ∀ b ∈ v, 0 ≤ b := by
  cases v <;> simp [LeVec]

theorem leVec_nil_right (v : List Int) : LeVec v [] ↔ ∀ a ∈ v, a ≤ 0 := by
  cases v <;> simp [LeVec]

theorem nonneg_emb (v : List Nat) : NonNeg (emb v) := by
  intro x hx
  simp only [emb, List.mem_map] at hx
  obtain ⟨y, _, hy⟩ := hx
  omega

theorem dot_nil_right (a : List Int) : dot a [] = 0 := by
  cases a <;> rfl

theorem dot_comm (a b : List Int) : dot a b = dot b a := by
  induction a generalizing b with
  | nil => cases b <;> rfl
  | cons x xs ih => cases b with
    | nil => rfl
    | cons y ys => simp [dot, ih, Int.mul_comm]

theorem dot_vadd (a b n : List Int) : dot (vadd a b) n = dot a n + dot b n := by
  induction a generalizing b n with
  | nil => cases b <;> cases n <;> simp [vadd, dot]
  | cons x xs ih =>
    cases b with
    | nil => cases n <;> simp [vadd, dot]
    | cons y ys =>
      cases n with
      | nil => simp [vadd, dot]
      | cons z zs =>
        simp only [vadd, dot, ih]
        rw [Int.add_mul]
        omega

theorem dot_smul (k : Int) (a n : List Int) : dot (smul k a) n = k * dot a n := by
  induction a generalizing n with
  | nil => simp [smul, dot]
  | cons x xs ih =>
    cases n with
    | nil => simp [smul, dot]
    | cons z zs =>
      have hrec := ih zs
      simp only [smul] at hrec
      simp only [smul, List.map_cons, dot, hrec]
      rw [Int.mul_add, Int.mul_assoc]

/-- The transpose identity: pricing rows and then contracting with the counts
equals contracting each row first and then pricing the results. -/
theorem dot_combine (w : List Nat) (rows : List (List Int)) (n : List Int) :
    dot (combine w rows) n = dot (emb w) (rows.map (fun r => dot r n)) := by
  induction w generalizing rows with
  | nil => cases rows <;> simp [combine, emb, dot]
  | cons k ws ih =>
    cases rows with
    | nil => simp [combine, emb, dot]
    | cons r rs =>
      simp only [combine, List.map_cons, dot_vadd, dot_smul, ih, emb, dot]

theorem leAll_iff (u v : List Int) : leAll u v = true ↔ LeVec u v := by
  induction u generalizing v with
  | nil =>
    cases v with
    | nil => simp [leAll, LeVec]
    | cons y ys => simp [leAll, LeVec]
  | cons x xs ih =>
    cases v with
    | nil => simp [leAll, LeVec]
    | cons y ys => simp [leAll, LeVec, ih]

instance decLeVec (u v : List Int) : Decidable (LeVec u v) :=
  decidable_of_iff (leAll u v = true) (leAll_iff u v)

/-- Monotonicity of the inner product in its second argument under nonnegative
weights. Every inequality in the dual chain is an instance of this. -/
theorem dot_le_dot (u v w : List Int) (hu : NonNeg u) (h : LeVec v w) :
    dot u v ≤ dot u w := by
  induction u generalizing v w with
  | nil => simp [dot]
  | cons x xs ih =>
    have hx : 0 ≤ x := hu x (by simp)
    have hxs : NonNeg xs := fun y hy => hu y (by simp [hy])
    cases v with
    | nil =>
      cases w with
      | nil => simp [dot]
      | cons c cs =>
        have hc : 0 ≤ c := h c (by simp)
        have htail : LeVec [] cs := fun b hb => h b (by simp [hb])
        have hrec := ih [] cs hxs htail
        have hprod : 0 ≤ x * c := Int.mul_nonneg hx hc
        simp only [dot] at *
        omega
    | cons b bs =>
      cases w with
      | nil =>
        have hb : b ≤ 0 := h b (by simp)
        have htail : LeVec bs [] :=
          (leVec_nil_right bs).mpr (fun a ha => h a (by simp [ha]))
        have hrec := ih bs [] hxs htail
        have hprod : x * b ≤ 0 := Int.mul_nonpos_of_nonneg_of_nonpos hx hb
        simp only [dot] at *
        omega
      | cons c cs =>
        have hbc : b ≤ c := h.1
        have hrec := ih bs cs hxs h.2
        have hprod : x * b ≤ x * c := Int.mul_le_mul_of_nonneg_left hbc hx
        simp only [dot]
        omega

theorem dot_le_dot_left (u v w : List Int) (hw : NonNeg w) (h : LeVec u v) :
    dot u w ≤ dot v w := by
  rw [dot_comm u w, dot_comm v w]
  exact dot_le_dot w u v hw h

/-! ## Counting a trace

A program is a list of instruction class indices. The count vector used by the
linear program is its histogram, and `dotN_histogram` is the only bridge between
per-instruction reasoning and the vector form.
-/

/-- Occurrences of class `j` in a trace. -/
def tally (j : Nat) : List Nat → Nat
  | [] => 0
  | x :: xs => (if x = j then 1 else 0) + tally j xs

/-- Counts of classes `s, s+1, …, s+k-1`. -/
def histFrom (s : Nat) : Nat → List Nat → List Nat
  | 0, _ => []
  | k + 1, t => tally s t :: histFrom (s + 1) k t

/-- Count vector of a trace over `k` instruction classes. -/
def histogram (k : Nat) (t : List Nat) : List Nat := histFrom 0 k t

/-- Weight of a trace charged instruction by instruction. -/
def traceWeight (w : List Int) (t : List Nat) : Int :=
  (t.map (fun j => w.getD j 0)).sum

private theorem sum_map_zero (t : List Nat) (f : Nat → Int) (h : ∀ j ∈ t, f j = 0) :
    (t.map f).sum = 0 := by
  induction t with
  | nil => simp
  | cons x xs ih =>
    have hx := h x (by simp)
    have hxs : ∀ j ∈ xs, f j = 0 := fun j hj => h j (by simp [hj])
    simp [hx, ih hxs]

private theorem sum_map_add (t : List Nat) (f g : Nat → Int) :
    (t.map (fun j => f j + g j)).sum = (t.map f).sum + (t.map g).sum := by
  induction t with
  | nil => simp
  | cons x xs ih => simp [ih]; omega

private theorem sum_map_congr (t : List Nat) (f g : Nat → Int) (h : ∀ j ∈ t, f j = g j) :
    (t.map f).sum = (t.map g).sum := by
  rw [List.map_congr_left h]

private theorem mul_tally (a : Int) (s : Nat) (t : List Nat) :
    a * (tally s t : Int) = (t.map (fun j => if j = s then a else 0)).sum := by
  induction t with
  | nil => simp [tally]
  | cons x xs ih =>
    by_cases h : x = s
    · subst h
      simp only [tally, List.map_cons, List.sum_cons]
      push_cast
      rw [Int.mul_add, ih]
      omega
    · simp only [tally, List.map_cons, List.sum_cons, if_neg h, Nat.zero_add]
      rw [ih]
      omega

private theorem dot_histFrom (w : List Int) (s k : Nat) (t : List Nat) :
    dot w (emb (histFrom s k t)) =
      (t.map (fun j => if s ≤ j ∧ j < s + k then w.getD (j - s) 0 else 0)).sum := by
  induction k generalizing w s with
  | zero =>
    rw [sum_map_zero t _ (by intro j _; rw [if_neg (by omega)])]
    simp [histFrom, emb, dot]
  | succ k ih =>
    cases w with
    | nil =>
      rw [sum_map_zero t _ (by intro j _; split <;> simp [List.getD])]
      simp [dot]
    | cons a w =>
      have hrec := ih w (s + 1)
      simp only [histFrom, emb_cons, dot, hrec, mul_tally a s t]
      rw [← sum_map_add]
      apply sum_map_congr
      intro j _
      by_cases hj : j = s
      · subst hj
        have h1 : ¬ (j + 1 ≤ j ∧ j < j + 1 + k) := by omega
        simp [h1, List.getD]
      · by_cases hin : s + 1 ≤ j ∧ j < s + 1 + k
        · have h1 : s ≤ j ∧ j < s + (k + 1) := by omega
          have h2 : j - s = (j - (s + 1)) + 1 := by omega
          simp [hj, hin, h1, h2, List.getD]
        · have h1 : ¬ (s ≤ j ∧ j < s + (k + 1)) := by omega
          simp [hj, hin, h1]

/-- Charging a trace instruction by instruction agrees with pricing its count
vector. This is the only step that turns a program into a point of the linear
program. -/
theorem dotN_histogram (w : List Int) (k : Nat) (t : List Nat)
    (ht : ∀ j ∈ t, j < k) : dotN w (histogram k t) = traceWeight w t := by
  rw [dotN, histogram, dot_histFrom]
  apply sum_map_congr
  intro j hj
  have := ht j hj
  simp [this]

theorem histogram_length (k : Nat) (t : List Nat) : (histogram k t).length = k := by
  have h : ∀ s, (histFrom s k t).length = k := by
    induction k with
    | zero => intro s; simp [histFrom]
    | succ k ih => intro s; simp [histFrom, ih]
  exact h 0

end Kelana.ResourceVectors
