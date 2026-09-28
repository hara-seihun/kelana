import Std

/-! Exact distinct-record occupancy under a repeatable finite source.
The list `distinct` is any duplicate-free enumeration of the values in a
chronological word. No dictionary implementation or byte codec is assumed. -/
namespace Kelana.ValueRecordCapacity

structure Enumerates (distinct word : List Nat) : Prop where
  nodup : distinct.Nodup
  same : ∀ x, x ∈ distinct ↔ x ∈ word

/-- There cannot be more distinct records than positions or source labels. -/
theorem occupancy_upper (M : Nat) (word distinct : List Nat)
    (valid : ∀ x ∈ word, x < M) (e : Enumerates distinct word) :
    distinct.length ≤ min M word.length := by
  have byWord := e.nodup.length_le_of_subset (fun x hx => (e.same x).mp hx)
  have bySource : distinct.length ≤ (List.range M).length :=
    e.nodup.length_le_of_subset (fun x hx => List.mem_range.mpr (valid x ((e.same x).mp hx)))
  simp only [List.length_range] at bySource
  omega

/-- Distinct occupancy is independent of which ordering enumerates records. -/
theorem occupancy_unique (word a b : List Nat)
    (ea : Enumerates a word) (eb : Enumerates b word) : a.length = b.length := by
  have hab := ea.nodup.length_le_of_subset (fun x hx => (eb.same x).mpr ((ea.same x).mp hx))
  have hba := eb.nodup.length_le_of_subset (fun x hx => (ea.same x).mpr ((eb.same x).mp hx))
  omega

/-- Every nonempty repeatable M-label source attains min(M,n) occupancy.
Padding repeats a legal source label; it introduces no extra records. -/
theorem occupancy_attained (M n : Nat) (nonempty : 0 < M) :
    ∃ word distinct : List Nat,
      word.length = n ∧ (∀ x ∈ word, x < M) ∧
      Enumerates distinct word ∧ distinct.length = min M n := by
  let k := min M n
  let word := List.range k ++ List.replicate (n-k) 0
  refine ⟨word, List.range k, ?_, ?_, ?_, by simp [k]⟩
  · simp only [word, List.length_append, List.length_range, List.length_replicate]
    have hk : k ≤ n := Nat.min_le_right M n
    omega
  · intro x hx
    rcases List.mem_append.mp hx with left | right
    · have h := List.mem_range.mp left
      have hk : k ≤ M := Nat.min_le_left M n
      omega
    · have h := List.mem_replicate.mp right
      rcases h with ⟨_, rfl⟩
      exact nonempty
  · refine ⟨List.nodup_range, ?_⟩
    intro x
    constructor
    · intro hx
      exact List.mem_append.mpr (Or.inl hx)
    · intro hx
      rcases List.mem_append.mp hx with left | right
      · exact left
      · rcases List.mem_replicate.mp right with ⟨more, rfl⟩
        apply List.mem_range.mpr
        dsimp [k]
        omega

/-- A fixed slot capacity below the maximum rejects some legal aged word. -/
theorem insufficient_slots (M n slots : Nat) (nonempty : 0 < M)
    (tooSmall : slots < min M n) :
    ∃ word distinct : List Nat,
      word.length = n ∧ (∀ x ∈ word, x < M) ∧
      Enumerates distinct word ∧ slots < distinct.length := by
  obtain ⟨word, distinct, len, valid, enumerates, size⟩ := occupancy_attained M n nonempty
  exact ⟨word, distinct, len, valid, enumerates, by omega⟩

def agedPost (T R : Nat) := T-R
def agedPre (T R : Nat) := T-(R+1)

theorem one_aged_transition (T R : Nat) :
    agedPre T R ≤ agedPost T R ∧ agedPost T R ≤ agedPre T R + 1 := by
  simp only [agedPre, agedPost]
  omega

/-- A distinct prefix one longer than capacity crosses the slot limit at
this after-query boundary, regardless of the contents of the recent suffix. -/
theorem first_full_boundary (slots R : Nat) :
    agedPre (slots+R+1) R = slots ∧
    agedPost (slots+R+1) R = slots+1 := by
  simp only [agedPre, agedPost]
  omega

theorem source_witness_boundary :
    agedPre 181 32 = 148 ∧ agedPost 181 32 = 149 ∧ agedPre 182 32 = 149 := by
  decide

end Kelana.ValueRecordCapacity
