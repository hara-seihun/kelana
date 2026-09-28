import Kelana.PairedWMMA

namespace Kelana.DeferredCarrier
open PairedWMMA

structure Run where
  gate : List Int
  up : List Int
  input : List Int

def valid (r : Run) : Prop :=
  r.gate.length = r.up.length ∧
  (∀ w ∈ r.gate, -1 ≤ w ∧ w ≤ 1) ∧
  (∀ w ∈ r.up, -1 ≤ w ∧ w ≤ 1) ∧ l1 r.input ≤ 1023

def encoded (r : Run) : Int := dot (pairedWeights r.gate r.up) r.input

theorem certified_run (r : Run) (h : valid r) :
    decodeLow (encoded r) = dot r.gate r.input ∧
    decodeHigh (encoded r) = dot r.up r.input := by
  obtain ⟨hlen, hg, hu, hx⟩ := h
  exact (paired_dot_decodes r.gate r.up r.input hlen hg hu hx).1

theorem certified_partition (runs : List Run) (h : ∀ r ∈ runs, valid r) :
    (runs.map fun r => decodeLow (encoded r)).sum =
      (runs.map fun r => dot r.gate r.input).sum ∧
    (runs.map fun r => decodeHigh (encoded r)).sum =
      (runs.map fun r => dot r.up r.input).sum := by
  induction runs with
  | nil => simp
  | cons r rs ih =>
    have hr := certified_run r (h r (by simp))
    have ht := ih (by intro r hr; exact h r (by simp [hr]))
    simp only [List.map_cons, List.sum_cons]
    omega

/-- Splitting the carrier need not change the shared scale or quantizer. -/
theorem shared_scale (s : Int) (xs : List Int) :
    (xs.map fun x => s*x).sum = s*xs.sum := by
  induction xs with
  | nil => simp
  | cons x xs ih => simp only [List.map_cons, List.sum_cons, ih]; grind

