import Std

namespace Kelana.CollisionPacking

/-! Finite rational core of an assignment-independent fractional collision floor.
`pairFloor` is a certified lower bound on two sources sharing one decoder;
the real-log Jensen–Shannon bridge is stated analytically in the study, not
smuggled into this rational theorem. The `sources` list is intended to contain
one copy of each state, so the incidence load charges every source once. -/

variable {Source : Type}

def load [DecidableEq Source] (edges : List (List Source))
    (share : List Source → Rat) (s : Source) : Rat :=
  (edges.map fun edge => if s ∈ edge then share edge else 0).sum

private theorem sum_pointwise_le {α : Type} (xs : List α) (f g : α → Rat)
    (bound : ∀ x ∈ xs, f x ≤ g x) : (xs.map f).sum ≤ (xs.map g).sum := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
      simp only [List.map_cons, List.sum_cons]
      have hx := bound x (by simp)
      have ht := ih (by
        intro y hy
        exact bound y (by simp [hy]))
      exact Rat.le_trans (Rat.add_le_add_right.mpr hx)
        (Rat.add_le_add_left.mpr ht)

private theorem sum_pointwise_add {α : Type} (xs : List α) (f g : α → Rat) :
    (xs.map fun x => f x + g x).sum = (xs.map f).sum + (xs.map g).sum := by
  induction xs with
  | nil => simp only [List.map_nil, List.sum_nil, Rat.add_zero]
  | cons x xs ih =>
      simp only [List.map_cons, List.sum_cons, ih]
      grind [Rat.add_assoc, Rat.add_comm]

private theorem sum_pointwise_mul {α : Type} (xs : List α) (f : α → Rat) (c : Rat) :
    (xs.map fun x => c * f x).sum = c * (xs.map f).sum := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
      simp only [List.map_cons, List.sum_cons, ih]
      simp [Rat.mul_add]

private theorem sum_exchange {α β : Type} (xs : List α) (ys : List β)
    (f : α → β → Rat) :
    (xs.map fun x => (ys.map fun y => f x y).sum).sum =
      (ys.map fun y => (xs.map fun x => f x y).sum).sum := by
  induction xs with
  | nil =>
      simp only [List.map_nil, List.sum_nil]
      induction ys with
      | nil => rfl
      | cons y ys ih =>
          change (0 : Rat) = 0 + (ys.map fun _ => (0 : Rat)).sum
          rw [Rat.zero_add]
          exact ih
  | cons x xs ih =>
      simp only [List.map_cons, List.sum_cons, ih]
      rw [← sum_pointwise_add ys]

/-- Fractional hyperedge bills never duplicate source mass: each source's
incident shares have total load at most one. This is a finite rational theorem,
valid for overlapping hyperedges and arbitrary nonnegative source costs. -/
theorem fractional_charge [DecidableEq Source]
    (sources : List Source) (edges : List (List Source))
    (share : List Source → Rat) (cost : Source → Rat)
    (nonnegative : ∀ s, 0 ≤ cost s)
    (loads : ∀ s ∈ sources, load edges share s ≤ 1) :
    (edges.map fun e => share e *
      (sources.map fun s => if s ∈ e then cost s else 0).sum).sum ≤
      (sources.map cost).sum := by
  have hinner (e : List Source) :
      share e * (sources.map fun s => if s ∈ e then cost s else 0).sum =
      (sources.map fun s => (if s ∈ e then share e else 0) * cost s).sum := by
    rw [← sum_pointwise_mul]
    have heq : (fun s : Source => share e * (if s ∈ e then cost s else 0)) =
        (fun s => (if s ∈ e then share e else 0) * cost s) := by
      funext s
      split <;> simp_all
    rw [heq]
  simp only [hinner]
  rw [sum_exchange edges sources (fun e s => (if s ∈ e then share e else 0) * cost s)]
  apply sum_pointwise_le
  intro s hs
  calc
    (edges.map fun e => (if s ∈ e then share e else 0) * cost s).sum =
        (edges.map fun e => cost s * (if s ∈ e then share e else 0)).sum := by
          have heq : (fun e : List Source => (if s ∈ e then share e else 0) * cost s) =
              (fun e => cost s * (if s ∈ e then share e else 0)) := by
            funext e
            exact Rat.mul_comm _ _
          rw [heq]
    _ = cost s * load edges share s := sum_pointwise_mul _ _ _
    _ ≤ cost s * 1 := Rat.mul_le_mul_of_nonneg_left (loads s hs) (nonnegative s)
    _ = cost s := by simp

/-- If every hyperedge forces a same-label pair and its least pairwise
certificate is `floor`, then a fractional packing of hyperedges bounds the
whole assignment loss without enumerating its label partitions. -/
theorem packed_collision_floor [DecidableEq Source]
    (sources : List Source) (edges : List (List Source))
    (share floor : List Source → Rat) (cost : Source → Rat)
    (nonnegative : ∀ s, 0 ≤ cost s)
    (loads : ∀ s ∈ sources, load edges share s ≤ 1)
    (shares : ∀ e ∈ edges, 0 ≤ share e)
    (collision : ∀ e ∈ edges,
      floor e ≤ (sources.map fun s => if s ∈ e then cost s else 0).sum) :
    (edges.map fun e => share e * floor e).sum ≤
      (sources.map cost).sum := by
  have h := fractional_charge sources edges share cost nonnegative loads
  apply Rat.le_trans ?_ h
  apply sum_pointwise_le
  intro e he
  exact Rat.mul_le_mul_of_nonneg_left (collision e he) (shares e he)

/-- Three distinct sources cannot all have distinct two-valued labels. -/
theorem triple_two_labels (g : Fin 3 → Fin 2) :
    (g 0 = g 1) ∨ (g 0 = g 2) ∨ (g 1 = g 2) := by
  have choices (x : Fin 2) : x = 0 ∨ x = 1 := by
    have hx := x.isLt
    omega
  rcases choices (g 0) with h0 | h0 <;>
    rcases choices (g 1) with h1 | h1 <;>
    rcases choices (g 2) with h2 | h2 <;>
    simp [h0, h1, h2]

/-- The three-source/two-label certificate, with a pair floor supplied by
an independent analytic KL argument. Each cost is charged at most once. -/
theorem triple_pair_floor (g : Fin 3 → Fin 2) (cost : Fin 3 → Rat)
    (floor d01 d02 d12 : Rat)
    (h01 : g 0 = g 1 → d01 ≤ cost 0 + cost 1)
    (h02 : g 0 = g 2 → d02 ≤ cost 0 + cost 2)
    (h12 : g 1 = g 2 → d12 ≤ cost 1 + cost 2)
    (lower01 : floor ≤ d01) (lower02 : floor ≤ d02)
    (lower12 : floor ≤ d12)
    (nonnegative : ∀ i, 0 ≤ cost i) :
    floor ≤ cost 0 + cost 1 + cost 2 := by
  rcases triple_two_labels g with heq | heq | heq
  · have h := Rat.le_trans lower01 (h01 heq)
    grind [nonnegative 2]
  · have h := Rat.le_trans lower02 (h02 heq)
    grind [nonnegative 1]
  · have h := Rat.le_trans lower12 (h12 heq)
    grind [nonnegative 0]

end Kelana.CollisionPacking
