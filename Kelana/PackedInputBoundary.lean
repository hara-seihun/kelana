import Std

namespace Kelana.PackedInputBoundary

/-- Signed two-bit trit code: 0, +1, -1 are stored as 0, 1, 3. -/
def code (a : Fin 3) : Nat := if a.val = 2 then 3 else a.val

def packed (a b c : Fin 3) : Nat := code a + 4 * code b + 16 * code c

/-- Every nonzero six-bit XOR difference occurs between two valid packed words. -/
theorem all_nonzero_differences :
    ∀ d : Fin 64, d.val ≠ 0 →
      ∃ a b c a' b' c' : Fin 3,
        Nat.xor (packed a b c) (packed a' b' c') = d.val := by
  decide

end Kelana.PackedInputBoundary
