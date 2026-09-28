import Std

namespace Kelana.ProducerAlgebras

private def sum (f : α → Int) : List α → Int
  | [] => 0
  | x :: xs => f x + sum f xs

private def cross (f g : α → Int) : List α → Int
  | [] => 0
  | x :: xs => f x * g x + cross f g xs

private def pairs (f g : α → Int) : List α → Int
  | [] => 0
  | x :: xs => pairs f g xs + sum (fun y => (f x - f y) * (g x - g y)) xs

private theorem sum_differences (f g : α → Int) (x : α) (xs : List α) :
    sum (fun y => (f x - f y) * (g x - g y)) xs =
      (xs.length : Int) * f x * g x - f x * sum g xs -
        g x * sum f xs + cross f g xs := by
  induction xs with
  | nil => simp [sum, cross]
  | cons y ys ih =>
      simp only [sum, cross, List.length_cons, Int.natCast_add, Int.natCast_one, Int.add_mul]
      rw [ih]
      simp only [Int.mul_add, Int.mul_sub,
        Int.mul_comm, Int.mul_left_comm, Int.mul_one]
      omega

/-- The exact pairwise-difference certificate for every finite producer fiber.
It detects product-continuation error from the two branch responses without
approximating or snapping any gate. Dividing by the square of the fiber size
gives the familiar conditional covariance. -/
theorem covariance_pairwise (f g : α → Int) (xs : List α) :
    (xs.length : Int) * cross f g xs - sum f xs * sum g xs =
      pairs f g xs := by
  induction xs with
  | nil => simp [sum, cross, pairs]
  | cons x rest ih =>
      simp only [sum, cross, pairs, List.length_cons, Int.natCast_add, Int.natCast_one, Int.add_mul]
      rw [sum_differences, ← ih]
      simp only [Int.mul_add, Int.one_mul,
        Int.mul_assoc, Int.mul_comm, Int.mul_left_comm, Int.mul_one]
      omega

end Kelana.ProducerAlgebras
