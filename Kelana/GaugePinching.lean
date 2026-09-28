import Std

namespace Kelana.GaugePinching

def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_map (xs : List I) (f : I → J) (g : J → Rat) :
    total (xs.map f) g = total xs (fun i => g (f i)) := by
  simp only [total, List.map_map, Function.comp_def]

private theorem total_append (xs ys : List I) (f : I → Rat) :
    total (xs ++ ys) f = total xs f + total ys f := by
  simp [total, List.map_append, List.sum_append]

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

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    have hr := ih ht
    change 0 ≤ f i + total xs f
    grind

private theorem total_zero (xs : List I) :
    total xs (fun _ => (0 : Rat)) = 0 := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    change 0 + total xs (fun _ => (0 : Rat)) = 0
    grind

/-- The rational coordinate presentation of S⊕S⊥. Lists can include repeated
    coordinates; the algebraic identities still hold, although ordinary
    Frobenius-norm interpretation uses each coordinate once. -/
def coordinates (support : List R) (complement : List N) : List (R ⊕ N) :=
  support.map Sum.inl ++ complement.map Sum.inr

def squaredError (F X : I → I → Rat) (i j : I) : Rat :=
  (F i j - X i j) * (F i j - X i j)

def frobenius (coords : List I) (F X : I → I → Rat) : Rat :=
  total coords (fun i => total coords (fun j => squaredError F X i j))

def within (support : List R) (complement : List N)
    (F X : (R ⊕ N) → (R ⊕ N) → Rat) : Rat :=
  total support (fun r => total support (fun s =>
      squaredError F X (Sum.inl r) (Sum.inl s))) +
  total complement (fun n => total complement (fun m =>
      squaredError F X (Sum.inr n) (Sum.inr m)))

def offBlock (support : List R) (complement : List N)
    (F : (R ⊕ N) → (R ⊕ N) → Rat) : Rat :=
  total support (fun r => total complement (fun n =>
    F (Sum.inl r) (Sum.inr n) * F (Sum.inl r) (Sum.inr n)))

def pinched (F : (R ⊕ N) → (R ⊕ N) → Rat) :
    (R ⊕ N) → (R ⊕ N) → Rat
  | Sum.inl r, Sum.inl s => F (Sum.inl r) (Sum.inl s)
  | Sum.inr n, Sum.inr m => F (Sum.inr n) (Sum.inr m)
  | _, _ => 0

def BlockDiagonal (X : (R ⊕ N) → (R ⊕ N) → Rat) : Prop :=
  (∀ r n, X (Sum.inl r) (Sum.inr n) = 0) ∧
    (∀ n r, X (Sum.inr n) (Sum.inl r) = 0)

def Symmetric (F : I → I → Rat) : Prop := ∀ i j, F i j = F j i

/-- Four genuine finite sums, before assuming any block structure. -/
theorem four_blocks (support : List R) (complement : List N)
    (F X : (R ⊕ N) → (R ⊕ N) → Rat) :
    frobenius (coordinates support complement) F X =
      within support complement F X +
      total support (fun r => total complement (fun n =>
        squaredError F X (Sum.inl r) (Sum.inr n))) +
      total complement (fun n => total support (fun r =>
        squaredError F X (Sum.inr n) (Sum.inl r))) := by
  unfold frobenius coordinates within
  rw [total_append, total_map, total_map]
  have hinnerLeft : ∀ r,
      total (support.map Sum.inl ++ complement.map Sum.inr)
        (fun j => squaredError F X (Sum.inl r) j) =
      total support (fun s => squaredError F X (Sum.inl r) (Sum.inl s)) +
      total complement (fun n => squaredError F X (Sum.inl r) (Sum.inr n)) := by
    intro r
    rw [total_append, total_map, total_map]
  have hinnerRight : ∀ n,
      total (support.map Sum.inl ++ complement.map Sum.inr)
        (fun j => squaredError F X (Sum.inr n) j) =
      total support (fun r => squaredError F X (Sum.inr n) (Sum.inl r)) +
      total complement (fun m => squaredError F X (Sum.inr n) (Sum.inr m)) := by
    intro n
    rw [total_append, total_map, total_map]
  simp only [hinnerLeft, hinnerRight]
  rw [total_add, total_add]
  grind

/-- A symmetric matrix has equal cross-block squared sums. Consequently,
    arbitrary block-diagonal X pays each cross term exactly twice. -/
