	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.protected	_Z8finish_oPKfPf        ; -- Begin function _Z8finish_oPKfPf
	.globl	_Z8finish_oPKfPf
	.p2align	8
	.type	_Z8finish_oPKfPf,@function
_Z8finish_oPKfPf:                       ; @_Z8finish_oPKfPf
; %bb.0:
	s_load_b32 s3, s[0:1], 0x1c
	s_waitcnt lgkmcnt(0)
	s_and_b32 s3, s3, 0xffff
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mad_u64_u32 v[0:1], null, s2, s3, v[0:1]
	s_mov_b32 s2, exec_lo
	v_cmpx_gt_i32_e32 0x400, v0
	s_cbranch_execz .LBB0_2
; %bb.1:                                ; %.preheader.preheader
	s_load_b128 s[0:3], s[0:1], 0x0
	v_ashrrev_i32_e32 v1, 31, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v2, vcc_lo, s0, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v3, null, s1, v1, vcc_lo
	v_add_co_u32 v4, vcc_lo, v2, 0x2000
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	v_add_co_u32 v6, vcc_lo, v2, 0x4000
	s_clause 0x1
	global_load_b32 v8, v[2:3], off
	global_load_b32 v9, v[4:5], off offset:-4096
	v_add_co_ci_u32_e64 v7, null, 0, v3, vcc_lo
	s_clause 0x1
	global_load_b32 v10, v[4:5], off
	global_load_b32 v11, v[6:7], off offset:-4096
	v_add_co_u32 v4, vcc_lo, v2, 0x6000
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	s_clause 0x1
	global_load_b32 v6, v[6:7], off
	global_load_b32 v7, v[4:5], off offset:-4096
	v_add_co_u32 v2, vcc_lo, 0x7000, v2
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
	s_clause 0x1
	global_load_b32 v4, v[4:5], off
	global_load_b32 v2, v[2:3], off
	v_add_co_u32 v0, vcc_lo, s2, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s3, v1, vcc_lo
	s_waitcnt vmcnt(7)
	v_add_f32_e32 v3, 0, v8
	s_waitcnt vmcnt(6)
	v_add_f32_e32 v3, v3, v9
	s_waitcnt vmcnt(5)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v3, v3, v10
	s_waitcnt vmcnt(4)
	v_add_f32_e32 v3, v3, v11
	s_waitcnt vmcnt(3)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v3, v3, v6
	s_waitcnt vmcnt(2)
	v_add_f32_e32 v3, v3, v7
	s_waitcnt vmcnt(1)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v3, v3, v4
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v2, v3, v2
	global_store_b32 v[0:1], v2, off
.LBB0_2:
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z8finish_oPKfPf
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
		.amdhsa_next_free_vgpr 12
		.amdhsa_next_free_sgpr 4
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
	.text
.Lfunc_end0:
	.size	_Z8finish_oPKfPf, .Lfunc_end0-_Z8finish_oPKfPf
                                        ; -- End function
	.set _Z8finish_oPKfPf.num_vgpr, 12
	.set _Z8finish_oPKfPf.num_agpr, 0
	.set _Z8finish_oPKfPf.numbered_sgpr, 4
	.set _Z8finish_oPKfPf.num_named_barrier, 0
	.set _Z8finish_oPKfPf.private_seg_size, 0
	.set _Z8finish_oPKfPf.uses_vcc, 1
	.set _Z8finish_oPKfPf.uses_flat_scratch, 0
	.set _Z8finish_oPKfPf.has_dyn_sized_stack, 0
	.set _Z8finish_oPKfPf.has_recursion, 0
	.set _Z8finish_oPKfPf.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 372
; TotalNumSgprs: 6
; NumVgprs: 12
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 6
; NumVGPRsForWavesPerEU: 12
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z11query_groupILi0EEvPKhPKfPKtPf,"axG",@progbits,_Z11query_groupILi0EEvPKhPKfPKtPf,comdat
	.protected	_Z11query_groupILi0EEvPKhPKfPKtPf ; -- Begin function _Z11query_groupILi0EEvPKhPKfPKtPf
	.globl	_Z11query_groupILi0EEvPKhPKfPKtPf
	.p2align	8
	.type	_Z11query_groupILi0EEvPKhPKfPKtPf,@function
_Z11query_groupILi0EEvPKhPKfPKtPf:      ; @_Z11query_groupILi0EEvPKhPKfPKtPf
; %bb.0:
	s_load_b256 s[12:19], s[0:1], 0x0
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_clause 0x1
	global_load_d16_u8 v2, v1, s[12:13] offset:4
	global_load_b32 v1, v1, s[12:13]
	s_waitcnt vmcnt(1)
	v_readfirstlane_b32 s0, v2
	s_waitcnt vmcnt(0)
	v_readfirstlane_b32 s1, v1
	s_and_b32 s25, s0, 0xff
	s_bfe_u32 s23, s1, 0x80008
	s_and_b32 s22, s1, 0xff
	s_lshl_b32 s24, s23, 8
	s_lshr_b32 s28, s1, 24
	s_or_b32 s26, s24, s22
	s_cmp_gt_i32 s2, 7
	v_sub_nc_u32_e64 v1, s26, 33 clamp
	s_cselect_b32 s0, -1, 0
	s_add_i32 s3, s26, 0xfffffeff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	s_cmp_lt_u32 s3, 0xffffff00
	v_sub_nc_u32_e32 v2, s26, v1
	s_cselect_b32 s3, -1, 0
	s_bfe_u32 s1, s1, 0x80010
	s_or_b32 s3, s0, s3
	s_cmp_lg_u32 s1, 0
	v_cmp_gt_u32_e32 vcc_lo, s28, v1
	s_cselect_b32 s1, -1, 0
	v_cmp_gt_i32_e64 s0, s25, v2
	s_or_b32 s1, s3, s1
	v_readfirstlane_b32 s27, v1
	s_or_b32 s1, s1, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s0, s1, s0
	s_and_b32 vcc_lo, exec_lo, s0
	s_cbranch_vccnz .LBB1_164
; %bb.1:                                ; %.preheader257
	s_add_i32 s0, s26, -1
	v_lshlrev_b32_e32 v1, 7, v0
	s_lshr_b32 s1, s0, 27
	v_lshl_add_u32 v4, v0, 2, 0x800
	s_add_i32 s0, s0, s1
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v5, 0xf80, v1
	s_and_b32 s35, s0, 0xffffffe0
	s_ashr_i32 s30, s0, 5
	s_sub_i32 s0, s26, s35
	s_mul_i32 s34, s30, 0x600
	s_lshl_b32 s29, s0, 8
	v_cmp_gt_u32_e64 s0, s26, v0
	s_add_i32 s29, s29, s34
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s1, s29, s2
	s_ashr_i32 s3, s1, 31
	s_add_u32 s31, s12, s1
	s_addc_u32 s33, s13, s3
	s_add_u32 s3, s31, s34
	s_addc_u32 s6, s33, 0
	s_lshl_b32 s10, s2, 8
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB1_9
; %bb.2:
                                        ; implicit-def: $vgpr1
	s_mov_b32 s4, exec_lo
	v_cmpx_le_u32_e64 s35, v0
	s_xor_b32 s7, exec_lo, s4
	s_cbranch_execz .LBB1_5
; %bb.3:                                ; %.preheader255
	v_subrev_nc_u32_e32 v1, s35, v0
	s_ashr_i32 s11, s10, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b64 s[4:5], s[10:11], 2
	s_add_u32 s4, s14, s4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 8, v1
	s_addc_u32 s5, s15, s5
	v_add_co_u32 v2, s8, s3, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s6, 0, s8
	s_add_u32 s8, s4, 28
	s_addc_u32 s9, s5, 0
	s_mov_b64 s[4:5], 0
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_4:                                ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v6, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v7, null, s5, v3, vcc_lo
	s_add_u32 s20, s8, 0xffffffe4
	s_addc_u32 s21, s9, -1
	s_add_u32 s4, s4, 16
	global_load_b128 v[6:9], v[6:7], off offset:5
	s_load_b256 s[36:43], s[20:21], 0x0
	s_addc_u32 s5, s5, 0
	s_add_u32 s8, s8, 32
	s_addc_u32 s9, s9, 0
	s_cmpk_lg_i32 s4, 0x100
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v10, 16, v6
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s36, v10 :: v_dual_lshlrev_b32 v10, 16, v7
	v_dual_fmac_f32 v1, s37, v6 :: v_dual_and_b32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s38, v10
	v_dual_fmac_f32 v1, s39, v6 :: v_dual_and_b32 v6, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, s40, v7
	v_lshlrev_b32_e32 v7, 16, v9
	v_dual_fmac_f32 v1, s41, v6 :: v_dual_and_b32 v6, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s42, v7
	v_fmac_f32_e32 v1, s43, v6
	s_cbranch_scc1 .LBB1_4
.LBB1_5:                                ; %Flow2274
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s7, s7
	s_cbranch_execz .LBB1_8
; %bb.6:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s11, s10, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	s_lshl_b64 s[4:5], s[10:11], 2
	s_mov_b32 s11, 0
	v_mul_u32_u24_e32 v2, 0x600, v1
	v_mov_b32_e32 v1, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s8, s31, v2
	v_add_co_ci_u32_e64 v3, null, s33, 0, s8
	s_add_u32 s8, s14, s4
	s_addc_u32 s9, s15, s5
	s_mov_b64 s[4:5], 0
.LBB1_7:                                ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v6, s11, v5
	s_add_u32 s20, s8, s4
	s_addc_u32 s21, s9, s5
	s_add_i32 s11, s11, 4
	s_load_b128 s[36:39], s[20:21], 0x0
	v_lshrrev_b32_e32 v6, 2, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v6, vcc_lo, v2, v6
	v_add_co_ci_u32_e64 v7, null, 0, v3, vcc_lo
	global_load_d16_u8 v10, v[6:7], off offset:5
	v_add_co_u32 v6, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v7, null, s5, v3, vcc_lo
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x200
	global_load_b128 v[6:9], v[6:7], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v12.l, v10.l, 3
	v_lshrrev_b16 v10.h, 2, v10.l
	v_lshrrev_b16 v11.l, 4, v10.l
	v_lshrrev_b16 v10.l, 6, v10.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v12, v12
	v_and_b16 v13.l, v10.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_and_b16 v11.l, v11.l, 3
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v6, v6, v12, v6 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v12, v13
	v_cvt_f32_ubyte0_e32 v11, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, s36, v6
	v_fma_mix_f32 v6, v7, v12, v7 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v7, v10
	v_fma_mix_f32 v8, v8, v11, v8 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, s37, v6
	v_fma_mix_f32 v6, v9, v7, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s38, v8
	v_fmac_f32_e32 v1, s39, v6
	s_cbranch_scc0 .LBB1_7
.LBB1_8:                                ; %Flow2275
	s_or_b32 exec_lo, exec_lo, s7
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v1
	ds_store_b32 v4, v1
.LBB1_9:                                ; %Flow2276
	s_or_b32 exec_lo, exec_lo, s1
	v_add_nc_u32_e32 v7, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_u32_e64 s1, s26, v7
	s_and_saveexec_b32 s7, s1
	s_cbranch_execz .LBB1_17
; %bb.10:
                                        ; implicit-def: $vgpr1
	s_mov_b32 s4, exec_lo
	v_cmpx_le_u32_e64 s35, v7
	s_xor_b32 s8, exec_lo, s4
	s_cbranch_execz .LBB1_13
; %bb.11:                               ; %.preheader255.1
	v_subrev_nc_u32_e32 v1, s35, v7
	s_ashr_i32 s11, s10, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b64 s[4:5], s[10:11], 2
	s_add_u32 s4, s14, s4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 8, v1
	s_addc_u32 s5, s15, s5
	v_add_co_u32 v2, s3, s3, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s6, 0, s3
	s_add_u32 s3, s4, 28
	s_addc_u32 s6, s5, 0
	s_mov_b64 s[4:5], 0
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_12:                               ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v8, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s5, v3, vcc_lo
	s_add_u32 s20, s3, 0xffffffe4
	s_addc_u32 s21, s6, -1
	s_add_u32 s4, s4, 16
	global_load_b128 v[8:11], v[8:9], off offset:5
	s_load_b256 s[36:43], s[20:21], 0x0
	s_addc_u32 s5, s5, 0
	s_add_u32 s3, s3, 32
	s_addc_u32 s6, s6, 0
	s_cmpk_eq_i32 s4, 0x100
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s36, v6 :: v_dual_and_b32 v8, 0xffff0000, v8
	v_dual_fmac_f32 v1, s37, v8 :: v_dual_lshlrev_b32 v6, 16, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s38, v6 :: v_dual_and_b32 v8, 0xffff0000, v9
	v_dual_fmac_f32 v1, s39, v8 :: v_dual_lshlrev_b32 v6, 16, v10
	v_and_b32_e32 v8, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s40, v6 :: v_dual_lshlrev_b32 v6, 16, v11
	v_dual_fmac_f32 v1, s41, v8 :: v_dual_and_b32 v8, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s42, v6
	v_fmac_f32_e32 v1, s43, v8
	s_cbranch_scc0 .LBB1_12
.LBB1_13:                               ; %Flow2269
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s3, s8
	s_cbranch_execz .LBB1_16
; %bb.14:
	v_lshrrev_b32_e32 v1, 5, v7
	s_ashr_i32 s11, s10, 31
	s_mov_b32 s9, 0
	s_lshl_b64 s[4:5], s[10:11], 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_u32_u24_e32 v2, 0x600, v1
	v_mov_b32_e32 v1, 0
	v_add_co_u32 v2, s6, s31, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s33, 0, s6
	s_add_u32 s6, s14, s4
	s_addc_u32 s8, s15, s5
	s_mov_b64 s[4:5], 0
.LBB1_15:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v6, s9, v5
	s_add_u32 s20, s6, s4
	s_addc_u32 s21, s8, s5
	s_add_i32 s9, s9, 4
	s_load_b128 s[36:39], s[20:21], 0x0
	v_lshrrev_b32_e32 v6, 2, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, v2, v6
	v_add_co_ci_u32_e64 v9, null, 0, v3, vcc_lo
	global_load_d16_u8 v6, v[8:9], off offset:5
	v_add_co_u32 v8, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s5, v3, vcc_lo
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x200
	global_load_b128 v[8:11], v[8:9], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v13.l, v6.l, 3
	v_lshrrev_b16 v6.h, 2, v6.l
	v_lshrrev_b16 v12.l, 4, v6.l
	v_lshrrev_b16 v6.l, 6, v6.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v13, v13
	v_and_b16 v14.l, v6.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v12.l, v12.l, 3
	v_cvt_f32_ubyte0_e32 v6, v6
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v8, v13, v8 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v13, v14
	v_cvt_f32_ubyte0_e32 v12, v12
	v_fma_mix_f32 v6, v11, v6, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v1, s36, v8
	v_fma_mix_f32 v8, v9, v13, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v9, v10, v12, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s37, v8
	v_fmac_f32_e32 v1, s38, v9
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, s39, v6
	s_cbranch_scc0 .LBB1_15
.LBB1_16:                               ; %Flow2270
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v1
	ds_store_b32 v4, v1 offset:512
.LBB1_17:                               ; %Flow2271
	s_or_b32 exec_lo, exec_lo, s7
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB1_19
; %bb.18:
	ds_load_b32 v1, v4
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB1_19:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB1_21
; %bb.20:
	ds_load_b32 v2, v4 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB1_21:
	s_or_b32 exec_lo, exec_lo, s3
	v_lshlrev_b32_e32 v3, 2, v0
	v_cmp_gt_u32_e64 s3, 64, v0
	s_delay_alu instid0(VALU_DEP_2)
	v_add_nc_u32_e32 v6, 0x1400, v3
	ds_store_b32 v3, v1 offset:5120
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB1_23
; %bb.22:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_23:
	s_or_b32 exec_lo, exec_lo, s4
	v_cmp_gt_u32_e64 s4, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB1_25
