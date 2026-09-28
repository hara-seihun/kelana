import Std

namespace Kelana.GridThresholdDecision

/-- Exact rational cost of an integer grid code; `c` may be nonintegral. -/
def cost (h b g c : Rat) (j : Nat) : Rat :=
  h * (b*b) * (((j : Rat)-c)*((j : Rat)-c)) +
    2*b*g*((j : Rat)-c)

/-- The sign of boundary `j` decides whether code `j+1` beats code `j`.
    Unlike the parabola's continuous vertex this expression uses no division. -/
def threshold (h b g c : Rat) (j : Nat) : Rat :=
  2*g + h*b*(2*((j : Rat)-c)+1)

theorem adjacent_difference (h b g c : Rat) (j : Nat) :
    cost h b g c (j+1) - cost h b g c j =
      b*threshold h b g c j := by
  unfold cost threshold
  simp only [Rat.natCast_add]
  grind +ring

/-- Positive curvature and positive grid step strictly order every boundary,
    including nonconsecutive ones. -/
theorem threshold_strict (h b g c : Rat) (hh : 0 < h) (hb : 0 < b)
    (j k : Nat) (hjk : j < k) :
    threshold h b g c j < threshold h b g c k := by
  have hcast : (j : Rat) < (k : Rat) := Rat.natCast_lt_natCast.mpr hjk
  have hdiff : 0 < (k : Rat)-(j : Rat) := by grind
  have hpos : 0 < (2:Rat)*(h*b)*((k:Rat)-(j:Rat)) :=
    Rat.mul_pos (Rat.mul_pos (by decide) (Rat.mul_pos hh hb)) hdiff
  have heq : threshold h b g c k - threshold h b g c j =
      (2:Rat)*(h*b)*((k:Rat)-(j:Rat)) := by
    unfold threshold
    grind +ring
  grind

theorem threshold_nondecreasing (h b g c : Rat) (hh : 0 < h) (hb : 0 < b)
    (j k : Nat) (hjk : j ≤ k) :
    threshold h b g c j ≤ threshold h b g c k := by
  rcases Nat.lt_or_eq_of_le hjk with hlt | heq
  · exact Rat.le_of_lt (threshold_strict h b g c hh hb j k hlt)
  · subst k
    exact Rat.le_refl

private theorem step_le_right (h b g c : Rat) (hb : 0 < b)
    (j : Nat) (hs : 0 ≤ threshold h b g c j) :
    cost h b g c j ≤ cost h b g c (j+1) := by
  have hdelta := adjacent_difference h b g c j
  have hnonneg := Rat.mul_nonneg (Rat.le_of_lt hb) hs
  grind

private theorem step_le_left (h b g c : Rat) (hb : 0 < b)
    (j : Nat) (hs : threshold h b g c j ≤ 0) :
    cost h b g c (j+1) ≤ cost h b g c j := by
  have hdelta := adjacent_difference h b g c j
  have hnonpos : b*threshold h b g c j ≤ 0 := by
    have h := Rat.mul_le_mul_of_nonneg_left hs (Rat.le_of_lt hb)
    simpa only [Rat.mul_zero] using h
  grind

/-- One nonnegative boundary certifies that all later grid codes cost at
    least as much as its left code. -/
theorem right_of_threshold (h b g c : Rat)
    (hh : 0 < h) (hb : 0 < b) (j n : Nat)
    (hs : 0 ≤ threshold h b g c j) (hjn : j ≤ n) :
    cost h b g c j ≤ cost h b g c n := by
  have hwalk : ∀ k, cost h b g c j ≤ cost h b g c (j+k) := by
    intro k
    induction k with
    | zero => simp
    | succ k ih =>
      have hth := threshold_nondecreasing h b g c hh hb j (j+k) (by omega)
      have hstep := step_le_right h b g c hb (j+k) (by grind)
      have heq : j+(k+1) = (j+k)+1 := by omega
      rw [heq]
      exact Rat.le_trans ih hstep
  have heq : j+(n-j)=n := by omega
  simpa only [heq] using hwalk (n-j)

/-- A nonpositive left boundary certifies that all earlier codes cost at
    least as much as its right code. -/
theorem left_of_threshold (h b g c : Rat)
    (hh : 0 < h) (hb : 0 < b) (l n : Nat)
    (hs : threshold h b g c l ≤ 0) (hnl : n ≤ l+1) :
    cost h b g c (l+1) ≤ cost h b g c n := by
  have hsteps : ∀ k, k < l+1 →
      cost h b g c (k+1) ≤ cost h b g c k := by
    intro k hk
    have hk_l : k ≤ l := by omega
    have hth := threshold_nondecreasing h b g c hh hb k l hk_l
    exact step_le_left h b g c hb k (by grind)
  have descend : ∀ m i, i ≤ m → m ≤ l+1 →
      cost h b g c m ≤ cost h b g c i := by
    intro m
    induction m with
    | zero =>
      intro i hi hm
      have : i = 0 := by omega
      subst i
      exact Rat.le_refl
    | succ m ih =>
      intro i hi hm
      by_cases heq : i = m+1
      · subst i
        exact Rat.le_refl
      · have him : i ≤ m := by omega
        exact Rat.le_trans (hsteps m (by omega)) (ih i him (by omega))
  exact descend (l+1) n hnl (by omega)

