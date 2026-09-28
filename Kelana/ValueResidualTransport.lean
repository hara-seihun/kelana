import Kelana.ValueRecordQuotient

/-! Exact finite rational residual transport. Edge residuals are signed amounts;
there is no claim about a particular quantizer, numerical reduction, or routing quality. -/

namespace Kelana.ValueResidualTransport

open ValueRecordQuotient (fiber regroup)

private theorem sum_map_sub (xs : List I) (f g : I → Rat) :
    (xs.map fun i => f i - g i).sum = (xs.map f).sum - (xs.map g).sum := by
  induction xs with
  | nil => grind +ring
  | cons i xs ih =>
    simp only [List.map_cons, List.sum_cons, ih]
    grind +ring

private theorem sum_map_add (xs : List I) (f g : I → Rat) :
    (xs.map fun i => f i + g i).sum = (xs.map f).sum + (xs.map g).sum := by
  induction xs with
  | nil => grind +ring
  | cons i xs ih =>
    simp only [List.map_cons, List.sum_cons, ih]
    grind +ring

/-- Incoming residual minus outgoing residual at a node. -/
def divergence [DecidableEq Node] (edges : List Edge)
    (src dst : Edge → Node) (R : Edge → Rat) (i : Node) : Rat :=
  fiber edges dst R i - fiber edges src R i

/-- The endpoint factor follows from unique, covering node enumeration. In
particular, this theorem uses `regroup`, whose proof exchanges the two finite
sums and reduces each edge's node sum using uniqueness and coverage. -/
theorem endpoint_sum [DecidableEq Node] (nodes : List Node) (edges : List Edge)
    (endpoint : Edge → Node) (R : Edge → Rat) (w : Node → Rat)
    (unique : nodes.Nodup) (covered : ∀ e ∈ edges, endpoint e ∈ nodes) :
    (nodes.map fun i => w i * fiber edges endpoint R i).sum =
      (edges.map fun e => w (endpoint e) * R e).sum := by
  have h := regroup edges nodes endpoint R w unique covered
  simpa only [Rat.mul_comm] using h.symm

/-- Discrete integration by parts, for arbitrary directed edges (not just
adjacent temporal neighbors). The mask is whatever weights are *actually*
applied at the nodes, including zero at unprocessed recipients. -/
theorem weighted_divergence [DecidableEq Node]
    (nodes : List Node) (edges : List Edge)
    (src dst : Edge → Node) (R : Edge → Rat) (w : Node → Rat)
    (unique : nodes.Nodup)
    (srcCovered : ∀ e ∈ edges, src e ∈ nodes)
    (dstCovered : ∀ e ∈ edges, dst e ∈ nodes) :
    (nodes.map fun i => w i * divergence edges src dst R i).sum =
      (edges.map fun e => (w (dst e) - w (src e)) * R e).sum := by
  calc
    (nodes.map fun i => w i * divergence edges src dst R i).sum =
        (nodes.map fun i => w i * fiber edges dst R i -
          w i * fiber edges src R i).sum := by
          apply congrArg List.sum
          apply List.map_congr_left
          intro i _
          simp only [divergence]
          grind +ring
    _ = (nodes.map fun i => w i * fiber edges dst R i).sum -
        (nodes.map fun i => w i * fiber edges src R i).sum := sum_map_sub _ _ _
    _ = (edges.map fun e => w (dst e) * R e).sum -
        (edges.map fun e => w (src e) * R e).sum := by
          rw [endpoint_sum nodes edges dst R w unique dstCovered,
            endpoint_sum nodes edges src R w unique srcCovered]
    _ = (edges.map fun e => (w (dst e) - w (src e)) * R e).sum := by
          rw [← sum_map_sub]
          apply congrArg List.sum
          apply List.map_congr_left
          intro e _
          grind +ring

