	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.section	.text._Z9flush_keyILb0EEvPKtPKDF16_Ph,"axG",@progbits,_Z9flush_keyILb0EEvPKtPKDF16_Ph,comdat
	.protected	_Z9flush_keyILb0EEvPKtPKDF16_Ph ; -- Begin function _Z9flush_keyILb0EEvPKtPKDF16_Ph
	.globl	_Z9flush_keyILb0EEvPKtPKDF16_Ph
	.p2align	8
	.type	_Z9flush_keyILb0EEvPKtPKDF16_Ph,@function
_Z9flush_keyILb0EEvPKtPKDF16_Ph:        ; @_Z9flush_keyILb0EEvPKtPKDF16_Ph
; %bb.0:
	s_load_b64 s[4:5], s[0:1], 0x0
	v_lshlrev_b32_e32 v3, 1, v0
	s_waitcnt lgkmcnt(0)
	s_clause 0xf
	global_load_u16 v5, v3, s[4:5] offset:256
	global_load_u16 v6, v3, s[4:5]
	global_load_u16 v7, v3, s[4:5] offset:512
	global_load_u16 v8, v3, s[4:5] offset:768
	global_load_u16 v9, v3, s[4:5] offset:1024
	global_load_u16 v10, v3, s[4:5] offset:1280
	global_load_u16 v11, v3, s[4:5] offset:1536
	global_load_u16 v12, v3, s[4:5] offset:1792
	global_load_u16 v13, v3, s[4:5] offset:2048
	global_load_u16 v14, v3, s[4:5] offset:2304
	global_load_u16 v15, v3, s[4:5] offset:2560
	global_load_u16 v16, v3, s[4:5] offset:2816
	global_load_u16 v17, v3, s[4:5] offset:3072
	global_load_u16 v18, v3, s[4:5] offset:3328
	global_load_u16 v19, v3, s[4:5] offset:3584
	global_load_u16 v20, v3, s[4:5] offset:3840
	v_add_co_u32 v1, s2, s4, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, s5, 0, s2
	v_add_co_u32 v3, vcc_lo, 0x1000, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v2, vcc_lo
	s_clause 0xf
	global_load_u16 v21, v[3:4], off
	global_load_u16 v22, v[3:4], off offset:256
	global_load_u16 v23, v[3:4], off offset:512
	global_load_u16 v24, v[3:4], off offset:768
	global_load_u16 v25, v[3:4], off offset:1024
	global_load_u16 v26, v[3:4], off offset:1280
	global_load_u16 v27, v[3:4], off offset:1536
	global_load_u16 v28, v[3:4], off offset:1792
	global_load_u16 v29, v[3:4], off offset:2048
	global_load_u16 v30, v[3:4], off offset:2304
	global_load_u16 v31, v[3:4], off offset:2560
	global_load_u16 v32, v[3:4], off offset:2816
	global_load_u16 v33, v[3:4], off offset:3072
	global_load_u16 v34, v[3:4], off offset:3328
	global_load_u16 v35, v[3:4], off offset:3584
	global_load_u16 v3, v[3:4], off offset:3840
	s_waitcnt vmcnt(31)
	v_lshlrev_b32_e32 v4, 16, v5
	s_waitcnt vmcnt(30)
	v_lshlrev_b32_e32 v5, 16, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v5, v4
	s_waitcnt vmcnt(29)
	v_dual_cndmask_b32 v7, v5, v4 :: v_dual_lshlrev_b32 v6, 16, v7
	v_cmp_lt_f32_e32 vcc_lo, v5, v4
	v_cndmask_b32_e32 v4, v5, v4, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	s_waitcnt vmcnt(27)
	v_lshlrev_b32_e32 v6, 16, v9
	v_lshlrev_b32_e32 v5, 16, v8
	s_waitcnt vmcnt(3)
	v_lshlrev_b32_e32 v9, 16, v33
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v10
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v11
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_lshlrev_b32_e32 v11, 16, v31
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_lshlrev_b32_e32 v12, 16, v30
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_4) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_lshlrev_b32_e32 v13, 16, v28
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v14
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v15
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v16
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v17
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v18
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v19
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v20
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v21
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v22
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v23
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v24
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v25
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v26
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v27
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_cndmask_b32_e32 v4, v4, v5, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v5, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v29
	v_cmp_gt_f32_e32 vcc_lo, v5, v13
	v_cndmask_b32_e32 v5, v5, v13, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v13
	v_cndmask_b32_e32 v4, v4, v13, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v6
	v_cndmask_b32_e32 v5, v5, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v12
	v_cndmask_b32_e32 v5, v5, v12, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v12
	v_cndmask_b32_e32 v4, v4, v12, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v11
	v_dual_cndmask_b32 v5, v5, v11 :: v_dual_lshlrev_b32 v10, 16, v32
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v11
	v_cndmask_b32_e32 v4, v4, v11, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v10
	v_cndmask_b32_e32 v5, v5, v10, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v10
	v_cndmask_b32_e32 v4, v4, v10, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v9
	v_cndmask_b32_e32 v5, v5, v9, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_cmp_lt_f32_e32 vcc_lo, v4, v9
	s_waitcnt vmcnt(1)
	v_dual_cndmask_b32 v4, v4, v9 :: v_dual_lshlrev_b32 v7, 16, v35
	v_lshlrev_b32_e32 v8, 16, v34
	v_cmp_gt_f32_e32 vcc_lo, v5, v8
	v_cndmask_b32_e32 v5, v5, v8, vcc_lo
	s_delay_alu instid0(VALU_DEP_4)
	v_cmp_lt_f32_e32 vcc_lo, v4, v8
	v_cndmask_b32_e32 v6, v4, v8, vcc_lo
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v4, 16, v3
	v_cmp_gt_f32_e32 vcc_lo, v5, v7
	v_cndmask_b32_e32 v3, v5, v7, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v6, v7
	v_cndmask_b32_e32 v6, v6, v7, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v3, v4
	v_cndmask_b32_e32 v5, v3, v4, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v6, v4
	v_cndmask_b32_e32 v3, v6, v4, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v3, v3, v5
	v_div_scale_f32 v6, null, 0x41700000, 0x41700000, v3
	v_div_scale_f32 v16, vcc_lo, v3, 0x41700000, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v14, v6
	v_fma_f32 v15, -v6, v14, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v14, v15, v14
	v_mul_f32_e32 v15, v16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v6, v15, v16
	v_fmac_f32_e32 v15, v17, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v6, -v6, v15, v16
	v_div_fmas_f32 v6, v6, v14, v15
	v_mov_b32_e32 v14, 0
	v_cvt_f16_f32_e32 v15.l, v5
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v6, v6, 0x41700000, v3
	v_lshlrev_b32_e32 v3, 2, v0
	v_cvt_f16_f32_e32 v15.h, v6
	v_cmp_lt_f32_e64 s2, 0, v6
	s_delay_alu instid0(VALU_DEP_2)
	v_pack_b32_f16 v16, v15.l, v15.h
	v_mov_b32_e32 v15, 0
	ds_store_b32 v3, v16 offset:4096
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_2
; %bb.1:
	global_load_u16 v15, v[1:2], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_2:                                ; %._crit_edge.i
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_4
; %bb.3:
	global_load_u16 v14, v[1:2], off offset:256
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_4:                                ; %._crit_edge.i.1
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:128
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_6
; %bb.5:
	global_load_u16 v15, v[1:2], off offset:512
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_6:                                ; %._crit_edge.i.2
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:256
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_8
; %bb.7:
	global_load_u16 v14, v[1:2], off offset:768
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_8:                                ; %._crit_edge.i.3
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:384
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_10
; %bb.9:
	global_load_u16 v15, v[1:2], off offset:1024
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_10:                               ; %._crit_edge.i.4
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:512
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_12
; %bb.11:
	global_load_u16 v14, v[1:2], off offset:1280
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_12:                               ; %._crit_edge.i.5
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:640
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_14
; %bb.13:
	global_load_u16 v15, v[1:2], off offset:1536
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_14:                               ; %._crit_edge.i.6
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:768
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_16
; %bb.15:
	global_load_u16 v14, v[1:2], off offset:1792
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_16:                               ; %._crit_edge.i.7
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:896
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_18
; %bb.17:
	global_load_u16 v15, v[1:2], off offset:2048
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_18:                               ; %._crit_edge.i.8
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:1024
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_20
; %bb.19:
	global_load_u16 v14, v[1:2], off offset:2304
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_20:                               ; %._crit_edge.i.9
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:1152
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_22
; %bb.21:
	global_load_u16 v15, v[1:2], off offset:2560
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_22:                               ; %._crit_edge.i.10
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:1280
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_24
; %bb.23:
	global_load_u16 v14, v[1:2], off offset:2816
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_24:                               ; %._crit_edge.i.11
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:1408
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_26
; %bb.25:
	global_load_u16 v15, v[1:2], off offset:3072
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_26:                               ; %._crit_edge.i.12
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:1536
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_28
; %bb.27:
	global_load_u16 v14, v[1:2], off offset:3328
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_28:                               ; %._crit_edge.i.13
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:1664
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_30
; %bb.29:
	global_load_u16 v15, v[1:2], off offset:3584
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_30:                               ; %._crit_edge.i.14
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:1792
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_32
; %bb.31:
	global_load_u16 v14, v[1:2], off offset:3840
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v5
	v_div_scale_f32 v15, null, v6, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v6, v14
	v_rndne_f32_e32 v14, v14
