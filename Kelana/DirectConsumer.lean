import Kelana.Toy2Optimality
import Kelana.FiberRank

namespace Kelana.DirectConsumer

/-- The arithmetic meaning of MUL_LO_U32 followed by BFE_I32 17,15.
The last branch sign-extends the extracted field. -/
def productConsumer (p : Int) : Int :=
  let field := ((p * p) % 4294967296) / 131072
  if field < 16384 then field else field - 32768

def pack (g u : Int) : Int := g + 65536 * u

theorem square_identity (g u : Int) :
    pack g u * pack g u = g*g + 131072*(g*u) + 4294967296*(u*u) := by
  unfold pack
  grind

theorem product_correct {g u : Int}
    (hg : -127 ≤ g ∧ g ≤ 127) (hu : -127 ≤ u ∧ u ≤ 127) :
    productConsumer (pack g u) = g*u := by
  have hs := Kelana.Toy2.bounded_product g g 127 127 hg hg (by decide) (by decide)
  have hp := Kelana.Toy2.bounded_product g u 127 127 hg hu (by decide) (by decide)
  have hnn : 0 ≤ g*g := by
    by_cases h : 0 ≤ g
    · exact Int.mul_nonneg h h
    · exact Int.mul_nonneg_of_nonpos_of_nonpos (by omega) (by omega)
  unfold productConsumer
  rw [square_identity]
  dsimp only
  split <;> omega

def productWord (p : BitVec 32) : Int :=
  (((p*p) >>> 17).setWidth 15).toInt

theorem product_word_reference (p : Int) :
    productWord (BitVec.ofInt 32 p) = productConsumer p := by
  unfold productWord
  rw [← BitVec.ofInt_mul]
  simp only [BitVec.toInt_eq_toNat_cond, BitVec.toNat_setWidth,
    BitVec.toNat_ushiftRight, BitVec.toNat_ofInt, Nat.shiftRight_eq_div_pow]
  change (if 2*((p*p%4294967296).toNat / 131072 % 32768) < 32768 then
    (((p*p%4294967296).toNat / 131072 % 32768 : Nat) : Int) else
    (((p*p%4294967296).toNat / 131072 % 32768 : Nat) : Int) - 32768) = _
  unfold productConsumer
  dsimp only
  split <;> split <;> omega

theorem product_word_correct {g u : Int}
    (hg : -127 ≤ g ∧ g ≤ 127) (hu : -127 ≤ u ∧ u ≤ 127) :
    productWord (BitVec.ofInt 32 (pack g u)) = g*u := by
  rw [product_word_reference]
  exact product_correct hg hu

/-- The integer read by MUL_I32_I24 from its low 24 source bits. -/
def signed24 (p : Int) : Int := (p + 8388608) % 16777216 - 8388608

theorem pack_fits_i24 {g u : Int}
    (hg : -127 ≤ g ∧ g ≤ 127) (hu : -127 ≤ u ∧ u ≤ 127) :
    -8388608 ≤ pack g u ∧ pack g u < 8388608 := by
  unfold pack
  omega

theorem signed24_identity {p : Int} (h : -8388608 ≤ p ∧ p < 8388608) :
    signed24 p = p := by
  unfold signed24
  omega

/-- The fast native multiply has the same low product on this input domain. -/
theorem product_i24_correct {g u : Int}
    (hg : -127 ≤ g ∧ g ≤ 127) (hu : -127 ≤ u ∧ u ≤ 127) :
    productWord (BitVec.ofInt 32 (signed24 (pack g u))) = g*u := by
  rw [signed24_identity (pack_fits_i24 hg hu)]
  exact product_word_correct hg hu

/-- Only the gate sign is observed; neither gate nor up is reconstructed. -/
def positiveGate (p : Int) : Bool := p % 65536 < 32768

def reluConsumer (p : Int) : Int :=
  if positiveGate p then productConsumer p else 0

theorem gate_sign {g u : Int} (hg : -127 ≤ g ∧ g ≤ 127) :
    positiveGate (pack g u) = decide (0 ≤ g) := by
  unfold positiveGate pack
  have hiff : (g + 65536*u) % 65536 < 32768 ↔ 0 ≤ g := by omega
  simp only [hiff]