/-- The actual observer coefficient: a pending node is not charged its
attention weight merely because a recent low-precision value is visible. -/
def mask (processed : Node → Bool) (p : Node → Rat) (i : Node) : Rat :=
  if processed i then p i else 0

/-- At processed nodes the code error has net incoming transport, net
outgoing transport, and an explicit local defect. -/
def codeError [DecidableEq Node] (edges : List Edge)
    (src dst : Edge → Node) (R : Edge → Rat) (defect : Node → Rat)
    (i : Node) : Rat := divergence edges src dst R i + defect i

/-- Ordinary skipped-node error remains a separate additive baseline. -/
theorem observed_error [DecidableEq Node]
    (nodes : List Node) (edges : List Edge)
    (src dst : Edge → Node) (R : Edge → Rat)
    (processed : Node → Bool) (p defect ordinary : Node → Rat)
    (unique : nodes.Nodup)
    (srcCovered : ∀ e ∈ edges, src e ∈ nodes)
    (dstCovered : ∀ e ∈ edges, dst e ∈ nodes) :
    (nodes.map fun i => if processed i then
       p i * codeError edges src dst R defect i else p i * ordinary i).sum =
      (nodes.map fun i => if processed i then 0 else p i * ordinary i).sum +
      (nodes.map fun i => mask processed p i * defect i).sum +
      (edges.map fun e =>
        (mask processed p (dst e) - mask processed p (src e)) * R e).sum := by
  have hdiv := weighted_divergence nodes edges src dst R
    (mask processed p) unique srcCovered dstCovered
  have hpoint (i : Node) :
      (if processed i then p i * codeError edges src dst R defect i
       else p i * ordinary i) =
      (if processed i then 0 else p i * ordinary i) +
      mask processed p i * defect i +
      mask processed p i * divergence edges src dst R i := by
    cases hp : processed i <;> simp [mask, codeError, hp, Rat.mul_add] <;> grind +ring
  have hsum :
      (nodes.map fun i => if processed i then
         p i * codeError edges src dst R defect i else p i * ordinary i).sum =
      (nodes.map fun i => (if processed i then 0 else p i * ordinary i) +
         mask processed p i * defect i +
         mask processed p i * divergence edges src dst R i).sum := by
    apply congrArg List.sum
    apply List.map_congr_left
    intro i _
    exact hpoint i
  rw [hsum, sum_map_add, sum_map_add, hdiv]

/-- An edge from a processed source to a pending destination costs only
`-p_src * R`, even if that destination's recent value is already visible. -/
theorem pending_endpoint (processed : Node → Bool) (p : Node → Rat)
    (src dst : Edge → Node) (R : Edge → Rat) (e : Edge)
    (sourceDone : processed (src e) = true)
    (recipientPending : processed (dst e) = false) :
    (mask processed p (dst e) - mask processed p (src e)) * R e =
      -(p (src e) * R e) := by
  simp only [mask, sourceDone, recipientPending, ite_true]
  grind +ring

/-- For two processed endpoints the coefficient is their weight difference. -/
theorem processed_endpoints (processed : Node → Bool) (p : Node → Rat)
    (src dst : Edge → Node) (R : Edge → Rat) (e : Edge)
    (sourceDone : processed (src e) = true)
    (recipientDone : processed (dst e) = true) :
    (mask processed p (dst e) - mask processed p (src e)) * R e =
      (p (dst e) - p (src e)) * R e := by
  simp [mask, sourceDone, recipientDone]

/-- Same-weight transport between processed nodes cancels in the observer. -/
theorem equal_weight_edge (processed : Node → Bool) (p : Node → Rat)
    (src dst : Edge → Node) (R : Edge → Rat) (e : Edge)
    (sourceDone : processed (src e) = true)
    (recipientDone : processed (dst e) = true)
    (sameWeight : p (dst e) = p (src e)) :
    (mask processed p (dst e) - mask processed p (src e)) * R e = 0 := by
  rw [processed_endpoints processed p src dst R e sourceDone recipientDone,
    sameWeight]
  grind +ring

