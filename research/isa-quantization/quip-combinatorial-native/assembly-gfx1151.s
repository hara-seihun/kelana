	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.p2align	2                               ; -- Begin function _Z13transform1024Pfi
	.type	_Z13transform1024Pfi,@function
_Z13transform1024Pfi:                   ; @_Z13transform1024Pfi
; %bb.0:                                ; %.preheader.preheader
	s_waitcnt vmcnt(0) expcnt(0) lgkmcnt(0)
	v_and_b32_e32 v6, 0x3fe, v2
	v_dual_mov_b32 v4, 0 :: v_dual_add_nc_u32 v5, 0x80, v2
	v_or_b32_e32 v3, 1, v2
	v_add_nc_u32_e32 v15, 0x200, v2
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshlrev_b32_e32 v8, 2, v6
	v_lshlrev_b64 v[6:7], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, v0, v8
	v_add_co_ci_u32_e64 v9, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v0, v6
	v_add_co_ci_u32_e64 v11, null, v1, v7, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[8:9]
	v_and_b32_e32 v3, 0x7fe, v5
	v_add_nc_u32_e32 v6, 0x100, v2
	v_cndmask_b32_e32 v14, -1, v8, vcc_lo
	v_lshlrev_b32_e32 v12, 2, v3
	v_or_b32_e32 v3, 1, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v7, vcc_lo, v0, v12
	v_add_co_ci_u32_e64 v8, null, 0, v1, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[10:11]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[12:13], 2, v[3:4]
	v_cndmask_b32_e32 v16, -1, v10, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[7:8]
	v_cndmask_b32_e32 v17, -1, v7, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_add_co_u32 v8, vcc_lo, v0, v12
	v_and_b32_e32 v3, 0x7fe, v6
	v_add_co_ci_u32_e64 v9, null, v1, v13, vcc_lo
	v_lshlrev_b32_e32 v10, 2, v3
	v_or_b32_e32 v3, 1, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v0, v10
	v_add_co_ci_u32_e64 v11, null, 0, v1, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[8:9]
	v_cndmask_b32_e32 v18, -1, v8, vcc_lo
	v_lshlrev_b64 v[8:9], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[10:11]
	v_cndmask_b32_e32 v19, -1, v10, vcc_lo
	v_add_co_u32 v8, vcc_lo, v0, v8
	v_add_nc_u32_e32 v7, 0x180, v2
	v_add_co_ci_u32_e64 v9, null, v1, v9, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_and_b32_e32 v12, 0x7fe, v7
	v_or_b32_e32 v3, 1, v7
	v_lshlrev_b32_e32 v12, 2, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_lshlrev_b64 v[10:11], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fe, v15
	v_add_co_u32 v12, vcc_lo, v0, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v13, null, 0, v1, vcc_lo
	v_add_co_u32 v10, vcc_lo, v0, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, v1, v11, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[8:9]
	v_dual_cndmask_b32 v20, -1, v8 :: v_dual_lshlrev_b32 v9, 2, v3
	v_cmp_ne_u64_e32 vcc_lo, 0, v[12:13]
	v_dual_cndmask_b32 v13, -1, v12 :: v_dual_add_nc_u32 v8, 0x280, v2
	v_cmp_ne_u64_e32 vcc_lo, 0, v[10:11]
	v_cndmask_b32_e32 v21, -1, v10, vcc_lo
	v_add_co_u32 v9, vcc_lo, v0, v9
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, 0, v1, vcc_lo
	ds_load_b32 v22, v14
	ds_load_b32 v23, v16
	ds_load_b32 v24, v17
	ds_load_b32 v25, v18
	ds_load_b32 v26, v19
	ds_load_b32 v20, v20
	ds_load_b32 v27, v13
	ds_load_b32 v21, v21
	v_cmp_ne_u64_e32 vcc_lo, 0, v[9:10]
	v_cndmask_b32_e32 v18, -1, v9, vcc_lo
	v_or_b32_e32 v3, 1, v15
	v_add_nc_u32_e32 v9, 0x300, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[11:12], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fe, v8
	v_lshlrev_b32_e32 v13, 2, v3
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v0, v11
	v_add_co_ci_u32_e64 v11, null, v1, v12, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, vcc_lo, v0, v13
	v_add_co_ci_u32_e64 v13, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[10:11]
	v_or_b32_e32 v3, 1, v8
	v_lshlrev_b64 v[16:17], 2, v[3:4]
	v_cndmask_b32_e32 v19, -1, v10, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[12:13]
	v_and_b32_e32 v3, 0x7fe, v9
	v_add_nc_u32_e32 v10, 0x380, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_cndmask_b32 v28, -1, v12 :: v_dual_lshlrev_b32 v13, 2, v3
	v_add_co_u32 v11, vcc_lo, v0, v16
	v_add_co_ci_u32_e64 v12, null, v1, v17, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v13, vcc_lo, v0, v13
	v_add_co_ci_u32_e64 v14, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[11:12]
	v_or_b32_e32 v3, 1, v9
	v_cndmask_b32_e32 v29, -1, v11, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[13:14]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_lshlrev_b64 v[11:12], 2, v[3:4]
	v_or_b32_e32 v3, 1, v10
	v_cndmask_b32_e32 v30, -1, v13, vcc_lo
	v_lshlrev_b64 v[13:14], 2, v[3:4]
	v_dual_mov_b32 v3, v4 :: v_dual_and_b32 v16, 0x7fe, v10
	v_add_co_u32 v11, vcc_lo, v0, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v12, null, v1, v12, vcc_lo
	v_lshlrev_b32_e32 v16, 2, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v16, vcc_lo, v0, v16
	v_add_co_ci_u32_e64 v17, null, 0, v1, vcc_lo
	v_add_co_u32 v13, vcc_lo, v0, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, v1, v14, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[11:12]
	v_cndmask_b32_e32 v11, -1, v11, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[16:17]
	v_cndmask_b32_e32 v12, -1, v16, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[13:14]
	v_dual_cndmask_b32 v13, -1, v13 :: v_dual_and_b32 v14, 1, v2
	ds_load_b32 v31, v18
	ds_load_b32 v32, v19
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v33, v11
	ds_load_b32 v34, v12
	ds_load_b32 v35, v13
	v_lshlrev_b64 v[11:12], 2, v[2:3]
	v_cmp_eq_u32_e32 vcc_lo, 0, v14
	s_waitcnt lgkmcnt(0)
	s_waitcnt_vscnt null, 0x0
	s_barrier
	buffer_gl0_inv
	v_add_co_u32 v18, s0, v0, v11
	v_cndmask_b32_e64 v13, -v23, v23, vcc_lo
	v_add_co_ci_u32_e64 v19, null, v1, v12, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_u32 v12, s0, 0x200, v18
	v_add_f32_e32 v3, v22, v13
	s_delay_alu instid0(VALU_DEP_3)
	v_add_co_ci_u32_e64 v13, null, 0, v19, s0
	v_cmp_ne_u64_e64 s0, 0, v[18:19]
	v_cndmask_b32_e64 v14, -v25, v25, vcc_lo
	v_cndmask_b32_e64 v16, -v20, v20, vcc_lo
	v_cndmask_b32_e64 v20, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v21, -v32, v32, vcc_lo
	v_cndmask_b32_e64 v22, -v29, v29, vcc_lo
	v_cndmask_b32_e64 v11, -1, v18, s0
	v_cmp_ne_u64_e64 s0, 0, v[12:13]
	v_dual_add_f32 v24, v24, v14 :: v_dual_add_f32 v25, v26, v16
	v_add_f32_e32 v26, v27, v20
	v_add_f32_e32 v27, v31, v21
	v_cndmask_b32_e64 v23, -v33, v33, vcc_lo
	v_cndmask_b32_e64 v12, -1, v12, s0
	v_add_co_u32 v13, s0, 0x400, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, 0, v19, s0
	v_add_co_u32 v16, s0, 0x600, v18
	v_add_co_ci_u32_e64 v17, null, 0, v19, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_cmp_ne_u64_e64 s0, 0, v[13:14]
	v_add_f32_e32 v28, v28, v22
	v_and_b32_e32 v31, 0x3fd, v2
	v_cndmask_b32_e64 v13, -1, v13, s0
	v_cmp_ne_u64_e64 s0, 0, v[16:17]
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v14, -1, v16, s0
	v_add_co_u32 v16, s0, 0x800, v18
	v_add_co_ci_u32_e64 v17, null, 0, v19, s0
	v_add_co_u32 v20, s0, 0xa00, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v21, null, 0, v19, s0
	v_cmp_ne_u64_e64 s0, 0, v[16:17]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cndmask_b32_e64 v16, -1, v16, s0
	v_cmp_ne_u64_e64 s0, 0, v[20:21]
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v17, -1, v20, s0
	v_add_co_u32 v20, s0, 0xc00, v18
	v_add_co_ci_u32_e64 v21, null, 0, v19, s0
	v_add_f32_e32 v29, v30, v23
	v_cndmask_b32_e64 v30, -v35, v35, vcc_lo
	v_add_co_u32 v22, vcc_lo, 0xe00, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v23, null, 0, v19, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_dual_cndmask_b32 v18, -1, v20 :: v_dual_lshlrev_b32 v21, 2, v31
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_add_f32_e32 v20, v34, v30
	v_cndmask_b32_e32 v19, -1, v22, vcc_lo
	ds_store_b32 v11, v3
	ds_store_b32 v12, v24
	ds_store_b32 v13, v25
	ds_store_b32 v14, v26
	ds_store_b32 v16, v27
	ds_store_b32 v17, v28
	ds_store_b32 v18, v29
	ds_store_b32 v19, v20
	v_add_co_u32 v20, vcc_lo, v0, v21
	v_or_b32_e32 v3, 2, v2
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_and_b32_e32 v24, 0x7fd, v5
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 2, v5
	v_lshlrev_b32_e32 v24, 2, v24
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fd, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	v_or_b32_e32 v3, 2, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v29, -1, v20, vcc_lo
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_or_b32_e32 v3, 2, v7
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_and_b32_e32 v24, 0x7fd, v7
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_and_b32_e32 v3, 0x7fd, v15
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v24, 2, v24
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 2, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fd, v8
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_u32 v20, vcc_lo, v0, v22
	v_lshlrev_b32_e32 v24, 2, v3
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_or_b32_e32 v3, 2, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fd, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	v_or_b32_e32 v3, 2, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v37, -1, v20, vcc_lo
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_or_b32_e32 v3, 2, v10
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_and_b32_e32 v24, 0x7fd, v10
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v24, 2, v24
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	v_and_b32_e32 v22, 2, v2
	ds_load_b32 v23, v35
	ds_load_b32 v24, v37
	ds_load_b32 v3, v3
	ds_load_b32 v21, v21
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	s_waitcnt lgkmcnt(10)
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	s_waitcnt lgkmcnt(8)
	v_cndmask_b32_e64 v29, -v29, v29, vcc_lo
	s_waitcnt lgkmcnt(4)
	v_cndmask_b32_e64 v33, -v33, v33, vcc_lo
	v_cndmask_b32_e64 v31, -v31, v31, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	v_add_f32_e32 v29, v32, v33
	ds_load_b32 v22, v34
	ds_load_b32 v25, v36
	ds_load_b32 v34, v38
	ds_load_b32 v20, v20
	v_add_f32_e32 v28, v30, v31
	v_and_b32_e32 v30, 0x3fb, v2
	s_waitcnt lgkmcnt(4)
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v23, -v23, v23, vcc_lo
	v_cndmask_b32_e64 v24, -v24, v24, vcc_lo
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_dual_add_f32 v22, v22, v23 :: v_dual_add_f32 v23, v25, v24
	v_dual_add_f32 v3, v34, v3 :: v_dual_add_f32 v20, v20, v21
	v_lshlrev_b32_e32 v21, 2, v30
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v28
	ds_store_b32 v14, v29
	ds_store_b32 v16, v22
	ds_store_b32 v17, v23
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 4, v2
	v_and_b32_e32 v24, 0x7fb, v5
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_lshlrev_b32_e32 v24, 2, v24
	v_or_b32_e32 v3, 4, v5
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fb, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 4, v6
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v24, 0x7fb, v7
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 4, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x7fb, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 4, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fb, v8
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 4, v8
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7fb, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 4, v9
	v_dual_cndmask_b32 v37, -1, v20 :: v_dual_and_b32 v24, 0x7fb, v10
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 4, v10
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	v_and_b32_e32 v22, 4, v2
	ds_load_b32 v23, v35
	ds_load_b32 v24, v37
	ds_load_b32 v3, v3
	ds_load_b32 v21, v21
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	ds_load_b32 v22, v34
	ds_load_b32 v25, v36
	ds_load_b32 v34, v38
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	v_cndmask_b32_e64 v29, -v29, v29, vcc_lo
	v_cndmask_b32_e64 v31, -v31, v31, vcc_lo
	v_cndmask_b32_e64 v33, -v33, v33, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	v_add_f32_e32 v28, v30, v31
	v_and_b32_e32 v30, 0x3f7, v2
	v_cndmask_b32_e64 v23, -v23, v23, vcc_lo
	v_cndmask_b32_e64 v24, -v24, v24, vcc_lo
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v29, v32, v33 :: v_dual_add_f32 v22, v22, v23
	v_dual_add_f32 v23, v25, v24 :: v_dual_add_f32 v20, v20, v21
	v_lshlrev_b32_e32 v21, 2, v30
	s_delay_alu instid0(VALU_DEP_4)
	v_add_f32_e32 v3, v34, v3
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v28
	ds_store_b32 v14, v29
	ds_store_b32 v16, v22
	ds_store_b32 v17, v23
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 8, v2
	v_and_b32_e32 v24, 0x7f7, v5
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b32_e32 v24, 2, v24
	v_or_b32_e32 v3, 8, v5
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7f7, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 8, v6
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v24, 0x7f7, v7
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 8, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x7f7, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 8, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x7f7, v8
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 8, v8
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7f7, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 8, v9
	v_dual_cndmask_b32 v37, -1, v20 :: v_dual_and_b32 v24, 0x7f7, v10
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 8, v10
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	v_and_b32_e32 v22, 8, v2
	ds_load_b32 v23, v35
	ds_load_b32 v24, v37
	ds_load_b32 v3, v3
	ds_load_b32 v21, v21
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	ds_load_b32 v22, v34
	ds_load_b32 v25, v36
	ds_load_b32 v34, v38
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	v_cndmask_b32_e64 v29, -v29, v29, vcc_lo
	v_cndmask_b32_e64 v31, -v31, v31, vcc_lo
	v_cndmask_b32_e64 v33, -v33, v33, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	v_add_f32_e32 v28, v30, v31
	v_and_b32_e32 v30, 0x3ef, v2
	v_cndmask_b32_e64 v23, -v23, v23, vcc_lo
	v_cndmask_b32_e64 v24, -v24, v24, vcc_lo
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v29, v32, v33 :: v_dual_add_f32 v22, v22, v23
	v_dual_add_f32 v23, v25, v24 :: v_dual_add_f32 v20, v20, v21
	v_lshlrev_b32_e32 v21, 2, v30
	s_delay_alu instid0(VALU_DEP_4)
	v_add_f32_e32 v3, v34, v3
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v28
	ds_store_b32 v14, v29
	ds_store_b32 v16, v22
	ds_store_b32 v17, v23
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 16, v2
	v_and_b32_e32 v24, 0x7ef, v5
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b32_e32 v24, 2, v24
	v_or_b32_e32 v3, 16, v5
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7ef, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 16, v6
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v24, 0x7ef, v7
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 16, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x7ef, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 16, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x7ef, v8
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 16, v8
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7ef, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 16, v9
	v_dual_cndmask_b32 v37, -1, v20 :: v_dual_and_b32 v24, 0x7ef, v10
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 16, v10
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	v_and_b32_e32 v22, 16, v2
	ds_load_b32 v23, v35
	ds_load_b32 v24, v37
	ds_load_b32 v3, v3
	ds_load_b32 v21, v21
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	ds_load_b32 v22, v34
	ds_load_b32 v25, v36
	ds_load_b32 v34, v38
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	v_cndmask_b32_e64 v29, -v29, v29, vcc_lo
	v_cndmask_b32_e64 v31, -v31, v31, vcc_lo
	v_cndmask_b32_e64 v33, -v33, v33, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	v_add_f32_e32 v28, v30, v31
	v_and_b32_e32 v30, 0x3df, v2
	v_cndmask_b32_e64 v23, -v23, v23, vcc_lo
	v_cndmask_b32_e64 v24, -v24, v24, vcc_lo
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v29, v32, v33 :: v_dual_add_f32 v22, v22, v23
	v_dual_add_f32 v23, v25, v24 :: v_dual_add_f32 v20, v20, v21
	v_lshlrev_b32_e32 v21, 2, v30
	s_delay_alu instid0(VALU_DEP_4)
	v_add_f32_e32 v3, v34, v3
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v28
	ds_store_b32 v14, v29
	ds_store_b32 v16, v22
	ds_store_b32 v17, v23
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 32, v2
	v_and_b32_e32 v24, 0x7df, v5
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b32_e32 v24, 2, v24
	v_or_b32_e32 v3, 32, v5
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7df, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 32, v6
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v24, 0x7df, v7
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 32, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x7df, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 32, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x7df, v8
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 32, v8
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7df, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 32, v9
	v_dual_cndmask_b32 v37, -1, v20 :: v_dual_and_b32 v24, 0x7df, v10
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 32, v10
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	v_and_b32_e32 v22, 32, v2
	ds_load_b32 v23, v35
	ds_load_b32 v24, v37
	ds_load_b32 v3, v3
	ds_load_b32 v21, v21
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	ds_load_b32 v22, v34
	ds_load_b32 v25, v36
	ds_load_b32 v34, v38
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	v_cndmask_b32_e64 v29, -v29, v29, vcc_lo
	v_cndmask_b32_e64 v31, -v31, v31, vcc_lo
	v_cndmask_b32_e64 v33, -v33, v33, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	v_add_f32_e32 v28, v30, v31
	v_and_b32_e32 v30, 0x3bf, v2
	v_cndmask_b32_e64 v23, -v23, v23, vcc_lo
	v_cndmask_b32_e64 v24, -v24, v24, vcc_lo
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v29, v32, v33 :: v_dual_add_f32 v22, v22, v23
	v_dual_add_f32 v23, v25, v24 :: v_dual_add_f32 v20, v20, v21
	v_lshlrev_b32_e32 v21, 2, v30
	s_delay_alu instid0(VALU_DEP_4)
	v_add_f32_e32 v3, v34, v3
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v28
	ds_store_b32 v14, v29
	ds_store_b32 v16, v22
	ds_store_b32 v17, v23
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 64, v2
	v_and_b32_e32 v24, 0x7bf, v5
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b32_e32 v24, 2, v24
	v_or_b32_e32 v3, 64, v5
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7bf, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 64, v6
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v24, 0x7bf, v7
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 64, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x7bf, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 64, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x7bf, v8
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 64, v8
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x7bf, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 64, v9
	v_dual_cndmask_b32 v37, -1, v20 :: v_dual_and_b32 v24, 0x7bf, v10
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 64, v10
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	v_and_b32_e32 v22, 64, v2
	ds_load_b32 v23, v35
	ds_load_b32 v24, v37
	ds_load_b32 v3, v3
	ds_load_b32 v21, v21
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	ds_load_b32 v22, v34
	ds_load_b32 v25, v36
	ds_load_b32 v34, v38
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	v_cndmask_b32_e64 v29, -v29, v29, vcc_lo
	v_cndmask_b32_e64 v31, -v31, v31, vcc_lo
	v_cndmask_b32_e64 v33, -v33, v33, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	v_add_f32_e32 v28, v30, v31
	v_and_b32_e32 v30, 0x37f, v2
	v_cndmask_b32_e64 v23, -v23, v23, vcc_lo
	v_cndmask_b32_e64 v24, -v24, v24, vcc_lo
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_add_f32 v29, v32, v33 :: v_dual_add_f32 v22, v22, v23
	v_dual_add_f32 v23, v25, v24 :: v_dual_add_f32 v20, v20, v21
	v_lshlrev_b32_e32 v21, 2, v30
	s_delay_alu instid0(VALU_DEP_4)
	v_add_f32_e32 v3, v34, v3
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v28
	ds_store_b32 v14, v29
	ds_store_b32 v16, v22
	ds_store_b32 v17, v23
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 0x80, v2
	v_and_b32_e32 v24, 0x77f, v5
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b32_e32 v24, 2, v24
	v_or_b32_e32 v3, 0x80, v5
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x77f, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 0x80, v6
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v24, 0x77f, v7
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 0x80, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x77f, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 0x80, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x77f, v8
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 0x80, v8
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x77f, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 0x80, v9
	v_dual_cndmask_b32 v37, -1, v20 :: v_dual_and_b32 v24, 0x77f, v10
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 0x80, v10
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	v_and_b32_e32 v22, 0x80, v2
	ds_load_b32 v23, v34
	ds_load_b32 v24, v35
	ds_load_b32 v25, v36
	ds_load_b32 v34, v37
	ds_load_b32 v35, v38
	ds_load_b32 v3, v3
	ds_load_b32 v20, v20
	ds_load_b32 v21, v21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	v_and_b32_e32 v22, 0x80, v7
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	v_cndmask_b32_e64 v29, v29, -v29, vcc_lo
	v_cndmask_b32_e64 v31, -v31, v31, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e64 s0, 0, v22
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	s_delay_alu instid0(VALU_DEP_3)
	v_dual_add_f32 v29, v30, v31 :: v_dual_and_b32 v30, 0x80, v10
	v_and_b32_e32 v28, 0x80, v8
	v_cndmask_b32_e64 v24, -v24, v24, vcc_lo
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	v_cndmask_b32_e64 v22, -v33, v33, s0
	v_cmp_eq_u32_e32 vcc_lo, 0, v30
	v_cmp_eq_u32_e64 s0, 0, v28
	v_dual_add_f32 v23, v23, v24 :: v_dual_and_b32 v30, 0x2ff, v2
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_f32_e32 v22, v32, v22
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	v_cndmask_b32_e64 v28, -v34, v34, s0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_add_f32 v3, v35, v3 :: v_dual_add_f32 v20, v20, v21
	v_dual_add_f32 v24, v25, v28 :: v_dual_lshlrev_b32 v21, 2, v30
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v29
	ds_store_b32 v14, v22
	ds_store_b32 v16, v23
	ds_store_b32 v17, v24
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 0x100, v2
	v_and_b32_e32 v24, 0x6ff, v5
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b32_e32 v24, 2, v24
	v_or_b32_e32 v3, 0x100, v5
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e32 v26, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x6ff, v6
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 0x100, v6
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v24, 0x6ff, v7
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 0x100, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v30, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x6ff, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 0x100, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x6ff, v8
	ds_load_b32 v26, v26
	ds_load_b32 v27, v27
	ds_load_b32 v28, v28
	ds_load_b32 v29, v29
	ds_load_b32 v30, v30
	ds_load_b32 v31, v31
	ds_load_b32 v32, v24
	ds_load_b32 v33, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 0x100, v8
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x6ff, v9
	v_cndmask_b32_e32 v35, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 0x100, v9
	v_dual_cndmask_b32 v37, -1, v20 :: v_dual_and_b32 v24, 0x6ff, v10
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 0x100, v10
	v_lshlrev_b32_e32 v24, 2, v24
	v_cndmask_b32_e32 v38, -1, v22, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_cndmask_b32_e32 v20, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v21, -1, v22, vcc_lo
	ds_load_b32 v22, v34
	ds_load_b32 v23, v35
	ds_load_b32 v24, v36
	ds_load_b32 v25, v37
	ds_load_b32 v34, v38
	ds_load_b32 v3, v3
	ds_load_b32 v20, v20
	ds_load_b32 v21, v21
	v_and_b32_e32 v35, 0x100, v2
	v_and_b32_e32 v36, 0x100, v5
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmp_eq_u32_e32 vcc_lo, 0, v35
	v_cmp_eq_u32_e64 s0, 0, v36
	v_and_b32_e32 v35, 0x100, v7
	v_cndmask_b32_e64 v27, -v27, v27, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cndmask_b32_e64 v29, -v29, v29, s0
	v_cndmask_b32_e64 v31, v31, -v31, vcc_lo
	v_cmp_eq_u32_e64 s0, 0, v35
	v_cndmask_b32_e64 v23, -v23, v23, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_dual_add_f32 v26, v26, v27 :: v_dual_add_f32 v27, v28, v29
	v_and_b32_e32 v29, 0x100, v8
	v_cndmask_b32_e64 v33, -v33, v33, s0
	v_dual_add_f32 v28, v30, v31 :: v_dual_and_b32 v31, 0x100, v9
	v_add_f32_e32 v22, v22, v23
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cmp_eq_u32_e32 vcc_lo, 0, v29
	v_add_f32_e32 v30, v32, v33
	v_and_b32_e32 v32, 0x100, v10
	v_and_b32_e32 v29, 0x1ff, v2
	v_cndmask_b32_e64 v25, -v25, v25, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_add_f32_e32 v23, v24, v25
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v32
	v_dual_add_f32 v3, v34, v3 :: v_dual_and_b32 v24, 0x5ff, v5
	v_cndmask_b32_e64 v21, -v21, v21, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v24, 2, v24
	v_add_f32_e32 v20, v20, v21
	v_lshlrev_b32_e32 v21, 2, v29
	ds_store_b32 v11, v26
	ds_store_b32 v12, v27
	ds_store_b32 v13, v28
	ds_store_b32 v14, v30
	ds_store_b32 v16, v22
	ds_store_b32 v17, v23
	ds_store_b32 v18, v3
	ds_store_b32 v19, v20
	v_or_b32_e32 v3, 0x200, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	v_add_co_u32 v20, vcc_lo, v0, v21
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_or_b32_e32 v3, 0x200, v5
	buffer_gl0_inv
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_dual_cndmask_b32 v26, -1, v20 :: v_dual_and_b32 v5, 0x200, v5
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x5ff, v6
	v_cmp_eq_u32_e64 s0, 0, v5
	v_cndmask_b32_e32 v27, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v28, -1, v22, vcc_lo
	v_lshlrev_b32_e32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 0x200, v6
	v_and_b32_e32 v24, 0x5ff, v7
	v_dual_cndmask_b32 v29, -1, v20 :: v_dual_and_b32 v6, 0x200, v6
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 0x200, v7
	v_lshlrev_b32_e32 v24, 2, v24
	v_dual_cndmask_b32 v30, -1, v22 :: v_dual_and_b32 v7, 0x200, v7
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	v_add_co_u32 v24, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v25, null, 0, v1, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v23, null, v1, v23, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_and_b32_e32 v3, 0x5ff, v15
	v_cndmask_b32_e32 v31, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[24:25]
	v_lshlrev_b32_e32 v20, 2, v3
	v_or_b32_e32 v3, 0x200, v15
	v_cndmask_b32_e32 v24, -1, v24, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v25, -1, v22, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, 0, v1, vcc_lo
	v_lshlrev_b64 v[22:23], 2, v[3:4]
	v_and_b32_e32 v3, 0x5ff, v8
	ds_load_b32 v15, v26
	ds_load_b32 v26, v27
	ds_load_b32 v27, v28
	ds_load_b32 v28, v29
	ds_load_b32 v29, v30
	ds_load_b32 v30, v31
	ds_load_b32 v31, v24
	ds_load_b32 v32, v25
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b32_e32 v24, 2, v3
	v_or_b32_e32 v3, 0x200, v8
	v_and_b32_e32 v8, 0x200, v8
	v_cndmask_b32_e32 v33, -1, v20, vcc_lo
	v_add_co_u32 v20, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v21, null, v1, v23, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v24
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_lshlrev_b64 v[24:25], 2, v[3:4]
	v_and_b32_e32 v3, 0x5ff, v9
	s_waitcnt lgkmcnt(4)
	v_cndmask_b32_e64 v5, -v28, v28, s0
	v_cmp_eq_u32_e64 s0, 0, v6
	v_cndmask_b32_e32 v34, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	s_delay_alu instid0(VALU_DEP_4)
	v_add_f32_e32 v5, v27, v5
	s_waitcnt lgkmcnt(2)
	v_cndmask_b32_e64 v6, -v30, v30, s0
	v_cmp_eq_u32_e64 s0, 0, v7
	v_dual_cndmask_b32 v35, -1, v22 :: v_dual_lshlrev_b32 v22, 2, v3
	v_add_co_u32 v20, vcc_lo, v0, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v21, null, v1, v25, vcc_lo
	v_add_co_u32 v22, vcc_lo, v0, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_or_b32_e32 v3, 0x200, v9
	v_and_b32_e32 v24, 0x5ff, v10
	v_and_b32_e32 v9, 0x200, v9
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v7, -v32, v32, s0
	v_dual_add_f32 v6, v29, v6 :: v_dual_cndmask_b32 v25, -1, v20
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_lshlrev_b64 v[20:21], 2, v[3:4]
	v_or_b32_e32 v3, 0x200, v10
	v_dual_add_f32 v7, v31, v7 :: v_dual_and_b32 v10, 0x200, v10
	v_cndmask_b32_e32 v36, -1, v22, vcc_lo
	v_lshlrev_b32_e32 v22, 2, v24
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 2, v[3:4]
	v_add_co_u32 v20, vcc_lo, v0, v20
	v_add_co_ci_u32_e64 v21, null, v1, v21, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, v0, v22
	v_add_co_ci_u32_e64 v23, null, 0, v1, vcc_lo
	v_add_co_u32 v0, vcc_lo, v0, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, v1, v4, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[20:21]
	v_cndmask_b32_e32 v3, -1, v20, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[22:23]
	v_cndmask_b32_e32 v4, -1, v22, vcc_lo
	v_cmp_ne_u64_e32 vcc_lo, 0, v[0:1]
	v_cndmask_b32_e32 v0, -1, v0, vcc_lo
	ds_load_b32 v1, v33
	ds_load_b32 v20, v34
	ds_load_b32 v21, v35
	ds_load_b32 v22, v25
	ds_load_b32 v23, v36
	ds_load_b32 v3, v3
	ds_load_b32 v4, v4
	ds_load_b32 v0, v0
	v_cmp_gt_u32_e32 vcc_lo, 0x200, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v2, -v26, v26, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_add_f32_e32 v2, v15, v2
	v_cndmask_b32_e64 v15, v20, -v20, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v8
	v_add_f32_e32 v1, v1, v15
	v_cndmask_b32_e64 v8, -v22, v22, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_add_f32_e32 v8, v21, v8
	v_cndmask_b32_e64 v3, -v3, v3, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v10
	v_add_f32_e32 v3, v23, v3
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v4, v0
	ds_store_b32 v11, v2
	ds_store_b32 v12, v5
	ds_store_b32 v13, v6
	ds_store_b32 v14, v7
	ds_store_b32 v16, v1
	ds_store_b32 v17, v8
	ds_store_b32 v18, v3
	ds_store_b32 v19, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v11
	ds_load_b32 v1, v12
	ds_load_b32 v2, v13
	ds_load_b32 v3, v14
	ds_load_b32 v4, v16
	ds_load_b32 v5, v17
	ds_load_b32 v6, v18
	ds_load_b32 v7, v19
	s_waitcnt lgkmcnt(6)
	v_dual_mul_f32 v0, 0x3d000000, v0 :: v_dual_mul_f32 v1, 0x3d000000, v1
	s_waitcnt lgkmcnt(4)
	v_dual_mul_f32 v2, 0x3d000000, v2 :: v_dual_mul_f32 v3, 0x3d000000, v3
	s_waitcnt lgkmcnt(2)
	v_dual_mul_f32 v4, 0x3d000000, v4 :: v_dual_mul_f32 v5, 0x3d000000, v5
	s_waitcnt lgkmcnt(0)
	v_dual_mul_f32 v6, 0x3d000000, v6 :: v_dual_mul_f32 v7, 0x3d000000, v7
	ds_store_b32 v11, v0
	ds_store_b32 v12, v1
	ds_store_b32 v13, v2
	ds_store_b32 v14, v3
	ds_store_b32 v16, v4
	ds_store_b32 v17, v5
	ds_store_b32 v18, v6
	ds_store_b32 v19, v7
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_setpc_b64 s[30:31]
.Lfunc_end0:
	.size	_Z13transform1024Pfi, .Lfunc_end0-_Z13transform1024Pfi
                                        ; -- End function
	.set .L_Z13transform1024Pfi.num_vgpr, 39
	.set .L_Z13transform1024Pfi.num_agpr, 0
	.set .L_Z13transform1024Pfi.numbered_sgpr, 32
	.set .L_Z13transform1024Pfi.num_named_barrier, 0
	.set .L_Z13transform1024Pfi.private_seg_size, 0
	.set .L_Z13transform1024Pfi.uses_vcc, 1
	.set .L_Z13transform1024Pfi.uses_flat_scratch, 0
	.set .L_Z13transform1024Pfi.has_dyn_sized_stack, 0
	.set .L_Z13transform1024Pfi.has_recursion, 0
	.set .L_Z13transform1024Pfi.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Function info:
