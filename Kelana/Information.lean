import Std

namespace Kelana.Information

private theorem finRange_nodup (n : Nat) : (List.finRange n).Nodup := by
  induction n with
  | zero => simp [List.finRange_zero]
  | succ n ih =>
    rw [List.finRange_succ, List.nodup_cons]
    constructor
    · simp only [List.mem_map, not_exists, not_and]
      intro x _ heq
      have hval := congrArg Fin.val heq
      simp at hval
    · exact ih.map Fin.succ (fun a b hab heq => hab (Fin.succ_inj.mp heq))

/-- A symbolic pigeonhole theorem, proved without enumerating functions or states. -/
theorem injective_capacity {n m : Nat} (f : Fin n → Fin m)
    (hf : Function.Injective f) : n ≤ m := by
  have hn : ((List.finRange n).map f).Nodup :=
    (finRange_nodup n).map f (fun a b hab heq => hab (hf heq))
  have h := hn.length_le_of_subset (fun x _ => List.mem_finRange x)
  simpa using h

/-- All information used by the decoder must pass through the encoded state. -/
theorem exact_cut_capacity {n m : Nat} {Y : Type}
    (target : Fin n → Y) (ht : Function.Injective target)
    (encode : Fin n → Fin m) (decode : Fin m → Y)
    (correct : ∀ x, decode (encode x) = target x) : n ≤ m := by
  apply injective_capacity encode
  intro x y h
  apply ht
  rw [← correct x, ← correct y, h]

/-- Little-endian bytes of a bounded nonnegative integer. -/
def bytes : Nat → Nat → List Nat
  | 0, _ => []
  | n + 1, x => x % 256 :: bytes n (x / 256)

theorem bytes_length (n x : Nat) : (bytes n x).length = n := by
  induction n generalizing x with
  | zero => simp [bytes]
  | succ n ih => simp [bytes, ih]

theorem bytes_injective (n x y : Nat) (hx : x < 256 ^ n) (hy : y < 256 ^ n)
    (h : bytes n x = bytes n y) : x = y := by
  induction n generalizing x y with
  | zero => simp only [Nat.pow_zero] at hx hy; omega
  | succ n ih =>
    have hparts := List.cons.inj h
    have hx' : x / 256 < 256 ^ n := by
      apply (Nat.div_lt_iff_lt_mul (by decide)).mpr
      simpa [Nat.pow_succ, Nat.mul_comm] using hx
    have hy' : y / 256 < 256 ^ n := by
      apply (Nat.div_lt_iff_lt_mul (by decide)).mpr
      simpa [Nat.pow_succ, Nat.mul_comm] using hy
    have hquot := ih (x / 256) (y / 256) hx' hy' hparts.2
    omega

theorem bytes_values (n x b : Nat) (hb : b ∈ bytes n x) : b < 256 := by
  induction n generalizing x with
  | zero => simp [bytes] at hb
  | succ n ih =>
    simp only [bytes, List.mem_cons] at hb
    rcases hb with h | h
    · subst b; exact Nat.mod_lt _ (by decide)
    · exact ih (x / 256) h

/-- Interpret each byte as one of the 256 signed-byte values. -/
def expand (n : Nat) (x : Fin (256 ^ n)) : List Int :=
  (bytes n x.val).map (fun b : Nat => (b : Int) - 128)

theorem expand_values (n : Nat) (x : Fin (256 ^ n)) (y : Int)
    (hy : y ∈ expand n x) : -128 ≤ y ∧ y ≤ 127 := by
  obtain ⟨b, hb, heq⟩ := List.mem_map.mp hy
  have hbound := bytes_values n x.val b hb
  omega

theorem expand_injective (n : Nat) : Function.Injective (expand n) := by
  intro x y h
  have hb := congrArg (List.map (fun z : Int => (z + 128).toNat)) h
  have hdecode : (fun b : Nat => (((b : Int) - 128) + 128).toNat) = id := by
    funext b
    simp
  simp only [expand, List.map_map, Function.comp_def, hdecode, List.map_id] at hb
  apply Fin.ext
  exact bytes_injective n x.val y.val x.isLt y.isLt hb

/-- Any exact representation of n independent signed bytes needs at least 8n bits. -/
theorem byte_cut_lower_bound (n bits : Nat)
    (encode : Fin (256 ^ n) → Fin (2 ^ bits))
    (decode : Fin (2 ^ bits) → List Int)
    (correct : ∀ x, decode (encode x) = expand n x) : 8 * n ≤ bits := by
  have h := exact_cut_capacity (expand n) (expand_injective n) encode decode correct
  have h256 : (256 : Nat) = 2 ^ 8 := by decide
  rw [h256, ← Nat.pow_mul] at h
  exact (Nat.pow_le_pow_iff_right (by decide)).mp h

