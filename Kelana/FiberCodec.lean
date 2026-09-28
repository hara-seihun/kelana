import Std

namespace Kelana.FiberCodec

/-- Place an object at its fiber's slot offset. -/
def encode {A : Type} (fiber : A → Nat) (offset : Nat → Nat)
    (rank : A → Nat) (x : A) : Nat :=
  offset (fiber x) + rank x

/-- Pairwise separated slots make a bounded, fiber-injective rank into a
lossless code. -/
theorem encode_injective {A : Type} (fiber : A → Nat)
    (offset width : Nat → Nat) (rank : A → Nat)
    (rank_lt : ∀ x, rank x < width (fiber x))
    (slots_disjoint : ∀ i j, i < j → offset i + width i ≤ offset j)
    (rank_injective : ∀ x y, fiber x = fiber y → rank x = rank y → x = y) :
    Function.Injective (encode fiber offset rank) := by
  intro x y hcode
  by_cases hf : fiber x = fiber y
  · apply rank_injective x y hf
    simp only [encode, hf, Nat.add_left_cancel_iff] at hcode
    exact hcode
  · rcases Nat.lt_or_gt_of_ne hf with hxy | hyx
    · have hslot := slots_disjoint (fiber x) (fiber y) hxy
      have hx := rank_lt x
      simp only [encode] at hcode
      omega
    · have hslot := slots_disjoint (fiber y) (fiber x) hyx
      have hy := rank_lt y
      simp only [encode] at hcode
      omega

/-- Once a decoder has identified the fiber, subtracting its offset recovers
exactly the within-fiber rank. -/
theorem rank_from_known_fiber {A : Type} (fiber : A → Nat)
    (offset : Nat → Nat) (rank : A → Nat) (x : A) (i : Nat)
    (hi : fiber x = i) :
    encode fiber offset rank x - offset i = rank x := by
  simp [encode, hi]

/-- A left inverse for each fiber gives a left inverse for the complete code
once the slot locator has recovered the fiber. -/
theorem decode_encode {A : Type} (fiber : A → Nat)
    (offset : Nat → Nat) (rank : A → Nat)
    (unrank : Nat → Nat → A) (locate : Nat → Nat)
    (locate_encode : ∀ x, locate (encode fiber offset rank x) = fiber x)
    (unrank_rank : ∀ x, unrank (fiber x) (rank x) = x) (x : A) :
    unrank (locate (encode fiber offset rank x))
      (encode fiber offset rank x -
        offset (locate (encode fiber offset rank x))) = x := by
  rw [locate_encode]
  rw [rank_from_known_fiber fiber offset rank x (fiber x) rfl]
  exact unrank_rank x

/-- Total width of the dyadic slots preceding a slot. The list stores their
base-two exponents. -/
def dyadicOffset (before : List Nat) : Nat :=
  (before.map fun exponent => 2 ^ exponent).sum

/-- Extending a prefix by one slot advances its offset by that slot's width,
plus any intervening slots. -/
theorem dyadicOffset_append_slot (before : List Nat) (bits : Nat)
    (between : List Nat) :
    dyadicOffset (before ++ bits :: between) =
      dyadicOffset before + 2 ^ bits + dyadicOffset between := by
  simp [dyadicOffset, List.map_append, List.sum_append, Nat.add_assoc]

/-- Every valid code in a slot lies below the offset of every later slot. -/
theorem earlier_code_lt_later_offset (before : List Nat) (bits rank : Nat)
    (between : List Nat) (rank_lt : rank < 2 ^ bits) :
    dyadicOffset before + rank <
      dyadicOffset (before ++ bits :: between) := by
  rw [dyadicOffset_append_slot]
  omega

/-- Largest-first ordering aligns each slot offset to the width of the current
slot. -/
theorem dyadicOffset_aligned (before : List Nat) (bits : Nat)
    (largest_first : ∀ exponent ∈ before, bits ≤ exponent) :
    2 ^ bits ∣ dyadicOffset before := by
  induction before with
  | nil => simp [dyadicOffset]
  | cons exponent rest ih =>
    simp only [dyadicOffset, List.map_cons, List.sum_cons]
    apply Nat.dvd_add
    · exact Nat.pow_dvd_pow 2 (largest_first exponent (by simp))
    · apply ih
      intro other hother
      exact largest_first other (by simp [hother])

/-- For an aligned dyadic slot, the low bits are precisely the fiber rank. -/
theorem dyadic_low_bits (before : List Nat) (bits rank : Nat)
    (largest_first : ∀ exponent ∈ before, bits ≤ exponent)
    (rank_lt : rank < 2 ^ bits) :
    (dyadicOffset before + rank) % 2 ^ bits = rank := by
  have haligned := dyadicOffset_aligned before bits largest_first
  have hoff : dyadicOffset before % 2 ^ bits = 0 :=
    Nat.mod_eq_zero_of_dvd haligned
  rw [Nat.add_mod, hoff]
  simp only [Nat.zero_add, Nat.mod_mod]
  exact Nat.mod_eq_of_lt rank_lt

