import Std

namespace Kelana.AntipodalGatedAlgebra

structure Channel (X : Type) where
  gate : X → Rat
  up : X → Rat
  down : Rat

def contribution (phi : Rat → Rat) (c : Channel X) (x : X) : Rat :=
  c.down * phi (c.gate x) * c.up x

def response (phi : Rat → Rat) (channels : List (Channel X)) (x : X) : Rat :=
  (channels.map (fun c => contribution phi c x)).sum

def quadratic (channels : List (Channel X)) (x : X) : Rat :=
  (channels.map (fun c => c.down * c.gate x * c.up x)).sum

/-- The only activation fact needed by the complete-map reflection theorem.
Actual real SiLU has this identity via sigmoid(z)+sigmoid(-z)=1. -/
def OddDifference (phi : Rat → Rat) : Prop :=
  ∀ z, phi z - phi (-z) = z

/-- A channel's antipodal sum contracts to a bilinear response. This does
not assume the channel has any antipodal partner. -/
theorem contribution_reflection (phi : Rat → Rat) (hphi : OddDifference phi)
    (c : Channel X) (reflect : X → X) (x : X)
    (hg : c.gate (reflect x) = -c.gate x)
    (hu : c.up (reflect x) = -c.up x) :
    contribution phi c x + contribution phi c (reflect x) =
      c.down * c.gate x * c.up x := by
  simp only [contribution, hg, hu]
  have difference := hphi (c.gate x)
  simp only [Rat.sub_eq_add_neg] at difference
  calc
    c.down * phi (c.gate x) * c.up x +
        c.down * phi (-c.gate x) * -(c.up x) =
      c.down * (phi (c.gate x) + -phi (-c.gate x)) * c.up x := by
        simp only [Rat.mul_add, Rat.add_mul, Rat.mul_neg, Rat.neg_mul, Rat.mul_assoc]
    _ = c.down * c.gate x * c.up x := by rw [difference]

/-- For any number of gate/up channels and every input, reflection exposes
an exact quadratic map of the *whole output*. Source channel pairing is
unnecessary; the contracted coefficient tensor may be realized differently. -/
theorem response_reflection (phi : Rat → Rat) (hphi : OddDifference phi)
    (channels : List (Channel X)) (reflect : X → X) (x : X)
    (hg : ∀ c ∈ channels, c.gate (reflect x) = -c.gate x)
    (hu : ∀ c ∈ channels, c.up (reflect x) = -c.up x) :
    response phi channels x + response phi channels (reflect x) =
      quadratic channels x := by
  induction channels with
  | nil => simp [response, quadratic, Rat.zero_add]
  | cons c rest ih =>
      have gc := hg c (by simp)
      have uc := hu c (by simp)
      have gr : ∀ d ∈ rest, d.gate (reflect x) = -d.gate x := by
        intro d hd
        exact hg d (by simp [hd])
      have ur : ∀ d ∈ rest, d.up (reflect x) = -d.up x := by
        intro d hd
        exact hu d (by simp [hd])
      specialize ih gr ur
      change contribution phi c x + response phi rest x +
          (contribution phi c (reflect x) + response phi rest (reflect x)) =
        c.down * c.gate x * c.up x + quadratic rest x
      rw [← ih, ← contribution_reflection phi hphi c reflect x gc uc]
      ac_rfl

/-- The finite symmetric-pair error identity; the first right-hand square is
nonnegative, so the odd difference sets a representation-independent floor
for any single even output label at the pair. Written over integers to avoid
an analytic square-root or a fixed numeric activation implementation. -/
theorem symmetric_pair_error (a b candidate : Int) :
    2 * ((a-candidate)*(a-candidate) + (b-candidate)*(b-candidate)) =
      (a+b-2*candidate)*(a+b-2*candidate) + (a-b)*(a-b) := by
  simp only [Int.sub_mul, Int.mul_sub, Int.add_mul, Int.mul_add,
    Int.mul_assoc]
  simp only [Int.mul_left_comm a 2 candidate,
    Int.mul_left_comm b 2 candidate,
    Int.mul_left_comm candidate 2 candidate]
  omega

end Kelana.AntipodalGatedAlgebra
