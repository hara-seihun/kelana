// Input v0: two column bytes, each containing b0,b1,c0,c1 as unsigned 2-bit trit codes.
// Output v0: one radix-7 encoded output column per byte. All preparation is outside these cores.
.text
.globl toy2_baseline
toy2_baseline:
// Prepared v16..v19: four signed-i4 coefficient words. v20,v21: row biases.
  v_lshl_or_b32 v1, v0, 8, v0
  v_and_b32 v1, 0x00ff00ff, v1
  v_lshl_or_b32 v1, v1, 4, v1
  v_and_b32 v1, 0x0f0f0f0f, v1
  v_lshl_or_b32 v1, v1, 2, v1
  v_and_b32 v1, 0x33333333, v1
  v_dot8_i32_iu4 v2, v16, v1, v20 neg_lo:[1,0,0]
  v_dot8_i32_iu4 v3, v17, v1, v21 neg_lo:[1,0,0]
  v_dot8_i32_iu4 v4, v18, v1, v20 neg_lo:[1,0,0]
  v_dot8_i32_iu4 v5, v19, v1, v21 neg_lo:[1,0,0]
  v_mad_u32_u24 v2, v2, 7, v3
  v_mad_u32_u24 v4, v4, 7, v5
  v_lshl_or_b32 v0, v4, 8, v2
  s_endpgm

.globl toy2_packed
toy2_packed:
// Prepared v16,v17: two fused coefficient words. v20: fused bias.
  v_lshl_or_b32 v1, v0, 8, v0
  v_and_b32 v1, 0x00ff00ff, v1
  v_lshl_or_b32 v1, v1, 4, v1
  v_and_b32 v1, 0x0f0f0f0f, v1
  v_lshl_or_b32 v1, v1, 2, v1
  v_and_b32 v1, 0x33333333, v1
  v_dot8_i32_iu4 v2, v16, v1, v20 neg_lo:[1,0,0]
  v_dot8_i32_iu4 v3, v17, v1, v20 neg_lo:[1,0,0]
  v_lshl_or_b32 v0, v3, 8, v2
  s_endpgm
