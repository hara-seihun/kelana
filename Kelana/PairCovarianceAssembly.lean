import Std

namespace Kelana.PairCovarianceAssembly

/-- All sums are finite and over exact rationals. The matrix-minorant,
    ratio-cone, and real-to-rational bridges are separate obligations. -/
def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind [ih ht]

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

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul_right (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i * a) = total xs f * a := by
  calc
    _ = total xs (fun i => a * f i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = a * total xs f := total_mul xs _ _
    _ = _ := Rat.mul_comm _ _

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

private theorem square_nonneg (z : Rat) : 0 ≤ z * z := by
  rcases Rat.le_total (a := 0) (b := z) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -z := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

private theorem mode_square (β μ r m : Rat)
    (hβ : 0 ≤ β) (hinv : β * μ = 1) :
    2 * m * r ≤ β * r * r + μ * m * m := by
  have hs := Rat.mul_nonneg hβ (square_nonneg (r - μ * m))
  have hcross := congrArg (fun v : Rat => v * r * m) hinv
  have htail := congrArg (fun v : Rat => v * μ * m * m) hinv
  grind +ring

private theorem shifted_square (d invD e p : Rat) (hinv : d * invD = 1) :
    d * (e + invD * p) * (e + invD * p) =
      d * e * e + 2 * p * e + invD * p * p := by
  have hcross := congrArg (fun v : Rat => v * e * p) hinv
  have htail := congrArg (fun v : Rat => v * invD * p * p) hinv
  grind +ring

def quadratic (coords : List I) (H : I → I → Rat) (e : I → Rat) : Rat :=
  total coords (fun i => total coords (fun j => e i * H i j * e j))

def mode (coords : List I) (V : I → K → Rat) (e : I → Rat) (k : K) : Rat :=
  total coords (fun i => V i k * e i)

def dualColumn (modes : List K) (V : I → K → Rat)
    (m : K → Rat) (i : I) : Rat :=
  total modes (fun k => V i k * m k)

/-- One shared mode dual, not a separately optimized mode per coordinate.
    The rational reciprocal witnesses are checked by multiplication, so no
    division or floating minimization enters the proof. -/
theorem dual_minorant_one_output
    (coords : List I) (modes : List K)
    (H : I → I → Rat) (V : I → K → Rat)
    (d invD : I → Rat) (β invβ : K → Rat)
    (w a : I → Rat) (m : K → Rat)
    (positiveβ : ∀ k ∈ modes, 0 ≤ β k)
    (d_inverse : ∀ i ∈ coords, d i * invD i = 1)
    (β_inverse : ∀ k ∈ modes, β k * invβ k = 1)
    (matrix_minorant :
      total coords (fun i => d i * (w i - a i) * (w i - a i)) +
        total modes (fun k => β k * mode coords V (fun i => w i - a i) k *
          mode coords V (fun i => w i - a i) k) ≤
        quadratic coords H (fun i => w i - a i)) :
    total coords (fun i =>
      d i * (w i + invD i * dualColumn modes V m i - a i) *
        (w i + invD i * dualColumn modes V m i - a i)) ≤
      quadratic coords H (fun i => w i - a i) +
        total coords (fun i => invD i * dualColumn modes V m i *
          dualColumn modes V m i) +
        total modes (fun k => invβ k * m k * m k) := by
  let e : I → Rat := fun i => w i - a i
  let p : I → Rat := dualColumn modes V m
  let r : K → Rat := mode coords V e
  have hcross : total modes (fun k => m k * r k) =
      total coords (fun i => p i * e i) := by
    calc
      _ = total modes (fun k => total coords (fun i =>
          m k * (V i k * e i))) := by
        apply total_congr modes; intro k hk
        exact (total_mul coords (m k) _).symm
      _ = total coords (fun i => total modes (fun k =>
          m k * (V i k * e i))) := total_comm modes coords _
      _ = total coords (fun i => total modes (fun k =>
          (V i k * m k) * e i)) := by
        apply total_congr coords; intro i hi
        apply total_congr modes; intro k hk; grind +ring
      _ = _ := by
        apply total_congr coords; intro i hi
        exact total_mul_right modes _ _
  have hm := total_le modes
    (fun k => 2 * (m k * r k))
    (fun k => β k * r k * r k + invβ k * m k * m k)
    (by
      intro k hk
      have h := mode_square (β k) (invβ k) (r k) (m k)
        (positiveβ k hk) (β_inverse k hk)
      grind +ring)
  have htwice : total modes (fun k => 2 * (m k * r k)) =
      2 * total coords (fun i => p i * e i) := by
    rw [total_mul, hcross]
  rw [htwice, total_add] at hm
  have hshift :
      total coords (fun i => d i * (e i + invD i * p i) *
        (e i + invD i * p i)) =
      total coords (fun i => d i * e i * e i) +
        2 * total coords (fun i => p i * e i) +
        total coords (fun i => invD i * p i * p i) := by
    calc
      _ = total coords (fun i =>
          d i * e i * e i + 2 * (p i * e i) + invD i * p i * p i) := by
        apply total_congr coords; intro i hi
        have h := shifted_square (d i) (invD i) (e i) (p i)
          (d_inverse i hi)
        grind +ring
      _ = _ := by rw [total_add, total_add, total_mul]
  have hbase : total coords (fun i => d i * e i * e i) +
      total modes (fun k => β k * r k * r k) ≤ quadratic coords H e :=
    matrix_minorant
  have hform : total coords (fun i =>
      d i * (w i + invD i * p i - a i) *
        (w i + invD i * p i - a i)) =
      total coords (fun i => d i * (e i + invD i * p i) *
        (e i + invD i * p i)) := by
    apply total_congr coords; intro i hi; grind +ring
  rw [hform, hshift]
  grind

/-- Finite shared-mode assembly across every output. Both penalties are
    summed once over their own index sets: the coordinate term over *all*
    inputs, the mode term over shared modes. -/
theorem shared_dual_all_outputs (outputs : List O) (coords : List I)
    (modes : List K) (H : I → I → Rat) (V : I → K → Rat)
    (d invD : I → Rat) (β invβ : K → Rat)
    (w a : O → I → Rat) (m : K → O → Rat)
    (positiveβ : ∀ k ∈ modes, 0 ≤ β k)
    (d_inverse : ∀ i ∈ coords, d i * invD i = 1)
    (β_inverse : ∀ k ∈ modes, β k * invβ k = 1)
    (matrix_minorant : ∀ o ∈ outputs,
      total coords (fun i => d i * (w o i - a o i) * (w o i - a o i)) +
        total modes (fun k => β k * mode coords V (fun i => w o i - a o i) k *
          mode coords V (fun i => w o i - a o i) k) ≤
        quadratic coords H (fun i => w o i - a o i)) :
    total coords (fun i => total outputs (fun o =>
      d i * (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i) *
        (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i))) ≤
      total outputs (fun o => quadratic coords H (fun i => w o i - a o i)) +
      total coords (fun i => total outputs (fun o =>
        invD i * dualColumn modes V (fun k => m k o) i *
          dualColumn modes V (fun k => m k o) i)) +
      total modes (fun k => total outputs (fun o => invβ k * m k o * m k o)) := by
  have ho := total_le outputs
    (fun o => total coords (fun i =>
      d i * (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i) *
        (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i)))
    (fun o => quadratic coords H (fun i => w o i - a o i) +
      total coords (fun i => invD i * dualColumn modes V (fun k => m k o) i *
        dualColumn modes V (fun k => m k o) i) +
      total modes (fun k => invβ k * m k o * m k o))
    (by
      intro o ho
      exact dual_minorant_one_output coords modes H V d invD β invβ
        (w o) (a o) (fun k => m k o)
        positiveβ d_inverse β_inverse (matrix_minorant o ho))
  rw [total_add, total_add] at ho
  have hfirst := total_comm outputs coords
    (fun o i => d i * (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i) *
      (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i))
  have hsecond := total_comm outputs coords
    (fun o i => invD i * dualColumn modes V (fun k => m k o) i *
      dualColumn modes V (fun k => m k o) i)
  have hthird := total_comm outputs modes
    (fun o k => invβ k * m k o * m k o)
  rw [hfirst, hsecond, hthird] at ho
  exact ho

private theorem total_perm (f : I → Rat) {xs ys : List I}
    (h : xs.Perm ys) : total xs f = total ys f := by
  induction h with
  | nil => rfl
  | cons i h ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind
  | swap i j xs =>
    simp only [total, List.map_cons, List.sum_cons]
    grind
  | trans _ _ ih₁ ih₂ => exact ih₁.trans ih₂

private theorem total_append (xs ys : List I) (f : I → Rat) :
    total (xs ++ ys) f = total xs f + total ys f := by
  simp [total, List.map_append, List.sum_append]

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

def vertices (edges : List (I × I)) : List I :=
  edges.flatMap fun e => [e.1, e.2]

private theorem total_vertices (edges : List (I × I)) (f : I → Rat) :
    total (vertices edges) f =
      total edges (fun e => f e.1 + f e.2) := by
  induction edges with
  | nil => rfl
  | cons e edges ih =>
    simp only [vertices, List.flatMap_cons, total,
      List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_constant (xs : List I) (c : Rat) :
    total xs (fun _ => c) = (xs.length : Rat) * c := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons, List.length_cons,
      Rat.natCast_add] at ih ⊢
    grind +ring

/-- Disjoint matching charging with nonpositive vertex prices. A permutation
    of the listed coordinates into pair endpoints plus unmatched coordinates is
    an explicit combinatorial witness: it prevents charging any coordinate
    twice. No optimization or LP duality theorem is assumed. -/
theorem matching_charge (coords : List I) (edges : List (I × I))
    (unmatched : List I) (square vertexPrice : I → Rat)
    (pairFloor : I × I → Rat) (cardPrice : Rat)
    (partition : coords.Perm (vertices edges ++ unmatched))
    (unmatched_square_nonneg : ∀ i ∈ unmatched, 0 ≤ square i)
    (unmatched_price_nonpos : ∀ i ∈ unmatched, vertexPrice i ≤ 0)
    (edge_square_floor : ∀ e ∈ edges,
      pairFloor e ≤ square e.1 + square e.2)
    (edge_price_floor : ∀ e ∈ edges,
      vertexPrice e.1 + vertexPrice e.2 + cardPrice ≤ pairFloor e) :
    total coords vertexPrice + (edges.length : Rat) * cardPrice ≤
      total coords square := by
  have hsquare := total_perm square partition
  have hprice := total_perm vertexPrice partition
  rw [total_append, total_vertices] at hsquare hprice
  have hunmatched := total_nonneg unmatched square unmatched_square_nonneg
  have hnegative : total unmatched vertexPrice ≤ 0 := by
    have h := total_le unmatched vertexPrice (fun _ => 0)
      (by intro i hi; exact unmatched_price_nonpos i hi)
    have hz := total_zero unmatched
    rw [hz] at h
    exact h
  have heprice := total_le edges
    (fun e => vertexPrice e.1 + vertexPrice e.2 + cardPrice)
    pairFloor edge_price_floor
  have hesquare := total_le edges pairFloor
    (fun e => square e.1 + square e.2) edge_square_floor
  have hsumprice :
      total edges (fun e => vertexPrice e.1 + vertexPrice e.2 + cardPrice) =
        total edges (fun e => vertexPrice e.1 + vertexPrice e.2) +
          (edges.length : Rat) * cardPrice := by
    rw [total_add, total_constant]
  rw [hsumprice] at heprice
  grind

/-- A scalar response lower bound transfers through the matching theorem.
    The coordinate penalty is summed over *all* coordinates, including every
    unmatched one; the shared-mode penalty is paid exactly once. -/
theorem assemble_floor (coords : List I) (edges : List (I × I))
    (unmatched : List I) (square coordPenalty vertexPrice : I → Rat)
    (modePenalty : List Rat) (pairFloor : I × I → Rat)
    (cardPrice response : Rat)
    (partition : coords.Perm (vertices edges ++ unmatched))
    (unmatched_square_nonneg : ∀ i ∈ unmatched, 0 ≤ square i)
    (unmatched_price_nonpos : ∀ i ∈ unmatched, vertexPrice i ≤ 0)
    (edge_square_floor : ∀ e ∈ edges,
      pairFloor e ≤ square e.1 + square e.2)
    (edge_price_floor : ∀ e ∈ edges,
      vertexPrice e.1 + vertexPrice e.2 + cardPrice ≤ pairFloor e)
    (minorant : total coords square ≤
      response + total coords coordPenalty + modePenalty.sum) :
    total coords vertexPrice + (edges.length : Rat) * cardPrice -
      total coords coordPenalty - modePenalty.sum ≤ response := by
  have hmatching := matching_charge coords edges unmatched square vertexPrice
    pairFloor cardPrice partition unmatched_square_nonneg unmatched_price_nonpos
    edge_square_floor edge_price_floor
  grind

def shiftedEnergy (outputs : List O) (modes : List K)
    (V : I → K → Rat) (d invD : I → Rat)
    (w a : O → I → Rat) (m : K → O → Rat) (i : I) : Rat :=
  total outputs (fun o =>
    d i * (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i) *
      (w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i))

def coordinatePenalty (outputs : List O) (modes : List K)
    (V : I → K → Rat) (invD : I → Rat) (m : K → O → Rat) (i : I) : Rat :=
  total outputs (fun o => invD i * dualColumn modes V (fun k => m k o) i *
    dualColumn modes V (fun k => m k o) i)

def sharedModePenalty (outputs : List O) (invβ : K → Rat)
    (m : K → O → Rat) (k : K) : Rat :=
  total outputs (fun o => invβ k * m k o * m k o)

/-- General rational certificate assembly. The only non-algebraic hypotheses
    are the quadratic matrix minorant, the pair floor (e.g. exact 2×2 cone),
    and the observed response bound. All shared-mode completion, coordinate
    shifting, output/mode Fubini, unmatched nonnegativity, and disjoint matching
    charging are proved above rather than included in the final inequality.
    The coordinate penalty is paid across the entire coordinate list, never
    only at paired endpoints. No real readout, PSD checker, or ratio cone is
    claimed to be implemented by this rational theorem. -/
theorem certified_disjoint_pair_floor
    (outputs : List O) (coords : List I) (modes : List K)
    (H : I → I → Rat) (V : I → K → Rat)
    (d invD : I → Rat) (β invβ : K → Rat)
    (w a : O → I → Rat) (m : K → O → Rat)
    (edges : List (I × I)) (unmatched : List I)
    (pairFloor : I × I → Rat) (vertexPrice : I → Rat)
    (cardPrice response : Rat)
    (partition : coords.Perm (vertices edges ++ unmatched))
    (positiveD : ∀ i ∈ coords, 0 ≤ d i)
    (positiveβ : ∀ k ∈ modes, 0 ≤ β k)
    (d_inverse : ∀ i ∈ coords, d i * invD i = 1)
    (β_inverse : ∀ k ∈ modes, β k * invβ k = 1)
    (matrix_minorant : ∀ o ∈ outputs,
      total coords (fun i => d i * (w o i - a o i) * (w o i - a o i)) +
        total modes (fun k => β k * mode coords V (fun i => w o i - a o i) k *
          mode coords V (fun i => w o i - a o i) k) ≤
        quadratic coords H (fun i => w o i - a o i))
    (observed_response :
      total outputs (fun o => quadratic coords H (fun i => w o i - a o i)) ≤ response)
    (unmatched_price_nonpos : ∀ i ∈ unmatched, vertexPrice i ≤ 0)
    (edge_square_floor : ∀ e ∈ edges,
      pairFloor e ≤ shiftedEnergy outputs modes V d invD w a m e.1 +
        shiftedEnergy outputs modes V d invD w a m e.2)
    (edge_price_floor : ∀ e ∈ edges,
      vertexPrice e.1 + vertexPrice e.2 + cardPrice ≤ pairFloor e) :
    total coords vertexPrice + (edges.length : Rat) * cardPrice -
      total coords (coordinatePenalty outputs modes V invD m) -
      total modes (sharedModePenalty outputs invβ m) ≤ response := by
  have hdual := shared_dual_all_outputs outputs coords modes H V d invD β invβ
    w a m positiveβ d_inverse β_inverse matrix_minorant
  have hminorant :
      total coords (shiftedEnergy outputs modes V d invD w a m) ≤
        response + total coords (coordinatePenalty outputs modes V invD m) +
          total modes (sharedModePenalty outputs invβ m) := by
    unfold shiftedEnergy coordinatePenalty sharedModePenalty
    grind
  have hsquare : ∀ i ∈ unmatched,
      0 ≤ shiftedEnergy outputs modes V d invD w a m i := by
    intro i hi
    have hmember : i ∈ coords := by
      have h := (List.Perm.mem_iff (a := i) partition)
      have hr : i ∈ vertices edges ++ unmatched := List.mem_append.mpr (Or.inr hi)
      exact h.mpr hr
    unfold shiftedEnergy
    apply total_nonneg outputs
    intro o ho
    let z := w o i + invD i * dualColumn modes V (fun k => m k o) i - a o i
    have hs := Rat.mul_nonneg (positiveD i hmember) (square_nonneg z)
    simpa only [Rat.mul_assoc] using hs
  exact assemble_floor coords edges unmatched
    (shiftedEnergy outputs modes V d invD w a m)
    (coordinatePenalty outputs modes V invD m)
    vertexPrice (modes.map (sharedModePenalty outputs invβ m))
    pairFloor cardPrice response partition hsquare unmatched_price_nonpos
    edge_square_floor edge_price_floor (by
      simpa only [total] using hminorant)

end Kelana.PairCovarianceAssembly
