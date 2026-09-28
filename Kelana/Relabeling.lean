import Kelana.Composition

/-!
# Simultaneous relabeling of a family of transitions

One bijection relabels a whole labelled family at once, or none does.  That is
strictly stronger than relabeling each operation separately, and it is the
demand that lets a region run many operations between one encode and one
decode.

The executable search, the exhaustive census and the priced boundary map live
in `research/discovery/relabeling/`.  This file carries the statements the
search relies on, and the concrete obstructions it reports.

Nothing here is a cost claim.  A relabeling that exists may still be expensive
to apply, and the last section shows a family whose relabeling provably cannot
be written as a bit matrix.
-/

namespace Kelana.Relabeling

/-- `p` relabels the transition `f` into the transition `g`. -/
def Conjugates {S T : Type} (p : S → T) (f : S → S) (g : T → T) : Prop :=
  ∀ s, p (f s) = g (p s)

/-- The same bijection relabels every member of the family. -/
def ConjugatesAll {S T I : Type} (p : S → T) (f : I → S → S) (g : I → T → T) : Prop :=
  ∀ i, Conjugates p (f i) (g i)

instance {n m : Nat} (p : Fin n → Fin m) (f : Fin n → Fin n) (g : Fin m → Fin m) :
    Decidable (Conjugates p f g) :=
  inferInstanceAs (Decidable (∀ s, p (f s) = g (p s)))

/-! ## What a shared relabeling buys -/

/-- Relabeling composes: a conjugated pair conjugates the composite. -/
theorem conjugates_comp {S T : Type} {p : S → T} {f₁ f₂ : S → S} {g₁ g₂ : T → T}
    (h₁ : Conjugates p f₁ g₁) (h₂ : Conjugates p f₂ g₂) :
    Conjugates p (f₂ ∘ f₁) (g₂ ∘ g₁) := by
  intro s
  simp only [Function.comp_apply, h₁ s, h₂ (f₁ s)]

theorem conjugates_id {S T : Type} (p : S → T) : Conjugates p id id := fun _ => rfl

/-- Every word in the family is conjugated by the same bijection.

This is the content of the claim that one decode can serve many operations:
the word is arbitrary and the relabeling does not change with it. -/
theorem conjugates_execute {S T I : Type} {p : S → T} {f : I → S → S} {g : I → T → T}
    (h : ConjugatesAll p f g) :
    ∀ (word : List I) (s : S),
      p (Kelana.Composition.execute (word.map f) s)
        = Kelana.Composition.execute (word.map g) (p s) := by
  intro word
  induction word with
  | nil => intro s; rfl
  | cons i rest ih =>
    intro s
    simp only [List.map_cons, Kelana.Composition.execute]
    rw [← h i s]
    exact ih (f i s)

/-- One encode, the whole region, one decode.  Intermediate states are never
converted back, and the boundary count does not grow with the region. -/
theorem region_needs_one_boundary {S T I : Type} {p : S → T} {q : T → S}
    {f : I → S → S} {g : I → T → T}
    (h : ConjugatesAll p f g) (inv : ∀ s, q (p s) = s) :
    ∀ (word : List I) (s : S),
      q (Kelana.Composition.execute (word.map g) (p s))
        = Kelana.Composition.execute (word.map f) s := by
  intro word s
  rw [← conjugates_execute h word s, inv]

/-- Conjugacy is `Simulates` with the graph of `p` as the relation, so a
relabeled region composes with the rest of Kelana's representation laws. -/
theorem simulates_of_conjugates {S T : Type} {p : S → T} {f : S → S} {g : T → T}
    (h : Conjugates p f g) :
    Kelana.Composition.Simulates (fun s t => p s = t) (fun s t => p s = t) f g := by
  intro s t hst
  rw [← hst]
  exact h s

/-- Adding an operation can only remove relabelings, never create one.  A
search may start from the producers and add consumers, and the surviving
witness set is monotone. -/
theorem conjugates_all_mono {S T I J : Type} {p : S → T} {f : I → S → S} {g : I → T → T}
    (sub : J → I) (h : ConjugatesAll p f g) :
    ConjugatesAll p (fun j => f (sub j)) (fun j => g (sub j)) :=
  fun j => h (sub j)

