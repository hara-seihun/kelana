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
	.section	.text._Z11query_groupILi0EEvPKPKhPKfPKtPfiiii,"axG",@progbits,_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii,comdat
	.protected	_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii ; -- Begin function _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii
	.globl	_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii
	.p2align	8
	.type	_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii,@function
_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii: ; @_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii
; %bb.0:
	s_cmp_gt_i32 s2, 7
	s_cbranch_scc1 .LBB1_166
; %bb.1:
	s_load_b128 s[16:19], s[0:1], 0x20
	s_waitcnt lgkmcnt(0)
	s_lshl_b32 s31, s16, 5
	s_add_i32 s3, s19, s17
	s_add_i32 s6, s18, s31
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lg_u32 s6, s3
	s_cselect_b32 s3, -1, 0
	s_cmpk_gt_i32 s6, 0x100
	s_cselect_b32 s4, -1, 0
	s_cmp_gt_i32 s16, 8
	s_cselect_b32 s5, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s4, s4, s5
	s_or_b32 s3, s4, s3
	s_cmp_gt_i32 s18, 32
	s_cselect_b32 s4, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_or_b32 s3, s4, s3
	s_cmp_gt_i32 s19, 33
	s_cselect_b32 s4, -1, 0
	s_or_b32 s3, s4, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB1_166
; %bb.2:                                ; %.preheader232
	s_load_b256 s[8:15], s[0:1], 0x0
	s_ashr_i32 s3, s2, 31
	v_lshlrev_b32_e32 v1, 7, v0
	s_lshl_b64 s[0:1], s[2:3], 3
	s_mulk_i32 s16, 0x600
	s_mul_i32 s26, s17, 48
	v_lshl_add_u32 v6, v0, 2, 0x800
	v_and_b32_e32 v7, 0xf80, v1
	s_waitcnt lgkmcnt(0)
	s_add_u32 s0, s8, s0
	s_addc_u32 s1, s9, s1
	s_ashr_i32 s27, s16, 31
	s_load_b64 s[22:23], s[0:1], 0x0
	v_cmp_gt_i32_e64 s0, s6, v0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s1, s22, s16
	s_addc_u32 s3, s23, s27
	s_ashr_i32 s28, s26, 31
	s_add_u32 s29, s1, s26
	s_addc_u32 s30, s3, s28
	s_lshl_b32 s20, s2, 8
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB1_10
; %bb.3:
	s_mov_b32 s3, exec_lo
                                        ; implicit-def: $vgpr2
	v_cmpx_le_i32_e64 s31, v0
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB1_6
; %bb.4:                                ; %.preheader230
	v_subrev_nc_u32_e32 v1, s31, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s7, s10, s4
	s_addc_u32 s8, s11, s5
	s_mov_b64 s[4:5], 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v3, vcc_lo, s29, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s30, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_5:                                ; =>This Inner Loop Header: Depth=1
	flat_load_b128 v[8:11], v[3:4]
	s_add_u32 s24, s7, s4
	s_addc_u32 s25, s8, s5
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[24:25], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_lg_i32 s4, 0x200
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_and_b32_e32 v5, 0xffff0000, v8
	v_lshlrev_b32_e32 v1, 16, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, s36, v1
	v_lshlrev_b32_e32 v1, 16, v9
	v_fmac_f32_e32 v2, s37, v5
	v_and_b32_e32 v5, 0xffff0000, v9
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s38, v1 :: v_dual_lshlrev_b32 v1, 16, v10
	v_dual_fmac_f32 v2, s39, v5 :: v_dual_and_b32 v5, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s40, v1 :: v_dual_lshlrev_b32 v1, 16, v11
	v_dual_fmac_f32 v2, s41, v5 :: v_dual_and_b32 v5, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s42, v1
	v_fmac_f32_e32 v2, s43, v5
	s_cbranch_scc1 .LBB1_5
.LBB1_6:                                ; %Flow2050
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s3, s3
	s_cbranch_execz .LBB1_9
; %bb.7:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[20:21], 2
	s_mov_b32 s9, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s7, s22, v1
	v_add_co_ci_u32_e64 v3, null, s23, 0, s7
	s_add_u32 s7, s10, s4
	s_addc_u32 s8, s11, s5
	s_mov_b64 s[4:5], 0
.LBB1_8:                                ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s9, v7
	s_add_u32 s24, s7, s4
	s_addc_u32 s25, s8, s5
	s_add_i32 s9, s9, 4
	s_load_b128 s[36:39], s[24:25], 0x0
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	v_add_co_u32 v8, vcc_lo, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s5, v3, vcc_lo
	flat_load_d16_u8 v4, v[4:5]
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	flat_load_b128 v[8:11], v[8:9] offset:1024
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(1) lgkmcnt(0)
	v_and_b16 v12.l, v4.l, 3
	v_lshrrev_b16 v4.h, 2, v4.l
	v_lshrrev_b16 v5.l, 4, v4.l
	v_lshrrev_b16 v4.l, 6, v4.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v12, v12
	v_and_b16 v13.l, v4.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v5.l, v5.l, 3
	v_cvt_f32_ubyte0_e32 v4, v4
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v8, v12, v8 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v12, v13
	v_cvt_f32_ubyte0_e32 v5, v5
	v_fma_mix_f32 v4, v11, v4, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v2, s36, v8
	v_fma_mix_f32 v8, v9, v12, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_mix_f32 v5, v10, v5, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v2, s37, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s38, v5
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB1_8
.LBB1_9:                                ; %Flow2051
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1
.LBB1_10:                               ; %Flow2052
	s_or_b32 exec_lo, exec_lo, s1
	v_add_nc_u32_e32 v9, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_i32_e64 s1, s6, v9
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB1_18
; %bb.11:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s4, exec_lo
	v_cmpx_le_i32_e64 s31, v9
	s_xor_b32 s6, exec_lo, s4
	s_cbranch_execz .LBB1_14
; %bb.12:                               ; %.preheader230.1
	v_subrev_nc_u32_e32 v1, s31, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s7, s10, s4
	s_addc_u32 s8, s11, s5
	s_mov_b64 s[4:5], 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v3, vcc_lo, s29, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s30, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_13:                               ; =>This Inner Loop Header: Depth=1
	flat_load_b128 v[10:13], v[3:4]
	s_add_u32 s24, s7, s4
	s_addc_u32 s25, s8, s5
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[24:25], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_and_b32_e32 v5, 0xffff0000, v10
	v_lshlrev_b32_e32 v1, 16, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s36, v1
	v_dual_fmac_f32 v2, s37, v5 :: v_dual_and_b32 v5, 0xffff0000, v11
	v_lshlrev_b32_e32 v1, 16, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s38, v1
	v_dual_fmac_f32 v2, s39, v5 :: v_dual_and_b32 v5, 0xffff0000, v12
	v_lshlrev_b32_e32 v1, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v2, s40, v1
	v_lshlrev_b32_e32 v1, 16, v13
	v_fmac_f32_e32 v2, s41, v5
	v_and_b32_e32 v5, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s42, v1
	v_fmac_f32_e32 v2, s43, v5
	s_cbranch_scc0 .LBB1_13
.LBB1_14:                               ; %Flow2045
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s6, s6
	s_cbranch_execz .LBB1_17
; %bb.15:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[20:21], 2
	s_mov_b32 s9, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s7, s22, v1
	v_add_co_ci_u32_e64 v3, null, s23, 0, s7
	s_add_u32 s7, s10, s4
	s_addc_u32 s8, s11, s5
	s_mov_b64 s[4:5], 0
.LBB1_16:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s9, v7
	s_add_u32 s24, s7, s4
	s_addc_u32 s25, s8, s5
	s_add_i32 s9, s9, 4
	s_load_b128 s[36:39], s[24:25], 0x0
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	v_add_co_u32 v10, vcc_lo, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s5, v3, vcc_lo
	flat_load_d16_u8 v4, v[4:5]
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	flat_load_b128 v[10:13], v[10:11] offset:1024
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(1) lgkmcnt(0)
	v_and_b16 v8.l, v4.l, 3
	v_lshrrev_b16 v4.h, 2, v4.l
	v_lshrrev_b16 v5.l, 4, v4.l
	v_lshrrev_b16 v4.l, 6, v4.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v8, v8
	v_and_b16 v14.l, v4.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v5.l, v5.l, 3
	v_cvt_f32_ubyte0_e32 v4, v4
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v10, v8, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v10, v14
	v_cvt_f32_ubyte0_e32 v5, v5
	v_fma_mix_f32 v4, v13, v4, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v2, s36, v8
	v_fma_mix_f32 v8, v11, v10, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_mix_f32 v5, v12, v5, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v2, s37, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s38, v5
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB1_16
.LBB1_17:                               ; %Flow2046
	s_or_b32 exec_lo, exec_lo, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:512
.LBB1_18:                               ; %Flow2047
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB1_20
; %bb.19:
	ds_load_b32 v1, v6
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB1_20:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB1_22
; %bb.21:
	ds_load_b32 v2, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB1_22:
	s_or_b32 exec_lo, exec_lo, s3
	v_lshlrev_b32_e32 v5, 2, v0
	v_cmp_gt_u32_e64 s3, 64, v0
	s_delay_alu instid0(VALU_DEP_2)
	v_add_nc_u32_e32 v8, 0x1400, v5
	ds_store_b32 v5, v1 offset:5120
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB1_24
; %bb.23:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_24:
	s_or_b32 exec_lo, exec_lo, s4
	v_cmp_gt_u32_e64 s4, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB1_26
; %bb.25:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_26:
	s_or_b32 exec_lo, exec_lo, s5
	v_cmp_gt_u32_e64 s5, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s5
	s_cbranch_execz .LBB1_28
; %bb.27:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_28:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB1_30
; %bb.29:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_30:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB1_32
; %bb.31:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_32:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_gt_u32_e64 s8, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB1_34
; %bb.33:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_34:
	s_or_b32 exec_lo, exec_lo, s9
	v_cmp_eq_u32_e64 s9, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s9
	s_cbranch_execz .LBB1_36
; %bb.35:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_36:
	s_or_b32 exec_lo, exec_lo, s21
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s21, s0
	s_cbranch_execz .LBB1_38
; %bb.37:
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
.LBB1_38:
	s_or_b32 exec_lo, exec_lo, s21
	s_and_saveexec_b32 s21, s1
	s_cbranch_execz .LBB1_40
; %bb.39:
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
.LBB1_40:
	s_or_b32 exec_lo, exec_lo, s21
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s3
	s_cbranch_execz .LBB1_42
; %bb.41:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_42:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s4
	s_cbranch_execz .LBB1_44
; %bb.43:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_44:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s5
	s_cbranch_execz .LBB1_46
; %bb.45:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_46:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s6
	s_cbranch_execz .LBB1_48
; %bb.47:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_48:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s7
	s_cbranch_execz .LBB1_50
; %bb.49:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_50:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s8
	s_cbranch_execz .LBB1_52
; %bb.51:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_52:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s9
	s_cbranch_execz .LBB1_54
; %bb.53:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_54:
	s_or_b32 exec_lo, exec_lo, s21
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s21, s0
	s_cbranch_execz .LBB1_56
