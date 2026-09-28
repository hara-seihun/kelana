	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.protected	_Z7flush_vPKhPhPfii     ; -- Begin function _Z7flush_vPKhPhPfii
	.globl	_Z7flush_vPKhPhPfii
	.p2align	8
	.type	_Z7flush_vPKhPhPfii,@function
_Z7flush_vPKhPhPfii:                    ; @_Z7flush_vPKhPhPfii
; %bb.0:
	s_load_b64 s[8:9], s[0:1], 0x18
	s_cmp_lt_i32 s2, 8
	v_and_b32_e32 v1, 31, v0
	s_cselect_b32 s4, -1, 0
	v_cmp_gt_u32_e32 vcc_lo, 0x80, v0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_cmp_eq_u32_e64 s3, 0, v1
	s_waitcnt lgkmcnt(0)
	s_sub_i32 s8, s8, 33
	s_cmpk_lt_u32 s8, 0xe0
	s_cselect_b32 s5, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s5, vcc_lo, s5
	s_and_b32 s4, s5, s4
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s3, s3, s4
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB0_39
; %bb.1:
	s_clause 0x1
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[10:11], s[0:1], 0x10
	s_mul_i32 s0, s2, 0x2100
	s_mul_i32 s1, s8, 0xf9
	s_ashr_i32 s3, s0, 31
	v_lshlrev_b32_e32 v1, 1, v0
	v_mov_b16_e32 v2.l, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b16_e32 v4.l, v2.l
	v_mov_b16_e32 v6.l, v2.l
	s_waitcnt lgkmcnt(0)
	s_add_u32 s0, s4, s0
	s_addc_u32 s3, s5, s3
	s_bfe_u32 s1, s1, 0x3000d
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s1, s1, 33
	s_sub_i32 s1, s8, s1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s1, s1, 0xff
	s_lshl_b32 s1, s1, 8
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s0, s0, s1
	s_addc_u32 s1, s3, 0
	s_clause 0x3
	global_load_b128 v[7:10], v1, s[0:1]
	global_load_b128 v[15:18], v1, s[0:1] offset:16
	global_load_b128 v[23:26], v1, s[0:1] offset:32
	global_load_b128 v[31:34], v1, s[0:1] offset:48
	s_mov_b32 s0, exec_lo
	s_waitcnt vmcnt(3)
	v_and_b32_e32 v3, 0xffff0000, v7
	v_mov_b16_e32 v2.h, v7.l
	v_and_b32_e32 v5, 0xffff0000, v8
	v_mov_b16_e32 v4.h, v8.l
	v_and_b32_e32 v7, 0xffff0000, v9
	v_mov_b16_e32 v6.h, v9.l
	v_max3_f32 v1, v2, 0xff800000, v3
	v_min3_f32 v8, v2, 0x7f800000, v3
	v_and_b32_e32 v9, 0xffff0000, v10
	s_waitcnt vmcnt(2)
	v_mov_b16_e32 v10.h, v15.l
	v_and_b32_e32 v13, 0xffff0000, v16
	v_max3_f32 v1, v1, v4, v5
	v_min3_f32 v11, v8, v4, v5
	v_mov_b16_e32 v8.l, v2.l
	v_mov_b16_e32 v8.h, v10.l
	v_mov_b16_e32 v10.l, v2.l
	v_max3_f32 v1, v1, v6, v7
	v_min3_f32 v12, v11, v6, v7
	v_and_b32_e32 v11, 0xffff0000, v15
	v_and_b32_e32 v15, 0xffff0000, v17
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v21, 0xffff0000, v24
	v_max3_f32 v1, v1, v8, v9
	v_min3_f32 v14, v12, v8, v9
	v_mov_b16_e32 v12.l, v2.l
	v_mov_b16_e32 v12.h, v16.l
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v29, 0xffff0000, v32
	v_max3_f32 v1, v1, v10, v11
	v_min3_f32 v16, v14, v10, v11
	v_mov_b16_e32 v14.l, v2.l
	v_mov_b16_e32 v14.h, v17.l
	v_and_b32_e32 v17, 0xffff0000, v18
	v_max3_f32 v1, v1, v12, v13
	v_min3_f32 v19, v16, v12, v13
	v_mov_b16_e32 v16.l, v2.l
	v_mov_b16_e32 v16.h, v18.l
	v_mov_b16_e32 v18.l, v2.l
	v_max3_f32 v1, v1, v14, v15
	v_min3_f32 v20, v19, v14, v15
	v_and_b32_e32 v19, 0xffff0000, v23
	v_mov_b16_e32 v18.h, v23.l
	v_and_b32_e32 v23, 0xffff0000, v25
	v_max3_f32 v1, v1, v16, v17
	v_min3_f32 v22, v20, v16, v17
	v_mov_b16_e32 v20.l, v2.l
	v_mov_b16_e32 v20.h, v24.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_max3_f32 v1, v1, v18, v19
	v_min3_f32 v24, v22, v18, v19
	v_mov_b16_e32 v22.l, v2.l
	v_mov_b16_e32 v22.h, v25.l
	v_and_b32_e32 v25, 0xffff0000, v26
	v_max3_f32 v1, v1, v20, v21
	v_min3_f32 v27, v24, v20, v21
	v_mov_b16_e32 v24.l, v2.l
	v_mov_b16_e32 v24.h, v26.l
	v_mov_b16_e32 v26.l, v2.l
	v_max3_f32 v1, v1, v22, v23
	v_min3_f32 v28, v27, v22, v23
	v_and_b32_e32 v27, 0xffff0000, v31
	v_mov_b16_e32 v26.h, v31.l
	v_and_b32_e32 v31, 0xffff0000, v33
	v_max3_f32 v1, v1, v24, v25
	v_min3_f32 v30, v28, v24, v25
	v_mov_b16_e32 v28.l, v2.l
	v_mov_b16_e32 v28.h, v32.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_max3_f32 v1, v1, v26, v27
	v_min3_f32 v32, v30, v26, v27
	v_mov_b16_e32 v30.l, v2.l
	v_mov_b16_e32 v30.h, v33.l
	v_and_b32_e32 v33, 0xffff0000, v34
	v_max3_f32 v1, v1, v28, v29
	v_min3_f32 v35, v32, v28, v29
	v_mov_b16_e32 v32.l, v2.l
	v_mov_b16_e32 v32.h, v34.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_max3_f32 v1, v1, v30, v31
	v_min3_f32 v34, v35, v30, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v32, v33
	v_min3_f32 v42, v34, v32, v33
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[34:35], v1
	v_cvt_f64_f32_e32 v[36:37], v42
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f64 v[34:35], v[34:35], -v[36:37]
	v_div_scale_f64 v[36:37], null, 0x40080000, 0x40080000, v[34:35]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f64_e32 v[38:39], v[36:37]
	v_fma_f64 v[40:41], -v[36:37], v[38:39], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[38:39], v[38:39], v[40:41], v[38:39]
	v_fma_f64 v[40:41], -v[36:37], v[38:39], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f64 v[38:39], v[38:39], v[40:41], v[38:39]
	v_div_scale_f64 v[40:41], vcc_lo, v[34:35], 0x40080000, v[34:35]
	v_mul_f64 v[43:44], v[40:41], v[38:39]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[36:37], -v[36:37], v[43:44], v[40:41]
	v_div_fmas_f64 v[36:37], v[36:37], v[38:39], v[43:44]
                                        ; implicit-def: $vgpr38
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f64 v[34:35], v[36:37], 0x40080000, v[34:35]
	v_bfe_u32 v1, v35, 20, 11
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u32_e32 0x7ff, v1
	s_xor_b32 s3, exec_lo, s0
	s_cbranch_execz .LBB0_11
