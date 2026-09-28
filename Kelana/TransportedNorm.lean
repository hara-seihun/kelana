import Std

namespace Kelana.TransportedNorm

/-- A finite-dimensional coordinate program is legal for a complete score
consumer when the encoding and decoding commute with every position rotation,
and the two paired encodings are dual for the score. The norm is explicitly
transported rather than recomputed as Euclidean norm in encoded coordinates. -/
structure Coordinate (α : Type) where
  encode : α → α
  decode : α → α
  decode_encode : ∀ x, decode (encode x) = x

def transportedNorm {α β : Type} (norm : α → β) (c : Coordinate α) (x : α) : β :=
  norm (c.decode x)

theorem norm_encoded {α β : Type} (norm : α → β) (c : Coordinate α) (x : α) :
    transportedNorm norm c (c.encode x) = norm x := by
  simp [transportedNorm, c.decode_encode]

/-- This is the exact real-operation obligation; quantized projection and BF16
rounding must be checked separately, as neither respects arbitrary encoding. -/
theorem complete_scores {α β : Type} (cq ck : Coordinate α)
    (rotate : Nat → α → α) (score : α → α → β)
    (commuteQ : ∀ t x, rotate t (cq.encode x) = cq.encode (rotate t x))
    (commuteK : ∀ t x, rotate t (ck.encode x) = ck.encode (rotate t x))
    (dual : ∀ q k, score (cq.encode q) (ck.encode k) = score q k)
    (query key : α) (queryPosition keyPosition : Nat) :
    score (rotate queryPosition (cq.encode query))
      (rotate keyPosition (ck.encode key)) =
    score (rotate queryPosition query) (rotate keyPosition key) := by
  rw [commuteQ, commuteK, dual]

/-- Every live query head sharing a key head receives the same score theorem;
no assumption about the number of GQA query heads is needed. -/
theorem shared_keys {α β : Type} (cq ck : Coordinate α)
    (rotate : Nat → α → α) (score : α → α → β)
    (commuteQ : ∀ t x, rotate t (cq.encode x) = cq.encode (rotate t x))
    (commuteK : ∀ t x, rotate t (ck.encode x) = ck.encode (rotate t x))
    (dual : ∀ q k, score (cq.encode q) (ck.encode k) = score q k)
    (queries : List (Nat × α)) (key : Nat × α) :
    queries.map (fun (t,q) => score (rotate t (cq.encode q))
      (rotate key.1 (ck.encode key.2))) =
    queries.map (fun (t,q) => score (rotate t q) (rotate key.1 key.2)) := by
  apply List.map_congr_left
  intro ⟨t,q⟩ _
  exact complete_scores cq ck rotate score commuteQ commuteK dual q key.2 t key.1

end Kelana.TransportedNorm
