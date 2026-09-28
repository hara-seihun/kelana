	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.section	.text._Z5queryILi0EEvPKhPKfPKtPfiiii,"axG",@progbits,_Z5queryILi0EEvPKhPKfPKtPfiiii,comdat
	.protected	_Z5queryILi0EEvPKhPKfPKtPfiiii ; -- Begin function _Z5queryILi0EEvPKhPKfPKtPfiiii
	.globl	_Z5queryILi0EEvPKhPKfPKtPfiiii
	.p2align	8
	.type	_Z5queryILi0EEvPKhPKfPKtPfiiii,@function
_Z5queryILi0EEvPKhPKfPKtPfiiii:         ; @_Z5queryILi0EEvPKhPKfPKtPfiiii
; %bb.0:
	s_load_b128 s[28:31], s[0:1], 0x20
	s_waitcnt lgkmcnt(0)
	s_add_i32 s20, s30, s28
	s_add_i32 s2, s31, s29
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s20, s2
	s_cselect_b32 s2, -1, 0
	s_cmpk_gt_i32 s20, 0x100
	s_cselect_b32 s3, -1, 0
	s_and_b32 s4, s28, 31
	s_cmp_lg_u32 s4, 0
	s_cselect_b32 s4, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s2, s2, s4
	s_or_b32 s2, s2, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s2
	s_cbranch_vccnz .LBB0_165
; %bb.1:                                ; %.preheader218
	s_load_b256 s[36:43], s[0:1], 0x0
	v_lshlrev_b32_e32 v1, 7, v0
	s_lshr_b32 s33, s28, 5
	v_cmp_gt_i32_e64 s0, s20, v0
	v_lshl_add_u32 v6, v0, 2, 0x800
	s_mulk_i32 s33, 0xa00
	v_and_b32_e32 v7, 0xf80, v1
	s_mul_i32 s35, s29, 0x50
	s_ashr_i32 s34, s33, 31
	s_ashr_i32 s44, s35, 31
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB0_9
; %bb.2:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s2, exec_lo
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s21, exec_lo, s2
	s_cbranch_execz .LBB0_5
; %bb.3:                                ; %.preheader216
	v_subrev_nc_u32_e32 v1, s28, v0
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s2, s36, s35
	s_addc_u32 s3, s37, s44
	s_add_u32 s2, s2, s33
	v_lshlrev_b32_e32 v1, 7, v1
	s_addc_u32 s3, s3, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v1, vcc_lo, s2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s3, v4, vcc_lo
	s_mov_b64 s[2:3], 0
	v_add_co_u32 v3, vcc_lo, v1, 16
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
.LBB0_4:                                ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[8:11], v[3:4], off offset:-16
	global_load_b128 v[12:15], v[3:4], off
	s_add_u32 s4, s38, s2
	s_addc_u32 s5, s39, s3
	v_add_co_u32 v3, vcc_lo, v3, 32
	s_load_b512 s[4:19], s[4:5], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s2, s2, 64
	s_addc_u32 s3, s3, 0
	s_cmpk_lg_i32 s2, 0x200
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v5, 0xffff0000, v8
	v_lshlrev_b32_e32 v1, 16, v8
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, s4, v1
	v_lshlrev_b32_e32 v1, 16, v9
	v_fmac_f32_e32 v2, s5, v5
	v_and_b32_e32 v5, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s6, v1 :: v_dual_lshlrev_b32 v1, 16, v10
	v_dual_fmac_f32 v2, s7, v5 :: v_dual_and_b32 v5, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s8, v1 :: v_dual_lshlrev_b32 v1, 16, v11
	v_dual_fmac_f32 v2, s9, v5 :: v_dual_and_b32 v5, 0xffff0000, v11
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s10, v1 :: v_dual_lshlrev_b32 v1, 16, v12
	v_dual_fmac_f32 v2, s11, v5 :: v_dual_and_b32 v5, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, s12, v1
	v_lshlrev_b32_e32 v1, 16, v13
	v_fmac_f32_e32 v2, s13, v5
	v_and_b32_e32 v5, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s14, v1 :: v_dual_lshlrev_b32 v1, 16, v14
	v_dual_fmac_f32 v2, s15, v5 :: v_dual_and_b32 v5, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s16, v1 :: v_dual_lshlrev_b32 v1, 16, v15
	v_dual_fmac_f32 v2, s17, v5 :: v_dual_and_b32 v5, 0xffff0000, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s18, v1
	v_fmac_f32_e32 v2, s19, v5
	s_cbranch_scc1 .LBB0_4
.LBB0_5:                                ; %Flow2172
	s_and_not1_saveexec_b32 s4, s21
	s_cbranch_execz .LBB0_8
; %bb.6:
	v_lshrrev_b32_e32 v1, 5, v0
	v_dual_mov_b32 v5, 0 :: v_dual_and_b32 v2, 31, v0
	s_mov_b32 s5, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_u32_u24_e32 v3, 0xa00, v1
	v_lshl_or_b32 v1, v2, 6, 1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s2, v1, v3
	v_add_co_ci_u32_e64 v4, null, 0, 0, s2
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v8, s2, s36, v3
	s_delay_alu instid0(VALU_DEP_3)
	v_add_co_u32 v3, vcc_lo, s36, v2
	v_add_co_ci_u32_e64 v9, null, s37, 0, s2
	v_add_co_ci_u32_e64 v4, null, s37, v4, vcc_lo
	v_mov_b32_e32 v2, v5
	s_mov_b64 s[2:3], 0
.LBB0_7:                                ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v10, s5, v7
	s_add_u32 s6, s38, s2
	s_addc_u32 s7, s39, s3
	s_add_i32 s5, s5, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v10, 1, v10
	v_add_co_u32 v10, vcc_lo, v8, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, 0, v9, vcc_lo
	v_add_co_u32 v12, vcc_lo, v8, v1
	v_add_co_ci_u32_e64 v13, null, v9, v5, vcc_lo
	global_load_d16_u8 v14, v[10:11], off
	v_add_co_u32 v10, vcc_lo, v8, s2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s3, v9, vcc_lo
	s_clause 0x1
	global_load_d16_hi_u8 v14, v[12:13], off
	global_load_b128 v[10:13], v[10:11], off offset:2048
	global_load_d16_u8 v15, v[3:4], off
	s_load_b128 s[8:11], s[6:7], 0x0
	v_add_co_u32 v3, vcc_lo, v3, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, 2
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_u32 s2, s2, 16
	s_addc_u32 s3, s3, 0
	s_cmpk_eq_i32 s2, 0x200
	s_waitcnt vmcnt(2)
	v_and_b16 v16.l, v14.l, 15
	v_lshrrev_b16 v14.l, 4, v14.l
	v_and_b16 v17.l, v14.h, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v16, v16
	v_cvt_f32_ubyte0_e32 v14, v14
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v15.l, 4, v15.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fma_mix_f32 v10, v10, v16, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v16, v17
	v_fma_mix_f32 v11, v11, v14, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s8, v10
	v_cvt_f32_ubyte0_e32 v10, v15
	v_fma_mix_f32 v12, v12, v16, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, s9, v11
	v_fma_mix_f32 v10, v13, v10, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s10, v12
	v_fmac_f32_e32 v2, s11, v10
	s_cbranch_scc0 .LBB0_7
.LBB0_8:                                ; %Flow2173
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1
.LBB0_9:                                ; %Flow2174
	s_or_b32 exec_lo, exec_lo, s1
	v_add_nc_u32_e32 v9, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_i32_e64 s1, s20, v9
	s_and_saveexec_b32 s20, s1
	s_cbranch_execz .LBB0_17
; %bb.10:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s2, exec_lo
	v_cmpx_le_i32_e64 s28, v9
	s_xor_b32 s21, exec_lo, s2
	s_cbranch_execz .LBB0_13
; %bb.11:                               ; %.preheader216.1
	v_subrev_nc_u32_e32 v1, s28, v9
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s2, s36, s35
	s_addc_u32 s3, s37, s44
	s_add_u32 s2, s2, s33
	v_lshlrev_b32_e32 v1, 7, v1
	s_addc_u32 s3, s3, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v1, vcc_lo, s2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s3, v4, vcc_lo
	s_mov_b64 s[2:3], 0
	v_add_co_u32 v3, vcc_lo, v1, 16
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
.LBB0_12:                               ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[10:13], v[3:4], off offset:-16
	global_load_b128 v[14:17], v[3:4], off
	s_add_u32 s4, s38, s2
	s_addc_u32 s5, s39, s3
	v_add_co_u32 v3, vcc_lo, v3, 32
	s_load_b512 s[4:19], s[4:5], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s2, s2, 64
	s_addc_u32 s3, s3, 0
	s_cmpk_eq_i32 s2, 0x200
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v5, 0xffff0000, v10
	v_lshlrev_b32_e32 v1, 16, v10
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s4, v1
	v_dual_fmac_f32 v2, s5, v5 :: v_dual_and_b32 v5, 0xffff0000, v11
	v_lshlrev_b32_e32 v1, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s6, v1
	v_dual_fmac_f32 v2, s7, v5 :: v_dual_and_b32 v5, 0xffff0000, v12
	v_lshlrev_b32_e32 v1, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, s8, v1
	v_lshlrev_b32_e32 v1, 16, v13
	v_fmac_f32_e32 v2, s9, v5
	v_and_b32_e32 v5, 0xffff0000, v13
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s10, v1 :: v_dual_lshlrev_b32 v1, 16, v14
	v_dual_fmac_f32 v2, s11, v5 :: v_dual_and_b32 v5, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s12, v1 :: v_dual_lshlrev_b32 v1, 16, v15
	v_dual_fmac_f32 v2, s13, v5 :: v_dual_and_b32 v5, 0xffff0000, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s14, v1 :: v_dual_lshlrev_b32 v1, 16, v16
	v_dual_fmac_f32 v2, s15, v5 :: v_dual_and_b32 v5, 0xffff0000, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, s16, v1
	v_lshlrev_b32_e32 v1, 16, v17
	v_fmac_f32_e32 v2, s17, v5
	v_and_b32_e32 v5, 0xffff0000, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s18, v1
	v_fmac_f32_e32 v2, s19, v5
	s_cbranch_scc0 .LBB0_12
.LBB0_13:                               ; %Flow2167
	s_and_not1_saveexec_b32 s4, s21
	s_cbranch_execz .LBB0_16
; %bb.14:
	v_lshrrev_b32_e32 v1, 5, v9
	v_dual_mov_b32 v5, 0 :: v_dual_and_b32 v2, 31, v0
	s_mov_b32 s5, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_u32_u24_e32 v3, 0xa00, v1
	v_lshl_or_b32 v1, v2, 6, 1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s2, v1, v3
	v_add_co_ci_u32_e64 v4, null, 0, 0, s2
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v8, s2, s36, v3
	s_delay_alu instid0(VALU_DEP_3)
	v_add_co_u32 v3, vcc_lo, s36, v2
	v_add_co_ci_u32_e64 v10, null, s37, 0, s2
	v_add_co_ci_u32_e64 v4, null, s37, v4, vcc_lo
	v_mov_b32_e32 v2, v5
	s_mov_b64 s[2:3], 0
.LBB0_15:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v11, s5, v7
	s_add_u32 s6, s38, s2
	s_addc_u32 s7, s39, s3
	s_add_i32 s5, s5, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v11, 1, v11
	v_add_co_u32 v11, vcc_lo, v8, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, 0, v10, vcc_lo
	v_add_co_u32 v13, vcc_lo, v8, v1
	v_add_co_ci_u32_e64 v14, null, v10, v5, vcc_lo
	global_load_d16_u8 v15, v[11:12], off
	v_add_co_u32 v11, vcc_lo, v8, s2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s3, v10, vcc_lo
	s_clause 0x1
	global_load_d16_hi_u8 v15, v[13:14], off
	global_load_b128 v[11:14], v[11:12], off offset:2048
	global_load_d16_u8 v16, v[3:4], off
	s_load_b128 s[8:11], s[6:7], 0x0
	v_add_co_u32 v3, vcc_lo, v3, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, 2
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_u32 s2, s2, 16
	s_addc_u32 s3, s3, 0
	s_cmpk_eq_i32 s2, 0x200
	s_waitcnt vmcnt(2)
	v_and_b16 v17.l, v15.l, 15
	v_lshrrev_b16 v15.l, 4, v15.l
	v_and_b16 v18.l, v15.h, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v17, v17
	v_cvt_f32_ubyte0_e32 v15, v15
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v16.l, 4, v16.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fma_mix_f32 v11, v11, v17, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v17, v18
	v_fma_mix_f32 v12, v12, v15, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s8, v11
	v_cvt_f32_ubyte0_e32 v11, v16
	v_fma_mix_f32 v13, v13, v17, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, s9, v12
	v_fma_mix_f32 v11, v14, v11, v14 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s10, v13
	v_fmac_f32_e32 v2, s11, v11
	s_cbranch_scc0 .LBB0_15
.LBB0_16:                               ; %Flow2168
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:512
.LBB0_17:                               ; %Flow2169
	s_or_b32 exec_lo, exec_lo, s20
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s0
	s_cbranch_execz .LBB0_19
; %bb.18:
	ds_load_b32 v1, v6
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB0_19:
	s_or_b32 exec_lo, exec_lo, s2
	s_and_saveexec_b32 s2, s1
	s_cbranch_execz .LBB0_21
; %bb.20:
	ds_load_b32 v2, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB0_21:
	s_or_b32 exec_lo, exec_lo, s2
	v_lshlrev_b32_e32 v5, 2, v0
	v_cmp_gt_u32_e64 s2, 64, v0
	s_delay_alu instid0(VALU_DEP_2)
	v_add_nc_u32_e32 v8, 0x1400, v5
	ds_store_b32 v5, v1 offset:5120
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB0_23
; %bb.22:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_23:
	s_or_b32 exec_lo, exec_lo, s3
	v_cmp_gt_u32_e64 s3, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB0_25
; %bb.24:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_25:
	s_or_b32 exec_lo, exec_lo, s4
	v_cmp_gt_u32_e64 s4, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB0_27
; %bb.26:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_27:
	s_or_b32 exec_lo, exec_lo, s5
	v_cmp_gt_u32_e64 s5, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s5
	s_cbranch_execz .LBB0_29
; %bb.28:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_29:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB0_31
; %bb.30:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_31:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB0_33
; %bb.32:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_33:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_eq_u32_e64 s8, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB0_35
; %bb.34:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_35:
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB0_37
; %bb.36:
	ds_load_b32 v1, v6
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v3, 0x3fb8aa3b, v1
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v1
	v_fma_f32 v4, 0x3fb8aa3b, v1, -v3
	v_rndne_f32_e32 v10, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v4, v1, 0x32a5705f, v4 :: v_dual_sub_f32 v3, v3, v10
	v_add_f32_e32 v3, v3, v4
	v_cvt_i32_f32_e32 v4, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v3, v3
	v_ldexp_f32 v3, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v3, 0, v3, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v1
	v_cndmask_b32_e32 v1, 0x7f800000, v3, vcc_lo
	ds_store_b32 v5, v1
.LBB0_37:
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB0_39
; %bb.38:
	ds_load_b32 v3, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v3, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v3, 0x3fb8aa3b, v2
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v2
	v_fma_f32 v4, 0x3fb8aa3b, v2, -v3
	v_rndne_f32_e32 v10, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v4, v2, 0x32a5705f, v4 :: v_dual_sub_f32 v3, v3, v10
	v_add_f32_e32 v3, v3, v4
	v_cvt_i32_f32_e32 v4, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v3, v3
	v_ldexp_f32 v3, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v3, 0, v3, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v2
	v_cndmask_b32_e32 v2, 0x7f800000, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v1, v2
	ds_store_b32 v5, v2 offset:512
.LBB0_39:
	s_or_b32 exec_lo, exec_lo, s9
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s2
	s_cbranch_execz .LBB0_41
; %bb.40:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_41:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s3
	s_cbranch_execz .LBB0_43
; %bb.42:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_43:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s4
	s_cbranch_execz .LBB0_45
; %bb.44:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_45:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s5
	s_cbranch_execz .LBB0_47
; %bb.46:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_47:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s6
	s_cbranch_execz .LBB0_49
; %bb.48:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_49:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s7
	s_cbranch_execz .LBB0_51
; %bb.50:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_51:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB0_53
; %bb.52:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_53:
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB0_55
; %bb.54:
	ds_load_b32 v2, v5
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v3, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v4, v3
	v_fma_f32 v10, -v3, v4, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v10, v4
	v_div_scale_f32 v10, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v11, v10, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v3, v11, v10
	v_fmac_f32_e32 v11, v12, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v3, -v3, v11, v10
	v_div_fmas_f32 v3, v3, v4, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v3, v1, v2
	ds_store_b32 v5, v2