; %bb.55:
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
.LBB1_56:
	s_or_b32 exec_lo, exec_lo, s21
	s_and_saveexec_b32 s21, s1
	s_cbranch_execz .LBB1_58
; %bb.57:
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
.LBB1_58:                               ; %.preheader232.1
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s33, s0
	s_cbranch_execz .LBB1_66
; %bb.59:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s21, exec_lo
	v_cmpx_le_i32_e64 s31, v0
	s_xor_b32 s34, exec_lo, s21
	s_cbranch_execz .LBB1_62
; %bb.60:                               ; %.preheader230.1270
	v_subrev_nc_u32_e32 v1, s31, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[24:25], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s21, s10, s24
	s_addc_u32 s35, s11, s25
	s_mov_b64 s[24:25], 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v3, vcc_lo, s29, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s30, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_61:                               ; =>This Inner Loop Header: Depth=1
	flat_load_b128 v[10:13], v[3:4]
	s_add_u32 s36, s21, s24
	s_addc_u32 s37, s35, s25
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[36:37], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s24, s24, 32
	s_addc_u32 s25, s25, 0
	s_cmpk_eq_i32 s24, 0x200
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_lshlrev_b32_e32 v1, 16, v10
	v_and_b32_e32 v10, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s36, v1 :: v_dual_lshlrev_b32 v1, 16, v11
	v_fmac_f32_e32 v2, s37, v10
	v_and_b32_e32 v10, 0xffff0000, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s38, v1 :: v_dual_lshlrev_b32 v1, 16, v12
	v_fmac_f32_e32 v2, s39, v10
	v_and_b32_e32 v10, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s40, v1
	v_dual_fmac_f32 v2, s41, v10 :: v_dual_lshlrev_b32 v1, 16, v13
	v_and_b32_e32 v10, 0xffff0000, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s42, v1
	v_fmac_f32_e32 v2, s43, v10
	s_cbranch_scc0 .LBB1_61
.LBB1_62:                               ; %Flow2040
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s34, s34
	s_cbranch_execz .LBB1_65
; %bb.63:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[24:25], s[20:21], 2
	s_mov_b32 s36, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s21, s22, v1
	v_add_co_ci_u32_e64 v3, null, s23, 0, s21
	s_add_u32 s21, s10, s24
	s_addc_u32 s35, s11, s25
	s_mov_b64 s[24:25], 0
.LBB1_64:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s36, v7
	s_add_u32 s38, s21, s24
	s_addc_u32 s39, s35, s25
	s_add_i32 s36, s36, 4
	s_load_b128 s[40:43], s[38:39], 0x200
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v11, null, 0, v3, vcc_lo
	flat_load_d16_u8 v4, v[10:11]
	v_add_co_u32 v10, vcc_lo, v1, s24
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s25, v3, vcc_lo
	s_add_u32 s24, s24, 16
	s_addc_u32 s25, s25, 0
	s_cmpk_eq_i32 s24, 0x200
	flat_load_b128 v[10:13], v[10:11] offset:1024
	s_waitcnt vmcnt(1) lgkmcnt(0)
	v_and_b16 v15.l, v4.l, 3
	v_lshrrev_b16 v4.h, 2, v4.l
	v_lshrrev_b16 v14.l, 4, v4.l
	v_lshrrev_b16 v4.l, 6, v4.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v15, v15
	v_and_b16 v16.l, v4.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v14.l, v14.l, 3
	v_cvt_f32_ubyte0_e32 v4, v4
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v10, v10, v15, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v15, v16
	v_cvt_f32_ubyte0_e32 v14, v14
	v_fma_mix_f32 v4, v13, v4, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v2, s40, v10
	v_fma_mix_f32 v10, v11, v15, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_mix_f32 v11, v12, v14, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v2, s41, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s42, v11
	v_fmac_f32_e32 v2, s43, v4
	s_cbranch_scc0 .LBB1_64
.LBB1_65:                               ; %Flow2041
	s_or_b32 exec_lo, exec_lo, s34
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1024
.LBB1_66:                               ; %Flow2042
	s_or_b32 exec_lo, exec_lo, s33
	s_and_saveexec_b32 s33, s1
	s_cbranch_execz .LBB1_75
; %bb.67:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s21, exec_lo
	v_cmpx_le_i32_e64 s31, v9
	s_xor_b32 s34, exec_lo, s21
	s_cbranch_execz .LBB1_71
; %bb.68:                               ; %.preheader230.1.1
	v_subrev_nc_u32_e32 v1, s31, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[24:25], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s21, s10, s24
	s_addc_u32 s31, s11, s25
	s_mov_b64 s[24:25], 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_add_co_u32 v3, vcc_lo, s29, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s30, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB1_69:                               ; =>This Inner Loop Header: Depth=1
	flat_load_b128 v[9:12], v[3:4]
	s_add_u32 s36, s21, s24
	s_addc_u32 s37, s31, s25
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[36:37], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s24, s24, 32
	s_addc_u32 s25, s25, 0
	s_cmpk_eq_i32 s24, 0x200
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v1, 16, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s36, v1 :: v_dual_lshlrev_b32 v1, 16, v10
	v_dual_fmac_f32 v2, s37, v7 :: v_dual_and_b32 v7, 0xffff0000, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s38, v1 :: v_dual_lshlrev_b32 v1, 16, v11
	v_fmac_f32_e32 v2, s39, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s40, v1 :: v_dual_and_b32 v7, 0xffff0000, v11
	v_dual_fmac_f32 v2, s41, v7 :: v_dual_lshlrev_b32 v1, 16, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v2, s42, v1 :: v_dual_and_b32 v7, 0xffff0000, v12
	v_fmac_f32_e32 v2, s43, v7
	s_cbranch_scc0 .LBB1_69
; %bb.70:                               ; %Flow2033
	s_set_inst_prefetch_distance 0x2
                                        ; implicit-def: $vgpr7
                                        ; implicit-def: $vgpr9
.LBB1_71:                               ; %Flow2035
	s_and_not1_saveexec_b32 s24, s34
	s_cbranch_execz .LBB1_74
; %bb.72:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[34:35], s[20:21], 2
	s_mov_b32 s31, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s21, s22, v1
	v_add_co_ci_u32_e64 v3, null, s23, 0, s21
	s_add_u32 s21, s10, s34
	s_addc_u32 s25, s11, s35
	s_mov_b64 s[10:11], 0
.LBB1_73:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s31, v7
	s_add_u32 s34, s21, s10
	s_addc_u32 s35, s25, s11
	s_add_i32 s31, s31, 4
	s_load_b128 s[36:39], s[34:35], 0x200
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v10, null, 0, v3, vcc_lo
	flat_load_d16_u8 v4, v[9:10]
	v_add_co_u32 v9, vcc_lo, v1, s10
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s11, v3, vcc_lo
	s_add_u32 s10, s10, 16
	s_addc_u32 s11, s11, 0
	s_cmpk_eq_i32 s10, 0x200
	flat_load_b128 v[9:12], v[9:10] offset:1024
	s_waitcnt vmcnt(1) lgkmcnt(0)
	v_and_b16 v14.l, v4.l, 3
	v_lshrrev_b16 v4.h, 2, v4.l
	v_lshrrev_b16 v13.l, 4, v4.l
	v_lshrrev_b16 v4.l, 6, v4.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_ubyte0_e32 v14, v14
	v_and_b16 v15.l, v4.h, 3
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_and_b16 v13.l, v13.l, 3
	v_cvt_f32_ubyte0_e32 v4, v4
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v14, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_cvt_f32_ubyte0_e32 v14, v15
	v_cvt_f32_ubyte0_e32 v13, v13
	v_fma_mix_f32 v4, v12, v4, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v2, s36, v9
	v_fma_mix_f32 v9, v10, v14, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_mix_f32 v10, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v2, s37, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s38, v10
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB1_73
.LBB1_74:                               ; %Flow2036
	s_or_b32 exec_lo, exec_lo, s24
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1536
.LBB1_75:                               ; %Flow2037
	s_or_b32 exec_lo, exec_lo, s33
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s0
	s_cbranch_execz .LBB1_77
; %bb.76:
	ds_load_b32 v1, v6 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB1_77:
	s_or_b32 exec_lo, exec_lo, s10
	s_and_saveexec_b32 s10, s1
	s_cbranch_execz .LBB1_79
; %bb.78:
	ds_load_b32 v2, v6 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB1_79:
	s_or_b32 exec_lo, exec_lo, s10
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s3
	s_cbranch_execz .LBB1_81
; %bb.80:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_81:
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s4
	s_cbranch_execz .LBB1_83
; %bb.82:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_83:
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s5
	s_cbranch_execz .LBB1_85
; %bb.84:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_85:
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s6
	s_cbranch_execz .LBB1_87
; %bb.86:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_87:
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s7
	s_cbranch_execz .LBB1_89
; %bb.88:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_89:
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s8
	s_cbranch_execz .LBB1_91
; %bb.90:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_91:
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s9
	s_cbranch_execz .LBB1_93
; %bb.92:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB1_93:
	s_or_b32 exec_lo, exec_lo, s10
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s10, s0
	s_cbranch_execz .LBB1_95
; %bb.94:
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
.LBB1_95:
	s_or_b32 exec_lo, exec_lo, s10
	s_and_saveexec_b32 s10, s1
	s_cbranch_execz .LBB1_97
; %bb.96:
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
.LBB1_97:
	s_or_b32 exec_lo, exec_lo, s10
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s10, s3
	s_cbranch_execz .LBB1_99
; %bb.98:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_99:
	s_or_b32 exec_lo, exec_lo, s10
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s4
	s_cbranch_execz .LBB1_101
; %bb.100:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_101:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s5
	s_cbranch_execz .LBB1_103
; %bb.102:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_103:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s6
	s_cbranch_execz .LBB1_105
; %bb.104:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_105:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s7
	s_cbranch_execz .LBB1_107
; %bb.106:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_107:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s8
	s_cbranch_execz .LBB1_109
; %bb.108:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_109:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s9
	s_cbranch_execz .LBB1_111
; %bb.110:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB1_111:
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB1_113
; %bb.112:
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
.LBB1_113:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB1_115
; %bb.114:
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
.LBB1_115:                              ; %.preheader228
	s_or_b32 exec_lo, exec_lo, s0
	v_dual_mov_b32 v8, 0 :: v_dual_lshlrev_b32 v3, 1, v0
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 3, v0
	v_lshrrev_b32_e32 v6, 2, v0
	s_cmp_gt_i32 s17, 0
	v_and_b32_e32 v4, 6, v3
	s_cselect_b32 s3, -1, 0
	v_and_b32_e32 v7, 0x7c, v1
	s_cmp_lt_i32 s17, 1
	s_mov_b32 s0, 0
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB1_123
; %bb.116:                              ; %.lr.ph.preheader
	s_cmp_lt_u32 s17, 4
	s_cbranch_scc1 .LBB1_120
; %bb.117:                              ; %.lr.ph.preheader.new
	v_add_co_u32 v1, s0, s22, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s23, 0, s0
	v_add_co_u32 v9, s0, s22, v6
	v_add_co_ci_u32_e64 v10, null, s23, 0, s0
	v_mov_b32_e32 v8, 0
	s_and_b32 s0, s17, 0x7ffffffc
	s_mov_b32 s1, 0
	s_mov_b32 s4, 0
