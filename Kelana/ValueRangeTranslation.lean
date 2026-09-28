import Kelana.CoupledGaugeCost

namespace Kelana.ValueRangeTranslation

open CoupledGaugeCost

def Feasible (coords : List I) (A : I → I → Rat) (c : I → Rat) (R : Rat) : Prop :=
  ∀ d ∈ coords, ∀ e ∈ coords, A d e - c d + c e ≤ R

/-- A feasible channel potential upper-bounds every translated source range
    when A upper-bounds the source pairwise differences. -/
theorem source_range_upper (samples : List S) (coords : List I)
    (v : S → I → Rat) (A : I → I → Rat) (c : I → Rat) (R : Rat)
    (hA : ∀ s ∈ samples, ∀ d ∈ coords, ∀ e ∈ coords, v s d - v s e ≤ A d e)
    (h : Feasible coords A c R) :
    ∀ s ∈ samples, ∀ d ∈ coords, ∀ e ∈ coords,
      (v s d - c d) - (v s e - c e) ≤ R := by
  intro s hs d hd e he
  have ha := hA s hs d hd e he
  have hb := h d hd e he
  grind

/-- Attained pairwise source maxima also give the converse; all original
    source constraints are represented, rather than a weaker summary. -/
theorem source_range_converse (samples : List S) (coords : List I)
    (v : S → I → Rat) (A : I → I → Rat) (c : I → Rat) (R : Rat)
    (hA : ∀ d ∈ coords, ∀ e ∈ coords,
      ∃ s ∈ samples, A d e = v s d - v s e)
    (h : ∀ s ∈ samples, ∀ d ∈ coords, ∀ e ∈ coords,
      (v s d - c d) - (v s e - c e) ≤ R) :
    Feasible coords A c R := by
  intro d hd e he
  obtain ⟨s, hs, ha⟩ := hA d hd e he
  have hb := h s hs d hd e he
  grind

/-- Every nonnegative unit-mass balanced edge flow gives a lower bound on
    all translated ranges. A normalized directed cycle is one such flow. -/
theorem balanced_lower_bound (coords : List I) (A B : I → I → Rat)
    (c : I → Rat) (R : Rat)
    (hB : ∀ d ∈ coords, ∀ e ∈ coords, 0 ≤ B d e)
    (hbalance : ∀ d ∈ coords, rowMass coords B d = columnMass coords B d)
    (hmass : flowMass coords B = 1) (h : Feasible coords A c R) :
    flowCost coords B A ≤ R := by
  have hsupport : ∀ d ∈ coords, ∀ e ∈ coords,
      1 + (-c d) - (-c e) ≤ 1 + R - A d e := by
    intro d hd e he
    have hh := h d hd e he
    grind
  have lower := balanced_flow_support coords B (fun d e => 1+R-A d e)
    (fun d => -c d) hB hbalance hsupport
  rw [flowCost_const_sub, hmass] at lower
  grind

/-- A matching feasible potential and balanced-flow value certify a global
    optimum against every rational center, without trusting an optimizer. -/
theorem optimality_certificate (coords : List I) (A B : I → I → Rat)
    (center : I → Rat) (R : Rat)
    (hB : ∀ d ∈ coords, ∀ e ∈ coords, 0 ≤ B d e)
    (hbalance : ∀ d ∈ coords, rowMass coords B d = columnMass coords B d)
    (hmass : flowMass coords B = 1) (hfeasible : Feasible coords A center R)
    (htight : flowCost coords B A = R) :
    Feasible coords A center R ∧
      ∀ next bound, Feasible coords A next bound → R ≤ bound := by
  refine ⟨hfeasible, ?_⟩
  intro next bound hnext
  have h := balanced_lower_bound coords A B next bound hB hbalance hmass hnext
  rw [htight] at h
  exact h

theorem common_shift (coords : List I) (A : I → I → Rat)
    (c : I → Rat) (R offset : Rat) (h : Feasible coords A c R) :
    Feasible coords A (fun d => c d - offset) R := by
  intro d hd e he
  have hh := h d hd e he
  grind

/-- Quantizing the stored center perturbs the range by at most twice the
    per-coordinate error radius, not by the width of the original values. -/
theorem rounded_range (coords : List I) (A : I → I → Rat)
    (c rounded : I → Rat) (R eps : Rat) (h : Feasible coords A c R)
    (hround : ∀ d ∈ coords, -eps ≤ rounded d - c d ∧ rounded d - c d ≤ eps) :
    Feasible coords A rounded (R + 2*eps) := by
  intro d hd e he
  have hr := h d hd e he
  have hrd := hround d hd
  have hre := hround e he
  grind

/-- A witnessed source extremum difference is a directed constraint on
    centers whenever every original token range must avoid increasing. -/
def ExtremalEdge (samples : List S) (v : S → I → Rat) (width : S → Rat)
    (lo hi : I) : Prop :=
  ∃ s ∈ samples, v s hi - v s lo = width s

inductive Reach (edge : I → I → Prop) : I → I → Prop
  | refl (a) : Reach edge a a
  | step {a b c} : Reach edge a b → edge b c → Reach edge a c

theorem source_edge_monotone (samples : List S) (v : S → I → Rat)
    (width : S → Rat) (center : I → Rat)
    (hpreserve : ∀ s ∈ samples, ∀ d e,
      (v s d - center d) - (v s e - center e) ≤ width s)
    {lo hi : I} (hedge : ExtremalEdge samples v width lo hi) :
    center lo ≤ center hi := by
  obtain ⟨s, hs, he⟩ := hedge
  have h := hpreserve s hs hi lo
  grind

theorem reach_monotone (edge : I → I → Prop) (center : I → Rat)
    (hstep : ∀ a b, edge a b → center a ≤ center b)
    {a b : I} (hpath : Reach edge a b) : center a ≤ center b := by
  induction hpath with
  | refl => exact Rat.le_refl
  | step path edge ih => exact Rat.le_trans ih (hstep _ _ edge)

/-- Every mutually reachable source-extremum component must carry one
    common center if no original token range is allowed to worsen. -/
theorem mutual_source_forces_equal (samples : List S) (v : S → I → Rat)
    (width : S → Rat) (center : I → Rat)
    (hpreserve : ∀ s ∈ samples, ∀ d e,
      (v s d - center d) - (v s e - center e) ≤ width s)
    {a b : I} (hab : Reach (ExtremalEdge samples v width) a b)
    (hba : Reach (ExtremalEdge samples v width) b a) :
    center a = center b := by
  have hs : ∀ d e, ExtremalEdge samples v width d e → center d ≤ center e := by
    intro d e h
    exact source_edge_monotone samples v width center hpreserve h
  have ha := reach_monotone _ center hs hab
  have hb := reach_monotone _ center hs hba
  grind

end Kelana.ValueRangeTranslation
