import Kelana.CausalStateCapacity

namespace Kelana.AttentionStateCapacity

open CausalStateCapacity

/-- On the unary zero stream, a finite deterministic machine eventually
    repeats a state: the first visit is at a positive length `n ≤ C`, and
    the repeat is after a positive period `d ≤ C`. -/
theorem positive_unary_cycle (C : Nat) (_hC : 0 < C)
    (step : Fin C → Fin C) (start : Fin C) :
    ∃ n d : Nat, 1 ≤ n ∧ n ≤ C ∧ 1 ≤ d ∧ d ≤ C ∧
      orbit step start n = orbit step start (n + d) := by
  let sampled : Fin (C + 1) → Fin C :=
    fun i => orbit step start (i.val + 1)
  obtain ⟨i, j, hij, heq⟩ := prefix_collision C sampled
  have hneq : i.val ≠ j.val := by
    intro h
    exact hij (Fin.ext h)
  have horient : i.val < j.val ∨ j.val < i.val := by omega
  rcases horient with hlt | hgt
  · refine ⟨i.val + 1, j.val - i.val, ?_, ?_, ?_, ?_, ?_⟩
    · omega
    · have hi := i.isLt; omega
    · omega
    · have hj := j.isLt; omega
    · dsimp [sampled] at heq
      have he : i.val + 1 + (j.val - i.val) = j.val + 1 := by omega
      simpa only [he] using heq
  · refine ⟨j.val + 1, i.val - j.val, ?_, ?_, ?_, ?_, ?_⟩
    · omega
    · have hj := j.isLt; omega
    · omega
    · have hi := i.isLt; omega
    · dsimp [sampled] at heq
      have he : j.val + 1 + (i.val - j.val) = i.val + 1 := by omega
      simpa only [he] using heq.symm

/-- The same loop may be traversed any number of times: this is the
    consistency constraint that independently reachable states alone miss. -/
theorem repeat_unary_cycle {X : Type} (step : X → X) (start : X)
    (n d : Nat) (h : orbit step start n = orbit step start (n + d))
    (k : Nat) : orbit step start n = orbit step start (n + k * d) := by
  induction k with
  | zero => simp
  | succ k ih =>
    have shifted := congrArg (fun x => orbit step x d) ih
    rw [← orbit_add, ← orbit_add] at shifted
    have index : n + (k + 1) * d = (n + k * d) + d := by
      simp only [Nat.add_mul]
      omega
    rw [index]
    exact h.trans shifted

/-- Periodic repetition gives a shared state at a large prescribed scale.
    We allow the upper endpoint `target+C`; this avoids a gratuitous special
    case when the target itself lies exactly on the cycle. -/
theorem late_unary_collision (C : Nat) (hC : 0 < C)
    (step : Fin C → Fin C) (start : Fin C)
    (target : Nat) (hlarge : C ≤ target) :
    ∃ n m : Nat, 1 ≤ n ∧ n ≤ C ∧ target ≤ m ∧ m ≤ target + C ∧
      orbit step start n = orbit step start m := by
  obtain ⟨n, d, hn0, hnC, hd0, hdC, heq⟩ := positive_unary_cycle C hC step start
  let k := (target - n) / d + 1
  let m := n + k * d
  have hnT : n ≤ target := by omega
  have hmod := Nat.mod_lt (target - n) hd0
  have hdiv : target - n = (target - n) % d +
      (target - n) / d * d := by
    simpa only [Nat.mul_comm] using (Nat.mod_add_div (target - n) d).symm
  have hbounds : target < m ∧ m ≤ target + d := by
    dsimp [m, k]
    rw [Nat.add_mul]
    omega
  refine ⟨n, m, hn0, hnC, by omega, by omega, ?_⟩
  exact repeat_unary_cycle step start n d heq k

/-- A deterministic candidate with a state-only readout cannot distinguish
    these two zero prefixes after the same suffix of `s*C` ones. -/
theorem shared_readout_after_ones (C s : Nat) (hC : 0 < C) (hs : 2 ≤ s)
    (zero one : Fin C → Fin C) (start : Fin C)
    (readout : Fin C → Rat) :
    ∃ n m : Nat, 1 ≤ n ∧ n ≤ C ∧ s * s * C ≤ m ∧
      m + s * C ≤ (s * s + s + 1) * C ∧
      readout (orbit one (orbit zero start n) (s * C)) =
        readout (orbit one (orbit zero start m) (s * C)) := by
  obtain ⟨n, m, hn0, hnC, hmlo, hmhi, hs⟩ :=
    late_unary_collision C hC zero start (s * s * C) (by
      have hss : 1 ≤ s * s := by
        have hpos : 0 < s * s := Nat.mul_pos (by omega) (by omega)
        omega
      simpa only [Nat.mul_assoc, Nat.one_mul] using Nat.mul_le_mul_right C hss)
  refine ⟨n, m, hn0, hnC, hmlo, ?_, ?_⟩
  · calc
      m + s * C ≤ (s * s * C + C) + s * C := by omega
      _ = (s * s + s + 1) * C := by simp only [Nat.add_mul]; omega
  · rw [hs]

