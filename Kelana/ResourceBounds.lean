import Kelana.ResourceVectors

/-!
# Resource-bound certificates

A conditional lower bound on execution time, a sound upper bound from an
exhibited run, and the comparison between them. Nothing here claims a hardware
fact. Every number a bound depends on arrives through one of three named
premises, and the bound is exactly as strong as they are:

* `Family.meets` — the semantic premise. Every run of the family satisfies the
  cuts `A n ≥ b`. Cuts are justified outside this file, for instance by
  `potential_cut` below or by a state-collision argument in `Kelana.Composition`.
* `Family.serves` — the service premise. Every run satisfies `D n ≤ T c`, where
  `c` is the service a resource can deliver in one tick. A measured throughput
  is not a `c`; only an upper bound on what the resource can do is.
* `TickRate` — the calibration premise, needed only to speak about seconds.

Four quantities are kept apart and are never interchanged:

* instruction *counts* `n`, dimensionless;
* *service* bounds `D n ≤ T c`, one inequality per resource, all sharing one
  makespan `T`, so that parallel resources are never charged sequentially;
* *latency* bounds from dependency chains, combined with service bounds by
  `LowerBound.max` and never by addition — `sum_is_not_a_lower_bound` exhibits
  the execution that refutes the sum;
* *native* time, which exists only relative to a `TickRate`.

Register peak is `Machine.Fits`: a constraint on schedules, in its own unit,
with no route to a tick count.

Dual weights are `Nat`. A rational certificate is used by clearing denominators;
the bound is homogeneous of degree one in the weights, so scaling by a common
denominator scales both sides of `λ·b ≤ T (μ·c)` and proves the same fact.
-/

namespace Kelana.ResourceBounds

open Kelana.ResourceVectors

/-- A named time base. Ticks of different clocks are different quantities, and
the type parameter on `LowerBound` and `UpperBound` keeps them from meeting. -/
structure Clock where
  name : String
deriving DecidableEq, Repr

/-- Semantic cuts: row `i` asserts `rows[i] ⬝ n ≥ rhs[i]` for every run. -/
structure Obligations where
  rows : List (List Int)
  rhs : List Int
deriving Repr

/-- The hardware side. `demand` charges each instruction class to each resource,
`capacity` is the service one tick of `clock` can deliver, and `registers` is the
architectural limit a schedule must fit in. -/
structure Machine where
  clock : Clock
  demand : List (List Int)
  capacity : List Int
  registers : Nat
deriving Repr

/-- One execution: how many instructions of each class it issues, how many ticks
it takes, and its peak register occupancy. -/
structure Execution where
  counts : List Nat
  ticks : Nat
  peakRegisters : Nat
deriving Repr

/-- `b ≤ A n`. -/
def Obligations.Meets (o : Obligations) (e : Execution) : Prop :=
  LeVec o.rhs (o.rows.map (fun a => dotN a e.counts))

/-- `D n ≤ T c`, one inequality per resource against the shared makespan `T`. -/
def Machine.Serves (m : Machine) (e : Execution) : Prop :=
  LeVec (m.demand.map (fun d => dotN d e.counts)) (smul (e.ticks : Int) m.capacity)

/-- Peak register occupancy, checked on schedules and never converted to time. -/
def Machine.Fits (m : Machine) (e : Execution) : Prop :=
  e.peakRegisters ≤ m.registers

/-- The relaxation a lower bound argues over. Every run of the family lands
here; points here need not be runs of anything. -/
def Feasible (o : Obligations) (m : Machine) (e : Execution) : Prop :=
  o.Meets e ∧ m.Serves e

instance (o : Obligations) (e : Execution) : Decidable (o.Meets e) :=
  inferInstanceAs (Decidable (LeVec _ _))

instance (m : Machine) (e : Execution) : Decidable (m.Serves e) :=
  inferInstanceAs (Decidable (LeVec _ _))

instance (o : Obligations) (m : Machine) (e : Execution) : Decidable (Feasible o m e) :=
  inferInstanceAs (Decidable (_ ∧ _))

/-- Row lengths agree with the number of instruction classes. Padding makes a
mismatch harmless rather than unsound, but a checker should still reject it. -/
def Obligations.Wf (o : Obligations) (classes : Nat) : Bool :=
  o.rows.length == o.rhs.length && o.rows.all (fun r => r.length == classes)