.LBB0_55:
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB0_57
; %bb.56:
	ds_load_b32 v2, v5 offset:512
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v3, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v4, v3
	v_fma_f32 v10, -v3, v4, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v10, v4
	v_div_scale_f32 v10, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v11, v10, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v3, v11, v10
	v_fmac_f32_e32 v11, v12, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v3, -v3, v11, v10
	v_div_fmas_f32 v3, v3, v4, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v1, v3, v1, v2
	ds_store_b32 v5, v1 offset:512
.LBB0_57:                               ; %.preheader218.1
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB0_65
; %bb.58:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s10, exec_lo
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s45, exec_lo, s10
	s_cbranch_execz .LBB0_61
; %bb.59:                               ; %.preheader216.1256
	v_subrev_nc_u32_e32 v1, s28, v0
	v_mov_b32_e32 v2, 0
	s_add_u32 s10, s36, s35
	s_addc_u32 s11, s37, s44
	s_add_u32 s10, s10, s33
	v_lshlrev_b32_e32 v1, 7, v1
	s_addc_u32 s11, s11, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v1, vcc_lo, s10, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s11, v4, vcc_lo
	s_mov_b64 s[10:11], 0
	v_add_co_u32 v3, vcc_lo, v1, 16
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
.LBB0_60:                               ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[10:13], v[3:4], off offset:-16
	global_load_b128 v[14:17], v[3:4], off
	s_add_u32 s12, s38, s10
	s_addc_u32 s13, s39, s11
	v_add_co_u32 v3, vcc_lo, v3, 32
	s_load_b512 s[12:27], s[12:13], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s10, s10, 64
	s_addc_u32 s11, s11, 0
	s_cmpk_eq_i32 s10, 0x200
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v1, 16, v10
	v_and_b32_e32 v10, 0xffff0000, v10
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s12, v1 :: v_dual_lshlrev_b32 v1, 16, v11
	v_fmac_f32_e32 v2, s13, v10
	v_and_b32_e32 v10, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s14, v1 :: v_dual_lshlrev_b32 v1, 16, v12
	v_fmac_f32_e32 v2, s15, v10
	v_and_b32_e32 v10, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s16, v1
	v_dual_fmac_f32 v2, s17, v10 :: v_dual_lshlrev_b32 v1, 16, v13
	v_and_b32_e32 v10, 0xffff0000, v13
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s18, v1 :: v_dual_lshlrev_b32 v1, 16, v14
	v_fmac_f32_e32 v2, s19, v10
	v_and_b32_e32 v10, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s20, v1 :: v_dual_lshlrev_b32 v1, 16, v15
	v_fmac_f32_e32 v2, s21, v10
	v_and_b32_e32 v10, 0xffff0000, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s22, v1 :: v_dual_lshlrev_b32 v1, 16, v16
	v_fmac_f32_e32 v2, s23, v10
	v_and_b32_e32 v10, 0xffff0000, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s24, v1
	v_dual_fmac_f32 v2, s25, v10 :: v_dual_lshlrev_b32 v1, 16, v17
	v_and_b32_e32 v10, 0xffff0000, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s26, v1
	v_fmac_f32_e32 v2, s27, v10
	s_cbranch_scc0 .LBB0_60
.LBB0_61:                               ; %Flow2162
	s_and_not1_saveexec_b32 s12, s45
	s_cbranch_execz .LBB0_64
; %bb.62:
	v_lshrrev_b32_e32 v1, 5, v0
	v_and_b32_e32 v2, 31, v0
	v_mov_b32_e32 v10, 0
	s_mov_b32 s13, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_mul_u32_u24_e32 v3, 0xa00, v1
	v_lshl_or_b32 v1, v2, 6, 1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s10, v1, v3
	v_add_co_ci_u32_e64 v4, null, 0, 0, s10
	v_add_co_u32 v11, s10, s36, v3
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_u32 v3, vcc_lo, s36, v2
	v_add_co_ci_u32_e64 v12, null, s37, 0, s10
	v_add_co_ci_u32_e64 v4, null, s37, v4, vcc_lo
	v_mov_b32_e32 v2, v10
	s_mov_b64 s[10:11], 0
.LBB0_63:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v13, s13, v7
	s_add_u32 s14, s38, s10
	s_addc_u32 s15, s39, s11
	s_add_i32 s13, s13, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v13, 1, v13
	v_add_co_u32 v13, vcc_lo, v11, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, 0, v12, vcc_lo
	v_add_co_u32 v15, vcc_lo, v11, v1
	v_add_co_ci_u32_e64 v16, null, v12, v10, vcc_lo
	global_load_d16_u8 v17, v[13:14], off
	v_add_co_u32 v13, vcc_lo, v11, s10
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, s11, v12, vcc_lo
	s_clause 0x1
	global_load_d16_hi_u8 v17, v[15:16], off
	global_load_b128 v[13:16], v[13:14], off offset:2048
	global_load_d16_u8 v18, v[3:4], off
	s_load_b128 s[16:19], s[14:15], 0x200
	v_add_co_u32 v3, vcc_lo, v3, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, 2
	v_add_co_ci_u32_e64 v10, null, 0, v10, vcc_lo
	s_add_u32 s10, s10, 16
	s_addc_u32 s11, s11, 0
	s_cmpk_eq_i32 s10, 0x200
	s_waitcnt vmcnt(2)
	v_and_b16 v19.l, v17.l, 15
	v_lshrrev_b16 v17.l, 4, v17.l
	v_and_b16 v20.l, v17.h, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v19, v19
	v_cvt_f32_ubyte0_e32 v17, v17
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v18.l, 4, v18.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fma_mix_f32 v13, v13, v19, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v19, v20
	v_fma_mix_f32 v14, v14, v17, v14 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s16, v13
	v_cvt_f32_ubyte0_e32 v13, v18
	v_fma_mix_f32 v15, v15, v19, v15 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, s17, v14
	v_fma_mix_f32 v13, v16, v13, v16 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s18, v15
	v_fmac_f32_e32 v2, s19, v13
	s_cbranch_scc0 .LBB0_63
.LBB0_64:                               ; %Flow2163
	s_or_b32 exec_lo, exec_lo, s12
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1024
.LBB0_65:                               ; %Flow2164
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB0_74
; %bb.66:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s10, exec_lo
	v_cmpx_le_i32_e64 s28, v9
	s_xor_b32 s45, exec_lo, s10
	s_cbranch_execz .LBB0_70
; %bb.67:                               ; %.preheader216.1.1
	v_subrev_nc_u32_e32 v1, s28, v9
	v_mov_b32_e32 v2, 0
	s_add_u32 s10, s36, s35
	s_addc_u32 s11, s37, s44
	s_add_u32 s10, s10, s33
	v_lshlrev_b32_e32 v1, 7, v1
	s_addc_u32 s11, s11, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v1, vcc_lo, s10, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s11, v4, vcc_lo
	s_mov_b64 s[10:11], 0
	v_add_co_u32 v3, vcc_lo, v1, 16
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
.LBB0_68:                               ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[9:12], v[3:4], off offset:-16
	global_load_b128 v[13:16], v[3:4], off
	s_add_u32 s12, s38, s10
	s_addc_u32 s13, s39, s11
	v_add_co_u32 v3, vcc_lo, v3, 32
	s_load_b512 s[12:27], s[12:13], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s10, s10, 64
	s_addc_u32 s11, s11, 0
	s_cmpk_eq_i32 s10, 0x200
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v1, 16, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s12, v1 :: v_dual_lshlrev_b32 v1, 16, v10
	v_dual_fmac_f32 v2, s13, v7 :: v_dual_and_b32 v7, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s14, v1 :: v_dual_lshlrev_b32 v1, 16, v11
	v_fmac_f32_e32 v2, s15, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s16, v1 :: v_dual_and_b32 v7, 0xffff0000, v11
	v_dual_fmac_f32 v2, s17, v7 :: v_dual_lshlrev_b32 v1, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s18, v1 :: v_dual_and_b32 v7, 0xffff0000, v12
	s_waitcnt vmcnt(0)
	v_dual_fmac_f32 v2, s19, v7 :: v_dual_lshlrev_b32 v1, 16, v13
	v_and_b32_e32 v7, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s20, v1 :: v_dual_lshlrev_b32 v1, 16, v14
	v_dual_fmac_f32 v2, s21, v7 :: v_dual_and_b32 v7, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s22, v1 :: v_dual_lshlrev_b32 v1, 16, v15
	v_fmac_f32_e32 v2, s23, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s24, v1 :: v_dual_and_b32 v7, 0xffff0000, v15
	v_dual_fmac_f32 v2, s25, v7 :: v_dual_lshlrev_b32 v1, 16, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s26, v1 :: v_dual_and_b32 v7, 0xffff0000, v16
	v_fmac_f32_e32 v2, s27, v7
	s_cbranch_scc0 .LBB0_68
; %bb.69:                               ; %Flow2155
                                        ; implicit-def: $vgpr7
                                        ; implicit-def: $vgpr9
.LBB0_70:                               ; %Flow2157
	s_and_not1_saveexec_b32 s12, s45
	s_cbranch_execz .LBB0_73
; %bb.71:
	v_lshrrev_b32_e32 v1, 5, v9
	v_dual_mov_b32 v9, 0 :: v_dual_and_b32 v2, 31, v0
	s_mov_b32 s13, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_u32_u24_e32 v3, 0xa00, v1
	v_lshl_or_b32 v1, v2, 6, 1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s10, v1, v3
	v_add_co_ci_u32_e64 v4, null, 0, 0, s10
	v_add_co_u32 v10, s10, s36, v3
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_u32 v3, vcc_lo, s36, v2
	v_add_co_ci_u32_e64 v11, null, s37, 0, s10
	v_add_co_ci_u32_e64 v4, null, s37, v4, vcc_lo
	v_mov_b32_e32 v2, v9
	s_mov_b64 s[10:11], 0
.LBB0_72:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v12, s13, v7
	s_add_u32 s14, s38, s10
	s_addc_u32 s15, s39, s11
	s_add_i32 s13, s13, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v12, 1, v12
	v_add_co_u32 v12, vcc_lo, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v13, null, 0, v11, vcc_lo
	v_add_co_u32 v14, vcc_lo, v10, v1
	v_add_co_ci_u32_e64 v15, null, v11, v9, vcc_lo
	global_load_d16_u8 v16, v[12:13], off
	v_add_co_u32 v12, vcc_lo, v10, s10
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v13, null, s11, v11, vcc_lo
	s_clause 0x1
	global_load_d16_hi_u8 v16, v[14:15], off
	global_load_b128 v[12:15], v[12:13], off offset:2048
	global_load_d16_u8 v17, v[3:4], off
	s_load_b128 s[16:19], s[14:15], 0x200
	v_add_co_u32 v3, vcc_lo, v3, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, 2
	v_add_co_ci_u32_e64 v9, null, 0, v9, vcc_lo
	s_add_u32 s10, s10, 16
	s_addc_u32 s11, s11, 0
	s_cmpk_eq_i32 s10, 0x200
	s_waitcnt vmcnt(2)
	v_and_b16 v18.l, v16.l, 15
	v_lshrrev_b16 v16.l, 4, v16.l
	v_and_b16 v19.l, v16.h, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v18, v18
	v_cvt_f32_ubyte0_e32 v16, v16
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v17.l, 4, v17.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fma_mix_f32 v12, v12, v18, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v18, v19
	v_fma_mix_f32 v13, v13, v16, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s16, v12
	v_cvt_f32_ubyte0_e32 v12, v17
	v_fma_mix_f32 v14, v14, v18, v14 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, s17, v13
	v_fma_mix_f32 v12, v15, v12, v15 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s18, v14
	v_fmac_f32_e32 v2, s19, v12
	s_cbranch_scc0 .LBB0_72
.LBB0_73:                               ; %Flow2158
	s_or_b32 exec_lo, exec_lo, s12
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1536
.LBB0_74:                               ; %Flow2159
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB0_76
; %bb.75:
	ds_load_b32 v1, v6 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB0_76:
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB0_78
; %bb.77:
	ds_load_b32 v2, v6 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB0_78:
	s_or_b32 exec_lo, exec_lo, s9
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s2
	s_cbranch_execz .LBB0_80
; %bb.79:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_80:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s3
	s_cbranch_execz .LBB0_82
; %bb.81:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_82:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s4
	s_cbranch_execz .LBB0_84
; %bb.83:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_84:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s5
	s_cbranch_execz .LBB0_86
; %bb.85:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_86:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s6
	s_cbranch_execz .LBB0_88
; %bb.87:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_88:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s7
	s_cbranch_execz .LBB0_90
; %bb.89:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_90:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB0_92
; %bb.91:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB0_92:
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB0_94
; %bb.93:
	ds_load_b32 v1, v6 offset:1024
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v3, 0x3fb8aa3b, v1
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v1
	v_fma_f32 v4, 0x3fb8aa3b, v1, -v3
	v_rndne_f32_e32 v7, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v4, v1, 0x32a5705f, v4 :: v_dual_sub_f32 v3, v3, v7
	v_add_f32_e32 v3, v3, v4
	v_cvt_i32_f32_e32 v4, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v3, v3
	v_ldexp_f32 v3, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v3, 0, v3, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v1
	v_cndmask_b32_e32 v1, 0x7f800000, v3, vcc_lo
	ds_store_b32 v5, v1 offset:1024
.LBB0_94:
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB0_96
; %bb.95:
	ds_load_b32 v3, v6 offset:1536
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v3, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v3, 0x3fb8aa3b, v2
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v2
	v_fma_f32 v4, 0x3fb8aa3b, v2, -v3
	v_rndne_f32_e32 v6, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v4, v2, 0x32a5705f, v4 :: v_dual_sub_f32 v3, v3, v6
	v_add_f32_e32 v3, v3, v4
	v_cvt_i32_f32_e32 v4, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v3, v3
	v_ldexp_f32 v3, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v3, 0, v3, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v2
	v_cndmask_b32_e32 v2, 0x7f800000, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v1, v2
	ds_store_b32 v5, v2 offset:1536
.LBB0_96:
	s_or_b32 exec_lo, exec_lo, s9
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s2
	s_cbranch_execz .LBB0_98
; %bb.97:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_98:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s3
	s_cbranch_execz .LBB0_100
; %bb.99:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_100:
	s_or_b32 exec_lo, exec_lo, s2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s4
	s_cbranch_execz .LBB0_102
; %bb.101:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_102:
	s_or_b32 exec_lo, exec_lo, s2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s5
	s_cbranch_execz .LBB0_104
; %bb.103:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_104:
	s_or_b32 exec_lo, exec_lo, s2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s6
	s_cbranch_execz .LBB0_106
; %bb.105:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_106:
	s_or_b32 exec_lo, exec_lo, s2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s7
	s_cbranch_execz .LBB0_108
; %bb.107:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_108:
	s_or_b32 exec_lo, exec_lo, s2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s8
	s_cbranch_execz .LBB0_110
; %bb.109:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB0_110:
	s_or_b32 exec_lo, exec_lo, s2
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s2, s0
	s_cbranch_execz .LBB0_112
; %bb.111:
	ds_load_b32 v2, v5 offset:1024
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v3, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v4, v3
	v_fma_f32 v6, -v3, v4, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v6, v4
	v_div_scale_f32 v6, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v7, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v3, v7, v6
	v_fmac_f32_e32 v7, v8, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v3, -v3, v7, v6
	v_div_fmas_f32 v3, v3, v4, v7
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v3, v1, v2
	ds_store_b32 v5, v2 offset:1024
.LBB0_112:
	s_or_b32 exec_lo, exec_lo, s2
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB0_114
; %bb.113:
	ds_load_b32 v2, v5 offset:1536
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v3, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v4, v3
	v_fma_f32 v6, -v3, v4, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v6, v4
	v_div_scale_f32 v6, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v7, v6, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v3, v7, v6
	v_fmac_f32_e32 v7, v8, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v3, -v3, v7, v6
	v_div_fmas_f32 v3, v3, v4, v7
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v1, v3, v1, v2
	ds_store_b32 v5, v1 offset:1536
.LBB0_114:                              ; %.preheader214
	s_or_b32 exec_lo, exec_lo, s0
	s_waitcnt lgkmcnt(0)
	v_dual_mov_b32 v6, 0 :: v_dual_and_b32 v1, 1, v0
	v_lshrrev_b32_e32 v2, 3, v0
	s_add_u32 s4, s36, s33
	s_addc_u32 s5, s37, s34
	v_lshrrev_b32_e32 v3, 1, v0
	v_cmp_eq_u32_e64 s0, 0, v1
	v_and_b32_e32 v4, 0x7c, v2
	s_cmp_gt_i32 s29, 0
	s_mov_b32 s6, 0
	s_cselect_b32 s1, -1, 0
	s_cmp_lt_i32 s29, 1
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB0_122
; %bb.115:                              ; %.lr.ph.preheader
	s_cmp_lt_u32 s29, 4
	s_cbranch_scc1 .LBB0_119
