	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.protected	_Z12k_check_wideiiiiPy  ; -- Begin function _Z12k_check_wideiiiiPy
	.globl	_Z12k_check_wideiiiiPy
	.p2align	8
	.type	_Z12k_check_wideiiiiPy,@function
_Z12k_check_wideiiiiPy:                 ; @_Z12k_check_wideiiiiPy
; %bb.0:
	s_clause 0x1
	s_load_b32 s3, s[0:1], 0x24
	s_load_b128 s[4:7], s[0:1], 0x0
	v_mov_b32_e32 v2, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b32_e32 v1, v2
	s_waitcnt lgkmcnt(0)
	s_and_b32 s3, s3, 0xffff
	s_delay_alu instid0(VALU_DEP_1) | instid1(SALU_CYCLE_1)
	v_mad_u64_u32 v[0:1], null, s3, s2, v[0:1]
	s_mul_hi_i32 s3, s7, s5
	s_mul_i32 s2, s7, s5
	s_delay_alu instid0(SALU_CYCLE_1)
	v_cmp_gt_i64_e32 vcc_lo, s[2:3], v[0:1]
	s_and_saveexec_b32 s3, vcc_lo
	s_cbranch_execz .LBB0_65
; %bb.1:
	s_ashr_i32 s5, s7, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_or_b32_e32 v3, s5, v1
	v_cmp_ne_u64_e32 vcc_lo, 0, v[2:3]
                                        ; implicit-def: $vgpr2_vgpr3
	s_and_saveexec_b32 s3, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB0_3
; %bb.2:
	s_ashr_i32 s8, s5, 31
	v_ashrrev_i32_e32 v7, 31, v1
	s_add_u32 s10, s7, s8
	s_mov_b32 s9, s8
	s_addc_u32 s11, s5, s8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_xor_b64 s[10:11], s[10:11], s[8:9]
	s_cvt_f32_u32 s2, s10
	s_cvt_f32_u32 s5, s11
	s_sub_u32 s9, 0, s10
	s_subb_u32 s12, 0, s11
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_3)
	s_fmamk_f32 s2, s5, 0x4f800000, s2
	v_rcp_f32_e32 v2, s2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_readfirstlane_b32 s2, v2
	v_add_co_u32 v2, vcc_lo, v0, v7
	v_add_co_ci_u32_e64 v1, null, v1, v7, vcc_lo
	s_mul_f32 s2, s2, 0x5f7ffffc
	v_xor_b32_e32 v8, v2, v7
	v_xor_b32_e32 v9, v1, v7
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_3)
	s_mul_f32 s5, s2, 0x2f800000
	s_trunc_f32 s5, s5
	s_delay_alu instid0(SALU_CYCLE_3) | instskip(SKIP_1) | instid1(SALU_CYCLE_2)
	s_fmamk_f32 s2, s5, 0xcf800000, s2
	s_cvt_u32_f32 s5, s5
	s_cvt_u32_f32 s2, s2
	s_delay_alu instid0(SALU_CYCLE_2) | instskip(NEXT) | instid1(SALU_CYCLE_2)
	s_mul_i32 s13, s9, s5
	s_mul_hi_u32 s15, s9, s2
	s_mul_i32 s14, s12, s2
	s_add_i32 s13, s15, s13
	s_mul_i32 s16, s9, s2
	s_add_i32 s13, s13, s14
	s_mul_hi_u32 s15, s2, s16
	s_mul_i32 s18, s2, s13
	s_mul_hi_u32 s17, s5, s16
	s_mul_i32 s14, s5, s16
	s_mul_hi_u32 s16, s2, s13
	s_add_u32 s15, s15, s18
	s_addc_u32 s16, 0, s16
	s_mul_hi_u32 s19, s5, s13
	s_add_u32 s14, s15, s14
	s_mul_i32 s13, s5, s13
	s_addc_u32 s14, s16, s17
	s_addc_u32 s15, s19, 0
	s_add_u32 s13, s14, s13
	s_addc_u32 s14, 0, s15
	s_add_u32 s2, s2, s13
	s_cselect_b32 s13, -1, 0
	s_mul_hi_u32 s15, s9, s2
	s_cmp_lg_u32 s13, 0
	s_mul_i32 s13, s9, s2
	s_addc_u32 s5, s5, s14
	s_mul_i32 s12, s12, s2
	s_mul_i32 s9, s9, s5
	s_mul_hi_u32 s14, s2, s13
	s_add_i32 s9, s15, s9
	s_mul_hi_u32 s15, s5, s13
	s_add_i32 s9, s9, s12
	s_mul_i32 s12, s5, s13
	s_mul_i32 s17, s2, s9
	s_mul_hi_u32 s16, s2, s9
	s_add_u32 s14, s14, s17
	s_addc_u32 s16, 0, s16
	s_mul_hi_u32 s13, s5, s9
	s_add_u32 s12, s14, s12
	s_mul_i32 s9, s5, s9
	s_addc_u32 s12, s16, s15
	s_addc_u32 s13, s13, 0
	s_add_u32 s9, s12, s9
	s_addc_u32 s12, 0, s13
	s_add_u32 s2, s2, s9
	s_cselect_b32 s9, -1, 0
	v_mul_hi_u32 v10, v8, s2
	s_cmp_lg_u32 s9, 0
	v_mad_u64_u32 v[3:4], null, v9, s2, 0
	s_addc_u32 s5, s5, s12
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mad_u64_u32 v[1:2], null, v8, s5, 0
	v_mad_u64_u32 v[5:6], null, v9, s5, 0
	v_add_co_u32 v1, vcc_lo, v10, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e32 v1, vcc_lo, v2, v4, vcc_lo
	v_add_co_ci_u32_e32 v2, vcc_lo, 0, v6, vcc_lo
	v_add_co_u32 v3, vcc_lo, v1, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v4, null, 0, v2, vcc_lo
	v_mul_lo_u32 v5, s11, v3
	v_mad_u64_u32 v[1:2], null, s10, v3, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_lo_u32 v6, s10, v4
	v_sub_co_u32 v1, vcc_lo, v8, v1
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add3_u32 v2, v2, v6, v5
	v_add_co_u32 v6, s2, v3, 2
	v_add_co_ci_u32_e64 v8, null, 0, v4, s2
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_sub_nc_u32_e32 v5, v9, v2
	v_sub_co_u32 v10, s2, v1, s10
	v_sub_co_ci_u32_e64 v2, null, v9, v2, vcc_lo
	v_subrev_co_ci_u32_e64 v5, null, s11, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_le_u32_e32 vcc_lo, s10, v10
	v_subrev_co_ci_u32_e64 v5, null, 0, v5, s2
	v_cndmask_b32_e64 v9, 0, -1, vcc_lo
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_le_u32_e32 vcc_lo, s11, v5
	v_cndmask_b32_e64 v10, 0, -1, vcc_lo
	v_cmp_le_u32_e32 vcc_lo, s10, v1
	v_cndmask_b32_e64 v1, 0, -1, vcc_lo
	v_cmp_le_u32_e32 vcc_lo, s11, v2
	v_cndmask_b32_e64 v11, 0, -1, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, s11, v5
	v_cndmask_b32_e32 v5, v10, v9, vcc_lo
	v_add_co_u32 v9, vcc_lo, v3, 1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, 0, v4, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, s11, v2
	v_cndmask_b32_e32 v1, v11, v1, vcc_lo
	v_cmp_ne_u32_e32 vcc_lo, 0, v5
	v_xor_b32_e32 v5, s8, v7
	v_cndmask_b32_e32 v2, v10, v8, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cmp_ne_u32_e64 s2, 0, v1
	v_cndmask_b32_e32 v1, v9, v6, vcc_lo
	v_cndmask_b32_e64 v2, v4, v2, s2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cndmask_b32_e64 v1, v3, v1, s2
	v_xor_b32_e32 v3, v2, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_xor_b32_e32 v1, v1, v5
	v_sub_co_u32 v2, vcc_lo, v1, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_sub_co_ci_u32_e64 v1, null, v3, v5, vcc_lo
.LBB0_3:
	s_and_not1_saveexec_b32 s2, s3
	s_cbranch_execz .LBB0_5
; %bb.4:
	v_cvt_f32_u32_e32 v1, s7
	s_sub_i32 s3, 0, s7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_iflag_f32_e32 v1, v1
	v_mul_f32_e32 v1, 0x4f7ffffe, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_u32_f32_e32 v1, v1
	v_mul_lo_u32 v2, s3, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_hi_u32 v2, v1, v2
	v_add_nc_u32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_hi_u32 v1, v0, v1
	v_mul_lo_u32 v2, v1, s7
	v_add_nc_u32_e32 v3, 1, v1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e32 v2, v0, v2
	v_subrev_nc_u32_e32 v4, s7, v2
	v_cmp_le_u32_e32 vcc_lo, s7, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_cndmask_b32 v2, v2, v4 :: v_dual_cndmask_b32 v1, v1, v3
	v_cmp_le_u32_e32 vcc_lo, s7, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v3, 1, v1
	v_cndmask_b32_e32 v2, v1, v3, vcc_lo
.LBB0_5:
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_mul_lo_u32 v1, v2, s7
	v_add_nc_u32_e32 v14, s4, v2
	v_cmp_lt_i32_e32 vcc_lo, 0, v14
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e32 v0, v0, v1
	v_add_nc_u32_e32 v15, s6, v0
	s_load_b64 s[6:7], s[0:1], 0x10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mad_i64_i32 v[0:1], null, v15, v14, 0
	v_cndmask_b32_e32 v9, 0, v1, vcc_lo
	v_mad_i64_i32 v[2:3], null, v14, v14, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v7, s0, 0x4000, v0
	v_add_co_ci_u32_e64 v8, null, 0, v1, s0
	v_lshl_add_u32 v16, v15, 16, v14
	s_delay_alu instid0(VALU_DEP_4)
	v_cmp_gt_u64_e64 s3, 0x20000, v[2:3]
	;;#ASMSTART
	v_mul_lo_u32 v2, v16, v16
	v_bfe_i32 v2, v2, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v4, v16, v16
	v_bfe_i32 v4, v4, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v11, v16, 0, 16
	v_add_nc_u32 v3, 0x8000, v16
	v_ashrrev_i32 v3, 16, v3
	v_mul_i32_i24 v11, v11, v3
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v6, v16, v16
	v_bfe_i32 v6, v6, 17, 15
	v_bfe_i32 v3, v16, 15, 1
	v_bfi_b32 v6, v3, 0, v6
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v10, v16, 0, 16
	v_add_nc_u32 v3, 0x8000, v16
	v_ashrrev_i32 v3, 16, v3
	v_max_i32 v10, 0, v10
	v_mul_i32_i24 v10, v10, v3
	;;#ASMEND
	v_ashrrev_i32_e32 v3, 31, v2
	v_ashrrev_i32_e32 v5, 31, v4
	v_cmp_gt_u64_e64 s4, 0x8000, v[7:8]
	v_cndmask_b32_e32 v8, 0, v0, vcc_lo
	s_delay_alu instid0(VALU_DEP_4)
	v_cmp_eq_u64_e64 s2, v[0:1], v[2:3]
	v_cmp_ne_u64_e64 s0, v[0:1], v[2:3]
	v_cmp_eq_u64_e64 s1, v[0:1], v[4:5]
	s_and_b32 s3, s3, s4
	s_mov_b32 s4, 0
	s_xor_b32 s5, s3, -1
	v_cmp_ne_u64_e32 vcc_lo, v[0:1], v[4:5]
	;;#ASMSTART
	v_lshl_add_u32 v4, v15, 16, v14
	v_mul_i32_i24 v4, v4, v4
	v_bfe_i32 v4, v4, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v2, v14, v15
	;;#ASMEND
	s_and_saveexec_b32 s8, s5
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s5, exec_lo, s8
	s_cbranch_execz .LBB0_10
; %bb.6:
	s_and_saveexec_b32 s4, s2
	s_cbranch_execz .LBB0_9
; %bb.7:
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s8, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_9
; %bb.8:
	s_bcnt1_i32_b32 s2, s8
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:24
.LBB0_9:
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s4, s1, exec_lo
                                        ; implicit-def: $vgpr10
                                        ; implicit-def: $vgpr11
.LBB0_10:
	s_or_saveexec_b32 s5, s5
	v_mov_b32_e32 v12, 32
	v_mov_b32_e32 v13, 0
	s_xor_b32 exec_lo, exec_lo, s5
	s_cbranch_execnz .LBB0_13
; %bb.11:
	s_or_b32 exec_lo, exec_lo, s5
	s_and_saveexec_b32 s5, s4
	s_cbranch_execnz .LBB0_38
.LBB0_12:
	s_or_b32 exec_lo, exec_lo, s5
	s_and_saveexec_b32 s4, s3
	s_cbranch_execnz .LBB0_39
	s_branch .LBB0_47
.LBB0_13:
	s_and_saveexec_b32 s8, s0
	s_cbranch_execz .LBB0_16
; %bb.14:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_16
; %bb.15:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v13, 0 :: v_dual_mov_b32 v12, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v13, v[12:13], s[6:7]
.LBB0_16:
	s_or_b32 exec_lo, exec_lo, s8
	s_and_saveexec_b32 s8, vcc_lo
	s_cbranch_execz .LBB0_19
; %bb.17:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_19
; %bb.18:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v13, 0 :: v_dual_mov_b32 v12, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v13, v[12:13], s[6:7] offset:8
.LBB0_19:
	s_or_b32 exec_lo, exec_lo, s8
	v_ashrrev_i32_e32 v7, 31, v6
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[8:9], v[6:7]
	s_cbranch_execz .LBB0_22