/-! ## Necessary conditions

Each of these is preserved by relabeling, so a mismatch rejects. Matching these
particular invariants does not accept: `gl32_points_planes_not_conjugate`
exhibits separately conjugate generators with no simultaneous relabeling.
The executable pair-refinement screen does distinguish that pair. -/

/-- Fixed states go to fixed states. -/
theorem fixed_point_transport {S T : Type} {p : S → T} {f : S → S} {g : T → T}
    (h : Conjugates p f g) {s : S} (hs : f s = s) : g (p s) = p s := by
  rw [← h s, hs]

/-- Commutation is preserved, so the commutation pattern is a screen. -/
theorem commutation_transport {S T : Type} {p : S → T} {f₁ f₂ : S → S} {g₁ g₂ : T → T}
    (h₁ : Conjugates p f₁ g₁) (h₂ : Conjugates p f₂ g₂)
    (comm : ∀ s, f₁ (f₂ s) = f₂ (f₁ s)) :
    ∀ s, g₁ (g₂ (p s)) = g₂ (g₁ (p s)) := by
  intro s
  rw [← h₂ s, ← h₁ (f₂ s), ← h₁ s, ← h₂ (f₁ s), comm s]

/-- Collisions carry across, so preimage shapes are a screen.  The converse
fails: matching collision counts do not produce a relabeling. -/
theorem collision_transport {S T : Type} {p : S → T} {f : S → S} {g : T → T}
    (h : Conjugates p f g) {a b : S} (hab : f a = f b) : g (p a) = g (p b) := by
  rw [← h a, ← h b, hab]

/-! ## Tables

Transitions are given by their tables.  `Fin n` indexing keeps every statement
below decidable without leaving Lean's standard library. -/

def t3 (l : List (Fin 3)) : Fin 3 → Fin 3 := fun x => l.getD x.val 0
def t7 (l : List (Fin 7)) : Fin 7 → Fin 7 := fun x => l.getD x.val 0
def t8 (l : List (Fin 8)) : Fin 8 → Fin 8 := fun x => l.getD x.val 0

/-! ## Separate relabelings are strictly weaker

Two labelled copies of the 3-cycle, against a 3-cycle paired with its square.
Each operation is conjugate on its own; no map does both. -/

def succ3 : Fin 3 → Fin 3 := t3 [1, 2, 0]
def twice3 : Fin 3 → Fin 3 := t3 [2, 0, 1]

theorem each_operation_separately_conjugate :
    Conjugates (t3 [0, 1, 2]) succ3 succ3 ∧ Conjugates (t3 [0, 2, 1]) succ3 twice3 := by
  constructor <;> decide

/-- No single map does both at once, bijective or not.  The first constraint
already pins `p 1`, and the second contradicts it. -/
theorem family_not_conjugate :
    ¬ ∃ p : Fin 3 → Fin 3, Conjugates p succ3 succ3 ∧ Conjugates p succ3 twice3 := by
  rintro ⟨p, hs, ht⟩
  have one : p 1 = succ3 (p 0) := hs 0
  have two : p 1 = twice3 (p 0) := ht 0
  rw [one] at two
  revert two
  generalize p 0 = c
  revert c
  decide

/-! ## A three-bit instance

Increment by one paired with clearing the low bit, against increment by three
paired with the same clear.  The two increments are interchangeable in
isolation: both are 8-cycles, and `x ↦ 3x` relabels one into the other.
Holding the clear fixed at the same time pins the relabeling, and then the
increments are distinguishable.

The proof does not search all `8^8` maps.  The increment constraint determines
the relabeling from its value at `0`, exactly as the executable search does,
and eight cases remain. -/

def inc1 : Fin 8 → Fin 8 := t8 [1, 2, 3, 4, 5, 6, 7, 0]
def inc3 : Fin 8 → Fin 8 := t8 [3, 4, 5, 6, 7, 0, 1, 2]
def clearLow : Fin 8 → Fin 8 := t8 [0, 0, 2, 2, 4, 4, 6, 6]

theorem increments_separately_conjugate : Conjugates (t8 [0, 3, 6, 1, 4, 7, 2, 5]) inc1 inc3 := by
  decide