; %bb.116:                              ; %.lr.ph.preheader.new
	s_and_b32 s6, s29, 0x7ffffffc
	s_add_u32 s2, s36, s33
	s_addc_u32 s3, s37, s34
	v_add_co_u32 v1, s7, s2, v4
	v_add_co_u32 v7, s2, s2, v3
	v_add_co_ci_u32_e64 v2, null, s3, 0, s7
	v_add_co_ci_u32_e64 v8, null, s3, 0, s2
	v_mov_b32_e32 v6, 0
	s_mov_b32 s7, 0
	s_mov_b64 s[2:3], 0
	s_mov_b32 s8, 0
.LBB0_117:                              ; %.lr.ph
                                        ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v9, vcc_lo, v7, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s3, v8, vcc_lo
	v_add_co_u32 v11, vcc_lo, v1, s2
	v_add_co_ci_u32_e64 v12, null, s3, v2, vcc_lo
	s_add_i32 s9, s2, 0xa0
	s_clause 0x3
	global_load_u8 v17, v[9:10], off
	global_load_b32 v18, v[11:12], off offset:64
	global_load_b32 v19, v[11:12], off offset:144
	global_load_u8 v20, v[9:10], off offset:80
	s_add_u32 s9, s4, s9
	s_addc_u32 s10, s5, 0
	s_add_i32 s11, s2, 0xf0
	v_add_co_u32 v13, s12, s9, v3
	v_add_co_u32 v15, s9, s9, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v16, null, s10, 0, s9
	s_add_u32 s9, s4, s11
	v_add_co_ci_u32_e64 v14, null, s10, 0, s12
	s_addc_u32 s10, s5, 0
	v_add_co_u32 v9, s11, s9, v3
	v_add_co_ci_u32_e64 v10, null, s10, 0, s11
	s_clause 0x2
	global_load_u8 v13, v[13:14], off
	global_load_b32 v14, v[15:16], off offset:64
	global_load_u8 v15, v[9:10], off
	v_add_co_u32 v9, s9, s9, v4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s10, 0, s9
	s_add_i32 s8, s8, 4
	s_add_u32 s2, s2, 0x140
	s_addc_u32 s3, s3, 0
	global_load_b32 v16, v[9:10], off offset:64
	v_mov_b32_e32 v9, s7
	s_add_i32 s7, s7, 16
	s_cmp_eq_u32 s6, s8
	s_waitcnt vmcnt(7)
	v_lshrrev_b32_e32 v21, 4, v17
	s_waitcnt vmcnt(4)
	v_lshrrev_b32_e32 v22, 4, v20
	v_and_b32_e32 v20, 15, v20
	ds_load_b128 v[9:12], v9
	v_and_b32_e32 v17, 15, v17
	v_cndmask_b32_e64 v20, v22, v20, s0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cndmask_b32_e64 v17, v21, v17, s0
	v_cvt_f32_ubyte0_e32 v20, v20
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v17, v17
	s_waitcnt vmcnt(3)
	v_lshrrev_b32_e32 v21, 4, v13
	v_and_b32_e32 v13, 15, v13
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v22, 4, v15
	v_fma_mix_f32 v17, v18, v17, v18 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_and_b32_e32 v15, 15, v15
	v_fma_mix_f32 v18, v19, v20, v19 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cndmask_b32_e64 v13, v21, v13, s0
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v6, v9, v17
	v_cndmask_b32_e64 v15, v22, v15, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v13, v13
	v_fmac_f32_e32 v6, v10, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v9, v15
	v_fma_mix_f32 v13, v14, v13, v14 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_mix_f32 v9, v16, v9, v16 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v6, v11, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v12, v9
	s_cbranch_scc0 .LBB0_117
; %bb.118:                              ; %.preheader212.loopexit.unr-lcssa
	s_and_b32 s2, s29, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s2, 0
	s_cbranch_scc0 .LBB0_120
	s_branch .LBB0_122
.LBB0_119:
	v_mov_b32_e32 v6, 0
	s_and_b32 s2, s29, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s2, 0
	s_cbranch_scc1 .LBB0_122
.LBB0_120:                              ; %.lr.ph.epil.preheader
	s_mul_i32 s3, s6, 0x50
	s_lshl_b32 s6, s6, 2
	s_add_u32 s3, s36, s3
	s_addc_u32 s7, s37, 0
	s_add_u32 s3, s3, s33
	s_addc_u32 s7, s7, s34
	v_add_co_u32 v1, s8, s3, v4
	v_add_co_u32 v7, s3, s3, v3
	v_add_co_ci_u32_e64 v2, null, s7, 0, s8
	v_add_co_ci_u32_e64 v8, null, s7, 0, s3
	s_mul_i32 s7, s2, 0x50
	s_mov_b64 s[2:3], 0
	.p2align	6
.LBB0_121:                              ; %.lr.ph.epil
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v7, s2
	v_add_co_ci_u32_e64 v10, null, s3, v8, vcc_lo
	global_load_u8 v11, v[9:10], off
	v_add_co_u32 v9, vcc_lo, v1, s2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s3, v2, vcc_lo
	global_load_b32 v9, v[9:10], off offset:64
	v_mov_b32_e32 v10, s6
	s_add_i32 s6, s6, 4
	s_add_u32 s2, s2, 0x50
	s_addc_u32 s3, s3, 0
	s_cmp_lg_u32 s7, s2
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v12, 4, v11
	v_and_b32_e32 v11, 15, v11
	ds_load_b32 v10, v10
	v_cndmask_b32_e64 v11, v12, v11, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v11, v11
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v11, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v10, v9
	s_cbranch_scc1 .LBB0_121
.LBB0_122:                              ; %.preheader212
	s_lshl_b32 s2, s30, 7
	v_lshlrev_b32_e32 v7, 1, v0
	s_ashr_i32 s3, s2, 31
	s_cmp_gt_i32 s31, 0
	s_cselect_b32 s6, -1, 0
	s_cmp_lt_i32 s31, 1
	s_cbranch_scc1 .LBB0_125
; %bb.123:                              ; %.lr.ph236.preheader
	s_add_u32 s7, s4, s35
	s_addc_u32 s8, s5, s44
	s_lshl_b64 s[4:5], s[2:3], 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	s_add_u32 s4, s7, s4
	s_addc_u32 s5, s8, s5
	v_add_co_u32 v1, s4, s4, v7
	v_add_co_ci_u32_e64 v2, null, s5, 0, s4
	s_lshl_b32 s4, s29, 2
	s_mov_b32 s5, s31
.LBB0_124:                              ; %.lr.ph236
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u16 v8, v[1:2], off
	v_mov_b32_e32 v9, s4
	v_add_co_u32 v1, vcc_lo, 0x100, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_i32 s5, s5, -1
	s_add_i32 s4, s4, 4
	s_cmp_eq_u32 s5, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v8, 16, v8
	ds_load_b32 v9, v9
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v6, v9, v8
	s_cbranch_scc0 .LBB0_124
.LBB0_125:                              ; %._crit_edge
	s_and_not1_b32 vcc_lo, exec_lo, s1
	ds_store_b32 v5, v6 offset:4096
	s_cbranch_vccnz .LBB0_129
; %bb.126:                              ; %.lr.ph.1.preheader
	s_add_u32 s1, s36, s33
	s_addc_u32 s4, s37, s34
	v_add_co_u32 v1, s5, s1, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v2, null, s4, 0, s5
	v_add_co_u32 v3, s1, s1, v3
	v_add_co_u32 v1, vcc_lo, v1, 64
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_ci_u32_e64 v4, null, s4, 0, s1
	v_mov_b32_e32 v6, 0
	s_movk_i32 s1, 0x400
	s_mov_b32 s4, s29
	.p2align	6
.LBB0_127:                              ; %.lr.ph.1
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v8, v[3:4], off
	global_load_b32 v9, v[1:2], off
	v_mov_b32_e32 v10, s1
	v_add_co_u32 v1, vcc_lo, 0x50, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	ds_load_b32 v10, v10
	v_add_co_u32 v3, vcc_lo, 0x50, v3
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_i32 s4, s4, -1
	s_add_i32 s1, s1, 4
	s_cmp_lg_u32 s4, 0
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v11, 4, v8
	v_and_b32_e32 v8, 15, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v8, v11, v8, s0
	v_cvt_f32_ubyte0_e32 v8, v8
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_mix_f32 v8, v9, v8, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v6, v10, v8
	s_cbranch_scc1 .LBB0_127
; %bb.128:                              ; %Flow2147
	v_or_b32_e32 v3, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s6
	s_cbranch_vccz .LBB0_130
	s_branch .LBB0_132
.LBB0_129:
	v_mov_b32_e32 v6, 0
	v_or_b32_e32 v3, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s6
	s_cbranch_vccnz .LBB0_132
.LBB0_130:                              ; %.lr.ph236.1
	s_lshl_b32 s0, s29, 2
	s_lshl_b64 s[2:3], s[2:3], 1
	s_addk_i32 s0, 0x400
	s_add_u32 s1, s36, s35
	s_addc_u32 s4, s37, s44
	s_add_u32 s1, s1, s33
	s_addc_u32 s4, s4, s34
	s_add_u32 s1, s1, s2
	s_addc_u32 s2, s4, s3
	v_add_co_u32 v1, s1, s1, v7
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s2, 0, s1
.LBB0_131:                              ; =>This Inner Loop Header: Depth=1
	global_load_u16 v4, v[1:2], off
	v_mov_b32_e32 v7, s0
	v_add_co_u32 v1, vcc_lo, 0x100, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_i32 s31, s31, -1
	s_add_i32 s0, s0, 4
	s_cmp_lg_u32 s31, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v4, 16, v4
	ds_load_b32 v7, v7
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v6, v7, v4
	s_cbranch_scc1 .LBB0_131
.LBB0_132:                              ; %._crit_edge.1
	v_lshlrev_b32_e32 v2, 9, v0
	v_mov_b32_e32 v4, 0
	s_movk_i32 s2, 0x1000
	ds_store_b32 v3, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v0, s0, s40, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s41, 0, s0
	s_mov_b64 s[0:1], 0
	s_barrier
	buffer_gl0_inv
.LBB0_133:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v10, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s1, v1, vcc_lo
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	v_mov_b32_e32 v3, s2
	s_add_i32 s2, s2, 64
	s_cmpk_eq_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v3
	ds_load_b128 v[18:21], v3 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v4, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v6, v17
	ds_load_b128 v[14:17], v3 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v4, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v4, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v6, v21
	ds_load_b128 v[6:9], v3 offset:48
	v_and_b32_e32 v3, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v3, v15
	v_dual_fmac_f32 v4, v10, v16 :: v_dual_and_b32 v3, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v3, v17 :: v_dual_and_b32 v3, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v4, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v3, v7 :: v_dual_and_b32 v3, 0xffff0000, v13
	v_fmac_f32_e32 v4, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v3, v9
	s_cbranch_scc0 .LBB0_133
; %bb.134:                              ; %.preheader.1
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_135:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v11, null, s1, v1, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	v_mov_b32_e32 v3, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v3
	ds_load_b128 v[18:21], v3 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v4, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v6, v17
	ds_load_b128 v[14:17], v3 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v4, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v4, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v6, v21
	ds_load_b128 v[6:9], v3 offset:48
	v_and_b32_e32 v3, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v3, v15
	v_dual_fmac_f32 v4, v10, v16 :: v_dual_and_b32 v3, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v3, v17 :: v_dual_and_b32 v3, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v4, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v3, v7 :: v_dual_and_b32 v3, 0xffff0000, v13
	v_fmac_f32_e32 v4, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v3, v9
	s_cbranch_scc1 .LBB0_135
; %bb.136:                              ; %.preheader.1278
	v_add_co_u32 v0, s0, s42, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s43, 0, s0
	v_add_co_u32 v2, s0, s40, v2
	v_mov_b32_e32 v6, 0
	v_add_co_ci_u32_e64 v3, null, s41, 0, s0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v5, v4, s[42:43]
.LBB0_137:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v4, vcc_lo, 0x10000, v4
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[7:10], v[4:5], off
	global_load_b128 v[11:14], v[4:5], off offset:16
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v5, 16, v7
	ds_load_b128 v[15:18], v4
	ds_load_b128 v[19:22], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v6, v5, v15 :: v_dual_lshlrev_b32 v5, 16, v8
	v_and_b32_e32 v7, 0xffff0000, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v6, v7, v16
	v_fmac_f32_e32 v6, v5, v17
	v_lshlrev_b32_e32 v5, 16, v9
	v_and_b32_e32 v7, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v6, v7, v18 :: v_dual_and_b32 v7, 0xffff0000, v9
	ds_load_b128 v[15:18], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v6, v5, v19 :: v_dual_lshlrev_b32 v5, 16, v10
	v_dual_fmac_f32 v6, v7, v20 :: v_dual_and_b32 v7, 0xffff0000, v10
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v6, v5, v21 :: v_dual_lshlrev_b32 v5, 16, v11
	v_fmac_f32_e32 v6, v7, v22
	ds_load_b128 v[7:10], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v11
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v6, v5, v15 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v6, v4, v16
	v_and_b32_e32 v4, 0xffff0000, v12
	v_fmac_f32_e32 v6, v5, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v6, v4, v18 :: v_dual_lshlrev_b32 v5, 16, v13
	v_and_b32_e32 v4, 0xffff0000, v13
	s_waitcnt lgkmcnt(0)
	v_dual_fmac_f32 v6, v5, v7 :: v_dual_lshlrev_b32 v5, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v6, v4, v8
	v_and_b32_e32 v4, 0xffff0000, v14
	v_fmac_f32_e32 v6, v5, v9
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v4, v10
	s_cbranch_scc1 .LBB0_137
; %bb.138:                              ; %.preheader.1.1
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_139:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v5, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, 0x10000, v4
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_clause 0x1
	global_load_b128 v[7:10], v[4:5], off offset:256
	global_load_b128 v[11:14], v[4:5], off offset:272
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v5, 16, v7
	ds_load_b128 v[15:18], v4
	ds_load_b128 v[19:22], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v6, v5, v15 :: v_dual_lshlrev_b32 v5, 16, v8
	v_and_b32_e32 v7, 0xffff0000, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v6, v7, v16
	v_fmac_f32_e32 v6, v5, v17
	v_lshlrev_b32_e32 v5, 16, v9
	v_and_b32_e32 v7, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v6, v7, v18 :: v_dual_and_b32 v7, 0xffff0000, v9
	ds_load_b128 v[15:18], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v6, v5, v19 :: v_dual_lshlrev_b32 v5, 16, v10
	v_dual_fmac_f32 v6, v7, v20 :: v_dual_and_b32 v7, 0xffff0000, v10
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v6, v5, v21 :: v_dual_lshlrev_b32 v5, 16, v11
	v_fmac_f32_e32 v6, v7, v22
	ds_load_b128 v[7:10], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v11
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v6, v5, v15 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v6, v4, v16
	v_and_b32_e32 v4, 0xffff0000, v12
	v_fmac_f32_e32 v6, v5, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v6, v4, v18 :: v_dual_lshlrev_b32 v5, 16, v13
	v_and_b32_e32 v4, 0xffff0000, v13
	s_waitcnt lgkmcnt(0)
	v_dual_fmac_f32 v6, v5, v7 :: v_dual_lshlrev_b32 v5, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v6, v4, v8
	v_and_b32_e32 v4, 0xffff0000, v14
	v_fmac_f32_e32 v6, v5, v9
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v4, v10
	s_cbranch_scc1 .LBB0_139
; %bb.140:                              ; %.preheader.2
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v6, off offset:512
.LBB0_141:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x20000, v5
	v_add_co_ci_u32_e64 v10, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off
	global_load_b128 v[9:12], v[9:10], off offset:16
	v_mov_b32_e32 v21, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v22, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v6, v17 :: v_dual_and_b32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v9, 0xffff0000, v9
	v_dual_fmac_f32 v4, v6, v19 :: v_dual_and_b32 v5, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v17, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_fmac_f32_e32 v4, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v13, v15
	v_dual_fmac_f32 v4, v9, v16 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v10, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	v_fmac_f32_e32 v4, v9, v6
	v_and_b32_e32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v7
	v_fmac_f32_e32 v4, v6, v8
	s_cbranch_scc1 .LBB0_141
; %bb.142:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_143:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x20000, v5
	v_add_co_ci_u32_e64 v10, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off offset:256
	global_load_b128 v[9:12], v[9:10], off offset:272
	v_mov_b32_e32 v21, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v22, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v6, v17 :: v_dual_and_b32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v9, 0xffff0000, v9
	v_dual_fmac_f32 v4, v6, v19 :: v_dual_and_b32 v5, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v17, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_fmac_f32_e32 v4, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v13, v15
	v_dual_fmac_f32 v4, v9, v16 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v10, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	v_fmac_f32_e32 v4, v9, v6
	v_and_b32_e32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v7
	v_fmac_f32_e32 v4, v6, v8
	s_cbranch_scc1 .LBB0_143