; %bb.20:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_22
; %bb.21:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v13, 0 :: v_dual_mov_b32 v12, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v13, v[12:13], s[6:7] offset:16
.LBB0_22:
	s_or_b32 exec_lo, exec_lo, s8
	v_ashrrev_i32_e32 v12, 31, v11
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[0:1], v[11:12]
	s_cbranch_execz .LBB0_25
; %bb.23:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_25
; %bb.24:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v12, 0 :: v_dual_mov_b32 v11, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v12, v[11:12], s[6:7] offset:40
.LBB0_25:
	s_or_b32 exec_lo, exec_lo, s8
	v_ashrrev_i32_e32 v11, 31, v10
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[8:9], v[10:11]
	s_cbranch_execz .LBB0_28
; %bb.26:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_28
; %bb.27:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:48
.LBB0_28:
	s_or_b32 exec_lo, exec_lo, s8
	v_add_nc_u32_e32 v3, 0x7f, v14
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_gt_u32_e32 0xff, v3
	s_cbranch_execz .LBB0_32
; %bb.29:
	v_bfe_u32 v3, v14, 15, 1
	v_lshrrev_b32_e32 v5, 31, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_ne_u32_e64 s2, v3, v5
	s_and_b32 exec_lo, exec_lo, s2
	s_cbranch_execz .LBB0_32
; %bb.30:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_32
; %bb.31:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:56
.LBB0_32:
	s_or_b32 exec_lo, exec_lo, s8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	s_mov_b32 s9, exec_lo
	s_mov_b32 s8, exec_lo
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmpx_eq_u32_e32 0, v3
	s_cbranch_execz .LBB0_34
; %bb.33:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:64
.LBB0_34:
	s_or_b32 exec_lo, exec_lo, s8
	v_ashrrev_i32_e32 v5, 31, v4
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[0:1], v[4:5]
	s_cbranch_execz .LBB0_37
; %bb.35:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s9, 0
	v_cmp_eq_u32_e64 s2, 0, v3
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_37
; %bb.36:
	s_bcnt1_i32_b32 s2, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:128
.LBB0_37:
	s_or_b32 exec_lo, exec_lo, s8
	v_ashrrev_i32_e32 v3, 31, v2
	v_mov_b32_e32 v12, 0x88
	v_mov_b32_e32 v13, 0
	s_and_not1_b32 s4, s4, exec_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_ne_u64_e64 s2, v[0:1], v[2:3]
	s_and_b32 s2, s2, exec_lo
	s_or_b32 s4, s4, s2
	s_or_b32 exec_lo, exec_lo, s5
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB0_12
.LBB0_38:
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v12, s2, s6, v12
	v_mov_b32_e32 v10, 1
	v_mov_b32_e32 v11, 0
	v_add_co_ci_u32_e64 v13, null, s7, v13, s2
	global_atomic_add_u64 v[12:13], v[10:11], off
	s_or_b32 exec_lo, exec_lo, s5
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB0_47
.LBB0_39:
	v_add_nc_u32_e32 v3, 0x800000, v16
	s_mov_b32 s3, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_lt_u32_e64 s2, 0xffffff, v3
	s_and_saveexec_b32 s5, s2
	s_xor_b32 s2, exec_lo, s5
; %bb.40:
	s_and_b32 s3, s1, exec_lo
; %bb.41:
	s_or_saveexec_b32 s2, s2
	v_mov_b32_e32 v10, 0x70
	v_mov_b32_e32 v11, 0
	s_xor_b32 exec_lo, exec_lo, s2
	s_cbranch_execz .LBB0_45
; %bb.42:
	s_mov_b32 s8, exec_lo
	s_mov_b32 s5, exec_lo
	v_mbcnt_lo_u32_b32 v3, s8, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_eq_u32_e32 0, v3
	s_cbranch_execz .LBB0_44
; %bb.43:
	s_bcnt1_i32_b32 s1, s8
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s1
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:120
.LBB0_44:
	s_or_b32 exec_lo, exec_lo, s5
	v_mov_b32_e32 v10, 0x68
	v_mov_b32_e32 v11, 0
	s_and_not1_b32 s1, s3, exec_lo
	s_and_b32 s3, vcc_lo, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s3, s1, s3
.LBB0_45:
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 exec_lo, exec_lo, s3
	s_cbranch_execz .LBB0_47
; %bb.46:
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v10, s1, s6, v10
	v_mov_b32_e32 v12, 1
	v_mov_b32_e32 v13, 0
	v_add_co_ci_u32_e64 v11, null, s7, v11, s1
	global_atomic_add_u64 v[10:11], v[12:13], off
.LBB0_47:
	s_or_b32 exec_lo, exec_lo, s4
	v_add_nc_u32_e32 v3, 0x7f, v14
	v_add_nc_u32_e32 v5, 0x7f, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_max_u32_e32 v3, v3, v5
	v_cmp_gt_u32_e64 s1, 0xff, v3
	s_and_b32 exec_lo, exec_lo, s1
	s_cbranch_execz .LBB0_65
; %bb.48:
	s_mov_b32 s3, exec_lo
	s_mov_b32 s2, exec_lo
	v_mbcnt_lo_u32_b32 v3, s3, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_eq_u32_e32 0, v3
	s_cbranch_execz .LBB0_50
; %bb.49:
	s_bcnt1_i32_b32 s1, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s1
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:72
.LBB0_50:
	s_or_b32 exec_lo, exec_lo, s2
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB0_53
; %bb.51:
	s_mov_b32 s2, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s2, 0
	v_cmp_eq_u32_e64 s0, 0, v3
	s_and_b32 s0, exec_lo, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s0
	s_cbranch_execz .LBB0_53
; %bb.52:
	s_bcnt1_i32_b32 s0, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:80
.LBB0_53:
	s_or_b32 exec_lo, exec_lo, s1
	s_and_saveexec_b32 s0, vcc_lo
	s_cbranch_execz .LBB0_56
; %bb.54:
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s1, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v3
	s_and_b32 s2, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_56
; %bb.55:
	s_bcnt1_i32_b32 s1, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v11, 0 :: v_dual_mov_b32 v10, s1
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v11, v[10:11], s[6:7] offset:88
.LBB0_56:
	s_or_b32 exec_lo, exec_lo, s0
	v_ashrrev_i32_e32 v7, 31, v6
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[8:9], v[6:7]
	s_cbranch_execz .LBB0_59
; %bb.57:
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s1, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v3
	s_and_b32 s2, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_59
; %bb.58:
	s_bcnt1_i32_b32 s1, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s1
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[6:7] offset:96
.LBB0_59:
	s_or_b32 exec_lo, exec_lo, s0
	v_ashrrev_i32_e32 v5, 31, v4
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[0:1], v[4:5]
	s_cbranch_execz .LBB0_62
; %bb.60:
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v3, s1, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v3
	s_and_b32 s2, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s2
	s_cbranch_execz .LBB0_62
; %bb.61:
	s_bcnt1_i32_b32 s1, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v4, 0 :: v_dual_mov_b32 v3, s1
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v4, v[3:4], s[6:7] offset:144
.LBB0_62:
	s_or_b32 exec_lo, exec_lo, s0
	v_ashrrev_i32_e32 v3, 31, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_ne_u64_e32 vcc_lo, v[0:1], v[2:3]
	s_and_b32 exec_lo, exec_lo, vcc_lo
	s_cbranch_execz .LBB0_65
; %bb.63:
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v0, s0, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 s1, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s1
	s_cbranch_execz .LBB0_65
; %bb.64:
	s_bcnt1_i32_b32 s0, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[6:7] offset:152
.LBB0_65:
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z12k_check_wideiiiiPy
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
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
		.amdhsa_next_free_vgpr 17
		.amdhsa_next_free_sgpr 20
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
		.amdhsa_inst_pref_size 23
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
	.size	_Z12k_check_wideiiiiPy, .Lfunc_end0-_Z12k_check_wideiiiiPy
                                        ; -- End function
	.set _Z12k_check_wideiiiiPy.num_vgpr, 17
	.set _Z12k_check_wideiiiiPy.num_agpr, 0
	.set _Z12k_check_wideiiiiPy.numbered_sgpr, 20
	.set _Z12k_check_wideiiiiPy.num_named_barrier, 0
	.set _Z12k_check_wideiiiiPy.private_seg_size, 0
	.set _Z12k_check_wideiiiiPy.uses_vcc, 1
	.set _Z12k_check_wideiiiiPy.uses_flat_scratch, 0
	.set _Z12k_check_wideiiiiPy.has_dyn_sized_stack, 0
	.set _Z12k_check_wideiiiiPy.has_recursion, 0
	.set _Z12k_check_wideiiiiPy.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 2860
; TotalNumSgprs: 22
; NumVgprs: 17
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 22
; NumVGPRsForWavesPerEU: 17
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
	.protected	_Z14k_check_narrowiiPy  ; -- Begin function _Z14k_check_narrowiiPy
	.globl	_Z14k_check_narrowiiPy
	.p2align	8
	.type	_Z14k_check_narrowiiPy,@function
_Z14k_check_narrowiiPy:                 ; @_Z14k_check_narrowiiPy
; %bb.0:
	s_clause 0x1
	s_load_b32 s3, s[0:1], 0x1c
	s_load_b64 s[4:5], s[0:1], 0x0
	v_mov_b32_e32 v2, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b32_e32 v1, v2
	s_waitcnt lgkmcnt(0)
	s_and_b32 s3, s3, 0xffff
	s_delay_alu instid0(VALU_DEP_1) | instid1(SALU_CYCLE_1)
	v_mad_u64_u32 v[0:1], null, s3, s2, v[0:1]
	s_mul_hi_i32 s3, s5, s5
	s_mul_i32 s2, s5, s5
	s_delay_alu instid0(SALU_CYCLE_1)
	v_cmp_gt_u64_e32 vcc_lo, s[2:3], v[0:1]
	s_and_saveexec_b32 s3, vcc_lo
	s_cbranch_execz .LBB1_51
; %bb.1:
	s_ashr_i32 s8, s5, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_or_b32_e32 v3, s8, v1
	v_cmp_ne_u64_e32 vcc_lo, 0, v[2:3]
                                        ; implicit-def: $vgpr2_vgpr3
	s_and_saveexec_b32 s3, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB1_3
; %bb.2:
	s_ashr_i32 s6, s8, 31
	v_ashrrev_i32_e32 v7, 31, v1
	s_add_u32 s10, s5, s6
	s_mov_b32 s7, s6
	s_addc_u32 s11, s8, s6
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_xor_b64 s[8:9], s[10:11], s[6:7]
	s_cvt_f32_u32 s2, s8
	s_cvt_f32_u32 s7, s9
	s_sub_u32 s10, 0, s8
	s_subb_u32 s11, 0, s9
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_3)
	s_fmamk_f32 s2, s7, 0x4f800000, s2
	v_rcp_f32_e32 v2, s2
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_readfirstlane_b32 s2, v2
	v_add_co_u32 v2, vcc_lo, v0, v7
	v_add_co_ci_u32_e64 v1, null, v1, v7, vcc_lo
	s_mul_f32 s2, s2, 0x5f7ffffc
	v_xor_b32_e32 v8, v2, v7
	v_xor_b32_e32 v9, v1, v7
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_3)
	s_mul_f32 s7, s2, 0x2f800000
	s_trunc_f32 s7, s7
	s_delay_alu instid0(SALU_CYCLE_3) | instskip(SKIP_1) | instid1(SALU_CYCLE_2)
	s_fmamk_f32 s2, s7, 0xcf800000, s2
	s_cvt_u32_f32 s7, s7
	s_cvt_u32_f32 s2, s2
	s_delay_alu instid0(SALU_CYCLE_2) | instskip(NEXT) | instid1(SALU_CYCLE_2)
	s_mul_i32 s12, s10, s7
	s_mul_hi_u32 s14, s10, s2
	s_mul_i32 s13, s11, s2
	s_add_i32 s12, s14, s12
	s_mul_i32 s15, s10, s2
	s_add_i32 s12, s12, s13
	s_mul_hi_u32 s14, s2, s15
	s_mul_i32 s17, s2, s12
	s_mul_hi_u32 s16, s7, s15
	s_mul_i32 s13, s7, s15
	s_mul_hi_u32 s15, s2, s12
	s_add_u32 s14, s14, s17
	s_addc_u32 s15, 0, s15
	s_mul_hi_u32 s18, s7, s12
	s_add_u32 s13, s14, s13
	s_mul_i32 s12, s7, s12
	s_addc_u32 s13, s15, s16
	s_addc_u32 s14, s18, 0
	s_add_u32 s12, s13, s12
	s_addc_u32 s13, 0, s14
	s_add_u32 s2, s2, s12
	s_cselect_b32 s12, -1, 0
	s_mul_hi_u32 s14, s10, s2
	s_cmp_lg_u32 s12, 0
	s_mul_i32 s12, s10, s2
	s_addc_u32 s7, s7, s13
	s_mul_i32 s11, s11, s2
	s_mul_i32 s10, s10, s7
	s_mul_hi_u32 s13, s2, s12
	s_add_i32 s10, s14, s10
	s_mul_hi_u32 s14, s7, s12
	s_add_i32 s10, s10, s11
	s_mul_i32 s11, s7, s12
	s_mul_i32 s16, s2, s10
	s_mul_hi_u32 s15, s2, s10
	s_add_u32 s13, s13, s16
	s_addc_u32 s15, 0, s15
	s_mul_hi_u32 s12, s7, s10
	s_add_u32 s11, s13, s11
	s_mul_i32 s10, s7, s10
	s_addc_u32 s11, s15, s14
	s_addc_u32 s12, s12, 0
	s_add_u32 s10, s11, s10
	s_addc_u32 s11, 0, s12
	s_add_u32 s2, s2, s10
	s_cselect_b32 s10, -1, 0
	v_mul_hi_u32 v10, v8, s2
	s_cmp_lg_u32 s10, 0
	v_mad_u64_u32 v[3:4], null, v9, s2, 0
	s_addc_u32 s7, s7, s11
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mad_u64_u32 v[1:2], null, v8, s7, 0
	v_mad_u64_u32 v[5:6], null, v9, s7, 0
	v_add_co_u32 v1, vcc_lo, v10, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e32 v1, vcc_lo, v2, v4, vcc_lo
	v_add_co_ci_u32_e32 v2, vcc_lo, 0, v6, vcc_lo
	v_add_co_u32 v3, vcc_lo, v1, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v4, null, 0, v2, vcc_lo
	v_mul_lo_u32 v5, s9, v3
	v_mad_u64_u32 v[1:2], null, s8, v3, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_lo_u32 v6, s8, v4
	v_sub_co_u32 v1, vcc_lo, v8, v1
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add3_u32 v2, v2, v6, v5
	v_add_co_u32 v6, s2, v3, 2
	v_add_co_ci_u32_e64 v8, null, 0, v4, s2
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_sub_nc_u32_e32 v5, v9, v2
	v_sub_co_u32 v10, s2, v1, s8
	v_sub_co_ci_u32_e64 v2, null, v9, v2, vcc_lo
	v_subrev_co_ci_u32_e64 v5, null, s9, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_le_u32_e32 vcc_lo, s8, v10
	v_subrev_co_ci_u32_e64 v5, null, 0, v5, s2
	v_cndmask_b32_e64 v9, 0, -1, vcc_lo
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_le_u32_e32 vcc_lo, s9, v5
	v_cndmask_b32_e64 v10, 0, -1, vcc_lo
	v_cmp_le_u32_e32 vcc_lo, s8, v1
	v_cndmask_b32_e64 v1, 0, -1, vcc_lo
	v_cmp_le_u32_e32 vcc_lo, s9, v2
	v_cndmask_b32_e64 v11, 0, -1, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, s9, v5
	v_cndmask_b32_e32 v5, v10, v9, vcc_lo
	v_add_co_u32 v9, vcc_lo, v3, 1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, 0, v4, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, s9, v2
	v_cndmask_b32_e32 v1, v11, v1, vcc_lo
	v_cmp_ne_u32_e32 vcc_lo, 0, v5
	v_xor_b32_e32 v5, s6, v7
	v_cndmask_b32_e32 v2, v10, v8, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cmp_ne_u32_e64 s2, 0, v1
	v_cndmask_b32_e32 v1, v9, v6, vcc_lo
	v_cndmask_b32_e64 v2, v4, v2, s2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cndmask_b32_e64 v1, v3, v1, s2
	v_xor_b32_e32 v3, v2, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_xor_b32_e32 v1, v1, v5
	v_sub_co_u32 v2, vcc_lo, v1, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_sub_co_ci_u32_e64 v1, null, v3, v5, vcc_lo
