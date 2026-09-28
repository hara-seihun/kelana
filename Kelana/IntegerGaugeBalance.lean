import Kelana.CoupledGaugeCost

namespace Kelana.IntegerGaugeBalance

open CoupledGaugeCost (total rowMass columnMass balanced_potential_zero)

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_sub (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i - g i) = total xs f - total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    change f i + total xs f ≤ g i + total xs g
    grind [ih ht]

/-- Integer positive-exponent tangent inequality, proved by induction
    rather than assumed as an analytic exponential convexity property. -/
theorem four_pow_nat_lower (n : Nat) :
    1 + 3*(n:Rat) ≤ (4:Rat)^n := by
  induction n with
  | zero => decide +kernel
  | succ n ih =>
    have hn : (0:Rat) ≤ n := Rat.natCast_nonneg
    have hmul := Rat.mul_le_mul_of_nonneg_left ih (by decide : (0:Rat) ≤ 4)
    rw [Rat.pow_succ]
    simp only [Rat.natCast_add]
    grind +ring

/-- One exact slope supports every nonnegative integer gauge difference. -/
theorem four_pow_nonnegative (k : Int) (hk : 0 ≤ k) :
    (3:Rat)*(k:Rat) ≤ (4:Rat)^k - 1 := by
  obtain ⟨n, rfl⟩ := Int.eq_ofNat_of_zero_le hk
  rw [Rat.zpow_natCast]
  have h := four_pow_nat_lower n
  simp only [Rat.intCast_natCast]
  grind

/-- The reverse-side slope is 3/4: at k=-1 equality holds. For k≤-2
    the right-hand side is at most -3/2 whereas 4^k-1>-1. -/
theorem four_pow_nonpositive (k : Int) (hk : k ≤ 0) :
    (3/4:Rat)*(k:Rat) ≤ (4:Rat)^k - 1 := by
  by_cases hz : k = 0
  · subst k
    simp
    grind
  have hneg : k < 0 := by omega
  obtain ⟨n, hn⟩ := Int.eq_negSucc_of_lt_zero hneg
  subst k
  cases n with
  | zero =>
    have hpow : (4:Rat)^(Int.negSucc 0) = 1/4 := by
      simp only [Int.negSucc_eq, Rat.zpow_neg]
      decide +kernel
    rw [hpow]
    grind +ring
  | succ n =>
    have hpow : 0 < (4:Rat)^Int.negSucc (n+1) :=
      Rat.zpow_pos (by decide)
    have hlarge : (1:Rat) ≤ (3/4:Rat)*((n+2:Nat):Rat) := by
      have hnn : (0:Rat) ≤ n := Rat.natCast_nonneg
      simp only [Rat.natCast_add] at *
      grind +ring
    have hcast : ((Int.negSucc (n+1):Int):Rat) =
        -(((n+2:Nat):Rat)) := by norm_cast
    rw [hcast]
    grind +ring

/-- The exact discrete one-edge supporting inequality. The band on f
    reverses roles for negative integer changes. -/
theorem edge_support (B f : Rat) (k : Int)
    (hB : 0 ≤ B) (hlo : (3/4:Rat)*B ≤ f)
    (hhi : f ≤ 3*B) :
    f*(k:Rat) ≤ B*((4:Rat)^k-1) := by
  by_cases hk : 0 ≤ k
  · have hkr : (0:Rat) ≤ (k:Rat) := Rat.intCast_le_intCast.mpr hk
    have hpower := four_pow_nonnegative k hk
    have hm1 := Rat.mul_le_mul_of_nonneg_left hpower hB
    have hm2 := Rat.mul_le_mul_of_nonneg_right hhi hkr
    grind +ring
  · have hk' : k ≤ 0 := by omega
    have hkr : (k:Rat) ≤ 0 := Rat.intCast_le_intCast.mpr hk'
    have hpos : (0:Rat) ≤ -(k:Rat) := by grind
    have hpower := four_pow_nonpositive k hk'
    have hm1 := Rat.mul_le_mul_of_nonneg_left hpower hB
    have hm2 := Rat.mul_le_mul_of_nonneg_right hlo hpos
    grind +ring

def cost (nodes : List A) (C : A → A → Rat) (e : A → Int) : Rat :=
  total nodes (fun a => total nodes (fun b =>
    C a b*((4:Rat)^(e a-e b))))

def scaledEdge (C : A → A → Rat) (e : A → Int) (a b : A) : Rat :=
  C a b*((4:Rat)^(e a-e b))