; %bb.144:                              ; %.preheader.3
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:1024
.LBB0_145:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x30000, v4
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v4
	ds_load_b128 v[18:21], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v5, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v5, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v5, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v17
	ds_load_b128 v[14:17], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v5, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v21
	ds_load_b128 v[6:9], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v18, v14
	v_fmac_f32_e32 v5, v4, v15
	v_and_b32_e32 v4, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v16
	v_dual_fmac_f32 v5, v4, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v10, v6 :: v_dual_and_b32 v4, 0xffff0000, v12
	v_dual_fmac_f32 v5, v4, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v8 :: v_dual_and_b32 v4, 0xffff0000, v13
	v_fmac_f32_e32 v5, v4, v9
	s_cbranch_scc1 .LBB0_145
; %bb.146:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_147:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x30000, v4
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v4
	ds_load_b128 v[18:21], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v5, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v5, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v5, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v17
	ds_load_b128 v[14:17], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v5, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v21
	ds_load_b128 v[6:9], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v18, v14
	v_fmac_f32_e32 v5, v4, v15
	v_and_b32_e32 v4, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v16
	v_dual_fmac_f32 v5, v4, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v10, v6 :: v_dual_and_b32 v4, 0xffff0000, v12
	v_dual_fmac_f32 v5, v4, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v8 :: v_dual_and_b32 v4, 0xffff0000, v13
	v_fmac_f32_e32 v5, v4, v9
	s_cbranch_scc1 .LBB0_147
; %bb.148:                              ; %.preheader.4
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:1536
.LBB0_149:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x40000, v5
	v_add_co_ci_u32_e64 v10, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off
	global_load_b128 v[9:12], v[9:10], off offset:16
	v_mov_b32_e32 v21, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v22, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v6, v17 :: v_dual_and_b32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v9, 0xffff0000, v9
	v_dual_fmac_f32 v4, v6, v19 :: v_dual_and_b32 v5, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v17, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_fmac_f32_e32 v4, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v13, v15
	v_dual_fmac_f32 v4, v9, v16 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v10, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	v_fmac_f32_e32 v4, v9, v6
	v_and_b32_e32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v7
	v_fmac_f32_e32 v4, v6, v8
	s_cbranch_scc1 .LBB0_149
; %bb.150:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_151:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x40000, v5
	v_add_co_ci_u32_e64 v10, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off offset:256
	global_load_b128 v[9:12], v[9:10], off offset:272
	v_mov_b32_e32 v21, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v22, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v6, v17 :: v_dual_and_b32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v9, 0xffff0000, v9
	v_dual_fmac_f32 v4, v6, v19 :: v_dual_and_b32 v5, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v17, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_fmac_f32_e32 v4, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v13, v15
	v_dual_fmac_f32 v4, v9, v16 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v10, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	v_fmac_f32_e32 v4, v9, v6
	v_and_b32_e32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v7
	v_fmac_f32_e32 v4, v6, v8
	s_cbranch_scc1 .LBB0_151
; %bb.152:                              ; %.preheader.5
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:2048
.LBB0_153:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x50000, v4
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v4
	ds_load_b128 v[18:21], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v5, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v5, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v5, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v17
	ds_load_b128 v[14:17], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v5, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v21
	ds_load_b128 v[6:9], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v18, v14
	v_fmac_f32_e32 v5, v4, v15
	v_and_b32_e32 v4, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v16
	v_dual_fmac_f32 v5, v4, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v10, v6 :: v_dual_and_b32 v4, 0xffff0000, v12
	v_dual_fmac_f32 v5, v4, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v8 :: v_dual_and_b32 v4, 0xffff0000, v13
	v_fmac_f32_e32 v5, v4, v9
	s_cbranch_scc1 .LBB0_153
; %bb.154:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_155:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x50000, v4
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v4
	ds_load_b128 v[18:21], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v5, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v5, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v5, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v17
	ds_load_b128 v[14:17], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v5, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v21
	ds_load_b128 v[6:9], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v18, v14
	v_fmac_f32_e32 v5, v4, v15
	v_and_b32_e32 v4, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v16
	v_dual_fmac_f32 v5, v4, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v10, v6 :: v_dual_and_b32 v4, 0xffff0000, v12
	v_dual_fmac_f32 v5, v4, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v8 :: v_dual_and_b32 v4, 0xffff0000, v13
	v_fmac_f32_e32 v5, v4, v9
	s_cbranch_scc1 .LBB0_155
; %bb.156:                              ; %.preheader.6
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:2560
.LBB0_157:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x60000, v5
	v_add_co_ci_u32_e64 v10, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off
	global_load_b128 v[9:12], v[9:10], off offset:16
	v_mov_b32_e32 v21, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v22, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v6, v17 :: v_dual_and_b32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v9, 0xffff0000, v9
	v_dual_fmac_f32 v4, v6, v19 :: v_dual_and_b32 v5, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v17, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_fmac_f32_e32 v4, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v13, v15
	v_dual_fmac_f32 v4, v9, v16 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v10, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	v_fmac_f32_e32 v4, v9, v6
	v_and_b32_e32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v7
	v_fmac_f32_e32 v4, v6, v8
	s_cbranch_scc1 .LBB0_157
; %bb.158:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_159:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x60000, v5
	v_add_co_ci_u32_e64 v10, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off offset:256
	global_load_b128 v[9:12], v[9:10], off offset:272
	v_mov_b32_e32 v21, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v22, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v6, v17 :: v_dual_and_b32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v9, 0xffff0000, v9
	v_dual_fmac_f32 v4, v6, v19 :: v_dual_and_b32 v5, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v17, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_fmac_f32_e32 v4, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v13, v15
	v_dual_fmac_f32 v4, v9, v16 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v10, v5 :: v_dual_lshlrev_b32 v5, 16, v12
	v_fmac_f32_e32 v4, v9, v6
	v_and_b32_e32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v7
	v_fmac_f32_e32 v4, v6, v8
	s_cbranch_scc1 .LBB0_159
; %bb.160:                              ; %.preheader.7
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:3072
.LBB0_161:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x70000, v4
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v4
	ds_load_b128 v[18:21], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v5, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v5, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v5, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v17
	ds_load_b128 v[14:17], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v5, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v21
	ds_load_b128 v[6:9], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v18, v14
	v_fmac_f32_e32 v5, v4, v15
	v_and_b32_e32 v4, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v16
	v_dual_fmac_f32 v5, v4, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v10, v6 :: v_dual_and_b32 v4, 0xffff0000, v12
	v_dual_fmac_f32 v5, v4, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v8 :: v_dual_and_b32 v4, 0xffff0000, v13
	v_fmac_f32_e32 v5, v4, v9
	s_cbranch_scc1 .LBB0_161
; %bb.162:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB0_163:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x70000, v4
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v4, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v4
	ds_load_b128 v[18:21], v4 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v5, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v5, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v5, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v17
	ds_load_b128 v[14:17], v4 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v5, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v21
	ds_load_b128 v[6:9], v4 offset:48
	v_and_b32_e32 v4, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v5, v18, v14
	v_fmac_f32_e32 v5, v4, v15
	v_and_b32_e32 v4, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v16
	v_dual_fmac_f32 v5, v4, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v10, v6 :: v_dual_and_b32 v4, 0xffff0000, v12
	v_dual_fmac_f32 v5, v4, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v5, v6, v8 :: v_dual_and_b32 v4, 0xffff0000, v13
	v_fmac_f32_e32 v5, v4, v9
	s_cbranch_scc1 .LBB0_163
; %bb.164:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v5, off offset:3584
.LBB0_165:                              ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z5queryILi0EEvPKhPKfPKtPfiiii
		.amdhsa_group_segment_fixed_size 5632
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 48
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
		.amdhsa_next_free_vgpr 23
		.amdhsa_next_free_sgpr 46
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
	.section	.text._Z5queryILi0EEvPKhPKfPKtPfiiii,"axG",@progbits,_Z5queryILi0EEvPKhPKfPKtPfiiii,comdat
.Lfunc_end0:
	.size	_Z5queryILi0EEvPKhPKfPKtPfiiii, .Lfunc_end0-_Z5queryILi0EEvPKhPKfPKtPfiiii
                                        ; -- End function
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.num_vgpr, 23
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.num_agpr, 0
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.numbered_sgpr, 46
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.num_named_barrier, 0
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.private_seg_size, 0
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.uses_vcc, 1
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.uses_flat_scratch, 0
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.has_dyn_sized_stack, 0
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.has_recursion, 0
	.set _Z5queryILi0EEvPKhPKfPKtPfiiii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 13504
; TotalNumSgprs: 48
; NumVgprs: 23
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 5632 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 48
; NumVGPRsForWavesPerEU: 23
; Occupancy: 16
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z5queryILi1EEvPKhPKfPKtPfiiii,"axG",@progbits,_Z5queryILi1EEvPKhPKfPKtPfiiii,comdat
	.protected	_Z5queryILi1EEvPKhPKfPKtPfiiii ; -- Begin function _Z5queryILi1EEvPKhPKfPKtPfiiii
	.globl	_Z5queryILi1EEvPKhPKfPKtPfiiii
	.p2align	8
	.type	_Z5queryILi1EEvPKhPKfPKtPfiiii,@function
_Z5queryILi1EEvPKhPKfPKtPfiiii:         ; @_Z5queryILi1EEvPKhPKfPKtPfiiii
; %bb.0:
	s_load_b128 s[28:31], s[0:1], 0x20
	s_waitcnt lgkmcnt(0)
	s_add_i32 s20, s30, s28
	s_add_i32 s2, s31, s29
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s20, s2
	s_cselect_b32 s2, -1, 0
	s_cmpk_gt_i32 s20, 0x100
	s_cselect_b32 s3, -1, 0
	s_and_b32 s4, s28, 31
	s_cmp_lg_u32 s4, 0
	s_cselect_b32 s4, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s2, s2, s4
	s_or_b32 s2, s2, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s2
	s_cbranch_vccnz .LBB1_174
; %bb.1:
	s_load_b256 s[36:43], s[0:1], 0x0
	v_add_nc_u32_e32 v5, 0x80, v0
	s_ashr_i32 s1, s28, 5
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_gt_i32 s1, 0
	s_cbranch_scc1 .LBB1_3
; %bb.2:                                ; %..preheader265_crit_edge
	v_add_nc_u32_e32 v1, 0x80, v0
	v_lshlrev_b32_e32 v6, 2, v0
	v_cmp_eq_u32_e64 s0, 0, v0
	s_cbranch_execz .LBB1_4
	s_branch .LBB1_11
.LBB1_3:
                                        ; implicit-def: $vgpr1
	v_lshlrev_b32_e32 v6, 2, v0
	v_cmp_eq_u32_e64 s0, 0, v0
.LBB1_4:                                ; %.lr.ph
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v3, s2, s36, v6
	v_add_co_ci_u32_e64 v4, null, s37, 0, s2
	v_add_co_u32 v1, s2, s38, v6
	s_delay_alu instid0(VALU_DEP_3)
	v_add_co_u32 v3, vcc_lo, 0x800, v3
	v_dual_mov_b32 v7, 0 :: v_dual_add_nc_u32 v8, 0x5400, v6
	v_add_co_ci_u32_e64 v2, null, s39, 0, s2
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	v_mov_b32_e32 v9, v6
	s_movk_i32 s2, 0x5600
	s_mov_b32 s3, s1
	s_branch .LBB1_6
.LBB1_5:                                ;   in Loop: Header=BB1_6 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	v_add_co_u32 v3, vcc_lo, 0xa00, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	v_add_nc_u32_e32 v9, 0x400, v9
	s_add_i32 s3, s3, -1
	s_add_i32 s2, s2, 8
	s_cmp_eq_u32 s3, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB1_10
.LBB1_6:                                ; =>This Inner Loop Header: Depth=1
	global_load_b32 v10, v[3:4], off
	global_load_b32 v11, v[1:2], off
	s_waitcnt vmcnt(1)
	v_cvt_f32_f16_e32 v12, v10.h
	v_cvt_f32_f16_e32 v10, v10.l
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v12, v11, v12
	v_mul_f32_e32 v10, v11, v10
	ds_store_b32 v9, v12
	ds_store_b32 v8, v10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB1_8
; %bb.7:                                ; %.preheader266.preheader
                                        ;   in Loop: Header=BB1_6 Depth=1
	ds_load_b128 v[10:13], v7 offset:21504
	ds_load_b128 v[14:17], v7 offset:21520
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, 0, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21536
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21552
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21568
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21584
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21600
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21616
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21632
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21648
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21664
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21680
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21696
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21712
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21728
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21744
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21760
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21776
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21792
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21808
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21824
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21840
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21856
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21872
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21888
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21904
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21920
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21936
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21952
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21968
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21984
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:22000
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_add_f32 v10, v10, v11 :: v_dual_mov_b32 v11, s2
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v13
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v10, v10, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v15
	v_add_f32_e32 v10, v10, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v17
	ds_store_b32 v11, v10
.LBB1_8:                                ;   in Loop: Header=BB1_6 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	global_load_b32 v10, v[3:4], off
	global_load_b32 v11, v[1:2], off offset:512
	s_waitcnt vmcnt(1)
	v_cvt_f32_f16_e32 v12, v10.h
	v_cvt_f32_f16_e32 v10, v10.l
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v12, v11, v12
	v_mul_f32_e32 v10, v11, v10
	ds_store_b32 v9, v12 offset:512
	ds_store_b32 v8, v10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB1_5
; %bb.9:                                ; %.preheader266.preheader.1
                                        ;   in Loop: Header=BB1_6 Depth=1
	ds_load_b128 v[10:13], v7 offset:21504
	ds_load_b128 v[14:17], v7 offset:21520
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, 0, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21536
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21552
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21568
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21584
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21600
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21616
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21632
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21648
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21664
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21680
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21696
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21712
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21728
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21744
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21760
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21776
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21792
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21808
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21824
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21840
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21856
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21872
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21888
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21904
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21920
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21936
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21952
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:21968
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v11
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v10, v13
	ds_load_b128 v[10:13], v7 offset:21984
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v18, v14
	v_add_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v16
	v_add_f32_e32 v18, v14, v17
	ds_load_b128 v[14:17], v7 offset:22000
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v10, v18, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_add_f32 v10, v10, v11 :: v_dual_mov_b32 v11, s2
	v_add_f32_e32 v10, v10, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v13
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v10, v10, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v15
	v_add_f32_e32 v10, v10, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v10, v10, v17
	ds_store_b32 v11, v10 offset:4
	s_branch .LBB1_5
.LBB1_10:
	v_mov_b32_e32 v1, v5
.LBB1_11:                               ; %Flow2242
	v_lshlrev_b32_e32 v2, 7, v0
	v_cmp_gt_i32_e64 s0, s20, v0
	v_lshl_add_u32 v7, v0, 2, 0x4800
	s_mul_i32 s33, s1, 0xa00
	s_mul_i32 s35, s29, 0x50
	v_and_b32_e32 v8, 0xf80, v2
	s_ashr_i32 s34, s33, 31
	s_ashr_i32 s44, s35, 31
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB1_19
; %bb.12:
                                        ; implicit-def: $vgpr3
	s_mov_b32 s2, exec_lo
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s21, exec_lo, s2
	s_cbranch_execz .LBB1_15
; %bb.13:                               ; %.preheader262
	v_subrev_nc_u32_e32 v2, s28, v0
	v_mov_b32_e32 v3, 0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s2, s36, s35
	s_addc_u32 s3, s37, s44
	s_add_u32 s2, s2, s33
	v_lshlrev_b32_e32 v2, 7, v2
	s_addc_u32 s3, s3, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[4:5], 1, v[2:3]
	v_add_co_u32 v2, vcc_lo, s2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s3, v5, vcc_lo
	s_mov_b64 s[2:3], 0
	v_add_co_u32 v4, vcc_lo, v2, 16
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
.LBB1_14:                               ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[9:12], v[4:5], off offset:-16
	global_load_b128 v[13:16], v[4:5], off
	s_add_u32 s4, s38, s2
	s_addc_u32 s5, s39, s3
	v_add_co_u32 v4, vcc_lo, v4, 32
	s_load_b512 s[4:19], s[4:5], 0x0
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_u32 s2, s2, 64
	s_addc_u32 s3, s3, 0
	s_cmpk_lg_i32 s2, 0x200
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v2, 16, v9
	v_and_b32_e32 v9, 0xffff0000, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, s4, v2
	v_dual_fmac_f32 v3, s5, v9 :: v_dual_lshlrev_b32 v2, 16, v10
	v_and_b32_e32 v9, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s6, v2 :: v_dual_lshlrev_b32 v2, 16, v11
	v_fmac_f32_e32 v3, s7, v9
	v_and_b32_e32 v9, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s8, v2 :: v_dual_lshlrev_b32 v2, 16, v12
	v_fmac_f32_e32 v3, s9, v9
	v_and_b32_e32 v9, 0xffff0000, v12
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s10, v2 :: v_dual_lshlrev_b32 v2, 16, v13
	v_fmac_f32_e32 v3, s11, v9
	v_and_b32_e32 v9, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, s12, v2
	v_dual_fmac_f32 v3, s13, v9 :: v_dual_lshlrev_b32 v2, 16, v14
	v_and_b32_e32 v9, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s14, v2 :: v_dual_lshlrev_b32 v2, 16, v15
	v_fmac_f32_e32 v3, s15, v9
	v_and_b32_e32 v9, 0xffff0000, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s16, v2 :: v_dual_lshlrev_b32 v2, 16, v16
	v_fmac_f32_e32 v3, s17, v9
	v_and_b32_e32 v9, 0xffff0000, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, s18, v2
	v_fmac_f32_e32 v3, s19, v9
	s_cbranch_scc1 .LBB1_14
