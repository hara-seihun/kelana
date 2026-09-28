import Std

namespace Kelana.TransportedPair

def rotate (c s x y : Int) : Int × Int := (c*x-s*y,s*x+c*y)
def dot (x y : Int × Int) : Int := x.1*y.1+x.2*y.2

theorem commute (a b c s : Int) (p : Int × Int) :
    rotate a b (rotate c s p.1 p.2).1 (rotate c s p.1 p.2).2 =
    rotate c s (rotate a b p.1 p.2).1 (rotate a b p.1 p.2).2 := by
  simp [rotate]
  constructor <;> simp only [Int.mul_add, Int.mul_sub, Int.mul_left_comm] <;> omega

/-- The exact pair score identity before the unit-circle specialization. -/
theorem score_rotate (c s : Int) (q k : Int × Int) :
    dot (rotate c s q.1 q.2) (rotate c s k.1 k.2) =
      (c*c+s*s) * dot q k := by
  simp only [dot, rotate, Int.mul_add, Int.mul_sub, Int.add_mul, Int.sub_mul,
    Int.mul_left_comm, Int.mul_assoc]
  omega

theorem unit_score (c s : Int) (unit : c*c+s*s=1) (q k : Int × Int) :
    dot (rotate c s q.1 q.2) (rotate c s k.1 k.2) = dot q k := by
  rw [score_rotate, unit, Int.one_mul]

end Kelana.TransportedPair
