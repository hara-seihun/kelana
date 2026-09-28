import Kelana.Hardware.IntOps
import Std

namespace Kelana.TritObserver
open Kelana.Hardware

/-- Input trits use signed two-bit codes: -1→3, 0→0, 1→1. -/
def code (x : Fin 3) : Nat := if x.val = 0 then 3 else if x.val = 1 then 0 else 1

def inputWord (x y : Fin 3) : BitVec 32 := BitVec.ofNat 32 (code x + 4*code y)

def bytes (a b c d : BitVec 8) : BitVec 32 :=
  a.setWidth 32 ||| (b.setWidth 32 <<< 8) ||| (c.setWidth 32 <<< 16) ||| (d.setWidth 32 <<< 24)

/-- Operand words compiled from the complete observed function, not its layers. -/
def lower (f : Fin 3 → Fin 3 → BitVec 8) : BitVec 32 := bytes (f 0 0) (f 2 2) (f 1 2) (f 2 0)
def upper (f : Fin 3 → Fin 3 → BitVec 8) : BitVec 32 := bytes (f 0 2) (f 0 1) (f 2 1) (f 1 0)

/-- BFE turns the sparse two-trit code into a PERM selector. Selector 12 emits
zero in hardware; the other eight states biject to the eight operand bytes. -/
def run (f : Fin 3 → Fin 3 → BitVec 8) (x y : Fin 3) : Except Unmodeled (BitVec 8) := do
  let selector ← v_bfe_u32 {} 0x722c (inputWord x y) 4
  let result ← v_perm_b32 {} (upper f) (lower f) selector
  pure (result.setWidth 8)

theorem observer_compilation (f : Fin 3 → Fin 3 → BitVec 8) (hz : f 1 1 = 0) :
    ∀ x y, run f x y = .ok (f x y) := by
  intro x y
  have hx : x = 0 ∨ x = 1 ∨ x = 2 := by omega
  have hy : y = 0 ∨ y = 1 ∨ y = 2 := by omega
  rcases hx with rfl | rfl | rfl <;> rcases hy with rfl | rfl | rfl <;>
    simp [run, inputWord, code, v_bfe_u32, v_perm_b32, Vop3.noModifiers,
      Vop3.integerFields, shiftCount, upper, lower, byte32, bytePermute, bytes,
      Bind.bind, Pure.pure, Except.pure, Except.bind, hz] <;>
    (generalize f 0 0 = a, f 0 1 = b, f 0 2 = c,
      f 1 0 = d, f 1 2 = e, f 2 0 = g, f 2 1 = h, f 2 2 = i
     apply BitVec.eq_of_getElem_eq
     intro j hj
     simp only [BitVec.getElem_setWidth]
     have h7 : j ≤ 7 := by omega
     have h15 : j ≤ 15 := by omega
     have h23 : j ≤ 23 := by omega
     simp +arith (disch := omega) [h7, h15, h23])

end Kelana.TritObserver
