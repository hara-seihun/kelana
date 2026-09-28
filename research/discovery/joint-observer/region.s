// gfx1151, one packed input per lane: v0 = q in [0,26].
// Prepared integer coefficients: v7=a0, v6=a1, v5=a2, v4=a3, v3=a4.
// Each coefficient is in [-7,7]. v1 and v2 are scratch; output replaces v0.
// This is a straight-line data region, not a launchable kernel.
.text
v_mad_u32_u24 v0, v0, 27, -320
v_bfe_i32 v0, v0, 6, 4
v_mul_i32_i24 v1, v0, v0
v_mad_i32_i24 v2, v1, v3, v4
v_mad_i32_i24 v2, v1, v2, v5
v_mad_i32_i24 v2, v1, v2, v6
v_mad_i32_i24 v2, v1, v2, v7
v_mul_i32_i24 v0, v0, v2
