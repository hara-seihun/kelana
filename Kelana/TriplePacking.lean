import Kelana.PairedWMMA

namespace Kelana.TriplePacking
open PairedWMMA

abbrev Triple := Int × Int × Int

def pack (a b c : Int) : Int := a + 33*b + 1089*c
def top (p : Int) : Int := (p+544)/1089
def middle (p : Int) : Int := (p-1089*top p+16)/33
def bottom (p : Int) : Int := p-1089*top p-33*middle p

theorem decode {a b c : Int}
    (ha : -16 ≤ a ∧ a ≤ 16) (hb : -16 ≤ b ∧ b ≤ 16) :
    bottom (pack a b c) = a ∧ middle (pack a b c) = b ∧ top (pack a b c) = c := by
  unfold bottom middle top pack
  omega

theorem operand_bound {a b c : Int}
    (ha : -1 ≤ a ∧ a ≤ 1) (hb : -1 ≤ b ∧ b ≤ 1) (hc : -1 ≤ c ∧ c ≤ 1) :
    -1123 ≤ pack a b c ∧ pack a b c ≤ 1123 := by
  unfold pack
  omega

theorem accumulator_bound {a b c : Int}
    (ha : -16 ≤ a ∧ a ≤ 16) (hb : -16 ≤ b ∧ b ≤ 16) (hc : -16 ≤ c ∧ c ≤ 16) :
    -17968 ≤ pack a b c ∧ pack a b c ≤ 17968 := by
  unfold pack
  omega

def weights (ws : List Triple) : List Int := ws.map fun w => pack w.1 w.2.1 w.2.2

theorem dot_pack (ws : List Triple) (xs : List Int) :
    dot (weights ws) xs =
    pack (dot (ws.map fun w => w.1) xs)
         (dot (ws.map fun w => w.2.1) xs)
         (dot (ws.map fun w => w.2.2) xs) := by
  induction ws generalizing xs with
  | nil => simp [weights, dot, pack]
  | cons w ws ih =>
    cases xs with
    | nil => simp [weights, dot, pack]
    | cons x xs =>
      have h := ih xs
      simp only [weights, List.map_cons, dot] at *
      unfold pack at *
      grind (ematch := 0)

theorem dot_decodes (ws : List Triple) (xs : List Int)
    (ha : ∀ w ∈ ws, -1 ≤ w.1 ∧ w.1 ≤ 1)
    (hb : ∀ w ∈ ws, -1 ≤ w.2.1 ∧ w.2.1 ≤ 1)
    (hx : l1 xs ≤ 16) :
    bottom (dot (weights ws) xs) = dot (ws.map fun w => w.1) xs ∧
    middle (dot (weights ws) xs) = dot (ws.map fun w => w.2.1) xs ∧
    top (dot (weights ws) xs) = dot (ws.map fun w => w.2.2) xs := by
  have ba := dot_bound (ws.map fun w => w.1) xs (by
    intro a h
    obtain ⟨w, hw, rfl⟩ := List.mem_map.mp h
    exact ha w hw)
  have bb := dot_bound (ws.map fun w => w.2.1) xs (by
    intro b h
    obtain ⟨w, hw, rfl⟩ := List.mem_map.mp h
    exact hb w hw)
  rw [dot_pack]
  apply decode <;> omega

def widePack (a b c : Int) : Int := a+60*b+1987*c
def wideTop (p : Int) : Int := (p+993)/1987
def wideMiddle (p : Int) : Int := (p-1987*wideTop p+30)/60

theorem wide_operand_bound {a b c : Int}
    (ha : -1 ≤ a ∧ a ≤ 1) (hb : -1 ≤ b ∧ b ≤ 1) (hc : -1 ≤ c ∧ c ≤ 1) :
    -2048 ≤ widePack a b c ∧ widePack a b c ≤ 2048 := by
  unfold widePack
  omega

-- Upper channels tolerate these integer perturbations. The remaining low
-- channel is a+e, NOT a; separation margin is not exact-recovery tolerance.
theorem wide_separates {a b c e : Int}
    (ha : -16 ≤ a ∧ a ≤ 16) (hb : -16 ≤ b ∧ b ≤ 16)
    (he : -13 ≤ e ∧ e ≤ 13) :
    wideTop (widePack a b c+e) = c ∧
    wideMiddle (widePack a b c+e) = b ∧
    widePack a b c+e-1987*c-60*b = a+e := by
  have ht : wideTop (widePack a b c+e) = c := by
    unfold wideTop widePack
    omega
  refine ⟨ht, ?_, ?_⟩
  · unfold wideMiddle
    rw [ht]
    unfold widePack
    omega
  · unfold widePack
    omega

-- Twice the smallest top-down separation margin for [1,b,c] is bounded
-- by 28 when every operand fits the consecutive integer range of FP16.
theorem wide_margin_upper_bound (b c : Int) (h : 1+b+c ≤ 2048) :
    min (b-32) (c-32*(1+b)) ≤ 28 := by omega

theorem wide_margin_attained :
    min ((60:Int)-32) (1987-32*(1+60)) = 28 ∧ 1+60+1987 = (2048:Int) := by decide

-- Integer semantics only. Native F16 WMMA and its rounding/decode sequence
-- require their own error bound. This theorem does not assert their exactness.
end Kelana.TriplePacking