theorem single_block_safe (xs : List Int) (hn : xs.length ≤ 128)
    (hx : ∀ x ∈ xs, x.natAbs ≤ 7) : l1 xs ≤ 1023 := by
  have h := sum_bounded (xs.map Int.natAbs) 7 (by
    intro y hy
    obtain ⟨x, hx', rfl⟩ := List.mem_map.mp hy
    exact hx x hx')
  simp only [List.length_map] at h
  unfold l1
  omega

theorem prefix_budget (front suffix : List Int) (h : l1 (front++suffix) ≤ 1023) :
    l1 front ≤ 1023 := by
  simp only [l1, List.map_append, List.sum_append] at *
  omega

/-- Per-token cumulative L1. One shared cut must satisfy every token in a tile. -/
def Fits {Token : Type} (cumulative : Token → Nat → Nat) (cap s t : Nat) : Prop :=
  ∀ token, cumulative token t ≤ cumulative token s + cap

/-- The longest legal next run is monotone in its starting point.
This is a scheduling theorem for fixed-order L1-certified runs, not a bound on
arbitrary GPU programs or alternative representations. -/
theorem longest_monotone {Token : Type} (cumulative : Token → Nat → Nat)
    (mono : ∀ token a b, a ≤ b → cumulative token a ≤ cumulative token b)
    (cap n : Nat) (next : Nat → Nat)
    (progress : ∀ s ≤ n, s ≤ next s ∧ next s ≤ n)
    (legal : ∀ s ≤ n, Fits cumulative cap s (next s))
    (longest : ∀ s t, s ≤ t → t ≤ n → Fits cumulative cap s t → t ≤ next s)
    {a b : Nat} (hab : a ≤ b) (hb : b ≤ n) : next a ≤ next b := by
  have ha : a ≤ n := by omega
  have pa := progress a ha
  have pb := progress b hb
  by_cases h : next a ≤ b
  · omega
  · apply longest b (next a) (by omega) pa.2
    intro token
    have hl := legal a ha token
    have hm := mono token a b hab
    omega

def advance (next : Nat → Nat) : Nat → Nat
  | 0 => 0
  | k+1 => next (advance next k)

/-- After any number of runs, greedy has covered at least as many blocks as any
other legal partition. Thus it minimizes the number of separations under this
certificate, order and shared-token schedule. It does not minimize all unit cycles. -/
theorem greedy_dominates {Token : Type} (cumulative : Token → Nat → Nat)
    (mono : ∀ token a b, a ≤ b → cumulative token a ≤ cumulative token b)
    (cap n : Nat) (next cuts : Nat → Nat)
    (progress : ∀ s ≤ n, s ≤ next s ∧ next s ≤ n)
    (legal : ∀ s ≤ n, Fits cumulative cap s (next s))
    (longest : ∀ s t, s ≤ t → t ≤ n → Fits cumulative cap s t → t ≤ next s)
    (start : cuts 0 = 0)
    (ordered : ∀ k, cuts k ≤ cuts (k+1))
    (bounded : ∀ k, cuts k ≤ n)
    (cutLegal : ∀ k, Fits cumulative cap (cuts k) (cuts (k+1))) :
    ∀ k, cuts k ≤ advance next k ∧ advance next k ≤ n := by
  intro k
  induction k with
  | zero => simp [advance, start]
  | succ k ih =>
    have pg := progress (advance next k) ih.2
    have hc := longest (cuts k) (cuts (k+1)) (ordered k) (bounded (k+1)) (cutLegal k)
    have hm := longest_monotone cumulative mono cap n next progress legal longest ih.1 ih.2
    simp only [advance]
    omega

/-- Exact nearest rounding of a rational p/q, with upward tie breaking.
The results below are strictly inside rounding cells, so the tie rule is irrelevant. -/
def nearest (q p : Int) : Int := (2*p+q)/(2*q)

/-- A sufficient error budget for both stages of separation. q is a positive
fixed-point denominator and e/q is the carrier error. This does not assert an
error bound for WMMA or for the floating reciprocal and FMA used by a kernel. -/
theorem noisy_separation (q lo hi e : Int) (hq : 0 < q)
    (hl : -1023 ≤ lo ∧ lo ≤ 1023) (he : -q < 2*e ∧ 2*e < q) :
    let p := q*(lo+2047*hi)+e
    nearest (2047*q) p = hi ∧ nearest q (p-q*2047*hi) = lo := by
  have hlow : q*(-1023) ≤ q*lo := (Int.mul_le_mul_left hq).2 hl.1
  have hupp : q*lo ≤ q*1023 := (Int.mul_le_mul_left hq).2 hl.2
  dsimp [nearest]
  constructor
  · apply (Int.ediv_eq_iff_of_pos (by omega : 0 < 2*(2047*q))).2
    constructor <;> grind
  · apply (Int.ediv_eq_iff_of_pos (by omega : 0 < 2*q)).2
    constructor <;> grind

/-- One extra bit about the low channel disambiguates a carry. The carrier
alone need not preserve the channels over its original centered interval. -/
def parityLow (p parity : Int) : Int :=
  (p - 2047*((p-parity)%2) + 2046)%4094 - 2046

def parityHigh (p parity : Int) : Int := (p-parityLow p parity)/2047

theorem parity_assisted_decode (lo hi : Int) (h : -2046 ≤ lo ∧ lo ≤ 2046) :
    parityLow (lo+2047*hi) (lo%2) = lo ∧
    parityHigh (lo+2047*hi) (lo%2) = hi := by
  unfold parityHigh parityLow
  omega

theorem expanded_range_needs_side_information :
    ¬ ∃ decode : Int → Int, ∀ lo hi : Int, -2046 ≤ lo ∧ lo ≤ 2046 →
      decode (lo+2047*hi) = lo := by
  rintro ⟨decode, h⟩
  have ha := h (-1023) 1 (by omega)
  have hb := h 1024 0 (by omega)
  have he : (-1023 : Int)+2047*1 = 1024+2047*0 := by decide
  rw [he] at ha
  omega

/-- The side bit is a parity dot over the support of the ternary weight row.
It can use bitsets without reconstructing the signed ternary values. This is a
semantic equality, not a statement that computing the side bit is cheap. -/
theorem support_parity (ws xs : List Int)
    (hw : ∀ w ∈ ws, -1 ≤ w ∧ w ≤ 1) :
    dot ws xs % 2 = dot (ws.map fun w => if w = 0 then 0 else 1)
      (xs.map fun x => x%2) % 2 := by
  induction ws generalizing xs with
  | nil => simp [dot]
  | cons w ws ih =>
    cases xs with
    | nil => simp [dot]
    | cons x xs =>
      have hb := hw w (by simp)
      have ht := ih xs (by intro v hv; exact hw v (by simp [hv]))
      have hc : w = -1 ∨ w = 0 ∨ w = 1 := by omega
      rcases hc with rfl | rfl | rfl <;> simp only [List.map_cons, dot] at * <;>
        simp at * <;> omega

end Kelana.DeferredCarrier
