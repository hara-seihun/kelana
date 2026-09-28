import Kelana.CausalStateCapacity
import Std

namespace Kelana.PartialTransitionReachability

/-- A completion chooses one destination per state/token pair, once for all
    visits. Unknown edges in the partial table impose no constraint. -/
def Extends (known : C → A → Option C) (complete : C → A → C) : Prop :=
  ∀ c a d, known c a = some d → complete c a = d

/-- A fixed deterministic completion processes the word from left to right. -/
def run (complete : C → A → C) (start : C) : List A → C
  | [] => start
  | a :: rest => run complete (complete start a) rest

/-- An unknown transition may choose any listed state *at this visit*.
    Repeated visits need not make the same choice in this relaxation. -/
def nextStates (states : List C) (known : C → A → Option C)
    (c : C) (a : A) : List C :=
  match known c a with
  | some d => [d]
  | none => states

def advance (states : List C) (known : C → A → Option C)
    (frontier : List C) (a : A) : List C :=
  frontier.flatMap (fun c => nextStates states known c a)

/-- Set-valued reachability, represented by a list (duplicates are harmless). -/
def reachFrom (states : List C) (known : C → A → Option C)
    (frontier : List C) : List A → List C
  | [] => frontier
  | a :: rest => reachFrom states known (advance states known frontier a) rest

def reach (states : List C) (known : C → A → Option C)
    (start : C) (word : List A) : List C :=
  reachFrom states known [start] word

private theorem next_sound (states : List C) (known : C → A → Option C)
    (complete : C → A → C) (agrees : Extends known complete)
    (closed : ∀ c a, complete c a ∈ states) (c : C) (a : A) :
    complete c a ∈ nextStates states known c a := by
  unfold nextStates
  cases h : known c a with
  | none => exact closed c a
  | some d =>
    have heq := agrees c a d h
    simp [heq]

private theorem advance_sound (states : List C) (known : C → A → Option C)
    (complete : C → A → C) (agrees : Extends known complete)
    (closed : ∀ c a, complete c a ∈ states)
    (frontier : List C) (c : C) (hc : c ∈ frontier) (a : A) :
    complete c a ∈ advance states known frontier a := by
  unfold advance
  apply List.mem_flatMap.mpr
  exact ⟨c, hc, next_sound states known complete agrees closed c a⟩

/-- Universal soundness for every word and every fixed completion extending
    the partial table. A witness destination may depend on each visit in the
    relaxation; the theorem only asserts containment, not realization. -/
theorem run_mem_reachFrom (states : List C) (known : C → A → Option C)
    (complete : C → A → C) (agrees : Extends known complete)
    (closed : ∀ c a, complete c a ∈ states)
    (frontier : List C) (start : C) (hstart : start ∈ frontier)
    (word : List A) :
    run complete start word ∈ reachFrom states known frontier word := by
  induction word generalizing frontier start with
  | nil => exact hstart
  | cons a rest ih =>
    exact ih (advance states known frontier a) (complete start a)
      (advance_sound states known complete agrees closed frontier start hstart a)

/-- Every deterministic completion's final state is in the relaxed set. -/
theorem run_mem_reach (states : List C) (known : C → A → Option C)
    (complete : C → A → C) (agrees : Extends known complete)
    (closed : ∀ c a, complete c a ∈ states) (start : C) (word : List A) :
    run complete start word ∈ reach states known start word := by
  exact run_mem_reachFrom states known complete agrees closed
    [start] start (by simp) word

/-- Thus every readout of a fixed completion is among the allowed labels,
    even if several words' allowed sets cannot be realized simultaneously. -/
theorem readout_mem_possible (states : List C) (known : C → A → Option C)
    (complete : C → A → C) (agrees : Extends known complete)
    (closed : ∀ c a, complete c a ∈ states)
    (readout : C → Y) (start : C) (word : List A) :
    readout (run complete start word) ∈
      (reach states known start word).map readout := by
  exact List.mem_map.mpr
    ⟨run complete start word,
      run_mem_reach states known complete agrees closed start word, rfl⟩

/-- One and two visits to the same unknown edge can be assigned inconsistent
    outcomes by separate reachability relaxations. Both labels occur in the
    respective allowed sets, but no single deterministic completion realizes
    the pair (false after one step, true after two steps). -/
theorem repeated_use_not_jointly_realizable :
    let states : List Bool := [false, true]
    let known : Bool → Unit → Option Bool := fun _ _ => none
    false ∈ reach states known false [()] ∧
      true ∈ reach states known false [(), ()] ∧
      ∀ complete : Bool → Unit → Bool,
        ¬ (run complete false [()] = false ∧
           run complete false [(), ()] = true) := by
  dsimp
  constructor
  · decide
  constructor
  · decide
  · intro complete h
    rcases h with ⟨hfirst, hsecond⟩
    have hfix : complete false () = false := by
      simpa [run] using hfirst
    simp only [run, hfix] at hsecond
    cases hsecond

/-- Any nonempty frontier reaches every listed state after one all-unknown
    step. In the inductive use, the frontier itself already contains every
    listed state, so no separate nonemptiness assumption is needed. -/