def Machine.Wf (m : Machine) (classes : Nat) : Bool :=
  m.demand.length == m.capacity.length && m.demand.all (fun r => r.length == classes)

/-! ## The dual certificate -/

/-- Nonnegative dual weights with denominators already cleared: `cut` is `λ` over
the semantic rows, `price` is `μ` over the resources. -/
structure Certificate where
  cut : List Nat
  price : List Nat
deriving Repr

/-- `Aᵀλ ≤ Dᵀμ`, decidable, and the only condition a checker has to agree on. -/
def Certificate.check (c : Certificate) (o : Obligations) (m : Machine) : Bool :=
  leAll (combine c.cut o.rows) (combine c.price m.demand)

/-- `λ·b`, the numerator of the bound. -/
def Certificate.work (c : Certificate) (o : Obligations) : Int :=
  dot (emb c.cut) o.rhs

/-- `μ·c`, the service the priced resources deliver per tick. -/
def Certificate.service (c : Certificate) (m : Machine) : Int :=
  dot (emb c.price) m.capacity

/-- Weak duality on the count relaxation: `λ·b ≤ T (μ·c)`. The rational bound is
`T ≥ (λ·b)/(μ·c)`; this is its cleared-denominator form, and it holds for every
feasible point whatever the denominators were. -/
theorem Certificate.bound {o : Obligations} {m : Machine} {e : Execution}
    (c : Certificate) (hc : c.check o m = true) (hf : Feasible o m e) :
    c.work o ≤ (e.ticks : Int) * c.service m := by
  obtain ⟨hmeets, hserves⟩ := hf
  have h1 : c.work o ≤ dot (emb c.cut) (o.rows.map (fun a => dotN a e.counts)) :=
    dot_le_dot _ _ _ (nonneg_emb _) hmeets
  have h2 : dot (emb c.cut) (o.rows.map (fun a => dotN a e.counts))
      = dot (combine c.cut o.rows) (emb e.counts) := (dot_combine _ _ _).symm
  have h3 : dot (combine c.cut o.rows) (emb e.counts)
      ≤ dot (combine c.price m.demand) (emb e.counts) :=
    dot_le_dot_left _ _ _ (nonneg_emb _) ((leAll_iff _ _).mp hc)
  have h4 : dot (combine c.price m.demand) (emb e.counts)
      = dot (emb c.price) (m.demand.map (fun d => dotN d e.counts)) := dot_combine _ _ _
  have h5 : dot (emb c.price) (m.demand.map (fun d => dotN d e.counts))
      ≤ dot (emb c.price) (smul (e.ticks : Int) m.capacity) :=
    dot_le_dot _ _ _ (nonneg_emb _) hserves
  have h6 : dot (emb c.price) (smul (e.ticks : Int) m.capacity)
      = (e.ticks : Int) * c.service m := by
    rw [dot_comm, dot_smul, dot_comm]
    rfl
  omega

/-- Retain column slack as an instruction-count penalty. Positive penalties
exclude instructions from a tight optimum and bound their counts near it. -/
theorem Certificate.penalty_bound {o : Obligations} {m : Machine} {e : Execution}
    (c : Certificate) (penalty : List Int)
    (hc : leAll (vadd (combine c.cut o.rows) penalty) (combine c.price m.demand) = true)
    (hf : Feasible o m e) :
    c.work o + dotN penalty e.counts ≤ (e.ticks : Int) * c.service m := by
  obtain ⟨hmeets, hserves⟩ := hf
  have h1 := dot_le_dot (emb c.cut) o.rhs
    (o.rows.map (fun a => dotN a e.counts)) (nonneg_emb _) hmeets
  have h2 := dot_le_dot_left
    (vadd (combine c.cut o.rows) penalty) (combine c.price m.demand)
    (emb e.counts) (nonneg_emb _) ((leAll_iff _ _).mp hc)
  rw [dot_vadd, dot_combine, dot_combine] at h2
  have h3 := dot_le_dot (emb c.price)
    (m.demand.map (fun d => dotN d e.counts))
    (smul (e.ticks : Int) m.capacity) (nonneg_emb _) hserves
  have h4 : dot (emb c.price) (smul (e.ticks : Int) m.capacity)
      = (e.ticks : Int) * c.service m := by
    rw [dot_comm, dot_smul, dot_comm]
    rfl
  change c.work o ≤ _ at h1
  change _ + dotN penalty e.counts ≤ _ at h2
  simp only [dotN] at *
  omega