theorem clears_separately_conjugate : Conjugates (t8 [0, 1, 2, 3, 4, 5, 6, 7]) clearLow clearLow := by
  decide

theorem three_bit_family_not_conjugate :
    ¬ ∃ p : Fin 8 → Fin 8, Conjugates p inc1 inc3 ∧ Conjugates p clearLow clearLow := by
  rintro ⟨p, hinc, hclear⟩
  have one : p 1 = inc3 (p 0) := hinc 0
  have zero : p 0 = clearLow (p 0) := hclear 0
  have oneClear : p 0 = clearLow (p 1) := hclear 1
  rw [one] at oneClear
  revert zero oneClear
  generalize p 0 = c
  revert c
  decide

/-! ## Restricting the relabeling to bit-linear maps changes the answer

Multiplication by `α` and by `α³` on GF(8) with `α³ = α + 1`, as permutations
of the eight states.  A bijection conjugates one into the other; no
GF(2)-linear one does.

The reason is an identity a linear conjugacy would transport.  Saying it this
way avoids enumerating the 168 matrices of `GL(3,2)` and explains the result
rather than reporting a failed search. -/

def mulAlpha : Fin 8 → Fin 8 := t8 [0, 2, 4, 6, 3, 1, 7, 5]
def mulAlphaCubed : Fin 8 → Fin 8 := t8 [0, 3, 6, 5, 7, 4, 1, 2]

/-- XOR of the underlying three-bit words. -/
def xor8 (a b : Fin 8) : Fin 8 := ⟨(a.val ^^^ b.val) % 8, Nat.mod_lt _ (by omega)⟩

theorem xor8_self (a : Fin 8) : xor8 a a = 0 := by revert a; decide

/-- A relabeling that is linear over GF(2): it respects the bit XOR. -/
def BitLinear (p : Fin 8 → Fin 8) : Prop := ∀ a b, p (xor8 a b) = xor8 (p a) (p b)

/-- `mulAlpha` satisfies `M³ + M + 1 = 0` pointwise, over GF(2). -/
theorem alpha_minimal_polynomial (x : Fin 8) :
    xor8 (xor8 (mulAlpha (mulAlpha (mulAlpha x))) (mulAlpha x)) x = 0 := by
  revert x; decide

/-- `mulAlphaCubed` does not satisfy it, with `1` as a witness point. -/
theorem alpha_cubed_fails_that_polynomial :
    xor8 (xor8 (mulAlphaCubed (mulAlphaCubed (mulAlphaCubed 1))) (mulAlphaCubed 1)) 1 ≠ 0 := by
  decide

/-- A relabeling does exist, with its inverse exhibited. -/
theorem alpha_conjugate_by_some_bijection :
    ∃ p q : Fin 8 → Fin 8,
      (∀ x, q (p x) = x) ∧ (∀ x, p (q x) = x) ∧ Conjugates p mulAlpha mulAlphaCubed := by
  refine ⟨t8 [0, 1, 3, 4, 5, 6, 7, 2], t8 [0, 1, 7, 2, 3, 4, 5, 6], ?_, ?_, ?_⟩ <;> decide

/-- No bit-linear relabeling exists.  A linear conjugacy transports the
polynomial identity, and the target does not satisfy it. -/
theorem alpha_not_conjugate_by_any_bit_linear :
    ¬ ∃ p : Fin 8 → Fin 8,
        BitLinear p ∧ (∀ x, ∃ y, p y = x) ∧ Conjugates p mulAlpha mulAlphaCubed := by
  rintro ⟨p, plin, ponto, hp⟩
  obtain ⟨x, hx⟩ := ponto 1
  have zero : p 0 = 0 := by
    have h := plin 0 0
    rw [xor8_self, xor8_self] at h
    exact h
  have transported :
      xor8 (xor8 (mulAlphaCubed (mulAlphaCubed (mulAlphaCubed (p x)))) (mulAlphaCubed (p x))) (p x)
        = p 0 := by
    rw [← hp x, ← hp (mulAlpha x), ← hp (mulAlpha (mulAlpha x)), ← plin, ← plin,
      alpha_minimal_polynomial x]
  rw [hx, zero] at transported
  exact alpha_cubed_fails_that_polynomial transported

