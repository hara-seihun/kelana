import Std

namespace Kelana.CoupledGaugeCost

/-- Finite rational sums; no probabilistic or exponential machinery. -/
def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_sub (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i - g i) = total xs f - total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a*f i) = a*total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul_right (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i*a) = total xs f*a := by
  calc
    _ = total xs (fun i => a*f i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = a*total xs f := total_mul xs a f
    _ = _ := Rat.mul_comm _ _

private theorem total_comm (xs : List I) (ys : List J) (f : I → J → Rat) :
    total xs (fun i => total ys (f i)) =
      total ys (fun j => total xs (fun i => f i j)) := by
  induction xs with
  | nil =>
    simp only [total, List.map_nil, List.sum_nil]
    induction ys with
    | nil => rfl
    | cons j ys ih => simp only [List.map_cons, List.sum_cons]; grind
  | cons i xs ih =>
    change total ys (f i) + total xs (fun k => total ys (f k)) =
      total ys (fun j => f i j + total xs (fun k => f k j))
    rw [ih, total_add]

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    change f i + total xs f ≤ g i + total xs g
    grind [ih ht]

/-- The weighted context product retains *every* cross-pair coefficient;
    forming a diagonal approximation would change the actual objective. -/
def coupling (contexts : List S) (μ : S → Rat)
    (qEnergy kEnergy : S → A → Rat) (a b : A) : Rat :=
  total contexts (fun s => μ s*qEnergy s a*kEnergy s b)

def contextCost (contexts : List S) (pairs : List A)
    (μ : S → Rat) (qEnergy kEnergy : S → A → Rat)
    (u v : A → Rat) : Rat :=
  total contexts (fun s => μ s *
    (total pairs (fun a => qEnergy s a*u a) *
     total pairs (fun b => kEnergy s b*v b)))

/-- Exact finite weighted norm-product assembly, derived by distributing
    actual finite sums and commuting context/pair order. -/
theorem context_cost_eq_coupling (contexts : List S) (pairs : List A)
    (μ : S → Rat) (qEnergy kEnergy : S → A → Rat)
    (u v : A → Rat) :
    contextCost contexts pairs μ qEnergy kEnergy u v =
      total pairs (fun a => total pairs (fun b =>
        coupling contexts μ qEnergy kEnergy a b*u a*v b)) := by
  unfold contextCost
  calc
    _ = total contexts (fun s => μ s *
        total pairs (fun a => total pairs (fun b =>
          (qEnergy s a*u a)*(kEnergy s b*v b)))) := by
      apply total_congr contexts
      intro s hs
      congr 1
      calc
        _ = total pairs (fun a =>
            (qEnergy s a*u a)*total pairs (fun b => kEnergy s b*v b)) :=
          (total_mul_right pairs _ _).symm
        _ = _ := by
          apply total_congr pairs
          intro a ha
          exact (total_mul pairs _ _).symm
    _ = total pairs (fun a => total contexts (fun s => μ s *
        total pairs (fun b => (qEnergy s a*u a)*(kEnergy s b*v b)))) := by
      calc
        _ = total contexts (fun s => total pairs (fun a => μ s *
            total pairs (fun b => (qEnergy s a*u a)*(kEnergy s b*v b)))) := by
          apply total_congr contexts
          intro s hs
          exact (total_mul pairs (μ s) _).symm
        _ = _ := total_comm contexts pairs _
    _ = total pairs (fun a => total pairs (fun b =>
        total contexts (fun s => μ s *
          ((qEnergy s a*u a)*(kEnergy s b*v b))))) := by
      apply total_congr pairs
      intro a ha
      calc
        _ = total contexts (fun s => total pairs (fun b => μ s *
            ((qEnergy s a*u a)*(kEnergy s b*v b)))) := by
          apply total_congr contexts
          intro s hs
          exact (total_mul pairs (μ s) _).symm
        _ = _ := total_comm contexts pairs _
    _ = _ := by
      apply total_congr pairs
      intro a ha
      apply total_congr pairs
      intro b hb
      calc
        _ = total contexts (fun s =>
            (u a*v b)*(μ s*qEnergy s a*kEnergy s b)) := by
          apply total_congr contexts
          intro s hs
          grind +ring
        _ = (u a*v b)*coupling contexts μ qEnergy kEnergy a b := by
          rw [total_mul]
          rfl
        _ = _ := by grind +ring

/-- Row and column masses of a finite transport/flow matrix. -/
def rowMass (pairs : List A) (B : A → A → Rat) (a : A) : Rat :=
  total pairs (fun b => B a b)

def columnMass (pairs : List A) (B : A → A → Rat) (b : A) : Rat :=
  total pairs (fun a => B a b)

def flowCost (pairs : List A) (B R : A → A → Rat) : Rat :=
  total pairs (fun a => total pairs (fun b => B a b*R a b))

def flowMass (pairs : List A) (B : A → A → Rat) : Rat :=
  total pairs (fun a => rowMass pairs B a)

/-- Affine edge costs preserve the actual finite flow mass. -/
theorem flowCost_const_sub (pairs : List A) (B R : A → A → Rat) (c : Rat) :
    flowCost pairs B (fun a b => c - R a b) =
      c * flowMass pairs B - flowCost pairs B R := by
  unfold flowCost flowMass rowMass
  calc
    _ = total pairs (fun a =>
        c * total pairs (fun b => B a b) -
          total pairs (fun b => B a b * R a b)) := by
      apply total_congr pairs
      intro a ha
      calc
        _ = total pairs (fun b => c * B a b - B a b * R a b) := by
          apply total_congr pairs
          intro b hb
          grind +ring
        _ = _ := by rw [total_sub, total_mul]
    _ = _ := by rw [total_sub, total_mul]

/-- The potential terms telescope precisely when weighted row and column
    sums match, not merely when B is symmetric or has equal total mass. -/
theorem balanced_potential_zero (pairs : List A) (B : A → A → Rat)
    (z : A → Rat)
    (hbalance : ∀ a ∈ pairs,
      rowMass pairs B a = columnMass pairs B a) :
    total pairs (fun a => total pairs (fun b => B a b*(z a-z b))) = 0 := by
  calc
    _ = total pairs (fun a => z a*rowMass pairs B a -
        total pairs (fun b => B a b*z b)) := by
      apply total_congr pairs
      intro a ha
      calc
        _ = total pairs (fun b => z a*B a b - B a b*z b) := by
          apply total_congr pairs
          intro b hb
          grind +ring
        _ = z a*total pairs (fun b => B a b) -
            total pairs (fun b => B a b*z b) := by
          rw [total_sub, total_mul]
        _ = _ := rfl
    _ = total pairs (fun a => z a*rowMass pairs B a) -
        total pairs (fun a => total pairs (fun b => B a b*z b)) :=
      total_sub _ _ _
    _ = total pairs (fun a => z a*rowMass pairs B a) -
        total pairs (fun b => z b*columnMass pairs B b) := by
      rw [total_comm pairs pairs (fun a b => B a b*z b)]
      apply congrArg (fun x : Rat =>
        total pairs (fun a => z a*rowMass pairs B a)-x)
      apply total_congr pairs
      intro b hb
      unfold columnMass
      calc
        _ = (total pairs (fun a => B a b))*z b :=
          total_mul_right pairs (fun a => B a b) (z b)
        _ = _ := Rat.mul_comm _ _
    _ = 0 := by
      have hsame : total pairs (fun a => z a*rowMass pairs B a) =
          total pairs (fun a => z a*columnMass pairs B a) := by
        apply total_congr pairs
        intro a ha
        rw [hbalance a ha]
      rw [hsame]
      grind

/-- Balanced flow supporting certificate. The only pointwise comparison is
    R_ab≥1+z_a−z_b; nonnegative B preserves it and the potential sum cancels
    *exactly once*. No exponential/logarithm or optimizer existence is used. -/
theorem balanced_flow_support (pairs : List A)
    (B R : A → A → Rat) (z : A → Rat)
    (hB : ∀ a ∈ pairs, ∀ b ∈ pairs, 0 ≤ B a b)
    (hbalance : ∀ a ∈ pairs,
      rowMass pairs B a = columnMass pairs B a)
    (hsupport : ∀ a ∈ pairs, ∀ b ∈ pairs,
      1+z a-z b ≤ R a b) :
    flowMass pairs B ≤ flowCost pairs B R := by
  have hlow : flowMass pairs B ≤
      total pairs (fun a => total pairs (fun b =>
        B a b*(1+z a-z b))) := by
    have heq : total pairs (fun a => total pairs (fun b =>
        B a b*(1+z a-z b))) = flowMass pairs B := by
      calc
        _ = total pairs (fun a =>
            rowMass pairs B a +
            total pairs (fun b => B a b*(z a-z b))) := by
          apply total_congr pairs
          intro a ha
          calc
            _ = total pairs (fun b => B a b+B a b*(z a-z b)) := by
              apply total_congr pairs
              intro b hb
              grind +ring
            _ = _ := by rw [total_add]; rfl
        _ = flowMass pairs B +
            total pairs (fun a => total pairs (fun b => B a b*(z a-z b))) :=
          total_add _ _ _
        _ = _ := by rw [balanced_potential_zero pairs B z hbalance]; grind
    rw [heq]
    exact Rat.le_refl
  exact Rat.le_trans hlow (by
    unfold flowCost
    apply total_le pairs
      (fun a => total pairs (fun b => B a b*(1+z a-z b)))
      (fun a => total pairs (fun b => B a b*R a b))
    intro a ha
    apply total_le pairs
      (fun b => B a b*(1+z a-z b))
      (fun b => B a b*R a b)
    intro b hb
    exact Rat.mul_le_mul_of_nonneg_left (hsupport a ha b hb) (hB a ha b hb))

end Kelana.CoupledGaugeCost