; %bb.2:
	v_mov_b32_e32 v38, 0
	s_mov_b32 s4, exec_lo
	v_cmpx_lt_u32_e32 0x3e5, v1
	s_cbranch_execz .LBB0_10
; %bb.3:
	v_mov_b32_e32 v38, 0x7c00
	s_mov_b32 s5, exec_lo
	v_cmpx_gt_u32_e32 0x40f, v1
	s_cbranch_execz .LBB0_9
; %bb.4:
	v_sub_nc_u32_e32 v36, 0x41b, v1
	v_cmp_gt_u32_e32 vcc_lo, 0x3f1, v1
	s_mov_b32 s0, 0xfffff
	s_mov_b32 s13, exec_lo
	v_and_or_b32 v44, v35, s0, 0x100000
	v_mov_b32_e32 v43, v34
	v_cndmask_b32_e32 v45, 42, v36, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[36:37], v45, -1
	v_add_nc_u32_e32 v38, -1, v45
	v_lshlrev_b64 v[38:39], v38, 1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_bfi_b32 v41, v37, 0, v44
	v_bfi_b32 v40, v36, 0, v34
	v_lshrrev_b64 v[36:37], v45, v[43:44]
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_gt_u64_e64 s12, v[40:41], v[38:39]
	v_cmpx_le_u64_e64 v[40:41], v[38:39]