theorem relu_correct {g u : Int}
    (hg : -127 ≤ g ∧ g ≤ 127) (hu : -127 ≤ u ∧ u ≤ 127) :
    reluConsumer (pack g u) = max g 0 * u := by
  unfold reluConsumer
  rw [gate_sign hg, product_correct hg hu]
  by_cases h : 0 ≤ g
  · simp [h, Int.max_eq_left h]
  · have hn : g ≤ 0 := by omega
    simp [h, Int.max_eq_right hn]

/-- Center the low square sum so signed downstream weights cannot borrow
from the product field. This extra constant is per output, not per hidden unit. -/
def centeredConsumer (p : Int) : Int :=
  let field := ((p + 65536) % 4294967296) / 131072
  if field < 16384 then field else field - 32768

theorem centered_correct (low product high : Int)
    (hl : -65536 ≤ low ∧ low < 65536)
    (hp : -16384 ≤ product ∧ product < 16384) :
    centeredConsumer (low + 131072*product + 4294967296*high) = product := by
  unfold centeredConsumer
  dsimp only
  split <;> omega

abbrev Term := Int × Int × Int

def squareSum (ts : List Term) : Int :=
  ts.foldr (fun t acc => t.1 * (pack t.2.1 t.2.2 * pack t.2.1 t.2.2) + acc) 0

def lowSum (ts : List Term) : Int :=
  ts.foldr (fun t acc => t.1 * (t.2.1*t.2.1) + acc) 0

def productSum (ts : List Term) : Int :=
  ts.foldr (fun t acc => t.1 * (t.2.1*t.2.2) + acc) 0

def highSum (ts : List Term) : Int :=
  ts.foldr (fun t acc => t.1 * (t.2.2*t.2.2) + acc) 0

theorem square_sum_identity (ts : List Term) :
    squareSum ts = lowSum ts + 131072*productSum ts + 4294967296*highSum ts := by
  induction ts with
  | nil => simp [squareSum, lowSum, productSum, highSum]
  | cons t ts ih =>
    simp only [squareSum, lowSum, productSum, highSum, List.foldr_cons] at *
    rw [square_identity]
    grind (ematch := 0)

/-- One final extraction after an entire signed linear consumer.
No gate, up, or individual hidden product is reconstructed. -/
theorem downstream_correct (ts : List Term)
    (hl : -65536 ≤ lowSum ts ∧ lowSum ts < 65536)
    (hp : -16384 ≤ productSum ts ∧ productSum ts < 16384) :
    centeredConsumer (squareSum ts) = productSum ts := by
  rw [square_sum_identity]
  exact centered_correct _ _ _ hl hp

def SmallTerm (t : Term) : Prop :=
  (-1 ≤ t.1 ∧ t.1 ≤ 1) ∧ (-7 ≤ t.2.1 ∧ t.2.1 ≤ 7) ∧
  (-7 ≤ t.2.2 ∧ t.2.2 ≤ 7)

theorem small_terms_bound (ts : List Term) (h : ∀ t ∈ ts, SmallTerm t) :
    (-(ts.length:Int)*49 ≤ lowSum ts ∧ lowSum ts ≤ (ts.length:Int)*49) ∧
    (-(ts.length:Int)*49 ≤ productSum ts ∧ productSum ts ≤ (ts.length:Int)*49) := by
  induction ts with
  | nil => simp [lowSum, productSum]
  | cons t ts ih =>
    have ht := h t (by simp)
    have hi := ih (by intro t ht; exact h t (by simp [ht]))
    obtain ⟨hc, hg, hu⟩ := ht
    have hgg := Kelana.Toy2.bounded_product _ _ 7 7 hg hg (by decide) (by decide)
    have hgu := Kelana.Toy2.bounded_product _ _ 7 7 hg hu (by decide) (by decide)
    have hcg := Kelana.Toy2.bounded_product _ _ 1 49 hc hgg (by decide) (by decide)
    have hcp := Kelana.Toy2.bounded_product _ _ 1 49 hc hgu (by decide) (by decide)
    simp only [lowSum, productSum, List.foldr_cons, List.length_cons] at *
    omega