; codeLenInByte = 10872
; TotalNumSgprs: 34
; NumVgprs: 39
; ScratchSize: 0
; MemoryBound: 0
	.section	.text._Z4quipILi0EEvPKfPfPKhPKj,"axG",@progbits,_Z4quipILi0EEvPKfPfPKhPKj,comdat
	.protected	_Z4quipILi0EEvPKfPfPKhPKj ; -- Begin function _Z4quipILi0EEvPKfPfPKhPKj
	.globl	_Z4quipILi0EEvPKfPfPKhPKj
	.p2align	8
	.type	_Z4quipILi0EEvPKfPfPKhPKj,@function
_Z4quipILi0EEvPKfPfPKhPKj:              ; @_Z4quipILi0EEvPKfPfPKhPKj
; %bb.0:
	s_clause 0x1
	s_load_b64 s[8:9], s[0:1], 0x10
	s_load_b128 s[4:7], s[0:1], 0x0
	v_mov_b32_e32 v39, v0
	s_lshl_b32 s3, s2, 10
	s_mov_b64 s[10:11], src_shared_base
	s_ashr_i32 s0, s3, 31
	s_mov_b32 s32, 0
	v_or_b32_e32 v0, s3, v39
	v_add_nc_u32_e32 v4, 0x80, v39
	v_lshrrev_b32_e32 v5, 3, v39
	v_add_nc_u32_e32 v7, 0x100, v39
	v_add_nc_u32_e32 v18, 0x380, v39
	v_ashrrev_i32_e32 v1, 31, v0
	s_mov_b32 s3, 0
	v_mov_b32_e32 v43, 0
	v_lshrrev_b32_e32 v9, 3, v7
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[2:3], 2, v[0:1]
	v_mov_b32_e32 v1, s0
	v_lshrrev_b32_e32 v6, 3, v4
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v4, s0, s8, v5
	v_add_co_ci_u32_e64 v5, null, s9, 0, s0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	v_add_co_u32 v2, vcc_lo, s4, v2
	v_add_co_u32 v6, s0, s8, v6
	v_add_co_ci_u32_e64 v3, null, s5, v3, vcc_lo
	v_add_co_u32 v4, vcc_lo, 0xc000, v4
	v_add_co_ci_u32_e64 v8, null, s9, 0, s0
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	v_add_co_u32 v0, vcc_lo, s4, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s5, v1, vcc_lo
	v_add_co_u32 v6, vcc_lo, 0xc000, v6
	v_add_co_ci_u32_e64 v7, null, 0, v8, vcc_lo
	v_add_nc_u32_e32 v8, 0x180, v39
	v_add_co_u32 v9, s0, s8, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v10, null, s9, 0, s0
	v_lshrrev_b32_e32 v11, 3, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, 0xc000, v9
	v_add_co_ci_u32_e64 v9, null, 0, v10, vcc_lo
	v_add_nc_u32_e32 v10, 0x200, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, s0, s8, v11
	v_add_co_ci_u32_e64 v12, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshrrev_b32_e32 v13, 3, v10
	v_add_co_u32 v10, vcc_lo, 0xc000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v11, null, 0, v12, vcc_lo
	v_add_nc_u32_e32 v12, 0x280, v39
	v_add_co_u32 v13, s0, s8, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v14, null, s9, 0, s0
	v_lshrrev_b32_e32 v15, 3, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, vcc_lo, 0xc000, v13
	v_add_co_ci_u32_e64 v13, null, 0, v14, vcc_lo
	v_add_nc_u32_e32 v14, 0x300, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_u32 v15, s0, s8, v15
	global_load_u8 v20, v[4:5], off
	v_add_co_ci_u32_e64 v16, null, s9, 0, s0
	v_lshrrev_b32_e32 v17, 3, v14
	v_add_co_u32 v14, vcc_lo, 0xc000, v15
	v_add_co_ci_u32_e64 v15, null, 0, v16, vcc_lo
	v_lshrrev_b32_e32 v16, 3, v18
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v17, s0, s8, v17
	v_add_co_ci_u32_e64 v18, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v19, s0, s8, v16
	v_add_co_ci_u32_e64 v21, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v16, vcc_lo, 0xc000, v17
	v_add_co_ci_u32_e64 v17, null, 0, v18, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v18, vcc_lo, 0xc000, v19
	v_add_co_ci_u32_e64 v19, null, 0, v21, vcc_lo
	s_clause 0x6
	global_load_u8 v6, v[6:7], off
	global_load_u8 v7, v[8:9], off
	global_load_u8 v8, v[10:11], off
	global_load_u8 v9, v[12:13], off
	global_load_u8 v10, v[14:15], off
	global_load_u8 v11, v[16:17], off
	global_load_u8 v12, v[18:19], off
	s_clause 0x7
	global_load_b32 v2, v[2:3], off
	global_load_b32 v3, v[0:1], off offset:512
	global_load_b32 v13, v[0:1], off offset:1024
	global_load_b32 v14, v[0:1], off offset:1536
	global_load_b32 v15, v[0:1], off offset:2048
	global_load_b32 v16, v[0:1], off offset:2560
	global_load_b32 v17, v[0:1], off offset:3072
	global_load_b32 v0, v[0:1], off offset:3584
	global_load_d16_u8 v40, v[4:5], off offset:128
	v_and_b32_e32 v1, 7, v39
	s_add_u32 s4, s8, 0xc092
	s_addc_u32 s5, s9, 0
	s_getpc_b64 s[0:1]
	s_add_u32 s0, s0, _Z13transform1024Pfi@rel32@lo+4
	s_addc_u32 s1, s1, _Z13transform1024Pfi@rel32@hi+12
	v_lshlrev_b32_e64 v41, v1, 1
	s_waitcnt vmcnt(16)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_and_b32_e32 v1, v41, v20
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_waitcnt vmcnt(15)
	v_and_b32_e32 v4, v41, v6
	s_waitcnt vmcnt(14)
	v_and_b32_e32 v5, v41, v7
	s_waitcnt vmcnt(13)
	v_and_b32_e32 v6, v41, v8
	s_waitcnt vmcnt(12)
	v_and_b32_e32 v7, v41, v9
	s_waitcnt vmcnt(11)
	v_and_b32_e32 v8, v41, v10
	s_waitcnt vmcnt(10)
	v_and_b32_e32 v9, v41, v11
	s_waitcnt vmcnt(9)
	v_and_b32_e32 v10, v41, v12
	s_waitcnt vmcnt(8)
	v_cndmask_b32_e64 v1, -v2, v2, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v4
	v_lshlrev_b32_e32 v42, 2, v39
	s_waitcnt vmcnt(7)
	v_cndmask_b32_e64 v2, -v3, v3, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v5
	s_waitcnt vmcnt(6)
	v_cndmask_b32_e64 v3, -v13, v13, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v6
	s_waitcnt vmcnt(5)
	v_cndmask_b32_e64 v4, -v14, v14, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v7
	s_waitcnt vmcnt(4)
	v_cndmask_b32_e64 v5, -v15, v15, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v8
	s_waitcnt vmcnt(3)
	v_cndmask_b32_e64 v6, -v16, v16, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v9
	s_waitcnt vmcnt(2)
	v_cndmask_b32_e64 v7, -v17, v17, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v10
	s_waitcnt vmcnt(1)
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	ds_store_2addr_stride64_b32 v42, v1, v2 offset1:2
	ds_store_2addr_stride64_b32 v42, v3, v4 offset0:4 offset1:6
	ds_store_2addr_stride64_b32 v42, v5, v6 offset0:8 offset1:10
	ds_store_2addr_stride64_b32 v42, v7, v0 offset0:12 offset1:14
	v_dual_mov_b32 v0, 0 :: v_dual_mov_b32 v1, s11
	v_mov_b32_e32 v2, v39
	s_waitcnt vmcnt(0) lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_swappc_b64 s[30:31], s[0:1]
	v_dual_mov_b32 v13, 0x3e800000 :: v_dual_lshlrev_b32 v0, 7, v39
	v_lshlrev_b32_e32 v2, 8, v39
	v_mov_b32_e32 v10, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, s0, s8, v0
	v_add_co_ci_u32_e64 v1, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_u32 v8, s0, s8, v2
	v_add_co_u32 v11, vcc_lo, 0x8000, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, 0, v1, vcc_lo
	v_add_co_ci_u32_e64 v9, null, s9, 0, s0
	s_mov_b64 s[0:1], 0
	s_branch .LBB1_3
