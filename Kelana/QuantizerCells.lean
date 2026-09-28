import Std

namespace Kelana.QuantizerCells

/-- Exact rational nearest-integer rounding, with ties to even; denominator must be positive. -/
def roundEven (n m : Int) : Int :=
  let q := (2 * n + m) / (2 * m)
  if 2 * n = (2 * q - 1) * m ∧ q % 2 ≠ 0 then q - 1 else q

/-- Strict cells deliberately exclude ties. This is a sufficient certificate, not an exhaustive one. -/
def InCell (m n q : Int) : Prop :=
  0 < m ∧ (2 * q - 1) * m < 2 * n ∧ 2 * n < (2 * q + 1) * m

theorem cell_floor {m n q : Int} (h : InCell m n q) :
    (2 * n + m) / (2 * m) = q := by
  rcases h with ⟨hm, hl, hu⟩
  apply (Int.ediv_eq_iff_of_pos (by omega : 0 < 2 * m)).2
  constructor <;> grind

theorem cell_round {m n q : Int} (h : InCell m n q) :
    roundEven n m = q := by
  unfold roundEven
  rw [cell_floor h]
  have hn : ¬ (2 * n = (2 * q - 1) * m ∧ q % 2 ≠ 0) := by
    intro he
    have := h.2.1
    omega
  simp [hn]

/-- The expensive exact numerator need not be evaluated if its interval lies in one cell. -/
theorem interval_round {m n e actual q : Int}
    (hm : 0 < m)
    (hl : (2 * q - 1) * m < 2 * (n - e))
    (hu : 2 * (n + e) < (2 * q + 1) * m)
    (ha : n - e ≤ actual ∧ actual ≤ n + e) :
    roundEven actual m = q := by
  apply cell_round
  exact ⟨hm, by omega, by omega⟩

def ScaleWitness {ι : Type} (v : ι → Int) (m : Int) : Prop :=
  0 < m ∧ (∀ i, -m ≤ v i ∧ v i ≤ m) ∧ ∃ i, v i = m ∨ v i = -m

theorem scale_unique {ι : Type} {v : ι → Int} {m k : Int}
    (hm : ScaleWitness v m) (hk : ScaleWitness v k) : m = k := by
  rcases hm with ⟨_, bm, i, hi⟩
  rcases hk with ⟨_, bk, j, hj⟩
  have := bm j
  have := bk i
  rcases hi with hi | hi <;> rcases hj with hj | hj <;> omega

def Encodes {ι : Type} (v : ι → Int) (m : Int) (q : ι → Int) : Prop :=
  ScaleWitness v m ∧ ∀ i, roundEven (127 * v i) m = q i

/-- A joint perturbation can alter every source coordinate while retaining scale and codes. -/
theorem interval_encoding {ι : Type} {v center error q : ι → Int} {m : Int}
    (hm : ScaleWitness v m)
    (hl : ∀ i, (2 * q i - 1) * m < 2 * (center i - error i))
    (hu : ∀ i, 2 * (center i + error i) < (2 * q i + 1) * m)
    (hb : ∀ i, center i - error i ≤ 127 * v i ∧ 127 * v i ≤ center i + error i) :
    Encodes v m q := by
  exact ⟨hm, fun i => interval_round hm.1 (hl i) (hu i) (hb i)⟩

/-- Same integer code does not imply the same decoded value: the scale remains observable. -/
example : roundEven 127 1 = roundEven 254 2 ∧ (1 : Int) ≠ 2 := by decide +kernel

#print axioms cell_round
#print axioms interval_round
#print axioms scale_unique
#print axioms interval_encoding

end Kelana.QuantizerCells
