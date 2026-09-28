import Std

namespace Kelana.CovarianceCompletion

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

private theorem total_map (xs : List I) (f : I → J) (g : J → Rat) :
    total (xs.map f) g = total xs (fun i => g (f i)) := by
  simp only [total, List.map_map, Function.comp_def]

private theorem total_append (xs ys : List I) (f : I → Rat) :
    total (xs ++ ys) f = total xs f + total ys f := by
  simp [total, List.map_append, List.sum_append]

private theorem square_nonneg (z : Rat) : 0 ≤ z * z := by
  rcases Rat.le_total (a := 0) (b := z) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -z := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

private theorem square_zero (z : Rat) (hz : z*z = 0) : z = 0 := by
  rcases Rat.le_total (a := 0) (b := z) with h | h
  · have hp := Rat.mul_nonneg h h
    grind +ring
  · have hn : 0 ≤ -z := by grind
    grind +ring

private theorem total_zero (xs : List I) :
    total xs (fun _ => (0 : Rat)) = 0 := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    change 0 + total xs (fun _ => (0 : Rat)) = 0
    grind

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

private theorem total_zero_iff (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) :
    total xs f = 0 ↔ ∀ i ∈ xs, f i = 0 := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    have hr := total_nonneg xs f ht
    change f i + total xs f = 0 ↔ ∀ j ∈ i :: xs, f j = 0
    constructor
    · intro h j hj
      have hi0 : f i = 0 := by grind
      have ht0 : total xs f = 0 := by grind
      rcases List.mem_cons.mp hj with rfl | hj
      · exact hi0
      · exact (ih ht).mp ht0 j hj
    · intro h
      have hi0 := h i (by simp)
      have ht0 : ∀ j ∈ xs, f j = 0 := by grind
      have hs := (ih ht).mpr ht0
      grind

/-- Inner product of finite response vectors. -/
def gram (outputs : List O) (φ : I → O → Rat) (i j : I) : Rat :=
  total outputs (fun o => φ i o * φ j o)

def quadratic (indices : List I) (M : I → I → Rat) (v : I → Rat) : Rat :=
  total indices (fun i => total indices (fun j => v i * M i j * v j))

def response (indices : List I) (φ : I → O → Rat)
    (v : I → Rat) (o : O) : Rat :=
  total indices (fun i => v i * φ i o)

def norm2 (outputs : List O) (v : O → Rat) : Rat :=
  total outputs (fun o => v o * v o)

/-- Finite Gram realization, with the matrix entries genuinely expanded as
    sums over outputs rather than assumed to represent a quadratic norm. -/
theorem gram_quadratic (indices : List I) (outputs : List O)
    (φ : I → O → Rat) (v : I → Rat) :
    quadratic indices (gram outputs φ) v =
      norm2 outputs (response indices φ v) := by
  unfold quadratic gram norm2 response
  calc
    _ = total indices (fun i => total indices (fun j =>
        total outputs (fun o => (v i * φ i o) * (v j * φ j o)))) := by
      apply total_congr indices; intro i hi
      apply total_congr indices; intro j hj
      calc
        _ = total outputs (fun o => v i * (φ i o * φ j o) * v j) := by
          rw [← total_mul, ← total_mul_right]
        _ = _ := by apply total_congr outputs; intro o ho; grind +ring
    _ = total outputs (fun o =>
        total indices (fun i => v i * φ i o) *
        total indices (fun j => v j * φ j o)) := by
      calc
        _ = total indices (fun i => total outputs (fun o =>
            total indices (fun j => (v i * φ i o) * (v j * φ j o)))) := by
          apply total_congr indices; intro i hi
          exact total_comm indices outputs _
        _ = total outputs (fun o => total indices (fun i =>
            total indices (fun j => (v i * φ i o) * (v j * φ j o)))) :=
          total_comm indices outputs _
        _ = _ := by
          apply total_congr outputs; intro o ho
          calc
            _ = total indices (fun i => (v i * φ i o) *
                  total indices (fun j => v j * φ j o)) := by
                apply total_congr indices; intro i hi
                exact total_mul indices _ _
            _ = _ := total_mul_right indices _ _
    _ = _ := rfl