.LBB1_118:                              ; %.lr.ph
                                        ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v11, vcc_lo, v9, s16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s27, v10, vcc_lo
	v_add_co_u32 v13, vcc_lo, v1, s16
	v_add_co_ci_u32_e64 v14, null, s27, v2, vcc_lo
	s_clause 0x2
	flat_load_u8 v15, v[11:12]
	flat_load_u8 v16, v[11:12] offset:48
	flat_load_u8 v17, v[11:12] offset:96
	flat_load_b32 v18, v[13:14] offset:32
	flat_load_u8 v19, v[11:12] offset:144
	s_clause 0x2
	flat_load_b32 v20, v[13:14] offset:80
	flat_load_b32 v21, v[13:14] offset:128
	flat_load_b32 v22, v[13:14] offset:176
	v_add_co_u32 v1, vcc_lo, 0xc0, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v9, vcc_lo, 0xc0, v9
	v_add_co_ci_u32_e64 v10, null, 0, v10, vcc_lo
	s_add_i32 s4, s4, 4
	s_waitcnt vmcnt(6) lgkmcnt(6)
	v_bfe_u32 v16, v16, v4, 2
	s_waitcnt vmcnt(5) lgkmcnt(5)
	v_bfe_u32 v17, v17, v4, 2
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v16, v16
	v_bfe_u32 v15, v15, v4, 2
	v_cvt_f32_ubyte0_e32 v17, v17
	s_waitcnt vmcnt(2) lgkmcnt(2)
	s_delay_alu instid0(VALU_DEP_3)
	v_fma_mix_f32 v16, v20, v16, v20 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_mov_b32_e32 v11, s1
	v_cvt_f32_ubyte0_e32 v15, v15
	s_add_i32 s1, s1, 16
	s_cmp_eq_u32 s0, s4
	ds_load_b128 v[11:14], v11
	v_fma_mix_f32 v15, v18, v15, v18 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_bfe_u32 v18, v19, v4, 2
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v8, v11, v15
	v_cvt_f32_ubyte0_e32 v11, v18
	s_waitcnt vmcnt(1)
	v_fma_mix_f32 v15, v21, v17, v21 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v8, v12, v16
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v11, v22, v11, v22 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v8, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, v14, v11
	s_cbranch_scc0 .LBB1_118
; %bb.119:                              ; %.preheader226.loopexit.unr-lcssa
	s_and_b32 s1, s17, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc0 .LBB1_121
	s_branch .LBB1_123
.LBB1_120:
	v_mov_b32_e32 v8, 0
	s_and_b32 s1, s17, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc1 .LBB1_123
.LBB1_121:                              ; %.lr.ph.epil.preheader
	s_mul_i32 s5, s0, 48
	s_lshl_b32 s4, s0, 2
	s_add_u32 s0, s22, s5
	s_addc_u32 s5, s23, 0
	s_add_u32 s0, s0, s16
	s_addc_u32 s5, s5, s27
	v_add_co_u32 v1, s6, s0, v7
	v_add_co_u32 v9, s0, s0, v6
	v_add_co_ci_u32_e64 v2, null, s5, 0, s6
	v_add_co_ci_u32_e64 v10, null, s5, 0, s0
	s_mul_i32 s5, s1, 48
	s_mov_b64 s[0:1], 0
	.p2align	6
.LBB1_122:                              ; %.lr.ph.epil
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, vcc_lo, v9, s0
	v_add_co_ci_u32_e64 v12, null, s1, v10, vcc_lo
	flat_load_u8 v13, v[11:12]
	v_add_co_u32 v11, vcc_lo, v1, s0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s1, v2, vcc_lo
	flat_load_b32 v11, v[11:12] offset:32
	v_mov_b32_e32 v12, s4
	s_add_i32 s4, s4, 4
	s_add_u32 s0, s0, 48
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s5, s0
	ds_load_b32 v12, v12
	s_waitcnt vmcnt(1) lgkmcnt(2)
	v_bfe_u32 v13, v13, v4, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v13, v13
	s_waitcnt vmcnt(0) lgkmcnt(1)
	v_fma_mix_f32 v11, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, v12, v11
	s_cbranch_scc1 .LBB1_122
.LBB1_123:                              ; %.preheader226
	s_lshl_b32 s0, s18, 7
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s1, s0, 31
	s_cmp_gt_i32 s19, 0
	s_cselect_b32 s4, -1, 0
	s_cmp_lt_i32 s19, 1
	s_cbranch_scc1 .LBB1_126
; %bb.124:                              ; %.lr.ph250.preheader
	s_lshl_b64 s[6:7], s[0:1], 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	s_add_u32 s5, s29, s6
	s_addc_u32 s6, s30, s7
	v_add_co_u32 v1, s5, s5, v3
	v_add_co_ci_u32_e64 v2, null, s6, 0, s5
	s_lshl_b32 s5, s17, 2
	s_mov_b32 s6, s19
.LBB1_125:                              ; %.lr.ph250
                                        ; =>This Inner Loop Header: Depth=1
	flat_load_u16 v9, v[1:2]
	v_mov_b32_e32 v10, s5
	v_add_co_u32 v1, vcc_lo, 0x100, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_i32 s6, s6, -1
	s_add_i32 s5, s5, 4
	s_cmp_eq_u32 s6, 0
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_lshlrev_b32_e32 v9, 16, v9
	ds_load_b32 v10, v10
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v8, v10, v9
	s_cbranch_scc0 .LBB1_125
.LBB1_126:                              ; %._crit_edge
	s_and_not1_b32 vcc_lo, exec_lo, s3
	ds_store_b32 v5, v8 offset:4096
	s_cbranch_vccnz .LBB1_130
; %bb.127:                              ; %.lr.ph.1.preheader
	s_add_u32 s3, s22, s16
	s_addc_u32 s5, s23, s27
	v_add_co_u32 v1, s6, s3, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v2, null, s5, 0, s6
	v_add_co_u32 v7, vcc_lo, v1, 34
	v_add_co_u32 v1, s3, s3, v6
	s_delay_alu instid0(VALU_DEP_3)
	v_add_co_ci_u32_e64 v8, null, 0, v2, vcc_lo
	v_add_co_ci_u32_e64 v2, null, s5, 0, s3
	v_mov_b32_e32 v6, 0
	s_movk_i32 s3, 0x400
	s_mov_b32 s5, s17
	.p2align	6
.LBB1_128:                              ; %.lr.ph.1
                                        ; =>This Inner Loop Header: Depth=1
	flat_load_u8 v11, v[1:2]
	v_add_co_u32 v9, vcc_lo, -2, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, -1, v8, vcc_lo
	v_add_co_u32 v7, vcc_lo, v7, 48
	v_add_co_ci_u32_e64 v8, null, 0, v8, vcc_lo
	flat_load_b32 v9, v[9:10]
	v_mov_b32_e32 v10, s3
	v_add_co_u32 v1, vcc_lo, v1, 48
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	ds_load_b32 v10, v10
	s_add_i32 s5, s5, -1
	s_add_i32 s3, s3, 4
	s_cmp_lg_u32 s5, 0
	s_waitcnt vmcnt(1) lgkmcnt(2)
	v_bfe_u32 v11, v11, v4, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v11, v11
	s_waitcnt vmcnt(0) lgkmcnt(1)
	v_fma_mix_f32 v9, v9, v11, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v10, v9
	s_cbranch_scc1 .LBB1_128
; %bb.129:                              ; %Flow2025
	v_or_b32_e32 v4, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s4
	s_cbranch_vccz .LBB1_131
	s_branch .LBB1_133
.LBB1_130:
	v_mov_b32_e32 v6, 0
	v_or_b32_e32 v4, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s4
	s_cbranch_vccnz .LBB1_133
.LBB1_131:                              ; %.lr.ph250.1
	s_lshl_b32 s3, s17, 2
	s_lshl_b64 s[4:5], s[0:1], 1
	s_add_i32 s0, s3, 0x400
	s_add_u32 s1, s22, s26
	s_addc_u32 s3, s23, s28
	s_add_u32 s1, s1, s16
	s_addc_u32 s3, s3, s27
	s_add_u32 s1, s1, s4
	s_addc_u32 s3, s3, s5
	v_add_co_u32 v1, s1, s1, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s3, 0, s1
.LBB1_132:                              ; =>This Inner Loop Header: Depth=1
	flat_load_u16 v3, v[1:2]
	v_mov_b32_e32 v5, s0
	v_add_co_u32 v1, vcc_lo, 0x100, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	ds_load_b32 v5, v5
	s_add_i32 s19, s19, -1
	s_add_i32 s0, s0, 4
	s_cmp_lg_u32 s19, 0
	s_waitcnt vmcnt(0) lgkmcnt(1)
	v_lshlrev_b32_e32 v3, 16, v3
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v5, v3
	s_cbranch_scc1 .LBB1_132
.LBB1_133:                              ; %._crit_edge.1
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 12, v0
	s_ashr_i32 s21, s20, 31
	ds_store_b32 v4, v6 offset:512
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, s0, s12, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s13, 0, s0
	s_lshl_b64 s[0:1], s[20:21], 1
	s_movk_i32 s3, 0x1000
	v_add_co_u32 v3, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v4, null, s1, v4, vcc_lo
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
.LBB1_134:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB1_134
; %bb.135:                              ; %.preheader.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[4:5], 0
.LBB1_136:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_136
; %bb.137:                              ; %.preheader.1291
	s_lshl_b32 s2, s2, 10
	s_add_u32 s0, s12, s0
	v_or_b32_e32 v3, s2, v0
	s_addc_u32 s1, s13, s1
	v_add_co_u32 v2, s0, s0, v2
	s_movk_i32 s3, 0x1000
	v_ashrrev_i32_e32 v4, 31, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], 2, v[3:4]
	v_mov_b32_e32 v4, 0
	v_add_co_ci_u32_e64 v3, null, s1, 0, s0
	s_mov_b64 s[0:1], 0
	v_add_co_u32 v5, vcc_lo, s14, v5
	v_add_co_ci_u32_e64 v6, null, s15, v6, vcc_lo
	global_store_b32 v[5:6], v1, off
.LBB1_138:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_138
; %bb.139:                              ; %.preheader.1.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_140:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_140
; %bb.141:                              ; %.preheader.2
	s_ashr_i32 s0, s2, 31
	v_add_co_u32 v0, s1, v0, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v1, null, 0, s0, s1
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s14, v0
	v_add_co_ci_u32_e64 v1, null, s15, v1, vcc_lo
	global_store_b32 v[0:1], v4, off offset:512
.LBB1_142:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_142
; %bb.143:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_144:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_144
; %bb.145:                              ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:1024
.LBB1_146:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_146
; %bb.147:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_148:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_148
; %bb.149:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:1536
.LBB1_150:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_150
; %bb.151:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_152:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_152
; %bb.153:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:2048
.LBB1_154:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_154
; %bb.155:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_156:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_156
; %bb.157:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:2560
.LBB1_158:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_158
; %bb.159:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_160:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_160
; %bb.161:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:3072
.LBB1_162:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_162
; %bb.163:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB1_164:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB1_164
; %bb.165:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
.LBB1_166:                              ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii
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
		.amdhsa_next_free_sgpr 44
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
	.section	.text._Z11query_groupILi0EEvPKPKhPKfPKtPfiiii,"axG",@progbits,_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii,comdat
