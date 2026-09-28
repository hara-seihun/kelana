	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.protected	_Z11quip_readerPKfPfPKhPKjPK6__half ; -- Begin function _Z11quip_readerPKfPfPKhPKjPK6__half
	.globl	_Z11quip_readerPKfPfPKhPKjPK6__half
	.p2align	8
	.type	_Z11quip_readerPKfPfPKhPKjPK6__half,@function
_Z11quip_readerPKfPfPKhPKjPK6__half:    ; @_Z11quip_readerPKfPfPKhPKjPK6__half
; %bb.0:
	s_load_b256 s[20:27], s[0:1], 0x0
	v_lshrrev_b32_e32 v2, 3, v0
	v_lshl_add_u32 v1, s2, 7, v0
	v_or_b32_e32 v12, 1, v0
	v_lshlrev_b32_e32 v9, 2, v0
	s_load_b64 s[28:29], s[0:1], 0x20
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_dual_mov_b32 v25, 0 :: v_dual_lshlrev_b32 v12, 2, v12
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v3, s2, s24, v2
	v_add_co_ci_u32_e64 v5, null, s25, 0, s2
	v_ashrrev_i32_e32 v2, 31, v1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, 0x1000, v3
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_lshlrev_b64 v[2:3], 2, v[1:2]
	s_clause 0x1
	global_load_u8 v1, v[4:5], off offset:2048
	global_load_d16_u8 v10, v[4:5], off offset:2064
	v_and_b32_e32 v5, 1, v0
	v_add_co_u32 v6, vcc_lo, s20, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v7, null, s21, v3, vcc_lo
	v_cmp_eq_u32_e64 s2, 0, v5
	v_or_b32_e32 v5, 2, v0
	global_load_b32 v6, v[6:7], off
	v_and_b32_e32 v7, 7, v0
	v_lshlrev_b32_e32 v14, 2, v5
	v_and_b32_e32 v5, 2, v0
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_lshlrev_b32_e64 v8, v7, 1
	v_and_b32_e32 v7, 0x3fe, v0
	v_cmp_eq_u32_e64 s3, 0, v5
	v_or_b32_e32 v5, 4, v0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v11, 2, v7
	v_lshlrev_b32_e32 v16, 2, v5
	v_and_b32_e32 v5, 4, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s4, 0, v5
	v_or_b32_e32 v5, 8, v0
	v_lshlrev_b32_e32 v18, 2, v5
	v_and_b32_e32 v5, 8, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s5, 0, v5
	v_or_b32_e32 v5, 16, v0
	v_lshlrev_b32_e32 v20, 2, v5
	v_and_b32_e32 v5, 16, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s6, 0, v5
	v_or_b32_e32 v5, 32, v0
	v_lshlrev_b32_e32 v22, 2, v5
	v_and_b32_e32 v5, 32, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s7, 0, v5
	v_or_b32_e32 v5, 64, v0
	v_lshlrev_b32_e32 v24, 2, v5
	v_and_b32_e32 v5, 64, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s8, 0, v5
	s_waitcnt vmcnt(2)
	v_and_b32_e32 v1, v8, v1
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_waitcnt vmcnt(0)
	v_cndmask_b32_e64 v1, -v6, v6, vcc_lo
	v_and_b32_e32 v6, 0x3fd, v0
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v12
	ds_load_b32 v4, v11
	v_lshlrev_b32_e32 v13, 2, v6
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_and_b32_e32 v6, 0x3fb, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v15, 2, v6
	v_and_b32_e32 v6, 0x3f7, v0
	v_lshlrev_b32_e32 v17, 2, v6
	v_and_b32_e32 v6, 0x3ef, v0
	v_cndmask_b32_e64 v1, -v1, v1, s2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v19, 2, v6
	v_dual_add_f32 v1, v4, v1 :: v_dual_and_b32 v6, 0x3df, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_lshlrev_b32_e32 v21, 2, v6
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v14
	ds_load_b32 v4, v13
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_and_b32_e32 v6, 0x3bf, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v23, 2, v6
	v_cndmask_b32_e64 v1, -v1, v1, s3
	v_add_f32_e32 v1, v4, v1
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v16
	ds_load_b32 v4, v15
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v1, -v1, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v4, v1
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v18
	ds_load_b32 v4, v17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v1, -v1, v1, s5
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v4, v1
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v20
	ds_load_b32 v4, v19
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v1, -v1, v1, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v4, v1
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v22
	ds_load_b32 v4, v21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v1, -v1, v1, s7
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v4, v1
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v24
	ds_load_b32 v4, v23
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v1, -v1, v1, s8
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v1, v4, v1 :: v_dual_mov_b32 v4, 0x1000
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v9
	s_waitcnt lgkmcnt(0)
	v_mul_f32_e32 v1, 0x3db504f3, v1
	ds_store_b32 v9, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	global_load_d16_b16 v1, v4, s[24:25] offset:2080
	v_lshlrev_b32_e32 v4, 4, v0
	v_lshlrev_b32_e32 v0, 5, v0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v6, s0, s24, v4
	v_add_co_ci_u32_e64 v7, null, s25, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_u32 v4, s0, s24, v0
	v_add_co_u32 v6, vcc_lo, 0x1000, v6
	v_add_co_ci_u32_e64 v5, null, s25, 0, s0
	s_delay_alu instid0(VALU_DEP_4)
	v_add_co_ci_u32_e64 v7, null, 0, v7, vcc_lo
	v_mov_b32_e32 v0, 0x3e800000
	s_mov_b32 s24, 0
