# v0 = r = min(q, 26-q), q = (x+1)+3(y+1)+9(z+1).
# Output v1 = sign(SiLU(x+y+z)*(x-y)) on the complete ternary cube.
v_lshlrev_b32 v2, 1, v0
v_bfe_i32 v1, 0x0130107c, v2, 2

# When the producer supplies q instead of r, first compute r:
# v_sub_nc_u32_e32 v3, 26, v0
# v_min_u32_e32 v4, v0, v3
# v_lshlrev_b32_e32 v2, 1, v4
# v_bfe_i32 v1, 0x0130107c, v2, 2