/-- One response to a supported-coordinate basis is imported into an unseen
    coordinate through the prior conditional coefficient B. -/
def transported (supported : List R) (A : R → O → Rat)
    (B : R → N → Rat) (n : N) (o : O) : Rat :=
  total supported (fun r => B r n * A r o)

def combinedIndices (supported : List R) (unseen : List N) : List (R ⊕ N) :=
  supported.map Sum.inl ++ unseen.map Sum.inr

def supportedResponse (supported : List R) (A : R → O → Rat)
    (B : R → N → Rat) : R ⊕ N → O → Rat
  | Sum.inl r => A r
  | Sum.inr n => transported supported A B n

def unseenResponse (C : N → P → Rat) : R ⊕ N → P → Rat
  | Sum.inl _ => fun _ => 0
  | Sum.inr n => C n

/-- The block completion M is a sum of two explicit rational Gram matrices:
    one for [A, AB], and one for [0, C]. It is congruent to the supported and
    prior-conditional Schur blocks without requiring an inverse calculation
    inside Lean. B and C are the supplied exact rational witnesses. -/
def completionGram (supported : List R) (out : List O) (priorOut : List P)
    (A : R → O → Rat) (B : R → N → Rat) (C : N → P → Rat) :
    (R ⊕ N) → (R ⊕ N) → Rat :=
  fun i j => gram out (supportedResponse supported A B) i j +
    gram priorOut (unseenResponse C) i j

private theorem quadratic_add (indices : List I) (M T : I → I → Rat) (v : I → Rat) :
    quadratic indices (fun i j => M i j + T i j) v =
      quadratic indices M v + quadratic indices T v := by
  unfold quadratic
  calc
    _ = total indices (fun i => total indices (fun j => v i * M i j * v j) +
      total indices (fun j => v i * T i j * v j)) := by
      apply total_congr indices; intro i hi
      calc
        _ = total indices (fun j => v i * M i j * v j + v i * T i j * v j) := by
          apply total_congr indices; intro j hj; grind +ring
        _ = _ := total_add indices _ _
    _ = _ := total_add indices _ _

private theorem response_split (supported : List R) (unseen : List N)
    (φ : (R ⊕ N) → O → Rat) (r : R → Rat) (n : N → Rat) (o : O) :
    response (combinedIndices supported unseen) φ
      (fun z => z.elim r n) o =
      response supported (fun i => φ (Sum.inl i)) r o +
      response unseen (fun j => φ (Sum.inr j)) n o := by
  unfold response combinedIndices
  rw [total_append, total_map, total_map]
  rfl

/-- Complete block factorization for arbitrary finite rational supported and
    unseen coefficients. The transported supported coefficient at index i is
    `r i + Σ_n B i n * n n`, i.e. r+Bᵀn. This is an identity of an actual
    block Gram quadratic and two realized response energies. -/