theorem downstream_128 (ts : List Term)
    (hn : ts.length ≤ 128) (h : ∀ t ∈ ts, SmallTerm t) :
    centeredConsumer (squareSum ts) = productSum ts := by
  have hb := small_terms_bound ts h
  apply downstream_correct <;> omega

/-- 334 maximal signed terms fit the original 32-bit downstream word. -/
theorem downstream_334 (ts : List Term)
    (hn : ts.length ≤ 334) (h : ∀ t ∈ ts, SmallTerm t) :
    centeredConsumer (squareSum ts) = productSum ts := by
  have hb := small_terms_bound ts h
  apply downstream_correct <;> omega

/-- A 64-bit square retains the entire 17,408-coordinate bilinear down
projection. The high square starts at bit 64 and disappears modulo 2^64. -/
def pack64 (g u : Int) : Int := g + 4294967296 * u

def squareSum64 (ts : List Term) : Int :=
  ts.foldr (fun t acc => t.1 * (pack64 t.2.1 t.2.2 * pack64 t.2.1 t.2.2) + acc) 0

def centeredConsumer64 (p : Int) : Int :=
  let field := ((p + 4294967296) % 18446744073709551616) / 8589934592
  if field < 1073741824 then field else field - 2147483648

theorem square64_identity (g u : Int) :
    pack64 g u * pack64 g u = g*g + 8589934592*(g*u) +
      18446744073709551616*(u*u) := by
  unfold pack64
  grind

theorem square_sum64_identity (ts : List Term) :
    squareSum64 ts = lowSum ts + 8589934592 * productSum ts +
      18446744073709551616 * highSum ts := by
  induction ts with
  | nil => simp [squareSum64, lowSum, productSum, highSum]
  | cons t ts ih =>
    simp only [squareSum64, lowSum, productSum, highSum, List.foldr_cons] at *
    rw [square64_identity]
    grind (ematch := 0)

theorem centered64_correct (low product high : Int)
    (hl : -4294967296 ≤ low ∧ low < 4294967296)
    (hp : -1073741824 ≤ product ∧ product < 1073741824) :
    centeredConsumer64 (low + 8589934592 * product +
      18446744073709551616 * high) = product := by
  unfold centeredConsumer64
  dsimp only
  split <;> omega

theorem downstream64_17408 (ts : List Term)
    (hn : ts.length ≤ 17408) (h : ∀ t ∈ ts, SmallTerm t) :
    centeredConsumer64 (squareSum64 ts) = productSum ts := by
  rw [square_sum64_identity]
  have hb := small_terms_bound ts h
  apply centered64_correct <;> omega

/-- One extraction also suffices at the full signed A8 input magnitude. -/
def A8Term (t : Term) : Prop :=
  (-1 ≤ t.1 ∧ t.1 ≤ 1) ∧ (-127 ≤ t.2.1 ∧ t.2.1 ≤ 127) ∧
    (-127 ≤ t.2.2 ∧ t.2.2 ≤ 127)

theorem a8_terms_bound (ts : List Term) (h : ∀ t ∈ ts, A8Term t) :
    (-(ts.length:Int)*16129 ≤ lowSum ts ∧ lowSum ts ≤ (ts.length:Int)*16129) ∧
    (-(ts.length:Int)*16129 ≤ productSum ts ∧
      productSum ts ≤ (ts.length:Int)*16129) := by
  induction ts with
  | nil => simp [lowSum, productSum]
  | cons t ts ih =>
    have ht := h t (by simp)
    have hi := ih (by intro t ht; exact h t (by simp [ht]))
    obtain ⟨hc, hg, hu⟩ := ht
    have hgg := Kelana.Toy2.bounded_product _ _ 127 127 hg hg (by decide) (by decide)
    have hgu := Kelana.Toy2.bounded_product _ _ 127 127 hg hu (by decide) (by decide)
    have hcg := Kelana.Toy2.bounded_product _ _ 1 16129 hc hgg (by decide) (by decide)
    have hcp := Kelana.Toy2.bounded_product _ _ 1 16129 hc hgu (by decide) (by decide)
    simp only [lowSum, productSum, List.foldr_cons, List.length_cons] at *
    omega