; %bb.24:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_25:
	s_or_b32 exec_lo, exec_lo, s5
	v_cmp_gt_u32_e64 s5, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s5
	s_cbranch_execz .LBB1_27
; %bb.26:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_27:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB1_29
; %bb.28:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_29:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB1_31
; %bb.30:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_31:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_gt_u32_e64 s8, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB1_33
; %bb.32:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_33:
	s_or_b32 exec_lo, exec_lo, s9
	v_cmp_eq_u32_e64 s9, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s9
	s_cbranch_execz .LBB1_35
; %bb.34:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_35:
	s_or_b32 exec_lo, exec_lo, s11
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s11, s0
	s_cbranch_execz .LBB1_37
; %bb.36:
	ds_load_b32 v1, v4
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v8, 0x3fb8aa3b, v1
	v_fma_f32 v9, 0x3fb8aa3b, v1, -v8
	v_rndne_f32_e32 v10, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v9, v1, 0x32a5705f, v9 :: v_dual_sub_f32 v8, v8, v10
	v_add_f32_e32 v8, v8, v9
	v_cvt_i32_f32_e32 v9, v10
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v8, v8
	v_ldexp_f32 v8, v8, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v8, 0, v8, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v1
	v_cndmask_b32_e32 v1, 0x7f800000, v8, vcc_lo
	ds_store_b32 v3, v1
.LBB1_37:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB1_39
; %bb.38:
	ds_load_b32 v8, v4 offset:512
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v8, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v8, 0x3fb8aa3b, v2
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v2
	v_fma_f32 v9, 0x3fb8aa3b, v2, -v8
	v_rndne_f32_e32 v10, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v9, v2, 0x32a5705f, v9 :: v_dual_sub_f32 v8, v8, v10
	v_add_f32_e32 v8, v8, v9
	v_cvt_i32_f32_e32 v9, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v8, v8
	v_ldexp_f32 v8, v8, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v8, 0, v8, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v2
	v_cndmask_b32_e32 v2, 0x7f800000, v8, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v1, v2
	ds_store_b32 v3, v2 offset:512
.LBB1_39:
	s_or_b32 exec_lo, exec_lo, s11
	ds_store_b32 v6, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s3
	s_cbranch_execz .LBB1_41
; %bb.40:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_41:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s4
	s_cbranch_execz .LBB1_43
; %bb.42:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_43:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s5
	s_cbranch_execz .LBB1_45
; %bb.44:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_45:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s6
	s_cbranch_execz .LBB1_47
; %bb.46:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_47:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s7
	s_cbranch_execz .LBB1_49
; %bb.48:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_49:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s8
	s_cbranch_execz .LBB1_51
; %bb.50:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_51:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s9
	s_cbranch_execz .LBB1_53
; %bb.52:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_53:
	s_or_b32 exec_lo, exec_lo, s11
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s11, s0
	s_cbranch_execz .LBB1_55
; %bb.54:
	ds_load_b32 v2, v3
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v8, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v9, v8
	v_fma_f32 v10, -v8, v9, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, v10, v9
	v_div_scale_f32 v10, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v11, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v8, v11, v10
	v_fmac_f32_e32 v11, v12, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v8, v11, v10
	v_div_fmas_f32 v8, v8, v9, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v8, v1, v2
	ds_store_b32 v3, v2
.LBB1_55:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB1_57
; %bb.56:
	ds_load_b32 v2, v3 offset:512
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v8, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v9, v8
	v_fma_f32 v10, -v8, v9, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, v10, v9
	v_div_scale_f32 v10, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v11, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v8, v11, v10
	v_fmac_f32_e32 v11, v12, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v8, v11, v10
	v_div_fmas_f32 v8, v8, v9, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v1, v8, v1, v2
	ds_store_b32 v3, v1 offset:512
.LBB1_57:                               ; %.preheader257.1
	s_or_b32 exec_lo, exec_lo, s11
	s_mulk_i32 s30, 0x1a00
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s36, s0
	s_cbranch_execz .LBB1_65
; %bb.58:
                                        ; implicit-def: $vgpr8
	s_mov_b32 s11, exec_lo
	v_cmpx_le_u32_e64 s35, v0
	s_xor_b32 s37, exec_lo, s11
	s_cbranch_execz .LBB1_61
; %bb.59:                               ; %.preheader255.1300
	s_ashr_i32 s11, s10, 31
	v_subrev_nc_u32_e32 v1, s35, v0
	s_lshl_b64 s[20:21], s[10:11], 2
	v_mov_b32_e32 v8, 0
	s_add_u32 s11, s14, s20
	s_addc_u32 s38, s15, s21
	s_lshl_b32 s20, s23, 16
	s_lshl_b32 s21, s22, 8
	v_lshlrev_b32_e32 v1, 8, v1
	s_or_b32 s20, s20, s21
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s20, s20, s30
	s_mul_i32 s20, s2, s20
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s21, s20, 31
	s_add_u32 s39, s12, s34
	s_addc_u32 s40, s13, 0
	s_add_u32 s20, s39, s20
	s_addc_u32 s21, s40, s21
	v_add_co_u32 v1, s20, s20, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s21, 0, s20
	s_mov_b64 s[20:21], 0
	v_add_co_u32 v1, vcc_lo, v1, 19
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_60:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[9:12], v[1:2], off offset:-14
	s_add_u32 s40, s11, s20
	s_addc_u32 s41, s38, s21
	v_add_co_u32 v1, vcc_lo, v1, 16
	s_load_b256 s[40:47], s[40:41], 0x200
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_u32 s20, s20, 32
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v9
	v_and_b32_e32 v9, 0xffff0000, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s40, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_dual_fmac_f32 v8, s41, v9 :: v_dual_and_b32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s42, v13
	v_dual_fmac_f32 v8, s43, v9 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v8, s44, v10
	v_lshlrev_b32_e32 v10, 16, v12
	v_dual_fmac_f32 v8, s45, v9 :: v_dual_and_b32 v9, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s46, v10
	v_fmac_f32_e32 v8, s47, v9
	s_cbranch_scc0 .LBB1_60
.LBB1_61:                               ; %Flow2264
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s37, s37
	s_cbranch_execz .LBB1_64
; %bb.62:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s11, s10, 31
	v_mov_b32_e32 v8, 0
	s_lshl_b64 s[20:21], s[10:11], 2
	s_mov_b32 s39, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s11, s31, v1
	v_add_co_ci_u32_e64 v2, null, s33, 0, s11
	s_add_u32 s11, s14, s20
	s_addc_u32 s38, s15, s21
	s_mov_b64 s[20:21], 0
.LBB1_63:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v9, s39, v5
	s_add_u32 s40, s11, s20
	s_addc_u32 s41, s38, s21
	s_add_i32 s39, s39, 4
	s_load_b128 s[40:43], s[40:41], 0x200
	v_lshrrev_b32_e32 v9, 2, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v1, v9
	v_add_co_ci_u32_e64 v10, null, 0, v2, vcc_lo
	global_load_d16_u8 v13, v[9:10], off offset:5
	v_add_co_u32 v9, vcc_lo, v1, s20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s21, v2, vcc_lo
	s_add_u32 s20, s20, 16
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	global_load_b128 v[9:12], v[9:10], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v15.l, v13.l, 3
	v_lshrrev_b16 v13.h, 2, v13.l
	v_lshrrev_b16 v14.l, 4, v13.l
	v_lshrrev_b16 v13.l, 6, v13.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v15, v15
	v_and_b16 v16.l, v13.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_and_b16 v14.l, v14.l, 3
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v15, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v15, v16
	v_cvt_f32_ubyte0_e32 v14, v14
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v8, s40, v9
	v_fma_mix_f32 v9, v10, v15, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v10, v13
	v_fma_mix_f32 v11, v11, v14, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v8, s41, v9
	v_fma_mix_f32 v9, v12, v10, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s42, v11
	v_fmac_f32_e32 v8, s43, v9
	s_cbranch_scc0 .LBB1_63
.LBB1_64:                               ; %Flow2265
	s_or_b32 exec_lo, exec_lo, s37
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v8
	ds_store_b32 v4, v1 offset:1024
.LBB1_65:                               ; %Flow2266
	s_or_b32 exec_lo, exec_lo, s36
	s_and_saveexec_b32 s36, s1
	s_cbranch_execz .LBB1_74
; %bb.66:
                                        ; implicit-def: $vgpr8
	s_mov_b32 s11, exec_lo
	v_cmpx_le_u32_e64 s35, v7
	s_xor_b32 s37, exec_lo, s11
	s_cbranch_execz .LBB1_70
; %bb.67:                               ; %.preheader255.1.1
	s_ashr_i32 s11, s10, 31
	v_subrev_nc_u32_e32 v1, s35, v7
	s_lshl_b64 s[20:21], s[10:11], 2
	v_mov_b32_e32 v8, 0
	s_add_u32 s11, s14, s20
	s_addc_u32 s38, s15, s21
	s_lshl_b32 s20, s23, 16
	s_lshl_b32 s21, s22, 8
	v_lshlrev_b32_e32 v1, 8, v1
	s_or_b32 s20, s20, s21
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s20, s20, s30
	s_mul_i32 s20, s2, s20
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s21, s20, 31
	s_add_u32 s34, s12, s34
	s_addc_u32 s35, s13, 0
	s_add_u32 s20, s34, s20
	s_addc_u32 s21, s35, s21
	v_add_co_u32 v1, s20, s20, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s21, 0, s20
	s_mov_b64 s[20:21], 0
	v_add_co_u32 v1, vcc_lo, v1, 19
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_68:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[9:12], v[1:2], off offset:-14
	s_add_u32 s34, s11, s20
	s_addc_u32 s35, s38, s21
	v_add_co_u32 v1, vcc_lo, v1, 16
	s_load_b256 s[40:47], s[34:35], 0x200
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_u32 s20, s20, 32
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v5, 16, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s40, v5 :: v_dual_lshlrev_b32 v5, 16, v10
	v_dual_fmac_f32 v8, s41, v7 :: v_dual_and_b32 v7, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s42, v5 :: v_dual_lshlrev_b32 v5, 16, v11
	v_fmac_f32_e32 v8, s43, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s44, v5 :: v_dual_and_b32 v7, 0xffff0000, v11
	v_dual_fmac_f32 v8, s45, v7 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s46, v5 :: v_dual_and_b32 v7, 0xffff0000, v12
	v_fmac_f32_e32 v8, s47, v7
	s_cbranch_scc0 .LBB1_68
; %bb.69:                               ; %Flow2257
	s_set_inst_prefetch_distance 0x2
                                        ; implicit-def: $vgpr5
                                        ; implicit-def: $vgpr7
.LBB1_70:                               ; %Flow2259
	s_and_not1_saveexec_b32 s20, s37
	s_cbranch_execz .LBB1_73
; %bb.71:
	v_lshrrev_b32_e32 v1, 5, v7
	s_ashr_i32 s11, s10, 31
	v_mov_b32_e32 v8, 0
	s_lshl_b64 s[34:35], s[10:11], 2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_u32_u24_e32 v1, 0x600, v1
	v_add_co_u32 v1, s11, s31, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s33, 0, s11
	s_add_u32 s11, s14, s34
	s_addc_u32 s21, s15, s35
	s_mov_b32 s31, 0
	s_mov_b64 s[14:15], 0
.LBB1_72:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v7, s31, v5
	s_add_u32 s34, s11, s14
	s_addc_u32 s35, s21, s15
	s_add_i32 s31, s31, 4
	s_load_b128 s[40:43], s[34:35], 0x200
	v_lshrrev_b32_e32 v7, 2, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v1, v7
	v_add_co_ci_u32_e64 v10, null, 0, v2, vcc_lo
	global_load_d16_u8 v7, v[9:10], off offset:5
	v_add_co_u32 v9, vcc_lo, v1, s14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s15, v2, vcc_lo
	s_add_u32 s14, s14, 16
	s_addc_u32 s15, s15, 0
	s_cmpk_eq_i32 s14, 0x200
	global_load_b128 v[9:12], v[9:10], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v14.l, v7.l, 3
	v_lshrrev_b16 v7.h, 2, v7.l
	v_lshrrev_b16 v13.l, 4, v7.l
	v_lshrrev_b16 v7.l, 6, v7.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v14, v14
	v_and_b16 v15.l, v7.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v13.l, v13.l, 3
	v_cvt_f32_ubyte0_e32 v7, v7
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v14, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v14, v15
	v_cvt_f32_ubyte0_e32 v13, v13
	v_fma_mix_f32 v7, v12, v7, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v8, s40, v9
	v_fma_mix_f32 v9, v10, v14, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v10, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s41, v9
	v_fmac_f32_e32 v8, s42, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, s43, v7
	s_cbranch_scc0 .LBB1_72
.LBB1_73:                               ; %Flow2260
	s_or_b32 exec_lo, exec_lo, s20
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v8
	ds_store_b32 v4, v1 offset:1536
.LBB1_74:                               ; %Flow2261
	s_or_b32 exec_lo, exec_lo, s36
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s0
	s_cbranch_execz .LBB1_76
; %bb.75:
	ds_load_b32 v1, v4 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB1_76:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB1_78
; %bb.77:
	ds_load_b32 v2, v4 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB1_78:
	s_or_b32 exec_lo, exec_lo, s11
	ds_store_b32 v6, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s3
	s_cbranch_execz .LBB1_80
; %bb.79:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_80:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s4
	s_cbranch_execz .LBB1_82
; %bb.81:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_82:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s5
	s_cbranch_execz .LBB1_84
; %bb.83:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_84:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s6
	s_cbranch_execz .LBB1_86
; %bb.85:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_86:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s7
	s_cbranch_execz .LBB1_88
; %bb.87:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_88:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s8
	s_cbranch_execz .LBB1_90
; %bb.89:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_90:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s9
	s_cbranch_execz .LBB1_92
; %bb.91:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB1_92:
	s_or_b32 exec_lo, exec_lo, s11
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s11, s0
	s_cbranch_execz .LBB1_94
; %bb.93:
	ds_load_b32 v1, v4 offset:1024
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v5, 0x3fb8aa3b, v1
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v1
	v_fma_f32 v7, 0x3fb8aa3b, v1, -v5
	v_rndne_f32_e32 v8, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmamk_f32 v7, v1, 0x32a5705f, v7
	v_sub_f32_e32 v5, v5, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add_f32_e32 v5, v5, v7
	v_cvt_i32_f32_e32 v7, v8
	v_exp_f32_e32 v5, v5
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ldexp_f32 v5, v5, v7
	v_cndmask_b32_e32 v5, 0, v5, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v1
	s_delay_alu instid0(VALU_DEP_2)
	v_cndmask_b32_e32 v1, 0x7f800000, v5, vcc_lo
	ds_store_b32 v3, v1 offset:1024
.LBB1_94:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB1_96
; %bb.95:
	ds_load_b32 v4, v4 offset:1536
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v4, v2
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
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v1, v2
	ds_store_b32 v3, v2 offset:1536
.LBB1_96:
	s_or_b32 exec_lo, exec_lo, s11
	ds_store_b32 v6, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s3
	s_cbranch_execz .LBB1_98
; %bb.97:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_98:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s4
	s_cbranch_execz .LBB1_100
; %bb.99:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_100:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s5
	s_cbranch_execz .LBB1_102
; %bb.101:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_102:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s6
	s_cbranch_execz .LBB1_104
; %bb.103:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_104:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s7
	s_cbranch_execz .LBB1_106
; %bb.105:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_106:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s8
	s_cbranch_execz .LBB1_108
; %bb.107:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_108:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s9
	s_cbranch_execz .LBB1_110
; %bb.109:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB1_110:
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB1_112
; %bb.111:
	ds_load_b32 v2, v3 offset:1024
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v6, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v5
	v_div_scale_f32 v6, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v7, v6, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v4, v7, v6
	v_fmac_f32_e32 v7, v8, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v7, v6
	v_div_fmas_f32 v4, v4, v5, v7
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v4, v1, v2
	ds_store_b32 v3, v2 offset:1024