.LBB0_1:                                ; =>This Inner Loop Header: Depth=1
	global_load_u8 v26, v[6:7], off
	global_load_u16 v38, v[4:5], off
	v_mov_b32_e32 v34, s24
	s_add_i32 s24, s24, 32
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	s_cmpk_eq_i32 s24, 0x200
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v30, 6, v38
	v_and_b32_e32 v41, 16, v38
	v_and_b32_e32 v30, 0x3fc, v30
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_eq_u32_e64 s14, 0, v41
	global_load_b32 v39, v30, s[26:27]
	s_waitcnt vmcnt(0)
	v_bfe_u32 v58, v39, 4, 4
	v_bfe_u32 v55, v39, 16, 4
	v_bfe_u32 v67, v39, 24, 4
	v_and_b32_e32 v52, 15, v39
	v_bfe_u32 v61, v39, 20, 4
	v_add_nc_u32_e32 v58, -8, v58
	v_bfe_u32 v64, v39, 8, 4
	v_add_nc_u32_e32 v67, -8, v67
	v_bfe_u32 v70, v39, 12, 4
	v_lshrrev_b32_e32 v39, 28, v39
	v_cvt_f32_i32_e32 v58, v58
	v_add_nc_u32_e32 v55, -8, v55
	v_cvt_f32_i32_e32 v67, v67
	v_and_b32_e32 v40, 0xff, v38
	v_add_nc_u32_e32 v64, -8, v64
	v_mul_f32_e32 v58, 0.5, v58
	v_cvt_f32_i32_e32 v55, v55
	v_dual_mul_f32 v67, 0.5, v67 :: v_dual_lshlrev_b32 v26, 4, v26
	v_bcnt_u32_b32 v40, v40, 0
	v_cvt_f32_i32_e32 v64, v64
	s_delay_alu instid0(VALU_DEP_4)
	v_mul_f32_e32 v55, 0.5, v55
	global_load_b128 v[26:29], v26, s[28:29]
	v_and_b32_e32 v47, 0x80, v38
	ds_load_b128 v[30:33], v34
	ds_load_b128 v[34:37], v34 offset:16
	v_mul_f32_e32 v64, 0.5, v64
	v_cmp_eq_u32_e64 s20, 0, v47
	s_waitcnt vmcnt(0)
	v_cvt_f32_f16_e32 v50, v28.l
	v_cvt_f32_f16_e32 v49, v27.l
	v_cvt_f32_f16_e32 v27, v27.h
	v_cvt_f32_f16_e32 v51, v29.l
	v_cvt_f32_f16_e32 v29, v29.h
	v_div_scale_f32 v65, null, 0x40028f5c, 0x40028f5c, v50
	v_div_scale_f32 v59, null, 0x40028f5c, 0x40028f5c, v49
	v_div_scale_f32 v62, null, 0x40028f5c, 0x40028f5c, v27
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_rcp_f32_e32 v79, v65
	v_and_b32_e32 v48, 1, v40
	v_rcp_f32_e32 v77, v59
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_4) | instid1(VALU_DEP_4)
	v_rcp_f32_e32 v78, v62
	v_add_nc_u32_e32 v39, -8, v39
	v_div_scale_f32 v71, null, 0x40028f5c, 0x40028f5c, v51
	v_cmp_eq_u32_e32 vcc_lo, 0, v48
	v_cvt_f32_f16_e32 v48, v26.l
	v_cvt_f32_i32_e32 v39, v39
	v_and_b32_e32 v42, 2, v38
	v_cvt_f32_f16_e32 v26, v26.h
	v_div_scale_f32 v73, null, 0x40028f5c, 0x40028f5c, v29
	v_div_scale_f32 v53, null, 0x40028f5c, 0x40028f5c, v48
	v_rcp_f32_e32 v81, v71
	v_mul_f32_e32 v39, 0.5, v39
	v_cmp_eq_u32_e64 s15, 0, v42
	s_delay_alu instid0(VALU_DEP_3)
	v_rcp_f32_e32 v75, v53
	v_fma_f32 v42, -v59, v77, 1.0
	v_and_b32_e32 v46, 8, v38
	v_div_scale_f32 v56, null, 0x40028f5c, 0x40028f5c, v26
	v_div_scale_f32 v60, s1, v49, 0x40028f5c, v49
	v_div_scale_f32 v66, s10, v50, 0x40028f5c, v50
	v_rcp_f32_e32 v82, v73
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_4)
	v_fma_f32 v83, -v53, v75, 1.0
	v_dual_fmac_f32 v77, v42, v77 :: v_dual_and_b32 v44, 4, v38
	v_add_nc_u32_e32 v52, -8, v52
	v_and_b32_e32 v43, 32, v38
	v_fmac_f32_e32 v75, v83, v75
	s_delay_alu instid0(VALU_DEP_4)
	v_cmp_eq_u32_e64 s17, 0, v44
	v_fma_f32 v44, -v65, v79, 1.0
	v_rcp_f32_e32 v76, v56
	v_cvt_f32_i32_e32 v52, v52
	v_and_b32_e32 v45, 64, v38
	v_xor_b32_e32 v38, v40, v38
	v_dual_fmac_f32 v79, v44, v79 :: v_dual_add_nc_u32 v70, -8, v70
	v_cmp_eq_u32_e64 s19, 0, v46
	v_fma_f32 v46, -v71, v81, 1.0
	s_delay_alu instid0(VALU_DEP_4)
	v_and_b32_e32 v38, 1, v38
	v_div_scale_f32 v72, s12, v51, 0x40028f5c, v51
	v_cvt_f32_i32_e32 v70, v70
	v_dual_mul_f32 v52, 0.5, v52 :: v_dual_add_nc_u32 v61, -8, v61
	v_cmp_eq_u32_e64 s18, 0, v45
	v_fma_f32 v47, -v73, v82, 1.0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f32_e32 v70, 0.5, v70
	v_cvt_f32_i32_e32 v61, v61
	v_dual_fmac_f32 v81, v46, v81 :: v_dual_cndmask_b32 v40, 0xbe800000, v0
	v_div_scale_f32 v54, vcc_lo, v48, 0x40028f5c, v48
	v_fma_f32 v41, -v56, v76, 1.0
	s_delay_alu instid0(VALU_DEP_4)
	v_mul_f32_e32 v61, 0.5, v61
	v_cmp_eq_u32_e64 s16, 0, v43
	v_cmp_eq_u32_e64 s21, 0, v38
	v_cndmask_b32_e64 v44, -v67, v67, s18
	v_dual_fmac_f32 v82, v47, v82 :: v_dual_mul_f32 v67, v72, v81
	v_div_scale_f32 v57, s0, v26, 0x40028f5c, v26
	s_delay_alu instid0(VALU_DEP_4)
	v_cndmask_b32_e64 v38, -v52, v52, s21
	v_cndmask_b32_e64 v52, -v55, v55, s14
	v_fmac_f32_e32 v76, v41, v76
	v_cndmask_b32_e64 v42, -v61, v61, s16
	v_mul_f32_e32 v61, v66, v79
	v_fma_f32 v89, -v71, v67, v72
	v_dual_mul_f32 v46, v54, v75 :: v_dual_add_f32 v47, v40, v52
	v_mul_f32_e32 v55, v60, v77
	s_delay_alu instid0(VALU_DEP_4)
	v_fma_f32 v87, -v65, v61, v66
	v_mul_f32_e32 v52, v57, v76
	v_fmac_f32_e32 v67, v89, v81
	v_fma_f32 v83, -v53, v46, v54
	v_fma_f32 v85, -v59, v55, v60
	v_fmac_f32_e32 v61, v87, v79
	v_fma_f32 v84, -v56, v52, v57
	v_add_f32_e32 v38, v40, v38
	v_fmac_f32_e32 v46, v83, v75
	v_fma_f32 v43, -v62, v78, 1.0
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_dual_fmac_f32 v55, v85, v77 :: v_dual_fmac_f32 v52, v84, v76
	v_div_scale_f32 v63, s9, v27, 0x40028f5c, v27
	v_fma_f32 v53, -v53, v46, v54
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v78, v43, v78
	v_fma_f32 v54, -v56, v52, v57
	v_cvt_f32_f16_e32 v28, v28.h
	v_cndmask_b32_e64 v41, -v58, v58, s15
	v_div_fmas_f32 v46, v53, v75, v46
	s_mov_b32 vcc_lo, s0
	v_fma_f32 v56, -v59, v55, v60
	v_div_fmas_f32 v52, v54, v76, v52
	v_div_scale_f32 v68, null, 0x40028f5c, 0x40028f5c, v28
	v_div_fixup_f32 v46, v46, 0x40028f5c, v48
	s_mov_b32 vcc_lo, s1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v26, v52, 0x40028f5c, v26
	v_rcp_f32_e32 v80, v68
	v_div_fmas_f32 v53, v56, v77, v55
	v_add_f32_e32 v38, v38, v46
	v_add_f32_e32 v44, v40, v44
	v_add_f32_e32 v26, v47, v26
	s_mov_b32 vcc_lo, s9
	v_add_f32_e32 v41, v40, v41
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v25, v38, v30
	v_add_f32_e32 v42, v40, v42
	v_div_fixup_f32 v49, v53, 0x40028f5c, v49
	v_fma_f32 v45, -v68, v80, 1.0
	v_div_scale_f32 v69, s11, v28, 0x40028f5c, v28
	v_dual_fmac_f32 v25, v26, v31 :: v_dual_mul_f32 v58, v63, v78
	s_delay_alu instid0(VALU_DEP_3)
	v_fmac_f32_e32 v80, v45, v80
	v_cndmask_b32_e64 v45, -v70, v70, s19
	v_add_f32_e32 v38, v41, v49
	v_cndmask_b32_e64 v43, -v64, v64, s17
	v_fma_f32 v86, -v62, v58, v63
	v_fma_f32 v59, -v65, v61, v66
	v_add_f32_e32 v45, v40, v45
	v_fmac_f32_e32 v25, v38, v32
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_dual_add_f32 v43, v40, v43 :: v_dual_fmac_f32 v58, v86, v78
	v_div_scale_f32 v74, s13, v29, 0x40028f5c, v29
	v_cndmask_b32_e64 v39, -v39, v39, s20
	v_fma_f32 v57, -v62, v58, v63
	v_fma_f32 v62, -v71, v67, v72
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v48, v57, v78, v58
	s_mov_b32 vcc_lo, s10
	v_div_fmas_f32 v52, v59, v79, v61
	s_mov_b32 vcc_lo, s11
	v_div_fixup_f32 v27, v48, 0x40028f5c, v27
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v26, v52, 0x40028f5c, v50
	v_dual_add_f32 v27, v42, v27 :: v_dual_mul_f32 v64, v69, v80
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f32_e32 v26, v43, v26
	v_fmac_f32_e32 v25, v27, v33
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f32 v88, -v68, v64, v69
	s_waitcnt lgkmcnt(0)
	v_dual_fmac_f32 v25, v26, v34 :: v_dual_fmac_f32 v64, v88, v80
	v_add_f32_e32 v26, v40, v39
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v60, -v68, v64, v69
	v_div_fmas_f32 v46, v60, v80, v64
	s_mov_b32 vcc_lo, s12
	v_div_fmas_f32 v30, v62, v81, v67
	s_mov_b32 vcc_lo, s13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v28, v46, 0x40028f5c, v28
	v_div_fixup_f32 v30, v30, 0x40028f5c, v51
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v28, v44, v28
	v_dual_mul_f32 v70, v74, v82 :: v_dual_fmac_f32 v25, v28, v35
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v90, -v73, v70, v74
	v_fmac_f32_e32 v70, v90, v82
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v63, -v73, v70, v74
	v_div_fmas_f32 v27, v63, v82, v70
	v_add_co_u32 v4, vcc_lo, v4, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	v_div_fixup_f32 v27, v27, 0x40028f5c, v29
	v_add_f32_e32 v29, v45, v30
	v_add_co_u32 v6, vcc_lo, v6, 1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v7, null, 0, v7, vcc_lo
	v_dual_add_f32 v26, v26, v27 :: v_dual_fmac_f32 v25, v29, v36
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v25, v26, v37
	s_cbranch_scc0 .LBB0_1