; %bb.5:
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_and_b32_e32 v43, 1, v36
	v_cmp_eq_u64_e64 s0, v[40:41], v[38:39]
	v_cmp_eq_u32_e64 s1, 1, v43
	s_and_b32 s0, s0, s1
	s_and_not1_b32 s1, s12, exec_lo
	s_and_b32 s0, s0, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s12, s1, s0
; %bb.6:                                ; %Flow144
	s_or_b32 exec_lo, exec_lo, s13
	s_and_saveexec_b32 s1, s12
; %bb.7:
	v_add_co_u32 v36, s0, v36, 1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v37, null, 0, v37, s0
; %bb.8:
	s_or_b32 exec_lo, exec_lo, s1
	v_lshl_add_u32 v1, v1, 10, 0xfff03c00
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v1, v1, 0, vcc_lo
	v_add_nc_u32_e32 v38, v1, v36
.LBB0_9:                                ; %Flow146
	s_or_b32 exec_lo, exec_lo, s5
.LBB0_10:                               ; %Flow148
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s4
.LBB0_11:                               ; %Flow150
	s_and_not1_saveexec_b32 s0, s3
; %bb.12:
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_dual_mov_b32 v36, v34 :: v_dual_and_b32 v37, 0xfffff, v35
	v_mov_b32_e32 v1, 0x7c00
	v_cmp_eq_u64_e32 vcc_lo, 0, v[36:37]
	s_delay_alu instid0(VALU_DEP_2)
	v_cndmask_b32_e32 v38, 0x7e00, v1, vcc_lo
; %bb.13:                               ; %_ZN8resident9step_bitsEy.exit
	s_or_b32 exec_lo, exec_lo, s0
	s_mul_i32 s12, s2, 0x2a00
	s_mul_i32 s8, s8, 48
	s_ashr_i32 s13, s12, 31
	s_add_u32 s0, s6, s12
	s_addc_u32 s1, s7, s13
	s_add_u32 s4, s0, s8
	v_cvt_f32_f64_e32 v36, v[34:35]
	v_cmp_neq_f64_e64 s0, 0, v[34:35]
	s_addc_u32 s5, s1, 0
	s_lshl_b32 s2, s2, 7
	v_mov_b32_e32 v1, 0
	s_ashr_i32 s3, s2, 31
	s_cmp_lg_u32 s9, 0
	v_lshrrev_b32_e32 v40, 3, v0
	s_cselect_b32 s1, -1, 0
	s_add_u32 s6, s6, s8
	s_addc_u32 s7, s7, 0
	v_lshlrev_b64 v[34:35], 2, v[0:1]
	s_add_u32 s6, s6, s12
	s_addc_u32 s7, s7, s13
	s_lshl_b64 s[2:3], s[2:3], 2
	v_lshrrev_b32_e32 v0, 2, v0
	s_add_u32 s2, s10, s2
	s_addc_u32 s3, s11, s3
	v_add_co_u32 v34, vcc_lo, s2, v34
	v_cvt_f16_f32_e32 v39.l, v42
	v_add_co_ci_u32_e64 v35, null, s3, v35, vcc_lo
	v_add_co_u32 v0, s2, s6, v0
	s_delay_alu instid0(VALU_DEP_4)
	v_add_co_u32 v34, vcc_lo, v34, 8
	v_mov_b16_e32 v39.h, v38.l
	v_cvt_f32_f16_e32 v37, v39.l
	v_cvt_f32_f16_e32 v38, v38.l
	v_add_co_ci_u32_e64 v1, null, s7, 0, s2
	v_add_co_ci_u32_e64 v35, null, 0, v35, vcc_lo
	s_mov_b64 s[2:3], 3
	global_store_b32 v40, v39, s[4:5] offset:32
	s_branch .LBB0_15
