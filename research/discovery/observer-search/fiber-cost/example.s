# Input v0 = (x+1) + 3(y+1) + 9(z+1), x,y,z in {-1,0,1}.
# Output v3 = sign(SiLU(x+y+z)*(x-y)) over the complete 27-state cube.
v_bfe_u32 v1, 0x00905048, v0, 1
v_bfe_u32 v2, 0x03010406, v0, 1
v_sub_u32 v3, v1, v2
