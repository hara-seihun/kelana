import Std

namespace Kelana.LowRankCodeUpdate

/-- A rank-R correction to a diagonal quadratic, all over exact rationals. -/
def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_zero (xs : List I) :
    total xs (fun _ => (0:Rat)) = 0 := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    change 0 + total xs (fun _ => (0:Rat)) = 0
    grind

/-- The finRange list contains the selected coordinate exactly once. -/
private theorem selected_total {N : Nat} (d : Fin N) (value : Rat) :
    total (List.finRange N) (fun i => if d = i then value else 0) = value := by
  have aux {I : Type} [DecidableEq I] (xs : List I)
      (hn : xs.Nodup) (d : I) (hd : d ∈ xs) :
      total xs (fun i => if d = i then value else 0) = value := by
    induction xs with
    | nil => simp at hd
    | cons i xs ih =>
      have hparts := List.nodup_cons.mp hn
      simp only [List.mem_cons] at hd
      rcases hd with heq | hmem
      · subst d
        have hz : total xs (fun j => if i = j then value else 0) = 0 := by
          calc
            _ = total xs (fun _ => (0:Rat)) := by
              apply total_congr xs
              intro j hj
              have hneq : i ≠ j := by intro eq; exact hparts.1 (eq ▸ hj)
              simp [hneq]
            _ = 0 := total_zero xs
        change (if i = i then value else 0) +
            total xs (fun j => if i = j then value else 0) = value
        simp only [if_pos rfl, hz]
        grind
      · have hneq : d ≠ i := by
          intro heq
          subst d
          exact hparts.1 hmem
        change (if d = i then value else 0) +
            total xs (fun j => if d = j then value else 0) = value
        simp only [if_neg hneq, Rat.zero_add]
        exact ih hparts.2 hmem
  exact aux (List.finRange N) (List.nodup_finRange N) d
    (List.mem_finRange _)

def update {D : Nat} (e : Fin D → Rat) (d : Fin D) (delta : Rat) :
    Fin D → Rat :=
  fun i => if d = i then e i + delta else e i

def response {D R : Nat} (U : Fin D → Fin R → Rat)
    (e : Fin D → Rat) (j : Fin R) : Rat :=
  total (List.finRange D) (fun i => U i j * e i)

def energy {D R : Nat} (diag : Fin D → Rat)
    (U : Fin D → Fin R → Rat) (e : Fin D → Rat) : Rat :=
  total (List.finRange D) (fun i => diag i * (e i*e i)) +
    total (List.finRange R) (fun j => response U e j * response U e j)

/-- The cached rank-R response requires one multiply-add per mode for a
    coordinate move, not a full D-by-R recomputation. -/
theorem response_update {D R : Nat} (U : Fin D → Fin R → Rat)
    (e : Fin D → Rat) (d : Fin D) (delta : Rat) (j : Fin R) :
    response U (update e d delta) j =
      response U e j + delta * U d j := by
  unfold response
  calc
    _ = total (List.finRange D) (fun i =>
        U i j * e i + (if d = i then delta*U d j else 0)) := by
      apply total_congr (List.finRange D)
      intro i hi
      by_cases h : d = i
      · subst i
        simp only [update]
        grind +ring
      · simp only [update, if_neg h]
        grind +ring
    _ = total (List.finRange D) (fun i => U i j*e i) +
        total (List.finRange D) (fun i => if d = i then delta*U d j else 0) :=
      total_add _ _ _
    _ = _ := by rw [selected_total]

private theorem diagonal_update {D : Nat} (diag e : Fin D → Rat)
    (d : Fin D) (delta : Rat) :
    total (List.finRange D) (fun i =>
      diag i * (update e d delta i * update e d delta i)) =
      total (List.finRange D) (fun i => diag i*(e i*e i)) +
        2*delta*(diag d*e d) + (delta*delta)*diag d := by
  calc
    _ = total (List.finRange D) (fun i =>
        diag i*(e i*e i) +
          (if d = i then 2*delta*(diag d*e d)+(delta*delta)*diag d else 0)) := by
      apply total_congr (List.finRange D)
      intro i hi
      by_cases h : d = i
      · subst i
        simp only [update]
        grind +ring
      · simp only [update, if_neg h]
        grind +ring
    _ = total (List.finRange D) (fun i => diag i*(e i*e i)) +
        total (List.finRange D) (fun i =>
          if d = i then 2*delta*(diag d*e d)+(delta*delta)*diag d else 0) :=
      total_add _ _ _
    _ = _ := by rw [selected_total]; grind +ring