.Lfunc_end1:
	.size	_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii, .Lfunc_end1-_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii
                                        ; -- End function
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.num_vgpr, 23
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.num_agpr, 0
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.numbered_sgpr, 44
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.num_named_barrier, 0
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.private_seg_size, 0
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.uses_vcc, 1
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.uses_flat_scratch, 1
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.has_dyn_sized_stack, 0
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.has_recursion, 0
	.set _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 12640
; TotalNumSgprs: 46
; NumVgprs: 23
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 5632 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 46
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
	.section	.text._Z11query_groupILi1EEvPKPKhPKfPKtPfiiii,"axG",@progbits,_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii,comdat
	.protected	_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii ; -- Begin function _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii
	.globl	_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii
	.p2align	8
	.type	_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii,@function
_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii: ; @_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii
; %bb.0:
	s_cmp_gt_i32 s2, 7
	s_cbranch_scc1 .LBB2_118
; %bb.1:
	s_load_b128 s[16:19], s[0:1], 0x20
	s_waitcnt lgkmcnt(0)
	s_lshl_b32 s21, s16, 5
	s_add_i32 s3, s19, s17
	s_add_i32 s26, s18, s21
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lg_u32 s26, s3
	s_cselect_b32 s3, -1, 0
	s_cmpk_gt_i32 s26, 0x100
	s_cselect_b32 s4, -1, 0
	s_cmp_gt_i32 s16, 8
	s_cselect_b32 s5, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_or_b32 s4, s4, s5
	s_or_b32 s3, s4, s3
	s_cmp_gt_i32 s18, 32
	s_cselect_b32 s4, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_or_b32 s3, s4, s3
	s_cmp_gt_i32 s19, 33
	s_cselect_b32 s4, -1, 0
	s_or_b32 s3, s4, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB2_118
; %bb.2:
	s_load_b256 s[8:15], s[0:1], 0x0
	s_ashr_i32 s3, s2, 31
	s_delay_alu instid0(SALU_CYCLE_1)
	s_lshl_b64 s[0:1], s[2:3], 3
	s_mov_b32 s3, 0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s0, s8, s0
	s_addc_u32 s1, s9, s1
	s_cmp_gt_i32 s16, 0
	s_load_b64 s[22:23], s[0:1], 0x0
	s_cbranch_scc1 .LBB2_4
; %bb.3:                                ; %..preheader297_crit_edge
	s_lshl_b32 s20, s2, 8
	s_branch .LBB2_5
.LBB2_4:
	s_mov_b32 s3, -1
                                        ; implicit-def: $sgpr20
.LBB2_5:                                ; %Flow1968
	v_lshlrev_b32_e32 v5, 2, v0
	v_cmp_gt_u32_e64 s0, 4, v0
	v_cmp_eq_u32_e64 s1, 0, v0
	v_lshrrev_b32_e32 v6, 3, v0
	s_and_not1_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB2_16
; %bb.6:                                ; %.preheader300.lr.ph
	s_lshl_b32 s20, s2, 8
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v3, s4, s22, v5
	v_add_nc_u32_e32 v1, s20, v0
	v_add_co_ci_u32_e64 v4, null, s23, 0, s4
	s_movk_i32 s3, 0x7c
	v_dual_mov_b32 v7, 0 :: v_dual_add_nc_u32 v8, 0x1e00, v5
	v_ashrrev_i32_e32 v2, 31, v1
	v_add_nc_u32_e32 v9, 0x1c00, v5
	v_dual_mov_b32 v13, v0 :: v_dual_lshlrev_b32 v10, 7, v0
	v_and_or_b32 v11, v6, s3, 0x2000
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_lshlrev_b64 v[1:2], 2, v[1:2]
	v_or_b32_e32 v12, 0x2000, v5
	s_movk_i32 s3, 0x2100
	s_movk_i32 s4, 0xff81
	s_mov_b32 s5, s16
	v_add_co_u32 v1, vcc_lo, s10, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s11, v2, vcc_lo
	v_add_co_u32 v3, vcc_lo, 0x400, v3
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_branch .LBB2_8
.LBB2_7:                                ;   in Loop: Header=BB2_8 Depth=1
	s_or_b32 exec_lo, exec_lo, s6
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v14, v8
	ds_load_b32 v15, v11 offset:16
	s_add_i32 s5, s5, -1
	s_add_i32 s3, s3, 8
	s_cmp_eq_u32 s5, 0
	v_add_nc_u32_e32 v12, 32, v12
	v_add_nc_u32_e32 v11, 32, v11
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v16, null, v15, v15, v14
	v_div_scale_f32 v19, vcc_lo, v14, v15, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_mul_f32_e32 v18, v19, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v18, v19
	v_fmac_f32_e32 v18, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v18, v19
	v_div_fmas_f32 v16, v16, v17, v18
	v_add_co_u32 v3, vcc_lo, 0x600, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	v_div_fixup_f32 v14, v16, v15, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rndne_f32_e32 v14, v14
	v_cvt_i32_f32_e32 v14, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_med3_i32 v14, v14, s4, 0x7f
	ds_store_b8 v13, v14 offset:128
	v_add_nc_u32_e32 v13, 0x100, v13
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB2_16
.LBB2_8:                                ; %.preheader300
                                        ; =>This Inner Loop Header: Depth=1
	flat_load_d16_b16 v14, v[3:4] offset:2
	global_load_b32 v15, v[1:2], off
	s_waitcnt vmcnt(1) lgkmcnt(0)
	v_cvt_f32_f16_e32 v14, v14.l
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v14, v15, v14
	ds_store_b32 v8, v14
	flat_load_d16_b16 v14, v[3:4]
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_cvt_f32_f16_e32 v14, v14.l
	v_mul_f32_e32 v14, v15, v14
	ds_store_b32 v9, v14
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s0
	s_cbranch_execz .LBB2_10
; %bb.9:                                ; %.preheader299.preheader
                                        ;   in Loop: Header=BB2_8 Depth=1
	ds_load_b128 v[14:17], v10 offset:7680
	ds_load_b128 v[18:21], v10 offset:7696
	ds_load_b128 v[22:25], v10 offset:7712
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v14, |v14|, 0, |v15|
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_max3_f32 v26, v14, |v16|, |v17|
	ds_load_b128 v[14:17], v10 offset:7728
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v18, v26, |v18|, |v19|
	v_max3_f32 v26, v18, |v20|, |v21|
	ds_load_b128 v[18:21], v10 offset:7744
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v22, v26, |v22|, |v23|
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_max3_f32 v26, v22, |v24|, |v25|
	ds_load_b128 v[22:25], v10 offset:7760
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v14, v26, |v14|, |v15|
	v_max3_f32 v26, v14, |v16|, |v17|
	ds_load_b128 v[14:17], v10 offset:7776
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v18, v26, |v18|, |v19|
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_max3_f32 v26, v18, |v20|, |v21|
	ds_load_b128 v[18:21], v10 offset:7792
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v22, v26, |v22|, |v23|
	v_max3_f32 v22, v22, |v24|, |v25|
	s_waitcnt lgkmcnt(1)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_max3_f32 v14, v22, |v14|, |v15|
	v_max3_f32 v14, v14, |v16|, |v17|
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_max3_f32 v14, v14, |v18|, |v19|
	v_max3_f32 v14, v14, |v20|, |v21|
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v15, null, 0x42fe0000, 0x42fe0000, v14
	v_rcp_f32_e32 v16, v15
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v15, v16, 1.0
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, 0x42fe0000, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v18, v17, v16
	v_fma_f32 v19, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v18, v19, v16
	v_fma_f32 v15, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v15, v15, v16, v18
	v_cmp_lt_f32_e32 vcc_lo, 0, v14
	v_div_fixup_f32 v15, v15, 0x42fe0000, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_cndmask_b32_e32 v14, 1.0, v15, vcc_lo
	ds_store_b32 v12, v14
.LBB2_10:                               ;   in Loop: Header=BB2_8 Depth=1
	s_or_b32 exec_lo, exec_lo, s6
	s_and_saveexec_b32 s6, s1
	s_cbranch_execz .LBB2_12
; %bb.11:                               ; %.preheader298.preheader
                                        ;   in Loop: Header=BB2_8 Depth=1
	ds_load_b128 v[14:17], v7 offset:7168
	ds_load_b128 v[18:21], v7 offset:7184
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, 0, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7200
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7216
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7232
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7248
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7264
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7280
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7296
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7312
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7328
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7344
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7360
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7376
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7392
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7408
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7424
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7440
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7456
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7472
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7488
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7504
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7520
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7536
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7552
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7568
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7584
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7600
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7616
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7632
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7648
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7664
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_add_f32 v14, v14, v15 :: v_dual_mov_b32 v15, s3
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v17
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v14, v14, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v19
	v_add_f32_e32 v14, v14, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v21
	ds_store_b32 v15, v14
.LBB2_12:                               ;   in Loop: Header=BB2_8 Depth=1
	s_or_b32 exec_lo, exec_lo, s6
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v14, v8
	ds_load_b32 v15, v11
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v16, null, v15, v15, v14
	v_div_scale_f32 v19, vcc_lo, v14, v15, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v16
	v_fma_f32 v18, -v16, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v18, v17
	v_mul_f32_e32 v18, v19, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v20, -v16, v18, v19
	v_fmac_f32_e32 v18, v20, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v16, -v16, v18, v19
	v_div_fmas_f32 v16, v16, v17, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v14, v16, v15, v14
	v_rndne_f32_e32 v14, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_i32_f32_e32 v14, v14
	v_med3_i32 v14, v14, s4, 0x7f
	ds_store_b8 v13, v14
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	flat_load_d16_b16 v14, v[3:4] offset:2
	global_load_b32 v15, v[1:2], off offset:512
	s_waitcnt vmcnt(1) lgkmcnt(0)
	v_cvt_f32_f16_e32 v14, v14.l
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v14, v15, v14
	ds_store_b32 v8, v14
	flat_load_d16_b16 v14, v[3:4]
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_cvt_f32_f16_e32 v14, v14.l
	v_mul_f32_e32 v14, v15, v14
	ds_store_b32 v9, v14
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s0
	s_cbranch_execz .LBB2_14
