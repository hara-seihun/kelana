import Std

namespace Kelana.EmbeddedAngle

/-- Canonical Q4 rows have negative origin and positive step. Three redundant
sign bits across a RoPE pair carry a three-bit angle label. -/
def store (bits : Bool × Bool × Bool) : Bool × Bool × Bool :=
  (!bits.1, bits.2.1, !bits.2.2)

def extract (signs : Bool × Bool × Bool) : Bool × Bool × Bool :=
  (!signs.1, signs.2.1, !signs.2.2)

theorem angle_roundtrip (bits : Bool × Bool × Bool) :
    extract (store bits) = bits := by
  cases bits with
  | mk a rest =>
    cases rest with
    | mk b c => cases a <;> cases b <;> cases c <;> rfl

theorem restored_scalar_signs (bits : Bool × Bool × Bool) :
    store (extract (store bits)) = store bits := by
  rw [angle_roundtrip]

end Kelana.EmbeddedAngle