private theorem unknown_advance_all (states frontier : List C) (a : A)
    (all : ∀ d ∈ states, d ∈ frontier) :
    ∀ d ∈ states,
      d ∈ advance states (fun _ _ => none) frontier a := by
  intro d hd
  unfold advance nextStates
  exact List.mem_flatMap.mpr ⟨d, all d hd, by simpa using hd⟩

private theorem unknown_reachFrom_all (states frontier : List C)
    (all : ∀ d ∈ states, d ∈ frontier) (word : List A) :
    ∀ d ∈ states,
      d ∈ reachFrom states (fun _ _ => none) frontier word := by
  induction word generalizing frontier with
  | nil => exact all
  | cons a rest ih =>
    exact ih (advance states (fun _ _ => none) frontier a)
      (unknown_advance_all states frontier a all)

/-- For *every* nonempty word, an all-unknown transition table admits each
    listed state individually. No joint completion is asserted. -/
theorem unknown_reach_all (states : List C) (start : C)
    (a : A) (rest : List A) :
    ∀ d ∈ states,
      d ∈ reach states (fun _ _ => none) start (a :: rest) := by
  exact unknown_reachFrom_all states
    (advance states (fun _ _ => none) [start] a)
    (by
      intro d hd
      unfold advance nextStates
      exact List.mem_flatMap.mpr ⟨start, by simp, by simpa using hd⟩)
    rest

/-- Both specified readout laws are separately possible after every nonempty
    word, even when later choices would contradict an earlier edge choice. -/
theorem unknown_two_laws_pointwise (states : List C) (start stateA stateB : C)
    (readout : C → Y) (stateA_mem : stateA ∈ states)
    (stateB_mem : stateB ∈ states)
    (a : A) (rest : List A) :
    readout stateA ∈ (reach states (fun _ _ => none) start (a :: rest)).map readout ∧
    readout stateB ∈ (reach states (fun _ _ => none) start (a :: rest)).map readout := by
  constructor
  · exact List.mem_map.mpr
      ⟨stateA, unknown_reach_all states start a rest stateA stateA_mem, rfl⟩
  · exact List.mem_map.mpr
      ⟨stateB, unknown_reach_all states start a rest stateB stateB_mem, rfl⟩

private theorem run_replicate (step : C → C) (start : C) (n : Nat) :
    run (fun c (_ : Unit) => step c) start (List.replicate n ()) =
      CausalStateCapacity.orbit step start n := by
  induction n generalizing start with
  | zero => rfl
  | succ n ih =>
    simp only [List.replicate_succ, run]
    calc
      _ = CausalStateCapacity.orbit step (step start) n := ih (step start)
      _ = CausalStateCapacity.orbit step start (1 + n) := by
        simpa only [CausalStateCapacity.orbit] using
          (CausalStateCapacity.orbit_add step start 1 n).symm
      _ = _ := by rw [Nat.add_comm]

/-- A general all-C clock gap: the all-unknown reachability relaxation fits
    every phase's prescribed law individually, whereas a single C-state
    completion cannot emit A for phases 0,...,C-1 and distinct B at phase C.
    The token is repeated; this is not a tensor/iid-copy construction. -/
theorem all_unknown_clock_gap (C : Nat) (hC : 2 ≤ C)
    {Y : Type} (A B : Y) (different : A ≠ B) :
    ∃ (start stateB : Fin C) (readout : Fin C → Y),
      readout start = A ∧ readout stateB = B ∧
      (∀ n : Nat,
        (if n < C then A else B) ∈
          (reach (List.finRange C) (fun _ (_ : Unit) => none)
            start (List.replicate n ())).map readout) ∧
      (∀ step : Fin C → Fin C,
        ¬ ((∀ n : Nat, n < C →
              readout (run (fun c (_ : Unit) => step c)
                start (List.replicate n ())) = A) ∧
            readout (run (fun c (_ : Unit) => step c)
              start (List.replicate C ())) = B)) := by
  let start : Fin C := ⟨0, by omega⟩
  let stateB : Fin C := ⟨1, by omega⟩
  let readout : Fin C → Y := fun c => if c = stateB then B else A
  have distinct_states : start ≠ stateB := by
    intro eq
    have heq := congrArg Fin.val eq
    simp only [start, stateB] at heq
    omega
  have hstart : readout start = A := by simp [readout, distinct_states]
  have hB : readout stateB = B := by simp [readout]
  refine ⟨start, stateB, readout, hstart, hB, ?_, ?_⟩
  · intro n
    cases n with
    | zero =>
      have hn : (0 : Nat) < C := by omega
      simp [hn, reach, reachFrom, hstart]
    | succ n =>
      have both := unknown_two_laws_pointwise (List.finRange C)
        start start stateB readout (List.mem_finRange start)
        (List.mem_finRange stateB) () (List.replicate n ())
      by_cases early : n + 1 < C
      · simpa only [List.replicate_succ, early, ↓reduceIte, hstart] using both.1
      · simpa only [List.replicate_succ, early, ↓reduceIte, hB] using both.2
  · intro step fitted
    rcases fitted with ⟨early, final⟩
    apply CausalStateCapacity.changed_final_law_impossible C
      step start readout A B different
    · intro i hi
      rw [← run_replicate step start i]
      exact early i hi
    · rw [← run_replicate step start C]
      exact final

end Kelana.PartialTransitionReachability