.LBB0_32:                               ; %._crit_edge.i.15
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:1920
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_34
; %bb.33:
	v_lshl_or_b32 v15, v0, 1, 0x1000
	global_load_u16 v15, v15, s[4:5]
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v15, v15, v5
	v_div_scale_f32 v16, null, v6, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	v_mul_f32_e32 v19, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v19, v18
	v_fmac_f32_e32 v19, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v19, v18
	v_div_fmas_f32 v16, v16, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v15, v16, v6, v15
	v_rndne_f32_e32 v15, v15
.LBB0_34:                               ; %._crit_edge.i.16
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:2048
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_36
; %bb.35:
	v_add_co_u32 v14, vcc_lo, 0x1100, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v2, vcc_lo
	global_load_u16 v14, v[14:15], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	v_sub_f32_e32 v14, v14, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v15, null, v6, v6, v14
	v_rcp_f32_e32 v16, v15
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v15, v16, 1.0
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v18, v17, v16
	v_fma_f32 v19, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v18, v19, v16
	v_fma_f32 v15, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v15, v15, v16, v18
	v_div_fixup_f32 v14, v15, v6, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v14, v14
.LBB0_36:                               ; %._crit_edge.i.17
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:2176
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_38
; %bb.37:
	v_add_co_u32 v15, vcc_lo, 0x1200, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v16, null, 0, v2, vcc_lo
	global_load_u16 v15, v[15:16], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	v_sub_f32_e32 v15, v15, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v16, null, v6, v6, v15
	v_rcp_f32_e32 v17, v16
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v16, v17, 1.0
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v19, v18, v17
	v_fma_f32 v20, -v16, v19, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v19, v20, v17
	v_fma_f32 v16, -v16, v19, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v16, v16, v17, v19
	v_div_fixup_f32 v15, v16, v6, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v15, v15
.LBB0_38:                               ; %._crit_edge.i.18
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:2304
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_40
; %bb.39:
	v_add_co_u32 v14, vcc_lo, 0x1300, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v2, vcc_lo
	global_load_u16 v14, v[14:15], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	v_sub_f32_e32 v14, v14, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v15, null, v6, v6, v14
	v_rcp_f32_e32 v16, v15
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v15, v16, 1.0
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v18, v17, v16
	v_fma_f32 v19, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v18, v19, v16
	v_fma_f32 v15, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v15, v15, v16, v18
	v_div_fixup_f32 v14, v15, v6, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v14, v14
.LBB0_40:                               ; %._crit_edge.i.19
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:2432
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_42
; %bb.41:
	v_add_co_u32 v15, vcc_lo, 0x1400, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v16, null, 0, v2, vcc_lo
	global_load_u16 v15, v[15:16], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v15, 16, v15
	v_sub_f32_e32 v15, v15, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v16, null, v6, v6, v15
	v_rcp_f32_e32 v17, v16
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v16, v17, 1.0
	v_fmac_f32_e32 v17, v18, v17
	v_div_scale_f32 v18, vcc_lo, v15, v6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v19, v18, v17
	v_fma_f32 v20, -v16, v19, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v19, v20, v17
	v_fma_f32 v16, -v16, v19, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v16, v16, v17, v19
	v_div_fixup_f32 v15, v16, v6, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v15, v15
.LBB0_42:                               ; %._crit_edge.i.20
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v15, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v15
	v_cndmask_b32_e32 v15, 0x41700000, v15, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v15
	ds_store_b8 v0, v15 offset:2560
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_44
; %bb.43:
	v_add_co_u32 v14, vcc_lo, 0x1500, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v2, vcc_lo
	global_load_u16 v14, v[14:15], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	v_sub_f32_e32 v14, v14, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v15, null, v6, v6, v14
	v_rcp_f32_e32 v16, v15
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v15, v16, 1.0
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v6, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v18, v17, v16
	v_fma_f32 v19, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v18, v19, v16
	v_fma_f32 v15, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v15, v15, v16, v18
	v_div_fixup_f32 v14, v15, v6, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v14, v14
.LBB0_44:                               ; %._crit_edge.i.21
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_dual_cndmask_b32 v15, 0x41700000, v14 :: v_dual_mov_b32 v14, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v16, v15
	v_mov_b32_e32 v15, 0
	ds_store_b8 v0, v16 offset:2688
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_46
; %bb.45:
	v_add_co_u32 v1, vcc_lo, 0x1600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	global_load_u16 v1, v[1:2], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v1, 16, v1
	v_sub_f32_e32 v1, v1, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v6, v6, v1
	v_rcp_f32_e32 v15, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v2, v15, 1.0
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v1, v6, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v17, v16, v15
	v_fma_f32 v18, -v2, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v15
	v_fma_f32 v2, -v2, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v15, v17
	v_div_fixup_f32 v1, v2, v6, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v15, v1
.LBB0_46:                               ; %._crit_edge.i.22
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v15
	v_cndmask_b32_e32 v1, 0, v15, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_cndmask_b32_e32 v1, 0x41700000, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v1, v1
	ds_store_b8 v0, v1 offset:2816
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_48
; %bb.47:
	v_sub_f32_e32 v1, v13, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v6, v6, v1
	v_rcp_f32_e32 v13, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v2, v13, 1.0
	v_fmac_f32_e32 v13, v14, v13
	v_div_scale_f32 v14, vcc_lo, v1, v6, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v15, v14, v13
	v_fma_f32 v16, -v2, v15, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v13
	v_fma_f32 v2, -v2, v15, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v13, v15
	v_div_fixup_f32 v1, v2, v6, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v14, v1
.LBB0_48:                               ; %._crit_edge.i.23
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v1, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v13, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v13 offset:2944
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_50
; %bb.49:
	v_lshl_or_b32 v2, v0, 1, 0x1800
	global_load_u16 v2, v2, s[4:5]
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v2, 16, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v2, v2, v5
	v_div_scale_f32 v13, null, v6, v6, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v14, v13
	v_fma_f32 v15, -v13, v14, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v14, v15, v14
	v_div_scale_f32 v15, vcc_lo, v2, v6, v2
	v_mul_f32_e32 v16, v15, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v13, v16, v15
	v_fmac_f32_e32 v16, v17, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v13, -v13, v16, v15
	v_div_fmas_f32 v13, v13, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v2, v13, v6, v2
	v_rndne_f32_e32 v2, v2
.LBB0_50:                               ; %._crit_edge.i.24
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3072
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_52
; %bb.51:
	v_sub_f32_e32 v1, v12, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v6, v6, v1
	v_rcp_f32_e32 v12, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v13, -v2, v12, 1.0
	v_fmac_f32_e32 v12, v13, v12
	v_div_scale_f32 v13, vcc_lo, v1, v6, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v14, v13, v12
	v_fma_f32 v15, -v2, v14, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v14, v15, v12
	v_fma_f32 v2, -v2, v14, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v12, v14
	v_div_fixup_f32 v1, v2, v6, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB0_52:                               ; %._crit_edge.i.25
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v12, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v12 offset:3200
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_54
; %bb.53:
	v_sub_f32_e32 v2, v11, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v11, null, v6, v6, v2
	v_rcp_f32_e32 v12, v11
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v13, -v11, v12, 1.0
	v_fmac_f32_e32 v12, v13, v12
	v_div_scale_f32 v13, vcc_lo, v2, v6, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v14, v13, v12
	v_fma_f32 v15, -v11, v14, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v14, v15, v12
	v_fma_f32 v11, -v11, v14, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v11, v11, v12, v14
	v_div_fixup_f32 v2, v11, v6, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v2, v2
