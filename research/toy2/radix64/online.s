// Core after the shared wire has put column 0's two-bit codes at bit 0
// and column 1's codes at bit 6 in each byte. v16 contains signed weights
// (a10+7a00, a11+7a01, 7, 1); v20 contains 65*(24-sum(weights)).
.text
.globl toy2_radix64_online
toy2_radix64_online:
  v_dot4_i32_iu8 v0, v16, v1, v20 neg_lo:[1,0,0]
  s_endpgm