/-- Batching does not reduce the per-tile information bound, even for joint nonlinear encodings. -/
theorem activation_batch_cut (tiles bits : Nat)
    (encode : Fin (256 ^ (256 * tiles)) → Fin (2 ^ bits))
    (decode : Fin (2 ^ bits) → List Int)
    (correct : ∀ x, decode (encode x) = expand (256 * tiles) x) :
    2048 * tiles ≤ bits := by
  have h := byte_cut_lower_bound (256 * tiles) bits encode decode correct
  omega

/-- The physical capacity hypothesis is separate from the semantic information theorem. -/
theorem charged_capacity_lower_bound (tiles bits capacity cycles : Nat)
    (encode : Fin (256 ^ (256 * tiles)) → Fin (2 ^ bits))
    (decode : Fin (2 ^ bits) → List Int)
    (correct : ∀ x, decode (encode x) = expand (256 * tiles) x)
    (physical : bits ≤ capacity * cycles) : 2048 * tiles ≤ capacity * cycles := by
  exact Nat.le_trans (activation_batch_cut tiles bits encode decode correct) physical

/-- A sole IU4 activation port has 256 nibbles, hence 1024 bits, per instruction. -/
theorem iu4_call_lower_bound (tiles calls : Nat)
    (encode : Fin (256 ^ (256 * tiles)) → Fin (2 ^ (1024 * calls)))
    (decode : Fin (2 ^ (1024 * calls)) → List Int)
    (correct : ∀ x, decode (encode x) = expand (256 * tiles) x) :
    2 * tiles ≤ calls := by
  have h := activation_batch_cut tiles (1024 * calls) encode decode correct
  omega

/-- Joint packing across a batch cannot evade the mixed-port information bill. -/
theorem mixed_port_lower_bound (tiles iu4 iu8 : Nat)
    (encode : Fin (256 ^ (256 * tiles)) → Fin (2 ^ (1024 * iu4 + 2048 * iu8)))
    (decode : Fin (2 ^ (1024 * iu4 + 2048 * iu8)) → List Int)
    (correct : ∀ x, decode (encode x) = expand (256 * tiles) x) :
    2 * tiles ≤ iu4 + 2 * iu8 := by
  have h := activation_batch_cut tiles (1024 * iu4 + 2048 * iu8) encode decode correct
  omega

/-- Conditional resource optimum for the explicit IU4/IU8 activation-cut class.
    Other recurring instructions have nonnegative extra charge. -/
theorem mixed_port_cost_lower_bound (tiles iu4 iu8 w4 w8 extra : Nat)
    (capacity : 2 * tiles ≤ iu4 + 2 * iu8) (rates : w8 ≤ 2 * w4) :
    tiles * w8 ≤ iu4 * w4 + iu8 * w8 + extra := by
  have hcap := Nat.mul_le_mul_left w8 capacity
  have hrate := Nat.mul_le_mul_left iu4 rates
  have hcap' : 2 * (tiles * w8) ≤ iu4 * w8 + 2 * (iu8 * w8) := by
    simpa [Nat.mul_add, Nat.mul_assoc, Nat.mul_left_comm, Nat.mul_comm] using hcap
  have hrate' : iu4 * w8 ≤ 2 * (iu4 * w4) := by
    simpa [Nat.mul_assoc, Nat.mul_left_comm, Nat.mul_comm] using hrate
  omega

/-- One IU8 call per independent activation tile attains the lower bill in this
    class when its charge is at most that of two IU4 calls. -/
theorem iu8_optimal_in_mixed_port_class (tiles iu4 iu8 w4 w8 extra : Nat)
    (encode : Fin (256 ^ (256 * tiles)) → Fin (2 ^ (1024 * iu4 + 2048 * iu8)))
    (decode : Fin (2 ^ (1024 * iu4 + 2048 * iu8)) → List Int)
    (correct : ∀ x, decode (encode x) = expand (256 * tiles) x)
    (rates : w8 ≤ 2 * w4) :
    tiles * w8 ≤ iu4 * w4 + iu8 * w8 + extra := by
  exact mixed_port_cost_lower_bound tiles iu4 iu8 w4 w8 extra
    (mixed_port_lower_bound tiles iu4 iu8 encode decode correct) rates

end Kelana.Information