.LBB0_54:                               ; %._crit_edge.i.26
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3328
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_56
; %bb.55:
	v_sub_f32_e32 v1, v10, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v6, v6, v1
	v_rcp_f32_e32 v10, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v11, -v2, v10, 1.0
	v_fmac_f32_e32 v10, v11, v10
	v_div_scale_f32 v11, vcc_lo, v1, v6, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v12, v11, v10
	v_fma_f32 v13, -v2, v12, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v12, v13, v10
	v_fma_f32 v2, -v2, v12, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v10, v12
	v_div_fixup_f32 v1, v2, v6, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB0_56:                               ; %._crit_edge.i.27
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v10, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v10 offset:3456
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_58
; %bb.57:
	v_sub_f32_e32 v2, v9, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v9, null, v6, v6, v2
	v_rcp_f32_e32 v10, v9
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v11, -v9, v10, 1.0
	v_fmac_f32_e32 v10, v11, v10
	v_div_scale_f32 v11, vcc_lo, v2, v6, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v12, v11, v10
	v_fma_f32 v13, -v9, v12, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v12, v13, v10
	v_fma_f32 v9, -v9, v12, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v9, v9, v10, v12
	v_div_fixup_f32 v2, v9, v6, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v2, v2
.LBB0_58:                               ; %._crit_edge.i.28
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3584
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_60
; %bb.59:
	v_sub_f32_e32 v1, v8, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v6, v6, v1
	v_rcp_f32_e32 v8, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v9, -v2, v8, 1.0
	v_fmac_f32_e32 v8, v9, v8
	v_div_scale_f32 v9, vcc_lo, v1, v6, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v10, v9, v8
	v_fma_f32 v11, -v2, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v10, v11, v8
	v_fma_f32 v2, -v2, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v8, v10
	v_div_fixup_f32 v1, v2, v6, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB0_60:                               ; %._crit_edge.i.29
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v8, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v8 offset:3712
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_62
; %bb.61:
	v_sub_f32_e32 v2, v7, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v7, null, v6, v6, v2
	v_rcp_f32_e32 v8, v7
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v9, -v7, v8, 1.0
	v_fmac_f32_e32 v8, v9, v8
	v_div_scale_f32 v9, vcc_lo, v2, v6, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v10, v9, v8
	v_fma_f32 v11, -v7, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v10, v11, v8
	v_fma_f32 v7, -v7, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v7, v7, v8, v10
	v_div_fixup_f32 v2, v7, v6, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v2, v2
.LBB0_62:                               ; %._crit_edge.i.30
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	s_load_b64 s[0:1], s[0:1], 0x10
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3840
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_64
; %bb.63:
	v_sub_f32_e32 v1, v4, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v6, v6, v1
	v_rcp_f32_e32 v4, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v5, -v2, v4, 1.0
	v_fmac_f32_e32 v4, v5, v4
	v_div_scale_f32 v5, vcc_lo, v1, v6, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v7, v5, v4
	v_fma_f32 v8, -v2, v7, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v7, v8, v4
	v_fma_f32 v2, -v2, v7, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v4, v7
	v_div_fixup_f32 v1, v2, v6, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB0_64:                               ; %._crit_edge.i.31
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	s_mov_b32 s4, 0
	s_mov_b32 s5, exec_lo
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_cndmask_b32_e32 v1, 0x41700000, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v1, v1
	ds_store_b8 v0, v1 offset:3968
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmpx_gt_u32_e32 32, v0
	s_cbranch_execz .LBB0_67
; %bb.65:                               ; %vector.ph
	v_lshlrev_b32_e32 v1, 6, v0
	v_mad_u32_u24 v0, 0x7f, v0, v0
	v_mov_b16_e32 v13.l, 0
	s_mov_b32 s6, 3
	s_mov_b32 s7, 2
	v_add_co_u32 v1, s2, s0, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s1, 0, s2
	s_mov_b32 s8, 1
	s_mov_b64 s[2:3], 0
.LBB0_66:                               ; %vector.body
                                        ; =>This Inner Loop Header: Depth=1
	v_lshl_add_u32 v7, s4, 1, v0
	v_lshl_add_u32 v6, s7, 1, v0
	v_lshl_add_u32 v9, s6, 1, v0
	v_lshl_add_u32 v8, s8, 1, v0
	v_mov_b16_e32 v14.h, v13.l
	ds_load_u16_d16 v4, v7
	s_waitcnt lgkmcnt(0)
	ds_load_u16_d16_hi v4, v6
	ds_load_u16_d16 v5, v9
	s_waitcnt lgkmcnt(0)
	ds_load_u16_d16_hi v5, v6 offset:8
	ds_load_u16_d16 v6, v8
	ds_load_u16_d16_hi v12, v9 offset:8
	ds_load_u16_d16_hi v13, v8 offset:8
	s_waitcnt lgkmcnt(2)
	ds_load_u16_d16_hi v6, v7 offset:8
	v_add_co_u32 v11, vcc_lo, v1, s2
	s_add_i32 s4, s4, 8
	s_add_i32 s8, s8, 8
	s_add_i32 s7, s7, 8
	s_add_i32 s6, s6, 8
	s_add_u32 s2, s2, 8
	v_lshrrev_b16 v7.l, 4, v4.l
	v_lshrrev_b16 v7.h, 4, v4.h
	v_lshlrev_b16 v8.l, 8, v5.l
	v_lshlrev_b16 v5.l, 4, v5.l
	s_waitcnt lgkmcnt(0)
	v_lshlrev_b16 v8.h, 8, v6.l
	v_lshlrev_b16 v6.l, 4, v6.l
	v_lshrrev_b32_e32 v10, 20, v13
	v_lshrrev_b16 v9.l, 4, v6.h
	v_lshrrev_b32_e32 v15, 20, v12
	v_lshrrev_b16 v9.h, 4, v5.h
	v_and_b16 v7.l, 0xf0, v7.l
	v_and_b16 v7.h, 0xf0, v7.h
	v_and_b16 v5.l, 0xf000, v5.l
	v_and_b16 v6.l, 0xf000, v6.l
	v_and_b16 v10.l, 0xf0, v10.l
	v_and_b16 v9.l, 0xf0, v9.l
	v_and_b16 v10.h, 0xf0, v15.l
	v_and_b16 v9.h, 0xf0, v9.h
	v_or_b16 v4.h, v7.h, v4.h
	v_or_b16 v4.l, v7.l, v4.l
	v_or_b16 v5.l, v5.l, v8.l
	v_or_b16 v6.l, v6.l, v8.h
	v_or_b16 v5.h, v9.h, v5.h
	v_or_b16 v7.l, v10.h, v12.h
	v_or_b16 v6.h, v9.l, v6.h
	v_or_b16 v7.h, v10.l, v13.h
	v_and_b16 v4.h, 0xff, v4.h
	v_and_b16 v4.l, 0xff, v4.l
	v_and_b16 v5.h, 0xff, v5.h
	v_lshlrev_b16 v7.l, 8, v7.l
	v_and_b16 v6.h, 0xff, v6.h
	v_lshlrev_b16 v7.h, 8, v7.h
	v_or_b16 v13.h, v4.h, v5.l
	v_or_b16 v14.l, v4.l, v6.l
	v_mov_b16_e32 v8.h, v13.l
	v_add_co_ci_u32_e64 v12, null, s3, v2, vcc_lo
	v_or_b16 v8.l, v6.h, v7.h
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_or_b32_e32 v4, v14, v13
	v_or_b16 v13.h, v5.h, v7.l
	s_addc_u32 s3, s3, 0
	s_cmp_lg_u32 s2, 64
	v_or_b32_e32 v5, v8, v13
	global_store_b64 v[11:12], v[4:5], off
	s_cbranch_scc1 .LBB0_66
.LBB0_67:                               ; %Flow41
	s_or_b32 exec_lo, exec_lo, s5
	ds_load_b32 v0, v3 offset:4096
	s_waitcnt lgkmcnt(0)
	global_store_b32 v3, v0, s[0:1] offset:2048
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z9flush_keyILb0EEvPKtPKDF16_Ph
		.amdhsa_group_segment_fixed_size 4608
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
		.amdhsa_next_free_vgpr 36
		.amdhsa_next_free_sgpr 9
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
		.amdhsa_inst_pref_size 61
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z9flush_keyILb0EEvPKtPKDF16_Ph,"axG",@progbits,_Z9flush_keyILb0EEvPKtPKDF16_Ph,comdat
.Lfunc_end0:
	.size	_Z9flush_keyILb0EEvPKtPKDF16_Ph, .Lfunc_end0-_Z9flush_keyILb0EEvPKtPKDF16_Ph
                                        ; -- End function
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.num_vgpr, 36
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.num_agpr, 0
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.numbered_sgpr, 9
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.num_named_barrier, 0
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.private_seg_size, 0
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.uses_vcc, 1
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.uses_flat_scratch, 0
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.has_dyn_sized_stack, 0
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.has_recursion, 0
	.set _Z9flush_keyILb0EEvPKtPKDF16_Ph.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 7684
; TotalNumSgprs: 11
; NumVgprs: 36
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 4608 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 11
; NumVGPRsForWavesPerEU: 36
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z9flush_keyILb1EEvPKtPKDF16_Ph,"axG",@progbits,_Z9flush_keyILb1EEvPKtPKDF16_Ph,comdat
	.protected	_Z9flush_keyILb1EEvPKtPKDF16_Ph ; -- Begin function _Z9flush_keyILb1EEvPKtPKDF16_Ph
	.globl	_Z9flush_keyILb1EEvPKtPKDF16_Ph
	.p2align	8
	.type	_Z9flush_keyILb1EEvPKtPKDF16_Ph,@function