.LBB1_3:
	s_and_not1_saveexec_b32 s2, s3
	s_cbranch_execz .LBB1_5
; %bb.4:
	v_cvt_f32_u32_e32 v1, s5
	s_sub_i32 s3, 0, s5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_iflag_f32_e32 v1, v1
	v_mul_f32_e32 v1, 0x4f7ffffe, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_u32_f32_e32 v1, v1
	v_mul_lo_u32 v2, s3, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_hi_u32 v2, v1, v2
	v_add_nc_u32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_hi_u32 v1, v0, v1
	v_mul_lo_u32 v2, v1, s5
	v_add_nc_u32_e32 v3, 1, v1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e32 v2, v0, v2
	v_subrev_nc_u32_e32 v4, s5, v2
	v_cmp_le_u32_e32 vcc_lo, s5, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_cndmask_b32 v2, v2, v4 :: v_dual_cndmask_b32 v1, v1, v3
	v_cmp_le_u32_e32 vcc_lo, s5, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v3, 1, v1
	v_cndmask_b32_e32 v2, v1, v3, vcc_lo
.LBB1_5:
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_mul_lo_u32 v1, v2, s5
	v_add_nc_u32_e32 v10, s4, v2
	v_mov_b32_e32 v12, 0x100
	v_mad_i64_i32 v[2:3], null, v10, v10, 0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e32 v0, v0, v1
	v_add_nc_u32_e32 v9, s4, v0
	s_load_b64 s[4:5], s[0:1], 0x8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_gt_u64_e64 s0, 0x800, v[2:3]
	v_mad_i64_i32 v[0:1], null, v9, v10, 0
	v_lshl_add_u32 v6, v9, 10, v10
	;;#ASMSTART
	v_mul_i32_i24 v2, v6, v6
	v_bfe_i32 v2, v2, 11, 9
	;;#ASMEND
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_i32_e32 v11, v6
	v_add_co_u32 v4, vcc_lo, 0x100, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, 0, v1, vcc_lo
	v_cmp_gt_u64_e64 s1, 0x200, v[4:5]
	;;#ASMSTART
	v_mul_i32_i24 v3, v6, v6
	v_bfe_i32 v4, v3, 11, 9
	v_cmp_eq_u32 vcc_lo, 0x10080100, v3
	v_cndmask_b32 v4, v4, v12, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v5, v6, 0, 10
	v_add_nc_u32 v3, 0x200, v6
	v_ashrrev_i32 v3, 10, v3
	v_mul_i32_i24 v5, v5, v3
	;;#ASMEND
	v_ashrrev_i32_e32 v3, 31, v2
	v_cvt_i32_f32_e32 v6, v11
	;;#ASMSTART
	v_cvt_i32_f32 v7, v11
	v_mul_i32_i24 v7, v7, v7
	v_bfe_i32 v7, v7, 11, 9
	v_cvt_f32_i32 v7, v7
	;;#ASMEND
	s_and_b32 s1, s0, s1
	;;#ASMSTART
	v_mul_f32 v13, 0x3a800000, v11
	v_rndne_f32 v13, v13
	v_fma_f32 v8, v13, 0xc4800000, v11
	v_mul_f32 v8, v8, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v13, v6, v6
	v_bfe_i32 v11, v13, 11, 9
	v_cmp_eq_u32 vcc_lo, 0x10080100, v13
	v_cndmask_b32 v11, v11, v12, vcc_lo
	;;#ASMEND
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB1_20
; %bb.6:
	s_mov_b32 s2, exec_lo
	v_cmpx_ne_u64_e64 v[0:1], v[2:3]
	s_cbranch_execz .LBB1_9
; %bb.7:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v6, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v6
	s_and_b32 s6, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s6
	s_cbranch_execz .LBB1_9
; %bb.8:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v13, 0 :: v_dual_mov_b32 v12, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v13, v[12:13], s[4:5]
.LBB1_9:
	s_or_b32 exec_lo, exec_lo, s2
	v_ashrrev_i32_e32 v6, 31, v5
	s_mov_b32 s2, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[0:1], v[5:6]
	s_cbranch_execz .LBB1_12
; %bb.10:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v5, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v5
	s_and_b32 s6, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s6
	s_cbranch_execz .LBB1_12
; %bb.11:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[4:5] offset:8
.LBB1_12:
	s_or_b32 exec_lo, exec_lo, s2
	v_xor_b32_e32 v5, v0, v1
	v_cls_i32_e32 v6, v1
	s_mov_b32 s2, exec_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_ashrrev_i32_e32 v5, 31, v5
	v_add_nc_u32_e32 v6, -1, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v5, 32, v5
	v_min_u32_e32 v12, v6, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], v12, v[0:1]
	v_min_u32_e32 v5, 1, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_or_b32_e32 v5, v6, v5
	v_sub_nc_u32_e32 v6, 32, v12
	v_cvt_f32_i32_e32 v5, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ldexp_f32 v5, v5, v6
	v_cmpx_neq_f32_e32 v7, v5
	s_cbranch_execz .LBB1_15
; %bb.13:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v6, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v6
	s_and_b32 s6, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s6
	s_cbranch_execz .LBB1_15
; %bb.14:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v13, 0 :: v_dual_mov_b32 v12, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v13, v[12:13], s[4:5] offset:16
.LBB1_15:
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 s2, exec_lo
	v_cmpx_neq_f32_e32 v8, v5
	s_cbranch_execz .LBB1_18
; %bb.16:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v5, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v5
	s_and_b32 s6, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s6
	s_cbranch_execz .LBB1_18
; %bb.17:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[4:5] offset:24
.LBB1_18:
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mov_b32 s2, exec_lo
	v_mbcnt_lo_u32_b32 v5, s2, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v5
	s_and_b32 s3, exec_lo, vcc_lo
	s_mov_b32 exec_lo, s3
	s_cbranch_execz .LBB1_20
; %bb.19:
	s_bcnt1_i32_b32 s2, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[4:5] offset:40
.LBB1_20:
	s_or_b32 exec_lo, exec_lo, s0
	v_ashrrev_i32_e32 v5, 31, v4
	v_cmp_eq_u64_e64 s0, 0x100, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_ne_u64_e32 vcc_lo, v[0:1], v[4:5]
	s_or_b32 s1, s1, s0
	s_and_b32 s1, s1, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_saveexec_b32 s2, s1
	s_cbranch_execz .LBB1_23
; %bb.21:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v5, s3, 0
	v_cmp_eq_u32_e64 s1, 0, v5
	s_and_b32 s1, exec_lo, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s1
	s_cbranch_execz .LBB1_23
; %bb.22:
	s_bcnt1_i32_b32 s1, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s1
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[4:5] offset:32
.LBB1_23:
	s_or_b32 exec_lo, exec_lo, s2
	v_add_nc_u32_e32 v5, 16, v10
	v_add_nc_u32_e32 v6, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_gt_u32_e64 s1, 33, v5
	v_cmp_gt_u32_e64 s2, 33, v6
	s_and_b32 s6, s1, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB1_33
; %bb.24:
	v_xor_b32_e32 v5, v0, v1
	v_cls_i32_e32 v6, v1
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_ashrrev_i32_e32 v5, 31, v5
	v_add_nc_u32_e32 v6, -1, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v5, 32, v5
	v_min_u32_e32 v9, v6, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], v9, v[0:1]
	v_min_u32_e32 v5, 1, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_or_b32_e32 v5, v6, v5
	v_sub_nc_u32_e32 v6, 32, v9
	v_cvt_f32_i32_e32 v9, v11
	v_cvt_f32_i32_e32 v5, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ldexp_f32 v5, v5, v6
	v_cmpx_neq_f32_e32 v9, v5
	s_cbranch_execz .LBB1_27
; %bb.25:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v6, s9, 0
	v_cmp_eq_u32_e64 s3, 0, v6
	s_and_b32 s3, exec_lo, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s3
	s_cbranch_execz .LBB1_27
; %bb.26:
	s_bcnt1_i32_b32 s3, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v10, 0 :: v_dual_mov_b32 v9, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v10, v[9:10], s[4:5] offset:104
.LBB1_27:
	s_or_b32 exec_lo, exec_lo, s8
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 s8, exec_lo
	v_cmpx_neq_f32_e32 v8, v5
	s_cbranch_execz .LBB1_30
; %bb.28:
	s_mov_b32 s9, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v6, s9, 0
	v_cmp_eq_u32_e64 s3, 0, v6
	s_and_b32 s3, exec_lo, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s3
	s_cbranch_execz .LBB1_30
; %bb.29:
	s_bcnt1_i32_b32 s3, s9
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v9, 0 :: v_dual_mov_b32 v8, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v9, v[8:9], s[4:5] offset:112
.LBB1_30:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_neq_f32_e64 s3, v7, v5
	s_and_b32 exec_lo, exec_lo, s3
	s_cbranch_execz .LBB1_33
; %bb.31:
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v5, s8, 0
	v_cmp_eq_u32_e64 s3, 0, v5
	s_and_b32 s3, exec_lo, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s3
	s_cbranch_execz .LBB1_33
; %bb.32:
	s_bcnt1_i32_b32 s3, s8
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[4:5] offset:120
.LBB1_33:
	s_or_b32 exec_lo, exec_lo, s7
	s_and_saveexec_b32 s7, s0
	s_cbranch_execz .LBB1_36
; %bb.34:
	s_mov_b32 s8, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v5, s8, 0
	v_cmp_eq_u32_e64 s3, 0, v5
	s_and_b32 s3, exec_lo, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s3
	s_cbranch_execz .LBB1_36
; %bb.35:
	s_bcnt1_i32_b32 s3, s8
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[4:5] offset:48
.LBB1_36:
	s_or_b32 exec_lo, exec_lo, s7
	s_and_b32 s0, s1, s0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s0, s0, s2
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB1_42
; %bb.37:
	s_mov_b32 s3, exec_lo
	s_mov_b32 s2, exec_lo
	v_mbcnt_lo_u32_b32 v5, s3, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_eq_u32_e32 0, v5
	s_cbranch_execz .LBB1_39
; %bb.38:
	s_bcnt1_i32_b32 s0, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v6, v[5:6], s[4:5] offset:96
.LBB1_39:
	s_or_b32 exec_lo, exec_lo, s2
	v_cmp_ne_u32_e64 s0, 0x100, v4
	s_and_b32 exec_lo, exec_lo, s0
	s_cbranch_execz .LBB1_42
; %bb.40:
	s_mov_b32 s2, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v4, s2, 0
	v_cmp_eq_u32_e64 s0, 0, v4
	s_and_b32 s0, exec_lo, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s0
	s_cbranch_execz .LBB1_42
; %bb.41:
	s_bcnt1_i32_b32 s0, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v5, 0 :: v_dual_mov_b32 v4, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v5, v[4:5], s[4:5] offset:88
.LBB1_42:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 exec_lo, exec_lo, s6
	s_cbranch_execz .LBB1_51