; %bb.2:
	v_cvt_f32_f16_e32 v0, v1.l
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v0, v25, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v12 offset:512
	ds_load_b32 v1, v11 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v14 offset:512
	ds_load_b32 v1, v13 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v16 offset:512
	ds_load_b32 v1, v15 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v18 offset:512
	ds_load_b32 v1, v17 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s5
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v20 offset:512
	ds_load_b32 v1, v19 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v22 offset:512
	ds_load_b32 v1, v21 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s7
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v1, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v24 offset:512
	ds_load_b32 v1, v23 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v0, v1, v0
	v_and_b32_e32 v1, v10, v8
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v9 offset:512
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_waitcnt lgkmcnt(0)
	v_mul_f32_e32 v0, 0x3db504f3, v0
	ds_store_b32 v9, v0 offset:512
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v9 offset:512
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v4, -v0, v0, vcc_lo
	v_add_co_u32 v0, vcc_lo, s22, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s23, v3, vcc_lo
	global_store_b32 v[0:1], v4, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11quip_readerPKfPfPKhPKjPK6__half
		.amdhsa_group_segment_fixed_size 1024
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 40
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
		.amdhsa_next_free_vgpr 91
		.amdhsa_next_free_sgpr 30
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
		.amdhsa_inst_pref_size 25
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end0:
	.size	_Z11quip_readerPKfPfPKhPKjPK6__half, .Lfunc_end0-_Z11quip_readerPKfPfPKhPKjPK6__half
                                        ; -- End function
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.num_vgpr, 91
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.num_agpr, 0
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.numbered_sgpr, 30
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.num_named_barrier, 0
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.private_seg_size, 0
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.uses_vcc, 1
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.uses_flat_scratch, 0
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.has_dyn_sized_stack, 0
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.has_recursion, 0
	.set _Z11quip_readerPKfPfPKhPKjPK6__half.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 3192
