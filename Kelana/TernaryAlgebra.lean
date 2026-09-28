import Std

namespace Kelana.TernaryAlgebra
open Lean.Grind

/-- Coefficients have exponent 0, 1 or 2 in each variable. The first branch is
constant in the current variable; the other two multiply it and its square. -/
@[reducible] def Normal (R : Type) : Nat → Type
  | 0 => R
  | n+1 => Normal R n × Normal R n × Normal R n

variable {R : Type} [CommRing R]

def evaluate : {n : Nat} → Normal R n → (Fin n → R) → R
  | 0, p, _ => p
  | _+1, (a,b,c), x =>
    evaluate a (fun i => x i.succ) +
    evaluate b (fun i => x i.succ)*x 0 +
    evaluate c (fun i => x i.succ)*x 0*x 0

def add : {n : Nat} → Normal R n → Normal R n → Normal R n
  | 0, p, q => @HAdd.hAdd R R R inferInstance p q
  | _+1, (a,b,c), (d,e,f) => (add a d, add b e, add c f)

def multiply : {n : Nat} → Normal R n → Normal R n → Normal R n
  | 0, p, q => @HMul.hMul R R R inferInstance p q
  | _+1, (a,b,c), (d,e,f) =>
    (multiply a d,
     add (add (multiply a e) (multiply b d)) (add (multiply b f) (multiply c e)),
     add (add (multiply a f) (multiply b e)) (add (multiply c d) (multiply c f)))

def constant (n : Nat) (r : R) : Normal R n :=
  match n with
  | 0 => r
  | n+1 => (constant n r, constant n 0, constant n 0)

def coordinate : {n : Nat} → Fin n → Normal R n
  | 0, i => Fin.elim0 i
  | n+1, i => if h : i.val=0 then
      (constant n 0, constant n 1, constant n 0)
    else (coordinate ⟨i.val-1, by omega⟩, constant n 0, constant n 0)

/-- This algebra also works on other rings' roots of x^3=x. Claiming it describes
all functions, or has unique coefficients, needs extra assumptions. -/
def CubicGrid {n : Nat} (x : Fin n → R) : Prop :=
  ∀ i, x i*x i*x i = x i

theorem evaluate_add {n : Nat} (p q : Normal R n) (x : Fin n → R) :
    evaluate (add p q) x = evaluate p x + evaluate q x := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rcases p with ⟨a,b,c⟩; rcases q with ⟨d,e,f⟩
    simp only [add, evaluate, ih]
    grind

theorem evaluate_constant (n : Nat) (r : R) (x : Fin n → R) :
    evaluate (constant n r) x = r := by
  induction n generalizing r with
  | zero => rfl
  | succ n ih => simp only [constant, evaluate, ih]; grind

theorem evaluate_multiply {n : Nat} (p q : Normal R n) (x : Fin n → R)
    (hx : CubicGrid x) :
    evaluate (multiply p q) x = evaluate p x * evaluate q x := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rcases p with ⟨a,b,c⟩; rcases q with ⟨d,e,f⟩
    have ht : CubicGrid (fun i : Fin n => x i.succ) := fun i => hx i.succ
    have hz := hx 0
    simp only [multiply, evaluate, evaluate_add, ih _ _ _ ht]
    grind

theorem evaluate_variable {n : Nat} (i : Fin n) (x : Fin n → R) :
    evaluate (coordinate i) x = x i := by
  induction n with
  | zero => exact Fin.elim0 i
  | succ n ih =>
    by_cases h : i.val=0
    · have hi : i=0 := by apply Fin.ext; exact h
      subst i
      simp only [coordinate, Fin.val_zero, evaluate]
      have h0 := evaluate_constant n (0:R) (fun i => x i.succ)
      have h1 := evaluate_constant n (1:R) (fun i => x i.succ)
      grind
    · rw [coordinate, dif_neg h]
      simp only [evaluate, evaluate_constant, ih]
      have hi : (⟨i.val-1, by omega⟩ : Fin n).succ = i := by
        apply Fin.ext; simp; omega
      rw [hi]
      grind

inductive Expr (R : Type) (n : Nat) where
  | lit : R → Expr R n
  | var : Fin n → Expr R n
  | plus : Expr R n → Expr R n → Expr R n
  | times : Expr R n → Expr R n → Expr R n