; %bb.43:
	s_mov_b32 s2, exec_lo
	s_mov_b32 s1, exec_lo
	v_mbcnt_lo_u32_b32 v4, s2, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_eq_u32_e32 0, v4
	s_cbranch_execz .LBB1_45
; %bb.44:
	s_bcnt1_i32_b32 s0, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v5, 0 :: v_dual_mov_b32 v4, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v5, v[4:5], s[4:5] offset:56
.LBB1_45:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 s1, exec_lo
	v_cmpx_ne_u64_e64 v[0:1], v[2:3]
	s_cbranch_execz .LBB1_48
; %bb.46:
	s_mov_b32 s2, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v0, s2, 0
	v_cmp_eq_u32_e64 s0, 0, v0
	s_and_b32 s0, exec_lo, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s0
	s_cbranch_execz .LBB1_48
; %bb.47:
	s_bcnt1_i32_b32 s0, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[4:5] offset:64
.LBB1_48:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 exec_lo, exec_lo, vcc_lo
	s_cbranch_execz .LBB1_51
; %bb.49:
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v0, s0, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 s1, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s1
	s_cbranch_execz .LBB1_51
; %bb.50:
	s_bcnt1_i32_b32 s0, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[4:5] offset:72
.LBB1_51:
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z14k_check_narrowiiPy
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 272
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
		.amdhsa_next_free_vgpr 14
		.amdhsa_next_free_sgpr 19
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
		.amdhsa_inst_pref_size 21
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
	.size	_Z14k_check_narrowiiPy, .Lfunc_end1-_Z14k_check_narrowiiPy
                                        ; -- End function
	.set _Z14k_check_narrowiiPy.num_vgpr, 14
	.set _Z14k_check_narrowiiPy.num_agpr, 0
	.set _Z14k_check_narrowiiPy.numbered_sgpr, 19
	.set _Z14k_check_narrowiiPy.num_named_barrier, 0
	.set _Z14k_check_narrowiiPy.private_seg_size, 0
	.set _Z14k_check_narrowiiPy.uses_vcc, 1
	.set _Z14k_check_narrowiiPy.uses_flat_scratch, 0
	.set _Z14k_check_narrowiiPy.has_dyn_sized_stack, 0
	.set _Z14k_check_narrowiiPy.has_recursion, 0
	.set _Z14k_check_narrowiiPy.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 2580
; TotalNumSgprs: 21
; NumVgprs: 14
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 21
; NumVGPRsForWavesPerEU: 14
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
	.protected	_Z12k_check_polyPy      ; -- Begin function _Z12k_check_polyPy
	.globl	_Z12k_check_polyPy
	.p2align	8
	.type	_Z12k_check_polyPy,@function
_Z12k_check_polyPy:                     ; @_Z12k_check_polyPy
; %bb.0:
	s_load_b32 s3, s[0:1], 0x14
	s_waitcnt lgkmcnt(0)
	s_and_b32 s3, s3, 0xffff
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mad_u64_u32 v[0:1], null, s2, s3, v[0:1]
	s_mov_b32 s2, exec_lo
	v_cmpx_gt_i32_e32 0x69, v0
	s_cbranch_execz .LBB2_15
; %bb.1:
	v_mul_hi_i32 v1, 0x88888889, v0
	s_load_b64 s[0:1], s[0:1], 0x0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v1, v1, v0
	v_lshrrev_b32_e32 v2, 31, v1
	v_ashrrev_i32_e32 v1, 3, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v9, v1, v2
	v_add_nc_u32_e32 v6, -3, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mad_i64_i32 v[2:3], null, v6, v6, 0
	v_mad_u64_u32 v[4:5], null, v2, -5, 0xf0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mov_b32_e32 v1, v5
	v_mul_lo_u32 v10, v4, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_mad_u64_u32 v[7:8], null, v3, -5, v[1:2]
	v_mul_lo_u32 v1, v9, 15
	v_mad_i64_i32 v[8:9], null, 0x3c0, v6, 0
	v_sub_nc_u32_e32 v5, v7, v2
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_sub_nc_u32_e32 v7, v0, v1
	v_mad_u64_u32 v[0:1], null, v4, v2, v[8:9]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_mul_lo_u32 v4, v5, v2
	v_add_nc_u32_e32 v5, -7, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_ashrrev_i32_e32 v7, 31, v5
	v_add3_u32 v4, v4, v1, v10
	v_lshl_add_u32 v9, v5, 16, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_mul_lo_u32 v7, v0, v7
	v_mad_u64_u32 v[0:1], null, v0, v5, 0
	v_mul_lo_u32 v8, v4, v5
	;;#ASMSTART
	v_mul_i32_i24 v5, v9, v9
	v_mul_lo_u32 v10, v5, v9
	v_mul_i32_i24 v4, v9, 80
	v_add_nc_u32 v4, 0x1e0, v4
	v_sub_nc_u32 v4, v4, v10
	v_mul_lo_u32 v4, v5, v4
	v_add_nc_u32 v4, 0x8000, v4
	v_bfe_i32 v4, v4, 16, 16
	;;#ASMEND
	v_ashrrev_i32_e32 v5, 31, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add3_u32 v1, v1, v7, v8
	v_ashrrev_i32_e32 v7, 31, v6
	v_cmp_ne_u64_e32 vcc_lo, v[0:1], v[4:5]
	;;#ASMSTART
	v_bfe_i32 v4, v9, 0, 16
	v_add_nc_u32 v5, 0x8000, v9
	v_ashrrev_i32 v5, 16, v5
	v_mul_i32_i24 v8, v4, v4
	v_mul_i32_i24 v8, v8, -5
	v_add_nc_u32 v8, 240, v8
	v_mad_i32_i24 v8, v4, v8, 960
	v_mul_i32_i24 v8, v4, v8
	v_mul_i32_i24 v4, v5, v8
	;;#ASMEND
	s_and_saveexec_b32 s2, vcc_lo
	s_cbranch_execz .LBB2_4
; %bb.2:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v5, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v5
	s_and_b32 s4, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s4
	s_cbranch_execz .LBB2_4
; %bb.3:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v9, 0 :: v_dual_mov_b32 v8, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v9, v[8:9], s[0:1]
.LBB2_4:
	s_or_b32 exec_lo, exec_lo, s2
	v_ashrrev_i32_e32 v5, 31, v4
	s_mov_b32 s2, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u64_e64 v[0:1], v[4:5]
	s_cbranch_execz .LBB2_7
; %bb.5:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v4, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v4
	s_and_b32 s4, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s4
	s_cbranch_execz .LBB2_7
; %bb.6:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v5, 0 :: v_dual_mov_b32 v4, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v5, v[4:5], s[0:1] offset:8
.LBB2_7:
	s_or_b32 exec_lo, exec_lo, s2
	v_sub_co_u32 v4, vcc_lo, 0x50, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_sub_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	s_mov_b32 s2, exec_lo
	v_mul_lo_u32 v7, v4, v7
	v_mul_lo_u32 v8, v5, v6
	v_mad_u64_u32 v[4:5], null, v4, v6, 0x1e0
	v_add3_u32 v5, v8, v5, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_lo_u32 v6, v4, v3
	v_mul_lo_u32 v5, v5, v2
	v_mad_u64_u32 v[2:3], null, v4, v2, 0x8000
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v3, v5, v3, v6
	v_cmpx_lt_u64_e32 0xffff, v[2:3]
	s_cbranch_execz .LBB2_10
; %bb.8:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v2, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v2
	s_and_b32 s4, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s4
	s_cbranch_execz .LBB2_10
; %bb.9:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v3, 0 :: v_dual_mov_b32 v2, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v3, v[2:3], s[0:1] offset:16
.LBB2_10:
	s_or_b32 exec_lo, exec_lo, s2
	v_add_co_u32 v0, vcc_lo, 0x8000, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, 0, v1, vcc_lo
	s_mov_b32 s2, exec_lo
	v_cmpx_lt_u64_e32 0xffff, v[0:1]
	s_cbranch_execz .LBB2_13
; %bb.11:
	s_mov_b32 s3, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v0, s3, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 s4, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s4
	s_cbranch_execz .LBB2_13
; %bb.12:
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s3
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[0:1] offset:24
.LBB2_13:
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mov_b32 s2, exec_lo
	v_mbcnt_lo_u32_b32 v0, s2, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 s3, exec_lo, vcc_lo
	s_mov_b32 exec_lo, s3
	s_cbranch_execz .LBB2_15
; %bb.14:
	s_bcnt1_i32_b32 s2, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s2
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[0:1] offset:32
.LBB2_15:
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z12k_check_polyPy
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 264
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
		.amdhsa_next_free_vgpr 11
		.amdhsa_next_free_sgpr 5
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
		.amdhsa_inst_pref_size 7
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end2:
	.size	_Z12k_check_polyPy, .Lfunc_end2-_Z12k_check_polyPy
                                        ; -- End function
	.set _Z12k_check_polyPy.num_vgpr, 11
	.set _Z12k_check_polyPy.num_agpr, 0
	.set _Z12k_check_polyPy.numbered_sgpr, 5
	.set _Z12k_check_polyPy.num_named_barrier, 0
	.set _Z12k_check_polyPy.private_seg_size, 0
	.set _Z12k_check_polyPy.uses_vcc, 1
	.set _Z12k_check_polyPy.uses_flat_scratch, 0
	.set _Z12k_check_polyPy.has_dyn_sized_stack, 0
	.set _Z12k_check_polyPy.has_recursion, 0
	.set _Z12k_check_polyPy.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 812
; TotalNumSgprs: 7
; NumVgprs: 11
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 7
; NumVGPRsForWavesPerEU: 11
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
	.protected	_Z16k_check_bilineariiiPy ; -- Begin function _Z16k_check_bilineariiiPy
	.globl	_Z16k_check_bilineariiiPy
	.p2align	8
	.type	_Z16k_check_bilineariiiPy,@function
_Z16k_check_bilineariiiPy:              ; @_Z16k_check_bilineariiiPy
; %bb.0:
	s_clause 0x1
	s_load_b32 s3, s[0:1], 0x24
	s_load_b128 s[4:7], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_and_b32 s3, s3, 0xffff
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mad_u64_u32 v[0:1], null, s2, s3, v[0:1]
	s_mov_b32 s2, exec_lo
	v_cmpx_gt_i32_e64 s4, v0
	s_cbranch_execz .LBB3_14
; %bb.1:
	s_cmp_lt_i32 s5, 1
	s_cbranch_scc1 .LBB3_5
; %bb.2:
	s_lshl_b32 s2, s6, 1
	v_mad_u64_u32 v[4:5], null, 0x9e3779b9, v0, 0xffffffff9e3779b9
	s_or_b32 s2, s2, 1
	v_mov_b32_e32 v2, 0
	s_cvt_f32_u32 s3, s2
	s_sub_i32 s4, 0, s2
	v_mov_b32_e32 v3, 0
	v_mov_b32_e32 v5, 0
	v_rcp_iflag_f32_e32 v1, s3
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_3)
	v_readfirstlane_b32 s3, v1
	v_mov_b32_e32 v0, 0
	v_mov_b32_e32 v1, 0
	s_mul_f32 s3, s3, 0x4f7ffffe
	s_cvt_u32_f32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_3) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s4, s4, s3
	s_mul_hi_u32 s4, s3, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_i32 s3, s3, s4
.LBB3_3:                                ; =>This Inner Loop Header: Depth=1
	v_lshlrev_b32_e32 v6, 13, v4
	s_add_i32 s5, s5, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	s_cmp_eq_u32 s5, 0
	v_xor_b32_e32 v4, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v6, 17, v4
	v_xor_b32_e32 v4, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v6, 5, v4
	v_xor_b32_e32 v4, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_mul_hi_u32 v7, v4, s3
	v_lshlrev_b32_e32 v6, 13, v4
	v_xor_b32_e32 v6, v6, v4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_lo_u32 v7, v7, s2
	v_lshrrev_b32_e32 v8, 17, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_xor_b32_e32 v6, v8, v6
	v_sub_nc_u32_e32 v4, v4, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_subrev_nc_u32_e32 v8, s2, v4
	v_cmp_le_u32_e32 vcc_lo, s2, v4
	v_dual_cndmask_b32 v4, v4, v8 :: v_dual_lshlrev_b32 v7, 5, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_xor_b32_e32 v6, v7, v6
	v_subrev_nc_u32_e32 v9, s2, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_mul_hi_u32 v8, v6, s3
	v_cmp_le_u32_e32 vcc_lo, s2, v4
	v_dual_cndmask_b32 v4, v4, v9 :: v_dual_lshlrev_b32 v7, 13, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_xor_b32_e32 v7, v7, v6
	v_mul_lo_u32 v8, v8, s2
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_subrev_nc_u32_e32 v10, s6, v4
	v_lshrrev_b32_e32 v9, 17, v7
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_sub_nc_u32_e32 v6, v6, v8
	v_xor_b32_e32 v4, v9, v7
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_ashrrev_i32_e32 v8, 31, v10
	v_subrev_nc_u32_e32 v9, s2, v6
	v_cmp_le_u32_e32 vcc_lo, s2, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_cndmask_b32 v6, v6, v9 :: v_dual_lshlrev_b32 v7, 5, v4
	v_xor_b32_e32 v4, v7, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_subrev_nc_u32_e32 v9, s2, v6
	v_mul_hi_u32 v7, 0xaaaaaaab, v4
	v_cmp_le_u32_e32 vcc_lo, s2, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cndmask_b32_e32 v6, v6, v9, vcc_lo
	v_lshrrev_b32_e32 v7, 1, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_subrev_nc_u32_e32 v9, s6, v6
	v_lshl_add_u32 v6, v7, 1, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_ashrrev_i32_e32 v11, 31, v9
	v_xad_u32 v12, v6, -1, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mad_i64_i32 v[6:7], null, v10, v12, 0
	v_mul_lo_u32 v8, v6, v8
	s_delay_alu instid0(VALU_DEP_2)
	v_mul_lo_u32 v13, v7, v10
	v_mad_u64_u32 v[2:3], null, v6, v10, v[2:3]
	v_mul_lo_u32 v11, v6, v11
	v_mul_lo_u32 v7, v7, v9
	v_mad_u64_u32 v[0:1], null, v6, v9, v[0:1]
	v_lshl_add_u32 v9, v9, 16, v10
	;;#ASMSTART
	v_mul_i32_i24 v6, v9, v9
	v_mul_i32_i24 v6, v6, v12
	v_add_nc_u32 v6, v6, v5
	;;#ASMEND
	v_mov_b32_e32 v5, v6
	v_add3_u32 v3, v13, v3, v8
	s_delay_alu instid0(VALU_DEP_4)
	v_add3_u32 v1, v7, v1, v11
	s_cbranch_scc0 .LBB3_3