.LBB1_112:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB1_114
; %bb.113:
	ds_load_b32 v2, v3 offset:1536
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v6, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v5
	v_div_scale_f32 v6, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v7, v6, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v4, v7, v6
	v_fmac_f32_e32 v7, v8, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v7, v6
	v_div_fmas_f32 v4, v4, v5, v7
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v1, v4, v1, v2
	ds_store_b32 v3, v1 offset:1536
.LBB1_114:                              ; %.preheader253
	s_or_b32 exec_lo, exec_lo, s0
	s_lshl_b32 s1, s29, 3
	v_dual_mov_b32 v5, 0 :: v_dual_lshlrev_b32 v6, 1, v0
	s_ashr_i32 s3, s1, 31
	v_lshrrev_b32_e32 v4, 3, v0
	s_add_u32 s6, s12, s1
	s_addc_u32 s7, s13, s3
	s_cmp_gt_u32 s26, 33
	s_mul_i32 s1, s2, 48
	s_cselect_b32 s5, -1, 0
	s_ashr_i32 s4, s1, 31
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 2, v0
	v_and_b32_e32 v2, 6, v6
	v_and_b32_e32 v4, 0x7c, v4
	s_add_u32 s3, s6, s1
	s_addc_u32 s4, s7, s4
	s_mulk_i32 s28, 0x180
	s_mov_b32 s0, 0
	s_cmp_lt_u32 s26, 34
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB1_122
; %bb.115:                              ; %.lr.ph.preheader
	s_cmp_lt_u32 s27, 4
	s_cbranch_scc1 .LBB1_119
; %bb.116:                              ; %.lr.ph.preheader.new
	s_lshl_b32 s0, s23, 16
	s_lshl_b32 s1, s22, 8
	v_mov_b32_e32 v7, 0
	s_or_b32 s0, s0, s1
	s_mov_b32 s11, 0
	s_sub_i32 s0, s0, s30
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b32 s0, s0, 3
	s_ashr_i32 s1, s0, 31
	s_add_u32 s0, s28, s0
	s_addc_u32 s1, 0, s1
	s_add_u32 s8, s12, s0
	s_addc_u32 s9, s13, s1
	s_add_i32 s0, s24, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e64 v5, s0, 33 clamp
	v_readfirstlane_b32 s0, v5
	v_mov_b32_e32 v5, 0
	s_max_u32 s0, s0, 1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s14, s0, 0xfffc
	s_mov_b64 s[0:1], 0
.LBB1_117:                              ; %.lr.ph
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s20, s8, s0
	s_addc_u32 s21, s9, s1
	s_add_u32 s0, s0, 4
	global_load_b32 v8, v7, s[20:21] offset:5
	s_addc_u32 s1, s1, 0
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v9, 0xff, v8
	v_bfe_u32 v11, v8, 8, 8
	v_lshrrev_b32_e32 v10, 24, v8
	v_bfe_u32 v8, v8, 16, 8
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_lo_u32 v9, 0x180, v9
	v_mul_lo_u32 v11, 0x180, v11
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_lo_u32 v10, 0x180, v10
	v_mul_lo_u32 v8, 0x180, v8
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, s15, s3, v9
	v_add_co_ci_u32_e64 v13, null, s4, 0, s15
	v_add_co_u32 v14, s15, s3, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, s4, 0, s15
	v_add_co_u32 v18, s15, s3, v8
	v_add_co_u32 v8, vcc_lo, v12, v1
	v_add_co_ci_u32_e64 v9, null, 0, v13, vcc_lo
	v_add_co_ci_u32_e64 v19, null, s4, 0, s15
	v_add_co_u32 v20, s15, s3, v10
	v_add_co_u32 v10, vcc_lo, v12, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, 0, v13, vcc_lo
	v_add_co_u32 v12, vcc_lo, v14, v1
	v_add_co_ci_u32_e64 v13, null, 0, v15, vcc_lo
	global_load_u8 v22, v[8:9], off offset:5
	v_add_co_u32 v14, vcc_lo, v14, v4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v15, vcc_lo
	v_add_co_u32 v16, vcc_lo, v18, v1
	global_load_u8 v12, v[12:13], off offset:5
	v_add_co_ci_u32_e64 v21, null, s4, 0, s15
	v_add_co_ci_u32_e64 v17, null, 0, v19, vcc_lo
	v_add_co_u32 v18, vcc_lo, v18, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v19, vcc_lo
	v_add_co_u32 v8, vcc_lo, v20, v1
	v_add_co_ci_u32_e64 v9, null, 0, v21, vcc_lo
	s_clause 0x4
	global_load_u8 v13, v[16:17], off offset:5
	global_load_b32 v16, v[10:11], off offset:37
	global_load_b32 v14, v[14:15], off offset:37
	global_load_u8 v15, v[8:9], off offset:5
	global_load_b32 v17, v[18:19], off offset:37
	v_add_co_u32 v8, vcc_lo, v20, v4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, 0, v21, vcc_lo
	global_load_b32 v18, v[8:9], off offset:37
	v_mov_b32_e32 v8, s11
	s_add_i32 s11, s11, 16
	s_cmp_eq_u32 s14, s0
	ds_load_b128 v[8:11], v8
	s_waitcnt vmcnt(7)
	v_bfe_u32 v19, v22, v2, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v19, v19
	s_waitcnt vmcnt(6)
	v_bfe_u32 v12, v12, v2, 2
	v_cvt_f32_ubyte0_e32 v12, v12
	s_waitcnt vmcnt(5)
	v_bfe_u32 v13, v13, v2, 2
	s_waitcnt vmcnt(4)
	v_fma_mix_f32 v16, v16, v19, v16 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt vmcnt(3)
	v_fma_mix_f32 v12, v14, v12, v14 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt vmcnt(2)
	v_bfe_u32 v15, v15, v2, 2
	v_cvt_f32_ubyte0_e32 v13, v13
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v5, v8, v16
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v8, v15
	s_waitcnt vmcnt(1)
	v_fma_mix_f32 v13, v17, v13, v17 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v5, v9, v12
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v18, v8, v18 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v13
	v_fmac_f32_e32 v5, v11, v8
	s_cbranch_scc0 .LBB1_117
; %bb.118:                              ; %.preheader251.loopexit.unr-lcssa
	s_max_u32 s1, s27, 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s1, s1, 3
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc0 .LBB1_120
	s_branch .LBB1_122
.LBB1_119:
	v_mov_b32_e32 v5, 0
	s_max_u32 s1, s27, 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s1, s1, 3
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc1 .LBB1_122
.LBB1_120:                              ; %.lr.ph.epil.preheader
	s_lshl_b32 s1, s23, 16
	s_lshl_b32 s8, s22, 8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_or_b32 s1, s1, s8
	s_lshl_b32 s8, s0, 2
	s_sub_i32 s1, s1, s30
	s_lshl_b32 s1, s1, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s9, s1, 31
	s_add_u32 s1, s28, s1
	s_addc_u32 s9, 0, s9
	s_add_u32 s0, s1, s0
	s_addc_u32 s1, s9, 0
	s_add_u32 s0, s12, s0
	s_addc_u32 s1, s13, s1
	s_add_u32 s0, s0, 5
	s_addc_u32 s1, s1, 0
	s_add_i32 s9, s24, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e64 v7, s9, 33 clamp
	v_readfirstlane_b32 s9, v7
	v_mov_b32_e32 v7, 0
	s_max_u32 s9, s9, 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s9, s9, 3
	s_lshl_b32 s9, s9, 2
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_121:                              ; %.lr.ph.epil
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v8, v7, s[0:1]
	s_waitcnt vmcnt(0)
	v_mul_lo_u32 v8, 0x180, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, s11, s3, v8
	v_add_co_ci_u32_e64 v11, null, s4, 0, s11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, v10, v1
	v_add_co_ci_u32_e64 v9, null, 0, v11, vcc_lo
	global_load_u8 v12, v[8:9], off offset:5
	v_add_co_u32 v8, vcc_lo, v10, v4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, 0, v11, vcc_lo
	global_load_b32 v8, v[8:9], off offset:37
	v_mov_b32_e32 v9, s8
	s_add_i32 s8, s8, 4
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_add_i32 s9, s9, -4
	ds_load_b32 v9, v9
	s_cmp_lg_u32 s9, 0
	s_waitcnt vmcnt(1)
	v_bfe_u32 v10, v12, v2, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v10, v10
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v8, v10, v8 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v9, v8
	s_cbranch_scc1 .LBB1_121
.LBB1_122:                              ; %.preheader251
	s_set_inst_prefetch_distance 0x2
	s_add_u32 s0, s6, s28
	s_addc_u32 s1, s7, 0
	s_add_u32 s0, s0, s27
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s26, s27
	v_mov_b32_e32 v8, 0
	s_cselect_b32 s6, -1, 0
	s_ashr_i32 s11, s10, 31
	s_add_u32 s0, s0, s10
	s_addc_u32 s1, s1, s11
	v_add_co_u32 v6, s0, s0, v6
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v7, null, s1, 0, s0
	s_lshl_b32 s7, s25, 11
	s_cmp_eq_u32 s26, s27
	s_cbranch_scc1 .LBB1_125
; %bb.123:                              ; %.lr.ph277.preheader
	s_add_i32 s0, s24, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	s_min_u32 s8, s0, 33
	s_add_u32 s1, s7, s28
	s_addc_u32 s9, 0, 0
	s_lshl_b32 s14, s23, 16
	s_lshl_b32 s15, s22, 8
	s_or_b32 s14, s14, s15
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s14, s14, s30
	s_lshl_b32 s14, s14, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_ashr_i32 s15, s14, 31
	s_add_u32 s1, s1, s14
	s_addc_u32 s9, s9, s15
	s_sub_i32 s14, s0, s8
	s_add_u32 s0, s1, s14
	s_addc_u32 s1, s9, 0
	s_add_u32 s0, s12, s0
	s_addc_u32 s1, s13, s1
	s_add_u32 s0, s0, 5
	s_addc_u32 s1, s1, 0
	s_lshl_b32 s9, s14, 2
	.p2align	6
.LBB1_124:                              ; %.lr.ph277
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v9, v8, s[0:1]
	s_add_i32 s8, s8, -1
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v9, 11, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	global_load_u16 v9, v[9:10], off offset:5
	v_mov_b32_e32 v10, s9
	s_add_i32 s9, s9, 4
	s_cmp_eq_u32 s8, 0
	ds_load_b32 v10, v10
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v9, 16, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v10, v9
	s_cbranch_scc0 .LBB1_124
.LBB1_125:                              ; %._crit_edge
	ds_store_b32 v3, v5 offset:4096
	v_mov_b32_e32 v5, 0
	s_and_not1_b32 vcc_lo, exec_lo, s5
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_cbranch_vccnz .LBB1_128
; %bb.126:                              ; %.lr.ph.1.preheader
	s_add_i32 s0, s24, s22
	s_lshl_b32 s1, s23, 16
	s_lshl_b32 s5, s22, 8
	v_sub_nc_u32_e64 v5, s0, 33 clamp
	s_or_b32 s0, s1, s5
	v_mov_b32_e32 v9, 0
	s_sub_i32 s0, s0, s30
	s_movk_i32 s5, 0x400
	s_lshl_b32 s0, s0, 3
	v_max_u32_e32 v5, 1, v5
	s_ashr_i32 s1, s0, 31
	s_add_u32 s0, s28, s0
	s_addc_u32 s1, 0, s1
	s_add_u32 s0, s12, s0
	v_sub_nc_u32_e32 v8, 0, v5
	v_mov_b32_e32 v5, 0
	s_addc_u32 s1, s13, s1
	s_add_u32 s0, s0, 5
	s_addc_u32 s1, s1, 0
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_127:                              ; %.lr.ph.1
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v10, v9, s[0:1]
	s_waitcnt vmcnt(0)
	v_mul_lo_u32 v10, 0x180, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, s8, s3, v10
	v_add_co_ci_u32_e64 v13, null, s4, 0, s8
	v_add_co_u32 v8, s8, v8, 1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v12, v1
	v_add_co_ci_u32_e64 v11, null, 0, v13, vcc_lo
	global_load_u8 v14, v[10:11], off offset:5
	v_add_co_u32 v10, vcc_lo, v12, v4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, 0, v13, vcc_lo
	global_load_b32 v10, v[10:11], off offset:37
	v_mov_b32_e32 v11, s5
	s_add_i32 s5, s5, 4
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_and_not1_b32 vcc_lo, exec_lo, s8
	ds_load_b32 v11, v11
	s_waitcnt vmcnt(1)
	v_bfe_u32 v12, v14, v2, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v12, v12
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v10, v10, v12, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v11, v10
	s_cbranch_vccnz .LBB1_127
.LBB1_128:                              ; %Flow2249
	s_set_inst_prefetch_distance 0x2
	v_or_b32_e32 v1, 0x1000, v3
	s_and_not1_b32 vcc_lo, exec_lo, s6
	s_cbranch_vccnz .LBB1_131
; %bb.129:                              ; %.lr.ph277.1
	s_add_i32 s24, s24, s22
	v_mov_b32_e32 v2, 0
	s_min_u32 s3, s24, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s0, s24, s3
	s_lshl_b32 s1, s0, 2
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	s_add_i32 s4, s1, 0x400
	s_add_u32 s1, s7, s28
	s_addc_u32 s5, 0, 0
	s_lshl_b32 s6, s23, 16
	s_lshl_b32 s7, s22, 8
	s_or_b32 s6, s6, s7
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s6, s6, s30
	s_lshl_b32 s6, s6, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s7, s6, 31
	s_add_u32 s1, s1, s6
	s_addc_u32 s5, s5, s7
	s_add_u32 s0, s1, s0
	s_addc_u32 s1, s5, 0
	s_add_u32 s0, s12, s0
	s_addc_u32 s1, s13, s1
	s_add_u32 s0, s0, 5
	s_addc_u32 s1, s1, 0
	.p2align	6
.LBB1_130:                              ; =>This Inner Loop Header: Depth=1
	global_load_u8 v3, v2, s[0:1]
	s_add_i32 s3, s3, -1
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v3, 11, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v3, vcc_lo, v6, v3
	v_add_co_ci_u32_e64 v4, null, 0, v7, vcc_lo
	global_load_u16 v3, v[3:4], off offset:5
	v_mov_b32_e32 v4, s4
	s_add_i32 s4, s4, 4
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s3, 0
	ds_load_b32 v4, v4
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v3, 16, v3
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v5, v4, v3
	s_cbranch_scc1 .LBB1_130
.LBB1_131:                              ; %._crit_edge.1
	v_lshlrev_b32_e32 v2, 12, v0
	ds_store_b32 v1, v5 offset:512
	v_mov_b32_e32 v1, 0
	s_mov_b64 s[4:5], 0
	s_movk_i32 s3, 0x1000
	v_add_co_u32 v3, s0, s16, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s17, 0, s0
	s_lshl_b64 s[0:1], s[10:11], 1
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v3, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v4, null, s1, v4, vcc_lo
	s_barrier
	buffer_gl0_inv
	s_barrier
	buffer_gl0_inv
.LBB1_132:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v9, vcc_lo, v3, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s5, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off
	global_load_b128 v[9:12], v[9:10], off offset:16
	v_mov_b32_e32 v21, s3
	s_add_i32 s3, s3, 64
	s_cmpk_eq_i32 s4, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	v_and_b32_e32 v5, 0xffff0000, v5
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v22, v13
	v_lshlrev_b32_e32 v13, 16, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v1, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	v_and_b32_e32 v5, 0xffff0000, v7
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v6, v17 :: v_dual_lshlrev_b32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v9, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v18
	v_and_b32_e32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v1, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v17, v13
	v_lshlrev_b32_e32 v13, 16, v10
	v_fmac_f32_e32 v1, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v13, v15
	v_fmac_f32_e32 v1, v9, v16
	v_and_b32_e32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v10, v5
	v_lshlrev_b32_e32 v5, 16, v12
	v_dual_fmac_f32 v1, v9, v6 :: v_dual_and_b32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v7
	v_fmac_f32_e32 v1, v6, v8
	s_cbranch_scc0 .LBB1_132