.LBB1_1:                                ; %Flow
                                        ;   in Loop: Header=BB1_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s11
.LBB1_2:                                ;   in Loop: Header=BB1_3 Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt vmcnt(0)
	v_bfe_u32 v18, v15, 16, 4
	v_and_b32_e32 v17, 15, v15
	v_bfe_u32 v20, v15, 4, 4
	v_bfe_u32 v21, v15, 20, 4
	s_add_u32 s0, s0, 1
	v_add_nc_u32_e32 v18, -8, v18
	s_addc_u32 s1, s1, 0
	v_add_nc_u32_e32 v20, -8, v20
	s_add_i32 s3, s3, 32
	s_cmpk_eq_i32 s0, 0x80
	v_cvt_f32_i32_e32 v18, v18
	v_add_nc_u32_e32 v17, -8, v17
	v_cvt_f32_i32_e32 v20, v20
	v_and_b32_e32 v19, 16, v14
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f32_e32 v18, 0.5, v18
	v_cvt_f32_i32_e32 v17, v17
	v_and_b32_e32 v16, 0xff, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_mul_f32 v20, 0.5, v20 :: v_dual_mul_f32 v17, 0.5, v17
	v_bcnt_u32_b32 v16, v16, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_xor_b32_e32 v22, v16, v14
	v_and_b32_e32 v16, 1, v16
	v_and_b32_e32 v22, 1, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v16
	v_cndmask_b32_e32 v16, 0xbe800000, v13, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	v_cndmask_b32_e64 v17, -v17, v17, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_f32_e32 v17, v16, v17
	v_cndmask_b32_e64 v18, -v18, v18, vcc_lo
	v_add_nc_u32_e32 v21, -8, v21
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v43, v17, v4 :: v_dual_add_f32 v18, v16, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cvt_f32_i32_e32 v21, v21
	v_and_b32_e32 v19, 2, v14
	v_bfe_u32 v17, v15, 8, 4
	v_fmac_f32_e32 v43, v18, v5
	v_bfe_u32 v18, v15, 24, 4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	v_add_nc_u32_e32 v5, -8, v17
	v_cndmask_b32_e64 v4, -v20, v20, vcc_lo
	v_dual_mul_f32 v20, 0.5, v21 :: v_dual_and_b32 v19, 32, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f32_e32 v4, v16, v4
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v43, v4, v6
	v_cndmask_b32_e64 v17, -v20, v20, vcc_lo
	v_add_nc_u32_e32 v6, -8, v18
	v_bfe_u32 v18, v15, 12, 4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_add_f32 v4, v16, v17 :: v_dual_and_b32 v17, 4, v14
	v_fmac_f32_e32 v43, v4, v7
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_i32_e32 v4, v6
	v_cmp_eq_u32_e32 vcc_lo, 0, v17
	v_add_nc_u32_e32 v6, -8, v18
	v_lshrrev_b32_e32 v7, 28, v15
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_dual_mul_f32 v4, 0.5, v4 :: v_dual_and_b32 v15, 64, v14
	v_cvt_f32_i32_e32 v5, v5
	v_cvt_f32_i32_e32 v6, v6
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_nc_u32_e32 v7, -8, v7
	v_dual_mul_f32 v5, 0.5, v5 :: v_dual_mul_f32 v6, 0.5, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_cndmask_b32_e64 v5, -v5, v5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v15
	v_and_b32_e32 v15, 8, v14
	v_add_f32_e32 v5, v16, v5
	v_cndmask_b32_e64 v4, -v4, v4, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v15
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v43, v5, v0
	v_cvt_f32_i32_e32 v0, v7
	v_cndmask_b32_e64 v5, -v6, v6, vcc_lo
	v_and_b32_e32 v6, 0x80, v14
	v_add_f32_e32 v4, v16, v4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_mul_f32_e32 v0, 0.5, v0
	v_cmp_eq_u32_e32 vcc_lo, 0, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v43, v4, v1
	v_add_f32_e32 v1, v16, v5
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	v_add_co_u32 v8, vcc_lo, v8, 2
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v43, v1, v2
	v_add_co_ci_u32_e64 v9, null, 0, v9, vcc_lo
	v_add_f32_e32 v0, v16, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v43, v0, v3
	s_cbranch_scc1 .LBB1_8