def Expr.eval {n : Nat} : Expr R n → (Fin n → R) → R
  | .lit c, _ => c
  | .var i, x => x i
  | .plus p q, x => p.eval x + q.eval x
  | .times p q, x => p.eval x * q.eval x

def Expr.normalize {n : Nat} : Expr R n → Normal R n
  | .lit c => constant n c
  | .var i => coordinate i
  | .plus p q => add p.normalize q.normalize
  | .times p q => multiply p.normalize q.normalize

/-- A checked normalization procedure, independent of how the expression was
originally decomposed. It does not assert that fewer monomials cost less hardware. -/
theorem normalize_correct {n : Nat} (p : Expr R n) (x : Fin n → R)
    (hx : CubicGrid x) : evaluate p.normalize x = p.eval x := by
  induction p with
  | lit c => exact evaluate_constant n c x
  | var i => exact evaluate_variable i x
  | plus p q hp hq => simp [Expr.normalize, Expr.eval, evaluate_add, hp, hq]
  | times p q hp hq => simp [Expr.normalize, Expr.eval, evaluate_multiply _ _ _ hx, hp, hq]

theorem equivalent_of_normal_equal {n : Nat} (p q : Expr R n)
    (h : p.normalize = q.normalize) (x : Fin n → R) (hx : CubicGrid x) :
    p.eval x = q.eval x := by
  rw [← normalize_correct p x hx, ← normalize_correct q x hx, h]

def Trit (v : R) : Prop := v = -1 ∨ v = 0 ∨ v = 1

def TernaryGrid {n : Nat} (x : Fin n → R) : Prop := ∀ i, Trit (x i)

theorem ternary_is_cubic {n : Nat} (x : Fin n → R) (hx : TernaryGrid x) : CubicGrid x := by
  intro i
  rcases hx i with h | h | h <;> rw [h] <;> grind

def prepend {n : Nat} (v : R) (x : Fin n → R) : Fin (n+1) → R := Fin.cases v x

omit [CommRing R] in
@[simp] theorem prepend_zero {n : Nat} (v : R) (x : Fin n → R) : prepend v x 0 = v := rfl
omit [CommRing R] in
@[simp] theorem prepend_succ {n : Nat} (v : R) (x : Fin n → R) (i : Fin n) :
    prepend v x i.succ = x i := rfl

theorem cons_grid {n : Nat} (v : R) (hv : Trit v) (x : Fin n → R)
    (hx : TernaryGrid x) : TernaryGrid (prepend v x) := by
  intro i
  refine Fin.cases ?_ (fun j => ?_) i
  · simpa using hv
  · simpa using hx j

/-- Coefficient uniqueness needs cancellation by two. It fails, for example,
in characteristic two, where the nominal -1 and +1 grid points coincide. -/
theorem coefficients_unique {n : Nat}
    (cancelTwo : ∀ a b : R, 2*a = 2*b → a=b)
    (p q : Normal R n)
    (h : ∀ x, TernaryGrid x → evaluate p x = evaluate q x) : p=q := by
  induction n with
  | zero =>
    exact h Fin.elim0 (by intro i; exact Fin.elim0 i)
  | succ n ih =>
    rcases p with ⟨a,b,c⟩; rcases q with ⟨d,e,f⟩
    have each (x : Fin n → R) (hx : TernaryGrid x) :
        evaluate a x = evaluate d x ∧ evaluate b x = evaluate e x ∧
        evaluate c x = evaluate f x := by
      have h0 := h (prepend 0 x) (cons_grid 0 (Or.inr (Or.inl rfl)) x hx)
      have hm := h (prepend (-1) x) (cons_grid (-1) (Or.inl rfl) x hx)
      have hp := h (prepend 1 x) (cons_grid 1 (Or.inr (Or.inr rfl)) x hx)
      simp only [evaluate, prepend_zero, prepend_succ] at h0 hm hp
      have ha : evaluate a x = evaluate d x := by grind
      have hb : evaluate b x = evaluate e x := by
        apply cancelTwo
        grind
      grind
    have ha := ih a d (fun x hx => (each x hx).1)
    have hb := ih b e (fun x hx => (each x hx).2.1)
    have hc := ih c f (fun x hx => (each x hx).2.2)
    rw [ha,hb,hc]