; %bb.13:                               ; %.preheader299.preheader.1
                                        ;   in Loop: Header=BB2_8 Depth=1
	ds_load_b128 v[14:17], v10 offset:7680
	ds_load_b128 v[18:21], v10 offset:7696
	ds_load_b128 v[22:25], v10 offset:7712
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v14, |v14|, 0, |v15|
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_max3_f32 v26, v14, |v16|, |v17|
	ds_load_b128 v[14:17], v10 offset:7728
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v18, v26, |v18|, |v19|
	v_max3_f32 v26, v18, |v20|, |v21|
	ds_load_b128 v[18:21], v10 offset:7744
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v22, v26, |v22|, |v23|
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_max3_f32 v26, v22, |v24|, |v25|
	ds_load_b128 v[22:25], v10 offset:7760
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v14, v26, |v14|, |v15|
	v_max3_f32 v26, v14, |v16|, |v17|
	ds_load_b128 v[14:17], v10 offset:7776
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v18, v26, |v18|, |v19|
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_max3_f32 v26, v18, |v20|, |v21|
	ds_load_b128 v[18:21], v10 offset:7792
	s_waitcnt lgkmcnt(2)
	v_max3_f32 v22, v26, |v22|, |v23|
	v_max3_f32 v22, v22, |v24|, |v25|
	s_waitcnt lgkmcnt(1)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_max3_f32 v14, v22, |v14|, |v15|
	v_max3_f32 v14, v14, |v16|, |v17|
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_max3_f32 v14, v14, |v18|, |v19|
	v_max3_f32 v14, v14, |v20|, |v21|
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v15, null, 0x42fe0000, 0x42fe0000, v14
	v_rcp_f32_e32 v16, v15
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v15, v16, 1.0
	v_fmac_f32_e32 v16, v17, v16
	v_div_scale_f32 v17, vcc_lo, v14, 0x42fe0000, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v18, v17, v16
	v_fma_f32 v19, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v18, v19, v16
	v_fma_f32 v15, -v15, v18, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v15, v15, v16, v18
	v_cmp_lt_f32_e32 vcc_lo, 0, v14
	v_div_fixup_f32 v15, v15, 0x42fe0000, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_cndmask_b32_e32 v14, 1.0, v15, vcc_lo
	ds_store_b32 v12, v14 offset:16
.LBB2_14:                               ;   in Loop: Header=BB2_8 Depth=1
	s_or_b32 exec_lo, exec_lo, s6
	s_and_saveexec_b32 s6, s1
	s_cbranch_execz .LBB2_7
; %bb.15:                               ; %.preheader298.preheader.1
                                        ;   in Loop: Header=BB2_8 Depth=1
	ds_load_b128 v[14:17], v7 offset:7168
	ds_load_b128 v[18:21], v7 offset:7184
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, 0, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7200
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7216
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7232
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7248
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7264
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7280
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7296
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7312
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7328
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7344
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7360
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7376
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7392
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7408
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7424
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7440
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7456
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7472
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7488
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7504
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7520
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7536
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7552
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7568
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7584
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7600
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7616
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7632
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v15
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_f32_e32 v22, v14, v17
	ds_load_b128 v[14:17], v7 offset:7648
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v18, v22, v18
	v_add_f32_e32 v18, v18, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v18, v18, v20
	v_add_f32_e32 v22, v18, v21
	ds_load_b128 v[18:21], v7 offset:7664
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v14, v22, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_add_f32 v14, v14, v15 :: v_dual_mov_b32 v15, s3
	v_add_f32_e32 v14, v14, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v17
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v14, v14, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v19
	v_add_f32_e32 v14, v14, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v14, v14, v21
	ds_store_b32 v15, v14 offset:4
	s_branch .LBB2_7
.LBB2_16:                               ; %.preheader297
	v_lshlrev_b32_e32 v1, 5, v0
	v_add_nc_u32_e32 v2, 0x80, v0
	s_mulk_i32 s16, 0x600
	s_mul_i32 s28, s17, 48
	s_ashr_i32 s27, s16, 31
	s_waitcnt lgkmcnt(0)
	s_add_u32 s0, s22, s16
	v_cmp_gt_i32_e64 s1, s26, v2
	v_dual_mov_b32 v2, 0 :: v_dual_and_b32 v1, 0x3e0, v1
	s_addc_u32 s24, s23, s27
	s_ashr_i32 s29, s28, 31
	s_add_u32 s30, s0, s28
	v_cmp_gt_i32_e64 s0, s26, v0
	v_add_co_u32 v9, s25, s22, v1
	v_or_b32_e32 v7, 0x1000, v5
	v_add_nc_u32_e32 v8, 0x1c00, v5
	v_cmp_gt_u32_e64 s3, 64, v0
	v_cmp_gt_u32_e64 s4, 32, v0
	v_cmp_gt_u32_e64 s5, 16, v0
	v_cmp_gt_u32_e64 s6, 8, v0
	v_cmp_gt_u32_e64 s7, 4, v0
	v_cmp_gt_u32_e64 s8, 2, v0
	v_cmp_eq_u32_e64 s9, 0, v0
	v_add_co_ci_u32_e64 v10, null, s23, 0, s25
	s_addc_u32 s31, s24, s29
	s_mov_b32 s36, 0
	s_mov_b32 s24, -1
	s_branch .LBB2_18
.LBB2_17:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_mov_b32 s36, 1
	s_and_b32 vcc_lo, exec_lo, s33
	s_mov_b32 s24, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_cbranch_vccnz .LBB2_67
.LBB2_18:                               ; %.preheader296
                                        ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB2_21 Depth 2
                                        ;       Child Loop BB2_24 Depth 3
	s_lshl_b32 s38, s36, 7
	s_xor_b32 s33, s24, -1
	s_add_i32 s24, s20, s38
	s_lshl_b32 s37, s36, 2
	s_ashr_i32 s25, s24, 31
	s_lshl_b32 s39, s36, 4
	s_lshl_b32 s34, s36, 10
	s_lshl_b64 s[24:25], s[24:25], 2
	s_addk_i32 s37, 0x2100
	s_addk_i32 s39, 0x2000
	s_add_i32 s35, s34, 0x1000
	s_add_u32 s40, s10, s24
	s_addc_u32 s41, s11, s25
	s_mov_b32 s42, -1
	s_mov_b32 s24, 0
	s_branch .LBB2_21
.LBB2_19:                               ; %.loopexit293
                                        ;   in Loop: Header=BB2_21 Depth=2
	s_or_b32 exec_lo, exec_lo, s24
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v1
	v_lshl_add_u32 v3, v11, 2, s35
	ds_store_b32 v3, v1
.LBB2_20:                               ; %Flow1964
                                        ;   in Loop: Header=BB2_21 Depth=2
	s_or_b32 exec_lo, exec_lo, s43
	s_xor_b32 s25, s42, -1
	s_movk_i32 s24, 0x80
	s_and_b32 vcc_lo, exec_lo, s25
	s_mov_b32 s42, 0
	s_cbranch_vccnz .LBB2_27
.LBB2_21:                               ;   Parent Loop BB2_18 Depth=1
                                        ; =>  This Loop Header: Depth=2
                                        ;       Child Loop BB2_24 Depth 3
	v_add_nc_u32_e32 v11, s24, v0
	s_mov_b32 s43, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_gt_i32_e64 s26, v11
	s_cbranch_execz .LBB2_20
; %bb.22:                               ;   in Loop: Header=BB2_21 Depth=2
                                        ; implicit-def: $vgpr1
	s_mov_b32 s24, exec_lo
	v_cmpx_le_i32_e64 s21, v11
	s_xor_b32 s44, exec_lo, s24
	s_cbranch_execz .LBB2_25
; %bb.23:                               ; %.preheader294
                                        ;   in Loop: Header=BB2_21 Depth=2
	v_subrev_nc_u32_e32 v1, s21, v11
	s_mov_b64 s[24:25], 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v1, 7, v1
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_mov_b32_e32 v1, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v3, vcc_lo, s30, v3
	v_add_co_ci_u32_e64 v4, null, s31, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB2_24:                               ;   Parent Loop BB2_18 Depth=1
                                        ;     Parent Loop BB2_21 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	flat_load_b128 v[12:15], v[3:4]
	s_add_u32 s46, s40, s24
	s_addc_u32 s47, s41, s25
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[48:55], s[46:47], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s24, s24, 32
	s_addc_u32 s25, s25, 0
	s_cmpk_lg_i32 s24, 0x200
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_lshlrev_b32_e32 v16, 16, v12
	v_and_b32_e32 v12, 0xffff0000, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v1, s48, v16 :: v_dual_lshlrev_b32 v16, 16, v13
	v_dual_fmac_f32 v1, s49, v12 :: v_dual_and_b32 v12, 0xffff0000, v13
	v_lshlrev_b32_e32 v13, 16, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s50, v16
	v_dual_fmac_f32 v1, s51, v12 :: v_dual_and_b32 v12, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v1, s52, v13
	v_lshlrev_b32_e32 v13, 16, v15
	v_dual_fmac_f32 v1, s53, v12 :: v_dual_and_b32 v12, 0xffff0000, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, s54, v13
	v_fmac_f32_e32 v1, s55, v12
	s_cbranch_scc1 .LBB2_24
.LBB2_25:                               ; %Flow1963
                                        ;   in Loop: Header=BB2_21 Depth=2
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s24, s44
	s_cbranch_execz .LBB2_19