.LBB1_3:                                ; =>This Inner Loop Header: Depth=1
	global_load_u16 v14, v[8:9], off
	v_add_co_u32 v0, vcc_lo, v11, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s1, v12, vcc_lo
	s_mov_b32 s10, exec_lo
	global_load_d16_i8 v17, v[0:1], off
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v2, 6, v14
	v_and_b32_e32 v0, 0x3fc, v2
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v16, 0xff, v17
	global_load_b32 v15, v0, s[4:5]
	v_mov_b32_e32 v0, s3
	ds_load_b128 v[4:7], v0
	ds_load_b128 v[0:3], v0 offset:16
	v_cmpx_gt_i16_e32 0, v17.l
	s_xor_b32 s10, exec_lo, s10
	s_cbranch_execz .LBB1_5
; %bb.4:                                ;   in Loop: Header=BB1_3 Depth=1
	v_and_b32_e32 v17, 1, v16
	v_and_b32_e32 v19, 4, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v17
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v17, -v4, v4, vcc_lo
	v_dual_add_f32 v17, 0, v17 :: v_dual_and_b32 v18, 2, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	v_cndmask_b32_e64 v18, -v5, v5, vcc_lo
	v_and_b32_e32 v20, 8, v16
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	v_add_f32_e32 v17, v17, v18
	v_cndmask_b32_e64 v19, -v6, v6, vcc_lo
	v_and_b32_e32 v18, 16, v16
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_f32_e32 v17, v17, v19
	v_and_b32_e32 v19, 32, v16
	v_cndmask_b32_e64 v20, -v7, v7, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	v_add_f32_e32 v17, v17, v20
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v18, -v0, v0, vcc_lo
	v_and_b32_e32 v20, 0x7f, v16
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_f32_e32 v17, v17, v18
	v_bcnt_u32_b32 v18, v20, 0
	v_cndmask_b32_e64 v19, -v1, v1, vcc_lo
	v_and_b32_e32 v16, 64, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_add_f32 v17, v17, v19 :: v_dual_and_b32 v18, 1, v18
	v_cmp_eq_u32_e32 vcc_lo, 0, v16
	v_cndmask_b32_e64 v16, -v2, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	v_add_f32_e32 v16, v17, v16
	v_cndmask_b32_e64 v17, -v3, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v16, v16, v17
                                        ; implicit-def: $vgpr17_lo16
	v_fmac_f32_e32 v10, 0.5, v16
                                        ; implicit-def: $vgpr16
.LBB1_5:                                ; %Flow153
                                        ;   in Loop: Header=BB1_3 Depth=1
	s_and_not1_saveexec_b32 s10, s10
	s_cbranch_execz .LBB1_2
; %bb.6:                                ;   in Loop: Header=BB1_3 Depth=1
	s_mov_b32 s11, exec_lo
	v_cmpx_ne_u16_e32 0x7f, v17.l
	s_cbranch_execz .LBB1_1
; %bb.7:                                ;   in Loop: Header=BB1_3 Depth=1
	v_bfe_u32 v18, v16, 3, 3
	v_and_b32_e32 v16, 7, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshl_add_u32 v19, v18, 2, s3
	v_lshl_add_u32 v20, v16, 2, s3
	v_cmp_gt_u32_e32 vcc_lo, v16, v18
	ds_load_b32 v19, v19
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v16, v19, -v19, vcc_lo
	v_cmp_gt_u16_e32 vcc_lo, 64, v17.l
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v16, v20, v16
	v_cndmask_b32_e64 v16, -v16, v16, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v16
	s_branch .LBB1_1
.LBB1_8:
	v_div_scale_f32 v1, null, 0x40028f5c, 0x40028f5c, v10
	v_div_scale_f32 v4, vcc_lo, v10, 0x40028f5c, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v2, v1
	v_fma_f32 v3, -v1, v2, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v3, v2
	v_dual_mov_b32 v0, 0xc000 :: v_dual_mul_f32 v3, v4, v2
	global_load_d16_b16 v0, v0, s[8:9] offset:144
	v_fma_f32 v5, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v5, v2
	v_fma_f32 v1, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_div_fmas_f32 v1, v1, v2, v3
	v_and_b32_e32 v2, 0x3fe, v39
	v_or_b32_e32 v3, 0x1008, v42
	v_div_fixup_f32 v1, v1, 0x40028f5c, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_dual_add_f32 v1, v43, v1 :: v_dual_lshlrev_b32 v2, 2, v2
	s_waitcnt vmcnt(0)
	v_cvt_f32_f16_e32 v0, v0.l
	v_mul_f32_e32 v0, v1, v0
	v_or_b32_e32 v1, 0x1004, v42
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_waitcnt_vscnt null, 0x0
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v1
	ds_load_b32 v1, v2 offset:4096
	v_and_b32_e32 v2, 1, v39
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3fd, v39
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 2, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3fb, v39
	v_or_b32_e32 v3, 0x1010, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 4, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3f7, v39
	v_or_b32_e32 v3, 0x1020, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 8, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3ef, v39
	v_or_b32_e32 v3, 0x1040, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 16, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3df, v39
	v_or_b32_e32 v3, 0x1080, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 32, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3bf, v39
	v_or_b32_e32 v3, 0x1100, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 64, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_and_b32_e32 v3, v40, v41
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v3
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v42 offset:4096
	s_waitcnt lgkmcnt(0)
	v_mul_f32_e32 v0, 0x3db504f3, v0
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v42 offset:4096
	v_lshl_add_u32 v0, s2, 7, v39
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ashrrev_i32_e32 v1, 31, v0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v2, -v2, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s6, v0
	v_add_co_ci_u32_e64 v1, null, s7, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_nop 0
	s_sendmsg sendmsg(MSG_DEALLOC_VGPRS)
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z4quipILi0EEvPKfPfPKhPKj
		.amdhsa_group_segment_fixed_size 4608
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 32
		.amdhsa_user_sgpr_count 2
		.amdhsa_user_sgpr_dispatch_ptr 0
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 0
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_wavefront_size32 1
		.amdhsa_uses_dynamic_stack 0
		.amdhsa_enable_private_segment 0
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 0
		.amdhsa_system_sgpr_workgroup_id_z 0
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 0
		.amdhsa_next_free_vgpr 44
		.amdhsa_next_free_sgpr 33
		.amdhsa_reserve_vcc 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_workgroup_processor_mode 1
		.amdhsa_memory_ordered 1
		.amdhsa_forward_progress 1
		.amdhsa_shared_vgpr_count 0
		.amdhsa_inst_pref_size 24
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z4quipILi0EEvPKfPfPKhPKj,"axG",@progbits,_Z4quipILi0EEvPKfPfPKhPKj,comdat
.Lfunc_end1:
	.size	_Z4quipILi0EEvPKfPfPKhPKj, .Lfunc_end1-_Z4quipILi0EEvPKfPfPKhPKj
                                        ; -- End function
	.set _Z4quipILi0EEvPKfPfPKhPKj.num_vgpr, max(44, .L_Z13transform1024Pfi.num_vgpr)
	.set _Z4quipILi0EEvPKfPfPKhPKj.num_agpr, max(0, .L_Z13transform1024Pfi.num_agpr)
	.set _Z4quipILi0EEvPKfPfPKhPKj.numbered_sgpr, max(33, .L_Z13transform1024Pfi.numbered_sgpr)
	.set _Z4quipILi0EEvPKfPfPKhPKj.num_named_barrier, max(0, .L_Z13transform1024Pfi.num_named_barrier)
	.set _Z4quipILi0EEvPKfPfPKhPKj.private_seg_size, 0+max(.L_Z13transform1024Pfi.private_seg_size)
	.set _Z4quipILi0EEvPKfPfPKhPKj.uses_vcc, or(1, .L_Z13transform1024Pfi.uses_vcc)
	.set _Z4quipILi0EEvPKfPfPKhPKj.uses_flat_scratch, or(0, .L_Z13transform1024Pfi.uses_flat_scratch)
	.set _Z4quipILi0EEvPKfPfPKhPKj.has_dyn_sized_stack, or(0, .L_Z13transform1024Pfi.has_dyn_sized_stack)
	.set _Z4quipILi0EEvPKfPfPKhPKj.has_recursion, or(0, .L_Z13transform1024Pfi.has_recursion)
	.set _Z4quipILi0EEvPKfPfPKhPKj.has_indirect_call, or(0, .L_Z13transform1024Pfi.has_indirect_call)
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 3056
; TotalNumSgprs: 35
; NumVgprs: 44
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 4608 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 5
; NumSGPRsForWavesPerEU: 35
; NumVGPRsForWavesPerEU: 44
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z4quipILi1EEvPKfPfPKhPKj,"axG",@progbits,_Z4quipILi1EEvPKfPfPKhPKj,comdat
	.protected	_Z4quipILi1EEvPKfPfPKhPKj ; -- Begin function _Z4quipILi1EEvPKfPfPKhPKj
	.globl	_Z4quipILi1EEvPKfPfPKhPKj
	.p2align	8
	.type	_Z4quipILi1EEvPKfPfPKhPKj,@function
