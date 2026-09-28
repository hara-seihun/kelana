import Kelana.ValueRoundingRisk

namespace Kelana.ValueGroupRiskFloor

open ValueCoordinateGauge (total finite_gram_identity)
open SharedSketchCovariance

def quadratic (keys : List I) (G : I → I → Rat) (x : I → Rat) :=
  total keys (fun i => total keys (fun j => G i j*x i*x j))

/-- Exact rational factor custody suffices; a floating eigenvalue estimate
alone does not. Every supplied coefficient is checked against the factors. -/
theorem weighted_factor_identity (keys : List I) (rows : List R)
    (w : R → Rat) (L : R → I → Rat) (G : I → I → Rat) (x : I → Rat)
    (hf : ∀ i ∈ keys, ∀ j ∈ keys, G i j = rawMoment rows w L i j) :
    quadratic keys G x =
      total rows (fun r => w r*(total keys (fun i => L r i*x i))*(total keys (fun i => L r i*x i))) := by
  have h := expectedSquared_eq_rawGram rows keys [()] w L (fun _ i => x i)
  have hgram : total keys (fun i => total keys (fun j =>
      outputGram [()] (fun _ i => x i) i j*rawMoment rows w L i j)) = quadratic keys G x := by
    apply total_congr keys
    intro i hi
    apply total_congr keys
    intro j hj
    rw [hf i hi j hj]
    simp only [outputGram, total, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
    grind +ring
  rw [hgram] at h
  rw [← h]
  unfold expectedSquared
  apply total_congr rows
  intro r hr
  have hs : response keys (fun _ i => x i) L r () = total keys (fun i => L r i*x i) := by
    unfold response
    apply total_congr keys; intro i hi; grind +ring
  simp only [total, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil] at hs ⊢
  rw [hs]
  grind +ring

theorem weighted_factor_nonneg (keys : List I) (rows : List R)
    (w : R → Rat) (L : R → I → Rat) (G : I → I → Rat) (x : I → Rat)
    (hw : ∀ r ∈ rows, 0 ≤ w r)
    (hf : ∀ i ∈ keys, ∀ j ∈ keys, G i j = rawMoment rows w L i j) :
    0 ≤ quadratic keys G x := by
  rw [weighted_factor_identity keys rows w L G x hf]
  apply total_nonneg rows
  intro r hr
  have h := Rat.mul_nonneg (hw r hr) (square_nonneg (total keys (fun i => L r i*x i)))
  grind +ring

/-- A diagonal is exactly a one-index energy on a distinct coordinate list. -/
theorem diagonal_identity [DecidableEq I] (keys : List I) (d x : I → Rat)
    (hn : keys.Nodup) :
    quadratic keys (fun i j => if i = j then d i else 0) x =
      total keys (fun i => d i*x i*x i) := by
  apply total_congr keys
  intro i hi
  calc
    _ = total keys (fun j => if j = i then d j*x j*x j else 0) := by
      apply total_congr keys
      intro j hj
      dsimp only
      by_cases he : i = j <;> grind +ring
    _ = _ := ValueRoundingRisk.total_at keys i _ hn hi

theorem quadratic_add (keys : List I) (G H : I → I → Rat) (x : I → Rat) :
    quadratic keys (fun i j => G i j+H i j) x = quadratic keys G x+quadratic keys H x := by
  unfold quadratic
  rw [← total_add]
  apply total_congr keys
  intro i hi
  rw [← total_add]
  apply total_congr keys
  intro j hj
  grind +ring

/-- The certificate is G-diag(d)=L^T diag(w)L with nonnegative exact w.
Its all-vector lower bound is derived, not assumed. -/
theorem certified_frame_lower [DecidableEq I] (keys : List I) (rows : List R)
    (w : R → Rat) (L : R → I → Rat) (G : I → I → Rat) (d x : I → Rat)
    (hn : keys.Nodup) (hw : ∀ r ∈ rows, 0 ≤ w r)
    (hf : ∀ i ∈ keys, ∀ j ∈ keys,
      G i j = (if i = j then d i else 0)+rawMoment rows w L i j) :
    total keys (fun i => d i*x i*x i) ≤ quadratic keys G x := by
  have he : quadratic keys G x =
      quadratic keys (fun i j => (if i = j then d i else 0)+rawMoment rows w L i j) x := by
    apply total_congr keys; intro i hi
    apply total_congr keys; intro j hj
    rw [hf i hi j hj]
  rw [he, quadratic_add, diagonal_identity keys d x hn]
  have h := weighted_factor_nonneg keys rows w L (rawMoment rows w L) x hw (by intros; rfl)
  grind

/-- No coordinate independence appears here. Pointwise frame dominance
controls every joint noise law and permits any larger marginal variances. -/
theorem joint_variance_floor (keys : List I) (outputs : List O) (outcomes : List Ω)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat)
    (d varianceLower : I → Rat)
    (hmu : ∀ w ∈ outcomes, 0 ≤ mu w)
    (hd : ∀ i ∈ keys, 0 ≤ d i)
    (hv : ∀ i ∈ keys, varianceLower i ≤ rawMoment outcomes mu E i i)
    (hframe : ∀ x : I → Rat,
      total keys (fun i => d i*x i*x i) ≤ quadratic keys (outputGram outputs A) x) :
    total keys (fun i => d i*varianceLower i) ≤ expectedSquared outcomes keys outputs mu E A := by
  have point : ∀ w ∈ outcomes,
      0 ≤ mu w*(quadratic keys (outputGram outputs A) (E w)-
        total keys (fun i => d i*E w i*E w i)) := by
    intro w hw
    apply Rat.mul_nonneg (hmu w hw)
    have h := hframe (E w)
    grind
  have hp := total_nonneg outcomes _ point
  have hsum : total outcomes (fun w => mu w*(quadratic keys (outputGram outputs A) (E w)-
      total keys (fun i => d i*E w i*E w i))) =
      expectedSquared outcomes keys outputs mu E A-
      total keys (fun i => d i*rawMoment outcomes mu E i i) := by
    have qeq : ∀ w, quadratic keys (outputGram outputs A) (E w) =
        total outputs (fun o => response keys A E w o*response keys A E w o) := by
      intro w
      exact (finite_gram_identity keys outputs (fun i o => A o i) (E w)).symm
    have qsum : total outcomes (fun w => mu w*quadratic keys (outputGram outputs A) (E w)) =
        expectedSquared outcomes keys outputs mu E A := by
      apply total_congr outcomes; intro w hw; rw [qeq]
    have dsum : total outcomes (fun w => mu w*total keys (fun i => d i*E w i*E w i)) =
        total keys (fun i => d i*rawMoment outcomes mu E i i) := by
      rw [total_weighted_comm]
      apply total_congr keys
      intro i hi
      unfold rawMoment
      rw [← total_mul]
      apply total_congr outcomes; intro w hw; grind +ring
    have he : total outcomes (fun w => mu w*(quadratic keys (outputGram outputs A) (E w)-
        total keys (fun i => d i*E w i*E w i))) +
        total outcomes (fun w => mu w*total keys (fun i => d i*E w i*E w i)) =
        total outcomes (fun w => mu w*quadratic keys (outputGram outputs A) (E w)) := by
      rw [← total_add]
      apply total_congr outcomes; intro w hw; grind +ring
    rw [qsum, dsum] at he
    grind
  rw [hsum] at hp
  have hlo : 0 ≤ total keys (fun i => d i*(rawMoment outcomes mu E i i-varianceLower i)) := by
    apply total_nonneg keys
    intro i hi
    apply Rat.mul_nonneg (hd i hi)
    have h := hv i hi
    grind
  have hid : total keys (fun i => d i*(rawMoment outcomes mu E i i-varianceLower i)) +
      total keys (fun i => d i*varianceLower i) =
      total keys (fun i => d i*rawMoment outcomes mu E i i) := by
    rw [← total_add]
    apply total_congr keys; intro i hi; grind +ring
  grind