/-- The budget is an additional premise, not a conclusion of a lower bound. -/
theorem Certificate.penalty_budget {o : Obligations} {m : Machine} {e : Execution}
    (c : Certificate) (penalty : List Int) (B : Nat)
    (hc : leAll (vadd (combine c.cut o.rows) penalty) (combine c.price m.demand) = true)
    (hf : Feasible o m e) (hs : 0 ≤ c.service m) (hb : e.ticks ≤ B) :
    dotN penalty e.counts ≤ (B : Int) * c.service m - c.work o := by
  have h1 := c.penalty_bound penalty hc hf
  have h2 := Int.mul_le_mul_of_nonneg_right (show (e.ticks : Int) ≤ (B : Int) by omega) hs
  omega

/-! ## Turning the inequality into a tick count -/

/-- `⌈work / service⌉`, and `0` when the certificate carries no information. -/
def ceilBound (work service : Int) : Nat :=
  if 0 < service ∧ 0 < work then (work.toNat + service.toNat - 1) / service.toNat else 0

theorem ceilBound_le {work service : Int} {T : Nat} (hs : 0 < service)
    (h : work ≤ (T : Int) * service) : ceilBound work service ≤ T := by
  unfold ceilBound
  split
  case isFalse => exact Nat.zero_le _
  case isTrue hcond =>
    have hw : 0 < work := hcond.2
    have hW : (work.toNat : Int) = work := Int.toNat_of_nonneg (by omega)
    have hS : (service.toNat : Int) = service := Int.toNat_of_nonneg (by omega)
    have hSpos : 0 < service.toNat := by omega
    have hmul : work.toNat ≤ T * service.toNat := by
      have : (work.toNat : Int) ≤ ((T * service.toNat : Nat) : Int) := by
        push_cast
        rw [hW, hS]
        exact h
      omega
    rcases Nat.lt_or_ge T ((work.toNat + service.toNat - 1) / service.toNat) with hcon | hok
    · exfalso
      have hlt : T + 1 ≤ (work.toNat + service.toNat - 1) / service.toNat := hcon
      have hdiv := (Nat.le_div_iff_mul_le hSpos).mp hlt
      have hexp : (T + 1) * service.toNat = T * service.toNat + service.toNat := by
        rw [Nat.succ_mul]
      omega
    · exact hok

/-! ## Families, and where the premises enter -/

/-- A program family on a fixed machine, together with the two premises that put
its runs inside the relaxation. `Target` names what the family computes; two
families may be compared only when they carry the same target, which is what
lets a rival family use instructions this one does not have. -/
structure Family (m : Machine) (Target : Type) where
  target : Target
  runs : Execution → Prop
  obligations : Obligations
  /-- Semantic premise: justified outside this structure, and conditional. -/
  meets : ∀ e, runs e → obligations.Meets e
  /-- Service premise: the capacities are ceilings the hardware cannot beat. -/
  serves : ∀ e, runs e → m.Serves e

theorem Family.feasible {m : Machine} {T : Type} (f : Family m T) {e : Execution}
    (he : f.runs e) : Feasible f.obligations m e :=
  ⟨f.meets e he, f.serves e he⟩

/-- A lower bound on the tick count of every run, on a named clock. -/
structure LowerBound (clk : Clock) (Runs : Execution → Prop) where
  ticks : Nat
  sound : ∀ e, Runs e → ticks ≤ e.ticks

/-- An upper bound backed by an exhibited run. Model feasibility alone never
constructs one: see `feasible_is_not_a_run`. -/
structure UpperBound (clk : Clock) (Runs : Execution → Prop) where
  ticks : Nat
  witness : Execution
  runs : Runs witness
  achieves : witness.ticks ≤ ticks

/-- The service lower bound of a checked certificate. -/
def Family.lower {m : Machine} {T : Type} (f : Family m T) (c : Certificate)
    (hc : c.check f.obligations m = true) (hs : 0 < c.service m) :
    LowerBound m.clock f.runs where
  ticks := ceilBound (c.work f.obligations) (c.service m)
  sound := fun _ he => ceilBound_le hs (c.bound hc (f.feasible he))

@[simp] theorem Family.lower_ticks {m : Machine} {T : Type} (f : Family m T) (c : Certificate)
    (hc : c.check f.obligations m = true) (hs : 0 < c.service m) :
    (f.lower c hc hs).ticks = ceilBound (c.work f.obligations) (c.service m) := rfl