/-- Exact low-rank coordinate descent formula, derived from the actual
    finite sums and mode response update rather than assumed as a derivative.
    It holds for arbitrary rational diagonal entries; positivity is not
    needed for the algebraic identity. -/
theorem energy_update {D R : Nat} (diag : Fin D → Rat)
    (U : Fin D → Fin R → Rat) (e : Fin D → Rat)
    (d : Fin D) (delta : Rat) :
    energy diag U (update e d delta) - energy diag U e =
      2*delta * (diag d*e d +
        total (List.finRange R) (fun j => U d j * response U e j)) +
      (delta*delta) * (diag d +
        total (List.finRange R) (fun j => U d j*U d j)) := by
  have hresponse : total (List.finRange R) (fun j =>
      response U (update e d delta) j *
        response U (update e d delta) j) =
      total (List.finRange R) (fun j => response U e j*response U e j) +
        2*delta * total (List.finRange R)
          (fun j => U d j*response U e j) +
        (delta*delta)*total (List.finRange R) (fun j => U d j*U d j) := by
    calc
      _ = total (List.finRange R) (fun j =>
          response U e j*response U e j +
          (2*delta)*(U d j*response U e j) +
          (delta*delta)*(U d j*U d j)) := by
        apply total_congr (List.finRange R)
        intro j hj
        rw [response_update]
        grind +ring
      _ = _ := by rw [total_add, total_add, total_mul, total_mul]
  unfold energy
  rw [diagonal_update, hresponse]
  grind +ring

/-- A candidate code denotes its actual affine-grid residual. The source
    codeword representation and its rounding policy are outside this module. -/
def gridError (origin stride target : Rat) (code : Nat) : Rat :=
  origin + stride*(code : Rat) - target

def setCoordinate {D : Nat} (e : Fin D → Rat) (d : Fin D)
    (value : Rat) : Fin D → Rat :=
  fun i => if d = i then value else e i

theorem update_to_value {D : Nat} (e : Fin D → Rat) (d : Fin D)
    (value : Rat) :
    update e d (value-e d) = setCoordinate e d value := by
  funext i
  by_cases h : d = i
  · subst i
    simp only [update, setCoordinate]
    grind +ring
  · simp only [update, setCoordinate, if_neg h]

/-- The minimum of a nonempty finite list exists for an arbitrary rational
    objective; the proof makes no claim about a particular argmin algorithm. -/
theorem finite_minimum (xs : List I) (f : I → Rat) (hne : xs ≠ []) :
    ∃ best, best ∈ xs ∧ ∀ x ∈ xs, f best ≤ f x := by
  induction xs with
  | nil => contradiction
  | cons x xs ih =>
    by_cases htail : xs = []
    · subst xs
      refine ⟨x, by simp, ?_⟩
      intro y hy
      simp only [List.mem_singleton] at hy
      subst y
      exact Rat.le_refl
    · obtain ⟨best, hb, hmin⟩ := ih htail
      rcases Rat.le_total (a := f x) (b := f best) with hxb | hbx
      · refine ⟨x, by simp, ?_⟩
        intro y hy
        rcases List.mem_cons.mp hy with heq | hmem
        · subst y; exact Rat.le_refl
        · exact Rat.le_trans hxb (hmin y hmem)
      · refine ⟨best, by simp [hb], ?_⟩
        intro y hy
        rcases List.mem_cons.mp hy with heq | hmem
        · subst y; exact hbx
        · exact hmin y hmem

/-- If the current affine code is included in a finite grid, selecting an
    actual minimum cannot increase the exact low-rank energy. -/