/-- For an aligned dyadic slot, division by its width removes the fiber rank.
These are the high bits which identify the response slot. -/
theorem dyadic_high_bits (before : List Nat) (bits rank : Nat)
    (largest_first : ∀ exponent ∈ before, bits ≤ exponent)
    (rank_lt : rank < 2 ^ bits) :
    (dyadicOffset before + rank) / 2 ^ bits =
      dyadicOffset before / 2 ^ bits := by
  have haligned := dyadicOffset_aligned before bits largest_first
  have hoff : dyadicOffset before % 2 ^ bits = 0 :=
    Nat.mod_eq_zero_of_dvd haligned
  have hrmod : rank % 2 ^ bits = rank := Nat.mod_eq_of_lt rank_lt
  have hrdiv : rank / 2 ^ bits = 0 := Nat.div_eq_of_lt rank_lt
  rw [Nat.add_div (Nat.two_pow_pos bits), hoff, hrmod, hrdiv]
  simp [Nat.not_le_of_lt rank_lt]

/-- Sum the exact fiber populations. -/
def population (fibers : List (Nat × Nat)) : Nat :=
  (fibers.map Prod.fst).sum

/-- Sum the dyadic widths. Each pair stores `(population, widthBits)`. -/
def payload (fibers : List (Nat × Nat)) : Nat :=
  (fibers.map fun fiber => 2 ^ fiber.2).sum

/-- Rounding every nonempty fiber population upward to a power of two costs
strictly less than a factor of two in total. -/
theorem payload_lt_twice_population (fibers : List (Nat × Nat))
    (nonempty : fibers ≠ [])
    (rounded : ∀ fiber ∈ fibers,
      fiber.1 ≤ 2 ^ fiber.2 ∧ 2 ^ fiber.2 < 2 * fiber.1) :
    payload fibers < 2 * population fibers := by
  induction fibers with
  | nil => exact (nonempty rfl).elim
  | cons fiber rest ih =>
    have hhead := rounded fiber (by simp)
    by_cases hrest : rest = []
    · subst rest
      simpa [payload, population] using hhead.2
    · have htail := ih hrest (fun other hother =>
        rounded other (by simp [hother]))
      simp only [payload, population, List.map_cons, List.sum_cons] at htail ⊢
      omega

/-- If the fibers partition all ternary vectors, their rounded slots occupy
less than twice the ternary state count. -/
theorem payload_lt_twice_ternary (fibers : List (Nat × Nat)) (n : Nat)
    (nonempty : fibers ≠ [])
    (partition : population fibers = 3 ^ n)
    (rounded : ∀ fiber ∈ fibers,
      fiber.1 ≤ 2 ^ fiber.2 ∧ 2 ^ fiber.2 < 2 * fiber.1) :
    payload fibers < 2 * 3 ^ n := by
  rw [← partition]
  exact payload_lt_twice_population fibers nonempty rounded

/-- Any `k`-bit upper bound for the ternary state count yields a `k+1`-bit
upper bound for the rounded fiber payload. -/
theorem payload_fits_one_extra_bit (fibers : List (Nat × Nat)) (n k : Nat)
    (nonempty : fibers ≠ [])
    (partition : population fibers = 3 ^ n)
    (rounded : ∀ fiber ∈ fibers,
      fiber.1 ≤ 2 ^ fiber.2 ∧ 2 ^ fiber.2 < 2 * fiber.1)
    (ternary_fits : 3 ^ n ≤ 2 ^ k) :
    payload fibers ≤ 2 ^ (k + 1) := by
  have hp := payload_lt_twice_ternary fibers n nonempty partition rounded
  have hk := Nat.mul_le_mul_left 2 ternary_fits
  rw [Nat.pow_succ]
  omega

/-- `bits` is the least number of bits whose code space contains `states`. -/
def IsLeastBitCapacity (states bits : Nat) : Prop :=
  states ≤ 2 ^ bits ∧ ∀ candidate, states ≤ 2 ^ candidate → bits ≤ candidate

/-- The least whole-row payload is at most one bit above any bit bound for the
unrounded ternary state count. -/
theorem least_payload_bits_le (fibers : List (Nat × Nat)) (n k bits : Nat)
    (nonempty : fibers ≠ [])
    (partition : population fibers = 3 ^ n)
    (rounded : ∀ fiber ∈ fibers,
      fiber.1 ≤ 2 ^ fiber.2 ∧ 2 ^ fiber.2 < 2 * fiber.1)
    (ternary_fits : 3 ^ n ≤ 2 ^ k)
    (least : IsLeastBitCapacity (payload fibers) bits) :
    bits ≤ k + 1 := by
  exact least.2 (k + 1)
    (payload_fits_one_extra_bit fibers n k nonempty partition rounded ternary_fits)

end Kelana.FiberCodec
