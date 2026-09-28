import Kelana.PairedWMMA

/-!
Gate/up pairing through an arbitrary nonlinear and downstream consumer.
The accumulation function is uninterpreted: no associativity, distributivity,
or real-arithmetic replacement of floating-point operations is assumed.
The native WMMA still needs to implement the integer block map below.
-/
namespace Kelana.FFNPairedMap
open PairedWMMA

structure Block (Scale : Type) where
  gate : List Int
  up : List Int
  input : List Int
  gateScale : Scale
  upScale : Scale

def Valid (b : Block Scale) : Prop :=
  b.gate.length = b.up.length ∧
  (∀ w ∈ b.gate, -1 ≤ w ∧ w ≤ 1) ∧
  (∀ w ∈ b.up, -1 ≤ w ∧ w ≤ 1) ∧
  (l1 b.gate ≤ 127 ∧ l1 b.up ≤ 127) ∧
  (∀ x ∈ b.input, -128 ≤ x ∧ x ≤ 127)

def directBlock (b : Block Scale) : Int × Int :=
  (dot b.gate b.input, dot b.up b.input)

def pairedBlock (b : Block Scale) : Int × Int :=
  sparsePairedBlock b.gate b.up b.input

theorem block_correct (b : Block Scale) (h : Valid b) :
    pairedBlock b = directBlock b :=
  sparse_paired_block_correct b.gate b.up b.input h.1 h.2.1 h.2.2.1
    h.2.2.2.1 h.2.2.2.2

def step (accumulate : Scale → Int → F → F)
    (evaluate : Block Scale → Int × Int) (state : F × F) (b : Block Scale) : F × F :=
  let v := evaluate b
  (accumulate b.gateScale v.1 state.1, accumulate b.upScale v.2 state.2)

def run (accumulate : Scale → Int → F → F)
    (evaluate : Block Scale → Int × Int) (initial : F × F)
    (blocks : List (Block Scale)) : F × F :=
  blocks.foldl (step accumulate evaluate) initial

theorem ordered_accumulation_correct
    (accumulate : Scale → Int → F → F) (blocks : List (Block Scale))
    (h : ∀ b ∈ blocks, Valid b) (initial : F × F) :
    run accumulate pairedBlock initial blocks = run accumulate directBlock initial blocks := by
  induction blocks generalizing initial with
  | nil => rfl
  | cons b bs ih =>
    have hb := block_correct b (h b (by simp))
    have ht : ∀ x ∈ bs, Valid x := by intro x hx; exact h x (by simp [hx])
    simp only [run, List.foldl_cons]
    have he : step accumulate pairedBlock initial b = step accumulate directBlock initial b := by
      simp only [step, hb]
    rw [he]
    exact ih ht _

-- The schedule fixes both per-wave block order and cross-wave reduction order.
-- It may be the actual FP32 instruction sequence rather than a sum in a field.
def scheduled (accumulate : Scale → Int → F → F)
    (reduce : List (F × F) → F × F) (evaluate : Block Scale → Int × Int)
    (initial : F × F) (waves : List (List (Block Scale))) : F × F :=
  reduce (waves.map (run accumulate evaluate initial))

theorem scheduled_correct
    (accumulate : Scale → Int → F → F) (reduce : List (F × F) → F × F)
    (initial : F × F) (waves : List (List (Block Scale)))
    (h : ∀ bs ∈ waves, ∀ b ∈ bs, Valid b) :
    scheduled accumulate reduce pairedBlock initial waves =
    scheduled accumulate reduce directBlock initial waves := by
  unfold scheduled
  congr 1
  apply List.map_congr_left
  intro bs hbs
  exact ordered_accumulation_correct accumulate bs (h bs hbs) initial

theorem spanning_consumer_correct
    (accumulate : Scale → Int → F → F) (reduce : List (F × F) → F × F)
    (initial : F × F) (waves : Row → List (List (Block Scale)))
    (h : ∀ row bs, bs ∈ waves row → ∀ b ∈ bs, Valid b)
    (nonlinear : Row → F × F → Hidden)
    (consumer : (Row → Hidden) → Output) :
    consumer (fun row => nonlinear row
      (scheduled accumulate reduce pairedBlock initial (waves row))) =
    consumer (fun row => nonlinear row
      (scheduled accumulate reduce directBlock initial (waves row))) := by
  congr 1
  funext row
  rw [scheduled_correct accumulate reduce initial (waves row) (h row)]

#print axioms spanning_consumer_correct
end Kelana.FFNPairedMap