theorem downstream64_a8_17408 (ts : List Term)
    (hn : ts.length ≤ 17408) (h : ∀ t ∈ ts, A8Term t) :
    centeredConsumer64 (squareSum64 ts) = productSum ts := by
  rw [square_sum64_identity]
  have hb := a8_terms_bound ts h
  apply centered64_correct <;> omega

/-- The 64-bit observation also accepts a wrapped instruction stream. -/
theorem centered64_wrap_invisible (s : Int) :
    centeredConsumer64 (s % 18446744073709551616) = centeredConsumer64 s := by
  have h : (s % 18446744073709551616 + 4294967296) % 18446744073709551616 =
      (s + 4294967296) % 18446744073709551616 := by omega
  unfold centeredConsumer64
  rw [h]

/-- 335 positive maximal terms exceed the signed 15-bit 32-bit field. -/
theorem downstream_335_counterexample :
    centeredConsumer (16415 * (pack 7 7 * pack 7 7)) ≠ 16415 := by
  decide

/-- Modular accumulation does not require the high square sum to fit a register. -/
theorem wrap_invisible (s : Int) :
    centeredConsumer (s % 4294967296) = centeredConsumer s := by
  have h : (s % 4294967296 + 65536) % 4294967296 =
      (s + 65536) % 4294967296 := by omega
  unfold centeredConsumer
  rw [h]

/-- Observing the gate's nonlinear factor is enough; the up value is unnecessary. -/
theorem gated_product (sigma : Int → Int) {g u : Int}
    (hg : -127 ≤ g ∧ g ≤ 127) (hu : -127 ≤ u ∧ u ≤ 127) :
    productConsumer (pack g u) * sigma g = (g * sigma g) * u := by
  rw [product_correct hg hu]
  grind

/-- The product alone cannot determine a gate-dependent consumer.
For logistic sigma over reals the analogous hypothesis holds at ±1. -/
theorem product_only_insufficient (sigma : Int → Int) (h : sigma 1 ≠ sigma (-1)) :
    ¬ ∃ f : Int → Int, ∀ g u : Int, f (g*u) = (g*sigma g)*u := by
  rintro ⟨f, hf⟩
  have hpos := hf 1 1
  have hneg := hf (-1) (-1)
  simp only [Int.one_mul, Int.mul_one, Int.neg_mul, Int.mul_neg,
    Int.neg_neg] at hpos hneg
  exact h (hpos.symm.trans hneg)

/-- Coefficients are in increasing degree order. -/
def evalPoly : List Int → Int → Int
  | [], _ => 0
  | a :: cs, x => a + x * evalPoly cs x

def evalWord : List Int → Int → Int
  | [], _ => 0
  | a :: cs, x => (a + x * evalWord cs x) % 4294967296

theorem word_polynomial (cs : List Int) (p : Int) :
    evalWord cs p = evalPoly cs p % 4294967296 := by
  induction cs with
  | nil => simp [evalWord, evalPoly]
  | cons a cs ih =>
    simp only [evalWord, evalPoly, ih, Int.add_emod, Int.mul_emod, Int.emod_emod]

def evalDerivative : List Int → Int → Int
  | [], _ => 0
  | _ :: cs, x => evalPoly cs x + x * evalDerivative cs x

/-- Base-R arithmetic emulates a dual number modulo R², apart from carries
out of P(g). The subsequent range hypotheses control exactly those carries. -/
theorem polynomial_taylor (cs : List Int) (g u r : Int) :
    ∃ high : Int, evalPoly cs (g+r*u) =
      evalPoly cs g + r * (u * evalDerivative cs g) + r*r * high := by
  induction cs with
  | nil => exact ⟨0, by simp [evalPoly, evalDerivative]⟩
  | cons a cs ih =>
    obtain ⟨h, hh⟩ := ih
    refine ⟨g*h + u*u*evalDerivative cs g + r*u*h, ?_⟩
    simp only [evalPoly, evalDerivative]
    rw [hh]
    grind (ematch := 0)

