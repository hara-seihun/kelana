// Online arithmetic cores under a free wire-packing pass.
// Packing produces the dynamic operands; preparation produces the weight words
// and accumulator constants.  Both are outside these cores.
.text

// Incumbent: two int4 dots on the shared expanded word, then join the bytes.
// v1: eight trit codes in nibble lanes. v16,v17: fused int4 weight words. v20: bias.
.globl toy2_incumbent_online
toy2_incumbent_online:
  v_dot8_i32_iu4 v2, v16, v1, v20 neg_lo:[1,0,0]
  v_dot8_i32_iu4 v3, v17, v1, v20 neg_lo:[1,0,0]
  v_lshl_or_b32 v0, v3, 8, v2
  s_endpgm

// Fused: the column-1 dot carries the output byte position in its weights, and
// the column-0 dot adds it through the accumulator operand.
// v1: column-1 codes, each prescaled by 16 inside its own byte lane.
// v2: column-0 codes in nibble lanes.
// v16: int8 weights 16*k. v17: int4 weights k. v20: 257*bias.
.globl toy2_fused_online
toy2_fused_online:
  v_dot4_i32_iu8 v3, v16, v1, v20 neg_lo:[1,0,0]
  v_dot8_i32_iu4 v0, v17, v2, v3 neg_lo:[1,0,0]
  s_endpgm

// Single instruction, A-dependent wiring (witness found for A = identity).
// v1: lane source wired for this A. v2: accumulator source wired for this A.
// v16: prepared int8 weights.
.globl toy2_single_online
toy2_single_online:
  v_dot4_i32_iu8 v0, v16, v1, v2 neg_lo:[1,0,0]
  s_endpgm