; TotalNumSgprs: 32
; NumVgprs: 91
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 1024 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 11
; NumSGPRsForWavesPerEU: 32
; NumVGPRsForWavesPerEU: 91
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
	.protected	_Z13scalar_readerPKfPfPKh ; -- Begin function _Z13scalar_readerPKfPfPKh
	.globl	_Z13scalar_readerPKfPfPKh
	.p2align	8
	.type	_Z13scalar_readerPKfPfPKh,@function
_Z13scalar_readerPKfPfPKh:              ; @_Z13scalar_readerPKfPfPKh
; %bb.0:
	s_load_b64 s[8:9], s[0:1], 0x10
	v_lshlrev_b32_e64 v1, v0, -1
	v_lshrrev_b32_e32 v3, 5, v0
	s_mov_b32 s3, exec_lo
                                        ; implicit-def: $vgpr2
	s_delay_alu instid0(VALU_DEP_2)
	v_not_b32_e32 v1, v1
	s_waitcnt lgkmcnt(0)
	s_load_b64 s[10:11], s[8:9], 0x0
	v_cmpx_gt_u32_e32 64, v0
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB1_2
; %bb.1:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v2, s11, v1
	v_cmp_eq_u32_e32 vcc_lo, 1, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v2, v2, 0
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
.LBB1_2:                                ; %Flow106
	s_and_not1_saveexec_b32 s3, s3
	s_cbranch_execz .LBB1_4