; %bb.26:                               ; %.preheader292
                                        ;   in Loop: Header=BB2_21 Depth=2
	v_lshrrev_b32_e32 v1, 5, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_u32_u24_e32 v3, 0x600, v1
	v_lshl_add_u32 v52, v1, 8, s38
	v_add_co_u32 v3, vcc_lo, v9, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v10, vcc_lo
	s_clause 0x1
	flat_load_b128 v[12:15], v[3:4]
	flat_load_b128 v[16:19], v[3:4] offset:16
	v_and_b32_e32 v3, 0xffffffe0, v11
	v_lshl_add_u32 v4, v1, 3, s37
	s_delay_alu instid0(VALU_DEP_2)
	v_add_nc_u32_e32 v3, s39, v3
	ds_load_b32 v1, v4
	ds_load_b128 v[20:23], v52
	ds_load_b128 v[24:27], v52 offset:16
	ds_load_b128 v[28:31], v52 offset:32
	ds_load_b128 v[32:35], v52 offset:48
	ds_load_b128 v[36:39], v52 offset:64
	ds_load_b128 v[40:43], v52 offset:80
	ds_load_b128 v[44:47], v52 offset:96
	ds_load_b128 v[48:51], v3
	ds_load_b128 v[52:55], v52 offset:112
	s_waitcnt vmcnt(1) lgkmcnt(11)
	v_and_b32_e32 v62, 0xff, v14
	v_bfe_u32 v63, v14, 8, 8
	v_lshrrev_b32_e32 v56, 24, v14
	v_bfe_u32 v14, v14, 16, 8
	v_and_b32_e32 v64, 0xff, v15
	v_mul_u32_u24_e32 v86, 0x1001, v62
	v_mul_u32_u24_e32 v62, 0x40040, v62
	v_mul_u32_u24_e32 v87, 0x1001, v63
	v_mul_u32_u24_e32 v63, 0x40040, v63
	v_mul_u32_u24_e32 v88, 0x1001, v14
	v_mul_u32_u24_e32 v14, 0x40040, v14
	v_or_b32_e32 v62, v62, v86
	v_mul_u32_u24_e32 v89, 0x1001, v56
	v_or_b32_e32 v63, v63, v87
	v_mul_u32_u24_e32 v56, 0x40040, v56
	v_or_b32_e32 v14, v14, v88
	v_and_b32_e32 v62, 0x3030303, v62
	v_bfe_u32 v65, v15, 8, 8
	v_and_b32_e32 v63, 0x3030303, v63
	v_mul_u32_u24_e32 v90, 0x1001, v64
	v_mul_u32_u24_e32 v64, 0x40040, v64
	s_waitcnt lgkmcnt(6)
	v_dot4_i32_iu8 v28, v28, v62, 0 neg_lo:[1,0,0]
	v_or_b32_e32 v56, v56, v89
	v_and_b32_e32 v14, 0x3030303, v14
	v_lshrrev_b32_e32 v57, 24, v15
	v_bfe_u32 v15, v15, 16, 8
	v_dot4_i32_iu8 v28, v29, v63, v28 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v91, 0x1001, v65
	v_mul_u32_u24_e32 v65, 0x40040, v65
	v_or_b32_e32 v64, v64, v90
	v_and_b32_e32 v56, 0x3030303, v56
	v_dot4_i32_iu8 v14, v30, v14, v28 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v92, 0x1001, v15
	v_mul_u32_u24_e32 v15, 0x40040, v15
	v_or_b32_e32 v65, v65, v91
	v_and_b32_e32 v64, 0x3030303, v64
	v_dot4_i32_iu8 v14, v31, v56, v14 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v93, 0x1001, v57
	v_mul_u32_u24_e32 v57, 0x40040, v57
	v_or_b32_e32 v15, v15, v92
	v_and_b32_e32 v65, 0x3030303, v65
	s_waitcnt lgkmcnt(5)
	v_dot4_i32_iu8 v14, v32, v64, v14 neg_lo:[1,0,0]
	v_and_b32_e32 v58, 0xff, v12
	v_or_b32_e32 v57, v57, v93
	v_and_b32_e32 v15, 0x3030303, v15
	v_bfe_u32 v59, v12, 8, 8
	v_dot4_i32_iu8 v14, v33, v65, v14 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v78, 0x1001, v58
	v_and_b32_e32 v57, 0x3030303, v57
	v_mul_u32_u24_e32 v58, 0x40040, v58
	v_lshrrev_b32_e32 v3, 24, v12
	v_dot4_i32_iu8 v14, v34, v15, v14 neg_lo:[1,0,0]
	v_bfe_u32 v12, v12, 16, 8
	v_mul_u32_u24_e32 v79, 0x1001, v59
	v_mul_u32_u24_e32 v59, 0x40040, v59
	v_or_b32_e32 v58, v58, v78
	v_dot4_i32_iu8 v14, v35, v57, v14 neg_lo:[1,0,0]
	v_bfe_u32 v61, v13, 8, 8
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v74, 0xff, v18
	v_mul_u32_u24_e32 v80, 0x1001, v12
	v_mul_u32_u24_e32 v12, 0x40040, v12
	v_cvt_f32_i32_e32 v14, v14
	v_and_b32_e32 v60, 0xff, v13
	v_or_b32_e32 v59, v59, v79
	v_and_b32_e32 v58, 0x3030303, v58
	v_lshrrev_b32_e32 v4, 24, v13
	v_bfe_u32 v13, v13, 16, 8
	v_mul_u32_u24_e32 v82, 0x1001, v60
	v_mul_u32_u24_e32 v60, 0x40040, v60
	v_bfe_u32 v75, v18, 8, 8
	v_mul_u32_u24_e32 v81, 0x1001, v3
	v_mul_u32_u24_e32 v3, 0x40040, v3
	v_mul_u32_u24_e32 v83, 0x1001, v61
	v_mul_u32_u24_e32 v61, 0x40040, v61
	v_or_b32_e32 v12, v12, v80
	v_or_b32_e32 v60, v60, v82
	v_mul_u32_u24_e32 v82, 0x1001, v74
	v_mul_u32_u24_e32 v74, 0x40040, v74
	v_and_b32_e32 v59, 0x3030303, v59
	v_dot4_i32_iu8 v20, v20, v58, 0 neg_lo:[1,0,0]
	v_lshrrev_b32_e32 v68, 24, v18
	v_bfe_u32 v18, v18, 16, 8
	v_mul_u32_u24_e32 v84, 0x1001, v13
	v_mul_u32_u24_e32 v13, 0x40040, v13
	v_or_b32_e32 v3, v3, v81
	v_or_b32_e32 v61, v61, v83
	v_mul_u32_u24_e32 v83, 0x1001, v75
	v_mul_u32_u24_e32 v75, 0x40040, v75
	v_or_b32_e32 v74, v74, v82
	v_and_b32_e32 v12, 0x3030303, v12
	v_dot4_i32_iu8 v20, v21, v59, v20 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v85, 0x1001, v4
	v_mul_u32_u24_e32 v4, 0x40040, v4
	v_or_b32_e32 v13, v13, v84
	v_mul_u32_u24_e32 v84, 0x1001, v18
	v_mul_u32_u24_e32 v18, 0x40040, v18
	v_or_b32_e32 v75, v75, v83
	v_and_b32_e32 v3, 0x3030303, v3
	v_dot4_i32_iu8 v12, v22, v12, v20 neg_lo:[1,0,0]
	v_and_b32_e32 v20, 0x3030303, v74
	v_and_b32_e32 v76, 0xff, v19
	v_or_b32_e32 v4, v4, v85
	v_mul_u32_u24_e32 v85, 0x1001, v68
	v_mul_u32_u24_e32 v68, 0x40040, v68
	v_or_b32_e32 v18, v18, v84
	v_and_b32_e32 v60, 0x3030303, v60
	v_and_b32_e32 v22, 0x3030303, v75
	v_dot4_i32_iu8 v3, v23, v3, v12 neg_lo:[1,0,0]
	s_waitcnt lgkmcnt(2)
	v_dot4_i32_iu8 v12, v44, v20, 0 neg_lo:[1,0,0]
	v_bfe_u32 v77, v19, 8, 8
	v_mul_u32_u24_e32 v86, 0x1001, v76
	v_mul_u32_u24_e32 v76, 0x40040, v76
	v_or_b32_e32 v68, v68, v85
	v_and_b32_e32 v61, 0x3030303, v61
	v_and_b32_e32 v18, 0x3030303, v18
	v_dot4_i32_iu8 v3, v24, v60, v3 neg_lo:[1,0,0]
	v_dot4_i32_iu8 v12, v45, v22, v12 neg_lo:[1,0,0]
	v_lshrrev_b32_e32 v69, 24, v19
	v_bfe_u32 v19, v19, 16, 8
	v_mul_u32_u24_e32 v87, 0x1001, v77
	v_mul_u32_u24_e32 v77, 0x40040, v77
	v_or_b32_e32 v76, v76, v86
	v_and_b32_e32 v13, 0x3030303, v13
	v_and_b32_e32 v20, 0x3030303, v68
	v_dot4_i32_iu8 v3, v25, v61, v3 neg_lo:[1,0,0]
	v_dot4_i32_iu8 v12, v46, v18, v12 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v88, 0x1001, v19
	v_mul_u32_u24_e32 v19, 0x40040, v19
	v_or_b32_e32 v77, v77, v87
	v_and_b32_e32 v4, 0x3030303, v4
	v_and_b32_e32 v18, 0x3030303, v76
	v_dot4_i32_iu8 v3, v26, v13, v3 neg_lo:[1,0,0]
	v_dot4_i32_iu8 v12, v47, v20, v12 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v89, 0x1001, v69
	v_mul_u32_u24_e32 v69, 0x40040, v69
	v_or_b32_e32 v19, v19, v88
	v_and_b32_e32 v13, 0x3030303, v77
	v_dot4_i32_iu8 v3, v27, v4, v3 neg_lo:[1,0,0]
	s_waitcnt lgkmcnt(0)
	v_dot4_i32_iu8 v4, v52, v18, v12 neg_lo:[1,0,0]
	v_or_b32_e32 v69, v69, v89
	v_and_b32_e32 v12, 0x3030303, v19
	v_bfe_u32 v71, v16, 8, 8
	v_cvt_f32_i32_e32 v3, v3
	v_dot4_i32_iu8 v4, v53, v13, v4 neg_lo:[1,0,0]
	v_and_b32_e32 v13, 0x3030303, v69
	v_lshrrev_b32_e32 v66, 24, v16
	v_mul_u32_u24_e32 v95, 0x1001, v71
	v_fmac_f32_e32 v1, v48, v3
	v_dot4_i32_iu8 v3, v54, v12, v4 neg_lo:[1,0,0]
	v_mul_u32_u24_e32 v71, 0x40040, v71
	v_and_b32_e32 v72, 0xff, v17
	v_mul_u32_u24_e32 v97, 0x1001, v66
	v_mul_u32_u24_e32 v66, 0x40040, v66
	v_dot4_i32_iu8 v3, v55, v13, v3 neg_lo:[1,0,0]
	v_or_b32_e32 v71, v71, v95
	v_bfe_u32 v73, v17, 8, 8
	v_mul_u32_u24_e32 v78, 0x1001, v72
	v_mul_u32_u24_e32 v72, 0x40040, v72
	v_cvt_f32_i32_e32 v3, v3
	v_and_b32_e32 v70, 0xff, v16
	v_bfe_u32 v16, v16, 16, 8
	v_and_b32_e32 v71, 0x3030303, v71
	v_or_b32_e32 v66, v66, v97
	v_lshrrev_b32_e32 v67, 24, v17
	v_mul_u32_u24_e32 v94, 0x1001, v70
	v_mul_u32_u24_e32 v70, 0x40040, v70
	v_mul_u32_u24_e32 v96, 0x1001, v16
	v_mul_u32_u24_e32 v16, 0x40040, v16
	v_bfe_u32 v17, v17, 16, 8
	v_mul_u32_u24_e32 v79, 0x1001, v73
	v_or_b32_e32 v70, v70, v94
	v_mul_u32_u24_e32 v73, 0x40040, v73
	v_or_b32_e32 v16, v16, v96
	v_or_b32_e32 v72, v72, v78
	v_and_b32_e32 v58, 0x3030303, v66
	v_and_b32_e32 v70, 0x3030303, v70
	v_mul_u32_u24_e32 v80, 0x1001, v17
	v_and_b32_e32 v16, 0x3030303, v16
	v_mul_u32_u24_e32 v17, 0x40040, v17
	v_or_b32_e32 v73, v73, v79
	v_dot4_i32_iu8 v36, v36, v70, 0 neg_lo:[1,0,0]
	v_and_b32_e32 v66, 0x3030303, v72
	v_mul_u32_u24_e32 v81, 0x1001, v67
	v_mul_u32_u24_e32 v67, 0x40040, v67
	v_or_b32_e32 v17, v17, v80
	v_dot4_i32_iu8 v29, v37, v71, v36 neg_lo:[1,0,0]
	v_dual_fmac_f32 v1, v49, v14 :: v_dual_and_b32 v72, 0x3030303, v73
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_or_b32_e32 v67, v67, v81
	v_and_b32_e32 v17, 0x3030303, v17
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dot4_i32_iu8 v16, v38, v16, v29 neg_lo:[1,0,0]
	v_and_b32_e32 v21, 0x3030303, v67
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dot4_i32_iu8 v16, v39, v58, v16 neg_lo:[1,0,0]
	v_dot4_i32_iu8 v16, v40, v66, v16 neg_lo:[1,0,0]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dot4_i32_iu8 v16, v41, v72, v16 neg_lo:[1,0,0]
	v_dot4_i32_iu8 v15, v42, v17, v16 neg_lo:[1,0,0]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dot4_i32_iu8 v15, v43, v21, v15 neg_lo:[1,0,0]
	v_cvt_f32_i32_e32 v4, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v1, v50, v4
	v_fmac_f32_e32 v1, v51, v3
	s_branch .LBB2_19
