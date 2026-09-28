.text
.globl square_cell
square_cell:
    v_mul_lo_u32 v0, v0, v0
    v_lshrrev_b32 v0, 7, v0
    s_endpgm

.globl affine_seed0
 affine_seed0:
    v_mul_lo_u32 v0, 31, v0
    v_lshrrev_b32 v0, 7, v0
    s_endpgm