_Z9flush_keyILb1EEvPKtPKDF16_Ph:        ; @_Z9flush_keyILb1EEvPKtPKDF16_Ph
; %bb.0:
	s_load_b64 s[4:5], s[0:1], 0x0
	v_lshlrev_b32_e32 v3, 1, v0
	s_waitcnt lgkmcnt(0)
	s_clause 0xf
	global_load_u16 v5, v3, s[4:5] offset:256
	global_load_u16 v6, v3, s[4:5]
	global_load_u16 v7, v3, s[4:5] offset:512
	global_load_u16 v8, v3, s[4:5] offset:768
	global_load_u16 v9, v3, s[4:5] offset:1024
	global_load_u16 v10, v3, s[4:5] offset:1280
	global_load_u16 v11, v3, s[4:5] offset:1536
	global_load_u16 v12, v3, s[4:5] offset:1792
	global_load_u16 v13, v3, s[4:5] offset:2048
	global_load_u16 v14, v3, s[4:5] offset:2304
	global_load_u16 v15, v3, s[4:5] offset:2560
	global_load_u16 v16, v3, s[4:5] offset:2816
	global_load_u16 v17, v3, s[4:5] offset:3072
	global_load_u16 v18, v3, s[4:5] offset:3328
	global_load_u16 v19, v3, s[4:5] offset:3584
	global_load_u16 v20, v3, s[4:5] offset:3840
	v_add_co_u32 v1, s2, s4, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, s5, 0, s2
	v_add_co_u32 v3, vcc_lo, 0x1000, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v2, vcc_lo
	s_clause 0xf
	global_load_u16 v21, v[3:4], off
	global_load_u16 v22, v[3:4], off offset:256
	global_load_u16 v23, v[3:4], off offset:512
	global_load_u16 v24, v[3:4], off offset:768
	global_load_u16 v25, v[3:4], off offset:1024
	global_load_u16 v26, v[3:4], off offset:1280
	global_load_u16 v27, v[3:4], off offset:1536
	global_load_u16 v28, v[3:4], off offset:1792
	global_load_u16 v29, v[3:4], off offset:2048
	global_load_u16 v30, v[3:4], off offset:2304
	global_load_u16 v31, v[3:4], off offset:2560
	global_load_u16 v32, v[3:4], off offset:2816
	global_load_u16 v33, v[3:4], off offset:3072
	global_load_u16 v34, v[3:4], off offset:3328
	global_load_u16 v35, v[3:4], off offset:3584
	global_load_u16 v3, v[3:4], off offset:3840
	s_waitcnt vmcnt(31)
	v_lshlrev_b32_e32 v4, 16, v5
	s_waitcnt vmcnt(30)
	v_lshlrev_b32_e32 v5, 16, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v5, v4
	s_waitcnt vmcnt(29)
	v_dual_cndmask_b32 v7, v5, v4 :: v_dual_lshlrev_b32 v6, 16, v7
	v_cmp_lt_f32_e32 vcc_lo, v5, v4
	v_cndmask_b32_e32 v4, v5, v4, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	s_waitcnt vmcnt(0)
	v_dual_cndmask_b32 v4, v4, v6 :: v_dual_lshlrev_b32 v3, 16, v3
	v_lshlrev_b32_e32 v6, 16, v9
	v_lshlrev_b32_e32 v5, 16, v8
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v10
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v11
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_dual_cndmask_b32 v7, v7, v6 :: v_dual_lshlrev_b32 v12, 16, v28
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v14
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v15
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v16
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v17
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v19
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_dual_cndmask_b32 v7, v7, v6 :: v_dual_lshlrev_b32 v20, 2, v0
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v21
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v22
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v23
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v24
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v25
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_dual_cndmask_b32 v4, v4, v5 :: v_dual_lshlrev_b32 v5, 16, v26
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v7, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_lshlrev_b32_e32 v6, 16, v27
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cmp_gt_f32_e32 vcc_lo, v7, v5
	v_cndmask_b32_e32 v7, v7, v5, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v5
	v_cndmask_b32_e32 v4, v4, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_gt_f32_e32 vcc_lo, v7, v6
	v_cndmask_b32_e32 v5, v7, v6, vcc_lo
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_lshlrev_b32_e32 v7, 16, v34
	v_lshlrev_b32_e32 v8, 16, v33
	v_lshlrev_b32_e32 v10, 16, v31
	v_lshlrev_b32_e32 v9, 16, v32
	v_lshlrev_b32_e32 v11, 16, v30
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v12
	v_dual_cndmask_b32 v5, v5, v12 :: v_dual_lshlrev_b32 v6, 16, v29
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v12
	v_cndmask_b32_e32 v4, v4, v12, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v6
	v_cndmask_b32_e32 v5, v5, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v4, v4, v6, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v11
	v_lshlrev_b32_e32 v6, 16, v35
	v_cndmask_b32_e32 v5, v5, v11, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v11
	v_cndmask_b32_e32 v4, v4, v11, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v10
	v_cndmask_b32_e32 v5, v5, v10, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v10
	v_cndmask_b32_e32 v4, v4, v10, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v9
	v_cndmask_b32_e32 v5, v5, v9, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v9
	v_cndmask_b32_e32 v4, v4, v9, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v8
	v_cndmask_b32_e32 v5, v5, v8, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v8
	v_cndmask_b32_e32 v4, v4, v8, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v7
	v_cndmask_b32_e32 v5, v5, v7, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v7
	v_cndmask_b32_e32 v4, v4, v7, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v6
	v_cndmask_b32_e32 v5, v5, v6, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f32_e32 vcc_lo, v4, v6
	v_cndmask_b32_e32 v13, v4, v6, vcc_lo
	v_cmp_gt_f32_e32 vcc_lo, v5, v3
	v_cndmask_b32_e32 v4, v5, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_lt_f32_e32 vcc_lo, v13, v3
	v_cndmask_b32_e32 v5, v13, v3, vcc_lo
	v_sub_f32_e32 v5, v5, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v13, null, 0x41700000, 0x41700000, v5
	v_div_scale_f32 v16, vcc_lo, v5, 0x41700000, v5
	v_rcp_f32_e32 v14, v13
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v13, v14, 1.0
	v_fmac_f32_e32 v14, v15, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v15, v16, v14
	v_fma_f32 v17, -v13, v15, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v17, v14
	v_fma_f32 v13, -v13, v15, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v13, v13, v14, v15
	v_cvt_f16_f32_e32 v14.l, v4
	v_div_fixup_f32 v5, v13, 0x41700000, v5
	v_mov_b32_e32 v13, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cvt_f16_f32_e32 v14.h, v5
	v_cmp_lt_f32_e64 s2, 0, v5
	v_pack_b32_f16 v15, v14.l, v14.h
	v_mov_b32_e32 v14, 0
	ds_store_b32 v20, v15 offset:4096
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_2
; %bb.1:
	global_load_u16 v14, v[1:2], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_2:                                ; %._crit_edge.i
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_4
; %bb.3:
	global_load_u16 v13, v[1:2], off offset:256
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_4:                                ; %._crit_edge.i.1
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:128
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_6
; %bb.5:
	global_load_u16 v14, v[1:2], off offset:512
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_6:                                ; %._crit_edge.i.2
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:256
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_8
; %bb.7:
	global_load_u16 v13, v[1:2], off offset:768
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_8:                                ; %._crit_edge.i.3
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:384
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_10
; %bb.9:
	global_load_u16 v14, v[1:2], off offset:1024
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_10:                               ; %._crit_edge.i.4
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:512
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_12
; %bb.11:
	global_load_u16 v13, v[1:2], off offset:1280
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_12:                               ; %._crit_edge.i.5
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:640
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_14
; %bb.13:
	global_load_u16 v14, v[1:2], off offset:1536
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_14:                               ; %._crit_edge.i.6
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:768
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_16
; %bb.15:
	global_load_u16 v13, v[1:2], off offset:1792
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_16:                               ; %._crit_edge.i.7
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:896
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_18
; %bb.17:
	global_load_u16 v14, v[1:2], off offset:2048
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_18:                               ; %._crit_edge.i.8
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:1024
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_20
; %bb.19:
	global_load_u16 v13, v[1:2], off offset:2304
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_20:                               ; %._crit_edge.i.9
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:1152
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_22
; %bb.21:
	global_load_u16 v14, v[1:2], off offset:2560
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_22:                               ; %._crit_edge.i.10
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:1280
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_24
; %bb.23:
	global_load_u16 v13, v[1:2], off offset:2816
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_24:                               ; %._crit_edge.i.11
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:1408
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_26
; %bb.25:
	global_load_u16 v14, v[1:2], off offset:3072
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_26:                               ; %._crit_edge.i.12
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:1536
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_28
; %bb.27:
	global_load_u16 v13, v[1:2], off offset:3328
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_28:                               ; %._crit_edge.i.13
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:1664
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_30
; %bb.29:
	global_load_u16 v14, v[1:2], off offset:3584
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_30:                               ; %._crit_edge.i.14
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:1792
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_32
; %bb.31:
	global_load_u16 v13, v[1:2], off offset:3840
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v13, v13, v4
	v_div_scale_f32 v14, null, v5, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v15, v14
	v_fma_f32 v16, -v14, v15, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	v_mul_f32_e32 v17, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v18, -v14, v17, v16
	v_fmac_f32_e32 v17, v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v14, v17, v16
	v_div_fmas_f32 v14, v14, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v13, v14, v5, v13
	v_rndne_f32_e32 v13, v13
