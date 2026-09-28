import Kelana.ResourceBounds

/-!
Conditional arithmetic behind the PERM observer profile. This is not a native
issue-rate theorem. Counts are [PERM, combiner]; a declared slot resource charges
one unit to each. Every use must justify both the eight-products contribution
cut and its chosen combiner cut for its own program family.
-/
namespace Kelana.PermResourceBounds
open Kelana.ResourceBounds Kelana.ResourceVectors

def slotMachine : Machine := ⟨⟨"declared issue slots"⟩, [[1, 1]], [1], 0⟩

/-- Each PERM contributes at most eight required lane-MACs. An independent
incoming accumulator requires 2*combiner >= PERM in this reduction grammar. -/
def runningCuts (macs : Nat) : Obligations :=
  ⟨[[8, 0], [-1, 2]], [(macs : Int), 0]⟩

def runningDual : Certificate := ⟨[3, 8], [16]⟩

/-- Under these premises, slots >= 3*macs/16. -/
theorem running_bound (macs : Nat) (e : Execution)
    (h : Feasible (runningCuts macs) slotMachine e) :
    3 * (macs : Int) ≤ (e.ticks : Int) * 16 := by
  have hcheck : runningDual.check (runningCuts macs) slotMachine = true := by rfl
  have bound := runningDual.bound hcheck h
  simpa [Certificate.work, Certificate.service, runningDual, runningCuts,
    slotMachine, dot, emb] using bound

/-- A weaker family cut: removable zero accumulator, rounds of at least two
partials. Its reduction-tree premise is 3*combiner >= PERM. -/
def removableCuts (macs : Nat) : Obligations :=
  ⟨[[8, 0], [-1, 3]], [(macs : Int), 0]⟩

def removableDual : Certificate := ⟨[1, 2], [6]⟩

theorem removable_bound (macs : Nat) (e : Execution)
    (h : Feasible (removableCuts macs) slotMachine e) :
    (macs : Int) ≤ (e.ticks : Int) * 6 := by
  have hcheck : removableDual.check (removableCuts macs) slotMachine = true := by rfl
  have bound := removableDual.bound hcheck h
  simpa [Certificate.work, Certificate.service, removableDual, removableCuts,
    slotMachine, dot, emb] using bound

/-- If even a single uncombined lookup can be the answer, only the contribution
cut remains. No accumulation overhead follows from this premise. -/
def singleCuts (macs : Nat) : Obligations := ⟨[[8, 0]], [(macs : Int)]⟩
def singleDual : Certificate := ⟨[1], [8]⟩

theorem single_bound (macs : Nat) (e : Execution)
    (h : Feasible (singleCuts macs) slotMachine e) :
    (macs : Int) ≤ (e.ticks : Int) * 8 := by
  have hcheck : singleDual.check (singleCuts macs) slotMachine = true := by rfl
  have bound := singleDual.bound hcheck h
  simpa [Certificate.work, Certificate.service, singleDual, singleCuts,
    slotMachine, dot, emb] using bound

/-- Dropping the running-accumulator premise really admits a counterexample to
its stronger floor, even under the same charging model. -/
theorem running_premise_matters :
    Feasible (singleCuts 8) slotMachine ⟨[1, 0], 1, 0⟩ ∧
    ¬ (3 * (8 : Int) ≤ (1 : Int) * 16) := by decide

end Kelana.PermResourceBounds