; %bb.4:
	v_add_co_u32 v2, vcc_lo, 0xffff0000, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_co_ci_u32_e64 v3, null, -1, v3, vcc_lo
	s_mov_b32 s2, 0xfffe0000
	s_mov_b32 s3, -1
	v_cmp_gt_u64_e64 s4, s[2:3], v[2:3]
	s_branch .LBB3_6
.LBB3_5:
	v_mov_b32_e32 v0, 0
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v6, 0
	s_mov_b32 s4, 0
.LBB3_6:
	s_load_b64 s[2:3], s[0:1], 0x10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, vcc_lo, 0xffffc000, v0
	v_add_co_ci_u32_e64 v3, null, -1, v1, vcc_lo
	s_movk_i32 s0, 0x8000
	s_mov_b32 s1, -1
	;;#ASMSTART
	v_add_nc_u32 v4, 0x10000, v6
	v_bfe_i32 v4, v4, 17, 15
	;;#ASMEND
	v_ashrrev_i32_e32 v5, 31, v4
	v_cmp_gt_u64_e32 vcc_lo, s[0:1], v[2:3]
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_ne_u64_e64 s0, v[0:1], v[4:5]
	s_or_b32 s1, s4, vcc_lo
	s_xor_b32 s4, s1, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s4, s4, s0
	s_and_saveexec_b32 s0, s4
	s_cbranch_execz .LBB3_9
; %bb.7:
	s_mov_b32 s4, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v0, s4, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 s5, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s5
	s_cbranch_execz .LBB3_9
; %bb.8:
	s_bcnt1_i32_b32 s4, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s4
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[2:3]
.LBB3_9:
	s_or_b32 exec_lo, exec_lo, s0
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB3_12
; %bb.10:
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mbcnt_lo_u32_b32 v0, s1, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 s4, exec_lo, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 exec_lo, s4
	s_cbranch_execz .LBB3_12
; %bb.11:
	s_bcnt1_i32_b32 s1, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s1
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[2:3] offset:8
.LBB3_12:
	s_or_b32 exec_lo, exec_lo, s0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mov_b32 s0, exec_lo
	v_mbcnt_lo_u32_b32 v0, s0, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 s1, exec_lo, vcc_lo
	s_mov_b32 exec_lo, s1
	s_cbranch_execz .LBB3_14
; %bb.13:
	s_bcnt1_i32_b32 s0, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v0, s0
	s_waitcnt lgkmcnt(0)
	global_atomic_add_u64 v1, v[0:1], s[2:3] offset:16
.LBB3_14:
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z16k_check_bilineariiiPy
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
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
		.amdhsa_next_free_vgpr 14
		.amdhsa_next_free_sgpr 8
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
		.amdhsa_inst_pref_size 8
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end3:
	.size	_Z16k_check_bilineariiiPy, .Lfunc_end3-_Z16k_check_bilineariiiPy
                                        ; -- End function
	.set _Z16k_check_bilineariiiPy.num_vgpr, 14
	.set _Z16k_check_bilineariiiPy.num_agpr, 0
	.set _Z16k_check_bilineariiiPy.numbered_sgpr, 8
	.set _Z16k_check_bilineariiiPy.num_named_barrier, 0
	.set _Z16k_check_bilineariiiPy.private_seg_size, 0
	.set _Z16k_check_bilineariiiPy.uses_vcc, 1
	.set _Z16k_check_bilineariiiPy.uses_flat_scratch, 0
	.set _Z16k_check_bilineariiiPy.has_dyn_sized_stack, 0
	.set _Z16k_check_bilineariiiPy.has_recursion, 0
	.set _Z16k_check_bilineariiiPy.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 908
; TotalNumSgprs: 10
; NumVgprs: 14
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 10
; NumVGPRsForWavesPerEU: 14
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI6VEmptyEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI6VEmptyEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI6VEmptyEvPKiS2_Pii ; -- Begin function _Z6k_rateI6VEmptyEvPKiS2_Pii
	.globl	_Z6k_rateI6VEmptyEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI6VEmptyEvPKiS2_Pii,@function
_Z6k_rateI6VEmptyEvPKiS2_Pii:           ; @_Z6k_rateI6VEmptyEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB4_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v1, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[9:12], v1, s[6:7]
	global_load_b128 v[5:8], v1, s[4:5]
	global_load_b128 v[13:16], v1, s[6:7] offset:16
	global_load_b128 v[1:4], v1, s[4:5] offset:16
.LBB4_2:                                ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_cbranch_scc1 .LBB4_2
	s_branch .LBB4_4
.LBB4_3:
	v_dual_mov_b32 v4, 0 :: v_dual_mov_b32 v3, 0
	v_dual_mov_b32 v2, 0 :: v_dual_mov_b32 v1, 0
	v_dual_mov_b32 v8, 0 :: v_dual_mov_b32 v7, 0
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v5, 0
.LBB4_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v9, v6, v5
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[5:6], null, s2, s0, v[0:1]
	v_mov_b32_e32 v6, 0
	v_add3_u32 v0, v7, v9, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v1, v0, v2
	v_lshlrev_b64 v[0:1], 2, v[5:6]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v3, v2, v4
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI6VEmptyEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 17
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI6VEmptyEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI6VEmptyEvPKiS2_Pii,comdat
.Lfunc_end4:
	.size	_Z6k_rateI6VEmptyEvPKiS2_Pii, .Lfunc_end4-_Z6k_rateI6VEmptyEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.num_vgpr, 17
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI6VEmptyEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 17
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 17
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI8VWSepMulEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI8VWSepMulEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI8VWSepMulEvPKiS2_Pii ; -- Begin function _Z6k_rateI8VWSepMulEvPKiS2_Pii
	.globl	_Z6k_rateI8VWSepMulEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI8VWSepMulEvPKiS2_Pii,@function
_Z6k_rateI8VWSepMulEvPKiS2_Pii:         ; @_Z6k_rateI8VWSepMulEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB5_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB5_2:                                ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v5, v1
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v6, v2
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v7, v3
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v8, v4
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v13, v9
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v14, v10
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v15, v11
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v16, v12
	;;#ASMEND
	s_cbranch_scc1 .LBB5_2
	s_branch .LBB5_4
.LBB5_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB5_4:
	s_set_inst_prefetch_distance 0x2
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI8VWSepMulEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 25
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI8VWSepMulEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI8VWSepMulEvPKiS2_Pii,comdat
.Lfunc_end5:
	.size	_Z6k_rateI8VWSepMulEvPKiS2_Pii, .Lfunc_end5-_Z6k_rateI8VWSepMulEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.num_vgpr, 25
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI8VWSepMulEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 268
; TotalNumSgprs: 12
; NumVgprs: 25
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 25
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI9VWFused24EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI9VWFused24EvPKiS2_Pii,comdat
	.protected	_Z6k_rateI9VWFused24EvPKiS2_Pii ; -- Begin function _Z6k_rateI9VWFused24EvPKiS2_Pii
	.globl	_Z6k_rateI9VWFused24EvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI9VWFused24EvPKiS2_Pii,@function
_Z6k_rateI9VWFused24EvPKiS2_Pii:        ; @_Z6k_rateI9VWFused24EvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB6_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB6_2:                                ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v5, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v6, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v7, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v8, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v13, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v25, v14, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v26, v15, v15
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v27, v16, v16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v17, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v18, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v19, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v20, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v22, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v25, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v26, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v27, 17, 15
	;;#ASMEND
	s_cbranch_scc1 .LBB6_2
	s_branch .LBB6_4
.LBB6_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB6_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI9VWFused24EvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 28
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI9VWFused24EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI9VWFused24EvPKiS2_Pii,comdat
.Lfunc_end6:
	.size	_Z6k_rateI9VWFused24EvPKiS2_Pii, .Lfunc_end6-_Z6k_rateI9VWFused24EvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.num_vgpr, 28
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI9VWFused24EvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 28
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 28
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI9VWFusedLoEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI9VWFusedLoEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI9VWFusedLoEvPKiS2_Pii ; -- Begin function _Z6k_rateI9VWFusedLoEvPKiS2_Pii
	.globl	_Z6k_rateI9VWFusedLoEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI9VWFusedLoEvPKiS2_Pii,@function
_Z6k_rateI9VWFusedLoEvPKiS2_Pii:        ; @_Z6k_rateI9VWFusedLoEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB7_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB7_2:                                ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v17, v5, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v18, v6, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v19, v7, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v20, v8, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v22, v13, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v25, v14, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v26, v15, v15
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v27, v16, v16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v17, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v18, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v19, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v20, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v22, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v25, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v26, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v27, 17, 15
	;;#ASMEND
	s_cbranch_scc1 .LBB7_2
	s_branch .LBB7_4
.LBB7_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB7_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI9VWFusedLoEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 28
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI9VWFusedLoEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI9VWFusedLoEvPKiS2_Pii,comdat
.Lfunc_end7:
	.size	_Z6k_rateI9VWFusedLoEvPKiS2_Pii, .Lfunc_end7-_Z6k_rateI9VWFusedLoEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.num_vgpr, 28
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI9VWFusedLoEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 28
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 28
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI10VWDecode24EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI10VWDecode24EvPKiS2_Pii,comdat
	.protected	_Z6k_rateI10VWDecode24EvPKiS2_Pii ; -- Begin function _Z6k_rateI10VWDecode24EvPKiS2_Pii
	.globl	_Z6k_rateI10VWDecode24EvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI10VWDecode24EvPKiS2_Pii,@function
_Z6k_rateI10VWDecode24EvPKiS2_Pii:      ; @_Z6k_rateI10VWDecode24EvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB8_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB8_2:                                ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v5, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v6, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v7, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v8, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v13, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v25, v14, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v26, v15, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v27, v16, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v21, 0x8000, v5
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v23, 0x8000, v6
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_add_nc_u32 v24, 0x8000, v7
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v28, 0x8000, v8
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v29, 0x8000, v13
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v30, 0x8000, v14
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v31, 0x8000, v15
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v32, 0x8000, v16
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v21, 16, v21
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v23, 16, v23
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v33, 16, v24
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v28, 16, v28
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v29, 16, v29
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v30, 16, v30
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v31, 16, v31
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v32, 16, v32
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v17, v21
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v18, v23
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v19, v33
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v20, v28
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v22, v29
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v25, v30
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v26, v31
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v27, v32
	;;#ASMEND
	s_cbranch_scc1 .LBB8_2
	s_branch .LBB8_4
.LBB8_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB8_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI10VWDecode24EvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 34
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI10VWDecode24EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI10VWDecode24EvPKiS2_Pii,comdat
.Lfunc_end8:
	.size	_Z6k_rateI10VWDecode24EvPKiS2_Pii, .Lfunc_end8-_Z6k_rateI10VWDecode24EvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.num_vgpr, 34
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI10VWDecode24EvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 34
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 34
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI10VWDecodeLoEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI10VWDecodeLoEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI10VWDecodeLoEvPKiS2_Pii ; -- Begin function _Z6k_rateI10VWDecodeLoEvPKiS2_Pii
	.globl	_Z6k_rateI10VWDecodeLoEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI10VWDecodeLoEvPKiS2_Pii,@function
_Z6k_rateI10VWDecodeLoEvPKiS2_Pii:      ; @_Z6k_rateI10VWDecodeLoEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB9_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB9_2:                                ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v5, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v6, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v7, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v8, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v13, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v25, v14, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v26, v15, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v27, v16, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v21, 0x8000, v5
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v23, 0x8000, v6
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_add_nc_u32 v24, 0x8000, v7
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v28, 0x8000, v8
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v29, 0x8000, v13
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v30, 0x8000, v14
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v31, 0x8000, v15
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v32, 0x8000, v16
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v21, 16, v21
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v23, 16, v23
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v33, 16, v24
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v28, 16, v28
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v29, 16, v29
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v30, 16, v30
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v31, 16, v31
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v32, 16, v32
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v24, v17, v21
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v23, v18, v23
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v21, v19, v33
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v20, v20, v28
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v18, v22, v29
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v22, v25, v30
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v19, v26, v31
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v17, v27, v32
	;;#ASMEND
	s_cbranch_scc1 .LBB9_2
	s_branch .LBB9_4
.LBB9_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB9_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI10VWDecodeLoEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 34
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI10VWDecodeLoEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI10VWDecodeLoEvPKiS2_Pii,comdat
.Lfunc_end9:
	.size	_Z6k_rateI10VWDecodeLoEvPKiS2_Pii, .Lfunc_end9-_Z6k_rateI10VWDecodeLoEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.num_vgpr, 34
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 34
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 34
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI11VWFusedReluEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VWFusedReluEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI11VWFusedReluEvPKiS2_Pii ; -- Begin function _Z6k_rateI11VWFusedReluEvPKiS2_Pii
	.globl	_Z6k_rateI11VWFusedReluEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI11VWFusedReluEvPKiS2_Pii,@function