/-- Per-class issue-to-use latency, a hardware input. -/
structure Latency where
  perClass : List Nat
deriving Repr

/-- Total latency along a dependency path. -/
def Latency.chain (l : Latency) (path : List Nat) : Nat :=
  (path.map (fun j => l.perClass.getD j 0)).sum

/-- A dependency-path lower bound. The path and the claim that every run
contains it are a separate obligation from the service premise; the latencies
are separate hardware data from the capacities. -/
def LowerBound.ofChain {clk : Clock} {Runs : Execution → Prop} (l : Latency)
    (path : List Nat) (h : ∀ e, Runs e → l.chain path ≤ e.ticks) :
    LowerBound clk Runs where
  ticks := l.chain path
  sound := h

@[simp] theorem LowerBound.ofChain_ticks {clk : Clock} {Runs : Execution → Prop} (l : Latency)
    (path : List Nat) (h : ∀ e, Runs e → l.chain path ≤ e.ticks) :
    (LowerBound.ofChain (clk := clk) l path h).ticks = l.chain path := rfl

/-- Without a further non-overlap premise, two lower bounds on the same runs
combine by maximum. Disjoint sequential regions can support stronger rules. -/
def LowerBound.max {clk : Clock} {Runs : Execution → Prop}
    (a b : LowerBound clk Runs) : LowerBound clk Runs where
  ticks := Nat.max a.ticks b.ticks
  sound := fun e he => Nat.max_le.mpr ⟨a.sound e he, b.sound e he⟩

@[simp] theorem LowerBound.max_ticks {clk : Clock} {Runs : Execution → Prop}
    (a b : LowerBound clk Runs) : (a.max b).ticks = Nat.max a.ticks b.ticks := rfl

/-- An upper bound from an exhibited run. Whatever establishes `Runs e` —
a port-reservation schedule, a dependency check, an endpoint replay — is the
supplier's obligation, discharged before this is called. -/
def UpperBound.ofRun {clk : Clock} {Runs : Execution → Prop} (e : Execution)
    (he : Runs e) : UpperBound clk Runs where
  ticks := e.ticks
  witness := e
  runs := he
  achieves := Nat.le_refl _

@[simp] theorem UpperBound.ofRun_ticks {clk : Clock} {Runs : Execution → Prop} (e : Execution)
    (he : Runs e) : (UpperBound.ofRun (clk := clk) e he).ticks = e.ticks := rfl

@[simp] theorem UpperBound.ofRun_witness {clk : Clock} {Runs : Execution → Prop} (e : Execution)
    (he : Runs e) : (UpperBound.ofRun (clk := clk) e he).witness = e := rfl

/-! ## Comparisons -/

/-- The exhibited run is optimal: no run is faster, and it meets the bound. -/
theorem optimal {clk : Clock} {Runs : Execution → Prop}
    (lo : LowerBound clk Runs) (up : UpperBound clk Runs) (h : up.ticks ≤ lo.ticks) :
    ∀ e, Runs e → up.witness.ticks ≤ e.ticks := by
  intro e he
  have h1 := lo.sound e he
  have h2 := up.achieves
  omega

/-- `a` is dominated by `b`: same target, same machine, and some run of `b` beats
every run of `a`. -/
def Dominates {m : Machine} {T : Type} (a b : Family m T) : Prop :=
  a.target = b.target ∧ ∃ w, b.runs w ∧ ∀ e, a.runs e → w.ticks < e.ticks

/-- Conditional strict domination. The conclusion is only as strong as `lo`,
which rests on `a`'s two premises, and `up`, which rests on an exhibited run of
`b`. Both families are charged against the same machine, so no capacity
difference is smuggled in with the comparison. -/
theorem dominates {m : Machine} {T : Type} {a b : Family m T}
    (hshare : a.target = b.target)
    (lo : LowerBound m.clock a.runs) (up : UpperBound m.clock b.runs)
    (h : up.ticks < lo.ticks) : Dominates a b := by
  refine ⟨hshare, up.witness, up.runs, ?_⟩
  intro e he
  have h1 := lo.sound e he
  have h2 := up.achieves
  omega

/-! ## Native time

Ticks become seconds only against a calibration, and the calibration is an
assumption about the machine, not a consequence of anything above.
-/