.LBB1_32:                               ; %._crit_edge.i.15
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:1920
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_34
; %bb.33:
	v_lshl_or_b32 v14, v0, 1, 0x1000
	global_load_u16 v14, v14, s[4:5]
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v14, v14, v4
	v_div_scale_f32 v15, null, v5, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v16, v15
	v_fma_f32 v17, -v15, v16, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	v_mul_f32_e32 v18, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v15, v18, v17
	v_fmac_f32_e32 v18, v19, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v15, v18, v17
	v_div_fmas_f32 v15, v15, v16, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v15, v5, v14
	v_rndne_f32_e32 v14, v14
.LBB1_34:                               ; %._crit_edge.i.16
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:2048
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_36
; %bb.35:
	v_add_co_u32 v13, vcc_lo, 0x1100, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, 0, v2, vcc_lo
	global_load_u16 v13, v[13:14], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	v_sub_f32_e32 v13, v13, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v14, null, v5, v5, v13
	v_rcp_f32_e32 v15, v14
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v14, v15, 1.0
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v17, v16, v15
	v_fma_f32 v18, -v14, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v15
	v_fma_f32 v14, -v14, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v14, v14, v15, v17
	v_div_fixup_f32 v13, v14, v5, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v13, v13
.LBB1_36:                               ; %._crit_edge.i.17
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:2176
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_38
; %bb.37:
	v_add_co_u32 v14, vcc_lo, 0x1200, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v2, vcc_lo
	global_load_u16 v14, v[14:15], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	v_sub_f32_e32 v14, v14, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v15, null, v5, v5, v14
	v_rcp_f32_e32 v16, v15
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v15, v16, 1.0
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v18, v17, v16
	v_fma_f32 v19, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v18, v19, v16
	v_fma_f32 v15, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v15, v15, v16, v18
	v_div_fixup_f32 v14, v15, v5, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v14, v14
.LBB1_38:                               ; %._crit_edge.i.18
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:2304
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_40
; %bb.39:
	v_add_co_u32 v13, vcc_lo, 0x1300, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, 0, v2, vcc_lo
	global_load_u16 v13, v[13:14], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	v_sub_f32_e32 v13, v13, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v14, null, v5, v5, v13
	v_rcp_f32_e32 v15, v14
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v14, v15, 1.0
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v17, v16, v15
	v_fma_f32 v18, -v14, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v15
	v_fma_f32 v14, -v14, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v14, v14, v15, v17
	v_div_fixup_f32 v13, v14, v5, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v13, v13
.LBB1_40:                               ; %._crit_edge.i.19
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:2432
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_42
; %bb.41:
	v_add_co_u32 v14, vcc_lo, 0x1400, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v2, vcc_lo
	global_load_u16 v14, v[14:15], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v14, 16, v14
	v_sub_f32_e32 v14, v14, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v15, null, v5, v5, v14
	v_rcp_f32_e32 v16, v15
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v15, v16, 1.0
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, v5, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v18, v17, v16
	v_fma_f32 v19, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v18, v19, v16
	v_fma_f32 v15, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v15, v15, v16, v18
	v_div_fixup_f32 v14, v15, v5, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v14, v14
.LBB1_42:                               ; %._crit_edge.i.20
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v14, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v14
	v_cndmask_b32_e32 v14, 0x41700000, v14, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	ds_store_b8 v0, v14 offset:2560
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_44
; %bb.43:
	v_add_co_u32 v13, vcc_lo, 0x1500, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, 0, v2, vcc_lo
	global_load_u16 v13, v[13:14], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v13
	v_sub_f32_e32 v13, v13, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v14, null, v5, v5, v13
	v_rcp_f32_e32 v15, v14
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v14, v15, 1.0
	v_fmac_f32_e32 v15, v16, v15
	v_div_scale_f32 v16, vcc_lo, v13, v5, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v17, v16, v15
	v_fma_f32 v18, -v14, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v15
	v_fma_f32 v14, -v14, v17, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v14, v14, v15, v17
	v_div_fixup_f32 v13, v14, v5, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v13, v13
.LBB1_44:                               ; %._crit_edge.i.21
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v13, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v13
	v_dual_cndmask_b32 v14, 0x41700000, v13 :: v_dual_mov_b32 v13, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v15, v14
	v_mov_b32_e32 v14, 0
	ds_store_b8 v0, v15 offset:2688
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_46
; %bb.45:
	v_add_co_u32 v1, vcc_lo, 0x1600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	global_load_u16 v1, v[1:2], off
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v1, 16, v1
	v_sub_f32_e32 v1, v1, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v5, v5, v1
	v_rcp_f32_e32 v14, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v2, v14, 1.0
	v_fmac_f32_e32 v14, v15, v14
	v_div_scale_f32 v15, vcc_lo, v1, v5, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v16, v15, v14
	v_fma_f32 v17, -v2, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v16, v17, v14
	v_fma_f32 v2, -v2, v16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v14, v16
	v_div_fixup_f32 v1, v2, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v14, v1
.LBB1_46:                               ; %._crit_edge.i.22
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v14
	v_cndmask_b32_e32 v1, 0, v14, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_cndmask_b32_e32 v1, 0x41700000, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v1, v1
	ds_store_b8 v0, v1 offset:2816
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_48
; %bb.47:
	v_sub_f32_e32 v1, v12, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v5, v5, v1
	v_rcp_f32_e32 v12, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v13, -v2, v12, 1.0
	v_fmac_f32_e32 v12, v13, v12
	v_div_scale_f32 v13, vcc_lo, v1, v5, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v14, v13, v12
	v_fma_f32 v15, -v2, v14, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v14, v15, v12
	v_fma_f32 v2, -v2, v14, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v12, v14
	v_div_fixup_f32 v1, v2, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v13, v1
.LBB1_48:                               ; %._crit_edge.i.23
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v13
	v_cndmask_b32_e32 v1, 0, v13, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v12, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v12 offset:2944
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_50
; %bb.49:
	v_lshl_or_b32 v2, v0, 1, 0x1800
	global_load_u16 v2, v2, s[4:5]
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v2, 16, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v2, v2, v4
	v_div_scale_f32 v12, null, v5, v5, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v13, v12
	v_fma_f32 v14, -v12, v13, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v13, v14, v13
	v_div_scale_f32 v14, vcc_lo, v2, v5, v2
	v_mul_f32_e32 v15, v14, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v12, v15, v14
	v_fmac_f32_e32 v15, v16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v12, v15, v14
	v_div_fmas_f32 v12, v12, v13, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v2, v12, v5, v2
	v_rndne_f32_e32 v2, v2
.LBB1_50:                               ; %._crit_edge.i.24
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3072
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_52
; %bb.51:
	v_sub_f32_e32 v1, v11, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v5, v5, v1
	v_rcp_f32_e32 v11, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v2, v11, 1.0
	v_fmac_f32_e32 v11, v12, v11
	v_div_scale_f32 v12, vcc_lo, v1, v5, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v13, v12, v11
	v_fma_f32 v14, -v2, v13, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v13, v14, v11
	v_fma_f32 v2, -v2, v13, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v11, v13
	v_div_fixup_f32 v1, v2, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB1_52:                               ; %._crit_edge.i.25
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v11, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v11 offset:3200
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_54
; %bb.53:
	v_sub_f32_e32 v2, v10, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v10, null, v5, v5, v2
	v_rcp_f32_e32 v11, v10
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v10, v11, 1.0
	v_fmac_f32_e32 v11, v12, v11
	v_div_scale_f32 v12, vcc_lo, v2, v5, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v13, v12, v11
	v_fma_f32 v14, -v10, v13, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v13, v14, v11
	v_fma_f32 v10, -v10, v13, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v10, v10, v11, v13
	v_div_fixup_f32 v2, v10, v5, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v2, v2