.LBB1_15:                               ; %Flow2237
	s_and_not1_saveexec_b32 s2, s21
	s_cbranch_execz .LBB1_18
; %bb.16:
	v_lshrrev_b32_e32 v3, 5, v0
	v_and_b32_e32 v2, 31, v0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v10, 3, v3
	v_lshlrev_b32_e32 v14, 6, v2
	v_mul_u32_u24_e32 v2, 0xa00, v3
	v_lshlrev_b32_e32 v4, 10, v3
	ds_load_b32 v3, v10 offset:22016
	v_or_b32_e32 v11, 3, v14
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v5, s3, s36, v2
	v_or_b32_e32 v15, 2, v14
	v_add_co_ci_u32_e64 v9, null, s37, 0, s3
	v_add_co_u32 v10, s3, s36, v11
	v_or_b32_e32 v16, 1, v14
	v_add_co_ci_u32_e64 v11, null, s37, 0, s3
	v_add_co_u32 v12, s3, s36, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v13, null, s37, 0, s3
	v_add_co_u32 v14, s3, s36, v15
	v_add_co_ci_u32_e64 v15, null, s37, 0, s3
	v_add_co_u32 v16, s3, s36, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v17, null, s37, 0, s3
	s_mov_b32 s3, 0
.LBB1_17:                               ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_or_b32_e32 v18, s3, v8
	s_add_i32 s3, s3, 8
	s_cmpk_eq_i32 s3, 0x80
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v18, 1, v18
	v_add_co_u32 v18, vcc_lo, v5, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v9, vcc_lo
	v_add_co_u32 v20, vcc_lo, v12, v2
	v_add_co_ci_u32_e64 v21, null, 0, v13, vcc_lo
	global_load_d16_u8 v26, v[18:19], off
	v_add_co_u32 v18, vcc_lo, v16, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v17, vcc_lo
	s_clause 0x1
	global_load_d16_b16 v29, v[20:21], off offset:1
	global_load_d16_hi_u8 v26, v[20:21], off offset:3
	v_add_co_u32 v20, vcc_lo, v14, v2
	global_load_d16_u8 v27, v[18:19], off
	v_add_co_ci_u32_e64 v21, null, 0, v15, vcc_lo
	v_add_co_u32 v18, vcc_lo, v10, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v11, vcc_lo
	global_load_d16_hi_u8 v27, v[20:21], off
	ds_load_b128 v[22:25], v4 offset:16
	v_add_co_u32 v10, vcc_lo, v10, 4
	global_load_d16_u8 v28, v[18:19], off
	ds_load_b128 v[18:21], v4
	v_add_co_ci_u32_e64 v11, null, 0, v11, vcc_lo
	v_add_co_u32 v12, vcc_lo, v12, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v13, null, 0, v13, vcc_lo
	v_add_co_u32 v14, vcc_lo, v14, 4
	v_add_co_ci_u32_e64 v15, null, 0, v15, vcc_lo
	v_add_co_u32 v16, vcc_lo, v16, 4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v17, null, 0, v17, vcc_lo
	v_add_nc_u32_e32 v4, 32, v4
	s_waitcnt vmcnt(3)
	v_and_b16 v30.l, v26.l, 15
	v_lshrrev_b16 v26.l, 4, v26.l
	v_and_b16 v31.l, v29.l, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v30, v30
	v_cvt_f32_ubyte0_e32 v32, v26
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v18, v30
	s_waitcnt vmcnt(1)
	v_lshrrev_b16 v18.l, 4, v27.l
	v_cvt_f32_ubyte0_e32 v30, v31
	v_fmac_f32_e32 v3, v19, v32
	v_bfe_u32 v19, v29, 8, 4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v18, v18
	v_fmac_f32_e32 v3, v20, v30
	v_lshrrev_b16 v20.l, 4, v27.h
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v19, v19
	v_fmac_f32_e32 v3, v21, v18
	v_and_b16 v18.l, v26.h, 15
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v20, v20
	v_fmac_f32_e32 v3, v22, v19
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v19.l, 4, v28.l
	v_cvt_f32_ubyte0_e32 v18, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v23, v20
	v_cvt_f32_ubyte0_e32 v19, v19
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v24, v18
	v_fmac_f32_e32 v3, v25, v19
	s_cbranch_scc0 .LBB1_17
.LBB1_18:                               ; %Flow2238
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v2, 0x3db504f3, v3
	ds_store_b32 v7, v2
.LBB1_19:                               ; %Flow2239
	s_or_b32 exec_lo, exec_lo, s1
	v_cmp_gt_i32_e64 s1, s20, v1
	v_lshl_add_u32 v9, v1, 2, 0x4800
	s_and_saveexec_b32 s20, s1
	s_cbranch_execz .LBB1_27
; %bb.20:
                                        ; implicit-def: $vgpr3
	s_mov_b32 s2, exec_lo
	v_cmpx_le_i32_e64 s28, v1
	s_xor_b32 s21, exec_lo, s2
	s_cbranch_execz .LBB1_23
; %bb.21:                               ; %.preheader262.1
	v_subrev_nc_u32_e32 v2, s28, v1
	v_mov_b32_e32 v3, 0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s2, s36, s35
	s_addc_u32 s3, s37, s44
	s_add_u32 s2, s2, s33
	v_lshlrev_b32_e32 v2, 7, v2
	s_addc_u32 s3, s3, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[4:5], 1, v[2:3]
	v_add_co_u32 v2, vcc_lo, s2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s3, v5, vcc_lo
	s_mov_b64 s[2:3], 0
	v_add_co_u32 v4, vcc_lo, v2, 16
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
.LBB1_22:                               ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[10:13], v[4:5], off offset:-16
	global_load_b128 v[14:17], v[4:5], off
	s_add_u32 s4, s38, s2
	s_addc_u32 s5, s39, s3
	v_add_co_u32 v4, vcc_lo, v4, 32
	s_load_b512 s[4:19], s[4:5], 0x0
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_u32 s2, s2, 64
	s_addc_u32 s3, s3, 0
	s_cmpk_eq_i32 s2, 0x200
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v2, 16, v10
	v_and_b32_e32 v10, 0xffff0000, v10
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s4, v2 :: v_dual_lshlrev_b32 v2, 16, v11
	v_dual_fmac_f32 v3, s5, v10 :: v_dual_and_b32 v10, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s6, v2 :: v_dual_lshlrev_b32 v2, 16, v12
	v_dual_fmac_f32 v3, s7, v10 :: v_dual_and_b32 v10, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s8, v2 :: v_dual_lshlrev_b32 v2, 16, v13
	v_dual_fmac_f32 v3, s9, v10 :: v_dual_and_b32 v10, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v3, s10, v2
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v2, 16, v14
	v_fmac_f32_e32 v3, s11, v10
	v_and_b32_e32 v10, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s12, v2 :: v_dual_lshlrev_b32 v2, 16, v15
	v_dual_fmac_f32 v3, s13, v10 :: v_dual_and_b32 v10, 0xffff0000, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s14, v2 :: v_dual_lshlrev_b32 v2, 16, v16
	v_dual_fmac_f32 v3, s15, v10 :: v_dual_and_b32 v10, 0xffff0000, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s16, v2 :: v_dual_lshlrev_b32 v2, 16, v17
	v_dual_fmac_f32 v3, s17, v10 :: v_dual_and_b32 v10, 0xffff0000, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, s18, v2
	v_fmac_f32_e32 v3, s19, v10
	s_cbranch_scc0 .LBB1_22
.LBB1_23:                               ; %Flow2232
	s_and_not1_saveexec_b32 s2, s21
	s_cbranch_execz .LBB1_26
; %bb.24:
	v_lshrrev_b32_e32 v3, 5, v1
	v_and_b32_e32 v4, 31, v0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_lshlrev_b32_e32 v5, 3, v3
	v_mul_lo_u32 v2, 0xa00, v3
	v_lshlrev_b32_e32 v15, 6, v4
	v_lshlrev_b32_e32 v4, 10, v3
	ds_load_b32 v3, v5 offset:22016
	v_or_b32_e32 v11, 3, v15
	v_or_b32_e32 v16, 2, v15
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v5, s3, s36, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s37, 0, s3
	v_add_co_u32 v11, s3, s36, v11
	v_or_b32_e32 v17, 1, v15
	v_add_co_ci_u32_e64 v12, null, s37, 0, s3
	v_add_co_u32 v13, s3, s36, v15
	v_add_co_ci_u32_e64 v14, null, s37, 0, s3
	v_add_co_u32 v15, s3, s36, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v16, null, s37, 0, s3
	v_add_co_u32 v17, s3, s36, v17
	v_add_co_ci_u32_e64 v18, null, s37, 0, s3
	s_mov_b32 s3, 0
.LBB1_25:                               ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_or_b32_e32 v19, s3, v8
	s_add_i32 s3, s3, 8
	s_cmpk_eq_i32 s3, 0x80
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v19, 1, v19
	v_add_co_u32 v19, vcc_lo, v5, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v20, null, 0, v10, vcc_lo
	v_add_co_u32 v21, vcc_lo, v13, v2
	v_add_co_ci_u32_e64 v22, null, 0, v14, vcc_lo
	global_load_d16_u8 v27, v[19:20], off
	v_add_co_u32 v19, vcc_lo, v17, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v20, null, 0, v18, vcc_lo
	s_clause 0x1
	global_load_d16_b16 v30, v[21:22], off offset:1
	global_load_d16_hi_u8 v27, v[21:22], off offset:3
	v_add_co_u32 v21, vcc_lo, v15, v2
	global_load_d16_u8 v28, v[19:20], off
	v_add_co_ci_u32_e64 v22, null, 0, v16, vcc_lo
	v_add_co_u32 v19, vcc_lo, v11, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v20, null, 0, v12, vcc_lo
	global_load_d16_hi_u8 v28, v[21:22], off
	ds_load_b128 v[23:26], v4 offset:16
	v_add_co_u32 v11, vcc_lo, v11, 4
	global_load_d16_u8 v29, v[19:20], off
	ds_load_b128 v[19:22], v4
	v_add_co_ci_u32_e64 v12, null, 0, v12, vcc_lo
	v_add_co_u32 v13, vcc_lo, v13, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, 0, v14, vcc_lo
	v_add_co_u32 v15, vcc_lo, v15, 4
	v_add_co_ci_u32_e64 v16, null, 0, v16, vcc_lo
	v_add_co_u32 v17, vcc_lo, v17, 4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v18, null, 0, v18, vcc_lo
	v_add_nc_u32_e32 v4, 32, v4
	s_waitcnt vmcnt(3)
	v_and_b16 v31.l, v27.l, 15
	v_lshrrev_b16 v27.l, 4, v27.l
	v_and_b16 v32.l, v30.l, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v31, v31
	v_cvt_f32_ubyte0_e32 v33, v27
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v19, v31
	s_waitcnt vmcnt(1)
	v_lshrrev_b16 v19.l, 4, v28.l
	v_cvt_f32_ubyte0_e32 v31, v32
	v_fmac_f32_e32 v3, v20, v33
	v_bfe_u32 v20, v30, 8, 4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v19, v19
	v_fmac_f32_e32 v3, v21, v31
	v_lshrrev_b16 v21.l, 4, v28.h
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v20, v20
	v_fmac_f32_e32 v3, v22, v19
	v_and_b16 v19.l, v27.h, 15
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v21, v21
	v_fmac_f32_e32 v3, v23, v20
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v20.l, 4, v29.l
	v_cvt_f32_ubyte0_e32 v19, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v24, v21
	v_cvt_f32_ubyte0_e32 v20, v20
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v25, v19
	v_fmac_f32_e32 v3, v26, v20
	s_cbranch_scc0 .LBB1_25
.LBB1_26:                               ; %Flow2233
	s_or_b32 exec_lo, exec_lo, s2
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v2, 0x3db504f3, v3
	ds_store_b32 v9, v2
.LBB1_27:                               ; %Flow2234
	s_or_b32 exec_lo, exec_lo, s20
	v_mov_b32_e32 v2, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s0
	s_cbranch_execz .LBB1_29
; %bb.28:
	ds_load_b32 v2, v7
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, 0xff800000, v2
.LBB1_29:
	s_or_b32 exec_lo, exec_lo, s2
	s_and_saveexec_b32 s2, s1
	s_cbranch_execz .LBB1_31
; %bb.30:
	ds_load_b32 v3, v9
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
.LBB1_31:
	s_or_b32 exec_lo, exec_lo, s2
	v_add_nc_u32_e32 v10, 0x5400, v6
	v_cmp_gt_u32_e64 s3, 64, v0
	ds_store_b32 v6, v2 offset:21504
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s3
	s_cbranch_execz .LBB1_33
; %bb.32:
	ds_load_2addr_stride64_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_33:
	s_or_b32 exec_lo, exec_lo, s2
	v_cmp_gt_u32_e64 s4, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s4
	s_cbranch_execz .LBB1_35
; %bb.34:
	ds_load_2addr_b32 v[2:3], v10 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_35:
	s_or_b32 exec_lo, exec_lo, s2
	v_cmp_gt_u32_e64 s5, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s2, s5
	s_cbranch_execz .LBB1_37
; %bb.36:
	ds_load_2addr_b32 v[2:3], v10 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_37:
	s_or_b32 exec_lo, exec_lo, s2
	v_cmp_gt_u32_e64 s2, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s2
	s_cbranch_execz .LBB1_39
; %bb.38:
	ds_load_2addr_b32 v[2:3], v10 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_39:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB1_41
; %bb.40:
	ds_load_2addr_b32 v[2:3], v10 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_41:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB1_43
; %bb.42:
	ds_load_2addr_b32 v[2:3], v10 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_43:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_eq_u32_e64 s8, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB1_45
; %bb.44:
	ds_load_2addr_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_45:
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v3, v2 offset:21504
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB1_47
; %bb.46:
	ds_load_b32 v2, v7
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v4, 0x3fb8aa3b, v2
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v2
	v_fma_f32 v5, 0x3fb8aa3b, v2, -v4
	v_rndne_f32_e32 v11, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v5, v2, 0x32a5705f, v5 :: v_dual_sub_f32 v4, v4, v11
	v_add_f32_e32 v4, v4, v5
	v_cvt_i32_f32_e32 v5, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v4, v4
	v_ldexp_f32 v4, v4, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v4, 0, v4, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v2
	v_cndmask_b32_e32 v2, 0x7f800000, v4, vcc_lo
	ds_store_b32 v6, v2 offset:16384
.LBB1_47:
	s_or_b32 exec_lo, exec_lo, s9
	v_lshlrev_b32_e32 v11, 2, v1
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB1_49
; %bb.48:
	ds_load_b32 v4, v9
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v3, v4, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v4, 0x3fb8aa3b, v3
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v3
	v_fma_f32 v5, 0x3fb8aa3b, v3, -v4
	v_rndne_f32_e32 v12, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v5, v3, 0x32a5705f, v5 :: v_dual_sub_f32 v4, v4, v12
	v_add_f32_e32 v4, v4, v5
	v_cvt_i32_f32_e32 v5, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v4, v4
	v_ldexp_f32 v4, v4, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v4, 0, v4, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v3
	v_cndmask_b32_e32 v3, 0x7f800000, v4, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v2, v2, v3
	ds_store_b32 v11, v3 offset:16384
.LBB1_49:
	s_or_b32 exec_lo, exec_lo, s9
	ds_store_b32 v10, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s3
	s_cbranch_execz .LBB1_51
; %bb.50:
	ds_load_2addr_stride64_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_51:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s4
	s_cbranch_execz .LBB1_53
; %bb.52:
	ds_load_2addr_b32 v[2:3], v10 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_53:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s5
	s_cbranch_execz .LBB1_55
; %bb.54:
	ds_load_2addr_b32 v[2:3], v10 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_55:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s2
	s_cbranch_execz .LBB1_57