_Z6k_rateI11VWFusedReluEvPKiS2_Pii:     ; @_Z6k_rateI11VWFusedReluEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB10_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB10_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v5, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v6, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v7, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v8, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v13, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v14, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v15, v15
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_mul_i32_i24 v24, v16, v16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v17, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v18, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v19, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v20, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v25, v21, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v22, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v26, v23, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v27, v24, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v5, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v6, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v28, v7, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v29, v8, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v30, v13, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v31, v14, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v32, v15, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v33, v16, 15, 1
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v24, v21, 0, v17
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v23, v23, 0, v18
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v21, v28, 0, v19
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v20, v29, 0, v20
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v18, v30, 0, v25
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v22, v31, 0, v22
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v19, v32, 0, v26
	;;#ASMEND
	;;#ASMSTART
	v_bfi_b32 v17, v33, 0, v27
	;;#ASMEND
	s_cbranch_scc1 .LBB10_2
	s_branch .LBB10_4
.LBB10_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB10_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI11VWFusedReluEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 34
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI11VWFusedReluEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VWFusedReluEvPKiS2_Pii,comdat
.Lfunc_end10:
	.size	_Z6k_rateI11VWFusedReluEvPKiS2_Pii, .Lfunc_end10-_Z6k_rateI11VWFusedReluEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.num_vgpr, 34
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI11VWFusedReluEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 34
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 34
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI12VWDecodeReluEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI12VWDecodeReluEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI12VWDecodeReluEvPKiS2_Pii ; -- Begin function _Z6k_rateI12VWDecodeReluEvPKiS2_Pii
	.globl	_Z6k_rateI12VWDecodeReluEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI12VWDecodeReluEvPKiS2_Pii,@function
_Z6k_rateI12VWDecodeReluEvPKiS2_Pii:    ; @_Z6k_rateI12VWDecodeReluEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB11_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB11_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v5, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v6, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v7, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v8, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v13, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v14, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v15, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v16, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v25, 0x8000, v5
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v26, 0x8000, v6
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v27, 0x8000, v7
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v28, 0x8000, v8
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v29, 0x8000, v13
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v30, 0x8000, v14
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v31, 0x8000, v15
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v32, 0x8000, v16
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_ashrrev_i32 v25, 16, v25
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v26, 16, v26
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v27, 16, v27
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v28, 16, v28
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v29, 16, v29
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v30, 16, v30
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v31, 16, v31
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v32, 16, v32
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v17, 0, v17
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v18, 0, v18
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v19, 0, v19
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v20, 0, v20
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v33, 0, v21
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v22, 0, v22
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v34, 0, v23
	;;#ASMEND
	;;#ASMSTART
	v_max_i32 v35, 0, v24
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v17, v25
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v18, v26
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v19, v27
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v20, v28
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v33, v29
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v22, v30
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v34, v31
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v35, v32
	;;#ASMEND
	s_cbranch_scc1 .LBB11_2
	s_branch .LBB11_4
.LBB11_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB11_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI12VWDecodeReluEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI12VWDecodeReluEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI12VWDecodeReluEvPKiS2_Pii,comdat
.Lfunc_end11:
	.size	_Z6k_rateI12VWDecodeReluEvPKiS2_Pii, .Lfunc_end11-_Z6k_rateI12VWDecodeReluEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.num_vgpr, 36
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 36
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 36
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI11VWPackFusedEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VWPackFusedEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI11VWPackFusedEvPKiS2_Pii ; -- Begin function _Z6k_rateI11VWPackFusedEvPKiS2_Pii
	.globl	_Z6k_rateI11VWPackFusedEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI11VWPackFusedEvPKiS2_Pii,@function
_Z6k_rateI11VWPackFusedEvPKiS2_Pii:     ; @_Z6k_rateI11VWPackFusedEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB12_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB12_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_lshl_add_u32 v17, v1, 16, v5
	;;#ASMEND
	;;#ASMSTART
	v_lshl_add_u32 v18, v2, 16, v6
	;;#ASMEND
	;;#ASMSTART
	v_lshl_add_u32 v19, v3, 16, v7
	;;#ASMEND
	;;#ASMSTART
	v_lshl_add_u32 v20, v4, 16, v8
	;;#ASMEND
	;;#ASMSTART
	v_lshl_add_u32 v21, v9, 16, v13
	;;#ASMEND
	;;#ASMSTART
	v_lshl_add_u32 v22, v10, 16, v14
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_lshl_add_u32 v23, v11, 16, v15
	;;#ASMEND
	;;#ASMSTART
	v_lshl_add_u32 v24, v12, 16, v16
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v17, v17
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v18, v18
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v19, v19
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v20, v20
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v25, v21, v21
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v22, v22
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v26, v23, v23
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v27, v24, v24
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v17, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v18, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v19, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v20, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v25, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v22, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v26, 17, 15
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v27, 17, 15
	;;#ASMEND
	s_cbranch_scc1 .LBB12_2
	s_branch .LBB12_4
.LBB12_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB12_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI11VWPackFusedEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 28
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI11VWPackFusedEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VWPackFusedEvPKiS2_Pii,comdat
.Lfunc_end12:
	.size	_Z6k_rateI11VWPackFusedEvPKiS2_Pii, .Lfunc_end12-_Z6k_rateI11VWPackFusedEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.num_vgpr, 28
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI11VWPackFusedEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 28
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 28
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI11VWPolyFusedEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VWPolyFusedEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI11VWPolyFusedEvPKiS2_Pii ; -- Begin function _Z6k_rateI11VWPolyFusedEvPKiS2_Pii
	.globl	_Z6k_rateI11VWPolyFusedEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI11VWPolyFusedEvPKiS2_Pii,@function
_Z6k_rateI11VWPolyFusedEvPKiS2_Pii:     ; @_Z6k_rateI11VWPolyFusedEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB13_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB13_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v5, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v6, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v7, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v8, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v13, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v14, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v15, v15
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v16, v16
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v25, v17, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v26, v18, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v27, v19, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v28, v20, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v29, v21, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v30, v22, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v31, v23, v15
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v32, v24, v16
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v33, v5, 80
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v34, v6, 80
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v35, v7, 80
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v36, v8, 80
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v37, v13, 80
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v38, v14, 80
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v39, v15, 80
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v40, v16, 80
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v33, 0x1e0, v33
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v34, 0x1e0, v34
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v35, 0x1e0, v35
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v36, 0x1e0, v36
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v37, 0x1e0, v37
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v38, 0x1e0, v38
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v39, 0x1e0, v39
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v40, 0x1e0, v40
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v25, v33, v25
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v26, v34, v26
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v27, v35, v27
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v28, v36, v28
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v29, v37, v29
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v30, v38, v30
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v31, v39, v31
	;;#ASMEND
	;;#ASMSTART
	v_sub_nc_u32 v32, v40, v32
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v17, v17, v25
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v18, v18, v26
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v19, v19, v27
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v20, v20, v28
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v21, v21, v29
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v22, v22, v30
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_mul_lo_u32 v23, v23, v31
	;;#ASMEND
	;;#ASMSTART
	v_mul_lo_u32 v24, v24, v32
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v17, 0x8000, v17
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v18, 0x8000, v18
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v19, 0x8000, v19
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v20, 0x8000, v20
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v25, 0x8000, v21
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v22, 0x8000, v22
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v26, 0x8000, v23
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v27, 0x8000, v24
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v17, 16, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v18, 16, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v19, 16, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v20, 16, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v25, 16, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v22, 16, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v26, 16, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v27, 16, 16
	;;#ASMEND
	s_cbranch_scc1 .LBB13_2
	s_branch .LBB13_4
.LBB13_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB13_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI11VWPolyFusedEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 41
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI11VWPolyFusedEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VWPolyFusedEvPKiS2_Pii,comdat
.Lfunc_end13:
	.size	_Z6k_rateI11VWPolyFusedEvPKiS2_Pii, .Lfunc_end13-_Z6k_rateI11VWPolyFusedEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.num_vgpr, 41
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 41
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 5
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 41
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI12VWPolyDecodeEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii ; -- Begin function _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii
	.globl	_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii,@function
_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii:    ; @_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB14_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB14_2:                               ; =>This Inner Loop Header: Depth=1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v5, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v6, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v7, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v8, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v13, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v14, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v15, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v16, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v25, 0x8000, v5
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v26, 0x8000, v6
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v27, 0x8000, v7
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v28, 0x8000, v8
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v29, 0x8000, v13
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v30, 0x8000, v14
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v31, 0x8000, v15
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v32, 0x8000, v16
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v25, 16, v25
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v26, 16, v26
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v27, 16, v27
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v28, 16, v28
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v29, 16, v29
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v30, 16, v30
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v31, 16, v31
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v32, 16, v32
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v33, v17, v17
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v34, v18, v18
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v35, v19, v19
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v36, v20, v20
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v37, v21, v21
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v38, v22, v22
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v39, v23, v23
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v40, v24, v24
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v33, v33, -5
	;;#ASMEND
	s_add_i32 s3, s3, -1
	;;#ASMSTART
	v_mul_i32_i24 v34, v34, -5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v35, v35, -5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v36, v36, -5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v37, v37, -5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v38, v38, -5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v39, v39, -5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v40, v40, -5
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v33, 240, v33
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v34, 240, v34
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v35, 240, v35
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v36, 240, v36
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v37, 240, v37
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v38, 240, v38
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v39, 240, v39
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v40, 240, v40
	;;#ASMEND
	;;#ASMSTART
	v_mad_i32_i24 v33, v17, v33, 960
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_mad_i32_i24 v34, v18, v34, 960
	;;#ASMEND
	;;#ASMSTART
	v_mad_i32_i24 v35, v19, v35, 960
	;;#ASMEND
	;;#ASMSTART
	v_mad_i32_i24 v36, v20, v36, 960
	;;#ASMEND
	;;#ASMSTART
	v_mad_i32_i24 v37, v21, v37, 960
	;;#ASMEND
	;;#ASMSTART
	v_mad_i32_i24 v38, v22, v38, 960
	;;#ASMEND
	;;#ASMSTART
	v_mad_i32_i24 v39, v23, v39, 960
	;;#ASMEND
	;;#ASMSTART
	v_mad_i32_i24 v40, v24, v40, 960
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v17, v33
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v18, v34
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v19, v35
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v20, v36
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v33, v21, v37
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v22, v38
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v34, v23, v39
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v35, v24, v40
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v25, v17
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v26, v18
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v27, v19
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v28, v20
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v29, v33
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v30, v22
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v31, v34
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v32, v35
	;;#ASMEND
	s_cbranch_scc1 .LBB14_2
	s_branch .LBB14_4
.LBB14_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB14_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 41
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI12VWPolyDecodeEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii,comdat
.Lfunc_end14:
	.size	_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii, .Lfunc_end14-_Z6k_rateI12VWPolyDecodeEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.num_vgpr, 41
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 41
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 5
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 41
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI7VNFusedEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI7VNFusedEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI7VNFusedEvPKiS2_Pii ; -- Begin function _Z6k_rateI7VNFusedEvPKiS2_Pii
	.globl	_Z6k_rateI7VNFusedEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI7VNFusedEvPKiS2_Pii,@function
_Z6k_rateI7VNFusedEvPKiS2_Pii:          ; @_Z6k_rateI7VNFusedEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB15_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB15_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v5, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v6, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v7, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v8, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v13, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v25, v14, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v26, v15, v15
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v27, v16, v16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v17, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v18, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v19, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v20, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v22, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v25, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v26, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v27, 11, 9
	;;#ASMEND
	s_cbranch_scc1 .LBB15_2
	s_branch .LBB15_4
.LBB15_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB15_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI7VNFusedEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 28
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI7VNFusedEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI7VNFusedEvPKiS2_Pii,comdat
.Lfunc_end15:
	.size	_Z6k_rateI7VNFusedEvPKiS2_Pii, .Lfunc_end15-_Z6k_rateI7VNFusedEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.num_vgpr, 28
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI7VNFusedEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 28
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 28
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI12VNFusedGuardEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI12VNFusedGuardEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI12VNFusedGuardEvPKiS2_Pii ; -- Begin function _Z6k_rateI12VNFusedGuardEvPKiS2_Pii
	.globl	_Z6k_rateI12VNFusedGuardEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI12VNFusedGuardEvPKiS2_Pii,@function
_Z6k_rateI12VNFusedGuardEvPKiS2_Pii:    ; @_Z6k_rateI12VNFusedGuardEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB16_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	v_mov_b32_e32 v17, 0x100
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB16_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v26, v5, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v27, v6, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v28, v7, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v29, v8, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v30, v13, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v31, v14, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v32, v15, v15
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v33, v16, v16
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v24, v26, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v25, v27, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v21, v28, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v23, v29, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v30, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v31, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v32, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v33, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v26
	v_cndmask_b32 v24, v24, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v27
	v_cndmask_b32 v25, v25, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v28
	v_cndmask_b32 v21, v21, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v29
	v_cndmask_b32 v23, v23, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v30
	v_cndmask_b32 v20, v20, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v31
	v_cndmask_b32 v22, v22, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v32
	v_cndmask_b32 v19, v19, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v33
	v_cndmask_b32 v18, v18, v17, vcc_lo
	;;#ASMEND
	s_cbranch_scc1 .LBB16_2
	s_branch .LBB16_4
.LBB16_3:
	v_dual_mov_b32 v18, 0 :: v_dual_mov_b32 v19, 0
	v_dual_mov_b32 v22, 0 :: v_dual_mov_b32 v23, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v25, 0 :: v_dual_mov_b32 v24, 0