.LBB1_54:                               ; %._crit_edge.i.26
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3328
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_56
; %bb.55:
	v_sub_f32_e32 v1, v9, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v5, v5, v1
	v_rcp_f32_e32 v9, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v10, -v2, v9, 1.0
	v_fmac_f32_e32 v9, v10, v9
	v_div_scale_f32 v10, vcc_lo, v1, v5, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v11, v10, v9
	v_fma_f32 v12, -v2, v11, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v11, v12, v9
	v_fma_f32 v2, -v2, v11, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v9, v11
	v_div_fixup_f32 v1, v2, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB1_56:                               ; %._crit_edge.i.27
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v9, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v9 offset:3456
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_58
; %bb.57:
	v_sub_f32_e32 v2, v8, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v8, null, v5, v5, v2
	v_rcp_f32_e32 v9, v8
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v10, -v8, v9, 1.0
	v_fmac_f32_e32 v9, v10, v9
	v_div_scale_f32 v10, vcc_lo, v2, v5, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v11, v10, v9
	v_fma_f32 v12, -v8, v11, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v11, v12, v9
	v_fma_f32 v8, -v8, v11, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v8, v8, v9, v11
	v_div_fixup_f32 v2, v8, v5, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v2, v2
.LBB1_58:                               ; %._crit_edge.i.28
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3584
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_60
; %bb.59:
	v_sub_f32_e32 v1, v7, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v5, v5, v1
	v_rcp_f32_e32 v7, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v2, v7, 1.0
	v_fmac_f32_e32 v7, v8, v7
	v_div_scale_f32 v8, vcc_lo, v1, v5, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v9, v8, v7
	v_fma_f32 v10, -v2, v9, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, v10, v7
	v_fma_f32 v2, -v2, v9, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v7, v9
	v_div_fixup_f32 v1, v2, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB1_60:                               ; %._crit_edge.i.29
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_dual_cndmask_b32 v2, 0x41700000, v1 :: v_dual_mov_b32 v1, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v7, v2
	v_mov_b32_e32 v2, 0
	ds_store_b8 v0, v7 offset:3712
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_62
; %bb.61:
	v_sub_f32_e32 v2, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v6, null, v5, v5, v2
	v_rcp_f32_e32 v7, v6
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v6, v7, 1.0
	v_fmac_f32_e32 v7, v8, v7
	v_div_scale_f32 v8, vcc_lo, v2, v5, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v9, v8, v7
	v_fma_f32 v10, -v6, v9, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, v10, v7
	v_fma_f32 v6, -v6, v9, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v6, v6, v7, v9
	v_div_fixup_f32 v2, v6, v5, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v2, v2
.LBB1_62:                               ; %._crit_edge.i.30
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v2
	s_load_b64 s[6:7], s[0:1], 0x10
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v2
	v_cndmask_b32_e32 v2, 0x41700000, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v2, v2
	ds_store_b8 v0, v2 offset:3840
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_64
; %bb.63:
	v_sub_f32_e32 v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v2, null, v5, v5, v1
	v_rcp_f32_e32 v3, v2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v2, v3, 1.0
	v_fmac_f32_e32 v3, v4, v3
	v_div_scale_f32 v4, vcc_lo, v1, v5, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v6, v4, v3
	v_fma_f32 v7, -v2, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v6, v7, v3
	v_fma_f32 v2, -v2, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v2, v2, v3, v6
	v_div_fixup_f32 v1, v2, v5, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_rndne_f32_e32 v1, v1
.LBB1_64:                               ; %._crit_edge.i.31
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cmp_ngt_f32_e32 vcc_lo, 0, v1
	s_mov_b32 s8, exec_lo
	v_cndmask_b32_e32 v1, 0, v1, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x41700000, v1
	v_cndmask_b32_e32 v1, 0x41700000, v1, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v1, v1
	ds_store_b8 v0, v1 offset:3968
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmpx_gt_u32_e32 32, v0
	s_cbranch_execz .LBB1_73
; %bb.65:
	v_dual_mov_b32 v22, 0 :: v_dual_lshlrev_b32 v1, 8, v0
	s_load_b64 s[0:1], s[0:1], 0x8
	v_lshlrev_b32_e32 v21, 7, v0
	s_movk_i32 s9, 0x1000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s2, s4, v1
	v_add_co_ci_u32_e64 v3, null, s5, 0, s2
	s_mov_b64 s[2:3], 0
	v_add_co_u32 v18, vcc_lo, v2, 2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v3, vcc_lo
	v_mov_b32_e32 v2, 0
	v_dual_mov_b32 v3, 0 :: v_dual_mov_b32 v4, 0
	v_dual_mov_b32 v5, 0 :: v_dual_mov_b32 v6, 0
	v_dual_mov_b32 v7, 0 :: v_dual_mov_b32 v8, 0
	v_dual_mov_b32 v9, 0 :: v_dual_mov_b32 v10, 0
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v12, 0
	v_dual_mov_b32 v13, 0 :: v_dual_mov_b32 v14, 0
	v_dual_mov_b32 v15, 0 :: v_dual_mov_b32 v16, 0
	v_mov_b32_e32 v17, 0
	v_mov_b32_e32 v23, v21
.LBB1_66:                               ; =>This Inner Loop Header: Depth=1
	global_load_b32 v45, v[18:19], off offset:-2
	s_waitcnt lgkmcnt(0)
	s_add_u32 s10, s0, s2
	s_addc_u32 s11, s1, s3
	s_clause 0x1
	global_load_b128 v[24:27], v22, s[10:11]
	global_load_b128 v[28:31], v22, s[10:11] offset:16
	v_mov_b32_e32 v33, s9
	ds_load_u16_d16 v32, v23
	ds_load_b64 v[33:34], v33
	v_mov_b16_e32 v35.h, 0
	v_add_co_u32 v18, vcc_lo, v18, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v19, null, 0, v19, vcc_lo
	v_mov_b16_e32 v46.l, v35.h
	v_mov_b16_e32 v39.h, v35.h
	v_add_nc_u32_e32 v23, 2, v23
	s_add_i32 s9, s9, 8
	s_add_u32 s2, s2, 32
	s_addc_u32 s3, s3, 0
	s_cmpk_lg_i32 s2, 0x800
	s_waitcnt lgkmcnt(1)
	v_and_b16 v35.l, 0xff, v32.l
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v36, 16, v33
	v_cvt_f32_f16_e32 v37, v33.l
	v_lshrrev_b16 v39.l, 8, v32.l
	v_lshrrev_b32_e32 v41, 16, v34
	v_cvt_f64_u32_e32 v[32:33], v35
	v_cvt_f32_f16_e32 v38, v36.l
	v_cvt_f64_f32_e32 v[35:36], v37
	v_cvt_f32_f16_e32 v34, v34.l
	v_cvt_f32_f16_e32 v43, v41.l
	v_cvt_f64_u32_e32 v[39:40], v39
	v_cvt_f64_f32_e32 v[37:38], v38
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f64_f32_e32 v[41:42], v34
	v_cvt_f64_f32_e32 v[43:44], v43
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f64 v[32:33], v[32:33], v[37:38], v[35:36]
	v_fma_f64 v[36:37], v[39:40], v[43:44], v[41:42]
	s_waitcnt vmcnt(2)
	v_mov_b16_e32 v46.h, v45.l
	v_and_b32_e32 v38, 0xffff0000, v45
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v39, 16, v24
	v_lshrrev_b32_e32 v41, 16, v25
	v_cvt_f64_f32_e32 v[34:35], v46
	v_lshrrev_b32_e32 v43, 16, v26
	v_lshrrev_b32_e32 v45, 16, v27
	v_cvt_f32_f16_e32 v40, v24.l
	v_cvt_f32_f16_e32 v42, v25.l
	v_cvt_f32_f16_e32 v44, v26.l
	v_cvt_f32_f16_e32 v46, v27.l
	v_cvt_f32_f16_e32 v47, v39.l
	v_cvt_f32_f16_e32 v48, v41.l
	v_cvt_f32_f16_e32 v49, v43.l
	v_cvt_f32_f16_e32 v50, v45.l
	v_cvt_f64_f32_e32 v[24:25], v38
	v_cvt_f64_f32_e32 v[26:27], v40
	v_cvt_f64_f32_e32 v[38:39], v42
	v_cvt_f64_f32_e32 v[40:41], v44
	v_cvt_f64_f32_e32 v[42:43], v46
	v_cvt_f64_f32_e32 v[44:45], v47
	v_cvt_f64_f32_e32 v[46:47], v48
	v_cvt_f64_f32_e32 v[48:49], v49
	v_cvt_f64_f32_e32 v[50:51], v50
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v53, 16, v29
	v_lshrrev_b32_e32 v55, 16, v30
	v_lshrrev_b32_e32 v57, 16, v31
	v_cvt_f32_f16_e32 v52, v29.l
	v_cvt_f32_f16_e32 v54, v30.l
	v_cvt_f32_f16_e32 v56, v31.l
	v_cvt_f32_f16_e32 v59, v53.l
	v_cvt_f32_f16_e32 v60, v55.l
	v_cvt_f32_f16_e32 v61, v57.l
	v_cvt_f64_f32_e32 v[30:31], v52
	v_cvt_f64_f32_e32 v[52:53], v56
	v_cvt_f64_f32_e32 v[56:57], v59
	v_add_f64 v[32:33], v[32:33], -v[34:35]
	v_lshrrev_b32_e32 v35, 16, v28
	v_cvt_f32_f16_e32 v34, v28.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_f16_e32 v58, v35.l
	v_cvt_f64_f32_e32 v[28:29], v34
	v_cvt_f64_f32_e32 v[34:35], v54
	v_add_f64 v[24:25], v[36:37], -v[24:25]
	s_delay_alu instid0(VALU_DEP_4)
	v_cvt_f64_f32_e32 v[54:55], v58
	v_cvt_f64_f32_e32 v[58:59], v60
	v_cvt_f64_f32_e32 v[60:61], v61
	v_fma_f64 v[4:5], v[32:33], v[44:45], v[4:5]
	v_fma_f64 v[2:3], v[32:33], v[26:27], v[2:3]
	v_fma_f64 v[8:9], v[32:33], v[46:47], v[8:9]
	v_fma_f64 v[6:7], v[32:33], v[38:39], v[6:7]
	v_fma_f64 v[12:13], v[32:33], v[48:49], v[12:13]
	v_fma_f64 v[10:11], v[32:33], v[40:41], v[10:11]
	v_fma_f64 v[16:17], v[32:33], v[50:51], v[16:17]
	v_fma_f64 v[14:15], v[32:33], v[42:43], v[14:15]
	v_fma_f64 v[4:5], v[24:25], v[54:55], v[4:5]
	v_fma_f64 v[2:3], v[24:25], v[28:29], v[2:3]
	v_fma_f64 v[8:9], v[24:25], v[56:57], v[8:9]
	v_fma_f64 v[6:7], v[24:25], v[30:31], v[6:7]
	v_fma_f64 v[12:13], v[24:25], v[58:59], v[12:13]
	v_fma_f64 v[10:11], v[24:25], v[34:35], v[10:11]
	v_fma_f64 v[16:17], v[24:25], v[60:61], v[16:17]
	v_fma_f64 v[14:15], v[24:25], v[52:53], v[14:15]
	s_cbranch_scc1 .LBB1_66