; %bb.133:                              ; %.preheader.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[4:5], 0
.LBB1_134:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v3, s4
	v_add_co_ci_u32_e64 v10, null, s5, v4, vcc_lo
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off offset:256
	global_load_b128 v[9:12], v[9:10], off offset:272
	v_mov_b32_e32 v21, s3
	s_add_i32 s3, s3, 64
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_lg_i32 s4, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	v_and_b32_e32 v5, 0xffff0000, v5
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v22, v13
	v_lshlrev_b32_e32 v13, 16, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v1, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	v_and_b32_e32 v5, 0xffff0000, v7
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v6, v17 :: v_dual_lshlrev_b32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v9, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v18
	v_and_b32_e32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v1, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v17, v13
	v_lshlrev_b32_e32 v13, 16, v10
	v_fmac_f32_e32 v1, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v13, v15
	v_fmac_f32_e32 v1, v9, v16
	v_and_b32_e32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v10, v5
	v_lshlrev_b32_e32 v5, 16, v12
	v_dual_fmac_f32 v1, v9, v6 :: v_dual_and_b32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v7
	v_fmac_f32_e32 v1, v6, v8
	s_cbranch_scc1 .LBB1_134
; %bb.135:                              ; %.preheader.1322
	s_lshl_b32 s2, s2, 10
	s_add_u32 s0, s16, s0
	v_or_b32_e32 v3, s2, v0
	s_addc_u32 s1, s17, s1
	v_add_co_u32 v2, s0, s0, v2
	s_movk_i32 s3, 0x1000
	v_ashrrev_i32_e32 v4, 31, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], 2, v[3:4]
	v_mov_b32_e32 v4, 0
	v_add_co_ci_u32_e64 v3, null, s1, 0, s0
	s_mov_b64 s[0:1], 0
	v_add_co_u32 v5, vcc_lo, s18, v5
	v_add_co_ci_u32_e64 v6, null, s19, v6, vcc_lo
	global_store_b32 v[5:6], v1, off
.LBB1_136:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v1, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x80000, v1
	v_add_co_ci_u32_e64 v10, null, 0, v5, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off
	global_load_b128 v[9:12], v[9:10], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v21, 16, v5
	v_mov_b32_e32 v1, s3
	s_add_i32 s3, s3, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[13:16], v1
	ds_load_b128 v[17:20], v1 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v21, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v1 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v6, v17
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v4, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v9
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v17, v13
	v_fmac_f32_e32 v4, v1, v14
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v9, 16, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v9, v15
	v_dual_fmac_f32 v4, v1, v16 :: v_dual_lshlrev_b32 v9, 16, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v9, v5 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_dual_fmac_f32 v4, v1, v6 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v7 :: v_dual_and_b32 v1, 0xffff0000, v12
	v_fmac_f32_e32 v4, v1, v8
	s_cbranch_scc1 .LBB1_136
; %bb.137:                              ; %.preheader.1.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_138:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v5, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x80000, v1
	v_add_co_ci_u32_e64 v10, null, 0, v5, vcc_lo
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off offset:256
	global_load_b128 v[9:12], v[9:10], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v21, 16, v5
	v_mov_b32_e32 v1, s3
	s_add_i32 s3, s3, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[13:16], v1
	ds_load_b128 v[17:20], v1 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v21, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v1 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v6, v17
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v4, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v9
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v17, v13
	v_fmac_f32_e32 v4, v1, v14
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v9, 16, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v9, v15
	v_dual_fmac_f32 v4, v1, v16 :: v_dual_lshlrev_b32 v9, 16, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v9, v5 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_dual_fmac_f32 v4, v1, v6 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v7 :: v_dual_and_b32 v1, 0xffff0000, v12
	v_fmac_f32_e32 v4, v1, v8
	s_cbranch_scc1 .LBB1_138
; %bb.139:                              ; %.preheader.2
	s_ashr_i32 s0, s2, 31
	v_add_co_u32 v0, s1, v0, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v1, null, 0, s0, s1
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s18, v0
	v_add_co_ci_u32_e64 v1, null, s19, v1, vcc_lo
	global_store_b32 v[0:1], v4, off offset:512
.LBB1_140:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x100000, v4
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
	s_cbranch_scc1 .LBB1_140
; %bb.141:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_142:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x100000, v4
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
	s_cbranch_scc1 .LBB1_142
; %bb.143:                              ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:1024
.LBB1_144:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x180000, v5
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
	s_cbranch_scc1 .LBB1_144
; %bb.145:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_146:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x180000, v5
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
	s_cbranch_scc1 .LBB1_146
; %bb.147:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:1536
.LBB1_148:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x200000, v4
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
	s_cbranch_scc1 .LBB1_148
; %bb.149:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_150:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x200000, v4
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
	s_cbranch_scc1 .LBB1_150
; %bb.151:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:2048
.LBB1_152:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x280000, v5
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
	s_cbranch_scc1 .LBB1_152
; %bb.153:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_154:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x280000, v5
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
	s_cbranch_scc1 .LBB1_154
; %bb.155:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:2560
.LBB1_156:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x300000, v4
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
	s_cbranch_scc1 .LBB1_156
; %bb.157:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_158:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x300000, v4
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
	s_cbranch_scc1 .LBB1_158
; %bb.159:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:3072
.LBB1_160:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x380000, v5
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
	s_cbranch_scc1 .LBB1_160
; %bb.161:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_162:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x380000, v5
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
	s_cbranch_scc1 .LBB1_162
; %bb.163:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
.LBB1_164:                              ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi0EEvPKhPKfPKtPf
		.amdhsa_group_segment_fixed_size 5632
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
		.amdhsa_next_free_vgpr 23
		.amdhsa_next_free_sgpr 48
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
	.section	.text._Z11query_groupILi0EEvPKhPKfPKtPf,"axG",@progbits,_Z11query_groupILi0EEvPKhPKfPKtPf,comdat
.Lfunc_end1:
	.size	_Z11query_groupILi0EEvPKhPKfPKtPf, .Lfunc_end1-_Z11query_groupILi0EEvPKhPKfPKtPf
                                        ; -- End function
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.num_vgpr, 23
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.num_agpr, 0
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.numbered_sgpr, 48
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.num_named_barrier, 0
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.private_seg_size, 0
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.uses_vcc, 1
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.uses_flat_scratch, 0
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.has_dyn_sized_stack, 0
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.has_recursion, 0
	.set _Z11query_groupILi0EEvPKhPKfPKtPf.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 13580
; TotalNumSgprs: 50
; NumVgprs: 23
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 5632 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 50
; NumVGPRsForWavesPerEU: 23
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z11query_groupILi1EEvPKhPKfPKtPf,"axG",@progbits,_Z11query_groupILi1EEvPKhPKfPKtPf,comdat
	.protected	_Z11query_groupILi1EEvPKhPKfPKtPf ; -- Begin function _Z11query_groupILi1EEvPKhPKfPKtPf
	.globl	_Z11query_groupILi1EEvPKhPKfPKtPf
	.p2align	8
	.type	_Z11query_groupILi1EEvPKhPKfPKtPf,@function
_Z11query_groupILi1EEvPKhPKfPKtPf:      ; @_Z11query_groupILi1EEvPKhPKfPKtPf
; %bb.0:
	s_load_b256 s[12:19], s[0:1], 0x0
	v_mov_b32_e32 v1, 0
	s_and_b32 s3, s0, 0xff00
	s_and_b32 s5, s0, 0xffff0000
	s_mov_b32 s4, 0
	s_waitcnt lgkmcnt(0)
	s_clause 0x1
	global_load_d16_u8 v2, v1, s[12:13] offset:4
	global_load_b32 v1, v1, s[12:13]
	s_waitcnt vmcnt(1)
	v_readfirstlane_b32 s1, v2
	s_waitcnt vmcnt(0)
	v_readfirstlane_b32 s0, v1
	s_and_b32 s24, s1, 0xff
	s_mov_b32 s1, s4
	s_or_b32 s28, s24, s3
	s_bfe_u32 s27, s0, 0x80008
	s_and_b32 s3, s28, 0xffff
	s_and_b32 s25, s0, 0xff
	s_or_b32 s5, s3, s5
	s_lshl_b32 s26, s27, 8
	s_or_b64 s[4:5], s[0:1], s[4:5]
	s_or_b32 s31, s26, s25
	s_lshr_b64 s[20:21], s[4:5], 24
	v_sub_nc_u32_e64 v1, s31, 33 clamp
	s_and_b32 s21, s20, 0xff
	s_cmp_gt_i32 s2, 7
	s_cselect_b32 s1, -1, 0
	s_add_i32 s3, s31, 0xfffffeff
	v_sub_nc_u32_e32 v2, s31, v1
	s_cmp_lt_u32 s3, 0xffffff00
	v_cmp_gt_u32_e32 vcc_lo, s21, v1
	s_cselect_b32 s3, -1, 0
	s_bfe_u32 s0, s0, 0x80010
	s_or_b32 s1, s1, s3
	s_cmp_lg_u32 s0, 0
	v_cmp_gt_i32_e64 s0, s24, v2
	s_cselect_b32 s3, -1, 0
	v_readfirstlane_b32 s30, v1
	s_or_b32 s1, s1, s3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s1, s1, vcc_lo
	s_or_b32 s0, s1, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s0
	s_cbranch_vccnz .LBB2_197
; %bb.1:                                ; %.preheader288
	s_add_i32 s0, s31, -1
	v_lshlrev_b32_e32 v1, 7, v0
	s_lshr_b32 s1, s0, 27
	v_lshl_add_u32 v4, v0, 2, 0x800
	s_add_i32 s0, s0, s1
	v_cmp_gt_u32_e64 s1, s31, v0
	s_and_b32 s36, s0, 0xffffffe0
	s_ashr_i32 s29, s0, 5
	s_sub_i32 s0, s31, s36
	s_mul_i32 s35, s29, 0x600
	s_lshl_b32 s0, s0, 8
	v_and_b32_e32 v5, 0xf80, v1
	s_add_i32 s0, s0, s35
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s0, s0, s2
	s_ashr_i32 s3, s0, 31
	s_add_u32 s33, s12, s0
	s_addc_u32 s34, s13, s3
	s_add_u32 s0, s33, s35
	s_addc_u32 s6, s34, 0
	s_lshl_b32 s10, s2, 8
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB2_9
; %bb.2:
                                        ; implicit-def: $vgpr1
	s_mov_b32 s4, exec_lo
	v_cmpx_le_u32_e64 s36, v0
	s_xor_b32 s7, exec_lo, s4
	s_cbranch_execz .LBB2_5
; %bb.3:                                ; %.preheader286
	v_subrev_nc_u32_e32 v1, s36, v0
	s_ashr_i32 s11, s10, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b64 s[4:5], s[10:11], 2
	s_add_u32 s4, s14, s4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 8, v1
	s_addc_u32 s5, s15, s5
	v_add_co_u32 v2, s8, s0, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s6, 0, s8
	s_add_u32 s8, s4, 28
	s_addc_u32 s9, s5, 0
	s_mov_b64 s[4:5], 0
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB2_4:                                ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v6, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v7, null, s5, v3, vcc_lo
	s_add_u32 s22, s8, 0xffffffe4
	s_addc_u32 s23, s9, -1
	s_add_u32 s4, s4, 16
	global_load_b128 v[6:9], v[6:7], off offset:5
	s_load_b256 s[40:47], s[22:23], 0x0
	s_addc_u32 s5, s5, 0
	s_add_u32 s8, s8, 32
	s_addc_u32 s9, s9, 0
	s_cmpk_lg_i32 s4, 0x100
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v10, 16, v6
	v_and_b32_e32 v6, 0xffff0000, v6
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s40, v10 :: v_dual_lshlrev_b32 v10, 16, v7
	v_dual_fmac_f32 v1, s41, v6 :: v_dual_and_b32 v6, 0xffff0000, v7
	v_lshlrev_b32_e32 v7, 16, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s42, v10
	v_dual_fmac_f32 v1, s43, v6 :: v_dual_and_b32 v6, 0xffff0000, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, s44, v7
	v_lshlrev_b32_e32 v7, 16, v9
	v_dual_fmac_f32 v1, s45, v6 :: v_dual_and_b32 v6, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s46, v7
	v_fmac_f32_e32 v1, s47, v6
	s_cbranch_scc1 .LBB2_4
.LBB2_5:                                ; %Flow2499
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s7, s7
	s_cbranch_execz .LBB2_8
; %bb.6:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s11, s10, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	s_lshl_b64 s[4:5], s[10:11], 2
	s_mov_b32 s11, 0
	v_mul_u32_u24_e32 v2, 0x600, v1
	v_mov_b32_e32 v1, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s8, s33, v2
	v_add_co_ci_u32_e64 v3, null, s34, 0, s8
	s_add_u32 s8, s14, s4
	s_addc_u32 s9, s15, s5
	s_mov_b64 s[4:5], 0
.LBB2_7:                                ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v6, s11, v5
	s_add_u32 s22, s8, s4
	s_addc_u32 s23, s9, s5
	s_add_i32 s11, s11, 4
	s_load_b128 s[40:43], s[22:23], 0x0
	v_lshrrev_b32_e32 v6, 2, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v6, vcc_lo, v2, v6
	v_add_co_ci_u32_e64 v7, null, 0, v3, vcc_lo
	global_load_d16_u8 v10, v[6:7], off offset:5
	v_add_co_u32 v6, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v7, null, s5, v3, vcc_lo
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x200
	global_load_b128 v[6:9], v[6:7], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v12.l, v10.l, 3
	v_lshrrev_b16 v10.h, 2, v10.l
	v_lshrrev_b16 v11.l, 4, v10.l
	v_lshrrev_b16 v10.l, 6, v10.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v12, v12
	v_and_b16 v13.l, v10.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_and_b16 v11.l, v11.l, 3
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v6, v6, v12, v6 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v12, v13
	v_cvt_f32_ubyte0_e32 v11, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, s40, v6
	v_fma_mix_f32 v6, v7, v12, v7 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v7, v10
	v_fma_mix_f32 v8, v8, v11, v8 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, s41, v6
	v_fma_mix_f32 v6, v9, v7, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s42, v8
	v_fmac_f32_e32 v1, s43, v6
	s_cbranch_scc0 .LBB2_7
.LBB2_8:                                ; %Flow2500
	s_or_b32 exec_lo, exec_lo, s7
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v1
	ds_store_b32 v4, v1
.LBB2_9:                                ; %Flow2501
	s_or_b32 exec_lo, exec_lo, s3
	v_add_nc_u32_e32 v7, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_u32_e64 s3, s31, v7
	s_and_saveexec_b32 s7, s3
	s_cbranch_execz .LBB2_17
; %bb.10:
                                        ; implicit-def: $vgpr1
	s_mov_b32 s4, exec_lo
	v_cmpx_le_u32_e64 s36, v7
	s_xor_b32 s8, exec_lo, s4
	s_cbranch_execz .LBB2_13
