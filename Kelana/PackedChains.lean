import Std

namespace Kelana.PackedChains

abbrev Pair := Int × Int

def pack (radix : Int) (p : Pair) : Int := p.1 + radix * p.2

def sumPairs : List Pair → Pair
  | [] => (0, 0)
  | p :: ps => (p.1 + (sumPairs ps).1, p.2 + (sumPairs ps).2)

def rawSum (radix : Int) (ps : List Pair) : Int := (ps.map (pack radix)).sum

def decodeByte (word : Int) : Pair := (word % 16, (word % 256) / 16)

def packedRun (ps : List Pair) : Int := rawSum 16 ps % 256

def Digits (ps : List Pair) : Prop :=
  ∀ p ∈ ps, (0 ≤ p.1 ∧ p.1 ≤ 2) ∧ (0 ≤ p.2 ∧ p.2 ≤ 2)

/-- Arbitrarily many additions commute with packing over integers. It is decoding,
not this identity, that consumes a range budget. -/
theorem sum_commutes (radix : Int) (ps : List Pair) :
    rawSum radix ps = pack radix (sumPairs ps) := by
  induction ps with
  | nil => simp [rawSum, sumPairs, pack]
  | cons p ps ih =>
    simp only [rawSum, List.map_cons, List.sum_cons] at *
    rw [ih]
    simp only [pack, sumPairs]
    grind

theorem pair_bounds (ps : List Pair) (h : Digits ps) :
    (0 ≤ (sumPairs ps).1 ∧ (sumPairs ps).1 ≤ 2 * (ps.length : Int)) ∧
    (0 ≤ (sumPairs ps).2 ∧ (sumPairs ps).2 ≤ 2 * (ps.length : Int)) := by
  induction ps with
  | nil => simp [sumPairs]
  | cons p ps ih =>
    have hp := h p (by simp)
    have ht : Digits ps := by intro q hq; exact h q (by simp [hq])
    have hb := ih ht
    simp only [sumPairs, List.length_cons, Int.natCast_add, Int.natCast_one]
    omega

theorem byte_decode {x y : Int}
    (hx : 0 ≤ x ∧ x < 16) (hy : 0 ≤ y ∧ y < 16) :
    decodeByte ((x + 16*y) % 256) = (x,y) := by
  unfold decodeByte
  apply Prod.ext <;> dsimp <;> omega

theorem seven_stages_exact (ps : List Pair) (hd : Digits ps) (hn : ps.length ≤ 7) :
    decodeByte (packedRun ps) = sumPairs ps := by
  have hb := pair_bounds ps hd
  unfold packedRun
  rw [sum_commutes]
  unfold pack
  exact byte_decode (by omega) (by omega)

/-- Eight low-lane increments cause a cross-lane carry even though the entire
word is only 16, nowhere near overflow of its 8-bit storage. -/
theorem eighth_stage_counterexample :
    let ps : List Pair := List.replicate 8 (2,0)
    Digits ps ∧ decodeByte (packedRun ps) = (0,1) ∧ sumPairs ps = (16,0) := by
  constructor
  · intro p hp
    have : p = (2,0) := (List.mem_replicate.mp hp).2
    subst p
    decide
  · decide +kernel

theorem repeated_low_sum (n : Nat) :
    sumPairs (List.replicate n (2,0)) = (2 * (n : Int),0) := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [List.replicate_succ, sumPairs, ih, Int.natCast_add, Int.natCast_one]
    apply Prod.ext <;> dsimp <;> omega

def InitialBits (p : Pair) : Prop :=
  (0 ≤ p.1 ∧ p.1 ≤ 1) ∧ (0 ≤ p.2 ∧ p.2 ≤ 1)

def normalFrom (initial : Pair) (ps : List Pair) : Pair :=
  (initial.1 + (sumPairs ps).1, initial.2 + (sumPairs ps).2)

def packedFrom (initial : Pair) (ps : List Pair) : Int :=
  (pack 16 initial + rawSum 16 ps) % 256

theorem seven_stages_from_bits (initial : Pair) (ps : List Pair)
    (hi : InitialBits initial) (hd : Digits ps) (hn : ps.length ≤ 7) :
    decodeByte (packedFrom initial ps) = normalFrom initial ps := by
  have hb := pair_bounds ps hd
  unfold packedFrom normalFrom
  rw [sum_commutes]
  have he : pack 16 initial + pack 16 (sumPairs ps) =
      initial.1 + (sumPairs ps).1 + 16 * (initial.2 + (sumPairs ps).2) := by
    unfold pack
    omega
  rw [he]
  exact byte_decode (by unfold InitialBits at hi; omega) (by unfold InitialBits at hi; omega)

def UniversallySafe (n : Nat) : Prop :=
  ∀ initial, InitialBits initial → ∀ ps : List Pair, ps.length = n → Digits ps →
    decodeByte (packedFrom initial ps) = normalFrom initial ps

theorem input_encoding_nonconstant : pack 16 (0,0) ≠ pack 16 (1,0) := by decide

theorem capacity_iff (n : Nat) : UniversallySafe n ↔ n ≤ 7 := by
  constructor
  · intro safe
    let ps : List Pair := List.replicate n (2,0)
    have hd : Digits ps := by
      intro p hp
      have : p = (2,0) := (List.mem_replicate.mp hp).2
      subst p
      decide
    have he := safe (0,0) (by unfold InitialBits; decide) ps (by simp [ps]) hd
    have hs : sumPairs ps = (2 * (n : Int),0) := repeated_low_sum n
    have hl := congrArg Prod.fst he
    simp only [normalFrom, hs, Int.zero_add, decodeByte] at hl
    omega
  · intro hn initial hi ps hlen hd
    exact seven_stages_from_bits initial ps hi hd (by omega)

def ordinaryCost (n : Nat) : Nat := 2*n
/-- Synthetic gateway charges: enter 3, exit 3, packed stage 1.
These are declared abstract costs, not gfx1151 instruction timings. -/
def packedCost (n : Nat) : Nat := 3+n+3

theorem break_even (n : Nat) : packedCost n < ordinaryCost n ↔ 7 ≤ n := by
  unfold packedCost ordinaryCost
  omega

theorem no_shorter_win (n : Nat) (hn : n ≤ 6) : ordinaryCost n ≤ packedCost n := by
  unfold packedCost ordinaryCost
  omega

/-- Exactly seven stages are both profitable and universally safe in this
fixed encoding and cost model. Other encodings and staged conversions are open. -/
theorem profitable_window (n : Nat) :
    (UniversallySafe n ∧ packedCost n < ordinaryCost n) ↔ n = 7 := by
  rw [capacity_iff, break_even]
  omega

/-- Per-stage local profitability would reject the entry that the full chain uses. -/
theorem greedy_rejects_entry : (2 : Nat) < 3+1 := by decide

/-- More generally, a chain's aggregate savings must pay its two representation
boundaries. This separates the cost condition from semantic legality. -/
theorem gateway_break_even (entry exit perStage saving stages : Nat) :
    entry + stages * perStage + exit < stages * (perStage + saving) ↔
      entry + exit < stages * saving := by
  rw [Nat.mul_add]
  omega

#print axioms sum_commutes
#print axioms seven_stages_exact
#print axioms eighth_stage_counterexample
#print axioms profitable_window
end Kelana.PackedChains
