import Kelana.ResourceBounds

/-!
# Two instruction-resource models for the same job

A packed-arithmetic family and a scalar family, both computing the same
multiply-accumulate products, both charged against the same machine. Three
instruction classes share one issue port:

| class | instruction         | products per issue | issue slots |
|-------|---------------------|--------------------|-------------|
| 0     | packed multiply-add | `lanes`            | 1           |
| 1     | scalar multiply-add | 1                  | 1           |
| 2     | operand shuffle     | 0                  | 1           |

`lanes`, `issue` and `regs` are inputs from a hardware profile, not facts
established here, and every result below carries them. `group` is how many
packed issues one shuffle prepares: an amortisation claim about a particular
code shape, not an ISA constant. No native time appears anywhere — the clock is
the issue tick, and converting ticks to seconds needs a `TickRate` this file
never supplies.

The scalar family's cut `n_fma ≥ products` assumes separately required products
and one scalar instruction for each. Excluding packed instructions alone does
not establish this: a different algebraic algorithm might avoid those products.
The packed family's cuts assume the stated product accounting and shuffle
amortisation. Both stay premises, carried into every conclusion.
-/

namespace Kelana.ResourceModels

open Kelana.ResourceVectors Kelana.ResourceBounds

/-- What both families compute. Sharing this value is the caller's claim that
the two families do the same job; nothing here checks it. -/
structure Task where
  products : Nat
deriving DecidableEq, Repr

structure Model where
  /-- Products one packed multiply-add retires. -/
  lanes : Nat
  /-- Packed issues prepared by one operand shuffle. -/
  group : Nat
  /-- Issue slots the shared port offers per tick. -/
  issue : Nat
  /-- Architectural register budget a schedule must fit in. -/
  regs : Nat
  /-- Problem scale in blocks. -/
  q : Nat
deriving Repr

/-- Price the issue port at one, charge the product cut at one. -/
def scalarCert : Certificate := ⟨[1], [1]⟩

namespace Model

variable (mo : Model)

def machine : Machine where
  clock := ⟨"issue-tick"⟩
  demand := [[1, 1, 1]]
  capacity := [(mo.issue : Int)]
  registers := mo.regs

/-- Shuffles in one problem instance. -/
def perm : Nat := mo.issue * mo.q

/-- Packed multiply-adds in one problem instance. -/
def packed : Nat := mo.group * mo.perm

/-- Products the job must retire. -/
def products : Nat := mo.lanes * mo.packed

def task : Task := ⟨mo.products⟩

/-- Ticks the scalar family needs before rounding. -/
def scalarTicks : Nat := mo.lanes * mo.group * mo.q

/-- Ticks the exhibited packed schedule takes. -/
def packedTicks : Nat := (mo.group + 1) * mo.q

/-- `n_fma ≥ products`: a scalar multiply-add retires one product, and this
family issues nothing else that retires any. -/
def scalarObligations : Obligations where
  rows := [[0, 1, 0]]
  rhs := [(mo.products : Int)]

/-- `lanes·n_pk + n_fma ≥ products` and `group·n_perm ≥ n_pk`. -/
def packedObligations : Obligations where
  rows := [[(mo.lanes : Int), 1, 0], [-1, 0, (mo.group : Int)]]
  rhs := [(mo.products : Int), 0]

/-- `λ = (group+1, lanes)`, `μ = lanes·group`: the cleared form of the rational
certificate `λ = (1 + 1/group, lanes/group)`, `μ = lanes`. -/
def packedCert : Certificate := ⟨[mo.group + 1, mo.lanes], [mo.lanes * mo.group]⟩

/-- The schedule the packed family exhibits: every product packed, one shuffle
per `group` packed issues, the issue port saturated for `packedTicks`. -/
def packedSchedule : Execution where
  counts := [mo.packed, 0, mo.perm]
  ticks := mo.packedTicks
  peakRegisters := mo.regs

theorem products_eq : mo.products = mo.scalarTicks * mo.issue := by
  simp [products, packed, perm, scalarTicks, Nat.mul_comm, Nat.mul_left_comm]

theorem packed_work_eq :
    (mo.group + 1) * mo.products = mo.packedTicks * (mo.lanes * mo.group * mo.issue) := by
  simp [products, packed, perm, packedTicks, Nat.succ_mul, Nat.mul_add,
    Nat.mul_comm, Nat.mul_left_comm]