; %bb.11:                               ; %.preheader286.1
	v_subrev_nc_u32_e32 v1, s36, v7
	s_ashr_i32 s11, s10, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b64 s[4:5], s[10:11], 2
	s_add_u32 s4, s14, s4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 8, v1
	s_addc_u32 s5, s15, s5
	v_add_co_u32 v2, s0, s0, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s6, 0, s0
	s_add_u32 s0, s4, 28
	s_addc_u32 s6, s5, 0
	s_mov_b64 s[4:5], 0
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB2_12:                               ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v8, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s5, v3, vcc_lo
	s_add_u32 s22, s0, 0xffffffe4
	s_addc_u32 s23, s6, -1
	s_add_u32 s4, s4, 16
	global_load_b128 v[8:11], v[8:9], off offset:5
	s_load_b256 s[40:47], s[22:23], 0x0
	s_addc_u32 s5, s5, 0
	s_add_u32 s0, s0, 32
	s_addc_u32 s6, s6, 0
	s_cmpk_eq_i32 s4, 0x100
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v6, 16, v8
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s40, v6 :: v_dual_and_b32 v8, 0xffff0000, v8
	v_dual_fmac_f32 v1, s41, v8 :: v_dual_lshlrev_b32 v6, 16, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s42, v6 :: v_dual_and_b32 v8, 0xffff0000, v9
	v_dual_fmac_f32 v1, s43, v8 :: v_dual_lshlrev_b32 v6, 16, v10
	v_and_b32_e32 v8, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s44, v6 :: v_dual_lshlrev_b32 v6, 16, v11
	v_dual_fmac_f32 v1, s45, v8 :: v_dual_and_b32 v8, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s46, v6
	v_fmac_f32_e32 v1, s47, v8
	s_cbranch_scc0 .LBB2_12
.LBB2_13:                               ; %Flow2494
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s0, s8
	s_cbranch_execz .LBB2_16
; %bb.14:
	v_lshrrev_b32_e32 v1, 5, v7
	s_ashr_i32 s11, s10, 31
	s_mov_b32 s9, 0
	s_lshl_b64 s[4:5], s[10:11], 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_u32_u24_e32 v2, 0x600, v1
	v_mov_b32_e32 v1, 0
	v_add_co_u32 v2, s6, s33, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s34, 0, s6
	s_add_u32 s6, s14, s4
	s_addc_u32 s8, s15, s5
	s_mov_b64 s[4:5], 0
.LBB2_15:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v6, s9, v5
	s_add_u32 s22, s6, s4
	s_addc_u32 s23, s8, s5
	s_add_i32 s9, s9, 4
	s_load_b128 s[40:43], s[22:23], 0x0
	v_lshrrev_b32_e32 v6, 2, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, v2, v6
	v_add_co_ci_u32_e64 v9, null, 0, v3, vcc_lo
	global_load_d16_u8 v6, v[8:9], off offset:5
	v_add_co_u32 v8, vcc_lo, v2, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s5, v3, vcc_lo
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x200
	global_load_b128 v[8:11], v[8:9], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v13.l, v6.l, 3
	v_lshrrev_b16 v6.h, 2, v6.l
	v_lshrrev_b16 v12.l, 4, v6.l
	v_lshrrev_b16 v6.l, 6, v6.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v13, v13
	v_and_b16 v14.l, v6.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v12.l, v12.l, 3
	v_cvt_f32_ubyte0_e32 v6, v6
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v8, v13, v8 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v13, v14
	v_cvt_f32_ubyte0_e32 v12, v12
	v_fma_mix_f32 v6, v11, v6, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v1, s40, v8
	v_fma_mix_f32 v8, v9, v13, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v9, v10, v12, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s41, v8
	v_fmac_f32_e32 v1, s42, v9
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, s43, v6
	s_cbranch_scc0 .LBB2_15
.LBB2_16:                               ; %Flow2495
	s_or_b32 exec_lo, exec_lo, s0
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v1
	ds_store_b32 v4, v1 offset:512
.LBB2_17:                               ; %Flow2496
	s_or_b32 exec_lo, exec_lo, s7
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB2_19
; %bb.18:
	ds_load_b32 v1, v4
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB2_19:
	s_or_b32 exec_lo, exec_lo, s0
	s_and_saveexec_b32 s0, s3
	s_cbranch_execz .LBB2_21
; %bb.20:
	ds_load_b32 v2, v4 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB2_21:
	s_or_b32 exec_lo, exec_lo, s0
	v_lshlrev_b32_e32 v3, 2, v0
	v_cmp_gt_u32_e64 s4, 64, v0
	s_delay_alu instid0(VALU_DEP_2)
	v_add_nc_u32_e32 v6, 0x1b00, v3
	ds_store_b32 v3, v1 offset:6912
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s4
	s_cbranch_execz .LBB2_23
; %bb.22:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_23:
	s_or_b32 exec_lo, exec_lo, s0
	v_cmp_gt_u32_e64 s5, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s5
	s_cbranch_execz .LBB2_25
; %bb.24:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_25:
	s_or_b32 exec_lo, exec_lo, s0
	v_cmp_gt_u32_e64 s6, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s6
	s_cbranch_execz .LBB2_27
; %bb.26:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_27:
	s_or_b32 exec_lo, exec_lo, s0
	v_cmp_gt_u32_e64 s7, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s7
	s_cbranch_execz .LBB2_29
; %bb.28:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_29:
	s_or_b32 exec_lo, exec_lo, s0
	v_cmp_gt_u32_e64 s8, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s8
	s_cbranch_execz .LBB2_31
; %bb.30:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_31:
	s_or_b32 exec_lo, exec_lo, s0
	v_cmp_gt_u32_e64 s9, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s0, s9
	s_cbranch_execz .LBB2_33
; %bb.32:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_33:
	s_or_b32 exec_lo, exec_lo, s0
	v_cmp_eq_u32_e64 s0, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s0
	s_cbranch_execz .LBB2_35
; %bb.34:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_35:
	s_or_b32 exec_lo, exec_lo, s11
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:6912
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB2_37
; %bb.36:
	ds_load_b32 v1, v4
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v8, 0x3fb8aa3b, v1
	v_fma_f32 v9, 0x3fb8aa3b, v1, -v8
	v_rndne_f32_e32 v10, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v9, v1, 0x32a5705f, v9 :: v_dual_sub_f32 v8, v8, v10
	v_add_f32_e32 v8, v8, v9
	v_cvt_i32_f32_e32 v9, v10
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v8, v8
	v_ldexp_f32 v8, v8, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v8, 0, v8, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v1
	v_cndmask_b32_e32 v1, 0x7f800000, v8, vcc_lo
	ds_store_b32 v3, v1
.LBB2_37:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s3
	s_cbranch_execz .LBB2_39
; %bb.38:
	ds_load_b32 v8, v4 offset:512
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v8, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v8, 0x3fb8aa3b, v2
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v2
	v_fma_f32 v9, 0x3fb8aa3b, v2, -v8
	v_rndne_f32_e32 v10, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmamk_f32 v9, v2, 0x32a5705f, v9 :: v_dual_sub_f32 v8, v8, v10
	v_add_f32_e32 v8, v8, v9
	v_cvt_i32_f32_e32 v9, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v8, v8
	v_ldexp_f32 v8, v8, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v8, 0, v8, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v2
	v_cndmask_b32_e32 v2, 0x7f800000, v8, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v1, v2
	ds_store_b32 v3, v2 offset:512
.LBB2_39:
	s_or_b32 exec_lo, exec_lo, s11
	ds_store_b32 v6, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s4
	s_cbranch_execz .LBB2_41
; %bb.40:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_41:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s5
	s_cbranch_execz .LBB2_43
; %bb.42:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_43:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s6
	s_cbranch_execz .LBB2_45
; %bb.44:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_45:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s7
	s_cbranch_execz .LBB2_47
; %bb.46:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_47:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s8
	s_cbranch_execz .LBB2_49
; %bb.48:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_49:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s9
	s_cbranch_execz .LBB2_51
; %bb.50:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_51:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s0
	s_cbranch_execz .LBB2_53
; %bb.52:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_53:
	s_or_b32 exec_lo, exec_lo, s11
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:6912
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB2_55
; %bb.54:
	ds_load_b32 v2, v3
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v8, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v9, v8
	v_fma_f32 v10, -v8, v9, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, v10, v9
	v_div_scale_f32 v10, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v11, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v8, v11, v10
	v_fmac_f32_e32 v11, v12, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v8, v11, v10
	v_div_fmas_f32 v8, v8, v9, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v8, v1, v2
	ds_store_b32 v3, v2
.LBB2_55:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s3
	s_cbranch_execz .LBB2_57
; %bb.56:
	ds_load_b32 v2, v3 offset:512
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v8, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v9, v8
	v_fma_f32 v10, -v8, v9, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, v10, v9
	v_div_scale_f32 v10, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v11, v10, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v8, v11, v10
	v_fmac_f32_e32 v11, v12, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v8, v11, v10
	v_div_fmas_f32 v8, v8, v9, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v1, v8, v1, v2
	ds_store_b32 v3, v1 offset:512
.LBB2_57:                               ; %.preheader288.1
	s_or_b32 exec_lo, exec_lo, s11
	s_mulk_i32 s29, 0x1a00
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s37, s1
	s_cbranch_execz .LBB2_65
; %bb.58:
                                        ; implicit-def: $vgpr8
	s_mov_b32 s11, exec_lo
	v_cmpx_le_u32_e64 s36, v0
	s_xor_b32 s38, exec_lo, s11
	s_cbranch_execz .LBB2_61
; %bb.59:                               ; %.preheader286.1343
	s_ashr_i32 s11, s10, 31
	v_subrev_nc_u32_e32 v1, s36, v0
	s_lshl_b64 s[22:23], s[10:11], 2
	v_mov_b32_e32 v8, 0
	s_add_u32 s11, s14, s22
	s_addc_u32 s39, s15, s23
	s_lshl_b32 s22, s27, 16
	s_lshl_b32 s23, s25, 8
	v_lshlrev_b32_e32 v1, 8, v1
	s_or_b32 s22, s22, s23
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s22, s22, s29
	s_mul_i32 s22, s2, s22
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s23, s22, 31
	s_add_u32 s40, s12, s35
	s_addc_u32 s41, s13, 0
	s_add_u32 s22, s40, s22
	s_addc_u32 s23, s41, s23
	v_add_co_u32 v1, s22, s22, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s23, 0, s22
	s_mov_b64 s[22:23], 0
	v_add_co_u32 v1, vcc_lo, v1, 19
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB2_60:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[9:12], v[1:2], off offset:-14
	s_add_u32 s40, s11, s22
	s_addc_u32 s41, s39, s23
	v_add_co_u32 v1, vcc_lo, v1, 16
	s_load_b256 s[40:47], s[40:41], 0x200
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_u32 s22, s22, 32
	s_addc_u32 s23, s23, 0
	s_cmpk_eq_i32 s22, 0x200
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v13, 16, v9
	v_and_b32_e32 v9, 0xffff0000, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s40, v13 :: v_dual_lshlrev_b32 v13, 16, v10
	v_dual_fmac_f32 v8, s41, v9 :: v_dual_and_b32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s42, v13
	v_dual_fmac_f32 v8, s43, v9 :: v_dual_and_b32 v9, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v8, s44, v10
	v_lshlrev_b32_e32 v10, 16, v12
	v_dual_fmac_f32 v8, s45, v9 :: v_dual_and_b32 v9, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s46, v10
	v_fmac_f32_e32 v8, s47, v9
	s_cbranch_scc0 .LBB2_60
.LBB2_61:                               ; %Flow2489
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s38, s38
	s_cbranch_execz .LBB2_64
; %bb.62:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s11, s10, 31
	v_mov_b32_e32 v8, 0
	s_lshl_b64 s[22:23], s[10:11], 2
	s_mov_b32 s40, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s11, s33, v1
	v_add_co_ci_u32_e64 v2, null, s34, 0, s11
	s_add_u32 s11, s14, s22
	s_addc_u32 s39, s15, s23
	s_mov_b64 s[22:23], 0
.LBB2_63:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v9, s40, v5
	s_add_u32 s42, s11, s22
	s_addc_u32 s43, s39, s23
	s_add_i32 s40, s40, 4
	s_load_b128 s[44:47], s[42:43], 0x200
	v_lshrrev_b32_e32 v9, 2, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v1, v9
	v_add_co_ci_u32_e64 v10, null, 0, v2, vcc_lo
	global_load_d16_u8 v13, v[9:10], off offset:5
	v_add_co_u32 v9, vcc_lo, v1, s22
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s23, v2, vcc_lo
	s_add_u32 s22, s22, 16
	s_addc_u32 s23, s23, 0
	s_cmpk_eq_i32 s22, 0x200
	global_load_b128 v[9:12], v[9:10], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v15.l, v13.l, 3
	v_lshrrev_b16 v13.h, 2, v13.l
	v_lshrrev_b16 v14.l, 4, v13.l
	v_lshrrev_b16 v13.l, 6, v13.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v15, v15
	v_and_b16 v16.l, v13.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_and_b16 v14.l, v14.l, 3
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v15, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v15, v16
	v_cvt_f32_ubyte0_e32 v14, v14
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v8, s44, v9
	v_fma_mix_f32 v9, v10, v15, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v10, v13
	v_fma_mix_f32 v11, v11, v14, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v8, s45, v9
	v_fma_mix_f32 v9, v12, v10, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s46, v11
	v_fmac_f32_e32 v8, s47, v9
	s_cbranch_scc0 .LBB2_63
.LBB2_64:                               ; %Flow2490
	s_or_b32 exec_lo, exec_lo, s38
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v8
	ds_store_b32 v4, v1 offset:1024
.LBB2_65:                               ; %Flow2491
	s_or_b32 exec_lo, exec_lo, s37
	s_and_saveexec_b32 s37, s3
	s_cbranch_execz .LBB2_74
; %bb.66:
                                        ; implicit-def: $vgpr8
	s_mov_b32 s11, exec_lo
	v_cmpx_le_u32_e64 s36, v7
	s_xor_b32 s38, exec_lo, s11
	s_cbranch_execz .LBB2_70
; %bb.67:                               ; %.preheader286.1.1
	s_ashr_i32 s11, s10, 31
	v_subrev_nc_u32_e32 v1, s36, v7
	s_lshl_b64 s[22:23], s[10:11], 2
	v_mov_b32_e32 v8, 0
	s_add_u32 s11, s14, s22
	s_addc_u32 s39, s15, s23
	s_lshl_b32 s22, s27, 16
	s_lshl_b32 s23, s25, 8
	v_lshlrev_b32_e32 v1, 8, v1
	s_or_b32 s22, s22, s23
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s22, s22, s29
	s_mul_i32 s22, s2, s22
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s23, s22, 31
	s_add_u32 s35, s12, s35
	s_addc_u32 s36, s13, 0
	s_add_u32 s22, s35, s22
	s_addc_u32 s23, s36, s23
	v_add_co_u32 v1, s22, s22, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s23, 0, s22
	s_mov_b64 s[22:23], 0
	v_add_co_u32 v1, vcc_lo, v1, 19
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB2_68:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[9:12], v[1:2], off offset:-14
	s_add_u32 s40, s11, s22
	s_addc_u32 s41, s39, s23
	v_add_co_u32 v1, vcc_lo, v1, 16
	s_load_b256 s[40:47], s[40:41], 0x200
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_u32 s22, s22, 32
	s_addc_u32 s23, s23, 0
	s_cmpk_eq_i32 s22, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v5, 16, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s40, v5 :: v_dual_lshlrev_b32 v5, 16, v10
	v_dual_fmac_f32 v8, s41, v7 :: v_dual_and_b32 v7, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s42, v5 :: v_dual_lshlrev_b32 v5, 16, v11
	v_fmac_f32_e32 v8, s43, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s44, v5 :: v_dual_and_b32 v7, 0xffff0000, v11
	v_dual_fmac_f32 v8, s45, v7 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v8, s46, v5 :: v_dual_and_b32 v7, 0xffff0000, v12
	v_fmac_f32_e32 v8, s47, v7
	s_cbranch_scc0 .LBB2_68
; %bb.69:                               ; %Flow2482
	s_set_inst_prefetch_distance 0x2
                                        ; implicit-def: $vgpr5
                                        ; implicit-def: $vgpr7
.LBB2_70:                               ; %Flow2484
	s_and_not1_saveexec_b32 s22, s38
	s_cbranch_execz .LBB2_73