; %bb.3:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s4, s11
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v2, s4
.LBB1_4:
	s_or_b32 exec_lo, exec_lo, s3
	s_load_b32 s3, s[8:9], 0x8
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr4
	v_cmpx_gt_u32_e32 0x60, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB1_6
; %bb.5:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v4, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 2, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v4, v4, 0
	v_cndmask_b32_e32 v4, 0, v4, vcc_lo
.LBB1_6:                                ; %Flow105
	s_waitcnt lgkmcnt(0)
	s_or_saveexec_b32 s11, s4
	s_load_b128 s[4:7], s[0:1], 0x0
	s_xor_b32 exec_lo, exec_lo, s11
; %bb.7:
	s_bcnt1_i32_b32 s0, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v4, s0
; %bb.8:
	s_or_b32 exec_lo, exec_lo, s11
	s_load_b32 s0, s[8:9], 0xc
	s_mov_b32 s1, exec_lo
                                        ; implicit-def: $vgpr5
	v_cmpx_gt_u32_e32 0x80, v0
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB1_10
; %bb.9:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s0, v1
	v_cmp_eq_u32_e32 vcc_lo, 3, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v5, 0, v5, vcc_lo
.LBB1_10:                               ; %Flow
	s_and_not1_saveexec_b32 s1, s1
	s_cbranch_execz .LBB1_12