theorem packed_polynomial (cs : List Int) (g u : Int) :
    ∃ high : Int, evalPoly cs (pack g u) =
      evalPoly cs g + 65536 * (u * evalDerivative cs g) + 4294967296 * high :=
  polynomial_taylor cs g u 65536

def derivativeConsumer (value : Int) : Int :=
  let field := ((value + 32768) % 4294967296) / 65536
  if field < 32768 then field else field - 65536

theorem derivative_correct (cs : List Int) (g u : Int)
    (hl : -32768 ≤ evalPoly cs g ∧ evalPoly cs g < 32768)
    (hd : -32768 ≤ u * evalDerivative cs g ∧ u * evalDerivative cs g < 32768) :
    derivativeConsumer (evalPoly cs (pack g u)) = u * evalDerivative cs g := by
  obtain ⟨high, hh⟩ := packed_polynomial cs g u
  unfold derivativeConsumer
  rw [hh]
  dsimp only
  split <;> omega

theorem derivative_wrap_invisible (s : Int) :
    derivativeConsumer (s % 4294967296) = derivativeConsumer s := by
  have h : (s % 4294967296 + 32768) % 4294967296 =
      (s + 32768) % 4294967296 := by omega
  unfold derivativeConsumer
  rw [h]

theorem word_derivative_correct (cs : List Int) (g u : Int)
    (hl : -32768 ≤ evalPoly cs g ∧ evalPoly cs g < 32768)
    (hd : -32768 ≤ u * evalDerivative cs g ∧ u * evalDerivative cs g < 32768) :
    derivativeConsumer (evalWord cs (pack g u)) = u * evalDerivative cs g := by
  rw [word_polynomial, derivative_wrap_invisible]
  exact derivative_correct cs g u hl hd

/-- Signed-24 multiplication preserves the residue even when either full
integer operand is outside the signed-24 range. -/
theorem mul24_quotient (x y : Int) :
    (signed24 x * signed24 y) % 16777216 = (x*y) % 16777216 := by
  have hx : signed24 x % 16777216 = x % 16777216 := by unfold signed24; omega
  have hy : signed24 y % 16777216 = y % 16777216 := by unfold signed24; omega
  simp only [Int.mul_emod, hx, hy, Int.emod_emod]

def eval24 : List Int → Int → Int
  | [], _ => 0
  | a :: cs, x => (a + signed24 x * signed24 (eval24 cs x)) % 16777216

theorem polynomial24 (cs : List Int) (p : Int) :
    eval24 cs p = evalPoly cs p % 16777216 := by
  induction cs with
  | nil => simp [eval24, evalPoly]
  | cons a cs ih =>
    simp only [eval24, evalPoly]
    rw [Int.add_emod, mul24_quotient]
    simp only [Int.mul_emod, ih, Int.emod_emod, Int.add_emod]

def evalNative24 : List Int → Int → Int
  | [], _ => 0
  | a :: cs, x => (a + signed24 x * signed24 (evalNative24 cs x)) % 4294967296

/-- Native 32-bit destinations need no explicit 24-bit mask between stages. -/
theorem native_polynomial24 (cs : List Int) (p : Int) :
    evalNative24 cs p % 16777216 = evalPoly cs p % 16777216 := by
  have wrap (s : Int) : s % 4294967296 % 16777216 = s % 16777216 := by omega
  induction cs with
  | nil => simp [evalNative24, evalPoly]
  | cons a cs ih =>
    simp only [evalNative24, evalPoly]
    rw [wrap, Int.add_emod, mul24_quotient]
    simp only [Int.mul_emod, ih, Int.emod_emod, Int.add_emod]

def derivativeConsumer24 (value : Int) : Int :=
  let field := ((value + 2048) % 16777216) / 4096
  if field < 2048 then field else field - 4096

