#!/usr/bin/env python3
"""Exact rewrites of a paired ternary gate/up network, and their limits.

Everything here is real arithmetic. `SiLU(t) - SiLU(-t) = t` is an identity over the reals;
it is not a statement about FP32 rounding and it is not commuted through quantisation.
Equality is reported as a measured residual in float64, not asserted bitwise.

Sections:
  1  class collapse for an arbitrary sign-class, unlike up rows, arbitrary consumer rows
  2  a 4 -> 8 -> 4 network whose classes are residue-free: half the MACs, no transcendental
  3  what breaks it: per-block sign flips, scale ratios other than +-1, near-duplicates
  4  the pole/residue invariant that forbids doing better on ordinary weights
  5  Bonsai-scale accounting for a designed +-paired FFN
"""
from dataclasses import dataclass
import numpy as np

rng = np.random.default_rng(7)


def silu(t):
    return t / (1.0 + np.exp(-t))


def tern(*shape):
    return rng.integers(-1, 2, size=shape).astype(np.float64)


@dataclass
class Ops:
    """Online work for one token. `mac` counts dense weight-times-activation accumulations."""
    mac: int = 0
    exp: int = 0
    mul: int = 0
    add: int = 0

    def __add__(self, o):
        return Ops(self.mac + o.mac, self.exp + o.exp, self.mul + o.mul, self.add + o.add)

    def __str__(self):
        return f"mac={self.mac:<8} exp={self.exp:<6} mul={self.mul:<5} add={self.add}"


# ---------------------------------------------------------------------------------------
# Blocked ternary rows: value = sum over 128-element groups of scale_b * <trits_b, x_b>.
# The identity needs whole-row equality up to ONE global sign, with equal scale vectors.

class Blocked:
    def __init__(self, trits, scales, block):
        self.t, self.s, self.b = trits, scales, block

    def __call__(self, x):
        parts = self.t.reshape(-1, self.b) * x.reshape(-1, self.b)
        return (parts.sum(axis=1) * self.s).sum()

    def dense(self):
        return (self.t.reshape(-1, self.b) * self.s[:, None]).reshape(-1)