/-- Discrete exponent difference is exactly a multiplicative edge update;
    this is the bridge from the finite flow certificate to the actual F(e). -/
theorem exponent_update (C : A → A → Rat)
    (e next : A → Int) (a b : A) :
    C a b*((4:Rat)^(next a-next b)) =
      scaledEdge C e a b *
        ((4:Rat)^((next a-e a)-(next b-e b))) := by
  have heq : next a-next b =
      (e a-e b)+((next a-e a)-(next b-e b)) := by omega
  rw [heq, Rat.zpow_add (by decide : (4:Rat) ≠ 0)]
  unfold scaledEdge
  exact (Rat.mul_assoc _ _ _).symm

/-- A balanced flow inside the exact edge band certifies global
    optimality over *all* integer exponent vectors, not merely one-step
    coordinate descent. -/
theorem balanced_flow_global_optimal (nodes : List A)
    (C f : A → A → Rat) (e : A → Int)
    (hC : ∀ a ∈ nodes, ∀ b ∈ nodes, 0 ≤ C a b)
    (hlo : ∀ a ∈ nodes, ∀ b ∈ nodes,
      (3/4:Rat)*scaledEdge C e a b ≤ f a b)
    (hhi : ∀ a ∈ nodes, ∀ b ∈ nodes,
      f a b ≤ 3*scaledEdge C e a b)
    (hbalance : ∀ a ∈ nodes,
      rowMass nodes f a = columnMass nodes f a)
    (next : A → Int) :
    cost nodes C e ≤ cost nodes C next := by
  let shift : A → Int := fun a => next a-e a
  have hshift : ∀ a b, (next a-e a)-(next b-e b) =
      shift a-shift b := by intros; rfl
  have hdiff : cost nodes C next - cost nodes C e =
      total nodes (fun a => total nodes (fun b =>
        scaledEdge C e a b * ((4:Rat)^(shift a-shift b)-1))) := by
    unfold cost
    rw [← total_sub]
    apply total_congr nodes
    intro a ha
    rw [← total_sub]
    apply total_congr nodes
    intro b hb
    rw [exponent_update C e next a b]
    change scaledEdge C e a b *
      ((4:Rat)^(shift a-shift b)) - scaledEdge C e a b = _
    grind +ring
  have hbound : total nodes (fun a => total nodes (fun b =>
      f a b * ((shift a-shift b):Rat))) ≤
      total nodes (fun a => total nodes (fun b =>
        scaledEdge C e a b*((4:Rat)^(shift a-shift b)-1))) := by
    apply total_le nodes
      (fun a => total nodes (fun b => f a b*((shift a-shift b):Rat)))
      (fun a => total nodes (fun b =>
        scaledEdge C e a b*((4:Rat)^(shift a-shift b)-1)))
    intro a ha
    apply total_le nodes
      (fun b => f a b*((shift a-shift b):Rat))
      (fun b => scaledEdge C e a b*((4:Rat)^(shift a-shift b)-1))
    intro b hb
    have hB : 0 ≤ scaledEdge C e a b :=
      Rat.mul_nonneg (hC a ha b hb) (Rat.le_of_lt
        (Rat.zpow_pos (by decide)))
    simpa only [Rat.intCast_sub] using
      (edge_support (scaledEdge C e a b) (f a b)
        (shift a-shift b) hB (hlo a ha b hb) (hhi a ha b hb))
  have hzero : total nodes (fun a => total nodes (fun b =>
      f a b*((shift a-shift b):Rat))) = 0 := by
    have heq : ∀ a b, ((shift a-shift b):Rat) =
        (shift a:Rat)-(shift b:Rat) := by intros; norm_cast
    calc
      _ = total nodes (fun a => total nodes (fun b =>
          f a b*((shift a:Rat)-(shift b:Rat)))) := by
        apply total_congr nodes
        intro a ha
        apply total_congr nodes
        intro b hb
        rw [heq]
      _ = 0 := balanced_potential_zero nodes f (fun a => (shift a:Rat)) hbalance
  rw [hzero] at hbound
  rw [← hdiff] at hbound
  grind

/-- A common integer exponent shift is an exact gauge symmetry. -/
theorem cost_common_shift (nodes : List A) (C : A → A → Rat)
    (e : A → Int) (offset : Int) :
    cost nodes C (fun a => e a+offset) = cost nodes C e := by
  unfold cost
  apply total_congr nodes
  intro a ha
  apply total_congr nodes
  intro b hb
  have heq : (e a+offset)-(e b+offset) = e a-e b := by omega
  rw [heq]

end Kelana.IntegerGaugeBalance
