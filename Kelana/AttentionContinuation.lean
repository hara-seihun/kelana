import Std

namespace Kelana.AttentionContinuation

/-- An unnormalised attention denominator and one numerator coordinate. -/
structure Moments where
  z : Rat
  n : Rat
  deriving DecidableEq, Repr

def output (m : Moments) : Rat := m.n / m.z

/-- A token of positive exponential weight `a` and value `v` contributes
    additively to both moments. No exponential or softmax is assumed here. -/
def append (m : Moments) (a v : Rat) : Moments :=
  ⟨m.z + a, m.n + a * v⟩

def run (m : Moments) : List (Rat × Rat) → Moments
  | [] => m
  | (a, v) :: rest => run (append m a v) rest

theorem append_positive (m : Moments) (a v : Rat)
    (hz : 0 < m.z) (ha : 0 < a) : 0 < (append m a v).z := by
  simp only [append]
  grind

/-- Equality of moments survives every additive continuation, not merely
    a single-token probe. -/
theorem moments_determine_continuations (m m' : Moments)
    (hm : m = m') (tokens : List (Rat × Rat)) :
    output (run m tokens) = output (run m' tokens) := by
  rw [hm]

private theorem output_cross (m m' : Moments) (hz : m.z ≠ 0)
    (hz' : m'.z ≠ 0) (h : output m = output m') :
    m.n * m'.z = m'.n * m.z := by
  unfold output at h
  calc
    m.n * m'.z = (m.n / m.z * m.z) * m'.z := by rw [Rat.div_mul_cancel hz]
    _ = (m'.n / m'.z * m'.z) * m.z := by rw [h]; grind +ring
    _ = m'.n * m.z := by rw [Rat.div_mul_cancel hz']

/-- A single append identifies the moment difference up to the token value,
    once current outputs agree. The weight must be nonzero. -/
theorem probe_difference (m m' : Moments) (a v : Rat)
    (hz : m.z ≠ 0) (hz' : m'.z ≠ 0)
    (hza : (append m a v).z ≠ 0)
    (hz'a : (append m' a v).z ≠ 0)
    (ha : a ≠ 0)
    (hcurrent : output m = output m')
    (hprobe : output (append m a v) = output (append m' a v)) :
    m.n - m'.n = v * (m.z - m'.z) := by
  have hc := output_cross m m' hz hz' hcurrent
  have hp := output_cross (append m a v) (append m' a v) hza hz'a hprobe
  simp only [append] at hp
  have hfactor : a * (m.n - m'.n - v * (m.z - m'.z)) = 0 := by
    grind +ring
  have hzero := (Rat.mul_eq_zero.mp hfactor).resolve_left ha
  grind +ring

/-- Two legal probes with different values distinguish every pair of
    positive-denominator prefixes, even if their current output agrees.
    Only two probes are needed from the family of all possible appends. -/
theorem two_probes_identify_moments (m m' : Moments)
    (a b v w : Rat)
    (hz : 0 < m.z) (hz' : 0 < m'.z)
    (ha : 0 < a) (hb : 0 < b) (hvw : v ≠ w)
    (hcurrent : output m = output m')
    (hv : output (append m a v) = output (append m' a v))
    (hw : output (append m b w) = output (append m' b w)) :
    m = m' := by
  have hza : (append m a v).z ≠ 0 := Rat.ne_of_gt (append_positive m a v hz ha)
  have hz'a : (append m' a v).z ≠ 0 := Rat.ne_of_gt (append_positive m' a v hz' ha)
  have hzb : (append m b w).z ≠ 0 := Rat.ne_of_gt (append_positive m b w hz hb)
  have hz'b : (append m' b w).z ≠ 0 := Rat.ne_of_gt (append_positive m' b w hz' hb)
  have hdiffv := probe_difference m m' a v (Rat.ne_of_gt hz) (Rat.ne_of_gt hz')
    hza hz'a (Rat.ne_of_gt ha) hcurrent hv
  have hdiffw := probe_difference m m' b w (Rat.ne_of_gt hz) (Rat.ne_of_gt hz')
    hzb hz'b (Rat.ne_of_gt hb) hcurrent hw
  have hfactor : (v - w) * (m.z - m'.z) = 0 := by grind +ring
  have hmass : m.z = m'.z := by
    have hne : v - w ≠ 0 := by
      intro hzero
      apply hvw
      grind +ring
    have h : m.z - m'.z = 0 :=
      (Rat.mul_eq_zero.mp hfactor).resolve_left hne
    grind +ring
  have hnum : m.n = m'.n := by rw [hmass] at hdiffv; grind +ring
  cases m
  cases m'
  simp_all

/-- An arbitrary probe family containing two unequal values therefore has
    the same distinguishing power as the full future continuation language. -/
theorem all_probes_identify_moments (m m' : Moments)
    (probes : List (Rat × Rat))
    (hz : 0 < m.z) (hz' : 0 < m'.z)
    (hlegal : ∀ token ∈ probes, 0 < token.1)
    (hcurrent : output m = output m')
    (hall : ∀ token ∈ probes,
      output (append m token.1 token.2) =
        output (append m' token.1 token.2))
    (p q : Rat × Rat) (hp : p ∈ probes) (hq : q ∈ probes)
    (hdistinct : p.2 ≠ q.2) : m = m' := by
  exact two_probes_identify_moments m m' p.1 q.1 p.2 q.2
    hz hz' (hlegal p hp) (hlegal q hq) hdistinct hcurrent (hall p hp) (hall q hq)

private theorem run_ray (v : Rat) (m : Moments) (tokens : List Rat)
    (hm : m.n = v * m.z) :
    (run m (tokens.map (fun a => (a, v)))).n =
      v * (run m (tokens.map (fun a => (a, v)))).z := by
  induction tokens generalizing m with
  | nil => simpa [run] using hm
  | cons a rest ih =>
    simp only [List.map_cons, run]
    apply ih
    simp only [append]
    rw [hm]
    grind +ring

private theorem run_positive (v : Rat) (m : Moments) (tokens : List Rat)
    (hz : 0 < m.z) (hlegal : ∀ a ∈ tokens, 0 < a) :
    0 < (run m (tokens.map (fun a => (a, v)))).z := by
  induction tokens generalizing m with
  | nil => simpa [run] using hz
  | cons a rest ih =>
    simp only [List.map_cons, run]
    apply ih
    · exact append_positive m a v hz (hlegal a (by simp))
    · intro b hb
      exact hlegal b (by simp [hb])

/-- If every legal token has the same value `v`, distinct positive prefix
    masses on the ray `(z,v*z)` remain indistinguishable after any continuation.
    The distinct-value premise cannot be removed. -/
theorem constant_value_ray (v z z' : Rat) (tokens : List Rat)
    (hz : 0 < z) (hz' : 0 < z')
    (hlegal : ∀ a ∈ tokens, 0 < a) :
    output (run ⟨z, v * z⟩ (tokens.map (fun a => (a, v)))) =
    output (run ⟨z', v * z'⟩ (tokens.map (fun a => (a, v)))) := by
  have hfirst := run_ray v ⟨z, v*z⟩ tokens (by rfl)
  have hsecond := run_ray v ⟨z', v*z'⟩ tokens (by rfl)
  have hpfirst := run_positive v ⟨z, v*z⟩ tokens hz hlegal
  have hpsecond := run_positive v ⟨z', v*z'⟩ tokens hz' hlegal
  unfold output
  rw [hfirst, hsecond, Rat.mul_div_cancel (Rat.ne_of_gt hpfirst),
      Rat.mul_div_cancel (Rat.ne_of_gt hpsecond)]

end Kelana.AttentionContinuation