_Z4quipILi1EEvPKfPfPKhPKj:              ; @_Z4quipILi1EEvPKfPfPKhPKj
; %bb.0:
	s_clause 0x1
	s_load_b64 s[8:9], s[0:1], 0x10
	s_load_b128 s[4:7], s[0:1], 0x0
	v_mov_b32_e32 v39, v0
	s_lshl_b32 s3, s2, 10
	s_mov_b64 s[10:11], src_shared_base
	s_ashr_i32 s0, s3, 31
	s_mov_b32 s32, 0
	v_or_b32_e32 v0, s3, v39
	v_add_nc_u32_e32 v4, 0x80, v39
	v_lshrrev_b32_e32 v5, 3, v39
	v_add_nc_u32_e32 v7, 0x100, v39
	v_add_nc_u32_e32 v18, 0x380, v39
	v_ashrrev_i32_e32 v1, 31, v0
	s_mov_b32 s3, 0
	v_mov_b32_e32 v43, 0
	v_lshrrev_b32_e32 v9, 3, v7
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[2:3], 2, v[0:1]
	v_mov_b32_e32 v1, s0
	v_lshrrev_b32_e32 v6, 3, v4
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v4, s0, s8, v5
	v_add_co_ci_u32_e64 v5, null, s9, 0, s0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	v_add_co_u32 v2, vcc_lo, s4, v2
	v_add_co_u32 v6, s0, s8, v6
	v_add_co_ci_u32_e64 v3, null, s5, v3, vcc_lo
	v_add_co_u32 v4, vcc_lo, 0xc000, v4
	v_add_co_ci_u32_e64 v8, null, s9, 0, s0
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	v_add_co_u32 v0, vcc_lo, s4, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s5, v1, vcc_lo
	v_add_co_u32 v6, vcc_lo, 0xc000, v6
	v_add_co_ci_u32_e64 v7, null, 0, v8, vcc_lo
	v_add_nc_u32_e32 v8, 0x180, v39
	v_add_co_u32 v9, s0, s8, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v10, null, s9, 0, s0
	v_lshrrev_b32_e32 v11, 3, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, 0xc000, v9
	v_add_co_ci_u32_e64 v9, null, 0, v10, vcc_lo
	v_add_nc_u32_e32 v10, 0x200, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, s0, s8, v11
	v_add_co_ci_u32_e64 v12, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshrrev_b32_e32 v13, 3, v10
	v_add_co_u32 v10, vcc_lo, 0xc000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v11, null, 0, v12, vcc_lo
	v_add_nc_u32_e32 v12, 0x280, v39
	v_add_co_u32 v13, s0, s8, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v14, null, s9, 0, s0
	v_lshrrev_b32_e32 v15, 3, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, vcc_lo, 0xc000, v13
	v_add_co_ci_u32_e64 v13, null, 0, v14, vcc_lo
	v_add_nc_u32_e32 v14, 0x300, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_u32 v15, s0, s8, v15
	global_load_u8 v20, v[4:5], off
	v_add_co_ci_u32_e64 v16, null, s9, 0, s0
	v_lshrrev_b32_e32 v17, 3, v14
	v_add_co_u32 v14, vcc_lo, 0xc000, v15
	v_add_co_ci_u32_e64 v15, null, 0, v16, vcc_lo
	v_lshrrev_b32_e32 v16, 3, v18
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v17, s0, s8, v17
	v_add_co_ci_u32_e64 v18, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v19, s0, s8, v16
	v_add_co_ci_u32_e64 v21, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v16, vcc_lo, 0xc000, v17
	v_add_co_ci_u32_e64 v17, null, 0, v18, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v18, vcc_lo, 0xc000, v19
	v_add_co_ci_u32_e64 v19, null, 0, v21, vcc_lo
	s_clause 0x6
	global_load_u8 v6, v[6:7], off
	global_load_u8 v7, v[8:9], off
	global_load_u8 v8, v[10:11], off
	global_load_u8 v9, v[12:13], off
	global_load_u8 v10, v[14:15], off
	global_load_u8 v11, v[16:17], off
	global_load_u8 v12, v[18:19], off
	s_clause 0x7
	global_load_b32 v2, v[2:3], off
	global_load_b32 v3, v[0:1], off offset:512
	global_load_b32 v13, v[0:1], off offset:1024
	global_load_b32 v14, v[0:1], off offset:1536
	global_load_b32 v15, v[0:1], off offset:2048
	global_load_b32 v16, v[0:1], off offset:2560
	global_load_b32 v17, v[0:1], off offset:3072
	global_load_b32 v0, v[0:1], off offset:3584
	global_load_d16_u8 v40, v[4:5], off offset:128
	v_and_b32_e32 v1, 7, v39
	s_getpc_b64 s[0:1]
	s_add_u32 s0, s0, _Z13transform1024Pfi@rel32@lo+4
	s_addc_u32 s1, s1, _Z13transform1024Pfi@rel32@hi+12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e64 v41, v1, 1
	s_waitcnt vmcnt(16)
	v_and_b32_e32 v1, v41, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_waitcnt vmcnt(15)
	v_and_b32_e32 v4, v41, v6
	s_waitcnt vmcnt(14)
	v_and_b32_e32 v5, v41, v7
	s_waitcnt vmcnt(13)
	v_and_b32_e32 v6, v41, v8
	s_waitcnt vmcnt(12)
	v_and_b32_e32 v7, v41, v9
	s_waitcnt vmcnt(11)
	v_and_b32_e32 v8, v41, v10
	s_waitcnt vmcnt(10)
	v_and_b32_e32 v9, v41, v11
	s_waitcnt vmcnt(9)
	v_and_b32_e32 v10, v41, v12
	s_waitcnt vmcnt(8)
	v_cndmask_b32_e64 v1, -v2, v2, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v4
	v_lshlrev_b32_e32 v42, 2, v39
	s_waitcnt vmcnt(7)
	v_cndmask_b32_e64 v2, -v3, v3, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v5
	s_waitcnt vmcnt(6)
	v_cndmask_b32_e64 v3, -v13, v13, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v6
	s_waitcnt vmcnt(5)
	v_cndmask_b32_e64 v4, -v14, v14, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v7
	s_waitcnt vmcnt(4)
	v_cndmask_b32_e64 v5, -v15, v15, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v8
	s_waitcnt vmcnt(3)
	v_cndmask_b32_e64 v6, -v16, v16, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v9
	s_waitcnt vmcnt(2)
	v_cndmask_b32_e64 v7, -v17, v17, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v10
	s_waitcnt vmcnt(1)
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	ds_store_2addr_stride64_b32 v42, v1, v2 offset1:2
	ds_store_2addr_stride64_b32 v42, v3, v4 offset0:4 offset1:6
	ds_store_2addr_stride64_b32 v42, v5, v6 offset0:8 offset1:10
	ds_store_2addr_stride64_b32 v42, v7, v0 offset0:12 offset1:14
	v_dual_mov_b32 v0, 0 :: v_dual_mov_b32 v1, s11
	v_mov_b32_e32 v2, v39
	s_waitcnt vmcnt(0) lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_swappc_b64 s[30:31], s[0:1]
	v_dual_mov_b32 v11, 0 :: v_dual_lshlrev_b32 v0, 7, v39
	v_lshlrev_b32_e32 v2, 8, v39
	v_mov_b32_e32 v14, 0x3e800000
	s_mov_b64 s[4:5], 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, s0, s8, v0
	v_add_co_ci_u32_e64 v1, null, s9, 0, s0
	v_add_co_u32 v9, s0, s8, v2
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, vcc_lo, 0x8000, v0
	v_add_co_ci_u32_e64 v13, null, 0, v1, vcc_lo
	v_add_co_ci_u32_e64 v10, null, s9, 0, s0
	s_branch .LBB2_3
.LBB2_1:                                ; %Flow
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
.LBB2_2:                                ;   in Loop: Header=BB2_3 Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s0
	v_add_f32_e32 v0, 0, v0
	s_add_u32 s4, s4, 1
	s_addc_u32 s5, s5, 0
	s_add_i32 s3, s3, 32
	s_cmpk_eq_i32 s4, 0x80
	v_dual_add_f32 v0, v0, v1 :: v_dual_and_b32 v1, 1, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f32_e32 v0, v0, v2
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_add_f32 v0, v0, v3 :: v_dual_cndmask_b32 v1, 0xbe800000, v14
	v_add_co_u32 v9, vcc_lo, v9, 2
	v_add_co_ci_u32_e64 v10, null, 0, v10, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v0, v0, v4
	v_add_f32_e32 v0, v0, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v0, v0, v6
	v_add_f32_e32 v0, v0, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v1, v0
	v_add_f32_e32 v43, v43, v15
	s_cbranch_scc1 .LBB2_94
.LBB2_3:                                ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, v12, s4
	v_add_co_ci_u32_e64 v1, null, s5, v13, vcc_lo
	global_load_u16 v15, v[9:10], off
                                        ; implicit-def: $vgpr17
	s_mov_b32 s0, exec_lo
	global_load_d16_u8 v8, v[0:1], off
	s_waitcnt vmcnt(1)
	v_cmpx_gt_u32_e32 0xc000, v15
	s_xor_b32 s10, exec_lo, s0
	s_cbranch_execz .LBB2_75
; %bb.4:                                ;   in Loop: Header=BB2_3 Depth=1
	v_lshrrev_b32_e32 v0, 8, v15
                                        ; implicit-def: $vgpr17
	s_mov_b32 s0, exec_lo
	v_cmpx_gt_u16_e32 0xa300, v15.l
	s_xor_b32 s11, exec_lo, s0
	s_cbranch_execz .LBB2_72
; %bb.5:                                ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v2, 4
	s_mov_b32 s0, exec_lo
	v_cmpx_gt_u16_e32 0x5d00, v15.l
; %bb.6:                                ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_lt_u16_e32 vcc_lo, 0xff, v15.l
	v_cndmask_b32_e64 v1, 0, 1, vcc_lo
	v_cmp_gt_u16_e32 vcc_lo, 0x900, v15.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v1, 2, v1, vcc_lo
	v_cmp_gt_u16_e32 vcc_lo, 0x2500, v15.l
	v_cndmask_b32_e32 v2, 3, v1, vcc_lo
; %bb.7:                                ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	s_mov_b32 s0, exec_lo
                                        ; implicit-def: $vgpr1
	v_cmpx_lt_i32_e32 2, v2
	s_xor_b32 s0, exec_lo, s0
	s_cbranch_execz .LBB2_11
; %bb.8:                                ; %NodeBlock
                                        ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v1, 0xffffffa3
	s_mov_b32 s1, exec_lo
	v_cmpx_gt_i32_e32 4, v2
; %bb.9:                                ; %.fold.split.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	v_not_b32_e32 v1, 36
; %bb.10:                               ; %Flow253
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
.LBB2_11:                               ; %Flow256
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_and_not1_saveexec_b32 s0, s0
	s_cbranch_execz .LBB2_17
; %bb.12:                               ; %LeafBlock
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s1, exec_lo
                                        ; implicit-def: $vgpr1
	v_cmpx_ne_u32_e32 2, v2
	s_xor_b32 s1, exec_lo, s1
; %bb.13:                               ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_eq_u32_e32 vcc_lo, 1, v2
	v_cndmask_b32_e64 v1, 0, -1, vcc_lo
; %bb.14:                               ; %Flow254
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_and_not1_saveexec_b32 s1, s1
; %bb.15:                               ; %.fold.split45.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v1, -9
; %bb.16:                               ; %Flow255
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
.LBB2_17:                               ;   in Loop: Header=BB2_3 Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s0
	v_mov_b32_e32 v4, 1
	s_mov_b32 s0, exec_lo
	v_cmpx_lt_i32_e32 0, v2
	s_cbranch_execz .LBB2_25
; %bb.18:                               ; %NodeBlock204
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s1, exec_lo
                                        ; implicit-def: $vgpr4
	v_cmpx_lt_i32_e32 1, v2
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB2_22
; %bb.19:                               ; %LeafBlock202
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s12, exec_lo
	v_cmpx_ne_u32_e32 2, v2
	s_xor_b32 s12, exec_lo, s12
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_saveexec_b32 s12, s12
	v_mov_b32_e32 v4, 35
	s_xor_b32 exec_lo, exec_lo, s12
; %bb.20:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v4, 21
; %bb.21:                               ; %Flow250
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
.LBB2_22:                               ; %Flow251
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_and_not1_saveexec_b32 s1, s1
; %bb.23:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v4, 7
; %bb.24:                               ; %Flow252
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
.LBB2_25:                               ; %_Z7choose8jj.exit.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s0
	v_dual_mov_b32 v0, 0 :: v_dual_add_nc_u32 v1, v1, v0
	v_mov_b32_e32 v3, 0
	s_mov_b32 s0, exec_lo
	v_cmpx_ne_u32_e32 0, v2
	s_cbranch_execz .LBB2_29
; %bb.26:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v0, 0
	s_mov_b32 s1, exec_lo
	v_cmpx_ge_u32_e64 v1, v4
; %bb.27:                               ;   in Loop: Header=BB2_3 Depth=1
	v_sub_nc_u32_e32 v1, v1, v4
	v_add_nc_u32_e32 v2, -1, v2
	v_mov_b32_e32 v0, 0x80
; %bb.28:                               ; %Flow248
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_2)
	v_mov_b32_e32 v3, v2
.LBB2_29:                               ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	v_mov_b32_e32 v2, 1
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(VALU_DEP_2)
	v_cmpx_lt_i32_e32 0, v3
	s_cbranch_execz .LBB2_41
; %bb.30:                               ; %NodeBlock212
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s1, 0
	s_mov_b32 s12, 0
	s_mov_b32 s13, exec_lo
	v_cmpx_lt_i32_e32 2, v3
	s_xor_b32 s13, exec_lo, s13
	s_cbranch_execz .LBB2_34
; %bb.31:                               ; %LeafBlock210
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s12, -1
	s_mov_b32 s14, exec_lo
	v_cmpx_eq_u32_e32 3, v3
; %bb.32:                               ;   in Loop: Header=BB2_3 Depth=1
	s_xor_b32 s12, exec_lo, -1
; %bb.33:                               ; %Flow244
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s14
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s12, s12, exec_lo
.LBB2_34:                               ; %Flow243
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_and_not1_saveexec_b32 s13, s13
; %bb.35:                               ; %LeafBlock208
                                        ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_ne_u32_e32 vcc_lo, 1, v3
	s_and_not1_b32 s12, s12, exec_lo
	s_mov_b32 s1, exec_lo
	s_and_b32 s14, vcc_lo, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s12, s12, s14
; %bb.36:                               ; %Flow245
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s13
	v_mov_b32_e32 v2, 20
	s_and_saveexec_b32 s13, s12
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s12, exec_lo, s13
; %bb.37:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v2, 15
	s_and_not1_b32 s1, s1, exec_lo
; %bb.38:                               ; %Flow246
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
; %bb.39:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v2, 6
; %bb.40:                               ; %Flow247
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
.LBB2_41:                               ; %_Z7choose8jj.exit.1.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s0
	v_mov_b32_e32 v4, 0
	s_mov_b32 s0, exec_lo
	v_cmpx_ne_u32_e32 0, v3
	s_cbranch_execz .LBB2_45
; %bb.42:                               ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s1, exec_lo
	v_cmpx_ge_u32_e64 v1, v2
; %bb.43:                               ;   in Loop: Header=BB2_3 Depth=1
	v_or_b32_e32 v0, 64, v0
	v_sub_nc_u32_e32 v1, v1, v2
	v_add_nc_u32_e32 v3, -1, v3
; %bb.44:                               ; %Flow242
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b32_e32 v4, v3
.LBB2_45:                               ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	s_mov_b32 s0, 0
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_lt_i32_e32 1, v4
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execnz .LBB2_84
; %bb.46:                               ; %Flow239
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_saveexec_b32 s1, s1
	v_mov_b32_e32 v3, 10
	s_xor_b32 exec_lo, exec_lo, s1
	s_cbranch_execnz .LBB2_87
.LBB2_47:                               ; %Flow241
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	s_and_saveexec_b32 s1, s0
.LBB2_48:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v3, 5
.LBB2_49:                               ; %_Z7choose8jj.exit.2.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	v_mov_b32_e32 v2, 0
	s_mov_b32 s0, exec_lo
	v_cmpx_ne_u32_e32 0, v4
	s_cbranch_execz .LBB2_53
; %bb.50:                               ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s1, exec_lo
	v_cmpx_ge_u32_e64 v1, v3
; %bb.51:                               ;   in Loop: Header=BB2_3 Depth=1
	v_or_b32_e32 v0, 32, v0
	v_sub_nc_u32_e32 v1, v1, v3
	v_add_nc_u32_e32 v4, -1, v4
