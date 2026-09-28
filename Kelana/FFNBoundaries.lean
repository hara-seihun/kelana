import Kelana.Composition
import Kelana.QuantizerCells

namespace Kelana.FFNBoundaries

/-- Gate and up share an upstream input. A whole-FFN rewrite need only agree on
pairs produced by that common source, not on every independent gate/up array. -/
theorem shared_producer_boundary {X G U O : Type}
    (gate : X → G) (up : X → U) (reference candidate : G → U → O)
    (h : ∀ g u, (∃ x, gate x = g ∧ up x = u) → candidate g u = reference g u) :
    ∀ x, candidate (gate x) (up x) = reference (gate x) (up x) := by
  intro x
  exact h _ _ ⟨x, rfl, rfl⟩

/-- The difference consumer is zero on the diagonal producer image, despite
not being zero on arbitrary independent intermediate values. -/
theorem producer_restriction_is_strict :
    (∀ x : Int, x - x = 0) ∧ ¬ (∀ g u : Int, g - u = 0) := by
  constructor
  · intro x; omega
  · intro h
    have := h 0 1
    omega

/-- Exact integer/rational reference for one nonzero 128-element quantizer group.
The integer maximum is retained. Hardware FP32 scale bits are a separate model. -/
def signature {ι : Type} (v : ι → Int) (maximum : Int) : Int × (ι → Int) :=
  (maximum, fun i => QuantizerCells.roundEven (127 * v i) maximum)

theorem signature_of_encoding {ι : Type} {v q : ι → Int} {m : Int}
    (h : QuantizerCells.Encodes v m q) : signature v m = (m,q) := by
  apply Prod.ext
  · rfl
  · exact funext h.2

/-- Any consumer of scale and codes gets identical inputs. This proof does not
commute Hadamard through quantization or discard the scale. -/
theorem quantizer_certificate_composes {ι O : Type} {v w q : ι → Int} {m : Int}
    (hv : QuantizerCells.Encodes v m q) (hw : QuantizerCells.Encodes w m q)
    (consume : (Int × (ι → Int)) → O) :
    consume (signature v m) = consume (signature w m) := by
  rw [signature_of_encoding hv, signature_of_encoding hw]

/-- The preserved signature can be consumed together with unchanged input-
residual context, without assuming that the residual operation is real addition. -/
theorem residual_context_composes {ι X Y O : Type} {v w q : ι → Int} {m : Int}
    (hv : QuantizerCells.Encodes v m q) (hw : QuantizerCells.Encodes w m q)
    (down : (Int × (ι → Int)) → Y) (finish : X → Y → O) (x : X) :
    finish x (down (signature v m)) = finish x (down (signature w m)) := by
  exact quantizer_certificate_composes hv hw (fun z => finish x (down z))

/-- Codes alone fail even for a one-element linear consumer. -/
theorem dropping_scales_changes_output :
    (1 : Int) * 1 ≠ 2 * 1 := by decide

/-- Conversely, preserving every code and scale is sufficient, not necessary.
A particular down-projection can erase changes to its input codes. -/
def twoCodeConsumer (z : Int × (Int × Int)) : Int := z.1 * (z.2.1 - z.2.2)

theorem downstream_quotient_can_be_coarser :
    (1, (0,0)) ≠ (1, (1,1)) ∧
    twoCodeConsumer (1, (0,0)) = twoCodeConsumer (1, (1,1)) := by decide

/-- For a fixed two-code consumer, simultaneous code translation is invisible.
This does not assert the change remains in a quantizer's admissible code domain. -/
theorem consumer_invisible_translation (m a b delta : Int) :
    twoCodeConsumer (m, (a+delta,b+delta)) = twoCodeConsumer (m,(a,b)) := by
  change m * ((a+delta)-(b+delta)) = m * (a-b)
  congr 1
  omega

#print axioms shared_producer_boundary
#print axioms quantizer_certificate_composes
#print axioms residual_context_composes
#print axioms consumer_invisible_translation
end Kelana.FFNBoundaries