.LBB2_27:                               ;   in Loop: Header=BB2_18 Depth=1
	v_mov_b32_e32 v1, 0xff800000
	v_lshl_add_u32 v3, s36, 10, v7
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s0
	s_cbranch_execz .LBB2_29
; %bb.28:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_b32 v1, v3
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB2_29:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_and_saveexec_b32 s24, s1
	s_cbranch_execz .LBB2_31
; %bb.30:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_b32 v3, v3 offset:512
	v_max_f32_e32 v1, v1, v1
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v3
.LBB2_31:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s3
	s_cbranch_execz .LBB2_33
; %bb.32:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_stride64_b32 v[3:4], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v4, v4
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v3, v1
	ds_store_b32 v8, v1
.LBB2_33:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s4
	s_cbranch_execz .LBB2_35
; %bb.34:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v4, v4
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v3, v1
	ds_store_b32 v8, v1
.LBB2_35:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s5
	s_cbranch_execz .LBB2_37
; %bb.36:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v4, v4
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v3, v1
	ds_store_b32 v8, v1
.LBB2_37:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s6
	s_cbranch_execz .LBB2_39
; %bb.38:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v4, v4
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v3, v1
	ds_store_b32 v8, v1
.LBB2_39:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s7
	s_cbranch_execz .LBB2_41
; %bb.40:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v4, v4
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v3, v1
	ds_store_b32 v8, v1
.LBB2_41:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s8
	s_cbranch_execz .LBB2_43
; %bb.42:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v4, v4
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v3, v1
	ds_store_b32 v8, v1
.LBB2_43:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s9
	s_cbranch_execz .LBB2_45
; %bb.44:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v4, v4
	v_max_f32_e32 v3, v3, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v3, v1
	ds_store_b32 v8, v1
.LBB2_45:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v4, v2 offset:7168
	s_addk_i32 s34, 0x800
	v_mov_b32_e32 v3, 0
	v_add_nc_u32_e32 v11, s35, v5
	v_add_nc_u32_e32 v1, s34, v5
	s_and_saveexec_b32 s24, s0
	s_cbranch_execz .LBB2_47
; %bb.46:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_b32 v3, v11
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v3, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v12, 0x3fb8aa3b, v3
	v_fma_f32 v13, 0x3fb8aa3b, v3, -v12
	v_rndne_f32_e32 v14, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_sub_f32_e32 v12, v12, v14
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v3
	v_fmac_f32_e32 v13, 0x32a5705f, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add_f32_e32 v12, v12, v13
	v_cvt_i32_f32_e32 v13, v14
	v_exp_f32_e32 v12, v12
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_ldexp_f32 v12, v12, v13
	v_cndmask_b32_e32 v12, 0, v12, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v3
	s_delay_alu instid0(VALU_DEP_2)
	v_cndmask_b32_e32 v3, 0x7f800000, v12, vcc_lo
	ds_store_b32 v1, v3
.LBB2_47:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_and_saveexec_b32 s24, s1
	s_cbranch_execz .LBB2_49
; %bb.48:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_b32 v11, v11 offset:512
	s_waitcnt lgkmcnt(0)
	v_sub_f32_e32 v4, v11, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v11, 0x3fb8aa3b, v4
	v_cmp_ngt_f32_e32 vcc_lo, 0xc2ce8ed0, v4
	v_fma_f32 v12, 0x3fb8aa3b, v4, -v11
	v_rndne_f32_e32 v13, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v12, 0x32a5705f, v4 :: v_dual_sub_f32 v11, v11, v13
	v_add_f32_e32 v11, v11, v12
	v_cvt_i32_f32_e32 v12, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_exp_f32_e32 v11, v11
	v_ldexp_f32 v11, v11, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cndmask_b32_e32 v11, 0, v11, vcc_lo
	v_cmp_nlt_f32_e32 vcc_lo, 0x42b17218, v4
	v_cndmask_b32_e32 v4, 0x7f800000, v11, vcc_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v3, v3, v4
	ds_store_b32 v1, v4 offset:512
.LBB2_49:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	ds_store_b32 v8, v3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s3
	s_cbranch_execz .LBB2_51
; %bb.50:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_stride64_b32 v[3:4], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v4, v3
	ds_store_b32 v8, v1
.LBB2_51:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s4
	s_cbranch_execz .LBB2_53
; %bb.52:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v4, v3
	ds_store_b32 v8, v1
.LBB2_53:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s5
	s_cbranch_execz .LBB2_55
; %bb.54:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v4, v3
	ds_store_b32 v8, v1
.LBB2_55:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s6
	s_cbranch_execz .LBB2_57
; %bb.56:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v4, v3
	ds_store_b32 v8, v1
.LBB2_57:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s7
	s_cbranch_execz .LBB2_59
; %bb.58:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v4, v3
	ds_store_b32 v8, v1
.LBB2_59:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s8
	s_cbranch_execz .LBB2_61
; %bb.60:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v4, v3
	ds_store_b32 v8, v1
.LBB2_61:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s24, s9
	s_cbranch_execz .LBB2_63
; %bb.62:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_2addr_b32 v[3:4], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v4, v3
	ds_store_b32 v8, v1
.LBB2_63:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v2 offset:7168
	v_lshl_add_u32 v3, v0, 2, s34
	s_and_saveexec_b32 s24, s0
	s_cbranch_execz .LBB2_65
; %bb.64:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_b32 v4, v3
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v11, null, v1, v1, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v12, v11
	v_fma_f32 v13, -v11, v12, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v12, v13, v12
	v_div_scale_f32 v13, vcc_lo, v4, v1, v4
	v_mul_f32_e32 v14, v13, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v11, v14, v13
	v_fmac_f32_e32 v14, v15, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v11, -v11, v14, v13
	v_div_fmas_f32 v11, v11, v12, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v4, v11, v1, v4
	ds_store_b32 v3, v4
.LBB2_65:                               ;   in Loop: Header=BB2_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s24
	s_and_saveexec_b32 s24, s1
	s_cbranch_execz .LBB2_17
; %bb.66:                               ;   in Loop: Header=BB2_18 Depth=1
	ds_load_b32 v4, v3 offset:512
	s_waitcnt lgkmcnt(0)
	v_div_scale_f32 v11, null, v1, v1, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v12, v11
	v_fma_f32 v13, -v11, v12, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v12, v13, v12
	v_div_scale_f32 v13, vcc_lo, v4, v1, v4
	v_mul_f32_e32 v14, v13, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v15, -v11, v14, v13
	v_fmac_f32_e32 v14, v15, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v11, -v11, v14, v13
	v_div_fmas_f32 v11, v11, v12, v14
	s_delay_alu instid0(VALU_DEP_1)
	v_div_fixup_f32 v1, v11, v1, v4
	ds_store_b32 v3, v1 offset:512
	s_branch .LBB2_17
.LBB2_67:                               ; %.preheader291
	v_dual_mov_b32 v8, 0 :: v_dual_lshlrev_b32 v3, 1, v0
	v_lshrrev_b32_e32 v7, 2, v0
	v_and_b32_e32 v6, 0x7c, v6
	s_cmp_gt_i32 s17, 0
	s_delay_alu instid0(VALU_DEP_3)
	v_and_b32_e32 v4, 6, v3
	s_cselect_b32 s3, -1, 0
	s_cmp_lt_i32 s17, 1
	s_mov_b32 s0, 0
	s_cbranch_scc1 .LBB2_75
; %bb.68:                               ; %.lr.ph.preheader
	s_cmp_lt_u32 s17, 4
	s_cbranch_scc1 .LBB2_72
; %bb.69:                               ; %.lr.ph.preheader.new
	v_add_co_u32 v1, s0, s22, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s23, 0, s0
	v_add_co_u32 v9, s0, s22, v7
	v_add_co_ci_u32_e64 v10, null, s23, 0, s0
	v_mov_b32_e32 v8, 0
	s_and_b32 s0, s17, 0x7ffffffc
	s_mov_b32 s1, 0
	s_movk_i32 s4, 0x800
.LBB2_70:                               ; %.lr.ph
                                        ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v11, vcc_lo, v9, s16
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s27, v10, vcc_lo
	v_add_co_u32 v13, vcc_lo, v1, s16
	v_add_co_ci_u32_e64 v14, null, s27, v2, vcc_lo
	s_clause 0x2
	flat_load_u8 v15, v[11:12]
	flat_load_u8 v16, v[11:12] offset:48
	flat_load_u8 v17, v[11:12] offset:96
	flat_load_b32 v18, v[13:14] offset:32
	flat_load_u8 v19, v[11:12] offset:144
	s_clause 0x2
	flat_load_b32 v20, v[13:14] offset:80
	flat_load_b32 v21, v[13:14] offset:128
	flat_load_b32 v22, v[13:14] offset:176
	v_add_co_u32 v1, vcc_lo, 0xc0, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v9, vcc_lo, 0xc0, v9
	v_add_co_ci_u32_e64 v10, null, 0, v10, vcc_lo
	s_add_i32 s1, s1, 4
	s_waitcnt vmcnt(6) lgkmcnt(6)
	v_bfe_u32 v16, v16, v4, 2
	s_waitcnt vmcnt(5) lgkmcnt(5)
	v_bfe_u32 v17, v17, v4, 2
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v16, v16
	v_bfe_u32 v15, v15, v4, 2
	v_cvt_f32_ubyte0_e32 v17, v17
	s_waitcnt vmcnt(2) lgkmcnt(2)
	s_delay_alu instid0(VALU_DEP_3)
	v_fma_mix_f32 v16, v20, v16, v20 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_mov_b32_e32 v11, s4
	v_cvt_f32_ubyte0_e32 v15, v15
	s_add_i32 s4, s4, 16
	s_cmp_eq_u32 s0, s1
	ds_load_b128 v[11:14], v11
	v_fma_mix_f32 v15, v18, v15, v18 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_bfe_u32 v18, v19, v4, 2
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v8, v11, v15
	v_cvt_f32_ubyte0_e32 v11, v18
	s_waitcnt vmcnt(1)
	v_fma_mix_f32 v15, v21, v17, v21 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v8, v12, v16
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v11, v22, v11, v22 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v8, v13, v15
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, v14, v11
	s_cbranch_scc0 .LBB2_70
; %bb.71:                               ; %.preheader289.loopexit.unr-lcssa
	s_and_b32 s1, s17, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc0 .LBB2_73
	s_branch .LBB2_75
.LBB2_72:
	v_mov_b32_e32 v8, 0
	s_and_b32 s1, s17, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc1 .LBB2_75