/-! ## A pair that composite cycle types do not reject

`GL(3,2)` acting on the seven non-zero vectors of `GF(2)³`, against the same
two matrices acting on the dual space by inverse transpose.  Every group
element fixes the same number of points in both actions, since inverse
transpose preserves the rank of `M − I`. The executable search confirms that
cycle types of individual composite words do not separate them, at any word
length. This is weaker than simultaneous conjugacy: pair refinement of the
named-generator graphs distinguishes them after one round.

The proof mirrors the executable search.  The first operation is a 7-cycle, so
its constraint determines the relabeling from its value at `0`; two instances
of the second constraint then leave seven cases. -/

def aPoint : Fin 7 → Fin 7 := t7 [1, 3, 5, 2, 0, 6, 4]
def bPoint : Fin 7 → Fin 7 := t7 [2, 6, 3, 4, 5, 1, 0]
def aPlane : Fin 7 → Fin 7 := t7 [2, 3, 6, 0, 1, 4, 5]
def bPlane : Fin 7 → Fin 7 := t7 [4, 6, 1, 2, 5, 3, 0]

/-- Both operations are separately conjugate. -/
theorem points_planes_separately_conjugate :
    Conjugates (t7 [0, 2, 5, 6, 3, 4, 1]) aPoint aPlane ∧
      Conjugates (t7 [0, 1, 4, 5, 3, 2, 6]) bPoint bPlane := by
  constructor <;> decide

/-- The two generators have equal fixed-point counts. This theorem does not
check composite words. Their cycle-type agreement at every length is a separate
finite-closure computation in the Python exploration. -/
theorem generators_have_equal_fixed_point_counts :
    (List.range 7).countP (fun i => aPoint ⟨i % 7, Nat.mod_lt _ (by omega)⟩ == ⟨i % 7, Nat.mod_lt _ (by omega)⟩)
      = (List.range 7).countP (fun i => aPlane ⟨i % 7, Nat.mod_lt _ (by omega)⟩ == ⟨i % 7, Nat.mod_lt _ (by omega)⟩)
    ∧ (List.range 7).countP (fun i => bPoint ⟨i % 7, Nat.mod_lt _ (by omega)⟩ == ⟨i % 7, Nat.mod_lt _ (by omega)⟩)
      = (List.range 7).countP (fun i => bPlane ⟨i % 7, Nat.mod_lt _ (by omega)⟩ == ⟨i % 7, Nat.mod_lt _ (by omega)⟩) := by
  decide

/-- No relabeling makes both families agree. -/
theorem gl32_points_planes_not_conjugate :
    ¬ ∃ p : Fin 7 → Fin 7, Conjugates p aPoint aPlane ∧ Conjugates p bPoint bPlane := by
  rintro ⟨p, ha, hb⟩
  -- the 7-cycle `aPoint` sends 0↦1, 1↦3, 3↦2, 2↦5, 5↦6
  have a0 : p 1 = aPlane (p 0) := ha 0
  have a1 : p 3 = aPlane (p 1) := ha 1
  have a3 : p 2 = aPlane (p 3) := ha 3
  have a2 : p 5 = aPlane (p 2) := ha 2
  have a5 : p 6 = aPlane (p 5) := ha 5
  -- `bPoint` sends 0↦2 and 1↦6, both now expressed in `p 0`
  have b0 : p 2 = bPlane (p 0) := hb 0
  have b1 : p 6 = bPlane (p 1) := hb 1
  rw [a0] at a1
  rw [a1] at a3
  rw [a3] at a2
  rw [a2] at a5
  rw [a3] at b0
  rw [a5, a0] at b1
  revert b0 b1
  generalize p 0 = c
  revert c
  decide

#print axioms conjugates_execute
#print axioms region_needs_one_boundary
#print axioms simulates_of_conjugates
#print axioms conjugates_all_mono
#print axioms family_not_conjugate
#print axioms three_bit_family_not_conjugate
#print axioms alpha_conjugate_by_some_bijection
#print axioms alpha_not_conjugate_by_any_bit_linear
#print axioms gl32_points_planes_not_conjugate

end Kelana.Relabeling
