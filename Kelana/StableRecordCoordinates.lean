import Std

/-! Logical ordered records do not require canonical physical addresses.
This finite-list foundation proves local insertion, reuse and retirement,
including typed aging; capacity and byte extent allocation remain separate. -/
namespace Kelana.StableRecordCoordinates

variable {A B V W : Type}

def decode (heap : A → V) (refs : List A) : List V := refs.map heap

def write [DecidableEq A] (heap : A → V) (a : A) (v : V) : A → V :=
  fun b => if b = a then v else heap b

/-- An observer only sees addresses actually referenced by the logical list. -/
theorem decode_agrees (h g : A → V) (refs : List A)
    (same : ∀ a ∈ refs, h a = g a) : decode h refs = decode g refs := by
  induction refs with
  | nil => rfl
  | cons a refs ih =>
      simp only [decode, List.map_cons]
      rw [same a (by simp)]
      congr 1
      exact ih (fun b hb => same b (by simp [hb]))

/-- Even global bijectivity is unnecessary: a physical map may merge addresses
whose observed records agree. Every live lookup, not an address count, is the
faithfulness premise. -/
theorem renamed_decode (h : A → V) (g : B → V) (name : A → B)
    (refs : List A) (same : ∀ a ∈ refs, g (name a) = h a) :
    decode g (refs.map name) = decode h refs := by
  induction refs with
  | nil => rfl
  | cons a refs ih =>
      simp only [decode, List.map_cons]
      rw [same a (by simp)]
      congr 1
      exact ih (fun b hb => same b (by simp [hb]))

/-- Shared physical names cannot merge distinct live records. -/
theorem merged_values_equal (h : A → V) (g : B → V) (name : A → B)
    (refs : List A) (same : ∀ a ∈ refs, g (name a) = h a)
    (a b : A) (ha : a ∈ refs) (hb : b ∈ refs) (eqname : name a = name b) :
    h a = h b := by
  rw [← same a ha, ← same b hb, eqname]

/-- Reusing a dead slot does not move or overwrite any live record. -/
theorem write_dead [DecidableEq A] (h : A → V) (refs : List A) (a : A) (v : V)
    (dead : a ∉ refs) : decode (write h a v) refs = decode h refs := by
  apply decode_agrees
  intro b hb
  have ne : b ≠ a := by
    intro eq
    subst b
    exact dead hb
  simp [write, ne]

theorem fresh_insert [DecidableEq A] (h : A → V) (refs : List A) (a : A) (v : V)
    (dead : a ∉ refs) :
    decode (write h a v) (refs ++ [a]) = decode h refs ++ [v] := by
  simp only [decode, List.map_append, List.map_cons, List.map_nil]
  have unchanged := write_dead h refs a v dead
  change (refs.map (write h a v)) = refs.map h at unchanged
  rw [unchanged]
  simp [write]

/-- Existing exact records need only an appended handle, not a value rewrite. -/
theorem shared_insert (h : A → V) (refs : List A) (a : A) (v : V)
    (equal : h a = v) : decode h (refs ++ [a]) = decode h refs ++ [v] := by
  simp [decode, equal]

/-- Logical retirement is a list operation. The physical record can be
reclaimed only when no remaining reference needs it. -/
theorem retire (h : A → V) (a : A) (refs : List A) :
    decode h refs = (decode h (a :: refs)).tail := by
  rfl

theorem reclaim_last [DecidableEq A] (h : A → V) (a : A) (refs : List A) (unused : V)
    (last_reference : a ∉ refs) :
    decode (write h a unused) refs = (decode h (a :: refs)).tail := by
  rw [write_dead h refs a unused last_reference]
  rfl

/-- Appending the encoded oldest recent value is a typed transition: its
quantized bytes need not share the raw value's representation or address. -/
theorem age_fresh {Q : Type} [DecidableEq Q]
    (recent : A → V) (aged : Q → W) (encode : V → W)
    (a : A) (rs : List A) (qs : List Q) (q : Q) (free : q ∉ qs) :
    (decode (write aged q (encode (recent a))) (qs ++ [q]), decode recent rs) =
    (decode aged qs ++ [encode ((decode recent (a :: rs)).head (by simp [decode]))],
      (decode recent (a :: rs)).tail) := by
  rw [fresh_insert aged qs q (encode (recent a)) free]
  rfl

theorem age_shared {Q : Type} [DecidableEq Q]
    (recent : A → V) (aged : Q → W) (encode : V → W)
    (a : A) (rs : List A) (qs : List Q) (q : Q)
    (equal : aged q = encode (recent a)) :
    (decode aged (qs ++ [q]), decode recent rs) =
    (decode aged qs ++ [encode (recent a)], (decode recent (a :: rs)).tail) := by
  rw [shared_insert aged qs q (encode (recent a)) equal]
  rfl

/-- Every deterministic ordered-record query inherits these identities. -/
theorem query_congr (observe : List V → W) (h g : A → V) (r s : List A)
    (equal : decode h r = decode g s) :
    observe (decode h r) = observe (decode g s) := congrArg observe equal

def references [DecidableEq A] (a : A) : List A → Nat
  | [] => 0
  | b :: bs => (if a = b then 1 else 0) + references a bs

/-- Reference ownership is the actual chronological multiplicity, not a
separate unchecked liveness flag. -/
theorem references_zero [DecidableEq A] (a : A) (rs : List A) :
    references a rs = 0 ↔ a ∉ rs := by
  induction rs with
  | nil => simp [references]
  | cons b bs ih =>
      by_cases h : a = b
      · subst b
        simp [references]
      · simp [references, h, ih]

theorem reference_increment [DecidableEq A] (a b : A) (rs : List A) :
    references a (rs ++ [b]) = references a rs + (if a = b then 1 else 0) := by
  induction rs with
  | nil => simp [references]
  | cons c cs ih => simp [references, ih, Nat.add_assoc]

theorem reference_decrement [DecidableEq A] (a : A) (rs : List A) :
    references a rs = references a (a :: rs) - 1 := by
  simp [references]

/-- A zero maintained multiplicity after retirement supplies precisely the
missing last-reference premise of local reclamation. -/
theorem reclaim_count_zero [DecidableEq A] (h : A → V) (a : A)
    (rs : List A) (unused : V) (zero : references a rs = 0) :
    decode (write h a unused) rs = (decode h (a :: rs)).tail := by
  exact reclaim_last h a rs unused ((references_zero a rs).mp zero)

/-- Clearing a slot merely because the first occurrence retired is unsound
when another occurrence remains. -/
theorem premature_reclaim :
    decode (fun _ : Nat => 1) ([0, 0].tail) = [1] ∧
    decode (write (fun _ : Nat => 1) 0 0) ([0, 0].tail) = [0] := by
  decide

end Kelana.StableRecordCoordinates