; %bb.52:                               ; %Flow238
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b32_e32 v2, v4
.LBB2_53:                               ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	s_mov_b32 s1, 0
	s_mov_b32 s0, exec_lo
                                        ; implicit-def: $vgpr4
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_lt_i32_e32 1, v2
	s_xor_b32 s0, exec_lo, s0
	s_cbranch_execnz .LBB2_88
; %bb.54:                               ; %Flow234
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_and_not1_saveexec_b32 s0, s0
	s_cbranch_execnz .LBB2_93
.LBB2_55:                               ; %Flow237
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	s_and_saveexec_b32 s0, s1
.LBB2_56:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v4, 4
.LBB2_57:                               ; %_Z7choose8jj.exit.3.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	v_mov_b32_e32 v3, 0
	v_mov_b32_e32 v5, 0
	s_mov_b32 s0, exec_lo
	v_cmpx_ne_u32_e32 0, v2
	s_cbranch_execz .LBB2_61
; %bb.58:                               ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s1, exec_lo
	v_cmpx_ge_u32_e64 v1, v4
; %bb.59:                               ;   in Loop: Header=BB2_3 Depth=1
	v_or_b32_e32 v0, 16, v0
	v_sub_nc_u32_e32 v1, v1, v4
	v_add_nc_u32_e32 v2, -1, v2
; %bb.60:                               ; %Flow233
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b32_e32 v5, v2
.LBB2_61:                               ; %_Z7choose8jj.exit.4.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_sub_co_u32 v2, s0, v5, 1
	s_xor_b32 s1, s0, -1
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB2_65
; %bb.62:                               ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_gt_u32_e32 vcc_lo, 3, v5
	s_mov_b32 s1, exec_lo
	v_cndmask_b32_e64 v3, 1, 3, vcc_lo
	v_cmp_gt_u32_e32 vcc_lo, 4, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e32 v3, 0, v3, vcc_lo
	v_cmpx_ge_u32_e64 v1, v3
; %bb.63:                               ;   in Loop: Header=BB2_3 Depth=1
	v_or_b32_e32 v0, 8, v0
	v_sub_nc_u32_e32 v1, v1, v3
	v_mov_b32_e32 v5, v2
; %bb.64:                               ; %Flow232
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b32_e32 v3, v5
.LBB2_65:                               ; %_Z7choose8jj.exit.5.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	v_mov_b32_e32 v2, 0
	v_mov_b32_e32 v4, 0
	s_mov_b32 s0, exec_lo
	v_cmpx_ne_u32_e32 0, v3
	s_cbranch_execz .LBB2_69
; %bb.66:                               ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_eq_u32_e32 vcc_lo, 1, v3
	s_mov_b32 s1, exec_lo
	v_cndmask_b32_e64 v4, 1, 2, vcc_lo
	v_cmp_gt_u32_e32 vcc_lo, 3, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e32 v4, 0, v4, vcc_lo
	v_cmpx_ge_u32_e64 v1, v4
; %bb.67:                               ;   in Loop: Header=BB2_3 Depth=1
	v_or_b32_e32 v0, 4, v0
	v_sub_nc_u32_e32 v1, v1, v4
	v_add_nc_u32_e32 v3, -1, v3
; %bb.68:                               ; %Flow231
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b32_e32 v4, v3
.LBB2_69:                               ; %_Z7choose8jj.exit.6.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	s_mov_b32 s12, exec_lo
	v_cmpx_ne_u32_e32 0, v4
	s_cbranch_execz .LBB2_71
; %bb.70:                               ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	v_cmp_ne_u32_e64 s0, 1, v4
	v_cmp_eq_u32_e64 s1, 1, v4
	v_or_b32_e32 v1, 2, v0
	s_or_b32 s0, s0, vcc_lo
	s_and_b32 vcc_lo, s1, vcc_lo
	v_cndmask_b32_e64 v2, 0, 1, s0
	s_delay_alu instid0(VALU_DEP_2)
	v_cndmask_b32_e32 v0, v1, v0, vcc_lo
.LBB2_71:                               ; %_Z7choose8jj.exit.7.i
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
	s_delay_alu instid0(VALU_DEP_1)
	v_or_b32_e32 v17, v0, v2
                                        ; implicit-def: $vgpr0
.LBB2_72:                               ; %Flow257
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_and_not1_saveexec_b32 s0, s11
	s_cbranch_execz .LBB2_74
; %bb.73:                               ;   in Loop: Header=BB2_3 Depth=1
	v_add_co_u32 v0, s1, s8, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v1, null, s9, 0, s1
	v_add_co_u32 v0, vcc_lo, 0xb000, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, 0, v1, vcc_lo
	global_load_u8 v17, v[0:1], off offset:4079
.LBB2_74:                               ; %Flow258
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
.LBB2_75:                               ; %Flow259
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_saveexec_b32 s0, s10
	v_mov_b32_e32 v18, 0
	s_xor_b32 exec_lo, exec_lo, s0
	s_cbranch_execz .LBB2_77
; %bb.76:                               ;   in Loop: Header=BB2_3 Depth=1
	v_bfe_u32 v0, v15, 11, 3
	v_bfe_u32 v1, v15, 8, 3
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e64 v2, v0, 1
	v_cmp_ne_u32_e32 vcc_lo, v1, v0
	v_lshlrev_b32_e64 v18, v1, 1
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_3)
	v_cndmask_b32_e32 v17, 0, v2, vcc_lo
.LBB2_77:                               ; %_Z5masksjPKhRj.exit
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	v_dual_mov_b32 v4, s3 :: v_dual_and_b32 v5, 0xff, v15
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v19, 1, v17
	v_and_b32_e32 v21, 16, v17
	v_and_b32_e32 v22, 16, v15
	ds_load_b128 v[0:3], v4
	v_bcnt_u32_b32 v16, v5, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	v_and_b32_e32 v23, 1, v18
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_xor_b32_e32 v5, v16, v15
	v_cndmask_b32_e64 v19, 0x3fc00000, 0.5, vcc_lo
	v_and_b32_e32 v20, 1, v5
	ds_load_b128 v[4:7], v4 offset:16
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v20, -v0, v0, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fma_f32 v19, v19, v20, 0
	v_cndmask_b32_e64 v21, 0x3fc00000, 0.5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	v_fma_f32 v20, 2.0, v20, v19
	v_cndmask_b32_e64 v22, -v1, v1, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v23
	v_and_b32_e32 v23, 16, v18
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_cndmask_b32 v19, v20, v19 :: v_dual_and_b32 v20, 2, v17
	v_fmac_f32_e32 v19, v21, v22
	v_and_b32_e32 v21, 2, v15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	v_fma_f32 v22, 2.0, v22, v19
	v_cndmask_b32_e64 v20, 0x3fc00000, 0.5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v21
	v_cndmask_b32_e64 v21, -v2, v2, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v23
	v_and_b32_e32 v23, 2, v18
	v_cndmask_b32_e32 v19, v22, v19, vcc_lo
	v_dual_fmac_f32 v19, v20, v21 :: v_dual_and_b32 v22, 32, v15
	v_and_b32_e32 v20, 32, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v21, 2.0, v21, v19
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	v_cndmask_b32_e64 v20, 0x3fc00000, 0.5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	v_cndmask_b32_e64 v22, -v3, v3, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v23
	v_and_b32_e32 v23, 32, v18
	v_cndmask_b32_e32 v19, v21, v19, vcc_lo
	v_and_b32_e32 v21, 4, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v19, v20, v22 :: v_dual_and_b32 v20, 4, v17
	v_fma_f32 v22, 2.0, v22, v19
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	v_cndmask_b32_e64 v20, 0x3fc00000, 0.5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v21
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v21, -v4, v4, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v23
	v_and_b32_e32 v23, 4, v18
	v_cndmask_b32_e32 v19, v22, v19, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v19, v20, v21 :: v_dual_and_b32 v22, 64, v15
	v_and_b32_e32 v20, 64, v17
	v_fma_f32 v21, 2.0, v21, v19
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	v_cndmask_b32_e64 v20, 0x3fc00000, 0.5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	v_cndmask_b32_e64 v22, -v5, v5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v23
	v_and_b32_e32 v23, 64, v18
	v_cndmask_b32_e32 v19, v21, v19, vcc_lo
	v_and_b32_e32 v21, 8, v15
	v_and_b32_e32 v15, 0x80, v15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v19, v20, v22 :: v_dual_and_b32 v20, 8, v17
	v_fma_f32 v22, 2.0, v22, v19
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	v_cndmask_b32_e64 v20, 0x3fc00000, 0.5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v21
	v_cndmask_b32_e64 v21, -v6, v6, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v23
	v_dual_cndmask_b32 v22, v22, v19 :: v_dual_and_b32 v19, 0x80, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v22, v20, v21
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	v_and_b32_e32 v20, 8, v18
	s_delay_alu instid0(VALU_DEP_3)
	v_fma_f32 v21, 2.0, v21, v22
	v_cndmask_b32_e64 v23, 0x3fc00000, 0.5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e64 v19, -v7, v7, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	v_bcnt_u32_b32 v20, v17, 0
	v_cndmask_b32_e32 v15, v21, v22, vcc_lo
	v_and_b32_e32 v21, 0x80, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v15, v23, v19 :: v_dual_and_b32 v20, 1, v20
	v_cmp_eq_u32_e32 vcc_lo, 0, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v22, 2.0, v19, v15
	v_cndmask_b32_e32 v15, v22, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_4)
	v_cmpx_eq_u32_e32 1, v20
	s_cbranch_execz .LBB2_79
; %bb.78:                               ;   in Loop: Header=BB2_3 Depth=1
	v_lshrrev_b32_e32 v17, 6, v17
	v_lshrrev_b32_e32 v18, 5, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_b32_e32 v17, 2, v17
	v_and_b32_e32 v18, 4, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_or3_b32 v17, v18, v17, 1
	v_cvt_f32_ubyte0_e32 v17, v17
	s_delay_alu instid0(VALU_DEP_1)
	v_fma_f32 v15, -v19, v17, v15
.LBB2_79:                               ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s0
	v_bfe_i32 v17, v8, 0, 8
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mov_b16_e32 v18.l, v17.l
	v_and_b32_e32 v17, 0xff, v8
	v_cmpx_gt_i16_e32 0, v18.l
	s_xor_b32 s0, exec_lo, s0
	s_cbranch_execz .LBB2_81
; %bb.80:                               ;   in Loop: Header=BB2_3 Depth=1
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_dual_mov_b32 v8, s3 :: v_dual_and_b32 v21, 2, v17
	ds_load_b96 v[18:20], v8
	v_and_b32_e32 v8, 1, v17
	v_cmp_eq_u32_e32 vcc_lo, 0, v8
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v8, -v18, v18, vcc_lo
	v_and_b32_e32 v18, 4, v17
	v_cmp_eq_u32_e32 vcc_lo, 0, v21
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_dual_add_f32 v8, 0, v8 :: v_dual_and_b32 v21, 8, v17
	v_cndmask_b32_e64 v19, -v19, v19, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_dual_add_f32 v8, v8, v19 :: v_dual_and_b32 v19, 16, v17
	v_cndmask_b32_e64 v18, -v20, v20, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v21
	v_add_f32_e32 v8, v8, v18
	v_cndmask_b32_e64 v20, -v3, v3, vcc_lo
	v_and_b32_e32 v18, 32, v17
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_f32_e32 v8, v8, v20
	v_and_b32_e32 v20, 0x7f, v17
	v_cndmask_b32_e64 v19, -v4, v4, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	v_dual_add_f32 v8, v8, v19 :: v_dual_and_b32 v17, 64, v17
	v_cndmask_b32_e64 v18, -v5, v5, vcc_lo
	v_bcnt_u32_b32 v19, v20, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v17
	v_add_f32_e32 v8, v8, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_and_b32_e32 v18, 1, v19
	v_cndmask_b32_e64 v17, -v6, v6, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v8, v8, v17
	v_cndmask_b32_e64 v17, -v7, v7, vcc_lo
	v_add_f32_e32 v8, v8, v17
                                        ; implicit-def: $vgpr17
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v11, 0.5, v8
                                        ; implicit-def: $vgpr8_lo16
.LBB2_81:                               ; %Flow230
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_and_not1_saveexec_b32 s0, s0
	s_cbranch_execz .LBB2_2
; %bb.82:                               ;   in Loop: Header=BB2_3 Depth=1
	v_and_b16 v8.l, 0xff, v8.l
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u16_e32 0x7f, v8.l
	s_cbranch_execz .LBB2_1
; %bb.83:                               ;   in Loop: Header=BB2_3 Depth=1
	v_bfe_u32 v18, v17, 3, 3
	v_and_b32_e32 v17, 7, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshl_add_u32 v19, v18, 2, s3
	v_lshl_add_u32 v20, v17, 2, s3
	v_cmp_gt_u32_e32 vcc_lo, v17, v18
	ds_load_b32 v19, v19
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v17, v19, -v19, vcc_lo
	v_cmp_gt_u16_e32 vcc_lo, 64, v8.l
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v17, v20, v17
	v_cndmask_b32_e64 v8, -v17, v17, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v11, v11, v8
	s_branch .LBB2_1
.LBB2_84:                               ; %LeafBlock218
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s0, -1
	s_mov_b32 s12, exec_lo
	v_cmpx_gt_i32_e32 4, v4
; %bb.85:                               ;   in Loop: Header=BB2_3 Depth=1
	s_xor_b32 s0, exec_lo, -1
; %bb.86:                               ; %Flow240
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s0, s0, exec_lo
	s_or_saveexec_b32 s1, s1
	v_mov_b32_e32 v3, 10
	s_xor_b32 exec_lo, exec_lo, s1
	s_cbranch_execz .LBB2_47
.LBB2_87:                               ; %LeafBlock216
                                        ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_ne_u32_e32 vcc_lo, 0, v4
	v_mov_b32_e32 v3, 1
	s_and_not1_b32 s0, s0, exec_lo
	s_and_b32 s12, vcc_lo, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s0, s0, s12
	s_or_b32 exec_lo, exec_lo, s1
	s_and_saveexec_b32 s1, s0
	s_cbranch_execnz .LBB2_48
	s_branch .LBB2_49