/-- Cross-multiplication with explicitly positive denominators; no floating
    numerical comparison is hidden in the ratio estimates below. -/
private theorem fraction_le (a b c d : Rat) (hb : 0 < b) (hd : 0 < d)
    (hcross : a * d ≤ c * b) : a / b ≤ c / d := by
  apply Rat.le_of_mul_le_mul_right (c := b * d) ?_ (Rat.mul_pos hb hd)
  have hleft : (a / b) * (b * d) = a * d := by
    rw [← Rat.mul_assoc, Rat.div_mul_cancel (Rat.ne_of_gt hb)]
  have hright : (c / d) * (b * d) = c * b := by
    calc
      _ = (c / d) * (d * b) := by rw [Rat.mul_comm b d]
      _ = c * b := by rw [← Rat.mul_assoc, Rat.div_mul_cancel (Rat.ne_of_gt hd)]
  rw [hleft, hright]
  exact hcross

/-- Uniform-attention outputs of a short all-zero prefix and an amplified
    all-zero prefix, each followed by the SAME `s*C` ones, differ by at least
    `(s-1)/(s+1)`. This is a rational algebra statement; the caller instantiates
    its rational parameters by casts of the finite-state witness lengths. -/
theorem rational_mean_gap (C s n m : Rat)
    (hC : 0 < C) (hs : 2 ≤ s) (hn : 0 ≤ n) (hnC : n ≤ C)
    (hm : s * s * C ≤ m) :
    (s - 1) / (s + 1) ≤
      (s * C) / (n + s * C) - (s * C) / (m + s * C) := by
  have hs0 : 0 < s := by grind
  have hs1 : 0 < s + 1 := by grind
  have ht : 0 < s * C := Rat.mul_pos hs0 hC
  have hshortden : 0 < n + s * C := by grind
  have hlongden : 0 < m + s * C := by
    have htarget : 0 < s * s * C := by
      rw [Rat.mul_assoc]
      exact Rat.mul_pos hs0 ht
    grind
  have hsn : s * n ≤ s * C :=
    Rat.mul_le_mul_of_nonneg_left hnC (Rat.le_of_lt hs0)
  have hshort : s / (s + 1) ≤ (s * C) / (n + s * C) := by
    apply fraction_le s (s+1) (s*C) (n+s*C) hs1 hshortden
    grind +ring
  have hlong : (s * C) / (m + s * C) ≤ 1 / (s + 1) := by
    apply fraction_le (s*C) (m+s*C) 1 (s+1) hlongden hs1
    grind +ring
  have hidentity : (s - 1) / (s + 1) = s / (s+1) - 1 / (s+1) := by
    have ha := Rat.div_mul_cancel (Rat.ne_of_gt hs1) (a := s)
    have hb := Rat.div_mul_cancel (Rat.ne_of_gt hs1) (a := (1:Rat))
    have hc := Rat.div_mul_cancel (Rat.ne_of_gt hs1) (a := s-1)
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := s+1) ?_ hs1
      grind +ring
    · apply Rat.le_of_mul_le_mul_right (c := s+1) ?_ hs1
      grind +ring
  rw [hidentity]
  grind

/-- Two outputs separated by twice a target error cannot both be closer than
    that error to the SAME state-only candidate output. -/