; %bb.71:
	v_lshrrev_b32_e32 v1, 5, v7
	s_ashr_i32 s11, s10, 31
	v_mov_b32_e32 v8, 0
	s_lshl_b64 s[38:39], s[10:11], 2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_u32_u24_e32 v1, 0x600, v1
	v_add_co_u32 v1, s11, s33, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s34, 0, s11
	s_add_u32 s11, s14, s38
	s_addc_u32 s23, s15, s39
	s_mov_b32 s33, 0
	s_mov_b64 s[14:15], 0
.LBB2_72:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v7, s33, v5
	s_add_u32 s34, s11, s14
	s_addc_u32 s35, s23, s15
	s_add_i32 s33, s33, 4
	s_load_b128 s[40:43], s[34:35], 0x200
	v_lshrrev_b32_e32 v7, 2, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v1, v7
	v_add_co_ci_u32_e64 v10, null, 0, v2, vcc_lo
	global_load_d16_u8 v7, v[9:10], off offset:5
	v_add_co_u32 v9, vcc_lo, v1, s14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s15, v2, vcc_lo
	s_add_u32 s14, s14, 16
	s_addc_u32 s15, s15, 0
	s_cmpk_eq_i32 s14, 0x200
	global_load_b128 v[9:12], v[9:10], off offset:1029
	s_waitcnt vmcnt(1)
	v_and_b16 v14.l, v7.l, 3
	v_lshrrev_b16 v7.h, 2, v7.l
	v_lshrrev_b16 v13.l, 4, v7.l
	v_lshrrev_b16 v7.l, 6, v7.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v14, v14
	v_and_b16 v15.l, v7.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v13.l, v13.l, 3
	v_cvt_f32_ubyte0_e32 v7, v7
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v14, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v14, v15
	v_cvt_f32_ubyte0_e32 v13, v13
	v_fma_mix_f32 v7, v12, v7, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v8, s40, v9
	v_fma_mix_f32 v9, v10, v14, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v10, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v8, s41, v9
	v_fmac_f32_e32 v8, s42, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, s43, v7
	s_cbranch_scc0 .LBB2_72
.LBB2_73:                               ; %Flow2485
	s_or_b32 exec_lo, exec_lo, s22
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v8
	ds_store_b32 v4, v1 offset:1536
.LBB2_74:                               ; %Flow2486
	s_or_b32 exec_lo, exec_lo, s37
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB2_76
; %bb.75:
	ds_load_b32 v1, v4 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB2_76:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s3
	s_cbranch_execz .LBB2_78
; %bb.77:
	ds_load_b32 v2, v4 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB2_78:
	s_or_b32 exec_lo, exec_lo, s11
	ds_store_b32 v6, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s4
	s_cbranch_execz .LBB2_80
; %bb.79:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_80:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s5
	s_cbranch_execz .LBB2_82
; %bb.81:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_82:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s6
	s_cbranch_execz .LBB2_84
; %bb.83:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_84:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s7
	s_cbranch_execz .LBB2_86
; %bb.85:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_86:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s8
	s_cbranch_execz .LBB2_88
; %bb.87:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_88:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s9
	s_cbranch_execz .LBB2_90
; %bb.89:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_90:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s0
	s_cbranch_execz .LBB2_92
; %bb.91:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v6, v1
.LBB2_92:
	s_or_b32 exec_lo, exec_lo, s11
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:6912
	s_and_saveexec_b32 s11, s1
	s_cbranch_execz .LBB2_94
; %bb.93:
	ds_load_b32 v1, v4 offset:1024
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v5, 0x3fb8aa3b, v1
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v1
	v_fma_f32 v7, 0x3fb8aa3b, v1, -v5
	v_rndne_f32_e32 v8, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmamk_f32 v7, v1, 0x32a5705f, v7
	v_sub_f32_e32 v5, v5, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add_f32_e32 v5, v5, v7
	v_cvt_i32_f32_e32 v7, v8
	v_exp_f32_e32 v5, v5
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ldexp_f32 v5, v5, v7
	v_cndmask_b32_e32 v5, 0, v5, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v1
	s_delay_alu instid0(VALU_DEP_2)
	v_cndmask_b32_e32 v1, 0x7f800000, v5, vcc_lo
	ds_store_b32 v3, v1 offset:1024
.LBB2_94:
	s_or_b32 exec_lo, exec_lo, s11
	s_and_saveexec_b32 s11, s3
	s_cbranch_execz .LBB2_96
; %bb.95:
	ds_load_b32 v4, v4 offset:1536
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v2, v4, v2
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
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v1, v1, v2
	ds_store_b32 v3, v2 offset:1536
.LBB2_96:
	s_or_b32 exec_lo, exec_lo, s11
	ds_store_b32 v6, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s11, s4
	s_cbranch_execz .LBB2_98
; %bb.97:
	ds_load_2addr_stride64_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_98:
	s_or_b32 exec_lo, exec_lo, s11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s5
	s_cbranch_execz .LBB2_100
; %bb.99:
	ds_load_2addr_b32 v[1:2], v6 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_100:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s6
	s_cbranch_execz .LBB2_102
; %bb.101:
	ds_load_2addr_b32 v[1:2], v6 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_102:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s7
	s_cbranch_execz .LBB2_104
; %bb.103:
	ds_load_2addr_b32 v[1:2], v6 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_104:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s8
	s_cbranch_execz .LBB2_106
; %bb.105:
	ds_load_2addr_b32 v[1:2], v6 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_106:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s9
	s_cbranch_execz .LBB2_108
; %bb.107:
	ds_load_2addr_b32 v[1:2], v6 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_108:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB2_110
; %bb.109:
	ds_load_2addr_b32 v[1:2], v6 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v6, v1
.LBB2_110:
	s_or_b32 exec_lo, exec_lo, s4
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:6912
	s_and_saveexec_b32 s4, s1
	s_cbranch_execz .LBB2_112
; %bb.111:
	ds_load_b32 v2, v3 offset:1024
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v6, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v5
	v_div_scale_f32 v6, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v7, v6, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v4, v7, v6
	v_fmac_f32_e32 v7, v8, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v7, v6
	v_div_fmas_f32 v4, v4, v5, v7
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v2, v4, v1, v2
	ds_store_b32 v3, v2 offset:1024
.LBB2_112:
	s_or_b32 exec_lo, exec_lo, s4
	s_and_saveexec_b32 s1, s3
	s_cbranch_execz .LBB2_114
; %bb.113:
	ds_load_b32 v2, v3 offset:1536
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v4, null, v1, v1, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v5, v4
	v_fma_f32 v6, -v4, v5, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v5, v6, v5
	v_div_scale_f32 v6, vcc_lo, v2, v1, v2
	v_mul_f32_e32 v7, v6, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v8, -v4, v7, v6
	v_fmac_f32_e32 v7, v8, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v4, -v4, v7, v6
	v_div_fmas_f32 v4, v4, v5, v7
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v1, v4, v1, v2
	ds_store_b32 v3, v1 offset:1536
.LBB2_114:                              ; %.preheader284
	s_or_b32 exec_lo, exec_lo, s1
	v_cmp_gt_u32_e64 s1, s21, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB2_117
; %bb.115:                              ; %.lr.ph.preheader
	v_lshl_or_b32 v1, v0, 2, 0x1000
	v_mov_b32_e32 v2, 0
	v_mov_b32_e32 v4, v0
	s_mov_b32 s4, 0
.LBB2_116:                              ; %.lr.ph
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v4, 0x80, v4
	ds_store_b32 v1, v2
	v_add_nc_u32_e32 v1, 0x200, v1
	v_cmp_le_u32_e32 vcc_lo, s21, v4
	s_or_b32 s4, vcc_lo, s4
	s_and_not1_b32 exec_lo, exec_lo, s4
	s_cbranch_execnz .LBB2_116
.LBB2_117:                              ; %Flow2481
	s_or_b32 exec_lo, exec_lo, s3
	v_cmp_gt_u32_e64 s3, s24, v0
	v_lshl_add_u32 v4, v0, 2, 0x1d00
	s_and_saveexec_b32 s4, s3
; %bb.118:
	v_mov_b32_e32 v1, 0
	ds_store_b32 v4, v1
; %bb.119:
	s_or_b32 exec_lo, exec_lo, s4
	s_cmp_gt_u32 s31, 33
	s_mul_i32 s8, s21, 0x180
	s_cselect_b32 s4, -1, 0
	s_cmp_lg_u32 s31, s30
	v_cndmask_b32_e64 v5, 0, 1, s4
	s_cselect_b32 s14, -1, 0
	s_lshl_b32 s9, s24, 11
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s0
	s_cbranch_execz .LBB2_130
; %bb.120:                              ; %.preheader282
	s_and_not1_b32 vcc_lo, exec_lo, s4
	s_cbranch_vccnz .LBB2_127
; %bb.121:                              ; %.lr.ph304.preheader
	s_cmp_lt_u32 s30, 8
	s_mov_b32 s4, 0
	s_cbranch_scc1 .LBB2_124
; %bb.122:                              ; %.lr.ph304.preheader.new
	s_lshl_b32 s4, s27, 16
	s_lshl_b32 s5, s25, 8
	s_mov_b32 s15, 0
	s_or_b32 s4, s4, s5
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s4, s4, s29
	s_lshl_b32 s4, s4, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s5, s4, 31
	s_add_u32 s4, s8, s4
	s_addc_u32 s5, 0, s5
	s_add_u32 s7, s12, s4
	s_addc_u32 s11, s13, s5
	s_add_i32 s4, s26, s25
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e64 v1, s4, 33 clamp
	v_readfirstlane_b32 s4, v1
	v_mov_b32_e32 v1, 0
	s_max_u32 s4, s4, 1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s22, s4, 0xfff8
	s_mov_b64 s[4:5], 0
.LBB2_123:                              ; %.lr.ph304
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s34, s7, s4
	s_addc_u32 s35, s11, s5
	v_mov_b32_e32 v10, s15
	global_load_b64 v[14:15], v1, s[34:35] offset:5
	s_add_u32 s4, s4, 8
	s_addc_u32 s5, s5, 0
	s_add_i32 s15, s15, 32
	s_cmp_eq_u32 s22, s4
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v2, 0xff, v14
	v_lshrrev_b32_e32 v17, 6, v14
	s_delay_alu instid0(VALU_DEP_2)
	v_lshlrev_b32_e32 v2, 2, v2
	ds_load_b128 v[6:9], v10
	ds_load_b32 v16, v2 offset:4096
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v6, v6, v16
	v_and_b32_e32 v16, 0x3fc, v17
	ds_store_b32 v2, v6 offset:4096
	ds_load_b32 v2, v16 offset:4096
	v_lshrrev_b32_e32 v6, 14, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_and_b32_e32 v6, 0x3fc, v6
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v7, v2
	v_lshrrev_b32_e32 v7, 22, v14
	ds_store_b32 v16, v2 offset:4096
	ds_load_b32 v2, v6 offset:4096
	v_and_b32_e32 v7, 0x3fc, v7
	ds_load_b128 v[10:13], v10 offset:16
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v2, v8, v2
	ds_store_b32 v6, v2 offset:4096
	ds_load_b32 v2, v7 offset:4096
	v_and_b32_e32 v6, 0xff, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_lshlrev_b32_e32 v6, 2, v6
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v9, v2
	ds_store_b32 v7, v2 offset:4096
	ds_load_b32 v2, v6 offset:4096
	v_lshrrev_b32_e32 v7, 6, v15
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_dual_add_f32 v2, v10, v2 :: v_dual_and_b32 v7, 0x3fc, v7
	ds_store_b32 v6, v2 offset:4096
	ds_load_b32 v2, v7 offset:4096
	v_lshrrev_b32_e32 v6, 14, v15
	v_and_b32_e32 v6, 0x3fc, v6
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v11, v2
	ds_store_b32 v7, v2 offset:4096
	ds_load_b32 v2, v6 offset:4096
	v_lshrrev_b32_e32 v7, 22, v15
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v2, v12, v2 :: v_dual_and_b32 v7, 0x3fc, v7
	ds_store_b32 v6, v2 offset:4096
	ds_load_b32 v2, v7 offset:4096
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v2, v13, v2
	ds_store_b32 v7, v2 offset:4096
	s_cbranch_scc0 .LBB2_123
.LBB2_124:                              ; %.preheader280.loopexit.unr-lcssa
	s_max_u32 s5, s30, 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s5, s5, 7
	s_cmp_eq_u32 s5, 0
	s_cbranch_scc1 .LBB2_127
; %bb.125:                              ; %.lr.ph304.epil.preheader
	s_lshl_b32 s5, s27, 16
	s_lshl_b32 s7, s25, 8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_or_b32 s5, s5, s7
	s_lshl_b32 s7, s4, 2
	s_sub_i32 s5, s5, s29
	s_lshl_b32 s5, s5, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s11, s5, 31
	s_add_u32 s5, s8, s5
	s_addc_u32 s11, 0, s11
	s_add_u32 s4, s5, s4
	s_addc_u32 s5, s11, 0
	s_add_u32 s4, s12, s4
	s_addc_u32 s5, s13, s5
	s_add_u32 s4, s4, 5
	s_addc_u32 s5, s5, 0
	s_add_i32 s11, s26, s25
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_nc_u32_e64 v1, s11, 33 clamp
	v_readfirstlane_b32 s11, v1
	v_mov_b32_e32 v1, 0
	s_max_u32 s11, s11, 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s11, s11, 7
	s_lshl_b32 s11, s11, 2
	.p2align	6
.LBB2_126:                              ; %.lr.ph304.epil
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v2, v1, s[4:5]
	v_mov_b32_e32 v6, s7
	s_add_i32 s7, s7, 4
	s_add_u32 s4, s4, 1
	s_addc_u32 s5, s5, 0
	s_add_i32 s11, s11, -4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lg_u32 s11, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v2, 2, v2
	ds_load_b32 v6, v6
	ds_load_b32 v7, v2 offset:4096
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v6, v6, v7
	ds_store_b32 v2, v6 offset:4096
	s_cbranch_scc1 .LBB2_126
.LBB2_127:                              ; %.preheader280
	s_and_not1_b32 vcc_lo, exec_lo, s14
	s_cbranch_vccnz .LBB2_130
; %bb.128:                              ; %.lr.ph306.preheader
	s_add_i32 s4, s26, s25
	v_mov_b32_e32 v1, 0
	s_min_u32 s7, s4, 33
	s_add_u32 s5, s9, s8
	s_addc_u32 s11, 0, 0
	s_lshl_b32 s15, s27, 16
	s_lshl_b32 s22, s25, 8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s15, s15, s22
	s_sub_i32 s15, s15, s29
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b32 s15, s15, 3
	s_ashr_i32 s22, s15, 31
	s_add_u32 s5, s5, s15
	s_addc_u32 s11, s11, s22
	s_sub_i32 s15, s4, s7
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s4, s5, s15
	s_addc_u32 s5, s11, 0
	s_add_u32 s4, s12, s4
	s_addc_u32 s5, s13, s5
	s_add_u32 s4, s4, 5
	s_addc_u32 s5, s5, 0
	s_lshl_b32 s11, s15, 2
	.p2align	6
.LBB2_129:                              ; %.lr.ph306
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v2, v1, s[4:5]
	v_mov_b32_e32 v6, s11
	s_add_i32 s7, s7, -1
	s_add_u32 s4, s4, 1
	s_addc_u32 s5, s5, 0
	s_add_i32 s11, s11, 4
	s_cmp_lg_u32 s7, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v2, 2, v2
	ds_load_b32 v6, v6
	ds_load_b32 v7, v2 offset:7424
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v6, v6, v7
	ds_store_b32 v2, v6 offset:7424
	s_cbranch_scc1 .LBB2_129
