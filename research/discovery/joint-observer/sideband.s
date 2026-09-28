// Input v0: packed q in 0..26. Outputs v1: h in -5..5, v2: q & 3.
// The original q remains in v0. The sideband can be materialized before
// reusing v0, but retaining v0 instead is cheaper when a register is free.
v_mad_u32_u24 v1, v0, 27, -320
v_bfe_i32 v1, v1, 6, 4
v_and_b32 v2, 3, v0
