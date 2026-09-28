import Std

/-!
The algebraic constraint imposed by one signed-pair input carrier. The
covariance-weighted projection identity and numerical eigenvalue bounds in
README.md are paper arguments, not formalized here.
-/
namespace Kelana.InputPrograms.PairConstraints

/-- One signed addition supplies a single scalar to the readout. -/
def carrier (sign inputI inputJ : Int) : Int := inputI + sign * inputJ

/-- The readout coefficient of the second input is fixed by the first. -/
theorem coefficients (sign readout : Int) :
    readout * carrier sign inputI inputJ =
      readout * inputI + (readout * sign) * inputJ := by
  simp [carrier, Int.mul_add, Int.mul_assoc]

/-- With sign square one, the signed column difference vanishes. -/
theorem signedDifference (sign readout : Int) (hs : sign * sign = 1) :
    readout - sign * (readout * sign) = 0 := by
  calc
    readout - sign * (readout * sign) = readout - readout * (sign * sign) := by
      simp [Int.mul_comm, Int.mul_left_comm]
    _ = 0 := by simp [hs]

end Kelana.InputPrograms.PairConstraints
