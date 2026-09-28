import Std

/-! A cache step observes the inserted state before its scheduled flush.
The encoded transitions may reject an input or exhaust capacity. Soundness
of accepted runs is deliberately not a promise that all inputs are accepted. -/
namespace Kelana.PhasedCacheSimulation

def run (insert : S → X → S) (observe : S → X → Y) (flush : S → S) :
    List X → S → S × List Y
  | [], s => (s, [])
  | x :: xs, s =>
      let pre := insert s x
      let rest := run insert observe flush xs (flush pre)
      (rest.1, observe pre x :: rest.2)

def checked (insert : C → X → Option C) (observe : C → X → Y)
    (flush : C → Option C) : List X → C → Option (C × List Y)
  | [], c => some (c, [])
  | x :: xs, c =>
      match insert c x with
      | none => none
      | some pre =>
          match flush pre with
          | none => none
          | some post =>
              match checked insert observe flush xs post with
              | none => none
              | some (last, ys) => some (last, observe pre x :: ys)

/-- Accepted encoded insertion/flush transitions and the before-flush query
commute with logical decoding. Their composition preserves every emitted
output and the final logical state, without requiring a fixed storage layout. -/
theorem accepted_run_sound
    (decode : C → S)
    (insert' : C → X → Option C) (observe' : C → X → Y)
    (flush' : C → Option C)
    (insert : S → X → S) (observe : S → X → Y) (flush : S → S)
    (insert_sound : ∀ c x pre, insert' c x = some pre →
      decode pre = insert (decode c) x)
    (observe_sound : ∀ c x, observe' c x = observe (decode c) x)
    (flush_sound : ∀ pre post, flush' pre = some post →
      decode post = flush (decode pre))
    (xs : List X) (c last : C) (ys : List Y)
    (accepted : checked insert' observe' flush' xs c = some (last, ys)) :
    (decode last, ys) = run insert observe flush xs (decode c) := by
  induction xs generalizing c last ys with
  | nil =>
      simp only [checked, Option.some.injEq, Prod.mk.injEq] at accepted
      rcases accepted with ⟨rfl, rfl⟩
      rfl
  | cons x xs ih =>
      cases hi : insert' c x with
      | none => simp [checked, hi] at accepted
      | some pre =>
          cases hf : flush' pre with
          | none => simp [checked, hi, hf] at accepted
          | some post =>
              cases hr : checked insert' observe' flush' xs post with
              | none => simp [checked, hi, hf, hr] at accepted
              | some result =>
                  rcases result with ⟨last', tail⟩
                  have heq : (last', observe' pre x :: tail) = (last, ys) := by
                    simpa only [checked, hi, hf, hr, Option.some.injEq] using accepted
                  cases heq
                  have hrest := ih post last tail hr
                  have hpre := insert_sound c x pre hi
                  have hpost := flush_sound pre post hf
                  have lifted := congrArg
                    (fun r : S × List Y => (r.1, observe (decode pre) x :: r.2)) hrest
                  simpa only [run, observe_sound, hpost, hpre] using lifted

/-- Rejection can coexist with perfect soundness. Capacity/admission is a
separate obligation, not a consequence of output correctness when accepted. -/
theorem rejecting_insert (observe : C → X → Y) (flush : C → Option C)
    (x : X) (xs : List X) (c : C) :
    checked (fun _ _ => none) observe flush (x :: xs) c = none := by
  rfl

/-- The before-query phase cannot be silently replaced by the after-flush
phase, even when both are legal deterministic states. -/
theorem phase_witness :
    run (fun s x : Nat => s + x) (fun s (_ : Nat) => s)
      (fun s => s / 2) [2, 2] 0 = (1, [2, 3]) := by
  decide

end Kelana.PhasedCacheSimulation