; %bb.67:                               ; %.preheader2.i.preheader
	v_add_co_u32 v18, s2, s4, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, s5, 0, s2
	v_mov_b32_e32 v22, 0
	s_mov_b64 s[2:3], 0x800
	s_mov_b64 s[4:5], 0
	s_movk_i32 s9, 0x1000
	s_branch .LBB1_69
.LBB1_68:                               ;   in Loop: Header=BB1_69 Depth=1
	s_add_u32 s2, s2, 2
	s_addc_u32 s3, s3, 0
	v_add_nc_u32_e32 v21, 1, v21
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	s_add_i32 s9, s9, 4
	s_cmpk_lg_i32 s2, 0x900
	s_cbranch_scc0 .LBB1_71
.LBB1_69:                               ; %.preheader2.i
                                        ; =>This Inner Loop Header: Depth=1
	v_mov_b32_e32 v1, s9
	ds_load_u16_d16 v1, v1 offset:2
	s_waitcnt lgkmcnt(0)
	v_cmp_eq_f16_e32 vcc_lo, 0, v1.l
	s_cbranch_vccnz .LBB1_68
; %bb.70:                               ; %.preheader.i
                                        ;   in Loop: Header=BB1_69 Depth=1
	s_add_u32 s10, s0, s4
	s_addc_u32 s11, s1, s5
	v_add_co_u32 v27, vcc_lo, v18, s2
	global_load_b128 v[23:26], v22, s[10:11]
	v_add_co_ci_u32_e64 v28, null, s3, v19, vcc_lo
	s_add_u32 s10, s0, s2
	s_addc_u32 s11, s1, s3
	global_load_d16_hi_b16 v1, v22, s[10:11]
	global_load_u16 v51, v[27:28], off offset:-2048
	s_waitcnt vmcnt(1)
	v_cvt_f32_f16_e32 v43, v1.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_cvt_f64_f32_e32 v[43:44], v43
	v_lshrrev_b32_e32 v27, 16, v23
	v_cvt_f32_f16_e32 v23, v23.l
	v_cvt_f32_f16_e32 v1, v1.h
	v_cvt_f32_f16_e32 v27, v27.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_4) | instid1(VALU_DEP_3)
	v_cvt_f64_f32_e32 v[29:30], v23
	v_cvt_f32_f16_e32 v23, v24.l
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v51, 16, v51
	v_cvt_f64_f32_e32 v[27:28], v27
	v_cvt_f64_f32_e32 v[33:34], v23
	v_lshrrev_b32_e32 v23, 16, v24
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[51:52], v51
	v_cvt_f32_f16_e32 v23, v23.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[37:38], v23
	v_fma_f64 v[35:36], v[2:3], v[29:30], 0
	v_mul_f64 v[31:32], v[27:28], v[27:28]
	v_fma_f64 v[23:24], v[4:5], v[27:28], v[35:36]
	v_cvt_f32_f16_e32 v35, v25.l
	v_lshrrev_b32_e32 v25, 16, v25
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fma_f64 v[31:32], v[29:30], v[29:30], v[31:32]
	v_cvt_f64_f32_e32 v[35:36], v35
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_f16_e32 v25, v25.l
	v_cvt_f64_f32_e32 v[39:40], v25
	v_cvt_f32_f16_e32 v25, v26.l
	v_lshrrev_b32_e32 v26, 16, v26
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[41:42], v25
	v_cvt_f32_f16_e32 v26, v26.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[49:50], v26
	v_fma_f64 v[23:24], v[6:7], v[33:34], v[23:24]
	v_fma_f64 v[31:32], v[33:34], v[33:34], v[31:32]
	v_fma_f64 v[23:24], v[8:9], v[37:38], v[23:24]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f64 v[31:32], v[37:38], v[37:38], v[31:32]
	v_fma_f64 v[24:25], v[10:11], v[35:36], v[23:24]
	v_mov_b32_e32 v23, s9
	ds_load_u16_d16 v23, v23
	ds_load_u8 v45, v21
	v_fma_f64 v[31:32], v[35:36], v[35:36], v[31:32]
	s_waitcnt lgkmcnt(1)
	v_cvt_f32_f16_e32 v23, v23.l
	s_waitcnt lgkmcnt(0)
	v_cvt_f64_u32_e32 v[45:46], v45
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[47:48], v23
	v_fma_f64 v[23:24], v[12:13], v[39:40], v[24:25]
	v_fma_f64 v[31:32], v[39:40], v[39:40], v[31:32]
	v_fma_f64 v[23:24], v[14:15], v[41:42], v[23:24]
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_fma_f64 v[25:26], v[41:42], v[41:42], v[31:32]
	v_fma_f64 v[31:32], v[43:44], v[45:46], v[47:48]
	v_cvt_f64_f32_e32 v[47:48], v1
	v_fma_f64 v[23:24], v[16:17], v[49:50], v[23:24]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f64 v[25:26], v[49:50], v[49:50], v[25:26]
	v_add_f64 v[31:32], v[31:32], -v[51:52]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f64 v[25:26], v[25:26], v[47:48]
	v_fma_f64 v[23:24], v[31:32], v[47:48], v[23:24]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f64 v[25:26], v[25:26], v[43:44]
	v_div_scale_f64 v[31:32], null, v[25:26], v[25:26], v[23:24]
	v_div_scale_f64 v[53:54], vcc_lo, v[23:24], v[25:26], v[23:24]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f64_e32 v[47:48], v[31:32]
	v_fma_f64 v[51:52], -v[31:32], v[47:48], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[47:48], v[47:48], v[51:52], v[47:48]
	v_fma_f64 v[51:52], -v[31:32], v[47:48], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[47:48], v[47:48], v[51:52], v[47:48]
	v_mul_f64 v[51:52], v[53:54], v[47:48]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[31:32], -v[31:32], v[51:52], v[53:54]
	v_div_fmas_f64 v[31:32], v[31:32], v[47:48], v[51:52]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f64 v[23:24], v[31:32], v[25:26], v[23:24]
	v_add_f64 v[23:24], v[45:46], -v[23:24]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rndne_f64_e32 v[23:24], v[23:24]
	v_cmp_ngt_f64_e32 vcc_lo, 0, v[23:24]
	v_dual_cndmask_b32 v24, 0, v24 :: v_dual_cndmask_b32 v23, 0, v23
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cmp_nlt_f64_e32 vcc_lo, 0x402e0000, v[23:24]
	v_cndmask_b32_e32 v24, 0x402e0000, v24, vcc_lo
	v_cndmask_b32_e32 v23, 0, v23, vcc_lo
	v_cvt_i32_f64_e32 v1, v[23:24]
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cvt_f64_u32_e32 v[23:24], v1
	ds_store_b8 v21, v1
	v_add_f64 v[23:24], v[23:24], -v[45:46]
	v_mul_f64 v[23:24], v[23:24], v[43:44]
	s_delay_alu instid0(VALU_DEP_1)
	v_fma_f64 v[4:5], v[23:24], v[27:28], v[4:5]
	v_fma_f64 v[2:3], v[23:24], v[29:30], v[2:3]
	v_fma_f64 v[8:9], v[23:24], v[37:38], v[8:9]
	v_fma_f64 v[6:7], v[23:24], v[33:34], v[6:7]
	v_fma_f64 v[12:13], v[23:24], v[39:40], v[12:13]
	v_fma_f64 v[10:11], v[23:24], v[35:36], v[10:11]
	v_fma_f64 v[16:17], v[23:24], v[49:50], v[16:17]
	v_fma_f64 v[14:15], v[23:24], v[41:42], v[14:15]
	s_branch .LBB1_68
