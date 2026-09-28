// Input v0 is q = (x+1) + 3*(y+1) + 9*(z+1), q in 0..26.
// Output v0 is the signed integer result of the five-unit network in PackedObserver.lean.
v_mad_u32_u24 v0, v0, 11, -13
v_bfe_i32 v0, v0, 8, 2