/-- A full-rate multiply path with 12-bit low and derivative fields.
No range hypothesis is imposed on the polynomial's intermediate values. -/
theorem derivative24_correct (cs : List Int) (g u : Int)
    (hl : -2048 ≤ evalPoly cs g ∧ evalPoly cs g < 2048)
    (hd : -2048 ≤ u * evalDerivative cs g ∧ u * evalDerivative cs g < 2048) :
    derivativeConsumer24 (eval24 cs (g+4096*u)) = u * evalDerivative cs g := by
  rw [polynomial24]
  obtain ⟨high, hh⟩ := polynomial_taylor cs g u 4096
  rw [hh]
  unfold derivativeConsumer24
  dsimp only
  split <;> omega

theorem native_derivative24_correct (cs : List Int) (g u : Int)
    (hl : -2048 ≤ evalPoly cs g ∧ evalPoly cs g < 2048)
    (hd : -2048 ≤ u * evalDerivative cs g ∧ u * evalDerivative cs g < 2048) :
    derivativeConsumer24 (evalNative24 cs (g+4096*u)) = u * evalDerivative cs g := by
  have hh := native_polynomial24 cs (g+4096*u)
  have he := polynomial24 cs (g+4096*u)
  have ho := derivative24_correct cs g u hl hd
  unfold derivativeConsumer24 at *
  have hx : (evalNative24 cs (g+4096*u)+2048) % 16777216 =
      (eval24 cs (g+4096*u)+2048) % 16777216 := by omega
  rw [hx]
  exact ho

/-- P'(g)/3840 is the quartic SiLU Taylor approximation at gate g/2.
Multiplying by u yields the gated value without recovering either operand.
The approximation to real SiLU is NOT an equality claim of this theorem. -/
def siluPolynomial : List Int := [0, 0, 480, 80, 0, -1]

theorem silu_polynomial_derivative (g : Int) :
    evalDerivative siluPolynomial g = 960*g + 240*g*g - 5*g*g*g*g := by
  simp only [siluPolynomial, evalDerivative, evalPoly]
  grind

theorem silu_polynomial_small (g u : Int)
    (hg : -3 ≤ g ∧ g ≤ 3) (hu : -7 ≤ u ∧ u ≤ 7) :
    derivativeConsumer (evalPoly siluPolynomial (pack g u)) =
      u * (960*g + 240*g*g - 5*g*g*g*g) := by
  rw [← silu_polynomial_derivative]
  apply derivative_correct
  all_goals
    have cases : g = -3 ∨ g = -2 ∨ g = -1 ∨ g = 0 ∨ g = 1 ∨ g = 2 ∨ g = 3 := by omega
    rcases cases with h | h | h | h | h | h | h <;> subst g <;>
      simp [siluPolynomial, evalPoly, evalDerivative] <;> omega

namespace ChunkTable

attribute [local simp] Kelana.FiberRank.Trit.value

/-- Shared ternary alphabet used by the exact ranker and response tables. -/
abbrev Trit := Kelana.FiberRank.Trit

namespace Trit

abbrev value (t : Trit) : Int := Kelana.FiberRank.Trit.value t

def digit : Trit → Nat
  | .neg => 0
  | .zero => 1
  | .pos => 2

end Trit

/-- Dense, most-significant-trit-first base-3 code. -/
def code : List Trit → Nat
  | [] => 0
  | trit :: weights => trit.digit * 3 ^ weights.length + code weights

/-- Exact integer dot response. Unequal suffixes are ignored; the public
correctness theorem requires equal lengths. -/
def response : List Trit → List Int → Int
  | trit :: weights, coefficient :: query =>
      trit.value * coefficient + response weights query
  | _, _ => 0

/-- Query-dependent response table in dense-code order. Each step makes the
`-q`, `0`, and `+q` shifted copies of the suffix table. -/
def table : List Int → List Int
  | [] => [0]
  | coefficient :: query =>
      let suffix := table query
      suffix.map (· - coefficient) ++ suffix ++ suffix.map (· + coefficient)

@[simp] theorem table_nil : table [] = [0] := rfl

theorem table_cons (coefficient : Int) (query : List Int) :
    table (coefficient :: query) =
      (table query).map (· - coefficient) ++ table query ++
        (table query).map (· + coefficient) := rfl