.LBB2_88:                               ; %NodeBlock226
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_mov_b32 s12, exec_lo
	v_cmpx_lt_i32_e32 2, v2
	s_xor_b32 s12, exec_lo, s12
; %bb.89:                               ; %LeafBlock224
                                        ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_eq_u32_e32 vcc_lo, 3, v2
	s_and_b32 s1, vcc_lo, exec_lo
; %bb.90:                               ; %Flow235
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_saveexec_b32 s12, s12
	v_mov_b32_e32 v4, 1
	s_xor_b32 exec_lo, exec_lo, s12
; %bb.91:                               ;   in Loop: Header=BB2_3 Depth=1
	v_mov_b32_e32 v4, 6
; %bb.92:                               ; %Flow236
                                        ;   in Loop: Header=BB2_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s1, s1, exec_lo
	s_and_not1_saveexec_b32 s0, s0
	s_cbranch_execz .LBB2_55
.LBB2_93:                               ; %LeafBlock222
                                        ;   in Loop: Header=BB2_3 Depth=1
	v_cmp_eq_u32_e32 vcc_lo, 1, v2
	v_mov_b32_e32 v4, 1
	s_and_not1_b32 s1, s1, exec_lo
	s_and_b32 s12, vcc_lo, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s1, s1, s12
	s_or_b32 exec_lo, exec_lo, s0
	s_and_saveexec_b32 s0, s1
	s_cbranch_execnz .LBB2_56
	s_branch .LBB2_57
.LBB2_94:
	v_div_scale_f32 v1, null, 0x40028f5c, 0x40028f5c, v11
	v_div_scale_f32 v4, vcc_lo, v11, 0x40028f5c, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v2, v1
	v_fma_f32 v3, -v1, v2, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v3, v2
	v_dual_mov_b32 v0, 0xc000 :: v_dual_mul_f32 v3, v4, v2
	global_load_d16_b16 v0, v0, s[8:9] offset:144
	v_fma_f32 v5, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v5, v2
	v_fma_f32 v1, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_div_fmas_f32 v1, v1, v2, v3
	v_and_b32_e32 v2, 0x3fe, v39
	v_or_b32_e32 v3, 0x1008, v42
	v_div_fixup_f32 v1, v1, 0x40028f5c, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_dual_add_f32 v1, v43, v1 :: v_dual_lshlrev_b32 v2, 2, v2
	s_waitcnt vmcnt(0)
	v_cvt_f32_f16_e32 v0, v0.l
	v_mul_f32_e32 v0, v1, v0
	v_or_b32_e32 v1, 0x1004, v42
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_waitcnt_vscnt null, 0x0
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v1
	ds_load_b32 v1, v2 offset:4096
	v_and_b32_e32 v2, 1, v39
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3fd, v39
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 2, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3fb, v39
	v_or_b32_e32 v3, 0x1010, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 4, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3f7, v39
	v_or_b32_e32 v3, 0x1020, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 8, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3ef, v39
	v_or_b32_e32 v3, 0x1040, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 16, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3df, v39
	v_or_b32_e32 v3, 0x1080, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 32, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3bf, v39
	v_or_b32_e32 v3, 0x1100, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 64, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_and_b32_e32 v3, v40, v41
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v3
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v42 offset:4096
	s_waitcnt lgkmcnt(0)
	v_mul_f32_e32 v0, 0x3db504f3, v0
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v42 offset:4096
	v_lshl_add_u32 v0, s2, 7, v39
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ashrrev_i32_e32 v1, 31, v0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v2, -v2, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s6, v0
	v_add_co_ci_u32_e64 v1, null, s7, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_nop 0
	s_sendmsg sendmsg(MSG_DEALLOC_VGPRS)
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z4quipILi1EEvPKfPfPKhPKj
		.amdhsa_group_segment_fixed_size 4608
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 32
		.amdhsa_user_sgpr_count 2
		.amdhsa_user_sgpr_dispatch_ptr 0
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 0
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_wavefront_size32 1
		.amdhsa_uses_dynamic_stack 0
		.amdhsa_enable_private_segment 0
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 0
		.amdhsa_system_sgpr_workgroup_id_z 0
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 0
		.amdhsa_next_free_vgpr 44
		.amdhsa_next_free_sgpr 33
		.amdhsa_reserve_vcc 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_workgroup_processor_mode 1
		.amdhsa_memory_ordered 1
		.amdhsa_forward_progress 1
		.amdhsa_shared_vgpr_count 0
		.amdhsa_inst_pref_size 37
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z4quipILi1EEvPKfPfPKhPKj,"axG",@progbits,_Z4quipILi1EEvPKfPfPKhPKj,comdat
.Lfunc_end2:
	.size	_Z4quipILi1EEvPKfPfPKhPKj, .Lfunc_end2-_Z4quipILi1EEvPKfPfPKhPKj
                                        ; -- End function
	.set _Z4quipILi1EEvPKfPfPKhPKj.num_vgpr, max(44, .L_Z13transform1024Pfi.num_vgpr)
	.set _Z4quipILi1EEvPKfPfPKhPKj.num_agpr, max(0, .L_Z13transform1024Pfi.num_agpr)
	.set _Z4quipILi1EEvPKfPfPKhPKj.numbered_sgpr, max(33, .L_Z13transform1024Pfi.numbered_sgpr)
	.set _Z4quipILi1EEvPKfPfPKhPKj.num_named_barrier, max(0, .L_Z13transform1024Pfi.num_named_barrier)
	.set _Z4quipILi1EEvPKfPfPKhPKj.private_seg_size, 0+max(.L_Z13transform1024Pfi.private_seg_size)
	.set _Z4quipILi1EEvPKfPfPKhPKj.uses_vcc, or(1, .L_Z13transform1024Pfi.uses_vcc)
	.set _Z4quipILi1EEvPKfPfPKhPKj.uses_flat_scratch, or(0, .L_Z13transform1024Pfi.uses_flat_scratch)
	.set _Z4quipILi1EEvPKfPfPKhPKj.has_dyn_sized_stack, or(0, .L_Z13transform1024Pfi.has_dyn_sized_stack)
	.set _Z4quipILi1EEvPKfPfPKhPKj.has_recursion, or(0, .L_Z13transform1024Pfi.has_recursion)
	.set _Z4quipILi1EEvPKfPfPKhPKj.has_indirect_call, or(0, .L_Z13transform1024Pfi.has_indirect_call)
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 4700
; TotalNumSgprs: 35
; NumVgprs: 44
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 4608 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 5
; NumSGPRsForWavesPerEU: 35
; NumVGPRsForWavesPerEU: 44
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z4quipILi2EEvPKfPfPKhPKj,"axG",@progbits,_Z4quipILi2EEvPKfPfPKhPKj,comdat
	.protected	_Z4quipILi2EEvPKfPfPKhPKj ; -- Begin function _Z4quipILi2EEvPKfPfPKhPKj
	.globl	_Z4quipILi2EEvPKfPfPKhPKj
	.p2align	8
	.type	_Z4quipILi2EEvPKfPfPKhPKj,@function
_Z4quipILi2EEvPKfPfPKhPKj:              ; @_Z4quipILi2EEvPKfPfPKhPKj
; %bb.0:
	s_load_b256 s[4:11], s[0:1], 0x0
	v_mov_b32_e32 v39, v0
	s_lshl_b32 s0, s2, 10
	s_mov_b64 s[12:13], src_shared_base
	s_mov_b32 s32, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_mov_b32 v43, 0 :: v_dual_add_nc_u32 v6, 0x100, v39
	v_or_b32_e32 v0, s0, v39
	s_ashr_i32 s0, s0, 31
	v_add_nc_u32_e32 v4, 0x80, v39
	v_lshrrev_b32_e32 v5, 3, v39
	v_lshrrev_b32_e32 v9, 3, v6
	v_ashrrev_i32_e32 v1, 31, v0
	v_add_nc_u32_e32 v18, 0x380, v39
	s_mov_b32 s3, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[2:3], 2, v[0:1]
	v_mov_b32_e32 v1, s0
	v_lshrrev_b32_e32 v7, 3, v4
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v4, s0, s8, v5
	v_add_co_ci_u32_e64 v5, null, s9, 0, s0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	v_add_co_u32 v2, vcc_lo, s4, v2
	v_add_co_u32 v7, s0, s8, v7
	v_add_co_ci_u32_e64 v3, null, s5, v3, vcc_lo
	v_add_co_u32 v4, vcc_lo, 0xc000, v4
	v_add_co_ci_u32_e64 v8, null, s9, 0, s0
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	v_add_co_u32 v0, vcc_lo, s4, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s5, v1, vcc_lo
	v_add_co_u32 v6, vcc_lo, 0xc000, v7
	v_add_co_ci_u32_e64 v7, null, 0, v8, vcc_lo
	v_add_nc_u32_e32 v8, 0x180, v39
	v_add_co_u32 v9, s0, s8, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v10, null, s9, 0, s0
	v_lshrrev_b32_e32 v11, 3, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, 0xc000, v9
	v_add_co_ci_u32_e64 v9, null, 0, v10, vcc_lo
	v_add_nc_u32_e32 v10, 0x200, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, s0, s8, v11
	v_add_co_ci_u32_e64 v12, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshrrev_b32_e32 v13, 3, v10
	v_add_co_u32 v10, vcc_lo, 0xc000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v11, null, 0, v12, vcc_lo
	v_add_nc_u32_e32 v12, 0x280, v39
	v_add_co_u32 v13, s0, s8, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v14, null, s9, 0, s0
	v_lshrrev_b32_e32 v15, 3, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, vcc_lo, 0xc000, v13
	v_add_co_ci_u32_e64 v13, null, 0, v14, vcc_lo
	v_add_nc_u32_e32 v14, 0x300, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v15, s0, s8, v15
	v_add_co_ci_u32_e64 v16, null, s9, 0, s0
	global_load_u8 v20, v[4:5], off
	v_lshrrev_b32_e32 v17, 3, v14
	v_add_co_u32 v14, vcc_lo, 0xc000, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v15, null, 0, v16, vcc_lo
	v_lshrrev_b32_e32 v16, 3, v18
	v_add_co_u32 v17, s0, s8, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v18, null, s9, 0, s0
	v_add_co_u32 v19, s0, s8, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v21, null, s9, 0, s0
	v_add_co_u32 v16, vcc_lo, 0xc000, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v17, null, 0, v18, vcc_lo
	v_add_co_u32 v18, vcc_lo, 0xc000, v19
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v21, vcc_lo
	s_clause 0x6
	global_load_u8 v6, v[6:7], off
	global_load_u8 v7, v[8:9], off
	global_load_u8 v8, v[10:11], off
	global_load_u8 v9, v[12:13], off
	global_load_u8 v10, v[14:15], off
	global_load_u8 v11, v[16:17], off
	global_load_u8 v12, v[18:19], off
	s_clause 0x7
	global_load_b32 v2, v[2:3], off
	global_load_b32 v3, v[0:1], off offset:512
	global_load_b32 v13, v[0:1], off offset:1024
	global_load_b32 v14, v[0:1], off offset:1536
	global_load_b32 v15, v[0:1], off offset:2048
	global_load_b32 v16, v[0:1], off offset:2560
	global_load_b32 v17, v[0:1], off offset:3072
	global_load_b32 v0, v[0:1], off offset:3584
	global_load_d16_u8 v40, v[4:5], off offset:128
	v_and_b32_e32 v1, 7, v39
	s_getpc_b64 s[0:1]
	s_add_u32 s0, s0, _Z13transform1024Pfi@rel32@lo+4
	s_addc_u32 s1, s1, _Z13transform1024Pfi@rel32@hi+12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e64 v41, v1, 1
	s_waitcnt vmcnt(15)
	v_and_b32_e32 v4, v41, v6
	v_and_b32_e32 v1, v41, v20
	s_waitcnt vmcnt(14)
	v_and_b32_e32 v5, v41, v7
	s_waitcnt vmcnt(13)
	v_and_b32_e32 v6, v41, v8
	s_waitcnt vmcnt(12)
	v_and_b32_e32 v7, v41, v9
	s_waitcnt vmcnt(11)
	v_and_b32_e32 v8, v41, v10
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_waitcnt vmcnt(10)
	v_and_b32_e32 v9, v41, v11
	s_waitcnt vmcnt(9)
	v_and_b32_e32 v10, v41, v12
	v_lshlrev_b32_e32 v42, 2, v39
	s_waitcnt vmcnt(8)
	v_cndmask_b32_e64 v1, -v2, v2, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v4
	s_waitcnt vmcnt(7)
	v_cndmask_b32_e64 v2, -v3, v3, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v5
	s_waitcnt vmcnt(6)
	v_cndmask_b32_e64 v3, -v13, v13, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v6
	s_waitcnt vmcnt(5)
	v_cndmask_b32_e64 v4, -v14, v14, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v7
	s_waitcnt vmcnt(4)
	v_cndmask_b32_e64 v5, -v15, v15, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v8
	s_waitcnt vmcnt(3)
	v_cndmask_b32_e64 v6, -v16, v16, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v9
	s_waitcnt vmcnt(2)
	v_cndmask_b32_e64 v7, -v17, v17, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v10
	s_waitcnt vmcnt(1)
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	ds_store_2addr_stride64_b32 v42, v1, v2 offset1:2
	ds_store_2addr_stride64_b32 v42, v3, v4 offset0:4 offset1:6
	ds_store_2addr_stride64_b32 v42, v5, v6 offset0:8 offset1:10
	ds_store_2addr_stride64_b32 v42, v7, v0 offset0:12 offset1:14
	v_dual_mov_b32 v0, 0 :: v_dual_mov_b32 v1, s13
	v_mov_b32_e32 v2, v39
	s_waitcnt vmcnt(0) lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_swappc_b64 s[30:31], s[0:1]
	v_dual_mov_b32 v13, 0x3e800000 :: v_dual_lshlrev_b32 v0, 7, v39
	v_lshlrev_b32_e32 v2, 8, v39
	v_mov_b32_e32 v10, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, s0, s8, v0
	v_add_co_ci_u32_e64 v1, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_u32 v8, s0, s8, v2
	v_add_co_u32 v11, vcc_lo, 0x8000, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, 0, v1, vcc_lo
	v_add_co_ci_u32_e64 v9, null, s9, 0, s0
	s_mov_b64 s[0:1], 0
	s_branch .LBB3_3