; %bb.56:
	ds_load_2addr_b32 v[2:3], v10 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_57:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s6
	s_cbranch_execz .LBB1_59
; %bb.58:
	ds_load_2addr_b32 v[2:3], v10 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_59:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s7
	s_cbranch_execz .LBB1_61
; %bb.60:
	ds_load_2addr_b32 v[2:3], v10 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_61:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB1_63
; %bb.62:
	ds_load_2addr_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_63:
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v2 offset:21504
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB1_65
; %bb.64:
	ds_load_b32 v3, v6 offset:16384
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v2, v2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v12, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v12, v5
	v_div_scale_f32 v12, vcc_lo, v3, v2, v3
	v_mul_f32_e32 v13, v12, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v4, v13, v12
	v_fmac_f32_e32 v13, v14, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v13, v12
	v_div_fmas_f32 v4, v4, v5, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v3, v4, v2, v3
	ds_store_b32 v6, v3 offset:16384
.LBB1_65:
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB1_67
; %bb.66:
	ds_load_b32 v3, v11 offset:16384
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v2, v2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v12, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v12, v5
	v_div_scale_f32 v12, vcc_lo, v3, v2, v3
	v_mul_f32_e32 v13, v12, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v14, -v4, v13, v12
	v_fmac_f32_e32 v13, v14, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v13, v12
	v_div_fmas_f32 v4, v4, v5, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v4, v2, v3
	ds_store_b32 v11, v2 offset:16384
.LBB1_67:                               ; %.preheader264.1
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB1_75
; %bb.68:
                                        ; implicit-def: $vgpr3
	s_mov_b32 s10, exec_lo
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s45, exec_lo, s10
	s_cbranch_execz .LBB1_71
; %bb.69:                               ; %.preheader262.1336
	v_subrev_nc_u32_e32 v2, s28, v0
	v_mov_b32_e32 v3, 0
	s_add_u32 s10, s36, s35
	s_addc_u32 s11, s37, s44
	s_add_u32 s10, s10, s33
	v_lshlrev_b32_e32 v2, 7, v2
	s_addc_u32 s11, s11, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[4:5], 1, v[2:3]
	v_add_co_u32 v2, vcc_lo, s10, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s11, v5, vcc_lo
	s_mov_b64 s[10:11], 0
	v_add_co_u32 v4, vcc_lo, v2, 16
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
.LBB1_70:                               ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[12:15], v[4:5], off offset:-16
	global_load_b128 v[16:19], v[4:5], off
	s_add_u32 s12, s38, s10
	s_addc_u32 s13, s39, s11
	v_add_co_u32 v4, vcc_lo, v4, 32
	s_load_b512 s[12:27], s[12:13], 0x200
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_u32 s10, s10, 64
	s_addc_u32 s11, s11, 0
	s_cmpk_eq_i32 s10, 0x200
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v2, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s12, v2 :: v_dual_and_b32 v12, 0xffff0000, v12
	v_dual_fmac_f32 v3, s13, v12 :: v_dual_lshlrev_b32 v2, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s14, v2 :: v_dual_and_b32 v12, 0xffff0000, v13
	v_dual_fmac_f32 v3, s15, v12 :: v_dual_lshlrev_b32 v2, 16, v14
	v_and_b32_e32 v12, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s16, v2 :: v_dual_lshlrev_b32 v2, 16, v15
	v_dual_fmac_f32 v3, s17, v12 :: v_dual_and_b32 v12, 0xffff0000, v15
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s18, v2 :: v_dual_lshlrev_b32 v2, 16, v16
	v_fmac_f32_e32 v3, s19, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s20, v2 :: v_dual_and_b32 v12, 0xffff0000, v16
	v_dual_fmac_f32 v3, s21, v12 :: v_dual_lshlrev_b32 v2, 16, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s22, v2 :: v_dual_and_b32 v12, 0xffff0000, v17
	v_dual_fmac_f32 v3, s23, v12 :: v_dual_lshlrev_b32 v2, 16, v18
	v_and_b32_e32 v12, 0xffff0000, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s24, v2 :: v_dual_lshlrev_b32 v2, 16, v19
	v_dual_fmac_f32 v3, s25, v12 :: v_dual_and_b32 v12, 0xffff0000, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, s26, v2
	v_fmac_f32_e32 v3, s27, v12
	s_cbranch_scc0 .LBB1_70
.LBB1_71:                               ; %Flow2227
	s_and_not1_saveexec_b32 s10, s45
	s_cbranch_execz .LBB1_74
; %bb.72:
	v_lshrrev_b32_e32 v20, 5, v0
	v_and_b32_e32 v2, 31, v0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v3, 3, v20
	v_lshlrev_b32_e32 v16, 6, v2
	v_mul_u32_u24_e32 v2, 0xa00, v20
	v_lshl_or_b32 v20, v20, 10, 0x200
	ds_load_b32 v3, v3 offset:22020
	v_or_b32_e32 v12, 3, v16
	v_add_co_u32 v4, s11, s36, v2
	v_or_b32_e32 v17, 2, v16
	v_add_co_ci_u32_e64 v5, null, s37, 0, s11
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, s11, s36, v12
	v_or_b32_e32 v18, 1, v16
	v_add_co_ci_u32_e64 v13, null, s37, 0, s11
	v_add_co_u32 v14, s11, s36, v16
	v_add_co_ci_u32_e64 v15, null, s37, 0, s11
	v_add_co_u32 v16, s11, s36, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v17, null, s37, 0, s11
	v_add_co_u32 v18, s11, s36, v18
	v_add_co_ci_u32_e64 v19, null, s37, 0, s11
	s_mov_b32 s11, 0
.LBB1_73:                               ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_or_b32_e32 v21, s11, v8
	s_add_i32 s11, s11, 8
	s_cmpk_eq_i32 s11, 0x80
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v21, 1, v21
	v_add_co_u32 v21, vcc_lo, v4, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v22, null, 0, v5, vcc_lo
	v_add_co_u32 v23, vcc_lo, v14, v2
	v_add_co_ci_u32_e64 v24, null, 0, v15, vcc_lo
	global_load_d16_u8 v29, v[21:22], off
	v_add_co_u32 v21, vcc_lo, v18, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v22, null, 0, v19, vcc_lo
	s_clause 0x1
	global_load_d16_b16 v32, v[23:24], off offset:1
	global_load_d16_hi_u8 v29, v[23:24], off offset:3
	v_add_co_u32 v23, vcc_lo, v16, v2
	global_load_d16_u8 v30, v[21:22], off
	v_add_co_ci_u32_e64 v24, null, 0, v17, vcc_lo
	v_add_co_u32 v21, vcc_lo, v12, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v22, null, 0, v13, vcc_lo
	global_load_d16_hi_u8 v30, v[23:24], off
	ds_load_b128 v[25:28], v20 offset:16
	v_add_co_u32 v12, vcc_lo, v12, 4
	global_load_d16_u8 v31, v[21:22], off
	ds_load_b128 v[21:24], v20
	v_add_co_ci_u32_e64 v13, null, 0, v13, vcc_lo
	v_add_co_u32 v14, vcc_lo, v14, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v15, vcc_lo
	v_add_co_u32 v16, vcc_lo, v16, 4
	v_add_co_ci_u32_e64 v17, null, 0, v17, vcc_lo
	v_add_co_u32 v18, vcc_lo, v18, 4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v19, vcc_lo
	v_add_nc_u32_e32 v20, 32, v20
	s_waitcnt vmcnt(3)
	v_and_b16 v33.l, v29.l, 15
	v_lshrrev_b16 v29.l, 4, v29.l
	v_and_b16 v34.l, v32.l, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v33, v33
	v_cvt_f32_ubyte0_e32 v35, v29
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v21, v33
	s_waitcnt vmcnt(1)
	v_lshrrev_b16 v21.l, 4, v30.l
	v_cvt_f32_ubyte0_e32 v33, v34
	v_fmac_f32_e32 v3, v22, v35
	v_bfe_u32 v22, v32, 8, 4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v21, v21
	v_fmac_f32_e32 v3, v23, v33
	v_lshrrev_b16 v23.l, 4, v30.h
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v22, v22
	v_fmac_f32_e32 v3, v24, v21
	v_and_b16 v21.l, v29.h, 15
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v23, v23
	v_fmac_f32_e32 v3, v25, v22
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v22.l, 4, v31.l
	v_cvt_f32_ubyte0_e32 v21, v21
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v26, v23
	v_cvt_f32_ubyte0_e32 v22, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v27, v21
	v_fmac_f32_e32 v3, v28, v22
	s_cbranch_scc0 .LBB1_73
.LBB1_74:                               ; %Flow2228
	s_or_b32 exec_lo, exec_lo, s10
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v2, 0x3db504f3, v3
	ds_store_b32 v7, v2 offset:1024
.LBB1_75:                               ; %Flow2229
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB1_84
; %bb.76:
                                        ; implicit-def: $vgpr3
	s_mov_b32 s10, exec_lo
	v_cmpx_le_i32_e64 s28, v1
	s_xor_b32 s45, exec_lo, s10
	s_cbranch_execz .LBB1_80
; %bb.77:                               ; %.preheader262.1.1
	v_subrev_nc_u32_e32 v2, s28, v1
	v_mov_b32_e32 v3, 0
	s_add_u32 s10, s36, s35
	s_addc_u32 s11, s37, s44
	s_add_u32 s10, s10, s33
	v_lshlrev_b32_e32 v2, 7, v2
	s_addc_u32 s11, s11, s34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[4:5], 1, v[2:3]
	v_add_co_u32 v2, vcc_lo, s10, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s11, v5, vcc_lo
	s_mov_b64 s[10:11], 0
	v_add_co_u32 v4, vcc_lo, v2, 16
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
.LBB1_78:                               ; =>This Inner Loop Header: Depth=1
	s_clause 0x1
	global_load_b128 v[12:15], v[4:5], off offset:-16
	global_load_b128 v[16:19], v[4:5], off
	s_add_u32 s12, s38, s10
	s_addc_u32 s13, s39, s11
	v_add_co_u32 v4, vcc_lo, v4, 32
	s_load_b512 s[12:27], s[12:13], 0x200
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_u32 s10, s10, 64
	s_addc_u32 s11, s11, 0
	s_cmpk_eq_i32 s10, 0x200
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v2, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s12, v2 :: v_dual_and_b32 v8, 0xffff0000, v12
	v_dual_fmac_f32 v3, s13, v8 :: v_dual_lshlrev_b32 v2, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s14, v2 :: v_dual_and_b32 v8, 0xffff0000, v13
	v_dual_fmac_f32 v3, s15, v8 :: v_dual_lshlrev_b32 v2, 16, v14
	v_and_b32_e32 v8, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s16, v2 :: v_dual_lshlrev_b32 v2, 16, v15
	v_dual_fmac_f32 v3, s17, v8 :: v_dual_and_b32 v8, 0xffff0000, v15
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s18, v2 :: v_dual_lshlrev_b32 v2, 16, v16
	v_fmac_f32_e32 v3, s19, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s20, v2 :: v_dual_and_b32 v8, 0xffff0000, v16
	v_dual_fmac_f32 v3, s21, v8 :: v_dual_lshlrev_b32 v2, 16, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s22, v2 :: v_dual_and_b32 v8, 0xffff0000, v17
	v_dual_fmac_f32 v3, s23, v8 :: v_dual_lshlrev_b32 v2, 16, v18
	v_and_b32_e32 v8, 0xffff0000, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v3, s24, v2 :: v_dual_lshlrev_b32 v2, 16, v19
	v_dual_fmac_f32 v3, s25, v8 :: v_dual_and_b32 v8, 0xffff0000, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, s26, v2
	v_fmac_f32_e32 v3, s27, v8
	s_cbranch_scc0 .LBB1_78
; %bb.79:                               ; %Flow2220
                                        ; implicit-def: $vgpr8
.LBB1_80:                               ; %Flow2222
	s_and_not1_saveexec_b32 s10, s45
	s_cbranch_execz .LBB1_83
; %bb.81:
	v_lshrrev_b32_e32 v20, 5, v1
	v_and_b32_e32 v3, 31, v0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_lshlrev_b32_e32 v4, 3, v20
	v_mul_lo_u32 v2, 0xa00, v20
	v_lshlrev_b32_e32 v16, 6, v3
	v_lshl_or_b32 v20, v20, 10, 0x200
	ds_load_b32 v3, v4 offset:22020
	v_or_b32_e32 v12, 3, v16
	v_or_b32_e32 v17, 2, v16
	v_add_co_u32 v4, s11, s36, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v5, null, s37, 0, s11
	v_add_co_u32 v12, s11, s36, v12
	v_or_b32_e32 v18, 1, v16
	v_add_co_ci_u32_e64 v13, null, s37, 0, s11
	v_add_co_u32 v14, s11, s36, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, s37, 0, s11
	v_add_co_u32 v16, s11, s36, v17
	v_add_co_ci_u32_e64 v17, null, s37, 0, s11
	v_add_co_u32 v18, s11, s36, v18
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, s37, 0, s11
	s_mov_b32 s11, 0
.LBB1_82:                               ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_or_b32_e32 v21, s11, v8
	s_add_i32 s11, s11, 8
	s_cmpk_eq_i32 s11, 0x80
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshrrev_b32_e32 v21, 1, v21
	v_add_co_u32 v21, vcc_lo, v4, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v22, null, 0, v5, vcc_lo
	v_add_co_u32 v23, vcc_lo, v14, v2
	v_add_co_ci_u32_e64 v24, null, 0, v15, vcc_lo
	global_load_d16_u8 v29, v[21:22], off
	v_add_co_u32 v21, vcc_lo, v18, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v22, null, 0, v19, vcc_lo
	s_clause 0x1
	global_load_d16_b16 v32, v[23:24], off offset:1
	global_load_d16_hi_u8 v29, v[23:24], off offset:3
	v_add_co_u32 v23, vcc_lo, v16, v2
	global_load_d16_u8 v30, v[21:22], off
	v_add_co_ci_u32_e64 v24, null, 0, v17, vcc_lo
	v_add_co_u32 v21, vcc_lo, v12, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v22, null, 0, v13, vcc_lo
	global_load_d16_hi_u8 v30, v[23:24], off
	ds_load_b128 v[25:28], v20 offset:16
	v_add_co_u32 v12, vcc_lo, v12, 4
	global_load_d16_u8 v31, v[21:22], off
	ds_load_b128 v[21:24], v20
	v_add_co_ci_u32_e64 v13, null, 0, v13, vcc_lo
	v_add_co_u32 v14, vcc_lo, v14, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v15, vcc_lo
	v_add_co_u32 v16, vcc_lo, v16, 4
	v_add_co_ci_u32_e64 v17, null, 0, v17, vcc_lo
	v_add_co_u32 v18, vcc_lo, v18, 4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v19, vcc_lo
	v_add_nc_u32_e32 v20, 32, v20
	s_waitcnt vmcnt(3)
	v_and_b16 v33.l, v29.l, 15
	v_lshrrev_b16 v29.l, 4, v29.l
	v_and_b16 v34.l, v32.l, 15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v33, v33
	v_cvt_f32_ubyte0_e32 v35, v29
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v21, v33
	s_waitcnt vmcnt(1)
	v_lshrrev_b16 v21.l, 4, v30.l
	v_cvt_f32_ubyte0_e32 v33, v34
	v_fmac_f32_e32 v3, v22, v35
	v_bfe_u32 v22, v32, 8, 4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v21, v21
	v_fmac_f32_e32 v3, v23, v33
	v_lshrrev_b16 v23.l, 4, v30.h
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v22, v22
	v_fmac_f32_e32 v3, v24, v21
	v_and_b16 v21.l, v29.h, 15
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v23, v23
	v_fmac_f32_e32 v3, v25, v22
	s_waitcnt vmcnt(0)
	v_lshrrev_b16 v22.l, 4, v31.l
	v_cvt_f32_ubyte0_e32 v21, v21
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v3, v26, v23
	v_cvt_f32_ubyte0_e32 v22, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v27, v21
	v_fmac_f32_e32 v3, v28, v22
	s_cbranch_scc0 .LBB1_82
.LBB1_83:                               ; %Flow2223
	s_or_b32 exec_lo, exec_lo, s10
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v2, 0x3db504f3, v3
	ds_store_b32 v9, v2 offset:1024
.LBB1_84:                               ; %Flow2224
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v2, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB1_86
; %bb.85:
	ds_load_b32 v2, v7 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, 0xff800000, v2
.LBB1_86:
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB1_88
; %bb.87:
	ds_load_b32 v3, v9 offset:1024
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
.LBB1_88:
	s_or_b32 exec_lo, exec_lo, s9
	ds_store_b32 v10, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s3
	s_cbranch_execz .LBB1_90
; %bb.89:
	ds_load_2addr_stride64_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_90:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s4
	s_cbranch_execz .LBB1_92