.LBB16_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v25, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v23
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v20, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v18
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI12VNFusedGuardEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 34
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI12VNFusedGuardEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI12VNFusedGuardEvPKiS2_Pii,comdat
.Lfunc_end16:
	.size	_Z6k_rateI12VNFusedGuardEvPKiS2_Pii, .Lfunc_end16-_Z6k_rateI12VNFusedGuardEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.num_vgpr, 34
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 268
; TotalNumSgprs: 12
; NumVgprs: 34
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 34
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI8VNDecodeEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI8VNDecodeEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI8VNDecodeEvPKiS2_Pii ; -- Begin function _Z6k_rateI8VNDecodeEvPKiS2_Pii
	.globl	_Z6k_rateI8VNDecodeEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI8VNDecodeEvPKiS2_Pii,@function
_Z6k_rateI8VNDecodeEvPKiS2_Pii:         ; @_Z6k_rateI8VNDecodeEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB17_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB17_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v5, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v6, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v7, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v8, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v13, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v25, v14, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v26, v15, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v27, v16, 0, 10
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v21, 0x200, v5
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v23, 0x200, v6
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_add_nc_u32 v24, 0x200, v7
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v28, 0x200, v8
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v29, 0x200, v13
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v30, 0x200, v14
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v31, 0x200, v15
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v32, 0x200, v16
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v21, 10, v21
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v23, 10, v23
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v33, 10, v24
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v28, 10, v28
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v29, 10, v29
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v30, 10, v30
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v31, 10, v31
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v32, 10, v32
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v17, v21
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v18, v23
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v19, v33
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v20, v28
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v22, v29
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v25, v30
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v26, v31
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v27, v32
	;;#ASMEND
	s_cbranch_scc1 .LBB17_2
	s_branch .LBB17_4
.LBB17_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB17_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI8VNDecodeEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 34
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI8VNDecodeEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI8VNDecodeEvPKiS2_Pii,comdat
.Lfunc_end17:
	.size	_Z6k_rateI8VNDecodeEvPKiS2_Pii, .Lfunc_end17-_Z6k_rateI8VNDecodeEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.num_vgpr, 34
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI8VNDecodeEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 34
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 34
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI10VNFusedF32EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI10VNFusedF32EvPKiS2_Pii,comdat
	.protected	_Z6k_rateI10VNFusedF32EvPKiS2_Pii ; -- Begin function _Z6k_rateI10VNFusedF32EvPKiS2_Pii
	.globl	_Z6k_rateI10VNFusedF32EvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI10VNFusedF32EvPKiS2_Pii,@function
_Z6k_rateI10VNFusedF32EvPKiS2_Pii:      ; @_Z6k_rateI10VNFusedF32EvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB18_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB18_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v17, v5
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v18, v6
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v19, v7
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v20, v8
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v21, v13
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v22, v14
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v23, v15
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v24, v16
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v17, v17, v17
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v18, v18, v18
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v19, v19
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v20, v20
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v21, v21
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v22, v22
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_mul_i32_i24 v23, v23, v23
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v24, v24
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v17, v17, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v18, v18, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v19, v19, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v20, v20, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v25, v21, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v22, v22, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v26, v23, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v27, v24, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v24, v17
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v23, v18
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v21, v19
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v20, v20
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v18, v25
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v22, v22
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v19, v26
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v17, v27
	;;#ASMEND
	s_cbranch_scc1 .LBB18_2
	s_branch .LBB18_4
.LBB18_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB18_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI10VNFusedF32EvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 28
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI10VNFusedF32EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI10VNFusedF32EvPKiS2_Pii,comdat
.Lfunc_end18:
	.size	_Z6k_rateI10VNFusedF32EvPKiS2_Pii, .Lfunc_end18-_Z6k_rateI10VNFusedF32EvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.num_vgpr, 28
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI10VNFusedF32EvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 28
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 28
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii,comdat
	.protected	_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii ; -- Begin function _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii
	.globl	_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii,@function
_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii: ; @_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB19_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	v_mov_b32_e32 v17, 0x100
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB19_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v18, v5
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v19, v6
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v20, v7
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v21, v8
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v22, v13
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v23, v14
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v24, v15
	;;#ASMEND
	;;#ASMSTART
	v_cvt_i32_f32 v25, v16
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_mul_i32_i24 v18, v18, v18
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v19, v19, v19
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v20, v20, v20
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v21, v21, v21
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v22, v22, v22
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v23, v23, v23
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v24, v24, v24
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v25, v25, v25
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v26, v18, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v27, v19, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v28, v20, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v29, v21, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v30, v22, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v31, v23, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v32, v24, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v33, v25, 11, 9
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v18
	v_cndmask_b32 v26, v26, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v19
	v_cndmask_b32 v27, v27, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v20
	v_cndmask_b32 v28, v28, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v21
	v_cndmask_b32 v29, v29, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v22
	v_cndmask_b32 v30, v30, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v23
	v_cndmask_b32 v31, v31, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v24
	v_cndmask_b32 v32, v32, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cmp_eq_u32 vcc_lo, 0x10080100, v25
	v_cndmask_b32 v33, v33, v17, vcc_lo
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v25, v26
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v24, v27
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v22, v28
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v21, v29
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v19, v30
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v23, v31
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v20, v32
	;;#ASMEND
	;;#ASMSTART
	v_cvt_f32_i32 v18, v33
	;;#ASMEND
	s_cbranch_scc1 .LBB19_2
	s_branch .LBB19_4
.LBB19_3:
	v_dual_mov_b32 v18, 0 :: v_dual_mov_b32 v23, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v19, 0
	v_dual_mov_b32 v21, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v24, 0 :: v_dual_mov_b32 v25, 0
.LBB19_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v24, v25
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v22, v2, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v19, v2, v23
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v20, v2, v18
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 34
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii,"axG",@progbits,_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii,comdat
.Lfunc_end19:
	.size	_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii, .Lfunc_end19-_Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.num_vgpr, 34
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 268
; TotalNumSgprs: 12
; NumVgprs: 34
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 34
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z6k_rateI11VNDecodeF32EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VNDecodeF32EvPKiS2_Pii,comdat
	.protected	_Z6k_rateI11VNDecodeF32EvPKiS2_Pii ; -- Begin function _Z6k_rateI11VNDecodeF32EvPKiS2_Pii
	.globl	_Z6k_rateI11VNDecodeF32EvPKiS2_Pii
	.p2align	8
	.type	_Z6k_rateI11VNDecodeF32EvPKiS2_Pii,@function
_Z6k_rateI11VNDecodeF32EvPKiS2_Pii:     ; @_Z6k_rateI11VNDecodeF32EvPKiS2_Pii
; %bb.0:
	s_clause 0x2
	s_load_b32 s3, s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s3, 1
	s_cbranch_scc1 .LBB20_3
; %bb.1:
	v_lshlrev_b32_e32 v1, 5, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v13, 0x3e0, v1
	s_clause 0x3
	global_load_b128 v[1:4], v13, s[6:7]
	global_load_b128 v[5:8], v13, s[4:5]
	global_load_b128 v[9:12], v13, s[6:7] offset:16
	global_load_b128 v[13:16], v13, s[4:5] offset:16
.LBB20_2:                               ; =>This Inner Loop Header: Depth=1
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(2)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v17, 0x3a800000, v5
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v18, 0x3a800000, v6
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v19, 0x3a800000, v7
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v20, 0x3a800000, v8
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v21, 0x3a800000, v13
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v22, 0x3a800000, v14
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v23, 0x3a800000, v15
	;;#ASMEND
	s_cmp_lg_u32 s3, 0
	;;#ASMSTART
	v_mul_f32 v24, 0x3a800000, v16
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v17, v17
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v18, v18
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v19, v19
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v20, v20
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v25, v21
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v22, v22
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v26, v23
	;;#ASMEND
	;;#ASMSTART
	v_rndne_f32 v27, v24
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v21, v17, 0xc4800000, v5
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v23, v18, 0xc4800000, v6
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v28, v19, 0xc4800000, v7
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v29, v20, 0xc4800000, v8
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v30, v25, 0xc4800000, v13
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v31, v22, 0xc4800000, v14
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v32, v26, 0xc4800000, v15
	;;#ASMEND
	;;#ASMSTART
	v_fma_f32 v33, v27, 0xc4800000, v16
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v24, v21, v17
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v23, v23, v18
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v21, v28, v19
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v20, v29, v20
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v18, v30, v25
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v22, v31, v22
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v19, v32, v26
	;;#ASMEND
	;;#ASMSTART
	v_mul_f32 v17, v33, v27
	;;#ASMEND
	s_cbranch_scc1 .LBB20_2
	s_branch .LBB20_4
.LBB20_3:
	v_dual_mov_b32 v17, 0 :: v_dual_mov_b32 v22, 0
	v_dual_mov_b32 v19, 0 :: v_dual_mov_b32 v18, 0
	v_dual_mov_b32 v20, 0 :: v_dual_mov_b32 v21, 0
	v_dual_mov_b32 v23, 0 :: v_dual_mov_b32 v24, 0
.LBB20_4:
	s_load_b32 s0, s[0:1], 0x2c
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v2, v23, v24
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	v_mad_u64_u32 v[0:1], null, s2, s0, v[0:1]
	v_mov_b32_e32 v1, 0
	v_add3_u32 v2, v21, v2, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add3_u32 v2, v18, v2, v22
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v2, v19, v2, v17
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6k_rateI11VNDecodeF32EvPKiS2_Pii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 34
		.amdhsa_next_free_sgpr 10
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
		.amdhsa_inst_pref_size 3
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z6k_rateI11VNDecodeF32EvPKiS2_Pii,"axG",@progbits,_Z6k_rateI11VNDecodeF32EvPKiS2_Pii,comdat
.Lfunc_end20:
	.size	_Z6k_rateI11VNDecodeF32EvPKiS2_Pii, .Lfunc_end20-_Z6k_rateI11VNDecodeF32EvPKiS2_Pii
                                        ; -- End function
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.num_vgpr, 34
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.num_agpr, 0
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.numbered_sgpr, 10
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.num_named_barrier, 0
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.private_seg_size, 0
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.uses_vcc, 1
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.uses_flat_scratch, 0
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.has_dyn_sized_stack, 0
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.has_recursion, 0
	.set _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 260
; TotalNumSgprs: 12
; NumVgprs: 34
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 34
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z10k_bilinearILb1EEvPKiS1_Piii,"axG",@progbits,_Z10k_bilinearILb1EEvPKiS1_Piii,comdat
	.protected	_Z10k_bilinearILb1EEvPKiS1_Piii ; -- Begin function _Z10k_bilinearILb1EEvPKiS1_Piii
	.globl	_Z10k_bilinearILb1EEvPKiS1_Piii
	.p2align	8
	.type	_Z10k_bilinearILb1EEvPKiS1_Piii,@function
_Z10k_bilinearILb1EEvPKiS1_Piii:        ; @_Z10k_bilinearILb1EEvPKiS1_Piii
; %bb.0:
	s_load_b256 s[4:11], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s10, 1
	s_cbranch_scc1 .LBB21_7
; %bb.1:
	s_cmp_gt_i32 s11, 0
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 2, v0
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cndmask_b32_e64 v3, 0, 1, s3
	v_and_b32_e32 v2, 0x7c, v2
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_ne_u32_e64 s3, 1, v3
	v_mov_b32_e32 v3, 0
	s_branch .LBB21_4
.LBB21_2:                               ;   in Loop: Header=BB21_4 Depth=1
	v_dual_mov_b32 v4, 0 :: v_dual_mov_b32 v5, 0
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v7, 0
.LBB21_3:                               ;   in Loop: Header=BB21_4 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add_nc_u32_e32 v6, v7, v6
	v_add_nc_u32_e32 v3, 1, v3
	v_add3_u32 v4, v6, v4, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_cmp_eq_u32_e32 vcc_lo, s10, v3
	;;#ASMSTART
	v_add_nc_u32 v4, 0x8000, v4
	;;#ASMEND
	;;#ASMSTART
	v_bfe_i32 v4, v4, 16, 16
	;;#ASMEND
	v_add_nc_u32_e32 v1, v4, v1
	s_cbranch_vccnz .LBB21_8
.LBB21_4:                               ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB21_6 Depth 2
	s_delay_alu instid0(VALU_DEP_2)
	s_and_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB21_2
; %bb.5:                                ;   in Loop: Header=BB21_4 Depth=1
	v_dual_mov_b32 v7, 0 :: v_dual_mov_b32 v6, 0
	v_dual_mov_b32 v5, 0 :: v_dual_mov_b32 v4, 0
	s_mov_b32 s12, 0
.LBB21_6:                               ;   Parent Loop BB21_4 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v8, s12, v2
	s_add_i32 s12, s12, 4
	s_cmp_lt_i32 s12, s11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_and_b32_e32 v9, 0x3fc, v8
	v_and_b32_e32 v10, 0xfc, v8
	v_add_nc_u32_e32 v11, 1, v8
	v_lshlrev_b32_e32 v9, 2, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshlrev_b32_e32 v10, 2, v10
	v_and_b32_e32 v12, 0x3fd, v11
	v_and_b32_e32 v11, 0xfd, v11
	global_load_b32 v9, v9, s[4:5]
	global_load_b32 v10, v10, s[6:7]
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_mul_i32_i24 v9, v9, v9
	;;#ASMEND
	v_lshlrev_b32_e32 v12, 2, v12
	v_lshlrev_b32_e32 v11, 2, v11
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v9, v9, v10
	;;#ASMEND
	global_load_b32 v10, v12, s[4:5]
	global_load_b32 v11, v11, s[6:7]
	v_add_nc_u32_e32 v12, 2, v8
	v_add_nc_u32_e32 v8, 3, v8
	v_add_nc_u32_e32 v7, v9, v7
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_mul_i32_i24 v10, v10, v10
	;;#ASMEND
	v_and_b32_e32 v13, 0x3fe, v12
	v_and_b32_e32 v12, 0xfe, v12
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v10, v10, v11
	;;#ASMEND
	v_add_nc_u32_e32 v6, v10, v6
	v_lshlrev_b32_e32 v13, 2, v13
	v_lshlrev_b32_e32 v12, 2, v12
	global_load_b32 v11, v13, s[4:5]
	global_load_b32 v12, v12, s[6:7]
	v_and_b32_e32 v13, 0x3ff, v8
	v_and_b32_e32 v8, 0xff, v8
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_mul_i32_i24 v11, v11, v11
	;;#ASMEND
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v13, 2, v13
	v_lshlrev_b32_e32 v8, 2, v8
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v11, v11, v12
	;;#ASMEND
	global_load_b32 v12, v13, s[4:5]
	global_load_b32 v8, v8, s[6:7]
	v_add_nc_u32_e32 v5, v11, v5
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_mul_i32_i24 v9, v12, v12
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v8, v9, v8
	;;#ASMEND
	v_add_nc_u32_e32 v4, v8, v4
	s_cbranch_scc1 .LBB21_6
	s_branch .LBB21_3