/-- The deterministic mean-output error, including K/source/clipping bias,
remains in the risk floor rather than being subtracted from the comparison. -/
theorem affine_joint_floor (keys : List I) (outputs : List O) (outcomes : List Ω)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) (b : O → Rat)
    (d varianceLower : I → Rat)
    (hmass : total outcomes mu = 1)
    (hzero : ∀ i ∈ keys, mean outcomes mu E i = 0)
    (hmu : ∀ w ∈ outcomes, 0 ≤ mu w) (hd : ∀ i ∈ keys, 0 ≤ d i)
    (hv : ∀ i ∈ keys, varianceLower i ≤ rawMoment outcomes mu E i i)
    (hframe : ∀ x : I → Rat,
      total keys (fun i => d i*x i*x i) ≤ quadratic keys (outputGram outputs A) x) :
    total outputs (fun o => b o*b o)+total keys (fun i => d i*varianceLower i) ≤
      ValueRoundingRisk.affineRisk outcomes keys outputs mu E A b := by
  rw [ValueRoundingRisk.affine_bias_variance outcomes keys outputs mu E A b hmass hzero]
  have h := joint_variance_floor keys outputs outcomes mu E A d varianceLower hmu hd hv hframe
  grind

/-- The two Q heads consume the same random KV vector, not independent
replicas. Lifting that vector into a64-column frame preserves this identity. -/
theorem shared_head_lift (keys : List I) (a b x : I → Rat) (u v : Rat) :
    total (ValueCoordinateGauge.cartesian [false,true] keys)
      (fun hi => (if hi.1 then b hi.2 else a hi.2)*
        ((if hi.1 then v else u)*x hi.2)) =
      u*total keys (fun i => a i*x i)+v*total keys (fun i => b i*x i) := by
  rw [ValueCoordinateGauge.total_pairs]
  change total keys (fun i => a i*(u*x i))+
    (total keys (fun i => b i*(v*x i))+0) = _
  have h0 : total keys (fun i => a i*(u*x i)) = u*total keys (fun i => a i*x i) := by
    rw [← total_mul]
    apply total_congr keys; intro i hi; grind +ring
  have h1 : total keys (fun i => b i*(v*x i)) = v*total keys (fun i => b i*x i) := by
    rw [← total_mul]
    apply total_congr keys; intro i hi; grind +ring
  rw [h0,h1]
  grind