theorem finite_grid_move {D R : Nat}
    (diag : Fin D → Rat) (U : Fin D → Fin R → Rat)
    (e : Fin D → Rat) (d : Fin D)
    (origin stride target : Rat) (codes : List Nat) (current : Nat)
    (hcurrent : e d = gridError origin stride target current)
    (hmem : current ∈ codes) :
    ∃ best ∈ codes,
      (∀ code ∈ codes,
        energy diag U (setCoordinate e d (gridError origin stride target best)) ≤
          energy diag U (setCoordinate e d (gridError origin stride target code))) ∧
      energy diag U (setCoordinate e d (gridError origin stride target best)) ≤
        energy diag U e := by
  have hne : codes ≠ [] := by
    intro heq
    subst codes
    simp at hmem
  obtain ⟨best, hb, hmin⟩ := finite_minimum codes
    (fun code => energy diag U
      (setCoordinate e d (gridError origin stride target code))) hne
  refine ⟨best, hb, hmin, ?_⟩
  have hsame : setCoordinate e d (gridError origin stride target current) = e := by
    funext i
    by_cases h : d = i
    · subst i
      change (if d = d then gridError origin stride target current else e d) = e d
      simp only [if_pos rfl]
      exact hcurrent.symm
    · simp only [setCoordinate, if_neg h]
  calc
    _ ≤ energy diag U (setCoordinate e d (gridError origin stride target current)) :=
      hmin current hmem
    _ = energy diag U e := by rw [hsame]

/-- The selected grid code is an actual single-coordinate increment, so
    the exact incremental formula applies to the chosen minimizing move. -/
theorem finite_grid_update {D R : Nat}
    (diag : Fin D → Rat) (U : Fin D → Fin R → Rat)
    (e : Fin D → Rat) (d : Fin D)
    (origin stride target : Rat) (codes : List Nat) (current : Nat)
    (hcurrent : e d = gridError origin stride target current)
    (hmem : current ∈ codes) :
    ∃ best ∈ codes,
      energy diag U
          (update e d (gridError origin stride target best-e d)) ≤
        energy diag U e := by
  obtain ⟨best, hb, _, hnonincrease⟩ :=
    finite_grid_move diag U e d origin stride target codes current hcurrent hmem
  refine ⟨best, hb, ?_⟩
  rw [update_to_value]
  exact hnonincrease

/-- Apply a finite list of coordinate transformations in order. -/
def sweep {D : Nat} (e : Fin D → Rat) :
    List ((Fin D → Rat) → (Fin D → Rat)) → (Fin D → Rat)
  | [] => e
  | move :: rest => sweep (move e) rest

/-- Local certificates refer to the actual state reached at each step;
    each may be supplied by `finite_grid_move` for the current affine code. -/
def Stepwise {D R : Nat}
    (diag : Fin D → Rat) (U : Fin D → Fin R → Rat)
    (e : Fin D → Rat) :
    List ((Fin D → Rat) → (Fin D → Rat)) → Prop
  | [] => True
  | move :: rest =>
      energy diag U (move e) ≤ energy diag U e ∧
        Stepwise diag U (move e) rest

/-- A finite path of locally checked moves preserves monotonicity without
    assuming that each move works at states it never visits. -/
theorem sweep_stepwise {D R : Nat}
    (diag : Fin D → Rat) (U : Fin D → Fin R → Rat)
    (e : Fin D → Rat) (moves : List ((Fin D → Rat) → (Fin D → Rat)))
    (h : Stepwise diag U e moves) :
    energy diag U (sweep e moves) ≤ energy diag U e := by
  induction moves generalizing e with
  | nil => exact Rat.le_refl
  | cons move rest ih =>
    have hstep : energy diag U (move e) ≤ energy diag U e := h.1
    have htail : Stepwise diag U (move e) rest := h.2
    change energy diag U (sweep (move e) rest) ≤ energy diag U e
    exact Rat.le_trans (ih (move e) htail) hstep

/-- The stronger all-state premise also composes, as a convenient corollary. -/
theorem sweep_nonincreasing {D R : Nat}
    (diag : Fin D → Rat) (U : Fin D → Fin R → Rat)
    (e : Fin D → Rat) (moves : List ((Fin D → Rat) → (Fin D → Rat)))
    (hmove : ∀ move ∈ moves, ∀ state,
      energy diag U (move state) ≤ energy diag U state) :
    energy diag U (sweep e moves) ≤ energy diag U e := by
  induction moves generalizing e with
  | nil => exact Rat.le_refl
  | cons move rest ih =>
    change energy diag U (sweep (move e) rest) ≤ energy diag U e
    have hrest : ∀ next ∈ rest, ∀ state,
        energy diag U (next state) ≤ energy diag U state := by
      intro next hn state
      exact hmove next (by simp [hn]) state
    exact Rat.le_trans (ih (move e) hrest) (hmove move (by simp) e)

end Kelana.LowRankCodeUpdate