@[simp] theorem table_length (query : List Int) :
    (table query).length = 3 ^ query.length := by
  induction query with
  | nil => simp [table]
  | cons coefficient query ih =>
      simp [table, ih, Nat.pow_succ]
      omega

@[simp] theorem code_lt_pow (weights : List Trit) :
    code weights < 3 ^ weights.length := by
  induction weights with
  | nil => simp [code]
  | cons trit weights ih =>
      cases trit <;> simp [code, Trit.digit, Nat.pow_succ] at * <;> omega

private theorem get_left (xs : List Int) (f g : Int → Int) (i : Nat)
    (indexBound : i < xs.length) :
    (xs.map f ++ xs ++ xs.map g)[i]? = Option.map f xs[i]? := by
  simp [List.getElem?_append, indexBound]

private theorem get_middle (xs : List Int) (f g : Int → Int) (i : Nat)
    (indexBound : i < xs.length) :
    (xs.map f ++ xs ++ xs.map g)[xs.length + i]? = xs[i]? := by
  simp [List.getElem?_append, indexBound]

private theorem get_right (xs : List Int) (f g : Int → Int) (i : Nat) :
    (xs.map f ++ xs ++ xs.map g)[2 * xs.length + i]? = Option.map g xs[i]? := by
  rw [List.getElem?_append]
  simp only [List.length_append, List.length_map]
  rw [if_neg (by omega : ¬2 * xs.length + i < xs.length + xs.length)]
  have subtractBlocks : 2 * xs.length + i - (xs.length + xs.length) = i := by omega
  rw [subtractBlocks, List.getElem?_map]

/-- Looking up the dense code returns the exact dot response for every
integer query. There is no distinguished probe and no equality guard. -/
theorem table_lookup (weights : List Trit) (query : List Int)
    (sameLength : weights.length = query.length) :
    (table query)[code weights]? = some (response weights query) := by
  induction weights generalizing query with
  | nil =>
      have queryNil : query = [] := List.eq_nil_of_length_eq_zero sameLength.symm
      subst query
      simp [table, code, response]
  | cons trit weights ih =>
      cases query with
      | nil => simp at sameLength
      | cons coefficient query =>
          have tailLength : weights.length = query.length := by simpa using sameLength
          have tailLookup := ih query tailLength
          have tailBound := code_lt_pow weights
          have tableSize : (table query).length = 3 ^ weights.length := by
            rw [table_length, ← tailLength]
          have tableBound : code weights < (table query).length := by
            rw [tableSize]
            exact tailBound
          cases trit with
          | neg =>
              rw [table_cons]
              simp only [code, Trit.digit, Nat.zero_mul, Nat.zero_add]
              rw [get_left (indexBound := tableBound), tailLookup]
              simp [response, Trit.value]
              omega
          | zero =>
              rw [table_cons]
              simp only [code, Trit.digit, Nat.one_mul]
              rw [← tableSize, get_middle (indexBound := tableBound), tailLookup]
              simp [response, Trit.value]
          | pos =>
              rw [table_cons]
              simp only [code, Trit.digit]
              rw [← tableSize, get_right, tailLookup]
              simp [response, Trit.value]
              omega

def tritOfDigit : Nat → Trit
  | 0 => .neg
  | 1 => .zero
  | _ => .pos

@[simp] theorem digit_tritOfDigit {digit : Nat} (h : digit < 3) :
    (tritOfDigit digit).digit = digit := by
  have cases : digit = 0 ∨ digit = 1 ∨ digit = 2 := by omega
  rcases cases with rfl | rfl | rfl <;> rfl

/-- Decode a bounded dense index into exactly `width` ternary digits. -/
def decode : (width : Nat) → Nat → List Trit
  | 0, _ => []
  | width + 1, index =>
      let block := 3 ^ width
      tritOfDigit (index / block) :: decode width (index % block)

@[simp] theorem decode_length (width index : Nat) :
    (decode width index).length = width := by
  induction width generalizing index with
  | zero => rfl
  | succ width ih => simp [decode, ih]