; %bb.11:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s0, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v5, s0
.LBB1_12:
	s_or_b32 exec_lo, exec_lo, s1
	v_lshrrev_b32_e32 v3, 3, v0
	v_cmp_gt_u32_e32 vcc_lo, 32, v0
	s_mov_b32 s11, 0
	v_and_b32_e32 v6, 7, v0
	v_mov_b32_e32 v12, 0
	global_load_u8 v3, v3, s[8:9]
	v_cndmask_b32_e32 v1, -1, v1, vcc_lo
	v_mov_b32_e32 v7, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_and_b32_e32 v1, s10, v1
	v_bcnt_u32_b32 v1, v1, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v1, v2, v1, v4
	v_add_lshl_u32 v1, v5, v1, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_mad_u32_u24 v1, v0, 36, v1
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v5, s0, s8, v1
	s_waitcnt vmcnt(0)
	v_bfe_u32 v2, v3, v6, 1
	v_add_co_ci_u32_e64 v6, null, s9, 0, s0
	s_lshl_b32 s0, s2, 7
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	s_ashr_i32 s1, s0, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	s_lshl_b64 s[2:3], s[0:1], 2
	v_cndmask_b32_e64 v4, 3, 2, vcc_lo
	s_add_u32 s1, s4, s2
	s_addc_u32 s10, s5, s3
	s_mov_b64 s[2:3], 0
	v_lshlrev_b32_e32 v2, 4, v4
	v_sub_nc_u32_e32 v8, 8, v4
	v_lshlrev_b32_e32 v10, 2, v4
	v_lshlrev_b32_e32 v11, 1, v4
	v_mul_u32_u24_e32 v13, 3, v4
	v_add_co_u32 v1, vcc_lo, v5, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v6, vcc_lo
	global_load_b32 v3, v[1:2], off offset:16
	v_lshlrev_b32_e64 v1, v4, -1
	v_not_b32_e32 v9, v1
	s_branch .LBB1_14
