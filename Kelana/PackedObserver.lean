import Std

namespace Kelana.PackedObserver

/-- Three tightly radix-3 packed trits. No two-bit expansion is an intermediate. -/
def packed (a b c : Fin 3) : BitVec 32 :=
  BitVec.ofNat 32 (a.val + 3 * b.val + 9 * c.val)

def trit (a : Fin 3) : Int := (a.val : Int) - 1

def relu (x : Int) : Int := max x 0

/-- A five-hidden-unit gated ReLU network with ternary gate/up/down weights. -/
def network (x y z : Int) : Int :=
  relu (-x-y-z) * (x+y) - relu (-x-y) * (x+y) -
  relu (-x) * x + relu (-x+z) * y + relu (-x+y+z) * x

/-- Abstract bitvector meaning of the two assembled integer instructions:
    v_mad_u32_u24 v0, v0, 11, -13
    v_bfe_i32 v0, v0, 8, 2
    All input words are <= 26, so the 24-bit multiplicand truncation is inert. -/
def fused (word : BitVec 32) : Int :=
  (((word * 11 + BitVec.ofInt 32 (-13)) >>> 8).setWidth 2).toInt

/-- All 27 inputs, checked by kernel reduction rather than sampled tests. -/
theorem five_hidden_units_in_packed_coordinates :
    ∀ a b c : Fin 3,
      fused (packed a b c) = network (trit a) (trit b) (trit c) := by
  decide

/-- This observer distinguishes just the two codes at either end and the middle.
    It is a special network, not an implementation of arbitrary trained weights. -/
theorem observer_regions :
    ∀ a b c : Fin 3,
      fused (packed a b c) =
        if (packed a b c).toNat < 2 then -1
        else if (packed a b c).toNat > 24 then 1 else 0 := by
  decide

end Kelana.PackedObserver