theorem issue_eq : mo.packed + mo.perm = mo.packedTicks * mo.issue := by
  simp [packed, perm, packedTicks, Nat.succ_mul, Nat.mul_add,
    Nat.mul_comm, Nat.mul_left_comm]

end Model

/-! ## Both certificates check -/

theorem scalar_check (mo : Model) :
    scalarCert.check mo.scalarObligations mo.machine = true := by
  rfl

theorem scalar_work (mo : Model) :
    scalarCert.work mo.scalarObligations = (mo.products : Int) := by
  simp [Certificate.work, scalarCert, Model.scalarObligations, dot, emb]

theorem scalar_service (mo : Model) :
    scalarCert.service mo.machine = (mo.issue : Int) := by
  simp [Certificate.service, scalarCert, Model.machine, dot, emb]

theorem packed_check (mo : Model) (hg : mo.group + 1 ≤ mo.lanes * mo.group) :
    mo.packedCert.check mo.packedObligations mo.machine = true := by
  rw [Certificate.check, leAll_iff]
  simp only [Model.packedCert, Model.packedObligations, Model.machine, combine, smul, vadd,
    List.map_cons, List.map_nil]
  have hc : (mo.group : Int) * (mo.lanes : Int) = (mo.lanes : Int) * (mo.group : Int) :=
    Int.mul_comm _ _
  refine ⟨?_, ?_, ?_, by simp [LeVec]⟩
  · push_cast
    rw [Int.add_mul, Int.one_mul]
    omega
  · push_cast
    omega
  · push_cast
    omega

theorem packed_work (mo : Model) :
    mo.packedCert.work mo.packedObligations = (((mo.group + 1) * mo.products : Nat) : Int) := by
  simp only [Certificate.work, Model.packedCert, Model.packedObligations, dot, emb,
    List.map_cons, List.map_nil]
  push_cast
  rw [Int.add_mul, Int.one_mul]
  omega

theorem packed_service (mo : Model) :
    mo.packedCert.service mo.machine = ((mo.lanes * mo.group : Nat) : Int) * (mo.issue : Int) := by
  simp only [Certificate.service, Model.packedCert, Model.machine, dot, emb,
    List.map_cons, List.map_nil]
  omega

/-! ## The exhibited schedule is model feasible

The upper bound rests on a supplied run, not on this lemma. These counts satisfy
the packed cuts, the issue-port service bound and the register budget. This
shows consistency of the relaxation, not existence of a run.
-/

theorem packedSchedule_feasible (mo : Model) :
    Feasible mo.packedObligations mo.machine mo.packedSchedule ∧
      mo.machine.Fits mo.packedSchedule := by
  have hprod : mo.products = mo.lanes * mo.packed := rfl
  have hissue := mo.issue_eq
  refine ⟨⟨?_, ?_⟩, Nat.le_refl _⟩
  · refine ⟨?_, ?_, by simp [LeVec]⟩
    · simp only [Model.packedSchedule, List.map_cons, dotN, emb, dot]
      omega
    · simp only [Model.packedSchedule, List.map_cons, dotN, emb, dot, Model.packed]
      omega
  · refine ⟨?_, by simp [LeVec]⟩
    simp only [Model.packedSchedule, List.map_cons, List.map_nil, dotN, emb, dot]
    omega

/-! ## A model optimum

The packed schedule is the fastest run the packed family can have. The
certificate is tight on the packed and shuffle classes; `group + 1 ≤ lanes·group`
is what the scalar class costs.
-/

theorem packed_lower_ticks (mo : Model) (hq : 0 < mo.q) (hl : 0 < mo.lanes)
    (hgp : 0 < mo.group) (hi : 0 < mo.issue) :
    mo.packedTicks ≤ ceilBound (mo.packedCert.work mo.packedObligations)
      (mo.packedCert.service mo.machine) := by
  have hs : 0 < mo.lanes * mo.group * mo.issue :=
    Nat.mul_pos (Nat.mul_pos hl hgp) hi
  have hperm : 0 < mo.perm := Nat.mul_pos hi hq
  have hpk : 0 < mo.packed := Nat.mul_pos hgp hperm
  have hprod : 0 < mo.products := Nat.mul_pos hl hpk
  have hwork := mo.packed_work_eq
  have hw : 0 < (mo.group + 1) * mo.products := Nat.mul_pos (by omega) hprod
  have hcast : ((mo.lanes * mo.group : Nat) : Int) * (mo.issue : Int)
      = ((mo.lanes * mo.group * mo.issue : Nat) : Int) := by push_cast; omega
  rw [packed_work, packed_service, hcast]
  unfold ceilBound
  rw [if_pos (by omega)]
  simp only [Int.toNat_natCast]
  rw [Nat.le_div_iff_mul_le hs]
  omega