/-- Ticks of `clk` per second. To be sound as a premise this must be a ceiling
on how fast the clock can advance, which a measured average rate is not. -/
structure TickRate (clk : Clock) where
  perSecond : Nat
  pos : 0 < perSecond

/-- An exact duration `num / den` seconds. -/
structure Seconds where
  num : Nat
  den : Nat
  denPos : 0 < den
deriving Repr

/-- A tick lower bound becomes a wall-clock lower bound, in cleared form:
`ticks / rate ≤ num / den` seconds. The hypothesis `hcal` is the calibration
applied to this run. -/
theorem native_seconds {clk : Clock} {Runs : Execution → Prop}
    (lo : LowerBound clk Runs) (r : TickRate clk) {e : Execution} (he : Runs e)
    (t : Seconds) (hcal : e.ticks * t.den ≤ t.num * r.perSecond) :
    lo.ticks * t.den ≤ t.num * r.perSecond := by
  have h := lo.sound e he
  have := Nat.mul_le_mul_right t.den h
  omega

/-! ## Deriving a cut from a program

The semantic premise is the load-bearing one, so the framework provides an
honest way to discharge it rather than leaving cuts arbitrary. Take a potential
Φ on complete machine states. If the initial state has `Φ ≥ b`, every accepting
state has `Φ ≤ 0`, and one instruction of class `j` can drop Φ by at most `w j`
on the reachable domain, then telescoping gives `w ⋅ n ≥ b` for every successful
program. No monotonicity and no recognisable intermediate values are needed, so
a Bellman certificate from a finite-state search lands here directly.
-/