/-- Division-free necessary/sufficient local sign conditions are enough for
    a *global* optimum on every finite grid `0..K`. At endpoints no missing
    neighboring boundary is consulted. -/
theorem local_threshold_global_min (h b g c : Rat)
    (hh : 0 < h) (hb : 0 < b) (K j : Nat) (hj : j ≤ K)
    (hleft : j = 0 ∨ ∃ l, j = l+1 ∧ threshold h b g c l ≤ 0)
    (hright : j = K ∨ 0 ≤ threshold h b g c j) :
    ∀ n, n ≤ K → cost h b g c j ≤ cost h b g c n := by
  intro n hn
  by_cases hnj : n ≤ j
  · rcases hleft with hz | ⟨l, hl, hs⟩
    · subst j
      have : n = 0 := by omega
      subst n
      exact Rat.le_refl
    · subst j
      exact left_of_threshold h b g c hh hb l n hs hnj
  · have hjn : j ≤ n := by omega
    rcases hright with heq | hs
    · subst j
      have : n = K := by omega
      subst n
      exact Rat.le_refl
    · exact right_of_threshold h b g c hh hb j n hs hjn

/-- Conversely every global grid minimizer satisfies the two local signs.
    Together with `local_threshold_global_min` this is a complete ordered
    decision characterization, not merely a sufficient test. -/
theorem global_min_local_threshold (h b g c : Rat)
    (hb : 0 < b) (K j : Nat) (hj : j ≤ K)
    (hmin : ∀ n, n ≤ K → cost h b g c j ≤ cost h b g c n) :
    (j = 0 ∨ ∃ l, j = l+1 ∧ threshold h b g c l ≤ 0) ∧
      (j = K ∨ 0 ≤ threshold h b g c j) := by
  constructor
  · cases j with
    | zero => exact Or.inl rfl
    | succ l =>
      right
      refine ⟨l, rfl, ?_⟩
      have hcost := hmin l (by omega)
      have hdiff := adjacent_difference h b g c l
      have hprod : b*threshold h b g c l ≤ 0 := by
        rw [← hdiff]
        grind
      apply Rat.le_of_mul_le_mul_right (c := b) ?_ hb
      simpa only [Rat.mul_zero, Rat.mul_comm] using hprod
  · by_cases hlast : j = K
    · exact Or.inl hlast
    · right
      have hn : j+1 ≤ K := by omega
      have hcost := hmin (j+1) hn
      have hdiff := adjacent_difference h b g c j
      have hprod : 0 ≤ b*threshold h b g c j := by
        rw [← hdiff]
        grind
      apply Rat.le_of_mul_le_mul_right (c := b) ?_ hb
      simpa only [Rat.mul_zero, Rat.mul_comm] using hprod

theorem grid_min_iff_threshold (h b g c : Rat)
    (hh : 0 < h) (hb : 0 < b) (K j : Nat) (hj : j ≤ K) :
    (∀ n, n ≤ K → cost h b g c j ≤ cost h b g c n) ↔
      (j = 0 ∨ ∃ l, j = l+1 ∧ threshold h b g c l ≤ 0) ∧
      (j = K ∨ 0 ≤ threshold h b g c j) := by
  constructor
  · exact global_min_local_threshold h b g c hb K j hj
  · intro signs
    exact local_threshold_global_min h b g c hh hb K j hj signs.1 signs.2

/-- A strictly positive boundary makes its right code strictly worse;
    exact-zero boundaries may tie their two neighboring codes. The machine's
    nearest-even tie policy is outside this algebraic scope. -/
theorem strict_right_step (h b g c : Rat) (hb : 0 < b)
    (j : Nat) (hs : 0 < threshold h b g c j) :
    cost h b g c j < cost h b g c (j+1) := by
  have hdelta := adjacent_difference h b g c j
  have hpositive := Rat.mul_pos hb hs
  grind

theorem zero_threshold_tie (h b g c : Rat) (_hb : 0 < b)
    (j : Nat) (hs : threshold h b g c j = 0) :
    cost h b g c j = cost h b g c (j+1) := by
  have hdelta := adjacent_difference h b g c j
  rw [hs] at hdelta
  grind

end Kelana.GridThresholdDecision
