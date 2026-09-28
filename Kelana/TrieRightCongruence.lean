import Std

namespace Kelana.TrieRightCongruence

/-- A finite list of histories is prefix-closed when each prefix of any
    listed history is listed. Duplicates are harmless. The root is supplied separately. -/
def PrefixClosed (trie : List (List A)) : Prop :=
  ∀ pre suffix, pre ++ suffix ∈ trie → pre ∈ trie

/-- Right congruence is checked only where both outgoing trie edges exist.
    Missing edges can later be completed without constraining the coloring. -/
def RightCongruent (trie : List (List A)) (color : List A → C) : Prop :=
  ∀ h ∈ trie, ∀ k ∈ trie, ∀ a,
    h ++ [a] ∈ trie → k ++ [a] ∈ trie →
      color h = color k → color (h ++ [a]) = color (k ++ [a])

/-- Deterministic replay of a word from a fixed root state. -/
def run (step : C → A → C) (root : C) (word : List A) : C :=
  word.foldl step root

private theorem run_snoc (step : C → A → C) (root : C)
    (h : List A) (a : A) :
    run step root (h ++ [a]) = step (run step root h) a := by
  simp [run, List.foldl_append]

/-- An executable finite-list edge selection. On an unspecified state/token
    pair it chooses the root state; on a represented edge it chooses the color
    of a witness child. -/
def completion [DecidableEq A] [DecidableEq C]
    (trie : List (List A)) (color : List A → C) (root : C)
    (c : C) (a : A) : C :=
  match trie.find? (fun h => decide (color h = c ∧ h ++ [a] ∈ trie)) with
  | some h => color (h ++ [a])
  | none => root

private theorem completion_agrees [DecidableEq A] [DecidableEq C]
    (trie : List (List A)) (color : List A → C) (root : C)
    (consistent : RightCongruent trie color)
    (h : List A) (hh : h ∈ trie) (a : A) (hchild : h ++ [a] ∈ trie) :
    completion trie color root (color h) a = color (h ++ [a]) := by
  unfold completion
  cases found : trie.find? (fun p => decide
      (color p = color h ∧ p ++ [a] ∈ trie)) with
  | none =>
    have missing := List.find?_eq_none.mp found h hh
    have present : decide (color h = color h ∧ h ++ [a] ∈ trie) = true := by
      simp [hchild]
    exact False.elim (missing present)
  | some witness =>
    have hw := List.mem_of_find?_eq_some found
    have hp := List.find?_some found
    have hp' : color witness = color h ∧ witness ++ [a] ∈ trie :=
      decide_eq_true_eq.mp hp
    exact consistent witness hw h hh a hp'.2 hchild hp'.1

private theorem extension_matches [DecidableEq A] [DecidableEq C]
    (trie : List (List A)) (color : List A → C) (root : C)
    (closed : PrefixClosed trie) (consistent : RightCongruent trie color)
    (pre suffix : List A)
    (hp : pre ∈ trie) (hfull : pre ++ suffix ∈ trie) :
    run (completion trie color root) (color pre) suffix =
      color (pre ++ suffix) := by
  induction suffix generalizing pre with
  | nil => simp [run]
  | cons a rest ih =>
    have hchild : pre ++ [a] ∈ trie := by
      apply closed (pre ++ [a]) rest
      simpa [List.append_assoc] using hfull
    have hstep := completion_agrees trie color root consistent pre hp a hchild
    change run (completion trie color root)
      (completion trie color root (color pre) a) rest = _
    rw [hstep]
    simpa [List.append_assoc] using
      (ih (pre ++ [a]) hchild (by simpa [List.append_assoc] using hfull))

/-- Constructive sufficiency: every right-congruent coloring of a finite
    prefix-closed history trie (with root color fixed) extends to a total
    deterministic state/token table. This table is the explicit `completion`,
    not a choice axiom over arbitrary functions. -/
theorem completion_realizes [DecidableEq A] [DecidableEq C]
    (trie : List (List A)) (root : C) (color : List A → C)
    (root_mem : [] ∈ trie) (root_color : color [] = root)
    (closed : PrefixClosed trie) (consistent : RightCongruent trie color) :
    ∀ h ∈ trie, run (completion trie color root) root h = color h := by
  intro h hh
  have h := extension_matches trie color root closed consistent
    [] h root_mem (by simpa using hh)
  simpa [root_color] using h

/-- Necessity: a shared deterministic transition cannot give different child
    colors to two identically colored parents under the same token. -/
theorem realization_right_congruent (trie : List (List A))
    (root : C) (color : List A → C) (step : C → A → C)
    (realizes : ∀ h ∈ trie, run step root h = color h) :
    RightCongruent trie color := by
  intro h hh k hk a hchild kchild same
  have hparent := realizes h hh
  have kparent := realizes k hk
  have hnext := realizes (h ++ [a]) hchild
  have knext := realizes (k ++ [a]) kchild
  rw [run_snoc, hparent] at hnext
  rw [run_snoc, kparent] at knext
  rw [← hnext, ← knext, same]

/-- Exact finite-list criterion for a C-state coloring: right congruence is
    both necessary and sufficient. Empty or non-prefix-closed observations are
    deliberately outside this API, since their unseen prefixes need colors. -/
theorem realizable_iff_right_congruent [DecidableEq A]
    (trie : List (List A)) (C : Nat) (root : Fin C)
    (color : List A → Fin C)
    (root_mem : [] ∈ trie) (root_color : color [] = root)
    (closed : PrefixClosed trie) :
    (∃ step : Fin C → A → Fin C,
      ∀ h ∈ trie, run step root h = color h) ↔
      RightCongruent trie color := by
  constructor
  · rintro ⟨step, realizes⟩
    exact realization_right_congruent trie root color step realizes
  · intro consistent
    exact ⟨completion trie color root,
      completion_realizes trie root color root_mem root_color closed consistent⟩

end Kelana.TrieRightCongruence
