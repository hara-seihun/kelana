import Std

namespace Kelana.RestrictedTransfer

/-- A uniform energy bound on a legal family forces every legal calibration-null
error to be held-null, regardless of how that family was parameterized. -/
theorem legal_null_necessary {Error : Type} (legal : Error → Prop)
    (calibration held : Error → Nat) (factor : Nat)
    (bounded : ∀ e, legal e → held e ≤ factor * calibration e)
    (e : Error) (he : legal e) (zero : calibration e = 0) : held e = 0 := by
  have h := bounded e he
  simp [zero] at h
  omega

/-- A certificate on a containing linear family immediately certifies any
nonlinear subfamily without asserting the converse. -/
theorem restrict_bound {Error : Type} (wide narrow : Error → Prop)
    (calibration held : Error → Nat) (factor : Nat)
    (contains : ∀ e, narrow e → wide e)
    (bounded : ∀ e, wide e → held e ≤ factor * calibration e) :
    ∀ e, narrow e → held e ≤ factor * calibration e := by
  intro e he
  exact bounded e (contains e he)

/-- A two-parameter exact family avoids the ambient blind direction. -/
def calibration (e : Int × Int × Int) : Int :=
  e.1 * e.1 + e.2.2 * e.2.2

def held (e : Int × Int × Int) : Int :=
  (e.1 + e.2.1) * (e.1 + e.2.1) + (2 * e.2.2) * (2 * e.2.2)

def legal (a b : Int) : Int × Int × Int := (a,a,b)

theorem legal_exact (a b : Int) :
    held (legal a b) = 4 * calibration (legal a b) := by
  have square_four (x : Int) : x * (x * 4) = 4 * (x * x) := by
    calc
      x * (x * 4) = (x * x) * 4 := by rw [← Int.mul_assoc]
      _ = 4 * (x * x) := by rw [Int.mul_comm]
  simp only [held, calibration, legal]
  simp only [Int.add_mul, Int.mul_add]
  simp only [Int.mul_comm, Int.mul_left_comm, Int.mul_assoc]
  simp only [show (2 : Int) * 2 = 4 by decide, square_four]
  omega

theorem ambient_blind :
    calibration (0,1,0) = 0 ∧ held (0,1,0) = 1 := by
  decide

end Kelana.RestrictedTransfer