.LBB0_14:                               ;   in Loop: Header=BB0_15 Depth=1
	v_lshlrev_b32_e32 v41, 4, v41
	v_lshlrev_b32_e32 v43, 6, v44
	s_add_u32 s2, s2, 4
	s_addc_u32 s3, s3, 0
	s_cmp_lg_u32 s2, 35
	v_lshl_or_b32 v40, v40, 2, v41
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_or3_b32 v39, v40, v43, v39
	global_store_b8 v[0:1], v39, off
	v_add_co_u32 v0, vcc_lo, v0, 1
	v_add_co_ci_u32_e64 v1, null, 0, v1, vcc_lo
	v_add_co_u32 v34, vcc_lo, v34, 16
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v35, null, 0, v35, vcc_lo
	s_cbranch_scc0 .LBB0_39
.LBB0_15:                               ; %.preheader
                                        ; =>This Inner Loop Header: Depth=1
	s_add_i32 m0, s2, -3
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v40, v2
	s_cbranch_vccnz .LBB0_17
; %bb.16:                               ;   in Loop: Header=BB0_15 Depth=1
	global_load_b32 v39, v[34:35], off offset:-8
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v40, v40, v39
.LBB0_17:                               ;   in Loop: Header=BB0_15 Depth=1
	v_mov_b32_e32 v39, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB0_19
; %bb.18:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v39, v40, v42
	v_div_scale_f32 v41, null, v36, v36, v39
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v43, v41
	v_fma_f32 v44, -v41, v43, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v43, v44, v43
	v_div_scale_f32 v44, vcc_lo, v39, v36, v39
	v_mul_f32_e32 v45, v44, v43
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v46, -v41, v45, v44
	v_fmac_f32_e32 v45, v46, v43
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v41, -v41, v45, v44
	v_div_fmas_f32 v41, v41, v43, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v39, v41, v36, v39
	v_rndne_f32_e32 v39, v39
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v39, v39, 0, 0x40400000
	v_cvt_u32_f32_e32 v39, v39
.LBB0_19:                               ;   in Loop: Header=BB0_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB0_21
; %bb.20:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v41, v39
	v_mul_f32_e32 v41, v38, v41
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v41, v41, v37
	v_sub_f32_e32 v40, v40, v41
	global_store_b32 v[34:35], v40, off offset:-8
.LBB0_21:                               ;   in Loop: Header=BB0_15 Depth=1
	s_add_i32 m0, s2, -2
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v41, v2
	s_cbranch_vccnz .LBB0_23
; %bb.22:                               ;   in Loop: Header=BB0_15 Depth=1
	global_load_b32 v40, v[34:35], off offset:-4
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v41, v41, v40
.LBB0_23:                               ;   in Loop: Header=BB0_15 Depth=1
	v_mov_b32_e32 v40, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB0_25
; %bb.24:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v40, v41, v42
	v_div_scale_f32 v43, null, v36, v36, v40
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v44, v43
	v_fma_f32 v45, -v43, v44, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v44, v45, v44
	v_div_scale_f32 v45, vcc_lo, v40, v36, v40
	v_mul_f32_e32 v46, v45, v44
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v47, -v43, v46, v45
	v_fmac_f32_e32 v46, v47, v44
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v43, -v43, v46, v45
	v_div_fmas_f32 v43, v43, v44, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v40, v43, v36, v40
	v_rndne_f32_e32 v40, v40
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v40, v40, 0, 0x40400000
	v_cvt_u32_f32_e32 v40, v40
.LBB0_25:                               ;   in Loop: Header=BB0_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB0_27
; %bb.26:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v43, v40
	v_mul_f32_e32 v43, v38, v43
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v43, v43, v37
	v_sub_f32_e32 v41, v41, v43
	global_store_b32 v[34:35], v41, off offset:-4
.LBB0_27:                               ;   in Loop: Header=BB0_15 Depth=1
	s_add_i32 m0, s2, -1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v43, v2
	s_cbranch_vccnz .LBB0_29
; %bb.28:                               ;   in Loop: Header=BB0_15 Depth=1
	global_load_b32 v41, v[34:35], off
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v43, v43, v41
.LBB0_29:                               ;   in Loop: Header=BB0_15 Depth=1
	v_mov_b32_e32 v41, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB0_31