.LBB2_130:                              ; %Flow2479
	s_or_b32 exec_lo, exec_lo, s6
	v_lshlrev_b32_e32 v6, 1, v0
	v_lshrrev_b32_e32 v1, 3, v0
	s_cmp_lg_u32 s21, 0
	s_mul_i32 s15, s2, 48
	v_lshrrev_b32_e32 v8, 2, v0
	v_dual_mov_b32 v10, 0 :: v_dual_and_b32 v7, 6, v6
	v_and_b32_e32 v9, 0x7c, v1
	s_cselect_b32 s23, -1, 0
	s_ashr_i32 s22, s15, 31
	s_mov_b32 s6, 0
	s_cmp_eq_u32 s21, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB2_138
; %bb.131:                              ; %.lr.ph310.preheader
	s_cmp_lt_u32 s21, 4
	s_cbranch_scc1 .LBB2_135
; %bb.132:                              ; %.lr.ph310.preheader.new
	s_lshl_b32 s4, s27, 16
	s_lshl_b32 s5, s25, 8
	v_mov_b32_e32 v10, 0
	s_or_b32 s4, s4, s5
	s_movk_i32 s11, 0x1000
	s_sub_i32 s4, s4, s29
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b32 s4, s4, 3
	s_ashr_i32 s5, s4, 31
	s_add_u32 s4, s12, s4
	s_addc_u32 s5, s13, s5
	s_add_u32 s4, s4, s15
	s_addc_u32 s5, s5, s22
	v_add_co_u32 v1, s7, s4, v9
	v_add_co_u32 v11, s4, s4, v8
	v_add_co_ci_u32_e64 v2, null, s5, 0, s7
	v_add_co_ci_u32_e64 v12, null, s5, 0, s4
	s_bfe_u32 s6, s20, 0x60002
	s_mov_b64 s[4:5], 0
	s_mul_i32 s7, s6, 0x600
	s_mov_b32 s6, 0
.LBB2_133:                              ; %.lr.ph310
                                        ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v13, vcc_lo, v11, s4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, s5, v12, vcc_lo
	v_add_co_u32 v15, vcc_lo, v1, s4
	v_add_co_ci_u32_e64 v16, null, s5, v2, vcc_lo
	s_clause 0x7
	global_load_u8 v17, v[13:14], off offset:5
	global_load_u8 v18, v[13:14], off offset:389
	global_load_b32 v19, v[15:16], off offset:37
	global_load_u8 v20, v[13:14], off offset:773
	global_load_b32 v21, v[15:16], off offset:421
	global_load_b32 v22, v[15:16], off offset:805
	global_load_b32 v23, v[15:16], off offset:1189
	global_load_u8 v24, v[13:14], off offset:1157
	s_add_i32 s6, s6, 4
	s_add_u32 s4, s4, 0x600
	s_addc_u32 s5, s5, 0
	s_waitcnt vmcnt(6)
	v_bfe_u32 v18, v18, v7, 2
	s_waitcnt vmcnt(4)
	v_bfe_u32 v20, v20, v7, 2
	v_bfe_u32 v17, v17, v7, 2
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v18, v18
	v_cvt_f32_ubyte0_e32 v20, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v17, v17
	s_waitcnt vmcnt(3)
	v_fma_mix_f32 v18, v21, v18, v21 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_mov_b32_e32 v13, s11
	s_add_i32 s11, s11, 16
	s_cmp_eq_u32 s7, s4
	v_fma_mix_f32 v17, v19, v17, v19 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt vmcnt(0)
	v_bfe_u32 v19, v24, v7, 2
	ds_load_b128 v[13:16], v13
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v10, v13, v17
	v_cvt_f32_ubyte0_e32 v13, v19
	v_fma_mix_f32 v17, v22, v20, v22 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v10, v14, v18
	v_fma_mix_f32 v13, v23, v13, v23 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v10, v15, v17
	v_fmac_f32_e32 v10, v16, v13
	s_cbranch_scc0 .LBB2_133
; %bb.134:                              ; %.preheader279.loopexit.unr-lcssa
	s_and_b32 s4, s21, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s4, 0
	s_cbranch_scc0 .LBB2_136
	s_branch .LBB2_138
.LBB2_135:
	v_mov_b32_e32 v10, 0
	s_and_b32 s4, s21, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s4, 0
	s_cbranch_scc1 .LBB2_138
.LBB2_136:                              ; %.lr.ph310.epil.preheader
	s_lshl_b32 s4, s27, 16
	s_lshl_b32 s5, s25, 8
	s_lshl_b32 s7, s6, 2
	s_or_b32 s4, s4, s5
	s_addk_i32 s7, 0x1000
	s_sub_i32 s4, s4, s29
	s_mul_hi_u32 s5, s6, 0x180
	s_lshl_b32 s4, s4, 3
	s_mulk_i32 s6, 0x180
	s_ashr_i32 s11, s4, 31
	s_add_u32 s4, s12, s4
	s_addc_u32 s11, s13, s11
	s_add_u32 s4, s4, s15
	s_addc_u32 s11, s11, s22
	s_add_u32 s4, s4, s6
	s_addc_u32 s5, s11, s5
	v_add_co_u32 v11, s6, s4, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v12, null, s5, 0, s6
	v_add_co_u32 v1, s4, s4, v9
	v_add_co_u32 v11, vcc_lo, v11, 5
	v_add_co_ci_u32_e64 v2, null, s5, 0, s4
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_add_co_ci_u32_e64 v12, null, 0, v12, vcc_lo
	s_and_b32 s4, s20, 3
	s_mul_i32 s6, s4, 0x180
	s_mov_b64 s[4:5], 0
	.p2align	6
.LBB2_137:                              ; %.lr.ph310.epil
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v13, vcc_lo, v11, s4
	v_add_co_ci_u32_e64 v14, null, s5, v12, vcc_lo
	global_load_u8 v15, v[13:14], off
	v_add_co_u32 v13, vcc_lo, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, s5, v2, vcc_lo
	global_load_b32 v13, v[13:14], off offset:37
	v_mov_b32_e32 v14, s7
	s_add_i32 s7, s7, 4
	s_add_u32 s4, s4, 0x180
	s_addc_u32 s5, s5, 0
	s_cmp_lg_u32 s6, s4
	ds_load_b32 v14, v14
	s_waitcnt vmcnt(1)
	v_bfe_u32 v15, v15, v7, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v15, v15
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v13, v13, v15, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v10, v14, v13
	s_cbranch_scc1 .LBB2_137
.LBB2_138:                              ; %.preheader279
	s_and_b32 s5, s28, 0xff
	s_mov_b32 s4, 0
	s_cmp_lg_u32 s5, 0
	s_cselect_b32 s20, -1, 0
	s_ashr_i32 s11, s10, 31
	s_cmp_eq_u32 s5, 0
	s_cbranch_scc1 .LBB2_145
; %bb.139:                              ; %.lr.ph315.preheader
	s_cmp_lt_u32 s5, 8
	s_cbranch_scc1 .LBB2_142
; %bb.140:                              ; %.lr.ph315.preheader.new
	s_add_i32 s6, s26, s25
	s_lshl_b32 s4, s27, 16
	v_sub_nc_u32_e64 v1, s6, 33 clamp
	s_lshl_b32 s5, s25, 8
	s_mov_b64 s[6:7], 0
	s_or_b32 s4, s4, s5
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	s_sub_i32 s4, s4, s29
	v_add_co_u32 v1, s5, s12, v1
	v_add_co_ci_u32_e64 v2, null, s13, 0, s5
	s_lshl_b32 s4, s4, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	s_ashr_i32 s5, s4, 31
	v_add_co_u32 v1, vcc_lo, v1, s4
	v_add_co_ci_u32_e64 v2, null, s5, v2, vcc_lo
	s_lshl_b32 s5, s28, 11
	v_add_co_u32 v1, vcc_lo, v1, s10
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s11, v2, vcc_lo
	s_mov_b32 s4, 0
	v_add_co_u32 v1, vcc_lo, v1, s8
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_and_b32 s5, s5, 0x7c000
	v_add_co_u32 v1, vcc_lo, v1, v6
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_movk_i32 s28, 0x1d00
.LBB2_141:                              ; %.lr.ph315
                                        ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v11, vcc_lo, v1, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s7, v2, vcc_lo
	s_add_i32 s4, s4, 8
	v_add_co_u32 v13, vcc_lo, 0x1000, v11
	global_load_u16 v17, v[11:12], off offset:5
	v_add_co_ci_u32_e64 v14, null, 0, v12, vcc_lo
	v_add_co_u32 v15, vcc_lo, 0x2000, v11
	s_clause 0x1
	global_load_u16 v19, v[11:12], off offset:2053
	global_load_u16 v20, v[13:14], off offset:5
	v_add_co_ci_u32_e64 v16, null, 0, v12, vcc_lo
	s_clause 0x1
	global_load_u16 v21, v[13:14], off offset:2053
	global_load_u16 v22, v[15:16], off offset:5
	v_add_co_u32 v11, vcc_lo, 0x3000, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, 0, v12, vcc_lo
	s_clause 0x2
	global_load_u16 v23, v[15:16], off offset:2053
	global_load_u16 v24, v[11:12], off offset:5
	global_load_u16 v25, v[11:12], off offset:2053
	v_mov_b32_e32 v15, s28
	s_add_u32 s6, s6, 0x4000
	s_addc_u32 s7, s7, 0
	s_add_i32 s28, s28, 32
	s_cmp_eq_u32 s5, s6
	s_waitcnt vmcnt(7)
	v_lshlrev_b32_e32 v26, 16, v17
	ds_load_b128 v[11:14], v15
	ds_load_b128 v[15:18], v15 offset:16
	s_waitcnt vmcnt(6) lgkmcnt(1)
	v_dual_fmac_f32 v10, v11, v26 :: v_dual_lshlrev_b32 v19, 16, v19
	s_waitcnt vmcnt(5)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v10, v12, v19 :: v_dual_lshlrev_b32 v11, 16, v20
	s_waitcnt vmcnt(4)
	v_lshlrev_b32_e32 v12, 16, v21
	s_waitcnt vmcnt(3)
	v_dual_fmac_f32 v10, v13, v11 :: v_dual_lshlrev_b32 v11, 16, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v10, v14, v12
	s_waitcnt vmcnt(2)
	v_lshlrev_b32_e32 v12, 16, v23
	s_waitcnt vmcnt(1) lgkmcnt(0)
	v_dual_fmac_f32 v10, v15, v11 :: v_dual_lshlrev_b32 v11, 16, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v10, v16, v12
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v12, 16, v25
	v_fmac_f32_e32 v10, v17, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v10, v18, v12
	s_cbranch_scc0 .LBB2_141
.LBB2_142:                              ; %._crit_edge316.loopexit.unr-lcssa
	s_and_b32 s6, s24, 7
	s_mov_b32 s5, 0
	s_cmp_eq_u32 s6, 0
	s_cbranch_scc1 .LBB2_145
; %bb.143:                              ; %.lr.ph315.epil.preheader
	s_lshl_b64 s[30:31], s[4:5], 11
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s5, s30, s8
	s_addc_u32 s7, s31, 0
	s_add_i32 s31, s26, s25
	s_lshl_b32 s28, s27, 16
	v_sub_nc_u32_e64 v1, s31, 33 clamp
	s_lshl_b32 s30, s25, 8
	s_lshl_b32 s4, s4, 2
	s_or_b32 s28, s28, s30
	s_addk_i32 s4, 0x1d00
	v_add_co_u32 v1, s30, s12, v1
	s_sub_i32 s28, s28, s29
	v_add_co_ci_u32_e64 v2, null, s13, 0, s30
	s_lshl_b32 s28, s28, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	s_ashr_i32 s30, s28, 31
	v_add_co_u32 v1, vcc_lo, v1, s28
	v_add_co_ci_u32_e64 v2, null, s30, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v1, s10
	v_add_co_ci_u32_e64 v2, null, s11, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v1, s5
	v_add_co_ci_u32_e64 v2, null, s7, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v1, v6
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v1, 5
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
.LBB2_144:                              ; %.lr.ph315.epil
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u16 v11, v[1:2], off
	v_mov_b32_e32 v12, s4
	v_add_co_u32 v1, vcc_lo, 0x800, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_i32 s6, s6, -1
	s_add_i32 s4, s4, 4
	s_cmp_lg_u32 s6, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v11, 16, v11
	ds_load_b32 v12, v12
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v10, v12, v11
	s_cbranch_scc1 .LBB2_144
.LBB2_145:                              ; %._crit_edge316
	ds_store_b32 v3, v10 offset:5888
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s1
	s_cbranch_execz .LBB2_148
; %bb.146:                              ; %.lr.ph.1.preheader
	v_lshl_add_u32 v1, v0, 2, 0x1380
	v_mov_b32_e32 v2, 0
	v_mov_b32_e32 v10, v0
	s_mov_b32 s1, 0
.LBB2_147:                              ; %.lr.ph.1
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	v_add_nc_u32_e32 v10, 0x80, v10
	ds_store_b32 v1, v2
	v_add_nc_u32_e32 v1, 0x200, v1
	v_cmp_le_u32_e32 vcc_lo, s21, v10
	s_or_b32 s1, vcc_lo, s1
	s_and_not1_b32 exec_lo, exec_lo, s1
	s_cbranch_execnz .LBB2_147
.LBB2_148:                              ; %Flow2461
	s_or_b32 exec_lo, exec_lo, s4
	v_add_nc_u32_e32 v3, 0x1700, v3
	s_and_saveexec_b32 s1, s3
; %bb.149:
	v_mov_b32_e32 v1, 0
	ds_store_b32 v4, v1 offset:132
; %bb.150:
	s_or_b32 exec_lo, exec_lo, s1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB2_157
; %bb.151:                              ; %.preheader282.1
	v_cmp_ne_u32_e32 vcc_lo, 1, v5
	s_cbranch_vccnz .LBB2_154
; %bb.152:                              ; %.lr.ph304.1.preheader
	s_add_i32 s0, s26, s25
	s_lshl_b32 s1, s27, 16
	s_lshl_b32 s4, s25, 8
	v_sub_nc_u32_e64 v1, s0, 33 clamp
	s_or_b32 s0, s1, s4
	v_mov_b32_e32 v2, 0
	s_sub_i32 s0, s0, s29
	s_movk_i32 s4, 0x400
	s_lshl_b32 s0, s0, 3
	v_max_u32_e32 v1, 1, v1
	s_ashr_i32 s1, s0, 31
	s_add_u32 s0, s8, s0
	s_addc_u32 s1, 0, s1
	s_add_u32 s0, s12, s0
	v_sub_nc_u32_e32 v1, 0, v1
	s_addc_u32 s1, s13, s1
	s_add_u32 s0, s0, 5
	s_addc_u32 s1, s1, 0
	.p2align	6
.LBB2_153:                              ; %.lr.ph304.1
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v4, v2, s[0:1]
	v_mov_b32_e32 v5, s4
	v_add_co_u32 v1, s5, v1, 1
	s_add_i32 s4, s4, 4
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_and_not1_b32 vcc_lo, exec_lo, s5
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v4, 2, v4
	ds_load_b32 v5, v5
	ds_load_b32 v10, v4 offset:4992
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v5, v5, v10
	ds_store_b32 v4, v5 offset:4992
	s_cbranch_vccnz .LBB2_153
.LBB2_154:                              ; %.preheader280.1
	s_and_not1_b32 vcc_lo, exec_lo, s14
	s_cbranch_vccnz .LBB2_157
; %bb.155:                              ; %.lr.ph306.1
	s_add_i32 s0, s26, s25
	v_mov_b32_e32 v1, 0
	s_min_u32 s4, s0, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s0, s0, s4
	s_lshl_b32 s1, s0, 2
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	s_add_i32 s5, s1, 0x400
	s_add_u32 s1, s9, s8
	s_addc_u32 s6, 0, 0
	s_lshl_b32 s7, s27, 16
	s_lshl_b32 s9, s25, 8
	s_or_b32 s7, s7, s9
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s7, s7, s29
	s_lshl_b32 s7, s7, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s9, s7, 31
	s_add_u32 s1, s1, s7
	s_addc_u32 s6, s6, s9
	s_add_u32 s0, s1, s0
	s_addc_u32 s1, s6, 0
	s_add_u32 s0, s12, s0
	s_addc_u32 s1, s13, s1
	s_add_u32 s0, s0, 5
	s_addc_u32 s1, s1, 0
	.p2align	6
