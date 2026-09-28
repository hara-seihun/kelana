import Std

namespace Kelana.ScaledTrit
open Lean.Grind

/-- Stored ternary code 0=-1, 1=0, 2=+1. Sign and zero selection constructs the
scaled FP16 operand bits without a floating multiplication. -/
def operandBits (scale : BitVec 16) (code : Fin 3) : BitVec 16 :=
  let c := BitVec.ofNat 16 code.val
  let nz := (~~~c) &&& 1
  let sign := ((~~~(c >>> 1)) &&& 1) <<< 15
  (scale ^^^ sign) &&& (0-nz)

theorem negative_operand (s : BitVec 16) : operandBits s 0 = s ^^^ 0x8000 := by
  simp [operandBits]
  exact BitVec.and_allOnes

theorem zero_operand (s : BitVec 16) : operandBits s 1 = 0 := by
  simp [operandBits]

theorem positive_operand (s : BitVec 16) : operandBits s 2 = s := by
  simp [operandBits]
  exact BitVec.and_allOnes

/-- Sign-bit construction specifies bits, not WMMA arithmetic or NaN handling.
The caller uses finite FP16 scales; flipping their sign is the exact negative. -/
theorem scaled_operand (s : BitVec 16) (c : Fin 3) :
    operandBits s c = if c=0 then s ^^^ 0x8000 else if c=1 then 0 else s := by
  have hc : c=0 ∨ c=1 ∨ c=2 := by omega
  rcases hc with rfl | rfl | rfl <;>
    simp [negative_operand, zero_operand, positive_operand]

variable {R : Type} [CommRing R]

def block (weights activations : List R) : R :=
  ((weights.zip activations).map fun p => p.1*p.2).sum

/-- Exact algebra behind removing the per-block scale epilogue. The two sides
may have different floating execution, which is not covered by this theorem. -/
theorem absorb_block_scales (weights activations : List R) (ws xs : R) :
    block (weights.map (fun w => ws*w)) (activations.map (fun x => xs*x)) =
      (ws*xs)*block weights activations := by
  induction weights generalizing activations with
  | nil => simp [block]; grind
  | cons w weights ih =>
    cases activations with
    | nil => simp [block]; grind
    | cons x activations =>
      have h := ih activations
      simp only [block, List.map_cons, List.zip_cons_cons, List.sum_cons] at *
      grind

/-- A whole projection needs no per-block scaled accumulator in its ideal map.
This keeps block-specific scales, rather than replacing them by a shared scale. -/
theorem absorb_projection (blocks : List (R × R × List R × List R)) :
    (blocks.map fun b => block (b.2.2.1.map (fun w => b.1*w))
      (b.2.2.2.map (fun x => b.2.1*x))).sum =
    (blocks.map fun b => (b.1*b.2.1)*block b.2.2.1 b.2.2.2).sum := by
  simp only [absorb_block_scales]

end Kelana.ScaledTrit