def blocked_rows(n, d, block):
    return [Blocked(tern(d), rng.normal(size=d // block) ** 2 + 0.25, block) for _ in range(n)]


# ---------------------------------------------------------------------------------------
print(__doc__.splitlines()[0])
print("\n== 1. class collapse: k units sharing one gate row up to sign ==")

D, BLOCK, K = 16, 4, 5
x = rng.normal(size=D)
G = blocked_rows(1, D, BLOCK)[0]
ups = blocked_rows(K, D, BLOCK)
eps = np.array([1, -1, -1, 1, -1], dtype=np.float64)
cs = rng.normal(size=K)

g = G(x)
direct = sum(cs[i] * silu(eps[i] * g) * ups[i](x) for i in range(K))
A = sum(cs[i] * ups[i].dense() for i in range(K))
B = sum(cs[i] * ups[i].dense() for i in range(K) if eps[i] < 0)
collapsed = silu(g) * (A @ x) - g * (B @ x)
print(f"  direct {direct:.15f}  collapsed {collapsed:.15f}  residual {abs(direct - collapsed):.3e}")
print("  A = sum_i c_i U_i (the residue row), B = sum over negated members")

# A residue-free class does not need equal up rows. Three members with U3 = U1 + U2 and
# consumer coefficients (1, 1, -1) cancel; disjoint supports keep U3 ternary, so the
# construction stays inside the weight format.
u1t, u2t = tern(D), tern(D)
u1t[D // 2:] = 0
u2t[:D // 2] = 0
sc = rng.normal(size=D // BLOCK) ** 2 + 0.25
U1, U2 = Blocked(u1t, sc, BLOCK), Blocked(u2t, sc, BLOCK)
U3 = Blocked(u1t + u2t, sc, BLOCK)
triple = [(1.0, U1, 1.0), (1.0, U2, -1.0), (-1.0, U3, 1.0)]
tri_direct = sum(c * silu(e * g) * u(x) for c, u, e in triple)
tri_bilinear = -g * U2(x)
print(f"  unlike-up residue-free triple: direct {tri_direct:.15f}  bilinear {tri_bilinear:.15f}"
      f"  residual {abs(tri_direct - tri_bilinear):.3e}")
print("  three units, three distinct ternary up rows, one product and no SiLU")


# ---------------------------------------------------------------------------------------
print("\n== 2. a 4 -> 8 -> 4 network with four residue-free classes ==")

DI, FF, DO, BLK = 4, 8, 4, 2
base = blocked_rows(4, DI, BLK)          # class representatives r_0 .. r_3
upbase = blocked_rows(4, DI, BLK)        # one up row per class, shared by both members
Cbase = tern(DO, 4)                      # consumer column per class

# Hidden unit 2k is (+r_k, u_k, +c_k); unit 2k+1 is (-r_k, u_k, -c_k).
gate_rows = [base[k // 2] for k in range(FF)]
gate_sign = np.array([1.0, -1.0] * 4)
up_rows = [upbase[k // 2] for k in range(FF)]
Cmat = np.zeros((DO, FF))
for k in range(4):
    Cmat[:, 2 * k] = Cbase[:, k]
    Cmat[:, 2 * k + 1] = -Cbase[:, k]


def baseline(x):
    """The network as written: FF gate dots, FF up dots, FF SiLUs, FF products, consumer."""
    gv = np.array([gate_sign[i] * gate_rows[i](x) for i in range(FF)])
    uv = np.array([up_rows[i](x) for i in range(FF)])
    z = silu(gv) * uv
    ops = Ops(mac=FF * DI * 2 + DO * FF, exp=FF, mul=FF, add=0)
    return Cmat @ z, ops


def reduced_shared(x):
    """Only the +- pairing is used: one gate dot and one SiLU per class, consumer untouched."""
    z = np.empty(FF)
    for k in range(4):
        g = base[k](x)
        s = silu(g)
        z[2 * k] = s * up_rows[2 * k](x)
        z[2 * k + 1] = (s - g) * up_rows[2 * k + 1](x)      # SiLU(-g) = SiLU(g) - g
    ops = Ops(mac=4 * DI + FF * DI + DO * FF, exp=4, mul=FF, add=4)
    return Cmat @ z, ops


def reduced_bilinear(x):
    """Residue-free classes: no SiLU at all, one gate dot, one up dot, one consumer column."""
    y = np.zeros(DO)
    for k in range(4):
        y += Cbase[:, k] * (base[k](x) * upbase[k](x))
    ops = Ops(mac=4 * DI + 4 * DI + DO * 4, exp=0, mul=4, add=0)
    return y, ops


xs = rng.normal(size=(64, DI))
r = [(baseline(v), reduced_shared(v), reduced_bilinear(v)) for v in xs]
e1 = max(np.abs(a[0] - b[0]).max() for a, b, _ in r)
e2 = max(np.abs(a[0] - c[0]).max() for a, _, c in r)
print(f"  baseline vs shared-gate  max |diff| over 64 inputs: {e1:.3e}")
print(f"  baseline vs bilinear     max |diff| over 64 inputs: {e2:.3e}")
for name, o in (("baseline", r[0][0][1]), ("shared gate", r[0][1][1]), ("bilinear", r[0][2][1])):
    print(f"  {name:<12} {o}")
print("  offline storage: bilinear form keeps 4 gate rows + 4 up rows + 4 consumer columns"
      f" = {3 * 4 * DI} trits, against {2 * FF * DI + DO * FF} for the written network")
print("  weight condition: G_{2k+1} = -G_{2k} (whole row, equal block scales),"
      " U_{2k+1} = U_{2k}, C[:,2k+1] = -C[:,2k]")

# A class that keeps its nonlinearity still halves gate work: verify a mixed network.
Cmix = Cmat.copy()
Cmix[:, 5] = tern(DO)                      # class 2 is no longer residue-free
mix_base = Cmix @ np.array([silu(gate_sign[i] * gate_rows[i](xs[0])) * up_rows[i](xs[0])
                            for i in range(FF)])
zmix = np.empty(FF)
for k in range(4):
    g = base[k](xs[0]); s = silu(g)
    zmix[2 * k] = s * up_rows[2 * k](xs[0])
    zmix[2 * k + 1] = (s - g) * up_rows[2 * k + 1](xs[0])
print(f"  mixed network (3 residue-free classes, 1 not): max |diff| "
      f"{np.abs(mix_base - Cmix @ zmix).max():.3e}, exp 8 -> 4, gate mac 64 -> 32")


# ---------------------------------------------------------------------------------------
print("\n== 3. what breaks the identity ==")

xb = rng.normal(size=D)
Gf = Blocked(G.t.copy(), G.s.copy(), BLOCK)
Gf.t = Gf.t.reshape(-1, BLOCK).copy()
Gf.t[0] *= -1                                   # flip one 128-block only
Gf.t = Gf.t.reshape(-1)
u = ups[0]
lhs = silu(G(xb)) * u(xb) + silu(Gf(xb)) * u(xb)
rhs = G(xb) * u(xb)                             # what a whole-row flip would give
print(f"  per-block sign flip: identity residual {abs(lhs - rhs):.3e} (not an identity)")

lam = 1.7
ts = np.linspace(-4, 4, 400)
basis = np.stack([silu(ts), ts, np.ones_like(ts)]).T
coef, *_ = np.linalg.lstsq(basis, silu(lam * ts), rcond=None)
res = np.abs(basis @ coef - silu(lam * ts)).max()
print(f"  scale ratio {lam}: best fit of SiLU({lam}t) by span(SiLU(t), t, 1) misses by {res:.4f}"
      f"  (poles move to t = i*pi/{lam}; see section 4)")

# Near-miss at model scale: a 5120-wide row at the measured 67% density, one trit changed.
big = tern(5120)
big[rng.permutation(5120)[:1678]] = 0.0
near = big.copy()
near[int(np.argmax(near != 0))] *= -1
xs5 = rng.normal(size=(256, 5120)) / np.sqrt(5120)
gv = xs5 @ big
err = np.abs(silu(-(xs5 @ near)) - (silu(gv) - gv))
print(f"  5120-wide row, one trit away from opposite: mean |error| {err.mean():.4f}, "
      f"max {err.max():.4f}, typical |g| {np.abs(gv).mean():.4f}")
print("  (no exact rewrite; the identity is not continuous in the weights)")


# ---------------------------------------------------------------------------------------
print("\n== 4. the residue invariant ==")
# SiLU(t) = t*sigmoid(t) has simple poles at t = i*pi*(2k+1), residue i*pi*(2k+1).
# Along the hyperplane {<G,x> = i*pi} the residue of the network output is
#   i*pi * <A_S, x>,  A_S = sum over the class of c_i * U_i,
# and SiLU(-g) contributes the same residue as SiLU(g), which is why the class shares one pole.
ip = 1j * np.pi


def silu_c(t):
    return t / (1.0 + np.exp(-t))


d = np.zeros(D)
d[:] = rng.normal(size=D)
d = d / (Blocked(G.t, G.s, BLOCK).dense() @ d)          # <G, d> = 1
x0 = rng.normal(size=D)
g0 = Blocked(G.t, G.s, BLOCK).dense() @ x0

for delta in (1e-2, 1e-4, 1e-6):
    tau = (ip + delta - g0)
    xc = x0.astype(complex) + tau * d
    val = sum(cs[i] * silu_c(eps[i] * (Blocked(G.t, G.s, BLOCK).dense() @ xc)) * (ups[i].dense() @ xc)
              for i in range(K))
    residue = delta * val
    predicted = ip * (A @ xc)
    print(f"  delta={delta:.0e}  delta*y = {residue:.6f}   i*pi*<A,x> = {predicted:.6f}")
print("  A = 0 kills the pole. Within the model 'sum of polynomial*SiLU(affine) + polynomial',")
print("  a class with A != 0 whose polar part is not cancelled by another class on the same")
print("  direction forces its own SiLU term; see NOTES.md bounds B and F for the hypotheses.")


# ---------------------------------------------------------------------------------------
print("\n== 5. Bonsai scale, designed +-paired FFN (D=5120, FF=17408, 64 layers) ==")
Dm, FFm, L = 5120, 17408, 64
gate = Dm * FFm
print(f"  per token per layer: gate {gate/1e6:.1f}M -> {gate/2e6:.1f}M mac, "
      f"SiLU {FFm} -> {FFm//2}, one extra subtract per class")
print(f"  FFN mac 3*D*FF = {3*gate/1e6:.1f}M -> {2.5*gate/1e6:.1f}M  (-16.7%)")
row_bytes = 1120                                        # 40 halo blocks of 28 bytes
print(f"  gate tensor {FFm*row_bytes/2**20:.1f} MiB/layer -> {FFm*row_bytes/2/2**20:.1f} MiB, "
      f"{L*FFm*row_bytes/2/2**30:.2f} GiB off the 5.47 GiB file")
print("  residue-free pairs additionally delete their up row, consumer column and both SiLUs:")
print(f"  an all-residue-free FFN is {2*gate/1e6:.1f}M mac with no transcendental, "
      "at half the hidden rank")
