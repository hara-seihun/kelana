import Std

namespace Kelana.AttentionConsumer

/-- A per-RoPE-pair sign is a paid-description-free gauge when the Q and K
coordinate signs are changed together. The coefficients of the two rotations
may differ with the positions; no unit-circle assumption is needed. -/
def rotate (a b x y : Int) : Int × Int :=
  (a*x-b*y, b*x+a*y)

def pairScore (q k : Int × Int) : Int := q.1*k.1 + q.2*k.2

def signed (flip : Bool) (p : Int × Int) : Int × Int :=
  if flip then (-p.1, -p.2) else p

theorem rotate_signed (a b : Int) (flip : Bool) (p : Int × Int) :
    rotate a b (signed flip p).1 (signed flip p).2 =
      signed flip (rotate a b p.1 p.2) := by
  cases flip <;> simp [signed, rotate, Int.mul_neg] <;> omega

theorem score_signed (flip : Bool) (q k : Int × Int) :
    pairScore (signed flip q) (signed flip k) = pairScore q k := by
  cases flip <;> simp [signed, pairScore, Int.neg_mul, Int.mul_neg]

theorem rotated_score_signed (aq bq ak bk : Int)
    (flip : Bool) (q k : Int × Int) :
    pairScore (rotate aq bq (signed flip q).1 (signed flip q).2)
      (rotate ak bk (signed flip k).1 (signed flip k).2) =
    pairScore (rotate aq bq q.1 q.2) (rotate ak bk k.1 k.2) := by
  rw [rotate_signed, rotate_signed]
  exact score_signed flip _ _

/-- Whole heads add the independent pair scores. The same sign choice is
shared by query and key for each pair, but choices can vary across pairs. -/
def headScore : List (Bool × (Int × Int) × (Int × Int)) → Int
  | [] => 0
  | (_, q, k) :: rest => pairScore q k + headScore rest

def gauged : List (Bool × (Int × Int) × (Int × Int)) →
    List (Bool × (Int × Int) × (Int × Int)) :=
  List.map fun (flip, q, k) => (flip, signed flip q, signed flip k)

theorem head_score_gauge (pairs : List (Bool × (Int × Int) × (Int × Int))) :
    headScore (gauged pairs) = headScore pairs := by
  induction pairs with
  | nil => rfl
  | cons p rest ih =>
    obtain ⟨flip, q, k⟩ := p
    simp only [gauged, List.map_cons, headScore]
    rw [score_signed]
    simpa [gauged] using congrArg (pairScore q k + ·) ih

/-- A causal row's observable logit differences discard any common offset.
Softmax uses precisely this row-shift-invariant information on visible keys. -/
def centered : List Int → List Int
  | [] => []
  | first :: rest => (first :: rest).map (fun x => x-first)

theorem centered_shift (row : List Int) (offset : Int) :
    centered (row.map (fun x => x+offset)) = centered row := by
  cases row with
  | nil => rfl
  | cons first rest =>
    simp only [List.map_cons, centered, List.map_map]
    have firstEq : first + offset - (first + offset) = first - first := by omega
    rw [firstEq]
    congr 1
    apply List.map_congr_left
    intro x hx
    simp only [Function.comp_apply]
    omega

/-- A consumer that only sees centered visible logits inherits row-offset
invariance; real softmax is one such consumer via cancellation of exp(offset). -/
theorem centered_observer_shift {Y : Type} (consume : List Int → Y)
    (row : List Int) (offset : Int) :
    consume (centered (row.map (fun x => x + offset))) =
      consume (centered row) := by
  rw [centered_shift]

/-- One-dimensional normal-equation identity; the finite multivariate
weighted-score calculation uses the same bilinear expansion with a Gram
matrix. The hypothesis names the stationary point, not a numerical solver. -/
def quadratic (a b c x : Int) : Int := a*x*x - 2*b*x + c

theorem quadratic_stationary_identity (a b c x x0 : Int)
    (stationary : a*x0 = b) :
    quadratic a b c x = quadratic a b c x0 + a*(x-x0)*(x-x0) := by
  simp only [quadratic]
  rw [←stationary]
  simp only [Int.mul_sub, Int.sub_mul, Int.mul_assoc]
  have swap : a * (x0 * x) = a * (x * x0) := by rw [Int.mul_comm x0 x]
  omega

end Kelana.AttentionConsumer