.LBB2_73:                               ; %.lr.ph.epil.preheader
	s_lshl_b32 s4, s0, 2
	s_mul_i32 s0, s0, 48
	s_addk_i32 s4, 0x800
	s_add_u32 s0, s22, s0
	s_addc_u32 s5, s23, 0
	s_add_u32 s0, s0, s16
	s_addc_u32 s5, s5, s27
	v_add_co_u32 v1, s6, s0, v6
	v_add_co_u32 v9, s0, s0, v7
	v_add_co_ci_u32_e64 v2, null, s5, 0, s6
	v_add_co_ci_u32_e64 v10, null, s5, 0, s0
	s_mul_i32 s5, s1, 48
	s_mov_b64 s[0:1], 0
	.p2align	6
.LBB2_74:                               ; %.lr.ph.epil
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, vcc_lo, v9, s0
	v_add_co_ci_u32_e64 v12, null, s1, v10, vcc_lo
	flat_load_u8 v13, v[11:12]
	v_add_co_u32 v11, vcc_lo, v1, s0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s1, v2, vcc_lo
	flat_load_b32 v11, v[11:12] offset:32
	v_mov_b32_e32 v12, s4
	s_add_i32 s4, s4, 4
	s_add_u32 s0, s0, 48
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s5, s0
	ds_load_b32 v12, v12
	s_waitcnt vmcnt(1) lgkmcnt(2)
	v_bfe_u32 v13, v13, v4, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v13, v13
	s_waitcnt vmcnt(0) lgkmcnt(1)
	v_fma_mix_f32 v11, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, v12, v11
	s_cbranch_scc1 .LBB2_74
.LBB2_75:                               ; %.preheader289
	s_lshl_b32 s0, s18, 7
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s1, s0, 31
	s_cmp_gt_i32 s19, 0
	s_cselect_b32 s4, -1, 0
	s_cmp_lt_i32 s19, 1
	s_cbranch_scc1 .LBB2_78
; %bb.76:                               ; %.lr.ph343.preheader
	s_lshl_b64 s[6:7], s[0:1], 1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	s_add_u32 s5, s30, s6
	s_addc_u32 s6, s31, s7
	v_add_co_u32 v1, s5, s5, v3
	v_add_co_ci_u32_e64 v2, null, s6, 0, s5
	s_lshl_b32 s5, s17, 2
	s_mov_b32 s6, s19
	s_addk_i32 s5, 0x800
.LBB2_77:                               ; %.lr.ph343
                                        ; =>This Inner Loop Header: Depth=1
	flat_load_u16 v9, v[1:2]
	v_mov_b32_e32 v10, s5
	v_add_co_u32 v1, vcc_lo, 0x100, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_add_i32 s6, s6, -1
	s_add_i32 s5, s5, 4
	s_cmp_eq_u32 s6, 0
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_lshlrev_b32_e32 v9, 16, v9
	ds_load_b32 v10, v10
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v8, v10, v9
	s_cbranch_scc0 .LBB2_77
.LBB2_78:                               ; %._crit_edge
	s_and_not1_b32 vcc_lo, exec_lo, s3
	ds_store_b32 v5, v8 offset:6144
	s_cbranch_vccnz .LBB2_82
; %bb.79:                               ; %.lr.ph.1.preheader
	s_add_u32 s3, s22, s16
	s_addc_u32 s5, s23, s27
	v_add_co_u32 v1, s6, s3, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v2, null, s5, 0, s6
	v_mov_b32_e32 v6, 0
	v_add_co_u32 v8, vcc_lo, v1, 34
	v_add_co_u32 v1, s3, s3, v7
	s_delay_alu instid0(VALU_DEP_4)
	v_add_co_ci_u32_e64 v9, null, 0, v2, vcc_lo
	v_add_co_ci_u32_e64 v2, null, s5, 0, s3
	s_movk_i32 s3, 0xc00
	s_mov_b32 s5, s17
	.p2align	6
.LBB2_80:                               ; %.lr.ph.1
                                        ; =>This Inner Loop Header: Depth=1
	flat_load_u8 v7, v[1:2]
	v_add_co_u32 v10, vcc_lo, -2, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, -1, v9, vcc_lo
	v_add_co_u32 v8, vcc_lo, v8, 48
	v_add_co_ci_u32_e64 v9, null, 0, v9, vcc_lo
	flat_load_b32 v10, v[10:11]
	v_mov_b32_e32 v11, s3
	v_add_co_u32 v1, vcc_lo, v1, 48
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	ds_load_b32 v11, v11
	s_add_i32 s5, s5, -1
	s_add_i32 s3, s3, 4
	s_cmp_lg_u32 s5, 0
	s_waitcnt vmcnt(1) lgkmcnt(2)
	v_bfe_u32 v7, v7, v4, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v7, v7
	s_waitcnt vmcnt(0) lgkmcnt(1)
	v_fma_mix_f32 v7, v10, v7, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v11, v7
	s_cbranch_scc1 .LBB2_80
; %bb.81:                               ; %Flow1954
	v_add_nc_u32_e32 v4, 0x1800, v5
	s_and_not1_b32 vcc_lo, exec_lo, s4
	s_cbranch_vccz .LBB2_83
	s_branch .LBB2_85
.LBB2_82:
	v_mov_b32_e32 v6, 0
	v_add_nc_u32_e32 v4, 0x1800, v5
	s_and_not1_b32 vcc_lo, exec_lo, s4
	s_cbranch_vccnz .LBB2_85
.LBB2_83:                               ; %.lr.ph343.1
	s_lshl_b32 s3, s17, 2
	s_lshl_b64 s[4:5], s[0:1], 1
	s_add_i32 s0, s3, 0xc00
	s_add_u32 s1, s22, s28
	s_addc_u32 s3, s23, s29
	s_add_u32 s1, s1, s16
	s_addc_u32 s3, s3, s27
	s_add_u32 s1, s1, s4
	s_addc_u32 s3, s3, s5
	v_add_co_u32 v1, s1, s1, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s3, 0, s1
.LBB2_84:                               ; =>This Inner Loop Header: Depth=1
	flat_load_u16 v3, v[1:2]
	v_mov_b32_e32 v5, s0
	v_add_co_u32 v1, vcc_lo, 0x100, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	ds_load_b32 v5, v5
	s_add_i32 s19, s19, -1
	s_add_i32 s0, s0, 4
	s_cmp_lg_u32 s19, 0
	s_waitcnt vmcnt(0) lgkmcnt(1)
	v_lshlrev_b32_e32 v3, 16, v3
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v6, v5, v3
	s_cbranch_scc1 .LBB2_84
.LBB2_85:                               ; %._crit_edge.1
	v_dual_mov_b32 v1, 0 :: v_dual_lshlrev_b32 v2, 12, v0
	s_ashr_i32 s21, s20, 31
	ds_store_b32 v4, v6 offset:512
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, s0, s12, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s13, 0, s0
	s_lshl_b64 s[0:1], s[20:21], 1
	s_movk_i32 s3, 0x1800
	v_add_co_u32 v3, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v4, null, s1, v4, vcc_lo
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
.LBB2_86:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB2_86
; %bb.87:                               ; %.preheader.1
	s_movk_i32 s3, 0x1a00
	s_mov_b64 s[4:5], 0
.LBB2_88:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_88
; %bb.89:                               ; %.preheader.1373
	s_lshl_b32 s2, s2, 10
	s_add_u32 s0, s12, s0
	v_or_b32_e32 v3, s2, v0
	s_addc_u32 s1, s13, s1
	v_add_co_u32 v2, s0, s0, v2
	s_movk_i32 s3, 0x1800
	v_ashrrev_i32_e32 v4, 31, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], 2, v[3:4]
	v_mov_b32_e32 v4, 0
	v_add_co_ci_u32_e64 v3, null, s1, 0, s0
	s_mov_b64 s[0:1], 0
	v_add_co_u32 v5, vcc_lo, s14, v5
	v_add_co_ci_u32_e64 v6, null, s15, v6, vcc_lo
	global_store_b32 v[5:6], v1, off
.LBB2_90:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_90
; %bb.91:                               ; %.preheader.1.1
	s_movk_i32 s3, 0x1a00
	s_mov_b64 s[0:1], 0
.LBB2_92:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_92
; %bb.93:                               ; %.preheader.2
	s_ashr_i32 s0, s2, 31
	v_add_co_u32 v0, s1, v0, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v1, null, 0, s0, s1
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1800
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s14, v0
	v_add_co_ci_u32_e64 v1, null, s15, v1, vcc_lo
	global_store_b32 v[0:1], v4, off offset:512
.LBB2_94:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_94
; %bb.95:                               ; %.preheader.1.2
	s_movk_i32 s2, 0x1a00
	s_mov_b64 s[0:1], 0
.LBB2_96:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_96
; %bb.97:                               ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1800
	global_store_b32 v[0:1], v5, off offset:1024
.LBB2_98:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_98
; %bb.99:                               ; %.preheader.1.3
	s_movk_i32 s2, 0x1a00
	s_mov_b64 s[0:1], 0
.LBB2_100:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_100
; %bb.101:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1800
	global_store_b32 v[0:1], v4, off offset:1536
.LBB2_102:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_102
; %bb.103:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1a00
	s_mov_b64 s[0:1], 0
.LBB2_104:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_104
; %bb.105:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1800
	global_store_b32 v[0:1], v5, off offset:2048
.LBB2_106:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_106
; %bb.107:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1a00
	s_mov_b64 s[0:1], 0
.LBB2_108:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_108
; %bb.109:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1800
	global_store_b32 v[0:1], v4, off offset:2560
.LBB2_110:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_110
; %bb.111:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1a00
	s_mov_b64 s[0:1], 0
.LBB2_112:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_112
; %bb.113:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1800
	global_store_b32 v[0:1], v5, off offset:3072
.LBB2_114:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_114
; %bb.115:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1a00
	s_mov_b64 s[0:1], 0
.LBB2_116:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB2_116
; %bb.117:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
.LBB2_118:                              ; %.loopexit
	s_nop 0
	s_sendmsg sendmsg(MSG_DEALLOC_VGPRS)
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii
		.amdhsa_group_segment_fixed_size 8512
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
		.amdhsa_next_free_vgpr 98
		.amdhsa_next_free_sgpr 56
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
	.section	.text._Z11query_groupILi1EEvPKPKhPKfPKtPfiiii,"axG",@progbits,_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii,comdat
.Lfunc_end2:
	.size	_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii, .Lfunc_end2-_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii
                                        ; -- End function
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.num_vgpr, 98
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.num_agpr, 0
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.numbered_sgpr, 56
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.num_named_barrier, 0
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.private_seg_size, 0
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.uses_vcc, 1
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.uses_flat_scratch, 1
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.has_dyn_sized_stack, 0
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.has_recursion, 0
	.set _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 14608
; TotalNumSgprs: 58
; NumVgprs: 98
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 8512 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 12
; NumSGPRsForWavesPerEU: 58
; NumVGPRsForWavesPerEU: 98
; Occupancy: 12
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
    .name:           _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi0EEvPKPKhPKfPKtPfiiii.kd
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
    .group_segment_fixed_size: 8512
    .kernarg_segment_align: 8
    .kernarg_segment_size: 48
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii
    .private_segment_fixed_size: 0
    .sgpr_count:     58
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi1EEvPKPKhPKfPKtPfiiii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     98
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