def scale (r : R) : {n : Nat} → Normal R n → Normal R n
  | 0, p => r*(p:R)
  | _+1, (a,b,c) => (scale r a, scale r b, scale r c)

theorem evaluate_scale {n : Nat} (r : R) (p : Normal R n) (x : Fin n → R) :
    evaluate (scale r p) x = r*evaluate p x := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rcases p with ⟨a,b,c⟩
    simp only [scale, evaluate, ih]
    grind

/-- Tensor-product interpolation. Invertibility of two is explicit; it must not
be silently applied to modular integers or hardware floating arithmetic. -/
def interpolate (half : R) : (n : Nat) → ((Fin n → R) → R) → Normal R n
  | 0, f => f Fin.elim0
  | n+1, f =>
    let a := interpolate half n (fun x => f (prepend 0 x))
    let m := interpolate half n (fun x => f (prepend (-1) x))
    let p := interpolate half n (fun x => f (prepend 1 x))
    (a, scale half (add p (scale (-1) m)),
        add (scale half (add p m)) (scale (-1) a))

theorem interpolate_correct (half : R) (hhalf : 2*half=1) (n : Nat)
    (f : (Fin n → R) → R) (x : Fin n → R) (hx : TernaryGrid x) :
    evaluate (interpolate half n f) x = f x := by
  induction n with
  | zero =>
    have he : x = Fin.elim0 := by funext i; exact Fin.elim0 i
    subst x
    rfl
  | succ n ih =>
    have ht : TernaryGrid (fun i : Fin n => x i.succ) := fun i => hx i.succ
    have he : prepend (x 0) (fun i : Fin n => x i.succ) = x := by
      funext i
      refine Fin.cases ?_ (fun j => ?_) i <;> rfl
    have hf := congrArg f he
    simp only [interpolate, evaluate, evaluate_add, evaluate_scale, ih _ _ ht]
    rcases hx 0 with h | h | h <;> rw [h] <;> grind

/-- For these coefficient rings the normal form decides polynomial behaviour on
the entire ternary grid, rather than merely supplying a sufficient identity test. -/
theorem normal_equal_iff {n : Nat} (cancelTwo : ∀ a b : R, 2*a=2*b → a=b)
    (p q : Expr R n) :
    p.normalize=q.normalize ↔ ∀ x, TernaryGrid x → p.eval x=q.eval x := by
  constructor
  · intro h x hx
    exact equivalent_of_normal_equal p q h x (ternary_is_cubic x hx)
  · intro h
    apply coefficients_unique cancelTwo
    intro x hx
    rw [normalize_correct p x (ternary_is_cubic x hx),
      normalize_correct q x (ternary_is_cubic x hx)]
    exact h x hx

def Expr.substitute {m n : Nat} (args : Fin n → Expr R m) : Expr R n → Expr R m
  | .lit c => .lit c
  | .var i => args i
  | .plus p q => .plus (p.substitute args) (q.substitute args)
  | .times p q => .times (p.substitute args) (q.substitute args)

theorem substitution_eval {m n : Nat} (p : Expr R n) (args : Fin n → Expr R m)
    (x : Fin m → R) : (p.substitute args).eval x = p.eval (fun i => (args i).eval x) := by
  induction p with
  | lit c => rfl
  | var i => rfl
  | plus p q hp hq => simp [Expr.substitute, Expr.eval, hp, hq]
  | times p q hp hq => simp [Expr.substitute, Expr.eval, hp, hq]

def CubicClosed {n : Nat} (p : Normal R n) : Prop := multiply (multiply p p) p = p

theorem closure_certificate {n : Nat} (p : Normal R n) (hp : CubicClosed p)
    (x : Fin n → R) (hx : CubicGrid x) :
    evaluate p x * evaluate p x * evaluate p x = evaluate p x := by
  have h := congrArg (fun a => evaluate a x) hp
  simpa only [evaluate_multiply _ _ _ hx] using h

/-- Replacing a finite-grid map inside a larger expression needs an input-domain
certificate. Inlining the original expressions before normalization needs none. -/
theorem substitute_normal_identity {m n : Nat} (p q : Expr R n)
    (h : p.normalize=q.normalize) (args : Fin n → Expr R m)
    (closed : ∀ i, CubicClosed (args i).normalize)
    (x : Fin m → R) (hx : CubicGrid x) :
    (p.substitute args).eval x = (q.substitute args).eval x := by
  rw [substitution_eval, substitution_eval]
  apply equivalent_of_normal_equal p q h
  intro i
  have hc := closure_certificate (args i).normalize (closed i) x hx
  simpa only [normalize_correct _ x hx] using hc

