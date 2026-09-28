// Full six-parameter family. Same contract as region.s, plus v8=a5 in [-7,7].
// v1 holds h*h first, then the sixth observer. No original hidden unit is recovered.
.text
v_mad_u32_u24 v0, v0, 27, -320
v_bfe_i32 v0, v0, 6, 4
v_mul_i32_i24 v1, v0, v0
v_mad_i32_i24 v2, v1, v3, v4
v_mad_i32_i24 v2, v1, v2, v5
v_mad_i32_i24 v2, v1, v2, v6
v_mad_i32_i24 v2, v1, v2, v7
v_lshl_add_u32 v1, v0, 1, 10
v_bfe_u32 v1, 0x355157, v1, 2
v_mul_i32_i24 v0, v0, v2
v_mad_i32_i24 v0, v1, v8, v0
