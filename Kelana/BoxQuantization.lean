import Std

namespace Kelana.BoxQuantization

def dot : List Int → List Int → Int
  | a :: as, b :: bs => a * b + dot as bs
  | _, _ => 0

def mass : List Int → Nat
  | [] => 0
  | a :: as => a.natAbs + mass as

def witness (errors : List Int) (radius : Nat) : List Int :=
  errors.map (fun e => e.sign * (radius : Int))

/-- The complete input box has a cheap support function. No input sampling or
enumeration of its exponentially many corners is needed. -/
theorem box_upper (errors inputs : List Int) (radius : Nat)
    (bounded : ∀ x ∈ inputs, x.natAbs ≤ radius) :
    (dot errors inputs).natAbs ≤ mass errors * radius := by
  induction errors generalizing inputs with
  | nil => simp [dot, mass]
  | cons e es ih =>
    cases inputs with
    | nil => simp [dot]
    | cons x xs =>
      have hx := bounded x (by simp)
      have hxs : ∀ z ∈ xs, z.natAbs ≤ radius := by
        intro z hz
        exact bounded z (by simp [hz])
      have ht := ih xs hxs
      have hm := Nat.mul_le_mul_left e.natAbs hx
      have ha := Int.natAbs_add_le (e*x) (dot es xs)
      rw [Int.natAbs_mul] at ha
      simp only [dot, mass, Nat.add_mul]
      omega

theorem witness_dot (errors : List Int) (radius : Nat) :
    dot errors (witness errors radius) = (mass errors : Int) * (radius : Int) := by
  induction errors with
  | nil => simp [dot, mass]
  | cons e es ih =>
    have he : e * (e.sign * (radius : Int)) = (e.natAbs : Int) * (radius : Int) := by
      rw [← Int.mul_assoc, Int.mul_comm e e.sign, Int.sign_mul_self]
    simp only [witness, List.map_cons, dot, mass] at *
    rw [he, ih]
    simp [Int.add_mul]

theorem sign_small (e : Int) : e.sign.natAbs ≤ 1 := by
  by_cases hp : 0 < e
  · simp [Int.sign_eq_one_of_pos hp]
  · by_cases hn : e < 0
    · simp [Int.sign_eq_neg_one_of_neg hn]
    · have he : e = 0 := by omega
      simp [he]

theorem witness_bounded (errors : List Int) (radius : Nat) :
    ∀ x ∈ witness errors radius, x.natAbs ≤ radius := by
  intro x hx
  obtain ⟨e, _, he⟩ := List.mem_map.mp hx
  subst x
  rw [Int.natAbs_mul]
  have h := Nat.mul_le_mul_right radius (sign_small e)
  simpa using h

/-- Exact robust distortion, proved for every length, integer error vector and
integer box radius. The witness attains the upper bound. -/
theorem robust_value (errors : List Int) (radius : Nat) :
    (∀ inputs, (∀ x ∈ inputs, x.natAbs ≤ radius) →
      (dot errors inputs).natAbs ≤ mass errors * radius) ∧
    (∃ inputs, (∀ x ∈ inputs, x.natAbs ≤ radius) ∧
      (dot errors inputs).natAbs = mass errors * radius) := by
  constructor
  · exact fun inputs h => box_upper errors inputs radius h
  · refine ⟨witness errors radius, witness_bounded errors radius, ?_⟩
    rw [witness_dot, Int.natAbs_mul]
    simp

/-- Robust scalar-row error factors across blocks. -/
theorem mass_append (a b : List Int) : mass (a ++ b) = mass a + mass b := by
  induction a with
  | nil => simp [mass]
  | cons x xs ih => simp [mass, ih, Nat.add_assoc]

/-- Independent per-block minima are a global minimum of an additive robust
objective. Coupled dictionaries, shared charges and non-box domains are not
silently covered by this theorem. -/
theorem independent_minima {A : Type} (costs : List (A → Nat))
    (chosen other : List A)
    (sameLength : costs.length = chosen.length)
    (otherLength : costs.length = other.length)
    (localMin : ∀ i : Fin costs.length, ∀ a,
      (costs[i]) (chosen[i.val]'(by omega)) ≤ (costs[i]) a) :
    ((costs.zip chosen).map (fun p => p.1 p.2)).sum ≤
      ((costs.zip other).map (fun p => p.1 p.2)).sum := by
  induction costs generalizing chosen other with
  | nil => simp
  | cons c cs ih =>
    cases chosen with
    | nil => simp at sameLength
    | cons a as =>
      cases other with
      | nil => simp at otherLength
      | cons b bs =>
        have h0 := localMin ⟨0, by simp⟩ b
        have tailLength : cs.length = as.length := by simpa using sameLength
        have tailOther : cs.length = bs.length := by simpa using otherLength
        have tailMin : ∀ i : Fin cs.length, ∀ x,
            (cs[i]) (as[i.val]'(by omega)) ≤ (cs[i]) x := by
          intro i x
          have h := localMin ⟨i.val+1, by simp only [List.length_cons]; omega⟩ x
          simpa using h
        have ht := ih as bs tailLength tailOther tailMin
        change c a ≤ c b at h0
        simp only [List.zip_cons_cons, List.map_cons, List.sum_cons]
        omega

#print axioms robust_value
#print axioms independent_minima
end Kelana.BoxQuantization