/-- Every index in `[0, 3^width)` is a code. Thus the code has no holes, not
merely an upper bound. -/
theorem code_decode {width index : Nat} (indexBound : index < 3 ^ width) :
    code (decode width index) = index := by
  induction width generalizing index with
  | zero =>
      have : index = 0 := by simpa using indexBound
      subst index
      rfl
  | succ width ih =>
      have blockPositive : 0 < 3 ^ width := Nat.pow_pos (by decide)
      have quotientBound : index / 3 ^ width < 3 := by
        rw [Nat.div_lt_iff_lt_mul blockPositive]
        simpa [Nat.pow_succ, Nat.mul_comm] using indexBound
      have remainderBound : index % 3 ^ width < 3 ^ width :=
        Nat.mod_lt _ blockPositive
      simp only [decode, code, decode_length, digit_tritOfDigit quotientBound,
        ih remainderBound]
      calc
        index / 3 ^ width * 3 ^ width + index % 3 ^ width =
            index % 3 ^ width + 3 ^ width * (index / 3 ^ width) := by ac_rfl
        _ = index := Nat.mod_add_div index (3 ^ width)

/-- Concatenating chunks concatenates their base-3 codes. -/
theorem code_append (left right : List Trit) :
    code (left ++ right) = code left * 3 ^ right.length + code right := by
  induction left with
  | nil => simp [code]
  | cons trit left ih =>
      simp only [List.cons_append, code, List.length_append, ih]
      rw [Nat.pow_add]
      cases trit <;> simp [Trit.digit]
      all_goals rw [Nat.add_mul]
      all_goals ac_rfl

/-- A response over adjacent chunks is the sum of the chunk responses. -/
theorem response_append (left right : List Trit) (leftQuery rightQuery : List Int)
    (sameLeftLength : left.length = leftQuery.length) :
    response (left ++ right) (leftQuery ++ rightQuery) =
      response left leftQuery + response right rightQuery := by
  induction left generalizing leftQuery with
  | nil =>
      have leftQueryNil : leftQuery = [] :=
        List.eq_nil_of_length_eq_zero sameLeftLength.symm
      subst leftQuery
      simp [response]
  | cons trit left ih =>
      cases leftQuery with
      | nil => simp at sameLeftLength
      | cons coefficient leftQuery =>
          have tailLength : left.length = leftQuery.length := by
            simpa using sameLeftLength
          simp only [List.cons_append, response]
          rw [ih leftQuery tailLength]
          omega

/-- Exact block composition, with the combined dense index written directly
from the two chunk codes. -/
theorem table_lookup_append (left right : List Trit)
    (leftQuery rightQuery : List Int)
    (sameLeftLength : left.length = leftQuery.length)
    (sameRightLength : right.length = rightQuery.length) :
    (table (leftQuery ++ rightQuery))[
        code left * 3 ^ right.length + code right]? =
      some (response left leftQuery + response right rightQuery) := by
  rw [← code_append, ← response_append left right leftQuery rightQuery sameLeftLength]
  apply table_lookup
  simp [sameLeftLength, sameRightLength]

def shiftOps : Nat → Nat
  | 0 => 0
  | k+1 => shiftOps k + 2*3^k

theorem shiftOps_capacity (k : Nat) : shiftOps k + 1 = 3^k := by
  induction k with
  | zero => rfl
  | succ k ih =>
      simp only [shiftOps, Nat.pow_succ]
      omega

/-- Cross-multiplied neighboring-width comparison for the declared arithmetic
proxy. `p` is instantiated by `3^k`; this is not a hardware-cycle model. -/
theorem neighbor_cost (k rows p : Int) :
    k * (rows + 3*p - 1) ≤ (k+1) * (rows+p-1) ↔
      (2*k-1)*p ≤ rows-1 := by
  grind

/-- The crossover thresholds grow strictly with width. -/
theorem threshold_growth (k p : Int) (hk : 1 ≤ k) (hp : 0 < p) :
    (2*k-1)*p < (2*(k+1)-1)*(3*p) := by
  have positive : 0 < (4*k+4)*p := Int.mul_pos (by omega) hp
  grind

end ChunkTable

end Kelana.DirectConsumer
