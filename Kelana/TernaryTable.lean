import Std

namespace Kelana.TernaryTable

def code (a b c : Int) : Int := (a + 1) + 3 * (b + 1) + 9 * (c + 1)
def lookup (i x y z : Int) : Int :=
  (i % 3 - 1) * x + (i / 3 % 3 - 1) * y + (i / 9 - 1) * z

theorem code_range {a b c : Int}
    (ha : -1 ≤ a ∧ a ≤ 1) (hb : -1 ≤ b ∧ b ≤ 1) (hc : -1 ≤ c ∧ c ≤ 1) :
    0 ≤ code a b c ∧ code a b c < 27 := by unfold code; omega

theorem lookup_correct {a b c : Int}
    (ha : -1 ≤ a ∧ a ≤ 1) (hb : -1 ≤ b ∧ b ≤ 1) (_hc : -1 ≤ c ∧ c ≤ 1)
    (x y z : Int) : lookup (code a b c) x y z = a*x + b*y + c*z := by
  have h0 : code a b c % 3 - 1 = a := by unfold code; omega
  have h1 : code a b c / 3 % 3 - 1 = b := by unfold code; omega
  have h2 : code a b c / 9 - 1 = c := by unfold code; omega
  simp only [lookup, h0, h1, h2]

theorem product_bound {w x : Int}
    (hw : -1 ≤ w ∧ w ≤ 1) (hx : -128 ≤ x ∧ x ≤ 127) :
    -128 ≤ w*x ∧ w*x ≤ 128 := by
  have : w = -1 ∨ w = 0 ∨ w = 1 := by omega
  rcases this with rfl | rfl | rfl <;> simp at * <;> omega

theorem triple_bound {a b c x y z : Int}
    (ha : -1 ≤ a ∧ a ≤ 1) (hb : -1 ≤ b ∧ b ≤ 1) (hc : -1 ≤ c ∧ c ≤ 1)
    (hx : -128 ≤ x ∧ x ≤ 127) (hy : -128 ≤ y ∧ y ≤ 127) (hz : -128 ≤ z ∧ z ≤ 127) :
    -384 ≤ lookup (code a b c) x y z ∧ lookup (code a b c) x y z ≤ 384 := by
  rw [lookup_correct ha hb hc]
  have := product_bound ha hx
  have := product_bound hb hy
  have := product_bound hc hz
  omega

-- Two token sums stay packed through every addition in the 128-wide scale group.
def packed (n : Nat) (a b : Int) : Int :=
  (a + 384 * n) + 65536 * (b + 384 * n)

theorem add_closed (n m : Nat) (a b c d : Int) :
    packed n a b + packed m c d = packed (n+m) (a+c) (b+d) := by
  unfold packed
  simp only [Int.natCast_add]
  omega

def Bounded (n : Nat) (a b : Int) : Prop :=
  -384 * (n : Int) ≤ a ∧ a ≤ 384 * n ∧ -384 * (n : Int) ≤ b ∧ b ≤ 384 * n

theorem closed_bound {n m : Nat} {a b c d : Int}
    (h : Bounded n a b) (h' : Bounded m c d) : Bounded (n+m) (a+c) (b+d) := by
  unfold Bounded at *
  simp only [Int.natCast_add]
  omega

theorem no_carry {n : Nat} {a b : Int} (hn : n ≤ 43) (h : Bounded n a b) :
    (0 ≤ a + 384*n ∧ a + 384*n < 65536) ∧
    (0 ≤ b + 384*n ∧ b + 384*n < 65536) ∧
    (0 ≤ packed n a b ∧ packed n a b < 4294967296) := by
  unfold Bounded at h
  unfold packed
  omega

theorem decode_at_consumer {n : Nat} {a b : Int} (hn : n ≤ 43) (h : Bounded n a b) :
    packed n a b % 65536 - 384*n = a ∧ packed n a b / 65536 - 384*n = b := by
  have := no_carry hn h
  unfold packed at *
  omega

def sums (xs : List (Int × Int)) : Int × Int :=
  ((xs.map Prod.fst).sum, (xs.map Prod.snd).sum)

theorem whole_chain (xs : List (Int × Int)) :
    (xs.map (fun p => packed 1 p.1 p.2)).sum = packed xs.length (sums xs).1 (sums xs).2 := by
  induction xs with
  | nil => simp [sums, packed]
  | cons x xs ih =>
    simp only [List.map_cons, List.sum_cons, List.length_cons]
    rw [ih, add_closed]
    simp only [sums, List.map_cons, List.sum_cons]
    have : 1 + xs.length = xs.length + 1 := by omega
    rw [this]

theorem sums_bounded (xs : List (Int × Int))
    (h : ∀ p ∈ xs, Bounded 1 p.1 p.2) :
    Bounded xs.length (sums xs).1 (sums xs).2 := by
  induction xs with
  | nil => simp [sums, Bounded]
  | cons x xs ih =>
    have hx := h x (by simp)
    have ht := ih (by intro p hp; exact h p (by simp [hp]))
    have hc := closed_bound hx ht
    simpa [sums, Nat.add_comm] using hc

theorem chain_decodes (xs : List (Int × Int)) (hn : xs.length ≤ 43)
    (h : ∀ p ∈ xs, Bounded 1 p.1 p.2) :
    let total := (xs.map (fun p => packed 1 p.1 p.2)).sum
    total % 65536 - 384*xs.length = (sums xs).1 ∧
    total / 65536 - 384*xs.length = (sums xs).2 := by
  dsimp
  rw [whole_chain]
  exact decode_at_consumer hn (sums_bounded xs h)

theorem lookup_antipodal {i : Int} (_hi : 0 ≤ i ∧ i < 27) (x y z : Int) :
    lookup (26-i) x y z = -lookup i x y z := by
  have h0 : (26-i)%3-1 = -(i%3-1) := by omega
  have h1 : (26-i)/3%3-1 = -(i/3%3-1) := by omega
  have h2 : (26-i)/9-1 = -(i/9-1) := by omega
  simp only [lookup, h0, h1, h2]
  grind

def centered (a b : Int) : Int := a + 65536*b

theorem centered_negation (a b : Int) : centered (-a) (-b) = -centered a b := by
  unfold centered
  omega

theorem add_centered (n : Nat) (a b c d : Int) :
    packed n a b + centered c d = packed n (a+c) (b+d) := by
  unfold packed centered
  omega

theorem signed_table_recovery {a b : Int}
    (ha : -16512 ≤ a ∧ a ≤ 16512) (hb : -16512 ≤ b ∧ b ≤ 16512) :
    let word := packed 43 0 0 + centered a b
    word % 65536 - 16512 = a ∧ word / 65536 - 16512 = b := by
  dsimp
  rw [add_centered]
  simpa using decode_at_consumer (n := 43) (a := a) (b := b) (by decide)
    (by unfold Bounded; omega)

#print axioms lookup_antipodal
#print axioms signed_table_recovery
#print axioms chain_decodes
#print axioms lookup_correct
#print axioms add_closed
#print axioms decode_at_consumer
end Kelana.TernaryTable