/-- A labelled transition relation on complete machine states. `R j s s'` says
one instruction of class `j` can carry the machine from `s` to `s'`. It is a
relation, not a function, so a class may cover many operand choices, immediate
values or memory contents without splitting into more classes. -/
def Chain {S : Type} (R : Nat → S → S → Prop) : S → List (Nat × S) → Prop
  | _, [] => True
  | s, (j, s') :: rest => R j s s' ∧ Chain R s' rest

/-- The state a chain ends in. -/
def final {S : Type} : S → List (Nat × S) → S
  | s, [] => s
  | _, (_, s') :: rest => final s' rest

/-- The instruction classes a chain issues, in order. -/
def labels {S : Type} (steps : List (Nat × S)) : List Nat := steps.map Prod.fst

theorem labels_cons {S : Type} (j : Nat) (s : S) (rest : List (Nat × S)) :
    labels ((j, s) :: rest) = j :: labels rest := rfl

/-- Telescoping along a chain, inside a domain closed under the allowed steps. -/
theorem chain_drop {S : Type} (Φ : S → Int) (R : Nat → S → S → Prop) (dom : S → Prop)
    (w : List Int) (k : Nat)
    (closed : ∀ j s s', j < k → dom s → R j s s' → dom s')
    (drop : ∀ j s s', j < k → dom s → R j s s' → Φ s - Φ s' ≤ w.getD j 0)
    (steps : List (Nat × S)) (ht : ∀ j ∈ labels steps, j < k) (s : S) (hs : dom s)
    (hc : Chain R s steps) :
    Φ s - Φ (final s steps) ≤ traceWeight w (labels steps) := by
  induction steps generalizing s with
  | nil => simp [final, labels, traceWeight]
  | cons step rest ih =>
    obtain ⟨j, s'⟩ := step
    have hj : j < k := ht j (by simp [labels_cons])
    have hrest : ∀ i ∈ labels rest, i < k := fun i hi => ht i (by simp [labels_cons, hi])
    have hstep := drop j s s' hj hs hc.1
    have hdom' := closed j s s' hj hs hc.1
    have htail := ih hrest s' hdom' hc.2
    have hw : traceWeight w (labels ((j, s') :: rest)) = w.getD j 0 + traceWeight w (labels rest) := by
      simp [labels_cons, traceWeight]
    have hfin : final s ((j, s') :: rest) = final s' rest := rfl
    rw [hfin, hw]
    omega

/-- A semantic cut from a potential argument. Every chain that starts above `b`
and ends at or below zero has counts satisfying `w ⋅ n ≥ b`. -/
theorem potential_cut {S : Type} (Φ : S → Int) (R : Nat → S → S → Prop) (dom : S → Prop)
    (w : List Int) (k : Nat)
    (closed : ∀ j s s', j < k → dom s → R j s s' → dom s')
    (drop : ∀ j s s', j < k → dom s → R j s s' → Φ s - Φ s' ≤ w.getD j 0)
    (steps : List (Nat × S)) (ht : ∀ j ∈ labels steps, j < k) (s₀ : S) (hs₀ : dom s₀)
    (hc : Chain R s₀ steps) (b : Int)
    (hstart : b ≤ Φ s₀) (haccept : Φ (final s₀ steps) ≤ 0) :
    b ≤ dotN w (histogram k (labels steps)) := by
  have h := chain_drop Φ R dom w k closed drop steps ht s₀ hs₀ hc
  rw [dotN_histogram w k (labels steps) ht]
  omega

/-- The counts a chain contributes to an execution. -/
def chainCounts {S : Type} (k : Nat) (steps : List (Nat × S)) : List Nat :=
  histogram k (labels steps)

theorem chainCounts_length {S : Type} (k : Nat) (steps : List (Nat × S)) :
    (chainCounts k steps).length = k := histogram_length k (labels steps)

/-! ## Pinned instances

Two instruction classes, one unit of each required: `A = I₂`, `b = (1,1)`. The
same semantic side is charged against one shared port and against two
independent ports, which is where a checker and this file have to agree on how
overlap is normalised. Capacities are summed in the denominator of one shared
makespan; times are never summed.
-/

/-- `A = I₂`, `b = (1,1)`: one instruction of each class is required. -/
def pairCuts : Obligations where
  rows := [[1, 0], [0, 1]]
  rhs := [1, 1]

/-- Both classes contend for one port of unit capacity. -/
def onePort : Machine where
  clock := ⟨"tick"⟩
  demand := [[1, 1]]
  capacity := [1]
  registers := 64

/-- Each class has its own port of unit capacity. -/
def twoPorts : Machine where
  clock := ⟨"tick"⟩
  demand := [[1, 0], [0, 1]]
  capacity := [1, 1]
  registers := 64

/-- `λ = (1,1)` on both, `μ = 1` on the shared port and `μ = (1,1)` on the pair. -/
def sharedCert : Certificate := ⟨[1, 1], [1]⟩
def splitCert : Certificate := ⟨[1, 1], [1, 1]⟩

/-- One instruction of each class, issued in the same tick. -/
def parallelPair : Execution where
  counts := [1, 1]
  ticks := 1
  peakRegisters := 2

theorem parallelPair_feasible : Feasible pairCuts twoPorts parallelPair := by decide

/-- Contending for one port: `λ·b = 2`, `μ·c = 1`, bound 2. -/
theorem one_port_bound :
    sharedCert.check pairCuts onePort = true ∧
      sharedCert.work pairCuts = 2 ∧ sharedCert.service onePort = 1 ∧
      ceilBound (sharedCert.work pairCuts) (sharedCert.service onePort) = 2 := by
  refine ⟨by decide, by decide, by decide, by decide⟩

/-- Two independent ports: same `λ·b = 2`, but `μ·c = 2`, bound 1. The two
capacities meet in the denominator of a single makespan. -/
theorem two_ports_bound :
    splitCert.check pairCuts twoPorts = true ∧
      splitCert.work pairCuts = 2 ∧ splitCert.service twoPorts = 2 ∧
      ceilBound (splitCert.work pairCuts) (splitCert.service twoPorts) = 1 := by
  refine ⟨by decide, by decide, by decide, by decide⟩

/-- The bound of 1 is attained by the two independent instructions. -/
theorem two_ports_attained :
    Feasible pairCuts twoPorts parallelPair ∧
      parallelPair.ticks = ceilBound (splitCert.work pairCuts) (splitCert.service twoPorts) := by
  exact ⟨parallelPair_feasible, by decide⟩

/-! ### A dependency chain on the same reservations

Four ticks of dependent latency over the same one-tick port reservations. The
dual bound stays at 1, so the exhibited four-tick run is not proved optimal by
the certificate. The latency premise is what closes the gap, and only through
`LowerBound.max`.
-/

/-- The same two instructions, now serialised by a dependency. -/
def chainRun : Execution where
  counts := [1, 1]
  ticks := 4
  peakRegisters := 2

/-- The family whose only run is `chainRun`. -/
def chainFamily : Family twoPorts Unit where
  target := ()
  runs := fun e => e = chainRun
  obligations := pairCuts
  meets := by intro e he; subst he; decide
  serves := by intro e he; subst he; decide

/-- Issue-to-use latency of four ticks on class 0. -/
def chainLatency : Latency := ⟨[4, 0]⟩

theorem chain_dual_bound :
    (chainFamily.lower splitCert (by decide) (by decide)).ticks = 1 := by
  decide

/-- The dual certificate reports 1 against a run of 4: a gap, not an optimum. -/
theorem chain_dual_is_not_optimality :
    ¬ ((UpperBound.ofRun (clk := twoPorts.clock) chainRun rfl).ticks ≤
      (chainFamily.lower splitCert (by decide) (by decide)).ticks) := by
  decide

/-- Supplying the dependency premise closes it, through `max`. The latency and
the service bound are still two separate facts about the same makespan. -/
theorem chain_optimum_needs_latency :
    ∀ e, chainFamily.runs e → chainRun.ticks ≤ e.ticks := by
  refine optimal ((chainFamily.lower splitCert (by decide) (by decide)).max
      (LowerBound.ofChain chainLatency [0] (by intro e he; subst he; decide)))
    (UpperBound.ofRun chainRun rfl) ?_
  decide

/-! ## What the framework refuses to prove

Executions that satisfy every premise while violating the tempting combination
rules. They are countermodels, so they settle the question rather than warn
about it.
-/

/-- Each port on its own forces one tick. -/
theorem each_port_forces_one :
    (Certificate.mk [1, 0] [1, 0]).work pairCuts = 1 ∧
      (Certificate.mk [1, 0] [1, 0]).service twoPorts = 1 ∧
      (Certificate.mk [0, 1] [0, 1]).work pairCuts = 1 ∧
      (Certificate.mk [0, 1] [0, 1]).service twoPorts = 1 := by
  refine ⟨by decide, by decide, by decide, by decide⟩

/-- Adding the two ports' own bounds claims two ticks. An execution satisfying
every premise takes one, because the ports run at the same time. Only the shared
makespan may appear on the right of a service bound. -/
theorem parallel_resources_are_not_sequential :
    ¬ (∀ e, Feasible pairCuts twoPorts e → 2 ≤ e.ticks) := by
  intro h
  have := h parallelPair parallelPair_feasible
  simp [parallelPair] at this

/-- A service bound of 1 and a dependency bound of 4 both hold of a run that
takes 4 ticks, so their sum is not a lower bound. `LowerBound.max` is the
combinator; there is no `+`. -/
theorem sum_is_not_a_lower_bound :
    ∃ (a b : LowerBound twoPorts.clock chainFamily.runs),
      a.ticks = 1 ∧ b.ticks = 4 ∧ ¬ (∀ e, chainFamily.runs e → a.ticks + b.ticks ≤ e.ticks) := by
  refine ⟨chainFamily.lower splitCert (by decide) (by decide),
    LowerBound.ofChain chainLatency [0] (by intro e he; subst he; decide),
    chain_dual_bound, by decide, ?_⟩
  intro h
  have := h chainRun rfl
  simp [chainRun, chainFamily, Family.lower, LowerBound.ofChain, chainLatency,
    Latency.chain, ceilBound, splitCert, pairCuts, Certificate.work, Certificate.service,
    twoPorts, dot, emb] at this

/-- A point of the relaxation is not a program. This family has no runs at all
while the relaxation has a feasible point, so no upper bound follows from
feasibility. That is why `UpperBound` demands a run. -/
theorem feasible_is_not_a_run :
    (∃ e, Feasible pairCuts twoPorts e) ∧
      (UpperBound ⟨"tick"⟩ (fun _ : Execution => False) → False) := by
  refine ⟨⟨parallelPair, parallelPair_feasible⟩, ?_⟩
  intro up
  exact up.runs

/-- The service premise is load-bearing. An execution that issues more work than
the capacities allow breaks the bound, so the bound is a claim about machines
that honour `capacity`, not a fact of arithmetic. -/
theorem capacity_premise_is_load_bearing :
    ∃ e : Execution, pairCuts.Meets e ∧ ¬ onePort.Serves e ∧
      e.ticks < ceilBound (sharedCert.work pairCuts) (sharedCert.service onePort) := by
  refine ⟨⟨[1, 1], 1, 2⟩, by decide, by decide, by decide⟩

#print axioms Certificate.bound
#print axioms potential_cut
#print axioms dominates

end Kelana.ResourceBounds