.LBB1_71:                               ; %_Z12metric_tokenPKtiPhPKDF16_S3_.exit
	v_lshlrev_b32_e32 v1, 6, v0
	v_mad_u32_u24 v0, 0x7f, v0, v0
	v_mov_b16_e32 v12.l, 0
	s_mov_b32 s2, 3
	s_mov_b32 s3, 2
	v_add_co_u32 v1, s0, s6, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s7, 0, s0
	s_mov_b32 s4, 1
	s_mov_b32 s5, 0
	s_mov_b64 s[0:1], 0
.LBB1_72:                               ; %vector.body
                                        ; =>This Inner Loop Header: Depth=1
	v_lshl_add_u32 v6, s5, 1, v0
	v_lshl_add_u32 v5, s3, 1, v0
	v_lshl_add_u32 v8, s2, 1, v0
	v_lshl_add_u32 v7, s4, 1, v0
	v_mov_b16_e32 v13.h, v12.l
	ds_load_u16_d16 v3, v6
	s_waitcnt lgkmcnt(0)
	ds_load_u16_d16_hi v3, v5
	ds_load_u16_d16 v4, v8
	s_waitcnt lgkmcnt(0)
	ds_load_u16_d16_hi v4, v5 offset:8
	ds_load_u16_d16 v5, v7
	ds_load_u16_d16_hi v11, v8 offset:8
	ds_load_u16_d16_hi v12, v7 offset:8
	s_waitcnt lgkmcnt(2)
	ds_load_u16_d16_hi v5, v6 offset:8
	v_add_co_u32 v10, vcc_lo, v1, s0
	s_add_i32 s5, s5, 8
	s_add_i32 s4, s4, 8
	s_add_i32 s3, s3, 8
	s_add_i32 s2, s2, 8
	s_add_u32 s0, s0, 8
	v_lshrrev_b16 v6.l, 4, v3.l
	v_lshrrev_b16 v6.h, 4, v3.h
	v_lshlrev_b16 v7.l, 8, v4.l
	v_lshlrev_b16 v4.l, 4, v4.l
	s_waitcnt lgkmcnt(0)
	v_lshlrev_b16 v7.h, 8, v5.l
	v_lshlrev_b16 v5.l, 4, v5.l
	v_lshrrev_b32_e32 v9, 20, v12
	v_lshrrev_b16 v8.l, 4, v5.h
	v_lshrrev_b32_e32 v14, 20, v11
	v_lshrrev_b16 v8.h, 4, v4.h
	v_and_b16 v6.l, 0xf0, v6.l
	v_and_b16 v6.h, 0xf0, v6.h
	v_and_b16 v4.l, 0xf000, v4.l
	v_and_b16 v5.l, 0xf000, v5.l
	v_and_b16 v9.l, 0xf0, v9.l
	v_and_b16 v8.l, 0xf0, v8.l
	v_and_b16 v9.h, 0xf0, v14.l
	v_and_b16 v8.h, 0xf0, v8.h
	v_or_b16 v3.h, v6.h, v3.h
	v_or_b16 v3.l, v6.l, v3.l
	v_or_b16 v4.l, v4.l, v7.l
	v_or_b16 v5.l, v5.l, v7.h
	v_or_b16 v4.h, v8.h, v4.h
	v_or_b16 v6.l, v9.h, v11.h
	v_or_b16 v5.h, v8.l, v5.h
	v_or_b16 v6.h, v9.l, v12.h
	v_and_b16 v3.h, 0xff, v3.h
	v_and_b16 v3.l, 0xff, v3.l
	v_and_b16 v4.h, 0xff, v4.h
	v_lshlrev_b16 v6.l, 8, v6.l
	v_and_b16 v5.h, 0xff, v5.h
	v_lshlrev_b16 v6.h, 8, v6.h
	v_or_b16 v12.h, v3.h, v4.l
	v_or_b16 v13.l, v3.l, v5.l
	v_mov_b16_e32 v7.h, v12.l
	v_add_co_ci_u32_e64 v11, null, s1, v2, vcc_lo
	v_or_b16 v7.l, v5.h, v6.h
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_or_b32_e32 v3, v13, v12
	v_or_b16 v12.h, v4.h, v6.l
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s0, 64
	v_or_b32_e32 v4, v7, v12
	global_store_b64 v[10:11], v[3:4], off
	s_cbranch_scc1 .LBB1_72
.LBB1_73:                               ; %Flow170
	s_or_b32 exec_lo, exec_lo, s8
	ds_load_b32 v0, v20 offset:4096
	s_waitcnt lgkmcnt(0)
	global_store_b32 v20, v0, s[6:7] offset:2048
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z9flush_keyILb1EEvPKtPKDF16_Ph
		.amdhsa_group_segment_fixed_size 4608
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
		.amdhsa_next_free_vgpr 62
		.amdhsa_next_free_sgpr 12
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
		.amdhsa_inst_pref_size 63
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z9flush_keyILb1EEvPKtPKDF16_Ph,"axG",@progbits,_Z9flush_keyILb1EEvPKtPKDF16_Ph,comdat
.Lfunc_end1:
	.size	_Z9flush_keyILb1EEvPKtPKDF16_Ph, .Lfunc_end1-_Z9flush_keyILb1EEvPKtPKDF16_Ph
                                        ; -- End function
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.num_vgpr, 62
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.num_agpr, 0
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.numbered_sgpr, 12
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.num_named_barrier, 0
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.private_seg_size, 0
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.uses_vcc, 1
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.uses_flat_scratch, 0
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.has_dyn_sized_stack, 0
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.has_recursion, 0
	.set _Z9flush_keyILb1EEvPKtPKDF16_Ph.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 9164
; TotalNumSgprs: 14
; NumVgprs: 62
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 4608 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 7
; NumSGPRsForWavesPerEU: 14
; NumVGPRsForWavesPerEU: 62
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.AMDGPU.gpr_maximums,"",@progbits
	.set amdgpu.max_num_vgpr, 0
	.set amdgpu.max_num_agpr, 0
	.set amdgpu.max_num_sgpr, 0
	.section	.AMDGPU.csdata,"",@progbits
	.type	__hip_cuid_160eca8d3623576f,@object ; @__hip_cuid_160eca8d3623576f
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_160eca8d3623576f
__hip_cuid_160eca8d3623576f:
	.byte	0                               ; 0x0
	.size	__hip_cuid_160eca8d3623576f, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __hip_cuid_160eca8d3623576f
	.amdgpu_metadata
---
amdhsa.kernels:
  - .args:
      - .actual_access:  read_only
        .address_space:  global
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .actual_access:  read_only
        .address_space:  global
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .actual_access:  write_only
        .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 4608
    .kernarg_segment_align: 8
    .kernarg_segment_size: 24
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z9flush_keyILb0EEvPKtPKDF16_Ph
    .private_segment_fixed_size: 0
    .sgpr_count:     11
    .sgpr_spill_count: 0
    .symbol:         _Z9flush_keyILb0EEvPKtPKDF16_Ph.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     36
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
  - .args:
      - .actual_access:  read_only
        .address_space:  global
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .actual_access:  read_only
        .address_space:  global
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .actual_access:  write_only
        .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 4608
    .kernarg_segment_align: 8
    .kernarg_segment_size: 24
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z9flush_keyILb1EEvPKtPKDF16_Ph
    .private_segment_fixed_size: 0
    .sgpr_count:     14
    .sgpr_spill_count: 0
    .symbol:         _Z9flush_keyILb1EEvPKtPKDF16_Ph.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     62
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