.LBB21_7:
	v_mov_b32_e32 v1, 0
.LBB21_8:
	s_load_b32 s0, s[0:1], 0x2c
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	s_delay_alu instid0(VALU_DEP_1) | instid1(SALU_CYCLE_1)
	v_mad_u64_u32 v[2:3], null, s2, s0, v[0:1]
	v_mov_b32_e32 v3, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[2:3], 2, v[2:3]
	v_add_co_u32 v2, vcc_lo, s8, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s9, v3, vcc_lo
	global_store_b32 v[2:3], v1, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z10k_bilinearILb1EEvPKiS1_Piii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 14
		.amdhsa_next_free_sgpr 13
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
		.amdhsa_inst_pref_size 4
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z10k_bilinearILb1EEvPKiS1_Piii,"axG",@progbits,_Z10k_bilinearILb1EEvPKiS1_Piii,comdat
.Lfunc_end21:
	.size	_Z10k_bilinearILb1EEvPKiS1_Piii, .Lfunc_end21-_Z10k_bilinearILb1EEvPKiS1_Piii
                                        ; -- End function
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.num_vgpr, 14
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.num_agpr, 0
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.numbered_sgpr, 13
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.num_named_barrier, 0
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.private_seg_size, 0
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.uses_vcc, 1
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.uses_flat_scratch, 0
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.has_dyn_sized_stack, 0
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.has_recursion, 0
	.set _Z10k_bilinearILb1EEvPKiS1_Piii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 500
; TotalNumSgprs: 15
; NumVgprs: 14
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 15
; NumVGPRsForWavesPerEU: 14
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z10k_bilinearILb0EEvPKiS1_Piii,"axG",@progbits,_Z10k_bilinearILb0EEvPKiS1_Piii,comdat
	.protected	_Z10k_bilinearILb0EEvPKiS1_Piii ; -- Begin function _Z10k_bilinearILb0EEvPKiS1_Piii
	.globl	_Z10k_bilinearILb0EEvPKiS1_Piii
	.p2align	8
	.type	_Z10k_bilinearILb0EEvPKiS1_Piii,@function
_Z10k_bilinearILb0EEvPKiS1_Piii:        ; @_Z10k_bilinearILb0EEvPKiS1_Piii
; %bb.0:
	s_load_b256 s[4:11], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_cmp_lt_i32 s10, 1
	s_cbranch_scc1 .LBB22_7
; %bb.1:
	s_cmp_gt_i32 s11, 0
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 2, v0
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cndmask_b32_e64 v3, 0, 1, s3
	v_and_b32_e32 v2, 0x7c, v2
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_ne_u32_e64 s3, 1, v3
	v_mov_b32_e32 v3, 0
	s_branch .LBB22_4
.LBB22_2:                               ;   in Loop: Header=BB22_4 Depth=1
	v_dual_mov_b32 v4, 0 :: v_dual_mov_b32 v5, 0
	v_dual_mov_b32 v6, 0 :: v_dual_mov_b32 v7, 0
.LBB22_3:                               ;   in Loop: Header=BB22_4 Depth=1
	v_add_nc_u32_e32 v3, 1, v3
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add3_u32 v1, v6, v1, v7
	v_cmp_eq_u32_e32 vcc_lo, s10, v3
	s_delay_alu instid0(VALU_DEP_2)
	v_add3_u32 v1, v1, v4, v5
	s_cbranch_vccnz .LBB22_8
.LBB22_4:                               ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB22_6 Depth 2
	s_delay_alu instid0(VALU_DEP_2)
	s_and_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB22_2
; %bb.5:                                ;   in Loop: Header=BB22_4 Depth=1
	v_dual_mov_b32 v7, 0 :: v_dual_mov_b32 v6, 0
	v_dual_mov_b32 v5, 0 :: v_dual_mov_b32 v4, 0
	s_mov_b32 s12, 0
.LBB22_6:                               ;   Parent Loop BB22_4 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v8, s12, v2
	s_add_i32 s12, s12, 4
	s_cmp_lt_i32 s12, s11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_and_b32_e32 v9, 0x3fc, v8
	v_and_b32_e32 v10, 0xfc, v8
	v_add_nc_u32_e32 v11, 1, v8
	v_lshlrev_b32_e32 v9, 2, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshlrev_b32_e32 v10, 2, v10
	v_and_b32_e32 v12, 0x3fd, v11
	v_and_b32_e32 v11, 0xfd, v11
	global_load_b32 v9, v9, s[4:5]
	global_load_b32 v10, v10, s[6:7]
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_bfe_i32 v13, v9, 0, 16
	;;#ASMEND
	v_lshlrev_b32_e32 v12, 2, v12
	v_lshlrev_b32_e32 v11, 2, v11
	;;#ASMSTART
	v_add_nc_u32 v9, 0x8000, v9
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v9, 16, v9
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v9, v13, v9
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v9, v9, v10
	;;#ASMEND
	global_load_b32 v10, v12, s[4:5]
	global_load_b32 v11, v11, s[6:7]
	v_add_nc_u32_e32 v12, 2, v8
	v_add_nc_u32_e32 v8, 3, v8
	v_add_nc_u32_e32 v7, v9, v7
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_bfe_i32 v14, v10, 0, 16
	;;#ASMEND
	v_and_b32_e32 v13, 0x3fe, v12
	v_and_b32_e32 v12, 0xfe, v12
	;;#ASMSTART
	v_add_nc_u32 v10, 0x8000, v10
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v10, 16, v10
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v10, v14, v10
	;;#ASMEND
	v_lshlrev_b32_e32 v13, 2, v13
	v_lshlrev_b32_e32 v12, 2, v12
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v10, v10, v11
	;;#ASMEND
	global_load_b32 v11, v13, s[4:5]
	global_load_b32 v12, v12, s[6:7]
	v_and_b32_e32 v13, 0x3ff, v8
	v_and_b32_e32 v8, 0xff, v8
	v_add_nc_u32_e32 v6, v10, v6
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_bfe_i32 v14, v11, 0, 16
	;;#ASMEND
	v_lshlrev_b32_e32 v13, 2, v13
	v_lshlrev_b32_e32 v8, 2, v8
	;;#ASMSTART
	v_add_nc_u32 v11, 0x8000, v11
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v11, 16, v11
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v11, v14, v11
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v11, v11, v12
	;;#ASMEND
	global_load_b32 v12, v13, s[4:5]
	global_load_b32 v8, v8, s[6:7]
	v_add_nc_u32_e32 v5, v11, v5
	s_waitcnt vmcnt(1)
	;;#ASMSTART
	v_bfe_i32 v9, v12, 0, 16
	;;#ASMEND
	;;#ASMSTART
	v_add_nc_u32 v10, 0x8000, v12
	;;#ASMEND
	;;#ASMSTART
	v_ashrrev_i32 v10, 16, v10
	;;#ASMEND
	;;#ASMSTART
	v_mul_i32_i24 v9, v9, v10
	;;#ASMEND
	s_waitcnt vmcnt(0)
	;;#ASMSTART
	v_mul_i32_i24 v8, v9, v8
	;;#ASMEND
	v_add_nc_u32_e32 v4, v8, v4
	s_cbranch_scc1 .LBB22_6
	s_branch .LBB22_3
.LBB22_7:
	v_mov_b32_e32 v1, 0
.LBB22_8:
	s_load_b32 s0, s[0:1], 0x2c
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	s_delay_alu instid0(VALU_DEP_1) | instid1(SALU_CYCLE_1)
	v_mad_u64_u32 v[2:3], null, s2, s0, v[0:1]
	v_mov_b32_e32 v3, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[2:3], 2, v[2:3]
	v_add_co_u32 v2, vcc_lo, s8, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s9, v3, vcc_lo
	global_store_b32 v[2:3], v1, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z10k_bilinearILb0EEvPKiS1_Piii
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
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
		.amdhsa_next_free_vgpr 15
		.amdhsa_next_free_sgpr 13
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
		.amdhsa_inst_pref_size 4
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z10k_bilinearILb0EEvPKiS1_Piii,"axG",@progbits,_Z10k_bilinearILb0EEvPKiS1_Piii,comdat
.Lfunc_end22:
	.size	_Z10k_bilinearILb0EEvPKiS1_Piii, .Lfunc_end22-_Z10k_bilinearILb0EEvPKiS1_Piii
                                        ; -- End function
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.num_vgpr, 15
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.num_agpr, 0
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.numbered_sgpr, 13
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.num_named_barrier, 0
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.private_seg_size, 0
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.uses_vcc, 1
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.uses_flat_scratch, 0
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.has_dyn_sized_stack, 0
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.has_recursion, 0
	.set _Z10k_bilinearILb0EEvPKiS1_Piii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 496
; TotalNumSgprs: 15
; NumVgprs: 15
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 15
; NumVGPRsForWavesPerEU: 15
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
	.type	__hip_cuid_d343832093ecc9ae,@object ; @__hip_cuid_d343832093ecc9ae
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_d343832093ecc9ae
__hip_cuid_d343832093ecc9ae:
	.byte	0                               ; 0x0
	.size	__hip_cuid_d343832093ecc9ae, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __hip_cuid_d343832093ecc9ae
	.amdgpu_metadata
---
amdhsa.kernels:
  - .args:
      - .offset:         0
        .size:           4
        .value_kind:     by_value
      - .offset:         4
        .size:           4
        .value_kind:     by_value
      - .offset:         8
        .size:           4
        .value_kind:     by_value
      - .offset:         12
        .size:           4
        .value_kind:     by_value
      - .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z12k_check_wideiiiiPy
    .private_segment_fixed_size: 0
    .sgpr_count:     22
    .sgpr_spill_count: 0
    .symbol:         _Z12k_check_wideiiiiPy.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     17
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
  - .args:
      - .offset:         0
        .size:           4
        .value_kind:     by_value
      - .offset:         4
        .size:           4
        .value_kind:     by_value
      - .address_space:  global
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .offset:         16
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         20
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         28
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         30
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         32
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         34
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         36
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         38
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         56
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         80
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 272
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z14k_check_narrowiiPy
    .private_segment_fixed_size: 0
    .sgpr_count:     21
    .sgpr_spill_count: 0
    .symbol:         _Z14k_check_narrowiiPy.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     14
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .offset:         8
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         12
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         16
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         20
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         22
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         24
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         26
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         28
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         30
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         48
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         56
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         72
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 264
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z12k_check_polyPy
    .private_segment_fixed_size: 0
    .sgpr_count:     7
    .sgpr_spill_count: 0
    .symbol:         _Z12k_check_polyPy.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     11
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
  - .args:
      - .offset:         0
        .size:           4
        .value_kind:     by_value
      - .offset:         4
        .size:           4
        .value_kind:     by_value
      - .offset:         8
        .size:           4
        .value_kind:     by_value
      - .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z16k_check_bilineariiiPy
    .private_segment_fixed_size: 0
    .sgpr_count:     10
    .sgpr_spill_count: 0
    .symbol:         _Z16k_check_bilineariiiPy.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     14
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI6VEmptyEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI6VEmptyEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     17
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI8VWSepMulEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI8VWSepMulEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     25
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI9VWFused24EvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI9VWFused24EvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     28
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI9VWFusedLoEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI9VWFusedLoEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     28
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI10VWDecode24EvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI10VWDecode24EvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     34
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI10VWDecodeLoEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI10VWDecodeLoEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     34
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI11VWFusedReluEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI11VWFusedReluEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     34
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI12VWDecodeReluEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI12VWDecodeReluEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     36
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI11VWPackFusedEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI11VWPackFusedEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     28
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI11VWPolyFusedEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI11VWPolyFusedEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     41
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI12VWPolyDecodeEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     41
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI7VNFusedEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI7VNFusedEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     28
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI12VNFusedGuardEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI12VNFusedGuardEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     34
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI8VNDecodeEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI8VNDecodeEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     34
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI10VNFusedF32EvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI10VNFusedF32EvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     28
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI15VNFusedF32GuardEvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     34
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z6k_rateI11VNDecodeF32EvPKiS2_Pii
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _Z6k_rateI11VNDecodeF32EvPKiS2_Pii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     34
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         28
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z10k_bilinearILb1EEvPKiS1_Piii
    .private_segment_fixed_size: 0
    .sgpr_count:     15
    .sgpr_spill_count: 0
    .symbol:         _Z10k_bilinearILb1EEvPKiS1_Piii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     14
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         28
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 128
    .name:           _Z10k_bilinearILb0EEvPKiS1_Piii
    .private_segment_fixed_size: 0
    .sgpr_count:     15
    .sgpr_spill_count: 0
    .symbol:         _Z10k_bilinearILb0EEvPKiS1_Piii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     15
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