theorem pinching_pythagorean (support : List R) (complement : List N)
    (F X : (R ⊕ N) → (R ⊕ N) → Rat)
    (symF : Symmetric F) (blockX : BlockDiagonal X) :
    frobenius (coordinates support complement) F X =
      within support complement F X + 2 * offBlock support complement F := by
  rw [four_blocks]
  have hforward : total support (fun r => total complement (fun n =>
      squaredError F X (Sum.inl r) (Sum.inr n))) =
      offBlock support complement F := by
    unfold offBlock
    apply total_congr support; intro r hr
    apply total_congr complement; intro n hn
    unfold squaredError
    rw [blockX.1 r n]
    grind +ring
  have hback : total complement (fun n => total support (fun r =>
      squaredError F X (Sum.inr n) (Sum.inl r))) =
      offBlock support complement F := by
    rw [total_comm]
    unfold offBlock
    apply total_congr support; intro r hr
    apply total_congr complement; intro n hn
    unfold squaredError
    rw [blockX.2 n r, symF (Sum.inr n) (Sum.inl r)]
    grind +ring
  rw [hforward, hback]
  grind

private theorem within_nonneg (support : List R) (complement : List N)
    (F X : (R ⊕ N) → (R ⊕ N) → Rat) :
    0 ≤ within support complement F X := by
  unfold within
  have hleft : 0 ≤ total support (fun r => total support (fun s =>
      squaredError F X (Sum.inl r) (Sum.inl s))) := by
    apply total_nonneg support
    intro r hr
    apply total_nonneg support
    intro s hs
    exact square_nonneg _
  have hright : 0 ≤ total complement (fun n => total complement (fun m =>
      squaredError F X (Sum.inr n) (Sum.inr m))) := by
    apply total_nonneg complement
    intro n hn
    apply total_nonneg complement
    intro m hm
    exact square_nonneg _
  grind

theorem pinched_symmetric (F : (R ⊕ N) → (R ⊕ N) → Rat)
    (symF : Symmetric F) : Symmetric (pinched F) := by
  intro i j
  cases i with
  | inl r =>
    cases j with
    | inl s => exact symF (Sum.inl r) (Sum.inl s)
    | inr n => rfl
  | inr n =>
    cases j with
    | inl r => rfl
    | inr m => exact symF (Sum.inr n) (Sum.inr m)

/-- Pinching attains the floor because it preserves every within-block
    coefficient and zeroes exactly the two cross-block rectangles. -/
theorem pinched_attains (support : List R) (complement : List N)
    (F : (R ⊕ N) → (R ⊕ N) → Rat) (symF : Symmetric F) :
    BlockDiagonal (pinched F) ∧
      frobenius (coordinates support complement) F (pinched F) =
        2 * offBlock support complement F := by
  have hb : BlockDiagonal (pinched F) := by
    constructor <;> intros <;> rfl
  have hw : within support complement F (pinched F) = 0 := by
    unfold within
    have hl : total support (fun r => total support (fun s =>
        squaredError F (pinched F) (Sum.inl r) (Sum.inl s))) = 0 := by
      rw [show (fun r => total support (fun s =>
          squaredError F (pinched F) (Sum.inl r) (Sum.inl s))) =
          (fun _ => 0) from funext (fun r => by
            rw [show (fun s => squaredError F (pinched F)
              (Sum.inl r) (Sum.inl s)) = (fun _ => 0) from
              funext (fun s => by simp only [squaredError, pinched]; grind +ring)]
            exact total_zero support), total_zero]
    have hr : total complement (fun n => total complement (fun m =>
        squaredError F (pinched F) (Sum.inr n) (Sum.inr m))) = 0 := by
      rw [show (fun n => total complement (fun m =>
          squaredError F (pinched F) (Sum.inr n) (Sum.inr m))) =
          (fun _ => 0) from funext (fun n => by
            rw [show (fun m => squaredError F (pinched F)
              (Sum.inr n) (Sum.inr m)) = (fun _ => 0) from
              funext (fun m => by simp only [squaredError, pinched]; grind +ring)]
            exact total_zero complement), total_zero]
    grind
  exact ⟨hb, by rw [pinching_pythagorean support complement F (pinched F) symF hb, hw]; grind⟩

/-- Exact rational optimum among *all* block-diagonal matrices, a stronger
    feasible class than symmetric block-diagonal matrices. In the original
    orthogonal coordinates this is the pinching PFP+(I-P)F(I-P). -/
theorem pinched_minimizes (support : List R) (complement : List N)
    (F X : (R ⊕ N) → (R ⊕ N) → Rat)
    (symF : Symmetric F) (blockX : BlockDiagonal X) :
    frobenius (coordinates support complement) F (pinched F) ≤
      frobenius (coordinates support complement) F X := by
  have ha := (pinched_attains support complement F symF).2
  rw [ha, pinching_pythagorean support complement F X symF blockX]
  have h := within_nonneg support complement F X
  grind

end Kelana.GaugePinching