; %bb.91:
	ds_load_2addr_b32 v[2:3], v10 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_92:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s5
	s_cbranch_execz .LBB1_94
; %bb.93:
	ds_load_2addr_b32 v[2:3], v10 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_94:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s2
	s_cbranch_execz .LBB1_96
; %bb.95:
	ds_load_2addr_b32 v[2:3], v10 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_96:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s6
	s_cbranch_execz .LBB1_98
; %bb.97:
	ds_load_2addr_b32 v[2:3], v10 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_98:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s7
	s_cbranch_execz .LBB1_100
; %bb.99:
	ds_load_2addr_b32 v[2:3], v10 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_100:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB1_102
; %bb.101:
	ds_load_2addr_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v3, v3, v3 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v2, v2, v3
	ds_store_b32 v10, v2
.LBB1_102:
	s_or_b32 exec_lo, exec_lo, s9
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v3, v2 offset:21504
	s_and_saveexec_b32 s9, s0
	s_cbranch_execz .LBB1_104
; %bb.103:
	ds_load_b32 v2, v7 offset:1024
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v4, 0x3fb8aa3b, v2
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v2
	v_fma_f32 v5, 0x3fb8aa3b, v2, -v4
	v_rndne_f32_e32 v7, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v5, v2, 0x32a5705f, v5 :: v_dual_sub_f32 v4, v4, v7
	v_add_f32_e32 v4, v4, v5
	v_cvt_i32_f32_e32 v5, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v4, v4
	v_ldexp_f32 v4, v4, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v4, 0, v4, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v2
	v_cndmask_b32_e32 v2, 0x7f800000, v4, vcc_lo
	ds_store_b32 v6, v2 offset:17408
.LBB1_104:
	s_or_b32 exec_lo, exec_lo, s9
	s_and_saveexec_b32 s9, s1
	s_cbranch_execz .LBB1_106
; %bb.105:
	ds_load_b32 v4, v9 offset:1024
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v3, v4, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v4, 0x3fb8aa3b, v3
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v3
	v_fma_f32 v5, 0x3fb8aa3b, v3, -v4
	v_rndne_f32_e32 v7, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v5, v3, 0x32a5705f, v5 :: v_dual_sub_f32 v4, v4, v7
	v_add_f32_e32 v4, v4, v5
	v_cvt_i32_f32_e32 v5, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v4, v4
	v_ldexp_f32 v4, v4, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v4, 0, v4, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v3
	v_cndmask_b32_e32 v3, 0x7f800000, v4, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v2, v2, v3
	ds_store_b32 v11, v3 offset:17408
.LBB1_106:
	s_or_b32 exec_lo, exec_lo, s9
	ds_store_b32 v10, v2
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s3
	s_cbranch_execz .LBB1_108
; %bb.107:
	ds_load_2addr_stride64_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_108:
	s_or_b32 exec_lo, exec_lo, s9
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s4
	s_cbranch_execz .LBB1_110
; %bb.109:
	ds_load_2addr_b32 v[2:3], v10 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_110:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s5
	s_cbranch_execz .LBB1_112
; %bb.111:
	ds_load_2addr_b32 v[2:3], v10 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_112:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s2
	s_cbranch_execz .LBB1_114
; %bb.113:
	ds_load_2addr_b32 v[2:3], v10 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_114:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s6
	s_cbranch_execz .LBB1_116
; %bb.115:
	ds_load_2addr_b32 v[2:3], v10 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_116:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s7
	s_cbranch_execz .LBB1_118
; %bb.117:
	ds_load_2addr_b32 v[2:3], v10 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_118:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s8
	s_cbranch_execz .LBB1_120
; %bb.119:
	ds_load_2addr_b32 v[2:3], v10 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v3, v2
	ds_store_b32 v10, v2
.LBB1_120:
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v2 offset:21504
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB1_122
; %bb.121:
	ds_load_b32 v3, v6 offset:17408
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v2, v2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v7, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v7, v5
	v_div_scale_f32 v7, vcc_lo, v3, v2, v3
	v_mul_f32_e32 v8, v7, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v9, -v4, v8, v7
	v_fmac_f32_e32 v8, v9, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v8, v7
	v_div_fmas_f32 v4, v4, v5, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v3, v4, v2, v3
	ds_store_b32 v6, v3 offset:17408
.LBB1_122:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB1_124
; %bb.123:
	ds_load_b32 v3, v11 offset:17408
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v2, v2, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v7, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v7, v5
	v_div_scale_f32 v7, vcc_lo, v3, v2, v3
	v_mul_f32_e32 v8, v7, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v9, -v4, v8, v7
	v_fmac_f32_e32 v8, v9, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v8, v7
	v_div_fmas_f32 v4, v4, v5, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v4, v2, v3
	ds_store_b32 v11, v2 offset:17408
.LBB1_124:
	s_or_b32 exec_lo, exec_lo, s0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s2
	s_cbranch_execz .LBB1_129
; %bb.125:
	v_dual_mov_b32 v7, 0 :: v_dual_and_b32 v2, 3, v0
	v_lshrrev_b32_e32 v4, 2, v0
	s_cmp_lt_i32 s29, 1
	s_delay_alu instid0(VALU_DEP_2)
	v_lshlrev_b32_e32 v5, 2, v2
	s_cbranch_scc1 .LBB1_128
; %bb.126:                              ; %.lr.ph293
	s_add_u32 s1, s36, s33
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_lshl_or_b32 v2, v4, 12, v5
	s_addc_u32 s2, s37, s34
	v_add_co_u32 v3, s1, s1, v5
	v_add_co_ci_u32_e64 v10, null, s2, 0, s1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_nc_u32_e32 v9, 0x2000, v2
	v_add_co_u32 v2, vcc_lo, v3, 64
	v_lshl_add_u32 v8, v4, 10, 0x4000
	s_delay_alu instid0(VALU_DEP_4)
	v_add_co_ci_u32_e64 v3, null, 0, v10, vcc_lo
	s_mov_b32 s1, s29
	.p2align	6
.LBB1_127:                              ; =>This Inner Loop Header: Depth=1
	global_load_b32 v10, v[2:3], off
	ds_load_b32 v11, v8
	v_add_co_u32 v2, vcc_lo, 0x50, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
	v_add_nc_u32_e32 v8, 4, v8
	s_add_i32 s1, s1, -1
	s_cmp_eq_u32 s1, 0
	s_waitcnt vmcnt(0)
	v_cvt_f32_f16_e32 v12, v10.h
	s_waitcnt lgkmcnt(0)
	v_fma_mix_f32 v7, v11, v10, v7 op_sel_hi:[0,1,0]
	s_delay_alu instid0(VALU_DEP_2)
	v_mul_f32_e32 v12, v11, v12
	ds_store_b32 v9, v12
	v_add_nc_u32_e32 v9, 16, v9
	s_cbranch_scc0 .LBB1_127
.LBB1_128:                              ; %._crit_edge
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v2, v4, 4, v5
	ds_store_b32 v2, v7 offset:22080
.LBB1_129:                              ; %Flow2219
	s_or_b32 exec_lo, exec_lo, s0
	v_lshrrev_b32_e32 v7, 5, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_lshrrev_b32_e32 v2, 1, v0
	v_lshlrev_b32_e32 v9, 2, v7
	v_and_b32_e32 v4, 1, v0
	s_add_u32 s5, s36, s33
	s_addc_u32 s6, s37, s34
	v_add_co_u32 v2, s0, s5, v2
	ds_load_b32 v8, v9 offset:22080
	v_add_co_ci_u32_e64 v3, null, s6, 0, s0
	v_cmp_eq_u32_e64 s0, 0, v4
	s_cmp_gt_i32 s29, 0
	s_cselect_b32 s1, -1, 0
	s_cmp_lt_i32 s29, 1
	s_cbranch_scc1 .LBB1_132
; %bb.130:                              ; %.lr.ph299.preheader
	v_lshl_or_b32 v10, v7, 2, 0x2000
	v_dual_mov_b32 v5, v3 :: v_dual_mov_b32 v4, v2
	s_mov_b32 s2, s29
	.p2align	6
.LBB1_131:                              ; %.lr.ph299
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v11, v[4:5], off
	ds_load_b32 v12, v10
	v_add_co_u32 v4, vcc_lo, 0x50, v4
	v_add_nc_u32_e32 v10, 16, v10
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_i32 s2, s2, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	s_cmp_eq_u32 s2, 0
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v13, 4, v11
	v_and_b32_e32 v11, 15, v11
	v_cndmask_b32_e64 v11, v13, v11, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v11, v11
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v8, v12, v11
	s_cbranch_scc0 .LBB1_131
.LBB1_132:                              ; %Flow2216
	s_lshl_b32 s2, s30, 7
	v_add_nc_u32_e32 v10, 0x5640, v9
	s_ashr_i32 s3, s2, 31
	v_lshlrev_b32_e32 v9, 1, v0
	s_cmp_gt_i32 s31, 0
	s_cselect_b32 s4, -1, 0
	s_cmp_lt_i32 s31, 1
	s_cbranch_scc1 .LBB1_135
; %bb.133:                              ; %.lr.ph307.preheader
	s_add_u32 s5, s5, s35
	s_addc_u32 s8, s6, s44
	s_lshl_b64 s[6:7], s[2:3], 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	s_add_u32 s5, s5, s6
	s_addc_u32 s6, s8, s7
	v_add_co_u32 v4, s5, s5, v9
	v_add_co_ci_u32_e64 v5, null, s6, 0, s5
	s_lshl_b32 s5, s29, 2
	s_mov_b32 s6, s31
	s_addk_i32 s5, 0x4000
.LBB1_134:                              ; %.lr.ph307
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u16 v11, v[4:5], off
	v_mov_b32_e32 v12, s5
	v_add_co_u32 v4, vcc_lo, 0x100, v4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	s_add_i32 s6, s6, -1
	s_add_i32 s5, s5, 4
	s_cmp_eq_u32 s6, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v11, 16, v11
	ds_load_b32 v12, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v8, v12, v11
	s_cbranch_scc0 .LBB1_134
.LBB1_135:                              ; %._crit_edge308
	ds_load_b32 v4, v10 offset:16
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_waitcnt lgkmcnt(1)
	ds_store_b32 v6, v8 offset:20480
	s_cbranch_vccnz .LBB1_138
; %bb.136:                              ; %.lr.ph299.1
	v_lshl_or_b32 v5, v7, 2, 0x3000
	s_mov_b32 s1, s29
	.p2align	6
.LBB1_137:                              ; =>This Inner Loop Header: Depth=1
	global_load_u8 v7, v[2:3], off
	ds_load_b32 v8, v5
	v_add_co_u32 v2, vcc_lo, 0x50, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
	s_add_i32 s1, s1, -1
	s_cmp_lg_u32 s1, 0
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v10, 4, v7
	v_and_b32_e32 v7, 15, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v7, v10, v7, s0
	v_cvt_f32_ubyte0_e32 v7, v7
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_fmac_f32 v4, v8, v7 :: v_dual_add_nc_u32 v5, 16, v5
	s_cbranch_scc1 .LBB1_137
.LBB1_138:                              ; %Flow2212
	v_or_b32_e32 v5, 0x5000, v6
	s_and_not1_b32 vcc_lo, exec_lo, s4
	s_cbranch_vccnz .LBB1_141
; %bb.139:                              ; %.lr.ph307.1
	s_lshl_b32 s0, s29, 2
	s_lshl_b64 s[2:3], s[2:3], 1
	s_addk_i32 s0, 0x4400
	s_add_u32 s1, s36, s35
	s_addc_u32 s4, s37, s44
	s_add_u32 s1, s1, s33
	s_addc_u32 s4, s4, s34
	s_add_u32 s1, s1, s2
	s_addc_u32 s2, s4, s3
	v_add_co_u32 v2, s1, s1, v9
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s2, 0, s1
.LBB1_140:                              ; =>This Inner Loop Header: Depth=1
	global_load_u16 v7, v[2:3], off
	v_mov_b32_e32 v8, s0
	v_add_co_u32 v2, vcc_lo, 0x100, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
	s_add_i32 s31, s31, -1
	s_add_i32 s0, s0, 4
	s_cmp_lg_u32 s31, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v7, 16, v7
	ds_load_b32 v8, v8
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v4, v8, v7
	s_cbranch_scc1 .LBB1_140
.LBB1_141:                              ; %._crit_edge308.1
	v_lshlrev_b32_e32 v0, 9, v0
	s_waitcnt lgkmcnt(1)
	ds_store_b32 v5, v4 offset:512
	v_mov_b32_e32 v2, 0
	s_movk_i32 s2, 0x5000
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v3, s0, s40, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s41, 0, s0
	s_mov_b64 s[0:1], 0
	s_barrier
	buffer_gl0_inv
.LBB1_142:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v11, vcc_lo, v3, s0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s1, v4, vcc_lo
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[7:10], v[11:12], off
	global_load_b128 v[11:14], v[11:12], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v23, 16, v7
	v_mov_b32_e32 v5, s2
	s_add_i32 s2, s2, 64
	s_cmpk_eq_i32 s0, 0x100
	ds_load_b128 v[15:18], v5
	ds_load_b128 v[19:22], v5 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v23, v15 :: v_dual_lshlrev_b32 v15, 16, v8
	v_and_b32_e32 v7, 0xffff0000, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v7, v16
	v_and_b32_e32 v7, 0xffff0000, v8
	v_lshlrev_b32_e32 v8, 16, v9
	v_fmac_f32_e32 v2, v15, v17
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v7, v18
	ds_load_b128 v[15:18], v5 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v8, v19
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v19, 16, v11
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v8, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v7, v20 :: v_dual_and_b32 v7, 0xffff0000, v10
	v_fmac_f32_e32 v2, v8, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v7, v22
	ds_load_b128 v[7:10], v5 offset:48
	v_and_b32_e32 v5, 0xffff0000, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v19, v15
	v_fmac_f32_e32 v2, v5, v16
	v_and_b32_e32 v5, 0xffff0000, v12
	v_lshlrev_b32_e32 v11, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v11, v17
	v_dual_fmac_f32 v2, v5, v18 :: v_dual_lshlrev_b32 v11, 16, v13
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v11, v7 :: v_dual_and_b32 v5, 0xffff0000, v13
	v_dual_fmac_f32 v2, v5, v8 :: v_dual_lshlrev_b32 v7, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v7, v9 :: v_dual_and_b32 v5, 0xffff0000, v14
	v_fmac_f32_e32 v2, v5, v10
	s_cbranch_scc0 .LBB1_142
; %bb.143:                              ; %.preheader.1
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_144:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v12, null, s1, v4, vcc_lo
	s_clause 0x1
	global_load_b128 v[7:10], v[11:12], off offset:256
	global_load_b128 v[11:14], v[11:12], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v23, 16, v7
	v_mov_b32_e32 v5, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[15:18], v5
	ds_load_b128 v[19:22], v5 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v23, v15 :: v_dual_lshlrev_b32 v15, 16, v8
	v_and_b32_e32 v7, 0xffff0000, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v7, v16
	v_and_b32_e32 v7, 0xffff0000, v8
	v_lshlrev_b32_e32 v8, 16, v9
	v_fmac_f32_e32 v2, v15, v17
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v7, v18
	ds_load_b128 v[15:18], v5 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v8, v19
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v19, 16, v11
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v8, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v7, v20 :: v_dual_and_b32 v7, 0xffff0000, v10
	v_fmac_f32_e32 v2, v8, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v7, v22
	ds_load_b128 v[7:10], v5 offset:48
	v_and_b32_e32 v5, 0xffff0000, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v19, v15
	v_fmac_f32_e32 v2, v5, v16
	v_and_b32_e32 v5, 0xffff0000, v12
	v_lshlrev_b32_e32 v11, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v11, v17
	v_dual_fmac_f32 v2, v5, v18 :: v_dual_lshlrev_b32 v11, 16, v13
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v11, v7 :: v_dual_and_b32 v5, 0xffff0000, v13
	v_dual_fmac_f32 v2, v5, v8 :: v_dual_lshlrev_b32 v7, 16, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v7, v9 :: v_dual_and_b32 v5, 0xffff0000, v14
	v_fmac_f32_e32 v2, v5, v10
	s_cbranch_scc1 .LBB1_144
; %bb.145:                              ; %.preheader.1359
	v_add_co_u32 v3, s0, s42, v6
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s43, 0, s0
	v_add_co_u32 v0, s0, s40, v0
	v_mov_b32_e32 v7, 0
	v_add_co_ci_u32_e64 v5, null, s41, 0, s0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x5000
	global_store_b32 v6, v2, s[42:43]