theorem separated_outputs (high low candidate epsilon : Rat)
    (hgap : 2 * epsilon ≤ high - low) :
    epsilon ≤ (candidate - high).abs ∨
      epsilon ≤ (candidate - low).abs := by
  by_cases hfirst : epsilon ≤ (candidate - high).abs
  · exact Or.inl hfirst
  by_cases hsecond : epsilon ≤ (candidate - low).abs
  · exact Or.inr hsecond
  have h1 : (candidate - high).abs < epsilon := by grind
  have h2 : (candidate - low).abs < epsilon := by grind
  by_cases hh : 0 ≤ candidate - high
  · rw [Rat.abs_of_nonneg hh] at h1
    by_cases hl : 0 ≤ candidate - low
    · rw [Rat.abs_of_nonneg hl] at h2
      grind
    · have hl' : candidate - low ≤ 0 := by grind
      rw [Rat.abs_of_nonpos hl'] at h2
      grind
  · have hh' : candidate - high ≤ 0 := by grind
    rw [Rat.abs_of_nonpos hh'] at h1
    by_cases hl : 0 ≤ candidate - low
    · rw [Rat.abs_of_nonneg hl] at h2
      grind
    · have hl' : candidate - low ≤ 0 := by grind
      rw [Rat.abs_of_nonpos hl'] at h2
      grind

/-- Running mean after `n` zeros and `t` ones. -/
def uniformOutput (n t : Nat) : Rat :=
  (t : Rat) / ((n : Rat) + (t : Rat))

/-- Quantitative all-`C` state capacity: the same candidate state reads out
    after two legal words of length at most `(s²+s+1)C`, but the teacher's
    scalar uniform-attention outputs differ enough to force this error floor.
    A position counter, if used by the candidate, is part of its `C` states. -/
theorem uniform_attention_state_floor (C s : Nat)
    (hC : 0 < C) (hs : 2 ≤ s)
    (zero one : Fin C → Fin C) (start : Fin C)
    (readout : Fin C → Rat) :
    ∃ n m : Nat, 1 ≤ n ∧ n ≤ C ∧
      n + s * C ≤ (s * s + s + 1) * C ∧
      m + s * C ≤ (s * s + s + 1) * C ∧
      (let ε : Rat := ((s : Rat) - 1) / (2 * ((s : Rat) + 1))
       ε ≤ (readout (orbit one (orbit zero start n) (s * C)) -
         uniformOutput n (s * C)).abs ∨
       ε ≤ (readout (orbit one (orbit zero start m) (s * C)) -
         uniformOutput m (s * C)).abs) := by
  obtain ⟨n, m, hn0, hnC, hmlo, hmlen, hstate⟩ :=
    shared_readout_after_ones C s hC hs zero one start readout
  have hClt : (0:Rat) < C := Rat.natCast_lt_natCast.mpr hC
  have hsle : (2:Rat) ≤ s := Rat.natCast_le_natCast.mpr hs
  have hnnonneg : (0:Rat) ≤ n := Rat.natCast_nonneg
  have hnle : (n:Rat) ≤ C := Rat.natCast_le_natCast.mpr hnC
  have hmle : (s:Rat) * s * C ≤ m := by
    simpa only [Rat.natCast_mul] using (Rat.natCast_le_natCast.mpr hmlo)
  have hgap := rational_mean_gap (C:Rat) (s:Rat) (n:Rat) (m:Rat)
    hClt hsle hnnonneg hnle hmle
  have hsden : (0:Rat) < (s:Rat) + 1 := by grind
  have htwoden : (0:Rat) < 2 * ((s:Rat) + 1) :=
    Rat.mul_pos (by decide) hsden
  have hε : 2 * (((s:Rat) - 1) / (2 * ((s:Rat) + 1))) =
      ((s:Rat) - 1) / ((s:Rat) + 1) := by
    have ha := Rat.div_mul_cancel (Rat.ne_of_gt htwoden) (a := ((s:Rat)-1))
    have hb := Rat.div_mul_cancel (Rat.ne_of_gt hsden) (a := ((s:Rat)-1))
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := ((s:Rat)+1)) ?_ hsden
      grind +ring
    · apply Rat.le_of_mul_le_mul_right (c := ((s:Rat)+1)) ?_ hsden
      grind +ring
  have herr :
      let candidate := readout (orbit one (orbit zero start n) (s*C))
      let ε : Rat := ((s:Rat)-1)/(2*((s:Rat)+1))
      ε ≤ (candidate - uniformOutput n (s*C)).abs ∨
        ε ≤ (candidate - uniformOutput m (s*C)).abs := by
    dsimp only
    have hfrac : (s:Rat) * C = ((s*C:Nat):Rat) := by
      simp only [Rat.natCast_mul]
    rw [hfrac] at hgap
    have hgap' : 2 * (((s:Rat)-1)/(2*((s:Rat)+1))) ≤
        uniformOutput n (s*C) - uniformOutput m (s*C) := by
      rw [hε]
      simpa only [uniformOutput] using hgap
    exact separated_outputs _ _ _ _ hgap'
  have hshortlen : n + s*C ≤ (s*s+s+1)*C := by
    have hCtarget : C ≤ s*s*C := by
      have hss : 1 ≤ s*s := by
        have hp : 0 < s*s := Nat.mul_pos (by omega) (by omega)
        omega
      simpa only [Nat.mul_assoc, Nat.one_mul] using Nat.mul_le_mul_right C hss
    omega
  refine ⟨n, m, hn0, hnC, hshortlen, hmlen, ?_⟩
  dsimp only at herr ⊢
  simpa only [hstate] using herr

end Kelana.AttentionStateCapacity