theorem completed_energy (supported : List R) (unseen : List N)
    (out : List O) (priorOut : List P)
    (A : R → O → Rat) (B : R → N → Rat) (C : N → P → Rat)
    (r : R → Rat) (n : N → Rat) :
    quadratic (combinedIndices supported unseen)
      (completionGram supported out priorOut A B C)
      (fun z => z.elim r n) =
      norm2 out (fun o => response supported A
        (fun i => r i + total unseen (fun j => B i j * n j)) o) +
      norm2 priorOut (response unseen C n) := by
  let indices := combinedIndices supported unseen
  let v : R ⊕ N → Rat := fun z => z.elim r n
  let φ := supportedResponse supported A B
  let ψ : R ⊕ N → P → Rat := unseenResponse C
  have hfirst := gram_quadratic indices out φ v
  have hsecond := gram_quadratic indices priorOut ψ v
  have hφ : ∀ o,
      response indices φ v o = response supported A
        (fun i => r i + total unseen (fun j => B i j * n j)) o := by
    intro o
    rw [response_split]
    change response supported A r o +
      total unseen (fun j => n j * transported supported A B j o) = _
    have htransport : total unseen (fun j => n j * transported supported A B j o) =
        total supported (fun i =>
          (total unseen (fun j => B i j * n j)) * A i o) := by
      calc
        _ = total unseen (fun j => total supported (fun i =>
            (n j * B i j) * A i o)) := by
          apply total_congr unseen; intro j hj
          unfold transported
          rw [← total_mul]
          apply total_congr supported; intro i hi; grind +ring
        _ = total supported (fun i => total unseen (fun j =>
              (n j * B i j) * A i o)) := total_comm unseen supported _
        _ = _ := by
          apply total_congr supported; intro i hi
          rw [total_mul_right]
          apply congrArg (fun z : Rat => z * A i o)
          apply total_congr unseen; intro j hj; exact Rat.mul_comm _ _
    rw [htransport]
    unfold response
    rw [← total_add]
    apply total_congr supported; intro i hi; grind +ring
  have hψ : ∀ p, response indices ψ v p = response unseen C n p := by
    intro p
    rw [response_split]
    change total supported (fun i => r i * 0) + response unseen C n p = _
    have hz : total supported (fun i => r i * (0 : Rat)) = 0 := by
      rw [show (fun i => r i * (0 : Rat)) = (fun _ => 0) from
        funext (fun i => by simp), total_zero]
    grind
  unfold completionGram
  rw [quadratic_add]
  change quadratic indices (gram out φ) v +
    quadratic indices (gram priorOut ψ) v = _
  rw [hfirst, hsecond]
  congr 1
  · apply total_congr out; intro o ho; rw [hφ]
  · apply total_congr priorOut; intro p hp; rw [hψ]

/-- PSD follows from the exhibited response maps; it does not assume PSD of
    the source matrix or of an unexamined prior. -/
theorem completed_psd (supported : List R) (unseen : List N)
    (out : List O) (priorOut : List P)
    (A : R → O → Rat) (B : R → N → Rat) (C : N → P → Rat)
    (r : R → Rat) (n : N → Rat) :
    0 ≤ quadratic (combinedIndices supported unseen)
      (completionGram supported out priorOut A B C)
      (fun z => z.elim r n) := by
  rw [completed_energy]
  have hA := total_nonneg out (fun o =>
    response supported A (fun i => r i + total unseen (fun j => B i j * n j)) o *
    response supported A (fun i => r i + total unseen (fun j => B i j * n j)) o)
    (by intro o ho; exact square_nonneg _)
  have hC := total_nonneg priorOut
    (fun p => response unseen C n p * response unseen C n p)
    (by intro p hp; exact square_nonneg _)
  unfold norm2
  grind

/-- A vector confined to the observed support has exactly its observed Gram
    energy, independently of B and C. -/
theorem supported_exact (supported : List R) (unseen : List N)
    (out : List O) (priorOut : List P)
    (A : R → O → Rat) (B : R → N → Rat) (C : N → P → Rat)
    (r : R → Rat) :
    quadratic (combinedIndices supported unseen)
      (completionGram supported out priorOut A B C)
      (fun z => z.elim r (fun _ => 0)) =
      quadratic supported (gram out A) r := by
  rw [completed_energy, gram_quadratic]
  have hz : ∀ i, total unseen (fun j => B i j * (0 : Rat)) = 0 := by
    intro i
    rw [show (fun j => B i j * (0 : Rat)) = (fun _ => 0) from
      funext (fun j => by simp), total_zero]
  have hc : ∀ p, response unseen C (fun _ => (0 : Rat)) p = 0 := by
    intro p
    unfold response
    rw [show (fun j => (0 : Rat) * C j p) = (fun _ => 0) from
      funext (fun j => by simp), total_zero]
  unfold norm2
  have hprior : total priorOut (fun p => response unseen C (fun _ => (0 : Rat)) p *
      response unseen C (fun _ => (0 : Rat)) p) = 0 := by
    rw [show (fun p => response unseen C (fun _ => (0 : Rat)) p *
      response unseen C (fun _ => (0 : Rat)) p) = (fun _ => 0) from
      funext (fun p => by simp [hc p]), total_zero]
  rw [hprior]
  have he : (fun i => r i + total unseen (fun j => B i j * (0 : Rat))) = r := by
    funext i; grind [hz i]
  rw [he]
  grind