; %bb.30:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v41, v43, v42
	v_div_scale_f32 v44, null, v36, v36, v41
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v45, v44
	v_fma_f32 v46, -v44, v45, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v45, v46, v45
	v_div_scale_f32 v46, vcc_lo, v41, v36, v41
	v_mul_f32_e32 v47, v46, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v48, -v44, v47, v46
	v_fmac_f32_e32 v47, v48, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v44, -v44, v47, v46
	v_div_fmas_f32 v44, v44, v45, v47
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v41, v44, v36, v41
	v_rndne_f32_e32 v41, v41
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v41, v41, 0, 0x40400000
	v_cvt_u32_f32_e32 v41, v41
.LBB0_31:                               ;   in Loop: Header=BB0_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB0_33
; %bb.32:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v44, v41
	v_mul_f32_e32 v44, v38, v44
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v44, v44, v37
	v_sub_f32_e32 v43, v43, v44
	global_store_b32 v[34:35], v43, off
.LBB0_33:                               ;   in Loop: Header=BB0_15 Depth=1
	s_mov_b32 m0, s2
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v43, v2
	s_cbranch_vccnz .LBB0_35
; %bb.34:                               ;   in Loop: Header=BB0_15 Depth=1
	global_load_b32 v44, v[34:35], off offset:4
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v43, v43, v44
.LBB0_35:                               ;   in Loop: Header=BB0_15 Depth=1
	v_mov_b32_e32 v44, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB0_37
; %bb.36:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v44, v43, v42
	v_div_scale_f32 v45, null, v36, v36, v44
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v46, v45
	v_fma_f32 v47, -v45, v46, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v46, v47, v46
	v_div_scale_f32 v47, vcc_lo, v44, v36, v44
	v_mul_f32_e32 v48, v47, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v49, -v45, v48, v47
	v_fmac_f32_e32 v48, v49, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v45, -v45, v48, v47
	v_div_fmas_f32 v45, v45, v46, v48
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v44, v45, v36, v44
	v_rndne_f32_e32 v44, v44
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v44, v44, 0, 0x40400000
	v_cvt_u32_f32_e32 v44, v44
.LBB0_37:                               ;   in Loop: Header=BB0_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB0_14
; %bb.38:                               ;   in Loop: Header=BB0_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v45, v44
	v_mul_f32_e32 v45, v38, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v45, v45, v37
	v_sub_f32_e32 v43, v43, v45
	global_store_b32 v[34:35], v43, off offset:4
	s_branch .LBB0_14
.LBB0_39:                               ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z7flush_vPKhPhPfii
		.amdhsa_group_segment_fixed_size 0
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
		.amdhsa_next_free_vgpr 50
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
		.amdhsa_inst_pref_size 19
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
	.size	_Z7flush_vPKhPhPfii, .Lfunc_end0-_Z7flush_vPKhPhPfii
                                        ; -- End function
	.set _Z7flush_vPKhPhPfii.num_vgpr, 50
	.set _Z7flush_vPKhPhPfii.num_agpr, 0
	.set _Z7flush_vPKhPhPfii.numbered_sgpr, 14
	.set _Z7flush_vPKhPhPfii.num_named_barrier, 0
	.set _Z7flush_vPKhPhPfii.private_seg_size, 0
	.set _Z7flush_vPKhPhPfii.uses_vcc, 1
	.set _Z7flush_vPKhPhPfii.uses_flat_scratch, 0
	.set _Z7flush_vPKhPhPfii.has_dyn_sized_stack, 0
	.set _Z7flush_vPKhPhPfii.has_recursion, 0
	.set _Z7flush_vPKhPhPfii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 2432
; TotalNumSgprs: 16
; NumVgprs: 50
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 6
; NumSGPRsForWavesPerEU: 16
; NumVGPRsForWavesPerEU: 50
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
	.type	__hip_cuid_2d07643a3c278af8,@object ; @__hip_cuid_2d07643a3c278af8
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_2d07643a3c278af8
__hip_cuid_2d07643a3c278af8:
	.byte	0                               ; 0x0
	.size	__hip_cuid_2d07643a3c278af8, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __hip_cuid_2d07643a3c278af8
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
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         28
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z7flush_vPKhPhPfii
    .private_segment_fixed_size: 0
    .sgpr_count:     16
    .sgpr_spill_count: 0
    .symbol:         _Z7flush_vPKhPhPfii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     50
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