.LBB1_13:                               ;   in Loop: Header=BB1_14 Depth=1
	s_or_b32 exec_lo, exec_lo, s13
	v_and_b32_e32 v1, 4, v7
	v_and_b32_e32 v2, 0xff, v15
	s_load_b32 s4, s[4:5], 0xc
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s11, s8
	s_add_u32 s2, s2, 16
	s_addc_u32 s3, s3, 0
	v_lshrrev_b32_e32 v1, v1, v2
	v_and_b32_e32 v2, v14, v9
	v_and_b32_e32 v14, v16, v9
	s_add_f32 s5, s5, s9
	s_cmpk_eq_i32 s2, 0x200
	v_add_nc_u32_e32 v7, v7, v10
	v_cvt_f32_ubyte0_e32 v2, v2
	v_cvt_f32_ubyte0_e32 v14, v14
	v_and_b32_e32 v1, v1, v9
	s_add_f32 s5, s5, s12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(SALU_CYCLE_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	s_add_f32 s11, s5, s4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v12, s8, v1
	v_dual_fmac_f32 v12, s9, v2 :: v_dual_and_b32 v1, v17, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_fmac_f32_e32 v12, s12, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v12, s4, v1
	s_cbranch_scc1 .LBB1_20
.LBB1_14:                               ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v16, v4, v7
	v_lshrrev_b32_e32 v14, 3, v7
	s_add_u32 s4, s1, s2
	s_addc_u32 s5, s10, s3
	s_mov_b32 s8, exec_lo
	v_lshrrev_b32_e32 v1, 3, v16
	v_and_b32_e32 v16, 7, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v5, v1
	v_add_co_ci_u32_e64 v2, null, 0, v6, vcc_lo
	v_add_co_u32 v14, vcc_lo, v5, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_u8 v17, v[1:2], off offset:16
	global_load_d16_u8 v15, v[14:15], off offset:16
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v14, v16, v17
	v_cmpx_gt_u32_e64 v16, v8
	s_cbranch_execz .LBB1_16
; %bb.15:                               ;   in Loop: Header=BB1_14 Depth=1
	global_load_u8 v1, v[1:2], off offset:17
	v_sub_nc_u32_e32 v2, 8, v16
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v14, v1, v2, v14
.LBB1_16:                               ;   in Loop: Header=BB1_14 Depth=1
	s_or_b32 exec_lo, exec_lo, s8
	v_add_nc_u32_e32 v16, v11, v7
	s_load_b64 s[8:9], s[4:5], 0x0
	s_mov_b32 s12, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v16
	v_and_b32_e32 v17, 6, v16
	v_add_co_u32 v1, vcc_lo, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v6, vcc_lo
	global_load_u8 v18, v[1:2], off offset:16
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v16, v17, v18
	v_cmpx_gt_u32_e64 v17, v8
	s_cbranch_execz .LBB1_18
; %bb.17:                               ;   in Loop: Header=BB1_14 Depth=1
	global_load_u8 v1, v[1:2], off offset:17
	v_sub_nc_u32_e32 v2, 8, v17
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v16, v1, v2, v16
.LBB1_18:                               ;   in Loop: Header=BB1_14 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
	v_add_nc_u32_e32 v17, v13, v7
	s_load_b32 s12, s[4:5], 0x8
	s_mov_b32 s13, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v17
	v_and_b32_e32 v18, 7, v17
	v_add_co_u32 v1, vcc_lo, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v6, vcc_lo
	global_load_u8 v19, v[1:2], off offset:16
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v17, v18, v19
	v_cmpx_gt_u32_e64 v18, v8
	s_cbranch_execz .LBB1_13
; %bb.19:                               ;   in Loop: Header=BB1_14 Depth=1
	global_load_u8 v1, v[1:2], off offset:17
	v_sub_nc_u32_e32 v2, 8, v18
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v17, v1, v2, v17
	s_branch .LBB1_13
.LBB1_20:
	v_add_nc_u32_e32 v0, s0, v0
	v_cvt_f32_f16_e32 v2, v3.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_ashrrev_i32_e32 v1, 31, v0
	v_mul_f32_e32 v2, v12, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	v_fma_mix_f32 v2, s11, v3, v2 op_sel:[0,1,0] op_sel_hi:[0,1,0]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s6, v0
	v_add_co_ci_u32_e64 v1, null, s7, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z13scalar_readerPKfPfPKh
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 24
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
		.amdhsa_next_free_vgpr 20
		.amdhsa_next_free_sgpr 14
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
		.amdhsa_inst_pref_size 9
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end1:
	.size	_Z13scalar_readerPKfPfPKh, .Lfunc_end1-_Z13scalar_readerPKfPfPKh
                                        ; -- End function
	.set _Z13scalar_readerPKfPfPKh.num_vgpr, 20
	.set _Z13scalar_readerPKfPfPKh.num_agpr, 0
	.set _Z13scalar_readerPKfPfPKh.numbered_sgpr, 14
	.set _Z13scalar_readerPKfPfPKh.num_named_barrier, 0
	.set _Z13scalar_readerPKfPfPKh.private_seg_size, 0
	.set _Z13scalar_readerPKfPfPKh.uses_vcc, 1
	.set _Z13scalar_readerPKfPfPKh.uses_flat_scratch, 0
	.set _Z13scalar_readerPKfPfPKh.has_dyn_sized_stack, 0
	.set _Z13scalar_readerPKfPfPKh.has_recursion, 0
	.set _Z13scalar_readerPKfPfPKh.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 1068
; TotalNumSgprs: 16
; NumVgprs: 20
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 16
; NumVGPRsForWavesPerEU: 20
; Occupancy: 16
; WaveLimiterHint : 0
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
	.set amdgpu.max_num_vgpr, 0
	.set amdgpu.max_num_agpr, 0
	.set amdgpu.max_num_sgpr, 0
	.text
	.type	__hip_cuid_ac48ee5d87994f7f,@object ; @__hip_cuid_ac48ee5d87994f7f
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_ac48ee5d87994f7f
__hip_cuid_ac48ee5d87994f7f:
	.byte	0                               ; 0x0
	.size	__hip_cuid_ac48ee5d87994f7f, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __hip_cuid_ac48ee5d87994f7f
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
      - .address_space:  global
        .offset:         32
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 1024
    .kernarg_segment_align: 8
    .kernarg_segment_size: 40
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z11quip_readerPKfPfPKhPKjPK6__half
    .private_segment_fixed_size: 0
    .sgpr_count:     32
    .sgpr_spill_count: 0
    .symbol:         _Z11quip_readerPKfPfPKhPKjPK6__half.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     91
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
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 24
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z13scalar_readerPKfPfPKh
    .private_segment_fixed_size: 0
    .sgpr_count:     16
    .sgpr_spill_count: 0
    .symbol:         _Z13scalar_readerPKfPfPKh.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     20
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