/-- Exact kernel characterization: zero completed energy is equivalent to
    vanishing of both realized response maps on every listed output. It does
    not assert that the coefficient vector itself is zero. -/
theorem completed_kernel (supported : List R) (unseen : List N)
    (out : List O) (priorOut : List P)
    (A : R → O → Rat) (B : R → N → Rat) (C : N → P → Rat)
    (r : R → Rat) (n : N → Rat) :
    quadratic (combinedIndices supported unseen)
      (completionGram supported out priorOut A B C)
      (fun z => z.elim r n) = 0 ↔
    (∀ o ∈ out, response supported A
      (fun i => r i + total unseen (fun j => B i j * n j)) o = 0) ∧
    (∀ p ∈ priorOut, response unseen C n p = 0) := by
  rw [completed_energy]
  let x : O → Rat := fun o => response supported A
    (fun i => r i + total unseen (fun j => B i j * n j)) o
  let y : P → Rat := response unseen C n
  have hx := total_nonneg out (fun o => x o * x o)
    (by intro o ho; exact square_nonneg _)
  have hy := total_nonneg priorOut (fun p => y p * y p)
    (by intro p hp; exact square_nonneg _)
  have hzx := total_zero_iff out (fun o => x o * x o)
    (by intro o ho; exact square_nonneg _)
  have hzy := total_zero_iff priorOut (fun p => y p * y p)
    (by intro p hp; exact square_nonneg _)
  unfold norm2
  constructor
  · intro h
    have h₁ : total out (fun o => x o * x o) = 0 := by grind
    have h₂ : total priorOut (fun p => y p * y p) = 0 := by grind
    exact ⟨(by intro o ho; exact square_zero _ ((hzx.mp h₁) o ho)),
      (by intro p hp; exact square_zero _ ((hzy.mp h₂) p hp))⟩
  · rintro ⟨h₁, h₂⟩
    have hz₁ := hzx.mpr (by
      intro o ho
      have ho0 : x o = 0 := h₁ o ho
      rw [ho0]; simp)
    have hz₂ := hzy.mpr (by
      intro p hp
      have hp0 : y p = 0 := h₂ p hp
      rw [hp0]; simp)
    grind

/-- Exact 2D witness: H_R=4, prior G=[[1,4/5],[4/5,1]],
    B=4/5, S_G=9/25. Its completion has the declared cross block and unseen
    diagonal. The two errors reverse order relative to an observed-only metric:
    (0,1/5) has zero supported error but completed energy 73/625;
    (1/10,-1/5) has supported error 1/25 but completed energy 18/625.
    These arithmetic facts alone do not assert anything about a true unseen
    producer moment or a statistical distribution. -/
theorem two_dimensional_witness :
    let A : Unit → Unit → Rat := fun _ _ => 2
    let B : Unit → Unit → Rat := fun _ _ => 4 / 5
    let C : Unit → Unit → Rat := fun _ _ => 3 / 5
    let M := completionGram [()] [()] [()] A B C
    M (Sum.inl ()) (Sum.inl ()) = 4 ∧
    M (Sum.inl ()) (Sum.inr ()) = 16 / 5 ∧
    M (Sum.inr ()) (Sum.inr ()) = 73 / 25 ∧
    quadratic (combinedIndices [()] [()]) M
      (fun z => z.elim (fun _ => 0) (fun _ => 1 / 5)) = 73 / 625 ∧
    quadratic (combinedIndices [()] [()]) M
      (fun z => z.elim (fun _ => 1 / 10) (fun _ => -(1 / 5))) = 18 / 625 ∧
    quadratic [()] (gram [()] A) (fun _ => 0) = 0 ∧
    quadratic [()] (gram [()] A) (fun _ => 1 / 10) = 1 / 25 := by
  decide +kernel

end Kelana.CovarianceCompletion