/-- If every emitted edge originates at a processed node, the recipient
mask determines whether its contribution is a processed weight difference or
the unpaired negative source weight. -/
theorem emitted_edge_cost (processed : Node → Bool) (p : Node → Rat)
    (edges : List Edge) (src dst : Edge → Node) (R : Edge → Rat)
    (sourcesDone : ∀ e ∈ edges, processed (src e) = true) :
    (edges.map fun e =>
      (mask processed p (dst e) - mask processed p (src e)) * R e).sum =
    (edges.map fun e => if processed (dst e) then
      (p (dst e) - p (src e)) * R e else -(p (src e) * R e)).sum := by
  apply congrArg List.sum
  apply List.map_congr_left
  intro e he
  cases hd : processed (dst e)
  · simpa [hd] using
      pending_endpoint processed p src dst R e (sourcesDone e he) hd
  · simpa [hd] using
      processed_endpoints processed p src dst R e (sourcesDone e he) hd

/-- With every edge emitted by a processed node, the full observed error
retains the skipped-node baseline and distinguishes pending recipients. -/
theorem observed_error_emitted [DecidableEq Node]
    (nodes : List Node) (edges : List Edge)
    (src dst : Edge → Node) (R : Edge → Rat)
    (processed : Node → Bool) (p defect ordinary : Node → Rat)
    (unique : nodes.Nodup)
    (srcCovered : ∀ e ∈ edges, src e ∈ nodes)
    (dstCovered : ∀ e ∈ edges, dst e ∈ nodes)
    (sourcesDone : ∀ e ∈ edges, processed (src e) = true) :
    (nodes.map fun i => if processed i then
       p i * codeError edges src dst R defect i else p i * ordinary i).sum =
      (nodes.map fun i => if processed i then 0 else p i * ordinary i).sum +
      (nodes.map fun i => mask processed p i * defect i).sum +
      (edges.map fun e => if processed (dst e) then
        (p (dst e) - p (src e)) * R e else -(p (src e) * R e)).sum := by
  rw [observed_error nodes edges src dst R processed p defect ordinary
    unique srcCovered dstCovered,
    emitted_edge_cost processed p edges src dst R sourcesDone]

/-- A fixed finite rational linear coordinate/head observer acts on the
identity without any orthogonality or independence assumption. -/
def headReadout (coords : List Coord) (A : Head → Coord → Rat)
    (signal : Coord → Rat) (h : Head) : Rat :=
  (coords.map fun c => A h c * signal c).sum

theorem head_residual_pushforward [DecidableEq Node]
    (nodes : List Node) (edges : List Edge) (coords : List Coord)
    (src dst : Edge → Node) (R : Edge → Coord → Rat)
    (w : Node → Rat) (A : Head → Coord → Rat)
    (unique : nodes.Nodup)
    (srcCovered : ∀ e ∈ edges, src e ∈ nodes)
    (dstCovered : ∀ e ∈ edges, dst e ∈ nodes)
    (h : Head) :
    headReadout coords A (fun c =>
      (nodes.map fun i => w i * divergence edges src dst (fun e => R e c) i).sum) h =
    headReadout coords A (fun c =>
      (edges.map fun e => (w (dst e) - w (src e)) * R e c).sum) h := by
  apply congrArg List.sum
  apply List.map_congr_left
  intro c _
  simpa using congrArg (fun x : Rat => A h c * x)
    (weighted_divergence nodes edges src dst (fun e => R e c) w
      unique srcCovered dstCovered)