.LBB3_1:                                ; %Flow
                                        ;   in Loop: Header=BB3_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s5
.LBB3_2:                                ;   in Loop: Header=BB3_3 Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt vmcnt(0)
	v_bfe_u32 v18, v15, 16, 4
	v_and_b32_e32 v17, 15, v15
	v_bfe_u32 v20, v15, 4, 4
	v_bfe_u32 v21, v15, 20, 4
	s_add_u32 s0, s0, 1
	v_add_nc_u32_e32 v18, -8, v18
	s_addc_u32 s1, s1, 0
	v_add_nc_u32_e32 v20, -8, v20
	s_add_i32 s3, s3, 32
	s_cmpk_eq_i32 s0, 0x80
	v_cvt_f32_i32_e32 v18, v18
	v_add_nc_u32_e32 v17, -8, v17
	v_cvt_f32_i32_e32 v20, v20
	v_and_b32_e32 v19, 16, v14
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f32_e32 v18, 0.5, v18
	v_cvt_f32_i32_e32 v17, v17
	v_and_b32_e32 v16, 0xff, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_mul_f32 v20, 0.5, v20 :: v_dual_mul_f32 v17, 0.5, v17
	v_bcnt_u32_b32 v16, v16, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_xor_b32_e32 v22, v16, v14
	v_and_b32_e32 v16, 1, v16
	v_and_b32_e32 v22, 1, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v16
	v_cndmask_b32_e32 v16, 0xbe800000, v13, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v22
	v_cndmask_b32_e64 v17, -v17, v17, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_f32_e32 v17, v16, v17
	v_cndmask_b32_e64 v18, -v18, v18, vcc_lo
	v_add_nc_u32_e32 v21, -8, v21
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v43, v17, v4 :: v_dual_add_f32 v18, v16, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cvt_f32_i32_e32 v21, v21
	v_and_b32_e32 v19, 2, v14
	v_bfe_u32 v17, v15, 8, 4
	v_fmac_f32_e32 v43, v18, v5
	v_bfe_u32 v18, v15, 24, 4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	v_add_nc_u32_e32 v5, -8, v17
	v_cndmask_b32_e64 v4, -v20, v20, vcc_lo
	v_dual_mul_f32 v20, 0.5, v21 :: v_dual_and_b32 v19, 32, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f32_e32 v4, v16, v4
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v43, v4, v6
	v_cndmask_b32_e64 v17, -v20, v20, vcc_lo
	v_add_nc_u32_e32 v6, -8, v18
	v_bfe_u32 v18, v15, 12, 4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_add_f32 v4, v16, v17 :: v_dual_and_b32 v17, 4, v14
	v_fmac_f32_e32 v43, v4, v7
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_i32_e32 v4, v6
	v_cmp_eq_u32_e32 vcc_lo, 0, v17
	v_add_nc_u32_e32 v6, -8, v18
	v_lshrrev_b32_e32 v7, 28, v15
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_dual_mul_f32 v4, 0.5, v4 :: v_dual_and_b32 v15, 64, v14
	v_cvt_f32_i32_e32 v5, v5
	v_cvt_f32_i32_e32 v6, v6
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_nc_u32_e32 v7, -8, v7
	v_dual_mul_f32 v5, 0.5, v5 :: v_dual_mul_f32 v6, 0.5, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_cndmask_b32_e64 v5, -v5, v5, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v15
	v_and_b32_e32 v15, 8, v14
	v_add_f32_e32 v5, v16, v5
	v_cndmask_b32_e64 v4, -v4, v4, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v15
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v43, v5, v0
	v_cvt_f32_i32_e32 v0, v7
	v_cndmask_b32_e64 v5, -v6, v6, vcc_lo
	v_and_b32_e32 v6, 0x80, v14
	v_add_f32_e32 v4, v16, v4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_mul_f32_e32 v0, 0.5, v0
	v_cmp_eq_u32_e32 vcc_lo, 0, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v43, v4, v1
	v_add_f32_e32 v1, v16, v5
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	v_add_co_u32 v8, vcc_lo, v8, 2
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v43, v1, v2
	v_add_co_ci_u32_e64 v9, null, 0, v9, vcc_lo
	v_add_f32_e32 v0, v16, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v43, v0, v3
	s_cbranch_scc1 .LBB3_8
.LBB3_3:                                ; =>This Inner Loop Header: Depth=1
	global_load_u16 v14, v[8:9], off
	v_add_co_u32 v0, vcc_lo, v11, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s1, v12, vcc_lo
	s_mov_b32 s4, exec_lo
	global_load_d16_i8 v17, v[0:1], off
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v2, 6, v14
	v_and_b32_e32 v0, 0x3fc, v2
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v16, 0xff, v17
	global_load_b32 v15, v0, s[10:11]
	v_mov_b32_e32 v0, s3
	ds_load_b128 v[4:7], v0
	ds_load_b128 v[0:3], v0 offset:16
	v_cmpx_gt_i16_e32 0, v17.l
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB3_5
; %bb.4:                                ;   in Loop: Header=BB3_3 Depth=1
	v_and_b32_e32 v17, 1, v16
	v_and_b32_e32 v19, 4, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v17
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v17, -v4, v4, vcc_lo
	v_dual_add_f32 v17, 0, v17 :: v_dual_and_b32 v18, 2, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	v_cndmask_b32_e64 v18, -v5, v5, vcc_lo
	v_and_b32_e32 v20, 8, v16
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	v_add_f32_e32 v17, v17, v18
	v_cndmask_b32_e64 v19, -v6, v6, vcc_lo
	v_and_b32_e32 v18, 16, v16
	v_cmp_eq_u32_e32 vcc_lo, 0, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_f32_e32 v17, v17, v19
	v_and_b32_e32 v19, 32, v16
	v_cndmask_b32_e64 v20, -v7, v7, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	v_add_f32_e32 v17, v17, v20
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v18, -v0, v0, vcc_lo
	v_and_b32_e32 v20, 0x7f, v16
	v_cmp_eq_u32_e32 vcc_lo, 0, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_f32_e32 v17, v17, v18
	v_bcnt_u32_b32 v18, v20, 0
	v_cndmask_b32_e64 v19, -v1, v1, vcc_lo
	v_and_b32_e32 v16, 64, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_add_f32 v17, v17, v19 :: v_dual_and_b32 v18, 1, v18
	v_cmp_eq_u32_e32 vcc_lo, 0, v16
	v_cndmask_b32_e64 v16, -v2, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v18
	v_add_f32_e32 v16, v17, v16
	v_cndmask_b32_e64 v17, -v3, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v16, v16, v17
                                        ; implicit-def: $vgpr17_lo16
	v_fmac_f32_e32 v10, 0.5, v16
                                        ; implicit-def: $vgpr16
.LBB3_5:                                ; %Flow156
                                        ;   in Loop: Header=BB3_3 Depth=1
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB3_2
; %bb.6:                                ;   in Loop: Header=BB3_3 Depth=1
	s_mov_b32 s5, exec_lo
	v_cmpx_ne_u16_e32 0x7f, v17.l
	s_cbranch_execz .LBB3_1
; %bb.7:                                ;   in Loop: Header=BB3_3 Depth=1
	v_bfe_u32 v18, v16, 3, 3
	v_and_b32_e32 v16, 7, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshl_add_u32 v19, v18, 2, s3
	v_lshl_add_u32 v20, v16, 2, s3
	v_cmp_gt_u32_e32 vcc_lo, v16, v18
	ds_load_b32 v19, v19
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v16, v19, -v19, vcc_lo
	v_cmp_gt_u16_e32 vcc_lo, 64, v17.l
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v16, v20, v16
	v_cndmask_b32_e64 v16, -v16, v16, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v16
	s_branch .LBB3_1
.LBB3_8:
	v_div_scale_f32 v1, null, 0x40028f5c, 0x40028f5c, v10
	v_div_scale_f32 v4, vcc_lo, v10, 0x40028f5c, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v2, v1
	v_fma_f32 v3, -v1, v2, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v3, v2
	v_dual_mov_b32 v0, 0xc000 :: v_dual_mul_f32 v3, v4, v2
	global_load_d16_b16 v0, v0, s[8:9] offset:144
	v_fma_f32 v5, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v5, v2
	v_fma_f32 v1, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_div_fmas_f32 v1, v1, v2, v3
	v_and_b32_e32 v2, 0x3fe, v39
	v_or_b32_e32 v3, 0x1008, v42
	v_div_fixup_f32 v1, v1, 0x40028f5c, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_dual_add_f32 v1, v43, v1 :: v_dual_lshlrev_b32 v2, 2, v2
	s_waitcnt vmcnt(0)
	v_cvt_f32_f16_e32 v0, v0.l
	v_mul_f32_e32 v0, v1, v0
	v_or_b32_e32 v1, 0x1004, v42
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_waitcnt_vscnt null, 0x0
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v1
	ds_load_b32 v1, v2 offset:4096
	v_and_b32_e32 v2, 1, v39
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3fd, v39
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 2, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3fb, v39
	v_or_b32_e32 v3, 0x1010, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 4, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3f7, v39
	v_or_b32_e32 v3, 0x1020, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 8, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3ef, v39
	v_or_b32_e32 v3, 0x1040, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 16, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3df, v39
	v_or_b32_e32 v3, 0x1080, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 32, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	v_and_b32_e32 v2, 0x3bf, v39
	v_or_b32_e32 v3, 0x1100, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 64, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_and_b32_e32 v3, v40, v41
	v_cndmask_b32_e64 v0, -v0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, 0, v3
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v42 offset:4096
	s_waitcnt lgkmcnt(0)
	v_mul_f32_e32 v0, 0x3db504f3, v0
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v42 offset:4096
	v_lshl_add_u32 v0, s2, 7, v39
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ashrrev_i32_e32 v1, 31, v0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v2, -v2, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s6, v0
	v_add_co_ci_u32_e64 v1, null, s7, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_nop 0
	s_sendmsg sendmsg(MSG_DEALLOC_VGPRS)
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z4quipILi2EEvPKfPfPKhPKj
		.amdhsa_group_segment_fixed_size 4608
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 32
		.amdhsa_user_sgpr_count 2
		.amdhsa_user_sgpr_dispatch_ptr 0
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 0
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_wavefront_size32 1
		.amdhsa_uses_dynamic_stack 0
		.amdhsa_enable_private_segment 0
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 0
		.amdhsa_system_sgpr_workgroup_id_z 0
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 0
		.amdhsa_next_free_vgpr 44
		.amdhsa_next_free_sgpr 33
		.amdhsa_reserve_vcc 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_workgroup_processor_mode 1
		.amdhsa_memory_ordered 1
		.amdhsa_forward_progress 1
		.amdhsa_shared_vgpr_count 0
		.amdhsa_inst_pref_size 24
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z4quipILi2EEvPKfPfPKhPKj,"axG",@progbits,_Z4quipILi2EEvPKfPfPKhPKj,comdat
.Lfunc_end3:
	.size	_Z4quipILi2EEvPKfPfPKhPKj, .Lfunc_end3-_Z4quipILi2EEvPKfPfPKhPKj
                                        ; -- End function
	.set _Z4quipILi2EEvPKfPfPKhPKj.num_vgpr, max(44, .L_Z13transform1024Pfi.num_vgpr)
	.set _Z4quipILi2EEvPKfPfPKhPKj.num_agpr, max(0, .L_Z13transform1024Pfi.num_agpr)
	.set _Z4quipILi2EEvPKfPfPKhPKj.numbered_sgpr, max(33, .L_Z13transform1024Pfi.numbered_sgpr)
	.set _Z4quipILi2EEvPKfPfPKhPKj.num_named_barrier, max(0, .L_Z13transform1024Pfi.num_named_barrier)
	.set _Z4quipILi2EEvPKfPfPKhPKj.private_seg_size, 0+max(.L_Z13transform1024Pfi.private_seg_size)
	.set _Z4quipILi2EEvPKfPfPKhPKj.uses_vcc, or(1, .L_Z13transform1024Pfi.uses_vcc)
	.set _Z4quipILi2EEvPKfPfPKhPKj.uses_flat_scratch, or(0, .L_Z13transform1024Pfi.uses_flat_scratch)
	.set _Z4quipILi2EEvPKfPfPKhPKj.has_dyn_sized_stack, or(0, .L_Z13transform1024Pfi.has_dyn_sized_stack)
	.set _Z4quipILi2EEvPKfPfPKhPKj.has_recursion, or(0, .L_Z13transform1024Pfi.has_recursion)
	.set _Z4quipILi2EEvPKfPfPKhPKj.has_indirect_call, or(0, .L_Z13transform1024Pfi.has_indirect_call)
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 3036
; TotalNumSgprs: 35
; NumVgprs: 44
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 4608 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 5
; NumSGPRsForWavesPerEU: 35
; NumVGPRsForWavesPerEU: 44
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.text
	.p2alignl 7, 3214868480
	.fill 96, 4, 3214868480
	.section	.AMDGPU.gpr_maximums,"",@progbits
	.set amdgpu.max_num_vgpr, 39
	.set amdgpu.max_num_agpr, 0
	.set amdgpu.max_num_sgpr, 32
	.text
	.type	__hip_cuid_c2f152ab948e02ee,@object ; @__hip_cuid_c2f152ab948e02ee
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_c2f152ab948e02ee
__hip_cuid_c2f152ab948e02ee:
	.byte	0                               ; 0x0
	.size	__hip_cuid_c2f152ab948e02ee, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __hip_cuid_c2f152ab948e02ee
	.amdgpu_metadata
---
amdhsa.kernels:
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         24
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 4608
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z4quipILi0EEvPKfPfPKhPKj
    .private_segment_fixed_size: 0
    .sgpr_count:     35
    .sgpr_spill_count: 0
    .symbol:         _Z4quipILi0EEvPKfPfPKhPKj.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     44
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         24
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 4608
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z4quipILi1EEvPKfPfPKhPKj
    .private_segment_fixed_size: 0
    .sgpr_count:     35
    .sgpr_spill_count: 0
    .symbol:         _Z4quipILi1EEvPKfPfPKhPKj.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     44
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         24
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 4608
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z4quipILi2EEvPKfPfPKhPKj
    .private_segment_fixed_size: 0
    .sgpr_count:     35
    .sgpr_spill_count: 0
    .symbol:         _Z4quipILi2EEvPKfPfPKhPKj.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     44
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