/-- A finite-grid identity need not survive substitution of a non-ternary
intermediate. At x=1 the proposed intermediate x+1 is 2, and y^3-y is 6. -/
theorem unrestricted_substitution_fails :
    (∀ x : Int, Trit x → x*x*x-x=0) ∧
    ((1:Int)+1)*((1:Int)+1)*((1:Int)+1)-((1:Int)+1)=6 := by
  constructor
  · intro x hx
    rcases hx with rfl | rfl | rfl <;> decide
  · decide

/-- Rational interpolation does not license fractional coefficients in modular
integer hardware. Even this one-hot map has no integer quadratic representative. -/
theorem integer_one_hot_not_polynomial :
    ¬ ∃ p : Normal Int 1,
      evaluate p (fun _ => (-1))=0 ∧ evaluate p (fun _ => 0)=0 ∧
      evaluate p (fun _ => 1)=1 := by
  rintro ⟨⟨a,b,c⟩,h⟩
  simp only [evaluate] at h
  omega

def coefficient : {n : Nat} → Normal R n → (Fin n → Fin 3) → R
  | 0, p, _ => p
  | _+1, (a,b,c), e =>
    let tail := fun i => e i.succ
    if e 0 = 0 then coefficient a tail
    else if e 0 = 1 then coefficient b tail else coefficient c tail

def oddDegree : {n : Nat} → (Fin n → Fin 3) → Bool
  | 0, _ => false
  | _+1, e => (e 0 == 1) ^^ oddDegree (fun i => e i.succ)

def reflect : {n : Nat} → Normal R n → Normal R n
  | 0, p => p
  | _+1, (a,b,c) => (reflect a, scale (-1) (reflect b), reflect c)

theorem coefficient_add {n : Nat} (p q : Normal R n) (e : Fin n → Fin 3) :
    coefficient (add p q) e = coefficient p e + coefficient q e := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rcases p with ⟨a,b,c⟩; rcases q with ⟨d,f,g⟩
    simp only [add, coefficient]
    split <;> (try split) <;> exact ih _ _ _

theorem coefficient_scale {n : Nat} (r : R) (p : Normal R n) (e : Fin n → Fin 3) :
    coefficient (scale r p) e = r*coefficient p e := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rcases p with ⟨a,b,c⟩
    simp only [scale, coefficient]
    split <;> (try split) <;> exact ih _ _

theorem evaluate_reflect {n : Nat} (p : Normal R n) (x : Fin n → R) :
    evaluate (reflect p) x = evaluate p (fun i => -x i) := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rcases p with ⟨a,b,c⟩
    simp only [reflect, evaluate, evaluate_scale, ih]
    grind

theorem coefficient_reflect {n : Nat} (p : Normal R n) (e : Fin n → Fin 3) :
    coefficient (reflect p) e =
      if oddDegree e then -coefficient p e else coefficient p e := by
  induction n with
  | zero => simp [reflect, coefficient, oddDegree]
  | succ n ih =>
    rcases p with ⟨a,b,c⟩
    have he : e 0 = 0 ∨ e 0 = 1 ∨ e 0 = 2 := by omega
    rcases he with he | he | he <;>
      simp [reflect, coefficient, coefficient_scale, oddDegree, he, ih] <;>
      split <;> grind

/-- A reflection identity prunes coefficients without inspecting hidden units.
If the observed even part has no coefficient here, neither does the full map. -/
theorem even_coefficient_vanishes {n : Nat}
    (cancelTwo : ∀ a b : R, 2*a=2*b → a=b)
    (p q : Normal R n) (h : add p (reflect p) = q)
    (e : Fin n → Fin 3) (he : oddDegree e = false)
    (hq : coefficient q e = 0) : coefficient p e = 0 := by
  have hc := congrArg (fun a => coefficient a e) h
  simp only [coefficient_add, coefficient_reflect, he, Bool.false_eq_true, ↓reduceIte] at hc
  apply cancelTwo
  grind

end Kelana.TernaryAlgebra