.LBB1_146:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v2, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v12, vcc_lo, 0x10000, v2
	v_add_co_ci_u32_e64 v13, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[8:11], v[12:13], off
	global_load_b128 v[12:15], v[12:13], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v6, 16, v8
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[16:19], v2
	ds_load_b128 v[20:23], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v7, v6, v16 :: v_dual_lshlrev_b32 v6, 16, v9
	v_and_b32_e32 v8, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v7, v8, v17
	v_fmac_f32_e32 v7, v6, v18
	v_lshlrev_b32_e32 v6, 16, v10
	v_and_b32_e32 v8, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v7, v8, v19
	ds_load_b128 v[16:19], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v7, v6, v20 :: v_dual_and_b32 v8, 0xffff0000, v10
	v_dual_fmac_f32 v7, v8, v21 :: v_dual_lshlrev_b32 v6, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v7, v6, v22 :: v_dual_and_b32 v8, 0xffff0000, v11
	s_waitcnt vmcnt(0)
	v_dual_fmac_f32 v7, v8, v23 :: v_dual_lshlrev_b32 v6, 16, v12
	ds_load_b128 v[8:11], v2 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v7, v6, v16 :: v_dual_lshlrev_b32 v6, 16, v13
	v_and_b32_e32 v2, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v7, v2, v17
	v_fmac_f32_e32 v7, v6, v18
	v_lshlrev_b32_e32 v6, 16, v14
	v_and_b32_e32 v2, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v7, v2, v19 :: v_dual_and_b32 v2, 0xffff0000, v14
	s_waitcnt lgkmcnt(0)
	v_dual_fmac_f32 v7, v6, v8 :: v_dual_lshlrev_b32 v6, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v7, v2, v9 :: v_dual_and_b32 v2, 0xffff0000, v15
	v_fmac_f32_e32 v7, v6, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v7, v2, v11
	s_cbranch_scc1 .LBB1_146
; %bb.147:                              ; %.preheader.1.1
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_148:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, vcc_lo, 0x10000, v2
	v_add_co_ci_u32_e64 v13, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[8:11], v[12:13], off offset:256
	global_load_b128 v[12:15], v[12:13], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v6, 16, v8
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[16:19], v2
	ds_load_b128 v[20:23], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v7, v6, v16 :: v_dual_lshlrev_b32 v6, 16, v9
	v_and_b32_e32 v8, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v7, v8, v17
	v_fmac_f32_e32 v7, v6, v18
	v_lshlrev_b32_e32 v6, 16, v10
	v_and_b32_e32 v8, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v7, v8, v19
	ds_load_b128 v[16:19], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v7, v6, v20 :: v_dual_and_b32 v8, 0xffff0000, v10
	v_dual_fmac_f32 v7, v8, v21 :: v_dual_lshlrev_b32 v6, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v7, v6, v22 :: v_dual_and_b32 v8, 0xffff0000, v11
	s_waitcnt vmcnt(0)
	v_dual_fmac_f32 v7, v8, v23 :: v_dual_lshlrev_b32 v6, 16, v12
	ds_load_b128 v[8:11], v2 offset:48
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v7, v6, v16 :: v_dual_lshlrev_b32 v6, 16, v13
	v_and_b32_e32 v2, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v7, v2, v17
	v_fmac_f32_e32 v7, v6, v18
	v_lshlrev_b32_e32 v6, 16, v14
	v_and_b32_e32 v2, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v7, v2, v19 :: v_dual_and_b32 v2, 0xffff0000, v14
	s_waitcnt lgkmcnt(0)
	v_dual_fmac_f32 v7, v6, v8 :: v_dual_lshlrev_b32 v6, 16, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v7, v2, v9 :: v_dual_and_b32 v2, 0xffff0000, v15
	v_fmac_f32_e32 v7, v6, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v7, v2, v11
	s_cbranch_scc1 .LBB1_148
; %bb.149:                              ; %.preheader.2
	v_mov_b32_e32 v2, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x5000
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[8:9], 2, v[1:2]
	v_add_co_u32 v8, vcc_lo, s42, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s43, v9, vcc_lo
	global_store_b32 v[8:9], v7, off
.LBB1_150:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v1, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x20000, v1
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	v_mov_b32_e32 v1, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v1
	ds_load_b128 v[18:21], v1 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v2, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v17
	ds_load_b128 v[14:17], v1 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v2, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v21
	ds_load_b128 v[6:9], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v15
	v_dual_fmac_f32 v2, v10, v16 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v17 :: v_dual_and_b32 v1, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v7 :: v_dual_and_b32 v1, 0xffff0000, v13
	v_fmac_f32_e32 v2, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v9
	s_cbranch_scc1 .LBB1_150
; %bb.151:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_152:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x20000, v1
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	v_mov_b32_e32 v1, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v1
	ds_load_b128 v[18:21], v1 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v2, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v17
	ds_load_b128 v[14:17], v1 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v2, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v21
	ds_load_b128 v[6:9], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v15
	v_dual_fmac_f32 v2, v10, v16 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v17 :: v_dual_and_b32 v1, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v7 :: v_dual_and_b32 v1, 0xffff0000, v13
	v_fmac_f32_e32 v2, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v9
	s_cbranch_scc1 .LBB1_152
; %bb.153:                              ; %.preheader.3
	v_mov_b32_e32 v1, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x5000
	global_store_b32 v[3:4], v2, off offset:1024
.LBB1_154:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v2, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x30000, v2
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v2
	ds_load_b128 v[18:21], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v1, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v17
	ds_load_b128 v[14:17], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v1, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v21
	ds_load_b128 v[6:9], v2 offset:48
	v_and_b32_e32 v2, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v18, v14
	v_fmac_f32_e32 v1, v2, v15
	v_and_b32_e32 v2, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v10, v16
	v_dual_fmac_f32 v1, v2, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v10, v6 :: v_dual_and_b32 v2, 0xffff0000, v12
	v_dual_fmac_f32 v1, v2, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v8 :: v_dual_and_b32 v2, 0xffff0000, v13
	v_fmac_f32_e32 v1, v2, v9
	s_cbranch_scc1 .LBB1_154
; %bb.155:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_156:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x30000, v2
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v2
	ds_load_b128 v[18:21], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v1, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v17
	ds_load_b128 v[14:17], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v1, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v21
	ds_load_b128 v[6:9], v2 offset:48
	v_and_b32_e32 v2, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v18, v14
	v_fmac_f32_e32 v1, v2, v15
	v_and_b32_e32 v2, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v10, v16
	v_dual_fmac_f32 v1, v2, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v10, v6 :: v_dual_and_b32 v2, 0xffff0000, v12
	v_dual_fmac_f32 v1, v2, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v8 :: v_dual_and_b32 v2, 0xffff0000, v13
	v_fmac_f32_e32 v1, v2, v9
	s_cbranch_scc1 .LBB1_156
; %bb.157:                              ; %.preheader.4
	v_mov_b32_e32 v2, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x5000
	global_store_b32 v[3:4], v1, off offset:1536
.LBB1_158:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v1, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x40000, v1
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	v_mov_b32_e32 v1, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v1
	ds_load_b128 v[18:21], v1 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v2, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v17
	ds_load_b128 v[14:17], v1 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v2, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v21
	ds_load_b128 v[6:9], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v15
	v_dual_fmac_f32 v2, v10, v16 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v17 :: v_dual_and_b32 v1, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v7 :: v_dual_and_b32 v1, 0xffff0000, v13
	v_fmac_f32_e32 v2, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v9
	s_cbranch_scc1 .LBB1_158
; %bb.159:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_160:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x40000, v1
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	v_mov_b32_e32 v1, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v1
	ds_load_b128 v[18:21], v1 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v2, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v17
	ds_load_b128 v[14:17], v1 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v2, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v21
	ds_load_b128 v[6:9], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v15
	v_dual_fmac_f32 v2, v10, v16 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v17 :: v_dual_and_b32 v1, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v7 :: v_dual_and_b32 v1, 0xffff0000, v13
	v_fmac_f32_e32 v2, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v9
	s_cbranch_scc1 .LBB1_160
; %bb.161:                              ; %.preheader.5
	v_mov_b32_e32 v1, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x5000
	global_store_b32 v[3:4], v2, off offset:2048
.LBB1_162:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v2, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x50000, v2
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v2
	ds_load_b128 v[18:21], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v1, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v17
	ds_load_b128 v[14:17], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v1, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v21
	ds_load_b128 v[6:9], v2 offset:48
	v_and_b32_e32 v2, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v18, v14
	v_fmac_f32_e32 v1, v2, v15
	v_and_b32_e32 v2, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v10, v16
	v_dual_fmac_f32 v1, v2, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v10, v6 :: v_dual_and_b32 v2, 0xffff0000, v12
	v_dual_fmac_f32 v1, v2, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v8 :: v_dual_and_b32 v2, 0xffff0000, v13
	v_fmac_f32_e32 v1, v2, v9
	s_cbranch_scc1 .LBB1_162
; %bb.163:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_164:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x50000, v2
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v2
	ds_load_b128 v[18:21], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v1, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v17
	ds_load_b128 v[14:17], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v1, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v21
	ds_load_b128 v[6:9], v2 offset:48
	v_and_b32_e32 v2, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v18, v14
	v_fmac_f32_e32 v1, v2, v15
	v_and_b32_e32 v2, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v10, v16
	v_dual_fmac_f32 v1, v2, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v10, v6 :: v_dual_and_b32 v2, 0xffff0000, v12
	v_dual_fmac_f32 v1, v2, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v8 :: v_dual_and_b32 v2, 0xffff0000, v13
	v_fmac_f32_e32 v1, v2, v9
	s_cbranch_scc1 .LBB1_164
; %bb.165:                              ; %.preheader.6
	v_mov_b32_e32 v2, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x5000
	global_store_b32 v[3:4], v1, off offset:2560
.LBB1_166:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v1, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x60000, v1
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	v_mov_b32_e32 v1, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v1
	ds_load_b128 v[18:21], v1 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v2, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v17
	ds_load_b128 v[14:17], v1 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v2, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v21
	ds_load_b128 v[6:9], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v15
	v_dual_fmac_f32 v2, v10, v16 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v17 :: v_dual_and_b32 v1, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v7 :: v_dual_and_b32 v1, 0xffff0000, v13
	v_fmac_f32_e32 v2, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v9
	s_cbranch_scc1 .LBB1_166
; %bb.167:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_168:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x60000, v1
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	v_mov_b32_e32 v1, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	ds_load_b128 v[14:17], v1
	ds_load_b128 v[18:21], v1 offset:16
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v22, v14
	v_lshlrev_b32_e32 v14, 16, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v2, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v2, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v17
	ds_load_b128 v[14:17], v1 offset:32
	v_and_b32_e32 v6, 0xffff0000, v8
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v2, v7, v18 :: v_dual_lshlrev_b32 v7, 16, v9
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, v6, v19
	v_and_b32_e32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v2, v7, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v6, v21
	ds_load_b128 v[6:9], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v2, v18, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v15
	v_dual_fmac_f32 v2, v10, v16 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v17 :: v_dual_and_b32 v1, 0xffff0000, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, v10, v6
	v_lshlrev_b32_e32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, v1, v7 :: v_dual_and_b32 v1, 0xffff0000, v13
	v_fmac_f32_e32 v2, v6, v8
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, v1, v9
	s_cbranch_scc1 .LBB1_168
; %bb.169:                              ; %.preheader.7
	v_mov_b32_e32 v1, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x5000
	global_store_b32 v[3:4], v2, off offset:3072
.LBB1_170:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v2, vcc_lo, v0, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x70000, v2
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off
	global_load_b128 v[10:13], v[10:11], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v2
	ds_load_b128 v[18:21], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v1, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v17
	ds_load_b128 v[14:17], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v1, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v21
	ds_load_b128 v[6:9], v2 offset:48
	v_and_b32_e32 v2, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v18, v14
	v_fmac_f32_e32 v1, v2, v15
	v_and_b32_e32 v2, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v10, v16
	v_dual_fmac_f32 v1, v2, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v10, v6 :: v_dual_and_b32 v2, 0xffff0000, v12
	v_dual_fmac_f32 v1, v2, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v8 :: v_dual_and_b32 v2, 0xffff0000, v13
	v_fmac_f32_e32 v1, v2, v9
	s_cbranch_scc1 .LBB1_170
; %bb.171:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x5200
	s_mov_b64 s[0:1], 0
.LBB1_172:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, vcc_lo, v0, s0
	v_add_co_ci_u32_e64 v6, null, s1, v5, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x70000, v2
	v_add_co_ci_u32_e64 v11, null, 0, v6, vcc_lo
	s_clause 0x1
	global_load_b128 v[6:9], v[10:11], off offset:256
	global_load_b128 v[10:13], v[10:11], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v6
	v_mov_b32_e32 v2, s2
	s_add_i32 s2, s2, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[14:17], v2
	ds_load_b128 v[18:21], v2 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v22, v14 :: v_dual_lshlrev_b32 v14, 16, v7
	v_and_b32_e32 v6, 0xffff0000, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v6, v15
	v_and_b32_e32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	v_fmac_f32_e32 v1, v14, v16
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v17
	ds_load_b128 v[14:17], v2 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v7, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v18, 16, v10
	v_and_b32_e32 v6, 0xffff0000, v8
	v_lshlrev_b32_e32 v7, 16, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v19 :: v_dual_and_b32 v6, 0xffff0000, v9
	v_fmac_f32_e32 v1, v7, v20
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v6, v21
	ds_load_b128 v[6:9], v2 offset:48
	v_and_b32_e32 v2, 0xffff0000, v10
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v18, v14
	v_fmac_f32_e32 v1, v2, v15
	v_and_b32_e32 v2, 0xffff0000, v11
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v10, v16
	v_dual_fmac_f32 v1, v2, v17 :: v_dual_lshlrev_b32 v10, 16, v12
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v10, v6 :: v_dual_and_b32 v2, 0xffff0000, v12
	v_dual_fmac_f32 v1, v2, v7 :: v_dual_lshlrev_b32 v6, 16, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, v6, v8 :: v_dual_and_b32 v2, 0xffff0000, v13
	v_fmac_f32_e32 v1, v2, v9
	s_cbranch_scc1 .LBB1_172
; %bb.173:                              ; %.loopexit.loopexit
	global_store_b32 v[3:4], v1, off offset:3584
.LBB1_174:                              ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z5queryILi1EEvPKhPKfPKtPfiiii
		.amdhsa_group_segment_fixed_size 22112
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 48
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
		.amdhsa_next_free_sgpr 46
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
	.section	.text._Z5queryILi1EEvPKhPKfPKtPfiiii,"axG",@progbits,_Z5queryILi1EEvPKhPKfPKtPfiiii,comdat
.Lfunc_end1:
	.size	_Z5queryILi1EEvPKhPKfPKtPfiiii, .Lfunc_end1-_Z5queryILi1EEvPKhPKfPKtPfiiii
                                        ; -- End function
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.num_vgpr, 36
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.num_agpr, 0
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.numbered_sgpr, 46
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.num_named_barrier, 0
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.private_seg_size, 0
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.uses_vcc, 1
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.uses_flat_scratch, 0
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.has_dyn_sized_stack, 0
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.has_recursion, 0
	.set _Z5queryILi1EEvPKhPKfPKtPfiiii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 16452
; TotalNumSgprs: 48
; NumVgprs: 36
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 22112 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 48
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
	.section	.AMDGPU.gpr_maximums,"",@progbits
	.set amdgpu.max_num_vgpr, 0
	.set amdgpu.max_num_agpr, 0
	.set amdgpu.max_num_sgpr, 0
	.section	.AMDGPU.csdata,"",@progbits
	.type	__hip_cuid_8294531b7e96a57,@object ; @__hip_cuid_8294531b7e96a57
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_8294531b7e96a57
__hip_cuid_8294531b7e96a57:
	.byte	0                               ; 0x0
	.size	__hip_cuid_8294531b7e96a57, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __hip_cuid_8294531b7e96a57
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
      - .offset:         32
        .size:           4
        .value_kind:     by_value
      - .offset:         36
        .size:           4
        .value_kind:     by_value
      - .offset:         40
        .size:           4
        .value_kind:     by_value
      - .offset:         44
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 5632
    .kernarg_segment_align: 8
    .kernarg_segment_size: 48
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z5queryILi0EEvPKhPKfPKtPfiiii
    .private_segment_fixed_size: 0
    .sgpr_count:     48
    .sgpr_spill_count: 0
    .symbol:         _Z5queryILi0EEvPKhPKfPKtPfiiii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     23
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
      - .offset:         32
        .size:           4
        .value_kind:     by_value
      - .offset:         36
        .size:           4
        .value_kind:     by_value
      - .offset:         40
        .size:           4
        .value_kind:     by_value
      - .offset:         44
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 22112
    .kernarg_segment_align: 8
    .kernarg_segment_size: 48
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z5queryILi1EEvPKhPKfPKtPfiiii
    .private_segment_fixed_size: 0
    .sgpr_count:     48
    .sgpr_spill_count: 0
    .symbol:         _Z5queryILi1EEvPKhPKfPKtPfiiii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     36
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