theorem head_observed_error [DecidableEq Node]
    (nodes : List Node) (edges : List Edge) (coords : List Coord)
    (src dst : Edge → Node) (R : Edge → Coord → Rat)
    (processed : Node → Bool) (p : Node → Rat)
    (defect ordinary : Node → Coord → Rat) (A : Head → Coord → Rat)
    (unique : nodes.Nodup)
    (srcCovered : ∀ e ∈ edges, src e ∈ nodes)
    (dstCovered : ∀ e ∈ edges, dst e ∈ nodes) (h : Head) :
    headReadout coords A (fun c =>
      (nodes.map fun i => if processed i then
        p i * codeError edges src dst (fun e => R e c) (fun i => defect i c) i
        else p i * ordinary i c).sum) h =
    headReadout coords A (fun c =>
      (nodes.map fun i => if processed i then 0 else p i * ordinary i c).sum +
      (nodes.map fun i => mask processed p i * defect i c).sum +
      (edges.map fun e =>
        (mask processed p (dst e) - mask processed p (src e)) * R e c).sum) h := by
  apply congrArg List.sum
  apply List.map_congr_left
  intro c _
  simpa using congrArg (fun x : Rat => A h c * x)
    (observed_error nodes edges src dst (fun e => R e c) processed p
      (fun i => defect i c) (fun i => ordinary i c)
      unique srcCovered dstCovered)

/-- Use the actual quantized/recent mask, with skipped quantized nodes' ordinary
error explicit inside that mask. In an application the defect is zero at skipped
nodes and the ordinary error is zero at active nodes. The algebra needs neither
support restriction: it records exactly the supplied decomposition. -/
theorem masked_error_with_baseline [DecidableEq Node]
    (nodes : List Node) (edges : List Edge)
    (src dst : Edge → Node) (R : Edge → Rat)
    (quantized : Node → Bool) (p defect ordinary : Node → Rat)
    (unique : nodes.Nodup)
    (srcCovered : ∀ e ∈ edges, src e ∈ nodes)
    (dstCovered : ∀ e ∈ edges, dst e ∈ nodes) :
    (nodes.map fun i => mask quantized p i *
      (divergence edges src dst R i + defect i + ordinary i)).sum =
    (nodes.map fun i => mask quantized p i * defect i).sum +
    (nodes.map fun i => mask quantized p i * ordinary i).sum +
    (edges.map fun e =>
      (mask quantized p (dst e) - mask quantized p (src e)) * R e).sum := by
  have hpoint (i : Node) : mask quantized p i *
      (divergence edges src dst R i + defect i + ordinary i) =
      mask quantized p i * defect i + mask quantized p i * ordinary i +
      mask quantized p i * divergence edges src dst R i := by grind +ring
  calc
    _ = (nodes.map fun i => mask quantized p i * defect i +
        mask quantized p i * ordinary i +
        mask quantized p i * divergence edges src dst R i).sum := by
      apply congrArg List.sum
      apply List.map_congr_left
      intro i _
      exact hpoint i
    _ = _ := by
      rw [sum_map_add, sum_map_add,
        weighted_divergence nodes edges src dst R (mask quantized p)
          unique srcCovered dstCovered]

/-- A query-visible source-weighted correction for every pending edge cancels
only the boundary debt. This changes the reader; it is not supplied by ordinary
feedback or by the visibility of the recipient's recent value. -/
theorem pending_read_correction (processed : Node → Bool) (p : Node → Rat)
    (edges : List Edge) (src dst : Edge → Node) (R : Edge → Rat)
    (sourcesDone : ∀ e ∈ edges, processed (src e) = true) :
    (edges.map fun e =>
      (mask processed p (dst e) - mask processed p (src e)) * R e).sum +
    (edges.map fun e => if processed (dst e) then 0 else p (src e) * R e).sum =
    (edges.map fun e => if processed (dst e) then
      (p (dst e) - p (src e)) * R e else 0).sum := by
  rw [emitted_edge_cost processed p edges src dst R sourcesDone, ← sum_map_add]
  apply congrArg List.sum
  apply List.map_congr_left
  intro e _
  cases processed (dst e) <;> simp only [Bool.false_eq_true, ite_false, ite_true] <;> grind +ring

end Kelana.ValueResidualTransport