theorem shared_head_diagonal (keys : List I) (d0 d1 x : I → Rat) (u v : Rat) :
    total (ValueCoordinateGauge.cartesian [false,true] keys)
      (fun hi => (if hi.1 then d1 hi.2 else d0 hi.2)*
        ((if hi.1 then v else u)*x hi.2)*((if hi.1 then v else u)*x hi.2)) =
      total keys (fun i => (u*u*d0 i+v*v*d1 i)*x i*x i) := by
  rw [ValueCoordinateGauge.total_pairs]
  change total keys (fun i => d0 i*(u*x i)*(u*x i))+
    (total keys (fun i => d1 i*(v*x i)*(v*x i))+0) = _
  rw [Rat.add_zero, ← total_add]
  apply total_congr keys; intro i hi; grind +ring

/-- Independent groups/events supply zero cross moments. There is no such
premise between the32 coordinates of one group or its two GQA readers. -/
theorem group_variance_sum [DecidableEq G] (groups : List G) (outputs : List O)
    (outcomes : List Ω) (mu : Ω → Rat) (Z : Ω → G → O → Rat)
    (hn : groups.Nodup)
    (hc : ∀ g ∈ groups, ∀ h ∈ groups, g ≠ h → ∀ o ∈ outputs,
      total outcomes (fun w => mu w*(Z w g o*Z w h o)) = 0) :
    total outcomes (fun w => mu w*total outputs (fun o =>
      (total groups (fun g => Z w g o))*(total groups (fun g => Z w g o)))) =
    total groups (fun g => total outcomes (fun w => mu w*
      total outputs (fun o => Z w g o*Z w g o))) := by
  rw [total_weighted_comm]
  have per_output : ∀ o ∈ outputs,
      total outcomes (fun w => mu w*((total groups (fun g => Z w g o))*(total groups (fun g => Z w g o)))) =
      total groups (fun g => total outcomes (fun w => mu w*(Z w g o*Z w g o))) := by
    intro o ho
    have h := expectedSquared_eq_rawGram outcomes groups [()] mu (fun w g => Z w g o) (fun _ _ => 1)
    have hl : expectedSquared outcomes groups [()] mu (fun w g => Z w g o) (fun _ _ => 1) =
        total outcomes (fun w => mu w*((total groups (fun g => Z w g o))*(total groups (fun g => Z w g o)))) := by
      unfold expectedSquared
      apply total_congr outcomes
      intro w hw
      have hr : response groups (fun _ _ => 1) (fun w g => Z w g o) w () = total groups (fun g => Z w g o) := by
        unfold response
        apply total_congr groups; intro g hg; grind
      change mu w*((response groups (fun _ _ => 1) (fun w g => Z w g o) w ())*(response groups (fun _ _ => 1) (fun w g => Z w g o) w ())+0) = _
      rw [hr]
      grind
    rw [hl] at h
    rw [h]
    apply total_congr groups
    intro g hg
    calc
      _ = total groups (fun j => if j = g then total outcomes (fun w => mu w*(Z w j o*Z w j o)) else 0) := by
        apply total_congr groups
        intro j hj
        have hgram : outputGram [()] (fun _ _ => (1 : Rat)) g j = 1 := by
          unfold outputGram total; simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]; grind
        rw [hgram]
        unfold rawMoment
        by_cases eq : j = g
        · subst j; grind
        · rw [hc g hg j hj (by grind) o ho]
          grind
      _ = _ := ValueRoundingRisk.total_at groups g _ hn hg
  calc
    _ = total outputs (fun o => total groups (fun g => total outcomes (fun w => mu w*(Z w g o*Z w g o)))) :=
      total_congr outputs _ _ per_output
    _ = total groups (fun g => total outputs (fun o => total outcomes (fun w => mu w*(Z w g o*Z w g o)))) :=
      total_comm outputs groups _
    _ = _ := by
      apply total_congr groups
      intro g hg
      exact (total_weighted_comm outcomes outputs mu _).symm

end Kelana.ValueGroupRiskFloor
