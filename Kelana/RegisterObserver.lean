import Kelana.Radix

namespace Kelana.RegisterObserver

structure Pair where
  w0 : Int
  w1 : Int
  x0 : Int
  x1 : Int

def value (p : Pair) : Int := p.w0*p.x0+p.w1*p.x1

def active (p : Pair) : Int := if p.w0=0 ∧ p.w1=0 then 0 else 1

/-- Zero-weight pairs use PERM's built-in zero. Every other pair receives a
constant 14 bias. Its eventual correction depends only on the fixed weights. -/
def encoded (p : Pair) : Int := value p+14*active p

def Valid (p : Pair) : Prop :=
  Kelana.Trit p.w0 ∧ Kelana.Trit p.w1 ∧
    -7 ≤ p.x0 ∧ p.x0 ≤ 7 ∧ -7 ≤ p.x1 ∧ p.x1 ≤ 7

theorem pair_range (p : Pair) (h : Valid p) : -14 ≤ value p ∧ value p ≤ 14 := by
  rcases h with ⟨hw0, hw1, hx0, hx0', hx1, hx1'⟩
  have h0 : p.w0 = -1 ∨ p.w0=0 ∨ p.w0=1 := by unfold Kelana.Trit at hw0; omega
  have h1 : p.w1 = -1 ∨ p.w1=0 ∨ p.w1=1 := by unfold Kelana.Trit at hw1; omega
  unfold value
  rcases h0 with h0 | h0 | h0 <;> rcases h1 with h1 | h1 | h1 <;> simp [h0,h1] <;> omega

theorem zero_slot (p : Pair) (h : p.w0=0 ∧ p.w1=0) : encoded p=0 := by
  simp [encoded, value, active, h.1, h.2]

theorem encoded_range (p : Pair) (h : Valid p) : 0 ≤ encoded p ∧ encoded p ≤ 28 := by
  have hr := pair_range p h
  by_cases hz : p.w0=0 ∧ p.w1=0
  · rw [zero_slot p hz]; omega
  · simp [encoded, active, hz]; omega

theorem offline_bias_correction (ps : List Pair) :
    (ps.map encoded).sum - 14*(ps.map active).sum = (ps.map value).sum := by
  induction ps with
  | nil => simp
  | cons p ps ih =>
    simp only [List.map_cons, List.sum_cons, encoded] at *
    omega

theorem sum_range (ps : List Pair) (h : ∀ p ∈ ps, Valid p) :
    0 ≤ (ps.map encoded).sum ∧ (ps.map encoded).sum ≤ 28*(ps.length : Int) := by
  induction ps with
  | nil => simp
  | cons p ps ih =>
    have hp := encoded_range p (h p (by simp))
    have hi := ih (fun q hq => h q (by simp [hq]))
    simp only [List.map_cons, List.sum_cons, List.length_cons, Int.natCast_add, Int.natCast_one]
    omega

theorem eight_pairs_fit_byte (ps : List Pair) (h : ∀ p ∈ ps, Valid p) (hn : ps.length ≤ 8) :
    0 ≤ (ps.map encoded).sum ∧ (ps.map encoded).sum ≤ 224 := by
  have hr := sum_range ps h
  omega

def pack4 (a b c d : Int) : Int := a+256*b+65536*c+16777216*d

/-- Four row sums remain separate under ordinary word addition while each digit
stays in a byte. This certifies carry freedom, not an issue-rate claim. -/
theorem four_byte_decode (a b c d : Int)
    (ha : 0 ≤ a ∧ a < 256) (hb : 0 ≤ b ∧ b < 256)
    (hc : 0 ≤ c ∧ c < 256) (hd : 0 ≤ d ∧ d < 256) :
    let p := pack4 a b c d
    0 ≤ p ∧ p < 4294967296 ∧ p%256=a ∧ (p/256)%256=b ∧
      (p/65536)%256=c ∧ p/16777216=d := by
  unfold pack4
  omega

theorem pack_add (a b c d e f g h : Int) :
    pack4 a b c d + pack4 e f g h = pack4 (a+e) (b+f) (c+g) (d+h) := by
  unfold pack4
  omega

end Kelana.RegisterObserver