.LBB2_156:                              ; =>This Inner Loop Header: Depth=1
	global_load_u8 v2, v1, s[0:1]
	v_mov_b32_e32 v4, s5
	s_add_i32 s5, s5, 4
	s_add_i32 s4, s4, -1
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s4, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v2, 2, v2
	ds_load_b32 v4, v4
	ds_load_b32 v5, v2 offset:7556
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v4, v4, v5
	ds_store_b32 v2, v4 offset:7556
	s_cbranch_scc1 .LBB2_156
.LBB2_157:                              ; %Flow2459
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s23
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_cbranch_vccnz .LBB2_161
; %bb.158:                              ; %.lr.ph310.1.preheader
	s_lshl_b32 s0, s27, 16
	s_lshl_b32 s1, s25, 8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s0, s0, s1
	s_sub_i32 s0, s0, s29
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b32 s0, s0, 3
	s_ashr_i32 s1, s0, 31
	s_add_u32 s0, s12, s0
	s_addc_u32 s1, s13, s1
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, s22
	v_add_co_u32 v4, s3, s0, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v8, null, s1, 0, s3
	v_add_co_u32 v1, s0, s0, v9
	v_add_co_u32 v5, vcc_lo, v4, 5
	v_add_co_ci_u32_e64 v2, null, s1, 0, s0
	s_delay_alu instid0(VALU_DEP_4)
	v_add_co_ci_u32_e64 v8, null, 0, v8, vcc_lo
	v_mov_b32_e32 v4, 0
	s_movk_i32 s3, 0x1380
	s_mov_b64 s[0:1], 0
	.p2align	6
.LBB2_159:                              ; %.lr.ph310.1
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v5, s0
	v_add_co_ci_u32_e64 v10, null, s1, v8, vcc_lo
	global_load_u8 v11, v[9:10], off
	v_add_co_u32 v9, vcc_lo, v1, s0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s1, v2, vcc_lo
	global_load_b32 v9, v[9:10], off offset:37
	v_mov_b32_e32 v10, s3
	s_add_i32 s3, s3, 4
	s_add_u32 s0, s0, 0x180
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s8, s0
	ds_load_b32 v10, v10
	s_waitcnt vmcnt(1)
	v_bfe_u32 v11, v11, v7, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v11, v11
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v11, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v10, v9
	s_cbranch_scc1 .LBB2_159
; %bb.160:                              ; %.preheader279.1
	s_and_not1_b32 vcc_lo, exec_lo, s20
	s_cbranch_vccz .LBB2_162
	s_branch .LBB2_164
.LBB2_161:
	v_mov_b32_e32 v4, 0
	s_and_not1_b32 vcc_lo, exec_lo, s20
	s_cbranch_vccnz .LBB2_164
.LBB2_162:                              ; %.lr.ph315.1.preheader
	s_add_i32 s26, s26, s25
	s_lshl_b32 s0, s27, 16
	v_sub_nc_u32_e64 v1, s26, 33 clamp
	s_lshl_b32 s1, s25, 8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s0, s0, s1
	s_sub_i32 s0, s0, s29
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s1, s12, v1
	v_add_co_ci_u32_e64 v2, null, s13, 0, s1
	s_lshl_b32 s0, s0, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	s_ashr_i32 s1, s0, 31
	v_add_co_u32 v1, vcc_lo, v1, s0
	v_add_co_ci_u32_e64 v2, null, s1, v2, vcc_lo
	s_movk_i32 s0, 0x1d84
	v_add_co_u32 v1, vcc_lo, v1, s10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, s11, v2, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, s8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v1, vcc_lo, v1, 5
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
.LBB2_163:                              ; %.lr.ph315.1
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u16 v5, v[1:2], off
	v_mov_b32_e32 v6, s0
	v_add_co_u32 v1, vcc_lo, 0x800, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_i32 s24, s24, -1
	s_add_i32 s0, s0, 4
	s_cmp_lg_u32 s24, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v5, 16, v5
	ds_load_b32 v6, v6
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v4, v6, v5
	s_cbranch_scc1 .LBB2_163
.LBB2_164:                              ; %._crit_edge316.1
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 12, v0
	ds_store_b32 v3, v4 offset:512
	s_mov_b64 s[4:5], 0
	s_movk_i32 s3, 0x1700
	v_add_co_u32 v3, s0, s16, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s17, 0, s0
	s_lshl_b64 s[0:1], s[10:11], 1
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v3, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v4, null, s1, v4, vcc_lo
	s_barrier
	buffer_gl0_inv
	s_barrier
	buffer_gl0_inv
.LBB2_165:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v9, vcc_lo, v3, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s5, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off
	global_load_b128 v[9:12], v[9:10], off offset:16
	v_mov_b32_e32 v21, s3
	s_add_i32 s3, s3, 64
	s_cmpk_eq_i32 s4, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	v_and_b32_e32 v5, 0xffff0000, v5
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v22, v13
	v_lshlrev_b32_e32 v13, 16, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v1, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	v_and_b32_e32 v5, 0xffff0000, v7
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v6, v17 :: v_dual_lshlrev_b32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v9, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v18
	v_and_b32_e32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v1, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v17, v13
	v_lshlrev_b32_e32 v13, 16, v10
	v_fmac_f32_e32 v1, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v13, v15
	v_fmac_f32_e32 v1, v9, v16
	v_and_b32_e32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v10, v5
	v_lshlrev_b32_e32 v5, 16, v12
	v_dual_fmac_f32 v1, v9, v6 :: v_dual_and_b32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v7
	v_fmac_f32_e32 v1, v6, v8
	s_cbranch_scc0 .LBB2_165
; %bb.166:                              ; %.preheader.1
	s_movk_i32 s3, 0x1900
	s_mov_b64 s[4:5], 0
.LBB2_167:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v3, s4
	v_add_co_ci_u32_e64 v10, null, s5, v4, vcc_lo
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off offset:256
	global_load_b128 v[9:12], v[9:10], off offset:272
	v_mov_b32_e32 v21, s3
	s_add_i32 s3, s3, 64
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_lg_i32 s4, 0x100
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v22, 16, v5
	ds_load_b128 v[13:16], v21
	ds_load_b128 v[17:20], v21 offset:16
	v_and_b32_e32 v5, 0xffff0000, v5
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v22, v13
	v_lshlrev_b32_e32 v13, 16, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v1, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v1, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v16
	ds_load_b128 v[13:16], v21 offset:32
	v_and_b32_e32 v5, 0xffff0000, v7
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v1, v6, v17 :: v_dual_lshlrev_b32 v6, 16, v8
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v9, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v18
	v_and_b32_e32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v1, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v5, v20
	ds_load_b128 v[5:8], v21 offset:48
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v1, v17, v13
	v_lshlrev_b32_e32 v13, 16, v10
	v_fmac_f32_e32 v1, v9, v14
	v_and_b32_e32 v9, 0xffff0000, v10
	v_lshlrev_b32_e32 v10, 16, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v13, v15
	v_fmac_f32_e32 v1, v9, v16
	v_and_b32_e32 v9, 0xffff0000, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, v10, v5
	v_lshlrev_b32_e32 v5, 16, v12
	v_dual_fmac_f32 v1, v9, v6 :: v_dual_and_b32 v6, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v5, v7
	v_fmac_f32_e32 v1, v6, v8
	s_cbranch_scc1 .LBB2_167
; %bb.168:                              ; %.preheader.1367
	s_lshl_b32 s2, s2, 10
	s_add_u32 s0, s16, s0
	v_or_b32_e32 v3, s2, v0
	s_addc_u32 s1, s17, s1
	v_add_co_u32 v2, s0, s0, v2
	s_movk_i32 s3, 0x1700
	v_ashrrev_i32_e32 v4, 31, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], 2, v[3:4]
	v_mov_b32_e32 v4, 0
	v_add_co_ci_u32_e64 v3, null, s1, 0, s0
	s_mov_b64 s[0:1], 0
	v_add_co_u32 v5, vcc_lo, s18, v5
	v_add_co_ci_u32_e64 v6, null, s19, v6, vcc_lo
	global_store_b32 v[5:6], v1, off
.LBB2_169:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v1, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x80000, v1
	v_add_co_ci_u32_e64 v10, null, 0, v5, vcc_lo
	s_addc_u32 s1, s1, 0
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off
	global_load_b128 v[9:12], v[9:10], off offset:16
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v21, 16, v5
	v_mov_b32_e32 v1, s3
	s_add_i32 s3, s3, 64
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[13:16], v1
	ds_load_b128 v[17:20], v1 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v21, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v1 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v6, v17
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v4, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v9
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v17, v13
	v_fmac_f32_e32 v4, v1, v14
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v9, 16, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v9, v15
	v_dual_fmac_f32 v4, v1, v16 :: v_dual_lshlrev_b32 v9, 16, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v9, v5 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_dual_fmac_f32 v4, v1, v6 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v7 :: v_dual_and_b32 v1, 0xffff0000, v12
	v_fmac_f32_e32 v4, v1, v8
	s_cbranch_scc1 .LBB2_169
; %bb.170:                              ; %.preheader.1.1
	s_movk_i32 s3, 0x1900
	s_mov_b64 s[0:1], 0
.LBB2_171:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v5, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x80000, v1
	v_add_co_ci_u32_e64 v10, null, 0, v5, vcc_lo
	s_clause 0x1
	global_load_b128 v[5:8], v[9:10], off offset:256
	global_load_b128 v[9:12], v[9:10], off offset:272
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v21, 16, v5
	v_mov_b32_e32 v1, s3
	s_add_i32 s3, s3, 64
	s_add_u32 s0, s0, 32
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x100
	ds_load_b128 v[13:16], v1
	ds_load_b128 v[17:20], v1 offset:16
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v21, v13 :: v_dual_lshlrev_b32 v13, 16, v6
	v_and_b32_e32 v5, 0xffff0000, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v4, v5, v14
	v_and_b32_e32 v5, 0xffff0000, v6
	v_lshlrev_b32_e32 v6, 16, v7
	v_fmac_f32_e32 v4, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v16
	ds_load_b128 v[13:16], v1 offset:32
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v6, v17
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v17, 16, v9
	v_and_b32_e32 v5, 0xffff0000, v7
	v_lshlrev_b32_e32 v6, 16, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v18 :: v_dual_and_b32 v5, 0xffff0000, v8
	v_fmac_f32_e32 v4, v6, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v5, v20
	ds_load_b128 v[5:8], v1 offset:48
	v_and_b32_e32 v1, 0xffff0000, v9
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v4, v17, v13
	v_fmac_f32_e32 v4, v1, v14
	v_and_b32_e32 v1, 0xffff0000, v10
	v_lshlrev_b32_e32 v9, 16, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v9, v15
	v_dual_fmac_f32 v4, v1, v16 :: v_dual_lshlrev_b32 v9, 16, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v9, v5 :: v_dual_and_b32 v1, 0xffff0000, v11
	v_dual_fmac_f32 v4, v1, v6 :: v_dual_lshlrev_b32 v5, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v5, v7 :: v_dual_and_b32 v1, 0xffff0000, v12
	v_fmac_f32_e32 v4, v1, v8
	s_cbranch_scc1 .LBB2_171
; %bb.172:                              ; %.preheader.2
	s_ashr_i32 s0, s2, 31
	v_add_co_u32 v0, s1, v0, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v1, null, 0, s0, s1
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1700
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s18, v0
	v_add_co_ci_u32_e64 v1, null, s19, v1, vcc_lo
	global_store_b32 v[0:1], v4, off offset:512
.LBB2_173:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x100000, v4
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
	s_cbranch_scc1 .LBB2_173
; %bb.174:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1900
	s_mov_b64 s[0:1], 0
.LBB2_175:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x100000, v4
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
	s_cbranch_scc1 .LBB2_175
; %bb.176:                              ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1700
	global_store_b32 v[0:1], v5, off offset:1024
.LBB2_177:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x180000, v5
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
	s_cbranch_scc1 .LBB2_177
; %bb.178:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1900
	s_mov_b64 s[0:1], 0
.LBB2_179:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x180000, v5
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
	s_cbranch_scc1 .LBB2_179
; %bb.180:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1700
	global_store_b32 v[0:1], v4, off offset:1536
.LBB2_181:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x200000, v4
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
	s_cbranch_scc1 .LBB2_181
; %bb.182:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1900
	s_mov_b64 s[0:1], 0
.LBB2_183:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x200000, v4
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
	s_cbranch_scc1 .LBB2_183
; %bb.184:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1700
	global_store_b32 v[0:1], v5, off offset:2048
.LBB2_185:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x280000, v5
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
	s_cbranch_scc1 .LBB2_185
; %bb.186:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1900
	s_mov_b64 s[0:1], 0
.LBB2_187:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x280000, v5
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
	s_cbranch_scc1 .LBB2_187
; %bb.188:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1700
	global_store_b32 v[0:1], v4, off offset:2560
.LBB2_189:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v4, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v10, vcc_lo, 0x300000, v4
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
	s_cbranch_scc1 .LBB2_189
; %bb.190:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1900
	s_mov_b64 s[0:1], 0
.LBB2_191:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, 0x300000, v4
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
	s_cbranch_scc1 .LBB2_191
; %bb.192:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1700
	global_store_b32 v[0:1], v5, off offset:3072
.LBB2_193:                              ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v5, vcc_lo, v2, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_add_u32 s0, s0, 32
	v_add_co_u32 v9, vcc_lo, 0x380000, v5
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
	s_cbranch_scc1 .LBB2_193
; %bb.194:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1900
	s_mov_b64 s[0:1], 0
.LBB2_195:                              ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v5, vcc_lo, v2, s0
	v_add_co_ci_u32_e64 v6, null, s1, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, 0x380000, v5
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
	s_cbranch_scc1 .LBB2_195
; %bb.196:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
.LBB2_197:                              ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi1EEvPKhPKfPKtPf
		.amdhsa_group_segment_fixed_size 7688
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
		.amdhsa_next_free_vgpr 27
		.amdhsa_next_free_sgpr 48
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
	.section	.text._Z11query_groupILi1EEvPKhPKfPKtPf,"axG",@progbits,_Z11query_groupILi1EEvPKhPKfPKtPf,comdat
.Lfunc_end2:
	.size	_Z11query_groupILi1EEvPKhPKfPKtPf, .Lfunc_end2-_Z11query_groupILi1EEvPKhPKfPKtPf
                                        ; -- End function
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.num_vgpr, 27
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.num_agpr, 0
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.numbered_sgpr, 48
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.num_named_barrier, 0
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.private_seg_size, 0
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.uses_vcc, 1
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.uses_flat_scratch, 0
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.has_dyn_sized_stack, 0
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.has_recursion, 0
	.set _Z11query_groupILi1EEvPKhPKfPKtPf.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 15424
; TotalNumSgprs: 50
; NumVgprs: 27
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 7688 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 50
; NumVGPRsForWavesPerEU: 27
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
	.set amdgpu.max_num_vgpr, 0
	.set amdgpu.max_num_agpr, 0
	.set amdgpu.max_num_sgpr, 0
	.text
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
    .name:           _Z8finish_oPKfPf
    .private_segment_fixed_size: 0
    .sgpr_count:     6
    .sgpr_spill_count: 0
    .symbol:         _Z8finish_oPKfPf.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     12
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
    .group_segment_fixed_size: 5632
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z11query_groupILi0EEvPKhPKfPKtPf
    .private_segment_fixed_size: 0
    .sgpr_count:     50
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi0EEvPKhPKfPKtPf.kd
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
    .group_segment_fixed_size: 7688
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z11query_groupILi1EEvPKhPKfPKtPf
    .private_segment_fixed_size: 0
    .sgpr_count:     50
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi1EEvPKhPKfPKtPf.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     27
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