/-- No run of the packed family beats the exhibited schedule. -/
theorem packed_optimum (mo : Model) (hq : 0 < mo.q) (hl : 0 < mo.lanes)
    (hgp : 0 < mo.group) (hi : 0 < mo.issue) (hg : mo.group + 1 ≤ mo.lanes * mo.group)
    (fam : Family mo.machine Task) (hobl : fam.obligations = mo.packedObligations)
    (w : Execution) (hw : fam.runs w) (hwt : w.ticks = mo.packedTicks) :
    ∀ e, fam.runs e → w.ticks ≤ e.ticks := by
  have hs : 0 < mo.lanes * mo.group * mo.issue := Nat.mul_pos (Nat.mul_pos hl hgp) hi
  have hcheck : mo.packedCert.check fam.obligations mo.machine = true := by
    rw [hobl]; exact packed_check mo hg
  have hsvc : 0 < mo.packedCert.service mo.machine := by
    rw [packed_service]
    have hcast : ((mo.lanes * mo.group : Nat) : Int) * (mo.issue : Int)
        = ((mo.lanes * mo.group * mo.issue : Nat) : Int) := by push_cast; omega
    omega
  have hlo : mo.packedTicks ≤ (fam.lower mo.packedCert hcheck hsvc).ticks := by
    rw [Family.lower_ticks, hobl]
    exact packed_lower_ticks mo hq hl hgp hi
  refine optimal (fam.lower mo.packedCert hcheck hsvc) (UpperBound.ofRun w hw) ?_
  simp only [UpperBound.ofRun_ticks]
  omega

/-! ## Conditional strict domination

Every run of the scalar family is slower than the exhibited packed run, provided
the packing gain beats the shuffle overhead. Both families are charged against
the same machine, and the conclusion never leaves ticks of the shared clock.
-/

theorem scalar_lower_ticks (mo : Model) (hi : 0 < mo.issue) (hprod : 0 < mo.products) :
    mo.scalarTicks ≤ ceilBound (scalarCert.work mo.scalarObligations)
      (scalarCert.service mo.machine) := by
  have hprods := mo.products_eq
  rw [scalar_work, scalar_service]
  unfold ceilBound
  rw [if_pos (by omega)]
  simp only [Int.toNat_natCast]
  rw [Nat.le_div_iff_mul_le hi]
  omega

theorem packed_dominates_scalar (mo : Model) (hq : 0 < mo.q) (hi : 0 < mo.issue)
    (hl : 0 < mo.lanes) (hgp : 0 < mo.group)
    (hgain : mo.group + 1 < mo.lanes * mo.group)
    (scalar packed : Family mo.machine Task)
    (hst : scalar.target = mo.task) (hpt : packed.target = mo.task)
    (hobl : scalar.obligations = mo.scalarObligations)
    (w : Execution) (hw : packed.runs w) (hwt : w.ticks = mo.packedTicks) :
    Dominates scalar packed := by
  have hperm : 0 < mo.perm := Nat.mul_pos hi hq
  have hpk : 0 < mo.packed := Nat.mul_pos hgp hperm
  have hprod : 0 < mo.products := Nat.mul_pos hl hpk
  have hcheck : scalarCert.check scalar.obligations mo.machine = true := by
    rw [hobl]; exact scalar_check mo
  have hsvc : 0 < scalarCert.service mo.machine := by
    rw [scalar_service]; omega
  have hlo : mo.scalarTicks ≤ (scalar.lower scalarCert hcheck hsvc).ticks := by
    rw [Family.lower_ticks, hobl]
    exact scalar_lower_ticks mo hi hprod
  have hstrict : mo.packedTicks < mo.scalarTicks := by
    simp only [Model.packedTicks, Model.scalarTicks]
    exact (Nat.mul_lt_mul_right hq).mpr hgain
  refine dominates (hst.trans hpt.symm) (scalar.lower scalarCert hcheck hsvc)
    (UpperBound.ofRun w hw) ?_
  simp only [UpperBound.ofRun_ticks]
  omega

#print axioms packed_optimum
#print axioms packed_dominates_scalar

end Kelana.ResourceModels
