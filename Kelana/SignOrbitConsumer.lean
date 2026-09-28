import Kelana.FiberRank

namespace Kelana.SignOrbitConsumer

open FiberRank

def flip : Trit → Trit
  | .neg => .pos
  | .zero => .zero
  | .pos => .neg

def digit : Trit → Nat
  | .neg => 0
  | .zero => 1
  | .pos => 2

def code : List Trit → Nat
  | [] => 0
  | t :: ts => digit t + 3 * code ts

theorem code_lt (w : List Trit) : code w < 3 ^ w.length := by
  induction w with
  | nil => simp [code]
  | cons t ts ih =>
      cases t <;> simp only [code, digit, List.length_cons, Nat.pow_succ] <;> omega

theorem code_flip (w : List Trit) :
    code (w.map flip) + code w + 1 = 3 ^ w.length := by
  induction w with
  | nil => simp [code]
  | cons t ts ih =>
      cases t <;> simp only [List.map_cons, flip, code, digit, List.length_cons, Nat.pow_succ] <;> omega

theorem response_flip (w : List Trit) (q : List Int) :
    response (w.map flip) q = -response w q := by
  induction w generalizing q with
  | nil => simp [response]
  | cons t ts ih =>
      cases q with
      | nil => simp [response]
      | cons a qs =>
          cases t <;> simp [List.map_cons, flip, response, Trit.value, ih] <;> omega

/-- A sign orbit uses the lower of two reflected table addresses. -/
def folded (n c : Nat) : Nat := min c (n - 1 - c)

def orientation (n c : Nat) : Int := if c ≤ n - 1 - c then 1 else -1

theorem folded_le_half (n c : Nat) (hn : 0 < n) (hc : c < n) :
    folded n c ≤ (n - 1) / 2 := by
  simp only [folded]
  have hd := Nat.mod_add_div (n - 1) 2
  have hm := Nat.mod_lt (n - 1) (by decide : 0 < 2)
  omega

/-- Any antisymmetric response table can be evaluated from one representative
per sign orbit. This is independent of how the table was generated. -/
theorem lookup_fold (n c : Nat) (table : Nat → Int)
    (hc : c < n) (symmetric : ∀ j, j < n → table (n - 1 - j) = -table j) :
    table c = orientation n c * table (folded n c) := by
  by_cases h : c ≤ n - 1 - c
  · simp [orientation, folded, h, Nat.min_eq_left h]
  · have hle : n - 1 - c ≤ c := by omega
    rw [orientation, if_neg h, folded, Nat.min_eq_right hle, symmetric c hc]
    omega

/-- Three ternary coordinates fit fourteen sign representatives. -/
theorem three_trit_table (c : Nat) (hc : c < 27) : folded 27 c < 14 := by
  have h := folded_le_half 27 c (by decide) hc
  omega

end Kelana.SignOrbitConsumer
