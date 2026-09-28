	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.protected	_ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii ; -- Begin function _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii
	.globl	_ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii
	.p2align	8
	.type	_ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii,@function
_ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii: ; @_ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii
; %bb.0:
	v_cmp_gt_u32_e32 vcc_lo, 0x80, v0
	s_cmp_lt_i32 s2, 8
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s3, s3, vcc_lo
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB0_11
; %bb.1:
	s_clause 0x1
	s_load_b64 s[8:9], s[0:1], 0x18
	s_load_b128 s[4:7], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_add_i32 s8, s8, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_ashr_i32 s3, s8, 31
	s_lshr_b32 s3, s3, 27
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s3, s8, s3
	s_lshr_b32 s11, s3, 5
	s_cmp_eq_u32 s9, 0
	s_cselect_b32 s10, -1, 0
	s_cmp_lg_u32 s9, 0
	s_mul_i32 s9, s11, 0xffffe600
	s_cselect_b32 s3, -1, 0
	s_lshl_b32 s8, s8, 8
	s_mov_b32 s11, -1
	s_add_i32 s8, s9, s8
	s_mov_b32 s9, 0
	s_addk_i32 s8, 0x100
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmpk_gt_i32 s8, 0x4a00
	s_cbranch_scc1 .LBB0_5
; %bb.2:                                ; %.lr.ph
	s_load_b64 s[0:1], s[0:1], 0x10
	v_lshl_add_u32 v1, s2, 8, v0
	s_and_b32 s10, s10, exec_lo
	s_mul_i32 s10, s2, 0x4a00
	v_add_nc_u32_e32 v3, 0xffffff80, v0
	s_cselect_b32 s12, s6, s4
	v_ashrrev_i32_e32 v2, 31, v1
	s_cselect_b32 s11, s7, s5
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v1, vcc_lo, s0, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s1, v2, vcc_lo
	s_mul_hi_i32 s1, s2, 0x4a00
	s_add_u32 s0, s12, s10
	s_addc_u32 s1, s11, s1
	.p2align	6
.LBB0_3:                                ; =>This Inner Loop Header: Depth=1
	global_load_d16_u8 v4, v[1:2], off
	v_add3_u32 v5, s8, v3, 0xffffff80
	v_add_co_u32 v1, vcc_lo, 0x80, v1
	v_add_co_u32 v3, s2, 0x80, v3
	s_delay_alu instid0(VALU_DEP_3)
	v_ashrrev_i32_e32 v6, 31, v5
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v5, vcc_lo, s0, v5
	s_xor_b32 s2, s2, -1
	v_add_co_ci_u32_e64 v6, null, s1, v6, vcc_lo
	s_and_b32 s2, exec_lo, s2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s9, s2, s9
	s_waitcnt vmcnt(0)
	global_store_b8 v[5:6], v4, off
	s_and_not1_b32 exec_lo, exec_lo, s9
	s_cbranch_execnz .LBB0_3
; %bb.4:                                ; %Flow
	s_or_b32 exec_lo, exec_lo, s9
	s_mov_b32 s11, 0
.LBB0_5:                                ; %Flow51
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s11
	s_cbranch_vccz .LBB0_11
; %bb.6:
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 exec_lo, exec_lo, vcc_lo
	s_cbranch_execz .LBB0_11
; %bb.7:
	s_and_not1_b32 vcc_lo, exec_lo, s3
	s_mov_b32 s0, -1
	s_cbranch_vccnz .LBB0_9
; %bb.8:
	v_dual_mov_b32 v0, 0x43000 :: v_dual_mov_b32 v1, 1
	s_mov_b32 s0, 0
	global_store_b32 v0, v1, s[4:5] offset:1992
.LBB0_9:                                ; %Flow48
	s_and_not1_b32 vcc_lo, exec_lo, s0
	s_cbranch_vccnz .LBB0_11
; %bb.10:
	v_dual_mov_b32 v0, 0x4a000 :: v_dual_mov_b32 v1, 1
	global_store_b32 v0, v1, s[6:7] offset:2048
.LBB0_11:                               ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii
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
		.amdhsa_next_free_vgpr 7
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
	.text
.Lfunc_end0:
	.size	_ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii, .Lfunc_end0-_ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii
                                        ; -- End function
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.num_vgpr, 7
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.num_agpr, 0
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.numbered_sgpr, 13
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.num_named_barrier, 0
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.private_seg_size, 0
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.uses_vcc, 1
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.uses_flat_scratch, 0
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.has_dyn_sized_stack, 0
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.has_recursion, 0
	.set _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 440
; TotalNumSgprs: 15
; NumVgprs: 7
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 0
; NumSGPRsForWavesPerEU: 15
; NumVGPRsForWavesPerEU: 7
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
	.protected	_ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii ; -- Begin function _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii
	.globl	_ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii
	.p2align	8
	.type	_ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii,@function
_ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii: ; @_ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii
; %bb.0:
	s_load_b256 s[4:11], s[0:1], 0x0
	v_cmp_lt_u32_e64 s0, 0x7f, v0
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s11, 0
	s_cbranch_scc0 .LBB1_19
; %bb.1:
	s_cmp_eq_u32 s2, 0
	s_cselect_b32 s1, -1, 0
	s_xor_b32 s3, s0, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s1, s1, s3
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB1_18
; %bb.2:
	s_mov_b32 s11, exec_lo
	v_cmpx_gt_u32_e32 33, v0
	s_cbranch_execz .LBB1_8
; %bb.3:
	v_add_co_u32 v1, s1, s4, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, s5, 0, s1
	s_mov_b32 s1, 0
	v_add_co_u32 v1, vcc_lo, 0x43000, v1
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_mov_b32 s14, exec_lo
	global_load_d16_u8 v2, v[1:2], off offset:1941
	v_mov_b32_e32 v1, 0
	s_waitcnt vmcnt(0)
	v_cmpx_ne_u16_e32 0, v2.l
	s_cbranch_execz .LBB1_7
; %bb.4:                                ; %.lr.ph
	v_lshlrev_b32_e32 v2, 11, v0
	s_add_u32 s15, s8, 0x800
	s_addc_u32 s16, s9, 0
	s_mov_b64 s[12:13], 0
	s_mov_b32 s17, 0
	v_add_co_u32 v2, s1, s4, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v3, null, s5, 0, s1
                                        ; implicit-def: $sgpr18
	v_add_co_u32 v2, vcc_lo, 0x32e00, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
	.p2align	6
.LBB1_5:                                ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v2, s12
	v_add_co_ci_u32_e64 v5, null, s13, v3, vcc_lo
	s_add_u32 s20, s15, s12
	s_addc_u32 s21, s16, s13
	global_load_d16_u8 v6, v1, s[20:21]
	global_load_d16_u8 v4, v[4:5], off
	s_cmpk_gt_u32 s12, 0x7fe
	s_cselect_b32 s19, -1, 0
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v5, 0xff, v6
	s_waitcnt vmcnt(0)
	v_and_b16 v4.l, 0xff, v4.l
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_ne_u16_e32 vcc_lo, v4.l, v5.l
	v_cmp_eq_u16_e64 s1, v4.l, v5.l
	s_or_b32 s19, s19, vcc_lo
	s_add_u32 s12, s12, 1
	s_addc_u32 s13, s13, 0
	s_and_b32 s19, exec_lo, s19
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_or_b32 s17, s19, s17
	s_and_not1_b32 s18, s18, exec_lo
	s_and_b32 s1, s1, exec_lo
	s_or_b32 s18, s18, s1
	s_and_not1_b32 exec_lo, exec_lo, s17
	s_cbranch_execnz .LBB1_5
; %bb.6:                                ; %Flow138
	s_or_b32 exec_lo, exec_lo, s17
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s1, s18, exec_lo
.LBB1_7:                                ; %Flow139
	s_or_b32 exec_lo, exec_lo, s14
	v_cndmask_b32_e64 v1, 0, 1, s1
	ds_store_b8 v0, v1
.LBB1_8:                                ; %Flow140
	s_or_b32 exec_lo, exec_lo, s11
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mov_b32 s1, exec_lo
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmpx_eq_u32_e32 0, v0
	s_cbranch_execz .LBB1_15
; %bb.9:                                ; %.preheader84
	v_dual_mov_b32 v6, 0x43000 :: v_dual_mov_b32 v5, 0
	s_add_u32 s12, s4, 0x43795
	s_addc_u32 s13, s5, 0
	s_clause 0x1
	global_load_b128 v[7:10], v6, s[4:5] offset:1941
	global_load_b128 v[15:18], v6, s[4:5] offset:1957
	ds_load_b128 v[11:14], v5
	ds_load_b128 v[1:4], v5 offset:16
	s_waitcnt lgkmcnt(1)
	v_readfirstlane_b32 s15, v11
	v_readfirstlane_b32 s14, v12
	v_readfirstlane_b32 s11, v13
	v_readfirstlane_b32 s18, v14
	s_and_b32 s17, s15, 0xff
	s_lshr_b32 s20, s15, 24
	s_lshr_b32 s21, s14, 24
	s_lshr_b32 s22, s11, 24
	s_lshr_b32 s16, s18, 24
	s_cmp_eq_u32 s17, 0
	s_cselect_b32 s26, -1, 0
	s_waitcnt vmcnt(1)
	v_readfirstlane_b32 s23, v7
	v_readfirstlane_b32 s24, v8
	v_readfirstlane_b32 s25, v9
	v_readfirstlane_b32 s19, v10
	v_cndmask_b32_e64 v7, 0, -1, s26
	s_and_b32 s30, s23, 0xff
	s_lshr_b32 s27, s23, 24
	s_lshr_b32 s28, s24, 24
	s_lshr_b32 s29, s25, 24
	s_lshr_b32 s17, s19, 24
	s_cmp_lg_u32 s30, 0
	s_cselect_b32 s30, -1, 0
	s_bfe_u32 s31, s15, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s31, 0
	v_readfirstlane_b32 s31, v7
	s_cselect_b32 s33, -1, 0
	v_cndmask_b32_e64 v7, 0, -1, s30
	s_and_b32 s33, s33, s26
	s_and_b32 s34, s33, exec_lo
	s_cselect_b32 s31, 1, s31
	s_bfe_u32 s34, s23, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_cmp_eq_u32 s34, 0
	v_readfirstlane_b32 s34, v7
	s_cselect_b32 s35, -1, 0
	s_and_b32 s35, s35, s30
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s36, s35, exec_lo
	s_cselect_b32 s34, 1, s34
	s_bfe_u32 s15, s15, 0x80010
	s_cmp_lg_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_xor_b32 s33, s33, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s33
	s_and_b32 s15, s15, s26
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s15, 2, s31
	s_bfe_u32 s23, s23, 0x80010
	s_cmp_eq_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_xor_b32 s26, s35, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, s26
	s_and_b32 s23, s23, s30
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s23, 2, s34
	s_cmp_lg_u32 s20, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s26, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, s26
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s15, 3, s15
	s_cmp_eq_u32 s27, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s23, 0
	s_cselect_b32 s26, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, s26
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s20, 3, s23
	s_and_b32 s23, s14, 0xff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s26, -1, 0
	s_and_b32 s23, s23, s26
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s15, 4, s15
	s_and_b32 s23, s24, 0xff
	s_cmp_eq_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s20, 0
	s_cselect_b32 s26, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, s26
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s20, 4, s20
	s_bfe_u32 s23, s14, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s26, -1, 0
	s_and_b32 s23, s23, s26
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s15, 5, s15
	s_bfe_u32 s23, s24, 0x80008
	s_cmp_eq_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s20, 0
	s_cselect_b32 s26, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s23, s23, s26
	s_waitcnt lgkmcnt(0)
	v_readfirstlane_b32 s26, v1
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s20, 5, s20
	s_bfe_u32 s14, s14, 0x80010
	global_load_u8 v1, v6, s[4:5] offset:1973
	s_cmp_lg_u32 s14, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s23, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s14, s14, s23
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s14, 6, s15
	s_bfe_u32 s15, s24, 0x80010
	s_waitcnt vmcnt(1)
	v_readfirstlane_b32 s24, v16
	s_cmp_eq_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s20, 0
	s_cselect_b32 s23, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s23
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s15, 6, s20
	s_cmp_lg_u32 s21, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s21, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, s21
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s14, 7, s14
	s_cmp_eq_u32 s28, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s21, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, s21
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s15, 7, s15
	s_and_b32 s20, s11, 0xff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s20, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s21, -1, 0
	s_and_b32 s20, s20, s21
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s14, 8, s14
	s_and_b32 s20, s25, 0xff
	s_cmp_eq_u32 s20, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s21, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, s21
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s15, 8, s15
	s_bfe_u32 s20, s11, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s20, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s21, -1, 0
	s_and_b32 s20, s20, s21
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s14, 9, s14
	s_bfe_u32 s20, s25, 0x80008
	s_cmp_eq_u32 s20, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s21, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, s21
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s15, 9, s15
	s_bfe_u32 s11, s11, 0x80010
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s11, 0
	s_cselect_b32 s11, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s20, -1, 0
	s_and_b32 s11, s11, s20
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s11, s11, exec_lo
	s_cselect_b32 s11, 10, s14
	s_bfe_u32 s14, s25, 0x80010
	s_cmp_eq_u32 s14, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s20, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s14, s14, s20
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s14, 10, s15
	s_cmp_lg_u32 s22, 0
	v_readfirstlane_b32 s22, v2
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s11, 0
	ds_load_u8 v2, v5 offset:32
	s_cselect_b32 s20, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s20
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s11, 11, s11
	s_cmp_eq_u32 s29, 0
	v_readfirstlane_b32 s29, v15
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s20, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s20
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s14, 11, s14
	s_and_b32 s15, s18, 0xff
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lg_u32 s15, 0
	s_waitcnt lgkmcnt(0)
	v_cmp_ne_u32_e32 vcc_lo, 0, v2
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s11, 0
	s_cselect_b32 s20, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s20
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s11, 12, s11
	s_and_b32 s15, s19, 0xff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_eq_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s20, -1, 0
	s_and_b32 s15, s15, s20
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s14, 12, s14
	s_bfe_u32 s15, s18, 0x80008
	s_cmp_lg_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s11, 0
	s_cselect_b32 s20, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s20
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s11, 13, s11
	s_bfe_u32 s15, s19, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_eq_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s20, -1, 0
	s_and_b32 s15, s15, s20
	v_readfirstlane_b32 s20, v17
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s14, 13, s14
	s_bfe_u32 s15, s18, 0x80010
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s11, 0
	s_cselect_b32 s18, -1, 0
	s_and_b32 s15, s15, s18
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s11, 14, s11
	s_bfe_u32 s15, s19, 0x80010
	v_readfirstlane_b32 s19, v3
	s_cmp_eq_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s18, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s18
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s14, 14, s14
	s_cmp_lg_u32 s16, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s11, 0
	s_cselect_b32 s16, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s16
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s18, 15, s11
	s_cmp_eq_u32 s17, 0
	s_cselect_b32 s11, -1, 0
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s15, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s11, s11, s15
	v_readfirstlane_b32 s15, v4
	s_and_b32 s11, s11, exec_lo
	s_cselect_b32 s27, 15, s14
	s_and_b32 s14, s26, 0xff
	s_lshr_b32 s28, s26, 24
	s_lshr_b32 s21, s22, 24
	s_lshr_b32 s17, s19, 24
	s_lshr_b32 s11, s15, 24
	s_cmp_lg_u32 s14, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s18, 0
	s_cselect_b32 s16, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s14, s14, s16
	v_readfirstlane_b32 s16, v18
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s30, 16, s18
	s_and_b32 s31, s29, 0xff
	s_lshr_b32 s25, s29, 24
	s_lshr_b32 s23, s24, 24
	s_lshr_b32 s18, s20, 24
	s_lshr_b32 s14, s16, 24
	s_cmp_eq_u32 s31, 0
	s_cselect_b32 s31, -1, 0
	s_cmp_lt_i32 s27, 0
	s_cselect_b32 s33, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s31, s31, s33
	s_and_b32 s31, s31, exec_lo
	s_cselect_b32 s27, 16, s27
	s_bfe_u32 s31, s26, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s31, 0
	s_cselect_b32 s31, -1, 0
	s_cmp_lt_i32 s30, 0
	s_cselect_b32 s33, -1, 0
	s_and_b32 s31, s31, s33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s31, s31, exec_lo
	s_cselect_b32 s30, 17, s30
	s_bfe_u32 s31, s29, 0x80008
	s_cmp_eq_u32 s31, 0
	s_cselect_b32 s31, -1, 0
	s_cmp_lt_i32 s27, 0
	s_cselect_b32 s33, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s31, s31, s33
	s_and_b32 s31, s31, exec_lo
	s_cselect_b32 s27, 17, s27
	s_bfe_u32 s26, s26, 0x80010
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s26, 0
	s_cselect_b32 s26, -1, 0
	s_cmp_lt_i32 s30, 0
	s_cselect_b32 s31, -1, 0
	s_and_b32 s26, s26, s31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s26, s26, exec_lo
	s_cselect_b32 s26, 18, s30
	s_bfe_u32 s29, s29, 0x80010
	s_cmp_eq_u32 s29, 0
	s_cselect_b32 s29, -1, 0
	s_cmp_lt_i32 s27, 0
	s_cselect_b32 s30, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s29, s29, s30
	s_and_b32 s29, s29, exec_lo
	s_cselect_b32 s27, 18, s27
	s_cmp_lg_u32 s28, 0
	s_cselect_b32 s28, -1, 0
	s_cmp_lt_i32 s26, 0
	s_cselect_b32 s29, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s28, s28, s29
	s_and_b32 s28, s28, exec_lo
	s_cselect_b32 s26, 19, s26
	s_cmp_eq_u32 s25, 0
	s_cselect_b32 s25, -1, 0
	s_cmp_lt_i32 s27, 0
	s_cselect_b32 s28, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s25, s25, s28
	s_and_b32 s25, s25, exec_lo
	s_cselect_b32 s25, 19, s27
	s_and_b32 s27, s22, 0xff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s27, 0
	s_cselect_b32 s27, -1, 0
	s_cmp_lt_i32 s26, 0
	s_cselect_b32 s28, -1, 0
	s_and_b32 s27, s27, s28
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s27, s27, exec_lo
	s_cselect_b32 s26, 20, s26
	s_and_b32 s27, s24, 0xff
	s_cmp_eq_u32 s27, 0
	s_cselect_b32 s27, -1, 0
	s_cmp_lt_i32 s25, 0
	s_cselect_b32 s28, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s27, s27, s28
	s_and_b32 s27, s27, exec_lo
	s_cselect_b32 s25, 20, s25
	s_bfe_u32 s27, s22, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s27, 0
	s_cselect_b32 s27, -1, 0
	s_cmp_lt_i32 s26, 0
	s_cselect_b32 s28, -1, 0
	s_and_b32 s27, s27, s28
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s27, s27, exec_lo
	s_cselect_b32 s26, 21, s26
	s_bfe_u32 s27, s24, 0x80008
	s_cmp_eq_u32 s27, 0
	s_cselect_b32 s27, -1, 0
	s_cmp_lt_i32 s25, 0
	s_cselect_b32 s28, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s27, s27, s28
	s_and_b32 s27, s27, exec_lo
	s_cselect_b32 s25, 21, s25
	s_bfe_u32 s22, s22, 0x80010
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s22, 0
	s_cselect_b32 s22, -1, 0
	s_cmp_lt_i32 s26, 0
	s_cselect_b32 s27, -1, 0
	s_and_b32 s22, s22, s27
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s22, s22, exec_lo
	s_cselect_b32 s22, 22, s26
	s_bfe_u32 s24, s24, 0x80010
	s_cmp_eq_u32 s24, 0
	s_cselect_b32 s24, -1, 0
	s_cmp_lt_i32 s25, 0
	s_cselect_b32 s26, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s24, s24, s26
	s_and_b32 s24, s24, exec_lo
	s_cselect_b32 s24, 22, s25
	s_cmp_lg_u32 s21, 0
	s_cselect_b32 s21, -1, 0
	s_cmp_lt_i32 s22, 0
	s_cselect_b32 s25, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s21, s21, s25
	s_and_b32 s21, s21, exec_lo
	s_cselect_b32 s21, 23, s22
	s_cmp_eq_u32 s23, 0
	s_cselect_b32 s22, -1, 0
	s_cmp_lt_i32 s24, 0
	s_cselect_b32 s23, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s22, s22, s23
	s_and_b32 s22, s22, exec_lo
	s_cselect_b32 s22, 23, s24
	s_and_b32 s23, s19, 0xff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s21, 0
	s_cselect_b32 s24, -1, 0
	s_and_b32 s23, s23, s24
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s21, 24, s21
	s_and_b32 s23, s20, 0xff
	s_cmp_eq_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s22, 0
	s_cselect_b32 s24, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, s24
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s22, 24, s22
	s_bfe_u32 s23, s19, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s21, 0
	s_cselect_b32 s24, -1, 0
	s_and_b32 s23, s23, s24
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s21, 25, s21
	s_bfe_u32 s23, s20, 0x80008
	s_cmp_eq_u32 s23, 0
	s_cselect_b32 s23, -1, 0
	s_cmp_lt_i32 s22, 0
	s_cselect_b32 s24, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s23, s23, s24
	s_and_b32 s23, s23, exec_lo
	s_cselect_b32 s22, 25, s22
	s_bfe_u32 s19, s19, 0x80010
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s19, 0
	s_cselect_b32 s19, -1, 0
	s_cmp_lt_i32 s21, 0
	s_cselect_b32 s23, -1, 0
	s_and_b32 s19, s19, s23
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s19, s19, exec_lo
	s_cselect_b32 s19, 26, s21
	s_bfe_u32 s20, s20, 0x80010
	s_cmp_eq_u32 s20, 0
	s_cselect_b32 s20, -1, 0
	s_cmp_lt_i32 s22, 0
	s_cselect_b32 s21, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s20, s20, s21
	s_and_b32 s20, s20, exec_lo
	s_cselect_b32 s20, 26, s22
	s_cmp_lg_u32 s17, 0
	s_cselect_b32 s17, -1, 0
	s_cmp_lt_i32 s19, 0
	s_cselect_b32 s21, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s17, s17, s21
	s_and_b32 s17, s17, exec_lo
	s_cselect_b32 s17, 27, s19
	s_cmp_eq_u32 s18, 0
	s_cselect_b32 s18, -1, 0
	s_cmp_lt_i32 s20, 0
	s_cselect_b32 s19, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s18, s18, s19
	s_and_b32 s18, s18, exec_lo
	s_cselect_b32 s18, 27, s20
	s_and_b32 s19, s15, 0xff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s19, 0
	s_cselect_b32 s19, -1, 0
	s_cmp_lt_i32 s17, 0
	s_cselect_b32 s20, -1, 0
	s_and_b32 s19, s19, s20
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s19, s19, exec_lo
	s_cselect_b32 s17, 28, s17
	s_and_b32 s19, s16, 0xff
	s_cmp_eq_u32 s19, 0
	s_cselect_b32 s19, -1, 0
	s_cmp_lt_i32 s18, 0
	s_cselect_b32 s20, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s19, s19, s20
	s_and_b32 s19, s19, exec_lo
	s_cselect_b32 s18, 28, s18
	s_bfe_u32 s19, s15, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s19, 0
	s_cselect_b32 s19, -1, 0
	s_cmp_lt_i32 s17, 0
	s_cselect_b32 s20, -1, 0
	s_and_b32 s19, s19, s20
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s19, s19, exec_lo
	s_cselect_b32 s17, 29, s17
	s_bfe_u32 s19, s16, 0x80008
	s_cmp_eq_u32 s19, 0
	s_cselect_b32 s19, -1, 0
	s_cmp_lt_i32 s18, 0
	s_cselect_b32 s20, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s19, s19, s20
	s_and_b32 s19, s19, exec_lo
	s_cselect_b32 s18, 29, s18
	s_bfe_u32 s15, s15, 0x80010
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_cmp_lg_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s17, 0
	s_cselect_b32 s19, -1, 0
	s_and_b32 s15, s15, s19
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s15, 30, s17
	s_bfe_u32 s16, s16, 0x80010
	s_cmp_eq_u32 s16, 0
	s_cselect_b32 s16, -1, 0
	s_cmp_lt_i32 s18, 0
	s_cselect_b32 s17, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s16, s16, s17
	s_and_b32 s16, s16, exec_lo
	s_cselect_b32 s16, 30, s18
	s_cmp_lg_u32 s11, 0
	s_cselect_b32 s11, -1, 0
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s17, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s11, s11, s17
	s_and_b32 s11, s11, exec_lo
	s_cselect_b32 s11, 31, s15
	s_cmp_eq_u32 s14, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s16, 0
	s_cselect_b32 s15, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s14, s14, s15
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s14, 31, s16
	s_cmp_lt_i32 s11, 0
	s_cselect_b32 s15, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s15, vcc_lo, s15
	s_waitcnt vmcnt(0)
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s15, 32, s11
	s_cmp_lt_i32 s14, 0
	s_cselect_b32 s11, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s11, vcc_lo, s11
	s_and_b32 s11, s11, exec_lo
	s_cselect_b32 s11, 32, s14
	s_cmp_lt_i32 s15, 0
	s_cselect_b32 s11, s11, s15
	s_lshr_b32 s14, s15, 31
	s_cmp_lt_i32 s11, 0
	v_dual_mov_b32 v1, s14 :: v_dual_mov_b32 v2, s11
	s_cselect_b32 s17, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s17
	ds_store_2addr_b32 v5, v1, v2 offset0:9 offset1:10
	s_cbranch_vccnz .LBB1_13
; %bb.10:
	s_load_b32 s16, s[4:5], 0x437b8
	s_add_u32 s14, s4, 0x437b8
	s_addc_u32 s15, s5, 0
	s_add_i32 s18, s10, -1
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s16, s18
	s_cselect_b32 s17, -1, 0
	s_cmp_eq_u32 s16, s18
	s_cbranch_scc0 .LBB1_13
; %bb.11:
	s_load_b32 s17, s[4:5], 0x437bc
	s_waitcnt lgkmcnt(0)
	s_cmp_eq_u32 s17, 1
	s_mov_b32 s17, -1
	s_cbranch_scc0 .LBB1_13
; %bb.12:
	v_dual_mov_b32 v3, s11 :: v_dual_mov_b32 v4, 0x43000
	s_mul_hi_i32 s11, s16, 0x3e0f83e1
	v_mov_b32_e32 v1, s10
	s_lshr_b32 s17, s11, 31
	global_load_u8 v2, v3, s[12:13]
	s_ashr_i32 s11, s11, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_add_i32 s11, s11, s17
	s_mov_b32 s17, 0
	s_mul_i32 s11, s11, 33
	s_sub_i32 s11, s16, s11
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s16, s11, 31
	s_add_u32 s18, s4, s11
	s_addc_u32 s19, s5, s16
	s_min_i32 s11, s10, 33
	s_waitcnt vmcnt(0)
	v_dual_mov_b32 v6, s11 :: v_dual_add_nc_u32 v5, 1, v2
	v_mov_b32_e32 v2, 0
	s_clause 0x3
	global_store_b8 v3, v5, s[12:13]
	global_store_b8 v4, v3, s[18:19] offset:1760
	global_store_b64 v2, v[1:2], s[14:15]
	global_store_b32 v4, v6, s[4:5] offset:1988
.LBB1_13:                               ; %Flow133
	s_and_b32 vcc_lo, exec_lo, s17
	s_cbranch_vccz .LBB1_15
; %bb.14:
	v_dual_mov_b32 v1, 0x43000 :: v_dual_mov_b32 v2, 2
	v_dual_mov_b32 v3, -1 :: v_dual_mov_b32 v4, 0
	global_store_b32 v1, v2, s[4:5] offset:1992
	ds_store_b32 v4, v3 offset:40
.LBB1_15:
	s_or_b32 exec_lo, exec_lo, s1
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_waitcnt_vscnt null, 0x0
	s_barrier
	buffer_gl0_inv
	ds_load_2addr_b32 v[2:3], v1 offset0:9 offset1:10
	s_waitcnt lgkmcnt(0)
	v_readfirstlane_b32 s12, v3
	v_readfirstlane_b32 s1, v2
	s_cmp_gt_i32 s12, -1
	s_cselect_b32 s11, -1, 0
	s_cmp_lg_u32 s1, 0
	s_cselect_b32 s1, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s1, s11, s1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB1_18
; %bb.16:                               ; %.preheader
	s_mov_b32 s13, 0
	v_mov_b32_e32 v2, v1
	s_lshl_b64 s[14:15], s[12:13], 11
	v_mov_b32_e32 v1, v0
	s_add_u32 s1, s4, s14
	s_addc_u32 s5, s5, s15
	s_add_u32 s4, s1, 0x32e00
	s_addc_u32 s5, s5, 0
	s_add_u32 s11, s8, 0x800
	s_addc_u32 s12, s9, 0
	.p2align	6
.LBB1_17:                               ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v3, vcc_lo, s11, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s12, v2, vcc_lo
	global_load_d16_u8 v3, v[3:4], off
	v_add_co_u32 v4, vcc_lo, s4, v1
	v_add_co_u32 v1, s1, 0x80, v1
	v_add_co_ci_u32_e64 v5, null, s5, v2, vcc_lo
	v_add_co_ci_u32_e64 v2, null, 0, v2, s1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v6, 0xffffff80, v1
	v_cmp_lt_u32_e32 vcc_lo, 0x77f, v6
	s_or_b32 s13, vcc_lo, s13
	s_waitcnt vmcnt(0)
	global_store_b8 v[4:5], v3, off
	s_and_not1_b32 exec_lo, exec_lo, s13
	s_cbranch_execnz .LBB1_17
.LBB1_18:                               ; %Flow141
	s_or_b32 exec_lo, exec_lo, s3
	s_cbranch_execz .LBB1_20
	s_branch .LBB1_23
.LBB1_19:
.LBB1_20:
	s_cmp_lt_u32 s2, 8
	s_cselect_b32 s1, -1, 0
	s_xor_b32 s0, s0, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s0, s1, s0
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB1_23
; %bb.21:
	s_add_i32 s0, s10, -1
	s_mul_i32 s5, s2, 0x2100
	s_mul_hi_i32 s1, s0, 0x3e0f83e1
	v_mov_b32_e32 v1, 0
	s_lshr_b32 s3, s1, 31
	s_lshr_b32 s1, s1, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_i32 s1, s1, s3
	s_lshl_b32 s3, s2, 8
	s_mul_i32 s4, s1, 33
	s_mul_hi_u32 s2, s2, 0x2100
	s_sub_i32 s0, s0, s4
	s_mov_b32 s1, 0
	s_lshl_b32 s0, s0, 8
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s10, s0, 31
	s_add_u32 s3, s8, s3
	s_addc_u32 s4, s9, 0
	s_add_u32 s3, s3, 0x800
	s_addc_u32 s4, s4, 0
	s_add_u32 s0, s5, s0
	s_addc_u32 s5, s2, s10
	s_add_u32 s2, s6, s0
	s_addc_u32 s5, s7, s5
	.p2align	6
.LBB1_22:                               ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v2, vcc_lo, s3, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s4, v1, vcc_lo
	global_load_d16_u8 v2, v[2:3], off
	v_add_co_u32 v3, vcc_lo, s2, v0
	v_add_co_u32 v0, s0, 0x80, v0
	v_add_co_ci_u32_e64 v4, null, s5, v1, vcc_lo
	v_add_co_ci_u32_e64 v1, null, 0, v1, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v5, 0xffffff80, v0
	v_add_co_u32 v3, vcc_lo, 0x3a000, v3
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_lt_u32_e64 s0, 0x7f, v5
	s_or_b32 s1, s0, s1
	s_waitcnt vmcnt(0)
	global_store_b8 v[3:4], v2, off
	s_and_not1_b32 exec_lo, exec_lo, s1
	s_cbranch_execnz .LBB1_22
.LBB1_23:                               ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii
		.amdhsa_group_segment_fixed_size 44
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
		.amdhsa_next_free_vgpr 19
		.amdhsa_next_free_sgpr 37
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
		.amdhsa_inst_pref_size 32
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
	.size	_ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii, .Lfunc_end1-_ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii
                                        ; -- End function
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.num_vgpr, 19
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.num_agpr, 0
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.numbered_sgpr, 37
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.num_named_barrier, 0
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.private_seg_size, 0
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.uses_vcc, 1
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.uses_flat_scratch, 0
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.has_dyn_sized_stack, 0
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.has_recursion, 0
	.set _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 4004
; TotalNumSgprs: 39
; NumVgprs: 19
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 44 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 39
; NumVGPRsForWavesPerEU: 19
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
	.protected	_ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii ; -- Begin function _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii
	.globl	_ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii
	.p2align	8
	.type	_ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii,@function
_ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii: ; @_ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii
; %bb.0:
	v_cmp_gt_u32_e32 vcc_lo, 0x80, v0
	s_cmp_lt_i32 s2, 8
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s3, s3, vcc_lo
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB2_85
; %bb.1:
	s_clause 0x1
	s_load_b64 s[8:9], s[0:1], 0x10
	s_load_b128 s[4:7], s[0:1], 0x0
	s_mul_hi_i32 s0, s2, 0x4a00
	s_mulk_i32 s2, 0x4a00
	v_lshlrev_b32_e32 v3, 1, v0
	s_waitcnt lgkmcnt(0)
	s_cmp_eq_u32 s9, 0
	s_cselect_b32 s1, s6, s4
	s_cselect_b32 s3, s7, s5
	s_add_u32 s4, s1, s2
	s_addc_u32 s5, s3, s0
	s_ashr_i32 s0, s8, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s0, s0, 27
	s_add_i32 s0, s8, s0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s6, s0, 5
	s_mulk_i32 s6, 0x600
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s7, s6, 0xfffffa00
	s_ashr_i32 s0, s7, 31
	s_add_u32 s2, s4, s7
	s_addc_u32 s3, s5, s0
	v_add_co_u32 v1, s0, s2, v3
	s_clause 0xb
	global_load_u16 v4, v3, s[2:3]
	global_load_u16 v5, v3, s[2:3] offset:256
	global_load_u16 v6, v3, s[2:3] offset:512
	global_load_u16 v7, v3, s[2:3] offset:768
	global_load_u16 v8, v3, s[2:3] offset:1024
	global_load_u16 v9, v3, s[2:3] offset:1280
	global_load_u16 v10, v3, s[2:3] offset:1536
	global_load_u16 v12, v3, s[2:3] offset:1792
	global_load_u16 v13, v3, s[2:3] offset:2048
	global_load_u16 v14, v3, s[2:3] offset:2304
	global_load_u16 v15, v3, s[2:3] offset:2560
	global_load_u16 v17, v3, s[2:3] offset:2816
	v_add_co_ci_u32_e64 v2, null, s3, 0, s0
	s_clause 0x1
	global_load_u16 v19, v3, s[2:3] offset:3072
	global_load_u16 v20, v3, s[2:3] offset:3328
	v_add_co_u32 v1, vcc_lo, 0x1000, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_clause 0x11
	global_load_u16 v21, v3, s[2:3] offset:3584
	global_load_u16 v3, v3, s[2:3] offset:3840
	global_load_u16 v23, v[1:2], off
	global_load_u16 v24, v[1:2], off offset:256
	global_load_u16 v25, v[1:2], off offset:512
	global_load_u16 v29, v[1:2], off offset:768
	global_load_u16 v33, v[1:2], off offset:1024
	global_load_u16 v37, v[1:2], off offset:1280
	global_load_u16 v39, v[1:2], off offset:1536
	global_load_u16 v43, v[1:2], off offset:1792
	global_load_u16 v44, v[1:2], off offset:2048
	global_load_u16 v45, v[1:2], off offset:2304
	global_load_u16 v46, v[1:2], off offset:2560
	global_load_u16 v47, v[1:2], off offset:2816
	global_load_u16 v48, v[1:2], off offset:3072
	global_load_u16 v49, v[1:2], off offset:3328
	global_load_u16 v50, v[1:2], off offset:3584
	global_load_u16 v1, v[1:2], off offset:3840
	s_waitcnt vmcnt(31)
	v_lshlrev_b32_e32 v18, 16, v4
	s_waitcnt vmcnt(30)
	v_lshlrev_b32_e32 v11, 16, v5
	s_waitcnt vmcnt(29)
	v_lshlrev_b32_e32 v42, 16, v6
	s_waitcnt vmcnt(28)
	v_lshlrev_b32_e32 v41, 16, v7
	s_waitcnt vmcnt(27)
	v_lshlrev_b32_e32 v40, 16, v8
	s_waitcnt vmcnt(26)
	v_lshlrev_b32_e32 v9, 16, v9
	s_waitcnt vmcnt(25)
	v_lshlrev_b32_e32 v38, 16, v10
	s_waitcnt vmcnt(24)
	v_lshlrev_b32_e32 v36, 16, v12
	s_waitcnt vmcnt(23)
	v_lshlrev_b32_e32 v35, 16, v13
	s_waitcnt vmcnt(22)
	v_lshlrev_b32_e32 v16, 16, v14
	s_waitcnt vmcnt(21)
	v_lshlrev_b32_e32 v34, 16, v15
	s_waitcnt vmcnt(20)
	v_lshlrev_b32_e32 v32, 16, v17
	s_waitcnt vmcnt(17)
	v_lshlrev_b32_e32 v30, 16, v21
	v_lshlrev_b32_e32 v31, 16, v19
	s_waitcnt vmcnt(9)
	v_lshlrev_b32_e32 v19, 16, v39
	v_mov_b32_e32 v39, 0
	v_max3_f32 v2, v18, 0xff800000, v11
	v_min3_f32 v4, v18, 0x7f800000, v11
	v_lshlrev_b32_e32 v22, 16, v20
	v_lshlrev_b32_e32 v28, 16, v3
	v_lshlrev_b32_e32 v27, 16, v23
	v_max3_f32 v2, v2, v42, v41
	v_min3_f32 v4, v4, v42, v41
	v_lshlrev_b32_e32 v26, 16, v24
	v_lshlrev_b32_e32 v25, 16, v25
	v_lshlrev_b32_e32 v23, 16, v29
	v_max3_f32 v2, v2, v40, v9
	v_min3_f32 v4, v4, v40, v9
	v_lshlrev_b32_e32 v21, 16, v33
	v_lshlrev_b32_e32 v20, 16, v37
	s_waitcnt vmcnt(8)
	v_lshlrev_b32_e32 v17, 16, v43
	v_max3_f32 v2, v2, v38, v36
	v_min3_f32 v4, v4, v38, v36
	s_waitcnt vmcnt(7)
	v_lshlrev_b32_e32 v15, 16, v44
	s_waitcnt vmcnt(6)
	v_lshlrev_b32_e32 v14, 16, v45
	s_waitcnt vmcnt(5)
	v_lshlrev_b32_e32 v13, 16, v46
	v_max3_f32 v2, v2, v35, v16
	v_min3_f32 v4, v4, v35, v16
	s_waitcnt vmcnt(4)
	v_lshlrev_b32_e32 v12, 16, v47
	s_waitcnt vmcnt(3)
	v_lshlrev_b32_e32 v10, 16, v48
	s_waitcnt vmcnt(2)
	v_lshlrev_b32_e32 v6, 16, v49
	v_max3_f32 v2, v2, v34, v32
	v_min3_f32 v4, v4, v34, v32
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v5, 16, v50
	v_mov_b16_e32 v7.h, 0
	v_max3_f32 v2, v2, v31, v22
	v_min3_f32 v3, v4, v31, v22
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v4, 16, v1
	v_mov_b16_e32 v24.l, v7.h
	v_max3_f32 v2, v2, v30, v28
	v_min3_f32 v3, v3, v30, v28
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v2, v2, v27, v26
	v_min3_f32 v3, v3, v27, v26
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v2, v2, v25, v23
	v_min3_f32 v3, v3, v25, v23
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v2, v2, v21, v20
	v_min3_f32 v3, v3, v21, v20
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v2, v2, v19, v17
	v_min3_f32 v3, v3, v19, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v2, v2, v15, v14
	v_min3_f32 v3, v3, v15, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v2, v2, v13, v12
	v_min3_f32 v3, v3, v13, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v2, v10, v6
	v_min3_f32 v2, v3, v10, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v5, v4
	v_min3_f32 v8, v2, v5, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[1:2], v1
	v_cvt_f64_f32_e32 v[43:44], v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f64 v[1:2], v[1:2], -v[43:44]
	v_div_scale_f64 v[43:44], null, 0x40080000, 0x40080000, v[1:2]
	v_div_scale_f64 v[49:50], vcc_lo, v[1:2], 0x40080000, v[1:2]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f64_e32 v[45:46], v[43:44]
	v_fma_f64 v[47:48], -v[43:44], v[45:46], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[45:46], v[45:46], v[47:48], v[45:46]
	v_fma_f64 v[47:48], -v[43:44], v[45:46], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[45:46], v[45:46], v[47:48], v[45:46]
	v_mul_f64 v[47:48], v[49:50], v[45:46]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[43:44], -v[43:44], v[47:48], v[49:50]
	v_div_fmas_f64 v[43:44], v[43:44], v[45:46], v[47:48]
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fixup_f64 v[1:2], v[43:44], 0x40080000, v[1:2]
	v_mov_b32_e32 v43, 0
	v_cvt_f32_f64_e32 v3, v[1:2]
	v_cmp_neq_f64_e64 s0, 0, v[1:2]
	s_and_saveexec_b32 s8, s0
	s_cbranch_execz .LBB2_3
; %bb.2:
	v_sub_f32_e32 v18, v18, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v24, null, v3, v3, v18
	v_rcp_f32_e32 v33, v24
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v43, -v24, v33, 1.0
	v_fmac_f32_e32 v33, v43, v33
	v_div_scale_f32 v45, vcc_lo, v18, v3, v18
	v_sub_f32_e32 v11, v11, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v29, null, v3, v3, v11
	v_rcp_f32_e32 v37, v29
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v44, -v29, v37, 1.0
	v_fmac_f32_e32 v37, v44, v37
	v_mul_f32_e32 v44, v45, v33
	v_div_scale_f32 v43, s1, v11, v3, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v47, -v24, v44, v45
	v_mul_f32_e32 v46, v43, v37
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v44, v47, v33
	v_fma_f32 v48, -v29, v46, v43
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v24, -v24, v44, v45
	v_fmac_f32_e32 v46, v48, v37
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v24, v24, v33, v44
	v_fma_f32 v29, -v29, v46, v43
	s_mov_b32 vcc_lo, s1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v18, v24, v3, v18
	v_div_fmas_f32 v29, v29, v37, v46
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v18, v18
	v_div_fixup_f32 v11, v29, v3, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v18, v18, 0, 0x40400000
	v_rndne_f32_e32 v11, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_i32_f32_e32 v43, v18
	v_med3_f32 v11, v11, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_i32_f32_e32 v24, v11
.LBB2_3:                                ; %.critedge.i
	s_or_b32 exec_lo, exec_lo, s8
	s_delay_alu instid0(VALU_DEP_1)
	v_lshlrev_b16 v7.l, 8, v24.l
	v_mov_b32_e32 v37, v39
	v_mov_b32_e32 v33, v39
	v_mov_b32_e32 v29, v39
	v_mov_b32_e32 v24, v39
	v_or_b16 v7.l, v43.l, v7.l
	v_mov_b32_e32 v18, v39
	v_mov_b32_e32 v11, v39
                                        ; implicit-def: $vgpr43_lo16
	s_and_saveexec_b32 s1, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_5
; %bb.4:
	v_sub_f32_e32 v11, v42, v8
	v_sub_f32_e32 v29, v41, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v18, null, v3, v3, v11
	v_div_scale_f32 v33, null, v3, v3, v29
	v_div_scale_f32 v42, vcc_lo, v11, v3, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v24, v18
	v_rcp_f32_e32 v41, v33
	v_div_scale_f32 v45, s1, v29, v3, v29
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v37, -v18, v24, 1.0
	v_fma_f32 v43, -v33, v41, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v24, v37, v24 :: v_dual_fmac_f32 v41, v43, v41
	v_mul_f32_e32 v37, v42, v24
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v43, v45, v41
	v_fma_f32 v44, -v18, v37, v42
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v37, v44, v24
	v_fma_f32 v18, -v18, v37, v42
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v42, -v33, v43, v45
	v_div_fmas_f32 v18, v18, v24, v37
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_dual_fmac_f32 v43, v42, v41 :: v_dual_mov_b32 v24, v39
	s_mov_b32 vcc_lo, s1
	v_mov_b32_e32 v37, v39
	v_div_fixup_f32 v11, v18, v3, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_fma_f32 v18, -v33, v43, v45
	v_mov_b32_e32 v33, v39
	v_rndne_f32_e32 v11, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fmas_f32 v18, v18, v41, v43
	v_mov_b16_e32 v41.l, 0
	v_med3_f32 v11, v11, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v18, v18, v3, v29
	v_mov_b32_e32 v29, v39
	v_cvt_i32_f32_e32 v11, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v18, v18
	v_mov_b16_e32 v41.h, v11.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_med3_f32 v42, v18, 0, 0x40400000
	v_mov_b32_e32 v18, v39
	v_mov_b32_e32 v11, v39
	v_or_b32_e32 v7, v7, v41
	s_delay_alu instid0(VALU_DEP_4)
	v_cvt_i32_f32_e32 v43, v42
.LBB2_5:                                ; %Flow227
	s_and_not1_saveexec_b32 s1, s8
; %bb.6:                                ; %.critedge39.i
	v_mov_b16_e32 v43.l, 0
; %bb.7:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v7, v7, v43, 0x60504
                                        ; implicit-def: $vgpr41_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_9
; %bb.8:
	v_sub_f32_e32 v9, v9, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v43, null, v3, v3, v9
	v_rcp_f32_e32 v45, v43
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v47, -v43, v45, 1.0
	v_dual_sub_f32 v40, v40, v8 :: v_dual_fmac_f32 v45, v47, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v41, null, v3, v3, v40
	v_div_scale_f32 v46, vcc_lo, v40, v3, v40
	v_rcp_f32_e32 v42, v41
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v44, -v41, v42, 1.0
	v_fmac_f32_e32 v42, v44, v42
	v_div_scale_f32 v49, s1, v9, v3, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v44, v46, v42 :: v_dual_mul_f32 v47, v49, v45
	v_fma_f32 v48, -v41, v44, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v44, v48, v42
	v_fma_f32 v41, -v41, v44, v46
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v46, -v43, v47, v49
	v_fmac_f32_e32 v47, v46, v45
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v41, v41, v42, v44
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v40, v41, v3, v40
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v41, -v43, v47, v49
	v_rndne_f32_e32 v40, v40
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v41, v41, v45, v47
	v_med3_f32 v40, v40, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v41, v41, v3, v9
	v_and_b16 v9.l, 0xff00, v39.l
	v_mov_b16_e32 v9.h, 0
	v_cvt_i32_f32_e32 v40, v40
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v41, v41
	v_or_b16 v9.l, v40.l, v9.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v40, v41, 0, 0x40400000
	v_and_or_b32 v39, 0xffff0000, v39, v9
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v41, v40
.LBB2_9:                                ; %Flow226
	s_and_not1_saveexec_b32 s1, s8
; %bb.10:                               ; %.critedge43.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v39, 0xffffff00, v39
	v_mov_b16_e32 v41.l, 0
; %bb.11:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v39, v39, v41, 0x7060004
                                        ; implicit-def: $vgpr40_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
                                        ; implicit-def: $vgpr9
	s_cbranch_execz .LBB2_13
; %bb.12:
	v_sub_f32_e32 v9, v38, v8
	v_sub_f32_e32 v36, v36, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v38, null, v3, v3, v9
	v_div_scale_f32 v41, null, v3, v3, v36
	v_div_scale_f32 v44, vcc_lo, v9, v3, v9
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v40, v38
	v_rcp_f32_e32 v43, v41
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v42, -v38, v40, 1.0
	v_fma_f32 v45, -v41, v43, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v43, v45, v43
	v_div_scale_f32 v47, s1, v36, v3, v36
	v_dual_fmac_f32 v40, v42, v40 :: v_dual_mul_f32 v45, v47, v43
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v42, v44, v40
	v_fma_f32 v46, -v38, v42, v44
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v42, v46, v40
	v_fma_f32 v38, -v38, v42, v44
	v_fma_f32 v44, -v41, v45, v47
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v45, v44, v43
	v_div_fmas_f32 v38, v38, v40, v42
	s_mov_b32 vcc_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v9, v38, v3, v9
	v_fma_f32 v38, -v41, v45, v47
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v9, v9
	v_div_fmas_f32 v38, v38, v43, v45
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v40, v9, 0, 0x40400000
	v_div_fixup_f32 v36, v38, v3, v36
	v_and_b16 v9.l, 0xff00, v39.h
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_i32_f32_e32 v38, v40
	v_rndne_f32_e32 v36, v36
	v_mov_b16_e32 v40.l, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_or_b16 v40.h, v38.l, v9.l
	v_med3_f32 v36, v36, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v9, 0xffff, v39, v40
	v_cvt_i32_f32_e32 v40, v36
                                        ; implicit-def: $vgpr39
.LBB2_13:                               ; %Flow225
	s_and_not1_saveexec_b32 s1, s8
; %bb.14:                               ; %.critedge47.i
	v_and_b32_e32 v9, 0xff00ffff, v39
	v_mov_b16_e32 v40.l, 0
; %bb.15:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v9, v9, v40, 0x60504
                                        ; implicit-def: $vgpr36_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_17
; %bb.16:
	v_sub_f32_e32 v35, v35, v8
	v_sub_f32_e32 v16, v16, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v36, null, v3, v3, v35
	v_div_scale_f32 v39, null, v3, v3, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rcp_f32_e32 v38, v36
	v_rcp_f32_e32 v41, v39
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v40, -v36, v38, 1.0
	v_fma_f32 v43, -v39, v41, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v38, v40, v38
	v_div_scale_f32 v42, vcc_lo, v35, v3, v35
	v_fmac_f32_e32 v41, v43, v41
	v_div_scale_f32 v45, s1, v16, v3, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v40, v42, v38 :: v_dual_mul_f32 v43, v45, v41
	v_fma_f32 v44, -v36, v40, v42
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v40, v44, v38
	v_fma_f32 v36, -v36, v40, v42
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v42, -v39, v43, v45
	v_fmac_f32_e32 v43, v42, v41
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v36, v36, v38, v40
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v35, v36, v3, v35
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v36, -v39, v43, v45
	v_rndne_f32_e32 v35, v35
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v36, v36, v41, v43
	v_med3_f32 v35, v35, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v36, v36, v3, v16
	v_and_b16 v16.l, 0xff00, v37.l
	v_mov_b16_e32 v16.h, 0
	v_cvt_i32_f32_e32 v35, v35
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v36, v36
	v_or_b16 v16.l, v35.l, v16.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v35, v36, 0, 0x40400000
	v_and_or_b32 v37, 0xffff0000, v37, v16
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v36, v35
.LBB2_17:                               ; %Flow224
	s_and_not1_saveexec_b32 s1, s8
; %bb.18:                               ; %.critedge51.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v37, 0xffffff00, v37
	v_mov_b16_e32 v36.l, 0
; %bb.19:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v35, v37, v36, 0x7060004
                                        ; implicit-def: $vgpr36_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
                                        ; implicit-def: $vgpr16
	s_cbranch_execz .LBB2_21
; %bb.20:
	v_sub_f32_e32 v32, v32, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v37, null, v3, v3, v32
	v_div_scale_f32 v43, s1, v32, v3, v32
	v_rcp_f32_e32 v39, v37
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v41, -v37, v39, 1.0
	v_dual_sub_f32 v16, v34, v8 :: v_dual_fmac_f32 v39, v41, v39
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_scale_f32 v34, null, v3, v3, v16
	v_div_scale_f32 v40, vcc_lo, v16, v3, v16
	v_mul_f32_e32 v41, v43, v39
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v36, v34
	v_fma_f32 v38, -v34, v36, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v36, v38, v36
	v_mul_f32_e32 v38, v40, v36
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v42, -v34, v38, v40
	v_fmac_f32_e32 v38, v42, v36
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f32 v34, -v34, v38, v40
	v_fma_f32 v40, -v37, v41, v43
	v_fmac_f32_e32 v41, v40, v39
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v34, v34, v36, v38
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v16, v34, v3, v16
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v34, -v37, v41, v43
	v_rndne_f32_e32 v16, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v34, v34, v39, v41
	v_med3_f32 v36, v16, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v32, v34, v3, v32
	v_and_b16 v16.l, 0xff00, v35.h
	v_cvt_i32_f32_e32 v34, v36
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_rndne_f32_e32 v32, v32
	v_mov_b16_e32 v36.l, 0
	v_or_b16 v36.h, v34.l, v16.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v32, v32, 0, 0x40400000
	v_and_or_b32 v16, 0xffff, v35, v36
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v36, v32
                                        ; implicit-def: $vgpr35
.LBB2_21:                               ; %Flow223
	s_and_not1_saveexec_b32 s1, s8
; %bb.22:                               ; %.critedge55.i
	v_and_b32_e32 v16, 0xff00ffff, v35
	v_mov_b16_e32 v36.l, 0
; %bb.23:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v16, v16, v36, 0x60504
                                        ; implicit-def: $vgpr32_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_25
; %bb.24:
	v_sub_f32_e32 v31, v31, v8
	v_sub_f32_e32 v22, v22, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v32, null, v3, v3, v31
	v_div_scale_f32 v35, null, v3, v3, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rcp_f32_e32 v34, v32
	v_rcp_f32_e32 v37, v35
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v36, -v32, v34, 1.0
	v_fma_f32 v39, -v35, v37, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v34, v36, v34
	v_div_scale_f32 v38, vcc_lo, v31, v3, v31
	v_fmac_f32_e32 v37, v39, v37
	v_div_scale_f32 v41, s1, v22, v3, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v36, v38, v34 :: v_dual_mul_f32 v39, v41, v37
	v_fma_f32 v40, -v32, v36, v38
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v36, v40, v34
	v_fma_f32 v32, -v32, v36, v38
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v38, -v35, v39, v41
	v_fmac_f32_e32 v39, v38, v37
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v32, v32, v34, v36
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v31, v32, v3, v31
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v32, -v35, v39, v41
	v_rndne_f32_e32 v31, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v32, v32, v37, v39
	v_med3_f32 v31, v31, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v32, v32, v3, v22
	v_and_b16 v22.l, 0xff00, v33.l
	v_mov_b16_e32 v22.h, 0
	v_cvt_i32_f32_e32 v31, v31
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v32, v32
	v_or_b16 v22.l, v31.l, v22.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v31, v32, 0, 0x40400000
	v_and_or_b32 v33, 0xffff0000, v33, v22
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v32, v31
.LBB2_25:                               ; %Flow222
	s_and_not1_saveexec_b32 s1, s8
; %bb.26:                               ; %.critedge59.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v33, 0xffffff00, v33
	v_mov_b16_e32 v32.l, 0
; %bb.27:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v31, v33, v32, 0x7060004
                                        ; implicit-def: $vgpr32_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
                                        ; implicit-def: $vgpr22
	s_cbranch_execz .LBB2_29
; %bb.28:
	v_sub_f32_e32 v28, v28, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v33, null, v3, v3, v28
	v_div_scale_f32 v39, s1, v28, v3, v28
	v_rcp_f32_e32 v35, v33
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v37, -v33, v35, 1.0
	v_dual_sub_f32 v22, v30, v8 :: v_dual_fmac_f32 v35, v37, v35
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_scale_f32 v30, null, v3, v3, v22
	v_div_scale_f32 v36, vcc_lo, v22, v3, v22
	v_mul_f32_e32 v37, v39, v35
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v32, v30
	v_fma_f32 v34, -v30, v32, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v32, v34, v32
	v_mul_f32_e32 v34, v36, v32
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v38, -v30, v34, v36
	v_fmac_f32_e32 v34, v38, v32
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f32 v30, -v30, v34, v36
	v_fma_f32 v36, -v33, v37, v39
	v_fmac_f32_e32 v37, v36, v35
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v30, v30, v32, v34
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v22, v30, v3, v22
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v30, -v33, v37, v39
	v_rndne_f32_e32 v22, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v30, v30, v35, v37
	v_med3_f32 v32, v22, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v28, v30, v3, v28
	v_and_b16 v22.l, 0xff00, v31.h
	v_cvt_i32_f32_e32 v30, v32
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_rndne_f32_e32 v28, v28
	v_mov_b16_e32 v32.l, 0
	v_or_b16 v32.h, v30.l, v22.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v28, v28, 0, 0x40400000
	v_and_or_b32 v22, 0xffff, v31, v32
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v32, v28
                                        ; implicit-def: $vgpr31
.LBB2_29:                               ; %Flow221
	s_and_not1_saveexec_b32 s1, s8
; %bb.30:                               ; %.critedge63.i
	v_and_b32_e32 v22, 0xff00ffff, v31
	v_mov_b16_e32 v32.l, 0
; %bb.31:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v22, v22, v32, 0x60504
                                        ; implicit-def: $vgpr28_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_33
; %bb.32:
	v_sub_f32_e32 v27, v27, v8
	v_sub_f32_e32 v26, v26, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v28, null, v3, v3, v27
	v_div_scale_f32 v31, null, v3, v3, v26
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rcp_f32_e32 v30, v28
	v_rcp_f32_e32 v33, v31
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v32, -v28, v30, 1.0
	v_fma_f32 v35, -v31, v33, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v30, v32, v30
	v_div_scale_f32 v34, vcc_lo, v27, v3, v27
	v_fmac_f32_e32 v33, v35, v33
	v_div_scale_f32 v37, s1, v26, v3, v26
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v32, v34, v30 :: v_dual_mul_f32 v35, v37, v33
	v_fma_f32 v36, -v28, v32, v34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v32, v36, v30
	v_fma_f32 v28, -v28, v32, v34
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v34, -v31, v35, v37
	v_fmac_f32_e32 v35, v34, v33
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v28, v28, v30, v32
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v27, v28, v3, v27
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v28, -v31, v35, v37
	v_rndne_f32_e32 v27, v27
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v28, v28, v33, v35
	v_med3_f32 v27, v27, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v28, v28, v3, v26
	v_and_b16 v26.l, 0xff00, v29.l
	v_mov_b16_e32 v26.h, 0
	v_cvt_i32_f32_e32 v27, v27
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v28, v28
	v_or_b16 v26.l, v27.l, v26.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v27, v28, 0, 0x40400000
	v_and_or_b32 v29, 0xffff0000, v29, v26
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v28, v27
.LBB2_33:                               ; %Flow220
	s_and_not1_saveexec_b32 s1, s8
; %bb.34:                               ; %.critedge67.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v29, 0xffffff00, v29
	v_mov_b16_e32 v28.l, 0
; %bb.35:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v27, v29, v28, 0x7060004
                                        ; implicit-def: $vgpr28_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
                                        ; implicit-def: $vgpr26
	s_cbranch_execz .LBB2_37
; %bb.36:
	v_sub_f32_e32 v25, v25, v8
	v_sub_f32_e32 v23, v23, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v26, null, v3, v3, v25
	v_div_scale_f32 v29, null, v3, v3, v23
	v_div_scale_f32 v32, vcc_lo, v25, v3, v25
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v28, v26
	v_rcp_f32_e32 v31, v29
	v_div_scale_f32 v35, s1, v23, v3, v23
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v30, -v26, v28, 1.0
	v_fma_f32 v33, -v29, v31, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v28, v30, v28 :: v_dual_fmac_f32 v31, v33, v31
	v_dual_mul_f32 v30, v32, v28 :: v_dual_mul_f32 v33, v35, v31
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v34, -v26, v30, v32
	v_fmac_f32_e32 v30, v34, v28
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v26, -v26, v30, v32
	v_fma_f32 v32, -v29, v33, v35
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v33, v32, v31
	v_div_fmas_f32 v26, v26, v28, v30
	s_mov_b32 vcc_lo, s1
	v_mov_b16_e32 v28.l, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v25, v26, v3, v25
	v_fma_f32 v26, -v29, v33, v35
	v_rndne_f32_e32 v25, v25
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v26, v26, v31, v33
	v_med3_f32 v25, v25, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v26, v26, v3, v23
	v_and_b16 v23.l, 0xff00, v27.h
	v_cvt_i32_f32_e32 v25, v25
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v26, v26
	v_or_b16 v28.h, v25.l, v23.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v23, v26, 0, 0x40400000
	v_and_or_b32 v26, 0xffff, v27, v28
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v28, v23
                                        ; implicit-def: $vgpr27
.LBB2_37:                               ; %Flow219
	s_and_not1_saveexec_b32 s1, s8
; %bb.38:                               ; %.critedge71.i
	v_and_b32_e32 v26, 0xff00ffff, v27
	v_mov_b16_e32 v28.l, 0
; %bb.39:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v26, v26, v28, 0x60504
                                        ; implicit-def: $vgpr23_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_41
; %bb.40:
	v_sub_f32_e32 v21, v21, v8
	v_sub_f32_e32 v20, v20, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v23, null, v3, v3, v21
	v_div_scale_f32 v27, null, v3, v3, v20
	v_div_scale_f32 v30, vcc_lo, v21, v3, v21
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v25, v23
	v_rcp_f32_e32 v29, v27
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v28, -v23, v25, 1.0
	v_fma_f32 v31, -v27, v29, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v25, v28, v25
	v_fmac_f32_e32 v29, v31, v29
	v_div_scale_f32 v33, s1, v20, v3, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v28, v30, v25
	v_mul_f32_e32 v31, v33, v29
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v32, -v23, v28, v30
	v_fmac_f32_e32 v28, v32, v25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v23, -v23, v28, v30
	v_fma_f32 v30, -v27, v31, v33
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v23, v23, v25, v28
	v_fmac_f32_e32 v31, v30, v29
	s_mov_b32 vcc_lo, s1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v21, v23, v3, v21
	v_fma_f32 v23, -v27, v31, v33
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v21, v21
	v_div_fmas_f32 v23, v23, v29, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v21, v21, 0, 0x40400000
	v_div_fixup_f32 v23, v23, v3, v20
	v_and_b16 v20.l, 0xff00, v24.l
	v_mov_b16_e32 v20.h, 0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_i32_f32_e32 v21, v21
	v_rndne_f32_e32 v23, v23
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v20.l, v21.l, v20.l
	v_med3_f32 v21, v23, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v24, 0xffff0000, v24, v20
	v_cvt_i32_f32_e32 v23, v21
.LBB2_41:                               ; %Flow218
	s_and_not1_saveexec_b32 s1, s8
; %bb.42:                               ; %.critedge75.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v24, 0xffffff00, v24
	v_mov_b16_e32 v23.l, 0
; %bb.43:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v21, v24, v23, 0x7060004
                                        ; implicit-def: $vgpr23_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
                                        ; implicit-def: $vgpr20
	s_cbranch_execz .LBB2_45
; %bb.44:
	v_sub_f32_e32 v19, v19, v8
	v_sub_f32_e32 v17, v17, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v20, null, v3, v3, v19
	v_div_scale_f32 v24, null, v3, v3, v17
	v_div_scale_f32 v28, vcc_lo, v19, v3, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v23, v20
	v_rcp_f32_e32 v27, v24
	v_div_scale_f32 v31, s1, v17, v3, v17
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v25, -v20, v23, 1.0
	v_fma_f32 v29, -v24, v27, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v23, v25, v23
	v_fmac_f32_e32 v27, v29, v27
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v25, v28, v23
	v_mul_f32_e32 v29, v31, v27
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v30, -v20, v25, v28
	v_fmac_f32_e32 v25, v30, v23
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v20, -v20, v25, v28
	v_fma_f32 v28, -v24, v29, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v20, v20, v23, v25
	v_fmac_f32_e32 v29, v28, v27
	s_mov_b32 vcc_lo, s1
	v_mov_b16_e32 v23.l, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v19, v20, v3, v19
	v_fma_f32 v20, -v24, v29, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v19, v19
	v_div_fmas_f32 v20, v20, v27, v29
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v19, v19, 0, 0x40400000
	v_div_fixup_f32 v20, v20, v3, v17
	v_and_b16 v17.l, 0xff00, v21.h
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_i32_f32_e32 v19, v19
	v_rndne_f32_e32 v20, v20
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v23.h, v19.l, v17.l
	v_med3_f32 v17, v20, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v20, 0xffff, v21, v23
	v_cvt_i32_f32_e32 v23, v17
                                        ; implicit-def: $vgpr21
.LBB2_45:                               ; %Flow217
	s_and_not1_saveexec_b32 s1, s8
; %bb.46:                               ; %.critedge79.i
	v_and_b32_e32 v20, 0xff00ffff, v21
	v_mov_b16_e32 v23.l, 0
; %bb.47:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v20, v20, v23, 0x60504
                                        ; implicit-def: $vgpr17_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_49
; %bb.48:
	v_sub_f32_e32 v15, v15, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v17, null, v3, v3, v15
	v_div_scale_f32 v25, vcc_lo, v15, v3, v15
	v_rcp_f32_e32 v19, v17
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v23, -v17, v19, 1.0
	v_dual_sub_f32 v14, v14, v8 :: v_dual_fmac_f32 v19, v23, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v21, null, v3, v3, v14
	v_div_scale_f32 v29, s1, v14, v3, v14
	v_rcp_f32_e32 v24, v21
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v27, -v21, v24, 1.0
	v_dual_mul_f32 v23, v25, v19 :: v_dual_fmac_f32 v24, v27, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v28, -v17, v23, v25
	v_mul_f32_e32 v27, v29, v24
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v23, v28, v19
	v_fma_f32 v17, -v17, v23, v25
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v25, -v21, v27, v29
	v_div_fmas_f32 v17, v17, v19, v23
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v27, v25, v24
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v15, v17, v3, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v17, -v21, v27, v29
	v_rndne_f32_e32 v15, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v17, v17, v24, v27
	v_med3_f32 v15, v15, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v17, v17, v3, v14
	v_and_b16 v14.l, 0xff00, v18.l
	v_mov_b16_e32 v14.h, 0
	v_cvt_i32_f32_e32 v15, v15
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v17, v17
	v_or_b16 v14.l, v15.l, v14.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v15, v17, 0, 0x40400000
	v_and_or_b32 v18, 0xffff0000, v18, v14
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v17, v15
.LBB2_49:                               ; %Flow216
	s_and_not1_saveexec_b32 s1, s8
; %bb.50:                               ; %.critedge83.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v18, 0xffffff00, v18
	v_mov_b16_e32 v17.l, 0
; %bb.51:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v15, v18, v17, 0x7060004
                                        ; implicit-def: $vgpr17_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
                                        ; implicit-def: $vgpr14
	s_cbranch_execz .LBB2_53
; %bb.52:
	v_sub_f32_e32 v12, v12, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v18, null, v3, v3, v12
	v_div_scale_f32 v27, s1, v12, v3, v12
	v_rcp_f32_e32 v21, v18
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v24, -v18, v21, 1.0
	v_fmac_f32_e32 v21, v24, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_sub_f32 v13, v13, v8 :: v_dual_mul_f32 v24, v27, v21
	v_div_scale_f32 v14, null, v3, v3, v13
	v_div_scale_f32 v23, vcc_lo, v13, v3, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v17, v14
	v_fma_f32 v19, -v14, v17, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v19, v17
	v_mul_f32_e32 v19, v23, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v25, -v14, v19, v23
	v_fmac_f32_e32 v19, v25, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fma_f32 v14, -v14, v19, v23
	v_fma_f32 v23, -v18, v24, v27
	v_div_fmas_f32 v14, v14, v17, v19
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v24, v23, v21
	s_mov_b32 vcc_lo, s1
	v_mov_b16_e32 v17.l, 0
	v_div_fixup_f32 v13, v14, v3, v13
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v14, -v18, v24, v27
	v_rndne_f32_e32 v13, v13
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v14, v14, v21, v24
	v_med3_f32 v13, v13, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v14, v14, v3, v12
	v_and_b16 v12.l, 0xff00, v15.h
	v_cvt_i32_f32_e32 v13, v13
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v14, v14
	v_or_b16 v17.h, v13.l, v12.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v12, v14, 0, 0x40400000
	v_and_or_b32 v14, 0xffff, v15, v17
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v17, v12
                                        ; implicit-def: $vgpr15
.LBB2_53:                               ; %Flow215
	s_and_not1_saveexec_b32 s1, s8
; %bb.54:                               ; %.critedge87.i
	v_and_b32_e32 v14, 0xff00ffff, v15
	v_mov_b16_e32 v17.l, 0
; %bb.55:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v14, v14, v17, 0x60504
                                        ; implicit-def: $vgpr12_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s8, exec_lo, s1
	s_cbranch_execz .LBB2_57
; %bb.56:
	v_sub_f32_e32 v10, v10, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v12, null, v3, v3, v10
	v_rcp_f32_e32 v13, v12
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v17, -v12, v13, 1.0
	v_fmac_f32_e32 v13, v17, v13
	v_div_scale_f32 v19, vcc_lo, v10, v3, v10
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_sub_f32 v6, v6, v8 :: v_dual_mul_f32 v17, v19, v13
	v_div_scale_f32 v15, null, v3, v3, v6
	v_div_scale_f32 v24, s1, v6, v3, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fma_f32 v23, -v12, v17, v19
	v_rcp_f32_e32 v18, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, v23, v13
	v_fma_f32 v12, -v12, v17, v19
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v21, -v15, v18, 1.0
	v_div_fmas_f32 v12, v12, v13, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v18, v21, v18
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v10, v12, v3, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v21, v24, v18
	v_rndne_f32_e32 v10, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v19, -v15, v21, v24
	v_med3_f32 v10, v10, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v21, v19, v18
	v_cvt_i32_f32_e32 v10, v10
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v12, -v15, v21, v24
	v_div_fmas_f32 v12, v12, v18, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v12, v12, v3, v6
	v_and_b16 v6.l, 0xff00, v11.l
	v_mov_b16_e32 v6.h, 0
	v_rndne_f32_e32 v12, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v6.l, v10.l, v6.l
	v_med3_f32 v10, v12, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v11, 0xffff0000, v11, v6
	v_cvt_i32_f32_e32 v12, v10
.LBB2_57:                               ; %Flow214
	s_and_not1_saveexec_b32 s1, s8
; %bb.58:                               ; %.critedge91.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v11, 0xffffff00, v11
	v_mov_b16_e32 v12.l, 0
; %bb.59:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v6, v11, v12, 0x7060004
                                        ; implicit-def: $vgpr11_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s1, exec_lo, s1
                                        ; implicit-def: $vgpr10
	s_cbranch_execz .LBB2_61
; %bb.60:
	v_sub_f32_e32 v5, v5, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v10, null, v3, v3, v5
	v_div_scale_f32 v17, vcc_lo, v5, v3, v5
	v_rcp_f32_e32 v11, v10
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v13, -v10, v11, 1.0
	v_dual_sub_f32 v4, v4, v8 :: v_dual_fmac_f32 v11, v13, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_scale_f32 v12, null, v3, v3, v4
	v_div_scale_f32 v21, s0, v4, v3, v4
	v_mul_f32_e32 v13, v17, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rcp_f32_e32 v15, v12
	v_fma_f32 v19, -v10, v13, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fmac_f32_e32 v13, v19, v11
	v_fma_f32 v18, -v12, v15, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v10, -v10, v13, v17
	v_fmac_f32_e32 v15, v18, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v10, v10, v11, v13
	v_mul_f32_e32 v18, v21, v15
	s_mov_b32 vcc_lo, s0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v5, v10, v3, v5
	v_fma_f32 v17, -v12, v18, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v5, v5
	v_fmac_f32_e32 v18, v17, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v5, v5, 0, 0x40400000
	v_fma_f32 v10, -v12, v18, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_i32_f32_e32 v5, v5
	v_div_fmas_f32 v10, v10, v15, v18
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v4, v10, v3, v4
	v_and_b16 v3.l, 0xff00, v6.h
	v_mov_b16_e32 v10.l, 0
	v_rndne_f32_e32 v4, v4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v10.h, v5.l, v3.l
	v_med3_f32 v3, v4, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v10, 0xffff, v6, v10
                                        ; implicit-def: $vgpr6
	v_cvt_i32_f32_e32 v11, v3
.LBB2_61:                               ; %Flow213
	s_and_not1_saveexec_b32 s0, s1
; %bb.62:                               ; %.critedge95.i
	v_and_b32_e32 v10, 0xff00ffff, v6
	v_mov_b16_e32 v11.l, 0
; %bb.63:
	s_or_b32 exec_lo, exec_lo, s0
	v_bfe_u32 v12, v2, 20, 11
                                        ; implicit-def: $vgpr3
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u32_e32 0x7ff, v12
	s_xor_b32 s8, exec_lo, s0
	s_cbranch_execz .LBB2_73
; %bb.64:
	v_mov_b32_e32 v3, 0
	s_mov_b32 s9, exec_lo
	v_cmpx_lt_u32_e32 0x3e5, v12
	s_cbranch_execz .LBB2_72
; %bb.65:
	v_mov_b32_e32 v3, 0x7c00
	s_mov_b32 s10, exec_lo
	v_cmpx_gt_u32_e32 0x40f, v12
	s_cbranch_execz .LBB2_71
; %bb.66:
	v_sub_nc_u32_e32 v3, 0x41b, v12
	v_cmp_gt_u32_e32 vcc_lo, 0x3f1, v12
	s_mov_b32 s0, 0xfffff
	s_mov_b32 s12, exec_lo
	v_and_or_b32 v2, v2, s0, 0x100000
	v_cndmask_b32_e32 v13, 42, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], v13, -1
	v_add_nc_u32_e32 v3, -1, v13
	v_lshlrev_b64 v[3:4], v3, 1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_bfi_b32 v6, v6, 0, v2
	v_bfi_b32 v5, v5, 0, v1
	v_lshrrev_b64 v[1:2], v13, v[1:2]
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_gt_u64_e64 s11, v[5:6], v[3:4]
	v_cmpx_le_u64_e64 v[5:6], v[3:4]
; %bb.67:
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_and_b32_e32 v13, 1, v1
	v_cmp_eq_u64_e64 s0, v[5:6], v[3:4]
	v_cmp_eq_u32_e64 s1, 1, v13
	s_and_b32 s0, s0, s1
	s_and_not1_b32 s1, s11, exec_lo
	s_and_b32 s0, s0, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s11, s1, s0
; %bb.68:                               ; %Flow205
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s1, s11
; %bb.69:
	v_add_co_u32 v1, s0, v1, 1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, s0
; %bb.70:
	s_or_b32 exec_lo, exec_lo, s1
	v_lshl_add_u32 v2, v12, 10, 0xfff03c00
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v2, v2, 0, vcc_lo
	v_add_nc_u32_e32 v3, v2, v1
.LBB2_71:                               ; %Flow207
	s_or_b32 exec_lo, exec_lo, s10
.LBB2_72:                               ; %Flow209
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s9
                                        ; implicit-def: $vgpr1_vgpr2
.LBB2_73:                               ; %Flow211
	s_and_not1_saveexec_b32 s0, s8
; %bb.74:
	v_and_b32_e32 v2, 0xfffff, v2
	v_mov_b32_e32 v3, 0x7c00
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u64_e32 vcc_lo, 0, v[1:2]
	v_cndmask_b32_e32 v3, 0x7e00, v3, vcc_lo
; %bb.75:                               ; %_ZN6stable7quant32EPKhiPhS2_.exit
	s_or_b32 exec_lo, exec_lo, s0
	v_lshrrev_b32_e32 v1, 24, v9
	v_cvt_f16_f32_e32 v2.l, v8
	v_lshrrev_b32_e32 v8, 8, v16
	v_lshrrev_b32_e32 v12, 24, v16
	v_lshrrev_b32_e32 v13, 8, v22
	ds_store_b8 v0, v1 offset:896
	ds_store_b8 v0, v16 offset:1024
	ds_store_b8 v0, v8 offset:1152
	ds_store_b8_d16_hi v0, v16 offset:1280
	ds_store_b8 v0, v12 offset:1408
	ds_store_b8 v0, v22 offset:1536
	ds_store_b8 v0, v13 offset:1664
	ds_store_b8_d16_hi v0, v22 offset:1792
	v_lshrrev_b32_e32 v1, 24, v22
	v_lshrrev_b32_e32 v15, 8, v3
	v_lshrrev_b32_e32 v8, 8, v26
	v_lshrrev_b32_e32 v12, 24, v26
	v_lshrrev_b32_e32 v13, 8, v20
	ds_store_b8 v0, v1 offset:1920
	ds_store_b8 v0, v26 offset:2048
	ds_store_b8 v0, v8 offset:2176
	ds_store_b8_d16_hi v0, v26 offset:2304
	ds_store_b8 v0, v12 offset:2432
	ds_store_b8 v0, v20 offset:2560
	ds_store_b8 v0, v13 offset:2688
	ds_store_b8_d16_hi v0, v20 offset:2816
	v_and_b16 v1.l, 0xff, v3.l
	v_lshlrev_b16 v1.h, 8, v15.l
	v_mov_b16_e32 v12.l, 0
	v_lshrrev_b32_e32 v8, 24, v20
	v_lshrrev_b32_e32 v4, 8, v7
	v_lshrrev_b32_e32 v3, 8, v14
	v_or_b16 v12.h, v1.l, v1.h
	v_mov_b16_e32 v2.h, v12.l
	v_lshrrev_b32_e32 v5, 24, v7
	v_lshrrev_b32_e32 v13, 24, v14
	v_lshrrev_b32_e32 v6, 8, v9
	v_lshrrev_b32_e32 v15, 8, v10
	v_or_b32_e32 v1, v2, v12
	v_mad_u32_u24 v2, v0, 3, v0
	ds_store_b8 v0, v8 offset:2944
	ds_store_b8 v0, v14 offset:3072
	ds_store_b8 v0, v3 offset:3200
	ds_store_b8_d16_hi v0, v14 offset:3328
	ds_store_b8 v0, v13 offset:3456
	ds_store_b8 v0, v10 offset:3584
	ds_store_b8 v0, v15 offset:3712
	ds_store_b8_d16_hi v0, v10 offset:3840
	ds_store_b8 v0, v11 offset:3968
	v_lshlrev_b32_e32 v3, 2, v0
	ds_store_b8 v0, v7
	ds_store_b8 v0, v4 offset:128
	ds_store_b8_d16_hi v0, v7 offset:256
	ds_store_b8 v0, v5 offset:384
	ds_store_b8 v0, v9 offset:512
	ds_store_b8 v0, v6 offset:640
	ds_store_b8_d16_hi v0, v9 offset:768
	ds_store_b32 v3, v1 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v2
	v_or_b32_e32 v4, s7, v0
	s_mov_b32 s0, exec_lo
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 8, v2
	v_lshlrev_b16 v1.h, 4, v2.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v1.l, 2, v1.l
	v_or_b16 v1.l, v1.l, v2.l
	v_lshrrev_b32_e32 v2, 24, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v1.l, v1.l, v1.h
	v_lshlrev_b16 v1.h, 6, v2.l
	v_ashrrev_i32_e32 v2, 31, v4
	v_add_co_u32 v4, vcc_lo, s4, v4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_or_b16 v1.l, v1.l, v1.h
	v_add_co_ci_u32_e64 v5, null, s5, v2, vcc_lo
	global_store_b8 v[4:5], v1, off
	v_cmpx_gt_u32_e32 0x380, v0
	s_cbranch_execz .LBB2_83
; %bb.76:
	v_or_b32_e32 v5, 0x80, v0
	v_ashrrev_i32_e32 v6, 31, v0
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_2)
	v_lshlrev_b32_e32 v1, 2, v5
	ds_load_b32 v2, v1
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 8, v2
	v_lshrrev_b32_e32 v4, 24, v2
	v_lshlrev_b16 v1.h, 4, v2.h
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v1.l, 2, v1.l
	v_or_b16 v1.l, v1.l, v2.l
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_lshlrev_b16 v2.l, 6, v4.l
	v_or_b16 v1.l, v1.l, v1.h
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_or_b16 v4.l, v1.l, v2.l
	v_add_co_u32 v1, vcc_lo, s2, v0
	v_add_co_ci_u32_e64 v2, null, s3, v6, vcc_lo
	global_store_b8 v[1:2], v4, off offset:128
	v_cmpx_gt_u32_e32 0x380, v5
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB2_83
; %bb.77:
	v_or_b32_e32 v5, 0x100, v0
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v4, 2, v5
	ds_load_b32 v6, v4
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v4, 8, v6
	v_lshlrev_b16 v4.h, 4, v6.h
	v_lshlrev_b16 v4.l, 2, v4.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_or_b16 v4.l, v4.l, v6.l
	v_lshrrev_b32_e32 v6, 24, v6
	v_or_b16 v4.l, v4.l, v4.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v4.h, 6, v6.l
	v_or_b16 v4.l, v4.l, v4.h
	global_store_b8 v[1:2], v4, off offset:256
	v_cmpx_gt_u32_e32 0x380, v5
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB2_83
; %bb.78:
	v_or_b32_e32 v5, 0x180, v0
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v4, 2, v5
	ds_load_b32 v6, v4
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v4, 8, v6
	v_lshlrev_b16 v4.h, 4, v6.h
	v_lshlrev_b16 v4.l, 2, v4.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_or_b16 v4.l, v4.l, v6.l
	v_lshrrev_b32_e32 v6, 24, v6
	v_or_b16 v4.l, v4.l, v4.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v4.h, 6, v6.l
	v_or_b16 v4.l, v4.l, v4.h
	global_store_b8 v[1:2], v4, off offset:384
	v_cmpx_gt_u32_e32 0x380, v5
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB2_83
; %bb.79:
	v_or_b32_e32 v5, 0x200, v0
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v4, 2, v5
	ds_load_b32 v6, v4
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v4, 8, v6
	v_lshlrev_b16 v4.h, 4, v6.h
	v_lshlrev_b16 v4.l, 2, v4.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_or_b16 v4.l, v4.l, v6.l
	v_lshrrev_b32_e32 v6, 24, v6
	v_or_b16 v4.l, v4.l, v4.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v4.h, 6, v6.l
	v_or_b16 v4.l, v4.l, v4.h
	global_store_b8 v[1:2], v4, off offset:512
	v_cmpx_gt_u32_e32 0x380, v5
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB2_83
; %bb.80:
	v_or_b32_e32 v5, 0x280, v0
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v4, 2, v5
	ds_load_b32 v6, v4
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v4, 8, v6
	v_lshlrev_b16 v4.h, 4, v6.h
	v_lshlrev_b16 v4.l, 2, v4.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_or_b16 v4.l, v4.l, v6.l
	v_lshrrev_b32_e32 v6, 24, v6
	v_or_b16 v4.l, v4.l, v4.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v4.h, 6, v6.l
	v_or_b16 v4.l, v4.l, v4.h
	global_store_b8 v[1:2], v4, off offset:640
	v_cmpx_gt_u32_e32 0x380, v5
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB2_83
; %bb.81:
	v_or_b32_e32 v5, 0x300, v0
	s_mov_b32 s1, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_lshlrev_b32_e32 v4, 2, v5
	ds_load_b32 v6, v4
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v4, 8, v6
	v_lshlrev_b16 v4.h, 4, v6.h
	v_lshlrev_b16 v4.l, 2, v4.l
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_or_b16 v4.l, v4.l, v6.l
	v_lshrrev_b32_e32 v6, 24, v6
	v_or_b16 v4.l, v4.l, v4.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v4.h, 6, v6.l
	v_or_b16 v4.l, v4.l, v4.h
	global_store_b8 v[1:2], v4, off offset:768
	v_cmpx_gt_u32_e32 0x380, v5
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB2_83
; %bb.82:
	ds_load_b32 v4, v3 offset:3584
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v3, 8, v4
	v_lshlrev_b16 v3.h, 4, v4.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v3.l, 2, v3.l
	v_or_b16 v3.l, v3.l, v4.l
	v_lshrrev_b32_e32 v4, 24, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v3.l, v3.l, v3.h
	v_lshlrev_b16 v3.h, 6, v4.l
	s_delay_alu instid0(VALU_DEP_1)
	v_or_b16 v3.l, v3.l, v3.h
	global_store_b8 v[1:2], v3, off offset:896
.LBB2_83:                               ; %.lr.ph
	s_or_b32 exec_lo, exec_lo, s0
	s_addk_i32 s6, 0xfe00
	s_mov_b32 s1, 0
	.p2align	6
.LBB2_84:                               ; =>This Inner Loop Header: Depth=1
	ds_load_u8_d16 v1, v0 offset:4096
	v_add_nc_u32_e32 v2, s6, v0
	v_add_nc_u32_e32 v4, 0x80, v0
	v_cmp_lt_u32_e32 vcc_lo, 0x17f, v0
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_ashrrev_i32_e32 v3, 31, v2
	v_add_co_u32 v2, s0, s4, v2
	v_mov_b32_e32 v0, v4
	s_or_b32 s1, vcc_lo, s1
	s_delay_alu instid0(VALU_DEP_3)
	v_add_co_ci_u32_e64 v3, null, s5, v3, s0
	s_waitcnt lgkmcnt(0)
	global_store_b8 v[2:3], v1, off
	s_and_not1_b32 exec_lo, exec_lo, s1
	s_cbranch_execnz .LBB2_84
.LBB2_85:                               ; %._crit_edge
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii
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
		.amdhsa_next_free_vgpr 51
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
		.amdhsa_inst_pref_size 63
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
	.size	_ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii, .Lfunc_end2-_ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii
                                        ; -- End function
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.num_vgpr, 51
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.num_agpr, 0
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.numbered_sgpr, 13
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.num_named_barrier, 0
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.private_seg_size, 0
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.uses_vcc, 1
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.uses_flat_scratch, 0
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.has_dyn_sized_stack, 0
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.has_recursion, 0
	.set _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 8288
; TotalNumSgprs: 15
; NumVgprs: 51
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 4608 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 6
; NumSGPRsForWavesPerEU: 15
; NumVGPRsForWavesPerEU: 51
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
	.protected	_ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii ; -- Begin function _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii
	.globl	_ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii
	.p2align	8
	.type	_ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii,@function
_ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii: ; @_ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii
; %bb.0:
	v_cmp_gt_u32_e32 vcc_lo, 0x80, v0
	s_cmp_lt_i32 s2, 8
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s3, s3, vcc_lo
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB3_87
; %bb.1:
	s_load_b256 s[4:11], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s11, 0
	s_cselect_b32 s3, -1, 0
	s_cmp_eq_u32 s11, 0
	s_mov_b32 s11, 0
	s_cbranch_scc1 .LBB3_88
; %bb.2:
	s_sub_i32 s0, s10, 33
	v_mov_b32_e32 v1, 0x43000
	s_mul_hi_i32 s1, s0, 0x3e0f83e1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s12, s1, 31
	s_ashr_i32 s1, s1, 3
	s_add_i32 s1, s1, s12
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s1, s1, 33
	s_sub_i32 s0, s0, s1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s1, s0, 31
	s_add_u32 s0, s4, s0
	s_addc_u32 s1, s5, s1
	global_load_u8 v1, v1, s[0:1] offset:1760
	s_waitcnt vmcnt(0)
	v_readfirstlane_b32 s0, v1
	s_lshl_b32 s0, s0, 11
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s0, s4, s0
	s_addc_u32 s1, s5, 0
	s_add_u32 s0, s0, 0x32e00
	s_addc_u32 s1, s1, 0
	s_and_not1_b32 vcc_lo, exec_lo, s11
	s_mov_b32 s5, s2
	s_cbranch_vccnz .LBB3_4
.LBB3_3:
	s_mul_i32 s0, s2, 0x2100
	s_mul_hi_i32 s1, s2, 0x2100
	s_add_u32 s0, s6, s0
	s_addc_u32 s1, s7, s1
	s_add_u32 s0, s0, 0x3a000
	s_addc_u32 s1, s1, 0
	s_sub_i32 s4, s10, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_hi_i32 s5, s4, 0x3e0f83e1
	s_lshr_b32 s11, s5, 31
	s_ashr_i32 s5, s5, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s5, s5, s11
	s_mul_i32 s5, s5, 33
	s_delay_alu instid0(SALU_CYCLE_1)
	s_sub_i32 s5, s4, s5
.LBB3_4:
	v_and_b32_e32 v1, 31, v0
	s_mov_b32 s4, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_eq_u32_e32 0, v1
	s_cbranch_execz .LBB3_80
; %bb.5:
	s_lshl_b32 s5, s5, 8
	v_lshlrev_b32_e32 v5, 1, v0
	s_ashr_i32 s11, s5, 31
	s_add_u32 s0, s0, s5
	s_addc_u32 s1, s1, s11
	s_clause 0x3
	global_load_b128 v[1:4], v5, s[0:1]
	global_load_b128 v[8:11], v5, s[0:1] offset:16
	global_load_b128 v[12:15], v5, s[0:1] offset:32
	global_load_b128 v[43:46], v5, s[0:1] offset:48
	v_mov_b32_e32 v39, 0
	s_waitcnt vmcnt(3)
	v_dual_mov_b32 v23, 0 :: v_dual_lshlrev_b32 v42, 16, v2
	v_lshlrev_b32_e32 v18, 16, v1
	v_and_b32_e32 v7, 0xffff0000, v1
	v_and_b32_e32 v41, 0xffff0000, v2
	v_lshlrev_b32_e32 v40, 16, v3
	v_and_b32_e32 v38, 0xffff0000, v3
	v_lshlrev_b32_e32 v36, 16, v4
	v_max3_f32 v1, v18, 0xff800000, v7
	v_min3_f32 v2, v18, 0x7f800000, v7
	s_waitcnt vmcnt(2)
	v_lshlrev_b32_e32 v35, 16, v8
	v_and_b32_e32 v34, 0xffff0000, v8
	v_lshlrev_b32_e32 v33, 16, v9
	v_max3_f32 v1, v1, v42, v41
	v_min3_f32 v3, v2, v42, v41
	v_and_b32_e32 v2, 0xffff0000, v4
	v_lshlrev_b32_e32 v31, 16, v10
	v_and_b32_e32 v30, 0xffff0000, v10
	v_max3_f32 v1, v1, v40, v38
	v_min3_f32 v3, v3, v40, v38
	v_lshlrev_b32_e32 v8, 16, v11
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v6, 16, v12
	v_lshlrev_b32_e32 v29, 16, v13
	v_max3_f32 v1, v1, v36, v2
	v_min3_f32 v4, v3, v36, v2
	v_and_b32_e32 v3, 0xffff0000, v9
	v_and_b32_e32 v27, 0xffff0000, v13
	v_lshlrev_b32_e32 v26, 16, v14
	v_max3_f32 v1, v1, v35, v34
	v_min3_f32 v4, v4, v35, v34
	v_and_b32_e32 v25, 0xffff0000, v14
	v_lshlrev_b32_e32 v24, 16, v15
	v_and_b32_e32 v22, 0xffff0000, v15
	v_max3_f32 v1, v1, v33, v3
	v_min3_f32 v5, v4, v33, v3
	v_and_b32_e32 v4, 0xffff0000, v11
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v21, 16, v43
	v_and_b32_e32 v20, 0xffff0000, v43
	v_max3_f32 v1, v1, v31, v30
	v_min3_f32 v9, v5, v31, v30
	v_and_b32_e32 v5, 0xffff0000, v12
	v_lshlrev_b32_e32 v19, 16, v44
	v_and_b32_e32 v17, 0xffff0000, v44
	v_max3_f32 v1, v1, v8, v4
	v_min3_f32 v9, v9, v8, v4
	v_lshlrev_b32_e32 v16, 16, v45
	v_and_b32_e32 v14, 0xffff0000, v45
	v_lshlrev_b32_e32 v13, 16, v46
	v_max3_f32 v1, v1, v6, v5
	v_min3_f32 v9, v9, v6, v5
	v_and_b32_e32 v12, 0xffff0000, v46
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_max3_f32 v1, v1, v29, v27
	v_min3_f32 v9, v9, v29, v27
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v26, v25
	v_min3_f32 v9, v9, v26, v25
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v24, v22
	v_min3_f32 v9, v9, v24, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v21, v20
	v_min3_f32 v9, v9, v21, v20
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v19, v17
	v_min3_f32 v9, v9, v19, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v16, v14
	v_min3_f32 v9, v9, v16, v14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v1, v1, v13, v12
	v_min3_f32 v15, v9, v13, v12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[9:10], v1
	v_cvt_f64_f32_e32 v[43:44], v15
	v_mov_b16_e32 v1.h, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_mov_b16_e32 v28.l, v1.h
	v_add_f64 v[9:10], v[9:10], -v[43:44]
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f64 v[43:44], null, 0x40080000, 0x40080000, v[9:10]
	v_div_scale_f64 v[49:50], vcc_lo, v[9:10], 0x40080000, v[9:10]
	v_rcp_f64_e32 v[45:46], v[43:44]
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[47:48], -v[43:44], v[45:46], 1.0
	v_fma_f64 v[45:46], v[45:46], v[47:48], v[45:46]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[47:48], -v[43:44], v[45:46], 1.0
	v_fma_f64 v[45:46], v[45:46], v[47:48], v[45:46]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f64 v[47:48], v[49:50], v[45:46]
	v_fma_f64 v[43:44], -v[43:44], v[47:48], v[49:50]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fmas_f64 v[43:44], v[43:44], v[45:46], v[47:48]
	v_div_fixup_f64 v[9:10], v[43:44], 0x40080000, v[9:10]
	s_delay_alu instid0(VALU_DEP_1)
	v_cvt_f32_f64_e32 v11, v[9:10]
	v_cmp_neq_f64_e64 s0, 0, v[9:10]
	s_and_saveexec_b32 s5, s0
	s_cbranch_execz .LBB3_7
; %bb.6:
	v_sub_f32_e32 v7, v7, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v28, null, v11, v11, v7
	v_rcp_f32_e32 v37, v28
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v44, -v28, v37, 1.0
	v_dual_sub_f32 v18, v18, v15 :: v_dual_fmac_f32 v37, v44, v37
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v23, null, v11, v11, v18
	v_div_scale_f32 v45, vcc_lo, v18, v11, v18
	v_rcp_f32_e32 v32, v23
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v43, -v23, v32, 1.0
	v_fmac_f32_e32 v32, v43, v32
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v44, v45, v32
	v_div_scale_f32 v43, s1, v7, v11, v7
	v_fma_f32 v47, -v23, v44, v45
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v46, v43, v37
	v_fmac_f32_e32 v44, v47, v32
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v48, -v28, v46, v43
	v_fma_f32 v23, -v23, v44, v45
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v46, v48, v37
	v_div_fmas_f32 v23, v23, v32, v44
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fma_f32 v28, -v28, v46, v43
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v18, v23, v11, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v28, v28, v37, v46
	v_rndne_f32_e32 v18, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v7, v28, v11, v7
	v_med3_f32 v18, v18, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v7, v7
	v_cvt_i32_f32_e32 v23, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_med3_f32 v7, v7, 0, 0x40400000
	v_cvt_i32_f32_e32 v28, v7
.LBB3_7:                                ; %.critedge.i
	s_or_b32 exec_lo, exec_lo, s5
	s_delay_alu instid0(VALU_DEP_1)
	v_lshlrev_b16 v1.l, 8, v28.l
	v_mov_b32_e32 v37, v39
	v_mov_b32_e32 v32, v39
	v_mov_b32_e32 v7, v39
	v_mov_b32_e32 v28, v39
	v_or_b16 v1.l, v23.l, v1.l
	v_mov_b32_e32 v23, v39
	v_mov_b32_e32 v18, v39
                                        ; implicit-def: $vgpr43_lo16
	s_and_saveexec_b32 s1, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_9
; %bb.8:
	v_sub_f32_e32 v7, v42, v15
	v_sub_f32_e32 v28, v41, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v18, null, v11, v11, v7
	v_div_scale_f32 v32, null, v11, v11, v28
	v_div_scale_f32 v42, vcc_lo, v7, v11, v7
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v23, v18
	v_rcp_f32_e32 v41, v32
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v37, -v18, v23, 1.0
	v_fma_f32 v43, -v32, v41, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v23, v37, v23
	v_fmac_f32_e32 v41, v43, v41
	v_div_scale_f32 v45, s1, v28, v11, v28
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v37, v42, v23
	v_mul_f32_e32 v43, v45, v41
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v44, -v18, v37, v42
	v_fmac_f32_e32 v37, v44, v23
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v18, -v18, v37, v42
	v_fma_f32 v42, -v32, v43, v45
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v18, v18, v23, v37
	v_fmac_f32_e32 v43, v42, v41
	s_mov_b32 vcc_lo, s1
	v_mov_b32_e32 v37, v39
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v7, v18, v11, v7
	v_fma_f32 v18, -v32, v43, v45
	v_mov_b32_e32 v32, v39
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_rndne_f32_e32 v7, v7
	v_div_fmas_f32 v18, v18, v41, v43
	v_mov_b16_e32 v41.l, 0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_med3_f32 v7, v7, 0, 0x40400000
	v_div_fixup_f32 v18, v18, v11, v28
	v_mov_b32_e32 v28, v39
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_i32_f32_e32 v23, v7
	v_rndne_f32_e32 v18, v18
	v_mov_b32_e32 v7, v39
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_mov_b16_e32 v41.h, v23.l
	v_med3_f32 v42, v18, 0, 0x40400000
	v_mov_b32_e32 v23, v39
	v_mov_b32_e32 v18, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_or_b32_e32 v1, v1, v41
	v_cvt_i32_f32_e32 v43, v42
.LBB3_9:                                ; %Flow257
	s_and_not1_saveexec_b32 s1, s5
; %bb.10:                               ; %.critedge39.i
	v_mov_b16_e32 v43.l, 0
; %bb.11:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v1, v1, v43, 0x60504
                                        ; implicit-def: $vgpr41_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_13
; %bb.12:
	v_sub_f32_e32 v38, v38, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v43, null, v11, v11, v38
	v_div_scale_f32 v49, s1, v38, v11, v38
	v_rcp_f32_e32 v45, v43
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v47, -v43, v45, 1.0
	v_dual_sub_f32 v40, v40, v15 :: v_dual_fmac_f32 v45, v47, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_scale_f32 v41, null, v11, v11, v40
	v_div_scale_f32 v46, vcc_lo, v40, v11, v40
	v_mul_f32_e32 v47, v49, v45
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v42, v41
	v_fma_f32 v44, -v41, v42, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v42, v44, v42
	v_mul_f32_e32 v44, v46, v42
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v48, -v41, v44, v46
	v_fmac_f32_e32 v44, v48, v42
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f32 v41, -v41, v44, v46
	v_fma_f32 v46, -v43, v47, v49
	v_fmac_f32_e32 v47, v46, v45
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v41, v41, v42, v44
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v40, v41, v11, v40
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v41, -v43, v47, v49
	v_rndne_f32_e32 v40, v40
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v41, v41, v45, v47
	v_med3_f32 v40, v40, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v41, v41, v11, v38
	v_and_b16 v38.l, 0xff00, v39.l
	v_mov_b16_e32 v38.h, 0
	v_cvt_i32_f32_e32 v40, v40
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v41, v41
	v_or_b16 v38.l, v40.l, v38.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v40, v41, 0, 0x40400000
	v_and_or_b32 v39, 0xffff0000, v39, v38
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v41, v40
.LBB3_13:                               ; %Flow256
	s_and_not1_saveexec_b32 s1, s5
; %bb.14:                               ; %.critedge43.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v39, 0xffffff00, v39
	v_mov_b16_e32 v41.l, 0
; %bb.15:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v38, v39, v41, 0x7060004
                                        ; implicit-def: $vgpr39_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_17
; %bb.16:
	v_sub_f32_e32 v36, v36, v15
	v_sub_f32_e32 v2, v2, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v39, null, v11, v11, v36
	v_div_scale_f32 v41, null, v11, v11, v2
	v_div_scale_f32 v44, vcc_lo, v36, v11, v36
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v40, v39
	v_rcp_f32_e32 v43, v41
	v_div_scale_f32 v47, s1, v2, v11, v2
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v42, -v39, v40, 1.0
	v_fma_f32 v45, -v41, v43, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v40, v42, v40 :: v_dual_fmac_f32 v43, v45, v43
	v_dual_mul_f32 v42, v44, v40 :: v_dual_mul_f32 v45, v47, v43
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v46, -v39, v42, v44
	v_fmac_f32_e32 v42, v46, v40
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v39, -v39, v42, v44
	v_fma_f32 v44, -v41, v45, v47
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v45, v44, v43
	v_div_fmas_f32 v39, v39, v40, v42
	s_mov_b32 vcc_lo, s1
	v_mov_b16_e32 v40.l, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v36, v39, v11, v36
	v_fma_f32 v39, -v41, v45, v47
	v_rndne_f32_e32 v36, v36
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v39, v39, v43, v45
	v_med3_f32 v36, v36, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v39, v39, v11, v2
	v_and_b16 v2.l, 0xff00, v38.h
	v_cvt_i32_f32_e32 v36, v36
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v39, v39
	v_or_b16 v40.h, v36.l, v2.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v36, v39, 0, 0x40400000
	v_and_or_b32 v2, 0xffff, v38, v40
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v39, v36
                                        ; implicit-def: $vgpr38
.LBB3_17:                               ; %Flow255
	s_and_not1_saveexec_b32 s1, s5
; %bb.18:                               ; %.critedge47.i
	v_and_b32_e32 v2, 0xff00ffff, v38
	v_mov_b16_e32 v39.l, 0
; %bb.19:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v2, v2, v39, 0x60504
                                        ; implicit-def: $vgpr36_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_21
; %bb.20:
	v_sub_f32_e32 v35, v35, v15
	v_sub_f32_e32 v34, v34, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v36, null, v11, v11, v35
	v_div_scale_f32 v39, null, v11, v11, v34
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rcp_f32_e32 v38, v36
	v_rcp_f32_e32 v41, v39
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v40, -v36, v38, 1.0
	v_fma_f32 v43, -v39, v41, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v38, v40, v38
	v_div_scale_f32 v42, vcc_lo, v35, v11, v35
	v_fmac_f32_e32 v41, v43, v41
	v_div_scale_f32 v45, s1, v34, v11, v34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v40, v42, v38 :: v_dual_mul_f32 v43, v45, v41
	v_fma_f32 v44, -v36, v40, v42
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v40, v44, v38
	v_fma_f32 v36, -v36, v40, v42
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v42, -v39, v43, v45
	v_fmac_f32_e32 v43, v42, v41
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v36, v36, v38, v40
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v35, v36, v11, v35
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v36, -v39, v43, v45
	v_rndne_f32_e32 v35, v35
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v36, v36, v41, v43
	v_med3_f32 v35, v35, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v36, v36, v11, v34
	v_and_b16 v34.l, 0xff00, v37.l
	v_mov_b16_e32 v34.h, 0
	v_cvt_i32_f32_e32 v35, v35
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v36, v36
	v_or_b16 v34.l, v35.l, v34.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v35, v36, 0, 0x40400000
	v_and_or_b32 v37, 0xffff0000, v37, v34
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v36, v35
.LBB3_21:                               ; %Flow254
	s_and_not1_saveexec_b32 s1, s5
; %bb.22:                               ; %.critedge51.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v37, 0xffffff00, v37
	v_mov_b16_e32 v36.l, 0
; %bb.23:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v34, v37, v36, 0x7060004
                                        ; implicit-def: $vgpr35_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_25
; %bb.24:
	v_sub_f32_e32 v33, v33, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v35, null, v11, v11, v33
	v_rcp_f32_e32 v36, v35
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v38, -v35, v36, 1.0
	v_fmac_f32_e32 v36, v38, v36
	v_div_scale_f32 v40, vcc_lo, v33, v11, v33
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_sub_f32 v3, v3, v15 :: v_dual_mul_f32 v38, v40, v36
	v_div_scale_f32 v37, null, v11, v11, v3
	v_div_scale_f32 v43, s1, v3, v11, v3
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fma_f32 v42, -v35, v38, v40
	v_rcp_f32_e32 v39, v37
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v38, v42, v36
	v_fma_f32 v35, -v35, v38, v40
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v41, -v37, v39, 1.0
	v_div_fmas_f32 v35, v35, v36, v38
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v39, v41, v39
	s_mov_b32 vcc_lo, s1
	v_mov_b16_e32 v36.l, 0
	v_div_fixup_f32 v33, v35, v11, v33
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v41, v43, v39
	v_rndne_f32_e32 v33, v33
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v40, -v37, v41, v43
	v_med3_f32 v33, v33, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v41, v40, v39
	v_cvt_i32_f32_e32 v33, v33
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v35, -v37, v41, v43
	v_div_fmas_f32 v35, v35, v39, v41
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v35, v35, v11, v3
	v_and_b16 v3.l, 0xff00, v34.h
	v_rndne_f32_e32 v35, v35
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v36.h, v33.l, v3.l
	v_med3_f32 v33, v35, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v3, 0xffff, v34, v36
                                        ; implicit-def: $vgpr34
	v_cvt_i32_f32_e32 v35, v33
.LBB3_25:                               ; %Flow253
	s_and_not1_saveexec_b32 s1, s5
; %bb.26:                               ; %.critedge55.i
	v_and_b32_e32 v3, 0xff00ffff, v34
	v_mov_b16_e32 v35.l, 0
; %bb.27:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v3, v3, v35, 0x60504
                                        ; implicit-def: $vgpr33_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_29
; %bb.28:
	v_sub_f32_e32 v31, v31, v15
	v_sub_f32_e32 v30, v30, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v33, null, v11, v11, v31
	v_div_scale_f32 v35, null, v11, v11, v30
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rcp_f32_e32 v34, v33
	v_rcp_f32_e32 v37, v35
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v36, -v33, v34, 1.0
	v_fma_f32 v39, -v35, v37, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v34, v36, v34
	v_div_scale_f32 v38, vcc_lo, v31, v11, v31
	v_fmac_f32_e32 v37, v39, v37
	v_div_scale_f32 v41, s1, v30, v11, v30
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v36, v38, v34 :: v_dual_mul_f32 v39, v41, v37
	v_fma_f32 v40, -v33, v36, v38
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v36, v40, v34
	v_fma_f32 v33, -v33, v36, v38
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v38, -v35, v39, v41
	v_fmac_f32_e32 v39, v38, v37
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v33, v33, v34, v36
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v31, v33, v11, v31
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v33, -v35, v39, v41
	v_rndne_f32_e32 v31, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v33, v33, v37, v39
	v_med3_f32 v31, v31, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v33, v33, v11, v30
	v_and_b16 v30.l, 0xff00, v32.l
	v_mov_b16_e32 v30.h, 0
	v_cvt_i32_f32_e32 v31, v31
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v33, v33
	v_or_b16 v30.l, v31.l, v30.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v31, v33, 0, 0x40400000
	v_and_or_b32 v32, 0xffff0000, v32, v30
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v33, v31
.LBB3_29:                               ; %Flow252
	s_and_not1_saveexec_b32 s1, s5
; %bb.30:                               ; %.critedge59.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v32, 0xffffff00, v32
	v_mov_b16_e32 v33.l, 0
; %bb.31:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v30, v32, v33, 0x7060004
                                        ; implicit-def: $vgpr31_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_33
; %bb.32:
	v_sub_f32_e32 v8, v8, v15
	v_sub_f32_e32 v4, v4, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v31, null, v11, v11, v8
	v_div_scale_f32 v33, null, v11, v11, v4
	v_div_scale_f32 v36, vcc_lo, v8, v11, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v32, v31
	v_rcp_f32_e32 v35, v33
	v_div_scale_f32 v39, s1, v4, v11, v4
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v34, -v31, v32, 1.0
	v_fma_f32 v37, -v33, v35, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v32, v34, v32 :: v_dual_fmac_f32 v35, v37, v35
	v_dual_mul_f32 v34, v36, v32 :: v_dual_mul_f32 v37, v39, v35
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v38, -v31, v34, v36
	v_fmac_f32_e32 v34, v38, v32
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v31, -v31, v34, v36
	v_fma_f32 v36, -v33, v37, v39
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v37, v36, v35
	v_div_fmas_f32 v31, v31, v32, v34
	s_mov_b32 vcc_lo, s1
	v_mov_b16_e32 v32.l, 0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v8, v31, v11, v8
	v_fma_f32 v31, -v33, v37, v39
	v_rndne_f32_e32 v8, v8
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v31, v31, v35, v37
	v_med3_f32 v8, v8, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v31, v31, v11, v4
	v_and_b16 v4.l, 0xff00, v30.h
	v_cvt_i32_f32_e32 v8, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v31, v31
	v_or_b16 v32.h, v8.l, v4.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v8, v31, 0, 0x40400000
	v_and_or_b32 v4, 0xffff, v30, v32
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v31, v8
                                        ; implicit-def: $vgpr30
.LBB3_33:                               ; %Flow251
	s_and_not1_saveexec_b32 s1, s5
; %bb.34:                               ; %.critedge63.i
	v_and_b32_e32 v4, 0xff00ffff, v30
	v_mov_b16_e32 v31.l, 0
; %bb.35:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v4, v4, v31, 0x60504
                                        ; implicit-def: $vgpr8_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_37
; %bb.36:
	v_sub_f32_e32 v5, v5, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_scale_f32 v31, null, v11, v11, v5
	v_rcp_f32_e32 v33, v31
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v35, -v31, v33, 1.0
	v_dual_sub_f32 v6, v6, v15 :: v_dual_fmac_f32 v33, v35, v33
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v8, null, v11, v11, v6
	v_div_scale_f32 v34, vcc_lo, v6, v11, v6
	v_rcp_f32_e32 v30, v8
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v32, -v8, v30, 1.0
	v_fmac_f32_e32 v30, v32, v30
	v_div_scale_f32 v37, s1, v5, v11, v5
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v32, v34, v30 :: v_dual_mul_f32 v35, v37, v33
	v_fma_f32 v36, -v8, v32, v34
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v32, v36, v30
	v_fma_f32 v8, -v8, v32, v34
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v34, -v31, v35, v37
	v_fmac_f32_e32 v35, v34, v33
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v8, v8, v30, v32
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v6, v8, v11, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v8, -v31, v35, v37
	v_rndne_f32_e32 v6, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v8, v8, v33, v35
	v_med3_f32 v6, v6, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v8, v8, v11, v5
	v_and_b16 v5.l, 0xff00, v7.l
	v_mov_b16_e32 v5.h, 0
	v_cvt_i32_f32_e32 v6, v6
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v8, v8
	v_or_b16 v5.l, v6.l, v5.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v6, v8, 0, 0x40400000
	v_and_or_b32 v7, 0xffff0000, v7, v5
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v8, v6
.LBB3_37:                               ; %Flow250
	s_and_not1_saveexec_b32 s1, s5
; %bb.38:                               ; %.critedge67.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v7, 0xffffff00, v7
	v_mov_b16_e32 v8.l, 0
; %bb.39:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v30, v7, v8, 0x7060004
                                        ; implicit-def: $vgpr31_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
                                        ; implicit-def: $vgpr5_vgpr6_vgpr7_vgpr8
	s_cbranch_execz .LBB3_41
; %bb.40:
	v_sub_f32_e32 v5, v29, v15
	v_sub_f32_e32 v8, v27, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v6, null, v11, v11, v5
	v_div_scale_f32 v27, null, v11, v11, v8
	v_div_scale_f32 v32, vcc_lo, v5, v11, v5
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v7, v6
	v_rcp_f32_e32 v31, v27
	v_div_scale_f32 v35, s1, v8, v11, v8
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v29, -v6, v7, 1.0
	v_fma_f32 v33, -v27, v31, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v7, v29, v7
	v_fmac_f32_e32 v31, v33, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v29, v32, v7
	v_mul_f32_e32 v33, v35, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v34, -v6, v29, v32
	v_fmac_f32_e32 v29, v34, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v6, -v6, v29, v32
	v_fma_f32 v32, -v27, v33, v35
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v6, v6, v7, v29
	v_fmac_f32_e32 v33, v32, v31
	s_mov_b32 vcc_lo, s1
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fixup_f32 v5, v6, v11, v5
	v_fma_f32 v6, -v27, v33, v35
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v5, v5
	v_div_fmas_f32 v6, v6, v31, v33
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v7, v5, 0, 0x40400000
	v_div_fixup_f32 v6, v6, v11, v8
	v_and_b16 v5.l, 0xff00, v30.h
	v_mov_b16_e32 v8.l, 0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_i32_f32_e32 v7, v7
	v_rndne_f32_e32 v6, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v8.h, v7.l, v5.l
	v_med3_f32 v6, v6, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v5, 0xffff, v30, v8
	v_cvt_i32_f32_e32 v31, v6
                                        ; implicit-def: $vgpr30
.LBB3_41:                               ; %Flow249
	s_and_not1_saveexec_b32 s1, s5
; %bb.42:                               ; %.critedge71.i
	v_and_b32_e32 v5, 0xff00ffff, v30
	v_mov_b16_e32 v31.l, 0
; %bb.43:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v5, v5, v31, 0x60504
                                        ; implicit-def: $vgpr27_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_45
; %bb.44:
	v_sub_f32_e32 v26, v26, v15
	v_sub_f32_e32 v25, v25, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v27, null, v11, v11, v26
	v_div_scale_f32 v30, null, v11, v11, v25
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_rcp_f32_e32 v29, v27
	v_rcp_f32_e32 v32, v30
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v31, -v27, v29, 1.0
	v_fma_f32 v34, -v30, v32, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v29, v31, v29
	v_div_scale_f32 v33, vcc_lo, v26, v11, v26
	v_fmac_f32_e32 v32, v34, v32
	v_div_scale_f32 v36, s1, v25, v11, v25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v31, v33, v29 :: v_dual_mul_f32 v34, v36, v32
	v_fma_f32 v35, -v27, v31, v33
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v31, v35, v29
	v_fma_f32 v27, -v27, v31, v33
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v33, -v30, v34, v36
	v_fmac_f32_e32 v34, v33, v32
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v27, v27, v29, v31
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v26, v27, v11, v26
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v27, -v30, v34, v36
	v_rndne_f32_e32 v26, v26
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v27, v27, v32, v34
	v_med3_f32 v26, v26, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v27, v27, v11, v25
	v_and_b16 v25.l, 0xff00, v28.l
	v_mov_b16_e32 v25.h, 0
	v_cvt_i32_f32_e32 v26, v26
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v27, v27
	v_or_b16 v25.l, v26.l, v25.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v26, v27, 0, 0x40400000
	v_and_or_b32 v28, 0xffff0000, v28, v25
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v27, v26
.LBB3_45:                               ; %Flow248
	s_and_not1_saveexec_b32 s1, s5
; %bb.46:                               ; %.critedge75.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v28, 0xffffff00, v28
	v_mov_b16_e32 v27.l, 0
; %bb.47:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v25, v28, v27, 0x7060004
                                        ; implicit-def: $vgpr26_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_49
; %bb.48:
	v_sub_f32_e32 v22, v22, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v27, null, v11, v11, v22
	v_div_scale_f32 v33, s1, v22, v11, v22
	v_rcp_f32_e32 v29, v27
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v31, -v27, v29, 1.0
	v_dual_sub_f32 v6, v24, v15 :: v_dual_fmac_f32 v29, v31, v29
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_scale_f32 v24, null, v11, v11, v6
	v_div_scale_f32 v30, vcc_lo, v6, v11, v6
	v_mul_f32_e32 v31, v33, v29
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v26, v24
	v_fma_f32 v28, -v24, v26, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v26, v28, v26
	v_mul_f32_e32 v28, v30, v26
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v32, -v24, v28, v30
	v_fmac_f32_e32 v28, v32, v26
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f32 v24, -v24, v28, v30
	v_fma_f32 v30, -v27, v31, v33
	v_fmac_f32_e32 v31, v30, v29
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v24, v24, v26, v28
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v6, v24, v11, v6
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v24, -v27, v31, v33
	v_rndne_f32_e32 v6, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v24, v24, v29, v31
	v_med3_f32 v26, v6, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v22, v24, v11, v22
	v_and_b16 v6.l, 0xff00, v25.h
	v_cvt_i32_f32_e32 v24, v26
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_rndne_f32_e32 v22, v22
	v_mov_b16_e32 v26.l, 0
	v_or_b16 v26.h, v24.l, v6.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v22, v22, 0, 0x40400000
	v_and_or_b32 v6, 0xffff, v25, v26
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v26, v22
                                        ; implicit-def: $vgpr25
.LBB3_49:                               ; %Flow247
	s_and_not1_saveexec_b32 s1, s5
; %bb.50:                               ; %.critedge79.i
	v_and_b32_e32 v6, 0xff00ffff, v25
	v_mov_b16_e32 v26.l, 0
; %bb.51:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v6, v6, v26, 0x60504
                                        ; implicit-def: $vgpr22_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_53
; %bb.52:
	v_sub_f32_e32 v21, v21, v15
	v_sub_f32_e32 v20, v20, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v22, null, v11, v11, v21
	v_div_scale_f32 v25, null, v11, v11, v20
	v_div_scale_f32 v31, s1, v20, v11, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v24, v22
	v_rcp_f32_e32 v27, v25
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v26, -v22, v24, 1.0
	v_fma_f32 v29, -v25, v27, 1.0
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v24, v26, v24
	v_div_scale_f32 v28, vcc_lo, v21, v11, v21
	v_dual_fmac_f32 v27, v29, v27 :: v_dual_mul_f32 v26, v28, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_mul_f32_e32 v29, v31, v27
	v_fma_f32 v30, -v22, v26, v28
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v26, v30, v24
	v_fma_f32 v22, -v22, v26, v28
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v28, -v25, v29, v31
	v_div_fmas_f32 v22, v22, v24, v26
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v29, v28, v27
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v21, v22, v11, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v22, -v25, v29, v31
	v_rndne_f32_e32 v21, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v22, v22, v27, v29
	v_med3_f32 v21, v21, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_2) | instid1(VALU_DEP_4)
	v_div_fixup_f32 v22, v22, v11, v20
	v_and_b16 v20.l, 0xff00, v23.l
	v_mov_b16_e32 v20.h, 0
	v_cvt_i32_f32_e32 v21, v21
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v22, v22
	v_or_b16 v20.l, v21.l, v20.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v21, v22, 0, 0x40400000
	v_and_or_b32 v23, 0xffff0000, v23, v20
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v22, v21
.LBB3_53:                               ; %Flow246
	s_and_not1_saveexec_b32 s1, s5
; %bb.54:                               ; %.critedge83.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v23, 0xffffff00, v23
	v_mov_b16_e32 v22.l, 0
; %bb.55:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v20, v23, v22, 0x7060004
                                        ; implicit-def: $vgpr21_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_57
; %bb.56:
	v_sub_f32_e32 v17, v17, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_scale_f32 v22, null, v11, v11, v17
	v_div_scale_f32 v28, s1, v17, v11, v17
	v_rcp_f32_e32 v24, v22
	s_delay_alu instid0(TRANS32_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v26, -v22, v24, 1.0
	v_dual_sub_f32 v7, v19, v15 :: v_dual_fmac_f32 v24, v26, v24
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_scale_f32 v19, null, v11, v11, v7
	v_div_scale_f32 v25, vcc_lo, v7, v11, v7
	v_mul_f32_e32 v26, v28, v24
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v21, v19
	v_fma_f32 v23, -v19, v21, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v21, v23, v21
	v_mul_f32_e32 v23, v25, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v27, -v19, v23, v25
	v_fmac_f32_e32 v23, v27, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f32 v19, -v19, v23, v25
	v_fma_f32 v25, -v22, v26, v28
	v_fmac_f32_e32 v26, v25, v24
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_div_fmas_f32 v19, v19, v21, v23
	s_mov_b32 vcc_lo, s1
	v_div_fixup_f32 v7, v19, v11, v7
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_f32 v19, -v22, v26, v28
	v_rndne_f32_e32 v7, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_fmas_f32 v19, v19, v24, v26
	v_med3_f32 v21, v7, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v17, v19, v11, v17
	v_and_b16 v7.l, 0xff00, v20.h
	v_cvt_i32_f32_e32 v19, v21
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_rndne_f32_e32 v17, v17
	v_mov_b16_e32 v21.l, 0
	v_or_b16 v21.h, v19.l, v7.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v17, v17, 0, 0x40400000
	v_and_or_b32 v7, 0xffff, v20, v21
	s_delay_alu instid0(VALU_DEP_2)
	v_cvt_i32_f32_e32 v21, v17
                                        ; implicit-def: $vgpr20
.LBB3_57:                               ; %Flow245
	s_and_not1_saveexec_b32 s1, s5
; %bb.58:                               ; %.critedge87.i
	v_and_b32_e32 v7, 0xff00ffff, v20
	v_mov_b16_e32 v21.l, 0
; %bb.59:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v7, v7, v21, 0x60504
                                        ; implicit-def: $vgpr17_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s5, exec_lo, s1
	s_cbranch_execz .LBB3_61
; %bb.60:
	v_sub_f32_e32 v16, v16, v15
	v_sub_f32_e32 v14, v14, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v17, null, v11, v11, v16
	v_div_scale_f32 v20, null, v11, v11, v14
	v_div_scale_f32 v23, vcc_lo, v16, v11, v16
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v19, v17
	v_rcp_f32_e32 v22, v20
	v_div_scale_f32 v26, s1, v14, v11, v14
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v21, -v17, v19, 1.0
	v_fma_f32 v24, -v20, v22, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v19, v21, v19 :: v_dual_fmac_f32 v22, v24, v22
	v_dual_mul_f32 v21, v23, v19 :: v_dual_mul_f32 v24, v26, v22
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v25, -v17, v21, v23
	v_fmac_f32_e32 v21, v25, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v17, -v17, v21, v23
	v_fma_f32 v23, -v20, v24, v26
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v24, v23, v22
	v_div_fmas_f32 v17, v17, v19, v21
	s_mov_b32 vcc_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v16, v17, v11, v16
	v_fma_f32 v17, -v20, v24, v26
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v16, v16
	v_div_fmas_f32 v17, v17, v22, v24
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v16, v16, 0, 0x40400000
	v_div_fixup_f32 v17, v17, v11, v14
	v_and_b16 v14.l, 0xff00, v18.l
	v_mov_b16_e32 v14.h, 0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_i32_f32_e32 v16, v16
	v_rndne_f32_e32 v17, v17
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v14.l, v16.l, v14.l
	v_med3_f32 v16, v17, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v18, 0xffff0000, v18, v14
	v_cvt_i32_f32_e32 v17, v16
.LBB3_61:                               ; %Flow244
	s_and_not1_saveexec_b32 s1, s5
; %bb.62:                               ; %.critedge91.i
	s_delay_alu instid0(VALU_DEP_2)
	v_and_b32_e32 v18, 0xffffff00, v18
	v_mov_b16_e32 v17.l, 0
; %bb.63:
	s_or_b32 exec_lo, exec_lo, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_perm_b32 v14, v18, v17, 0x7060004
                                        ; implicit-def: $vgpr16_lo16
	s_and_saveexec_b32 s1, s0
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB3_65
; %bb.64:
	v_sub_f32_e32 v8, v13, v15
	v_sub_f32_e32 v12, v12, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_div_scale_f32 v13, null, v11, v11, v8
	v_div_scale_f32 v17, null, v11, v11, v12
	v_div_scale_f32 v20, vcc_lo, v8, v11, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rcp_f32_e32 v16, v13
	v_rcp_f32_e32 v19, v17
	v_div_scale_f32 v23, s0, v12, v11, v12
	s_delay_alu instid0(TRANS32_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_fma_f32 v18, -v13, v16, 1.0
	v_fma_f32 v21, -v17, v19, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v16, v18, v16 :: v_dual_fmac_f32 v19, v21, v19
	v_dual_mul_f32 v18, v20, v16 :: v_dual_mul_f32 v21, v23, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v22, -v13, v18, v20
	v_fmac_f32_e32 v18, v22, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_f32 v13, -v13, v18, v20
	v_fma_f32 v20, -v17, v21, v23
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v21, v20, v19
	v_div_fmas_f32 v13, v13, v16, v18
	s_mov_b32 vcc_lo, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_div_fixup_f32 v8, v13, v11, v8
	v_fma_f32 v13, -v17, v21, v23
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_rndne_f32_e32 v8, v8
	v_div_fmas_f32 v13, v13, v19, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_med3_f32 v16, v8, 0, 0x40400000
	v_div_fixup_f32 v11, v13, v11, v12
	v_and_b16 v8.l, 0xff00, v14.h
	v_mov_b16_e32 v13.l, 0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_i32_f32_e32 v12, v16
	v_rndne_f32_e32 v11, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v13.h, v12.l, v8.l
	v_med3_f32 v11, v11, 0, 0x40400000
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_and_or_b32 v8, 0xffff, v14, v13
	v_cvt_i32_f32_e32 v16, v11
                                        ; implicit-def: $vgpr14
.LBB3_65:                               ; %Flow243
	s_and_not1_saveexec_b32 s0, s1
; %bb.66:                               ; %.critedge95.i
	v_and_b32_e32 v8, 0xff00ffff, v14
	v_mov_b16_e32 v16.l, 0
; %bb.67:
	s_or_b32 exec_lo, exec_lo, s0
	v_bfe_u32 v17, v10, 20, 11
                                        ; implicit-def: $vgpr11
	s_mov_b32 s0, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u32_e32 0x7ff, v17
	s_xor_b32 s5, exec_lo, s0
	s_cbranch_execz .LBB3_77
; %bb.68:
	v_mov_b32_e32 v11, 0
	s_mov_b32 s11, exec_lo
	v_cmpx_lt_u32_e32 0x3e5, v17
	s_cbranch_execz .LBB3_76
; %bb.69:
	v_mov_b32_e32 v11, 0x7c00
	s_mov_b32 s12, exec_lo
	v_cmpx_gt_u32_e32 0x40f, v17
	s_cbranch_execz .LBB3_75
; %bb.70:
	v_sub_nc_u32_e32 v11, 0x41b, v17
	v_cmp_gt_u32_e32 vcc_lo, 0x3f1, v17
	s_mov_b32 s0, 0xfffff
	s_mov_b32 s14, exec_lo
	v_and_or_b32 v10, v10, s0, 0x100000
	v_cndmask_b32_e32 v18, 42, v11, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[13:14], v18, -1
	v_add_nc_u32_e32 v11, -1, v18
	v_lshlrev_b64 v[11:12], v11, 1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_bfi_b32 v14, v14, 0, v10
	v_bfi_b32 v13, v13, 0, v9
	v_lshrrev_b64 v[9:10], v18, v[9:10]
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_gt_u64_e64 s13, v[13:14], v[11:12]
	v_cmpx_le_u64_e64 v[13:14], v[11:12]
; %bb.71:
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_and_b32_e32 v18, 1, v9
	v_cmp_eq_u64_e64 s0, v[13:14], v[11:12]
	v_cmp_eq_u32_e64 s1, 1, v18
	s_and_b32 s0, s0, s1
	s_and_not1_b32 s1, s13, exec_lo
	s_and_b32 s0, s0, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s13, s1, s0
; %bb.72:                               ; %Flow235
	s_or_b32 exec_lo, exec_lo, s14
	s_and_saveexec_b32 s1, s13
; %bb.73:
	v_add_co_u32 v9, s0, v9, 1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, 0, v10, s0
; %bb.74:
	s_or_b32 exec_lo, exec_lo, s1
	v_lshl_add_u32 v10, v17, 10, 0xfff03c00
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v10, v10, 0, vcc_lo
	v_add_nc_u32_e32 v11, v10, v9
.LBB3_75:                               ; %Flow237
	s_or_b32 exec_lo, exec_lo, s12
.LBB3_76:                               ; %Flow239
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s11
                                        ; implicit-def: $vgpr9_vgpr10
.LBB3_77:                               ; %Flow241
	s_and_not1_saveexec_b32 s0, s5
; %bb.78:
	v_and_b32_e32 v10, 0xfffff, v10
	v_mov_b32_e32 v11, 0x7c00
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u64_e32 vcc_lo, 0, v[9:10]
	v_cndmask_b32_e32 v11, 0x7e00, v11, vcc_lo
; %bb.79:                               ; %_ZN6stable7quant32EPKhiPhS2_.exit
	s_or_b32 exec_lo, exec_lo, s0
	v_cvt_f16_f32_e32 v9.l, v15
	v_perm_b32 v8, v8, v16, 0x60504
	v_lshrrev_b32_e32 v10, 3, v0
	v_lshrrev_b32_e32 v12, 8, v11
	s_delay_alu instid0(VALU_DEP_4)
	v_lshrrev_b16 v9.h, 8, v9.l
	ds_store_b128 v0, v[1:4]
	ds_store_b128 v0, v[5:8] offset:16
	ds_store_b8 v10, v9 offset:128
	ds_store_b8_d16_hi v10, v9 offset:129
	ds_store_b8 v10, v11 offset:130
	ds_store_b8 v10, v12 offset:131
.LBB3_80:                               ; %Flow258
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_cbranch_vccnz .LBB3_89
; %bb.81:
	s_mul_i32 s0, s2, 48
	s_cbranch_execnz .LBB3_83
.LBB3_82:
	s_mul_i32 s0, s2, 0x2a00
	s_mul_hi_i32 s1, s2, 0x2a00
	s_add_u32 s0, s6, s0
	s_addc_u32 s1, s7, s1
	s_add_u32 s8, s0, 0x25000
	s_mul_i32 s0, s10, 48
	s_addc_u32 s9, s1, 0
	s_addk_i32 s0, 0xf9d0
.LBB3_83:
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s1, s0, 31
	s_add_u32 s0, s8, s0
	s_addc_u32 s1, s9, s1
	s_mov_b32 s2, exec_lo
	v_cmpx_gt_u32_e32 32, v0
	s_cbranch_execz .LBB3_85
; %bb.84:
	v_lshlrev_b32_e32 v1, 2, v0
	ds_load_b32 v2, v1
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 8, v2
	v_lshlrev_b16 v1.h, 4, v2.h
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b16 v1.l, 2, v1.l
	v_or_b16 v1.l, v1.l, v2.l
	v_lshrrev_b32_e32 v2, 24, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_or_b16 v1.l, v1.l, v1.h
	v_lshlrev_b16 v1.h, 6, v2.l
	s_delay_alu instid0(VALU_DEP_1)
	v_or_b16 v1.l, v1.l, v1.h
	global_store_b8 v0, v1, s[0:1]
.LBB3_85:
	s_or_b32 exec_lo, exec_lo, s2
	v_cmp_gt_u32_e32 vcc_lo, 16, v0
	s_and_b32 exec_lo, exec_lo, vcc_lo
	s_cbranch_execz .LBB3_87
; %bb.86:
	ds_load_u8_d16 v1, v0 offset:128
	s_waitcnt lgkmcnt(0)
	global_store_b8 v0, v1, s[0:1] offset:32
.LBB3_87:
	s_endpgm
.LBB3_88:
                                        ; implicit-def: $sgpr0_sgpr1
	s_mov_b32 s5, s2
	s_branch .LBB3_3
.LBB3_89:
                                        ; implicit-def: $sgpr0
	s_branch .LBB3_82
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii
		.amdhsa_group_segment_fixed_size 144
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
		.amdhsa_next_free_vgpr 51
		.amdhsa_next_free_sgpr 15
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
		.amdhsa_inst_pref_size 55
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
	.size	_ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii, .Lfunc_end3-_ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii
                                        ; -- End function
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.num_vgpr, 51
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.num_agpr, 0
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.numbered_sgpr, 15
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.num_named_barrier, 0
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.private_seg_size, 0
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.uses_vcc, 1
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.uses_flat_scratch, 0
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.has_dyn_sized_stack, 0
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.has_recursion, 0
	.set _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 7036
; TotalNumSgprs: 17
; NumVgprs: 51
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 144 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 6
; NumSGPRsForWavesPerEU: 17
; NumVGPRsForWavesPerEU: 51
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
	.protected	_ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi ; -- Begin function _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi
	.globl	_ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi
	.p2align	8
	.type	_ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi,@function
_ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi: ; @_ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi
; %bb.0:
	v_cmp_gt_u32_e32 vcc_lo, 0x80, v0
	s_cmp_eq_u32 s2, 0
	s_mov_b32 s3, 0
	s_cselect_b32 s2, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s2, s2, vcc_lo
	s_and_saveexec_b32 s4, s2
	s_cbranch_execz .LBB4_24
; %bb.1:                                ; %.preheader75
	s_load_b128 s[4:7], s[0:1], 0x0
	v_dual_mov_b32 v1, 0 :: v_dual_mov_b32 v4, v0
	s_waitcnt lgkmcnt(0)
	v_mad_u64_u32 v[2:3], null, 0x180, v0, s[4:5]
	s_add_u32 s8, s4, 0x43701
	s_addc_u32 s9, s5, 0
	v_add_co_u32 v2, vcc_lo, 0x25000, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
	s_branch .LBB4_3
.LBB4_2:                                ; %Flow126
                                        ;   in Loop: Header=BB4_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s12
	v_cndmask_b32_e64 v5, 0, 1, s2
	v_add_nc_u32_e32 v6, 0x80, v4
	v_cmp_lt_u32_e32 vcc_lo, 19, v4
	v_add_co_u32 v2, s2, 0xc000, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	v_add_co_ci_u32_e64 v3, null, 0, v3, s2
	ds_store_b8 v4, v5
	v_mov_b32_e32 v4, v6
	s_or_b32 s3, vcc_lo, s3
	s_and_not1_b32 exec_lo, exec_lo, s3
	s_cbranch_execz .LBB4_7
.LBB4_3:                                ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB4_5 Depth 2
	global_load_d16_u8 v5, v4, s[8:9]
	s_mov_b32 s2, 0
	s_mov_b32 s12, exec_lo
	s_waitcnt vmcnt(0)
	v_cmpx_ne_u16_e32 0, v5.l
	s_cbranch_execz .LBB4_2
; %bb.4:                                ; %.lr.ph
                                        ;   in Loop: Header=BB4_3 Depth=1
	s_mov_b64 s[10:11], 0
	s_mov_b32 s13, 0
                                        ; implicit-def: $sgpr14
	.p2align	6
.LBB4_5:                                ;   Parent Loop BB4_3 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	v_add_co_u32 v5, vcc_lo, v2, s10
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v6, null, s11, v3, vcc_lo
	s_add_u32 s16, s6, s10
	s_addc_u32 s17, s7, s11
	global_load_d16_u8 v7, v1, s[16:17]
	global_load_d16_u8 v5, v[5:6], off
	s_cmpk_gt_u32 s10, 0x17e
	s_cselect_b32 s15, -1, 0
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v6, 0xff, v7
	s_waitcnt vmcnt(0)
	v_and_b16 v5.l, 0xff, v5.l
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_ne_u16_e32 vcc_lo, v5.l, v6.l
	v_cmp_eq_u16_e64 s2, v5.l, v6.l
	s_or_b32 s15, s15, vcc_lo
	s_add_u32 s10, s10, 1
	s_addc_u32 s11, s11, 0
	s_and_b32 s15, exec_lo, s15
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_or_b32 s13, s15, s13
	s_and_not1_b32 s14, s14, exec_lo
	s_and_b32 s2, s2, exec_lo
	s_or_b32 s14, s14, s2
	s_and_not1_b32 exec_lo, exec_lo, s13
	s_cbranch_execnz .LBB4_5
; %bb.6:                                ; %Flow125
                                        ;   in Loop: Header=BB4_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s13
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s2, s14, exec_lo
	s_branch .LBB4_2
.LBB4_7:
	s_or_b32 exec_lo, exec_lo, s3
	s_mov_b32 s11, 0
	s_mov_b32 s10, exec_lo
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cmpx_eq_u32_e32 0, v0
	s_cbranch_execz .LBB4_21
; %bb.8:                                ; %.preheader74.preheader
	v_mov_b32_e32 v2, 0
	s_add_u32 s2, s4, 0x43704
	s_addc_u32 s3, s5, 0
	s_mov_b32 s12, -1
	s_mov_b32 s13, -1
.LBB4_9:                                ; %.preheader74
                                        ; =>This Inner Loop Header: Depth=1
	global_load_b32 v3, v2, s[2:3] offset:-3
	v_mov_b32_e32 v4, s11
	ds_load_b32 v4, v4
	s_waitcnt lgkmcnt(0)
	v_readfirstlane_b32 s14, v4
	s_and_b32 s15, s14, 0xff
	s_lshr_b32 s16, s14, 24
	s_cmp_lg_u32 s15, 0
	s_cselect_b32 s15, -1, 0
	s_cmp_lt_i32 s13, 0
	s_cselect_b32 s17, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s15, s15, s17
	s_and_b32 s15, s15, exec_lo
	s_cselect_b32 s13, s11, s13
	s_waitcnt vmcnt(0)
	v_readfirstlane_b32 s15, v3
	s_and_b32 s17, s15, 0xff
	s_lshr_b32 s18, s15, 24
	s_cmp_eq_u32 s17, 0
	s_cselect_b32 s17, -1, 0
	s_cmp_lt_i32 s12, 0
	s_cselect_b32 s19, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s17, s17, s19
	s_and_b32 s17, s17, exec_lo
	s_cselect_b32 s12, s11, s12
	s_bfe_u32 s17, s14, 0x80008
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lg_u32 s17, 0
	s_cselect_b32 s17, -1, 0
	s_cmp_lt_i32 s13, 0
	s_cselect_b32 s19, -1, 0
	s_add_i32 s20, s11, 1
	s_and_b32 s17, s17, s19
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s17, s17, exec_lo
	s_cselect_b32 s13, s20, s13
	s_bfe_u32 s17, s15, 0x80008
	s_cmp_eq_u32 s17, 0
	s_cselect_b32 s17, -1, 0
	s_cmp_lt_i32 s12, 0
	s_cselect_b32 s19, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s17, s17, s19
	s_and_b32 s17, s17, exec_lo
	s_cselect_b32 s12, s20, s12
	s_bfe_u32 s14, s14, 0x80010
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lg_u32 s14, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s13, 0
	s_cselect_b32 s17, -1, 0
	s_add_i32 s19, s11, 2
	s_and_b32 s14, s14, s17
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s13, s19, s13
	s_bfe_u32 s14, s15, 0x80010
	s_cmp_eq_u32 s14, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s12, 0
	s_cselect_b32 s15, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s14, s14, s15
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s12, s19, s12
	s_cmp_lg_u32 s16, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s13, 0
	s_cselect_b32 s15, -1, 0
	s_add_i32 s16, s11, 3
	s_and_b32 s14, s14, s15
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s13, s16, s13
	s_cmp_eq_u32 s18, 0
	s_cselect_b32 s14, -1, 0
	s_cmp_lt_i32 s12, 0
	s_cselect_b32 s15, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s14, s14, s15
	s_and_b32 s14, s14, exec_lo
	s_cselect_b32 s12, s16, s12
	s_add_u32 s2, s2, 4
	s_addc_u32 s3, s3, 0
	s_add_i32 s11, s11, 4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmpk_eq_i32 s11, 0x94
	s_cbranch_scc0 .LBB4_9
; %bb.10:
	s_cmp_lt_i32 s13, 0
	s_cselect_b32 s11, s12, s13
	s_lshr_b32 s2, s13, 31
	s_delay_alu instid0(SALU_CYCLE_1)
	v_dual_mov_b32 v2, 0 :: v_dual_mov_b32 v3, s2
	v_mov_b32_e32 v4, s11
	s_cmp_lt_i32 s11, 0
	s_cselect_b32 s13, -1, 0
	s_cmp_gt_i32 s11, -1
	ds_store_2addr_b32 v2, v3, v4 offset0:37 offset1:38
	s_cbranch_scc0 .LBB4_19
; %bb.11:
	s_load_b32 s12, s[4:5], 0x437bc
	s_add_u32 s2, s4, 0x437bc
	s_addc_u32 s3, s5, 0
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s12, 0
	s_cselect_b32 s13, -1, 0
	s_cmp_eq_u32 s12, 0
	s_cbranch_scc0 .LBB4_19
; %bb.12:
	s_load_b32 s13, s[0:1], 0x10
	s_load_b32 s12, s[4:5], 0x437c0
	s_add_u32 s0, s4, 0x437c0
	s_addc_u32 s1, s5, 0
	s_waitcnt lgkmcnt(0)
	s_sub_i32 s13, s13, 33
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s12, s13
	s_mov_b32 s13, -1
	s_cbranch_scc0 .LBB4_19
; %bb.13:
	s_mul_hi_i32 s13, s12, 0x3e0f83e1
	v_mov_b32_e32 v2, 0x43000
	s_lshr_b32 s14, s13, 31
	s_ashr_i32 s13, s13, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s13, s13, s14
	s_mul_i32 s13, s13, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s13, s12, s13
	s_ashr_i32 s15, s13, 31
	s_add_u32 s14, s4, s13
	s_addc_u32 s15, s5, s15
	global_load_d16_u8 v3, v2, s[14:15] offset:1760
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v3, 0xffff, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, s13, s4, v3
	v_add_co_ci_u32_e64 v5, null, s5, 0, s13
	s_mov_b32 s13, 0
	v_readfirstlane_b32 s14, v4
	v_readfirstlane_b32 s15, v5
	global_load_u8 v3, v2, s[14:15] offset:1941
	s_waitcnt vmcnt(0)
	v_cmp_ne_u32_e32 vcc_lo, 0, v3
	v_mov_b32_e32 v3, 0
	s_cbranch_vccz .LBB4_15
; %bb.14:
	s_add_i32 s14, s12, 1
	v_add_co_u32 v4, vcc_lo, 0x43795, v4
	v_dual_mov_b32 v6, s14 :: v_dual_mov_b32 v7, s11
	s_ashr_i32 s11, s12, 31
	s_add_u32 s14, s4, s12
	s_addc_u32 s15, s5, s11
	s_clause 0x1
	global_store_b32 v3, v6, s[0:1]
	global_store_b8 v2, v7, s[14:15] offset:1536
	global_load_u8 v6, v7, s[8:9]
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	v_mov_b32_e32 v8, 1
	s_waitcnt vmcnt(0)
	v_add_nc_u32_e32 v6, 1, v6
	global_store_b8 v7, v6, s[8:9]
	global_load_u8 v6, v[4:5], off
	s_waitcnt vmcnt(0)
	v_dual_mov_b32 v7, 32 :: v_dual_add_nc_u32 v6, -1, v6
	s_clause 0x2
	global_store_b8 v[4:5], v6, off
	global_store_b32 v2, v7, s[4:5] offset:1988
	global_store_b32 v3, v8, s[2:3]
	s_branch .LBB4_16
.LBB4_15:
	s_mov_b32 s13, -1
.LBB4_16:                               ; %Flow117
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s13
	s_cbranch_vccnz .LBB4_18
; %bb.17:
	v_dual_mov_b32 v2, 0x43000 :: v_dual_mov_b32 v3, 4
	v_dual_mov_b32 v4, -1 :: v_dual_mov_b32 v5, 0
	global_store_b32 v2, v3, s[4:5] offset:1992
	ds_store_b32 v5, v4 offset:152
.LBB4_18:                               ; %Flow118
	s_mov_b32 s13, 0
.LBB4_19:                               ; %Flow119
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s13
	s_cbranch_vccz .LBB4_21
; %bb.20:
	v_dual_mov_b32 v2, 0x43000 :: v_dual_mov_b32 v3, 3
	v_dual_mov_b32 v4, -1 :: v_dual_mov_b32 v5, 0
	global_store_b32 v2, v3, s[4:5] offset:1992
	ds_store_b32 v5, v4 offset:152
.LBB4_21:                               ; %Flow123
	s_or_b32 exec_lo, exec_lo, s10
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_waitcnt_vscnt null, 0x0
	s_barrier
	buffer_gl0_inv
	ds_load_2addr_b32 v[2:3], v2 offset0:37 offset1:38
	s_waitcnt lgkmcnt(0)
	v_readfirstlane_b32 s0, v3
	v_readfirstlane_b32 s1, v2
	s_cmp_gt_i32 s0, -1
	s_cselect_b32 s2, -1, 0
	s_cmp_lg_u32 s1, 0
	s_cselect_b32 s1, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s1, s2, s1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_mov_b32 s1, 0
	s_cbranch_vccnz .LBB4_24
; %bb.22:                               ; %.lr.ph82
	s_mul_i32 s2, s0, 0x180
	s_mul_hi_u32 s0, s0, 0x180
	s_add_u32 s2, s4, s2
	s_addc_u32 s0, s5, s0
	s_add_u32 s2, s2, 0x25000
	s_addc_u32 s3, s0, 0
	.p2align	6
.LBB4_23:                               ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v2, vcc_lo, s6, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s7, v1, vcc_lo
	global_load_d16_u8 v2, v[2:3], off
	v_add_co_u32 v3, vcc_lo, s2, v0
	v_add_co_u32 v0, s0, 0x80, v0
	v_add_co_ci_u32_e64 v4, null, s3, v1, vcc_lo
	v_add_co_ci_u32_e64 v1, null, 0, v1, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v5, 0xffffff80, v0
	v_cmp_lt_u32_e32 vcc_lo, 0xff, v5
	s_or_b32 s1, vcc_lo, s1
	s_waitcnt vmcnt(0)
	global_store_b8 v[3:4], v2, off
	s_and_not1_b32 exec_lo, exec_lo, s1
	s_cbranch_execnz .LBB4_23
.LBB4_24:                               ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi
		.amdhsa_group_segment_fixed_size 156
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 20
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
		.amdhsa_next_free_vgpr 9
		.amdhsa_next_free_sgpr 21
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
		.amdhsa_inst_pref_size 13
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end4:
	.size	_ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi, .Lfunc_end4-_ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi
                                        ; -- End function
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.num_vgpr, 9
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.num_agpr, 0
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.numbered_sgpr, 21
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.num_named_barrier, 0
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.private_seg_size, 0
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.uses_vcc, 1
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.uses_flat_scratch, 0
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.has_dyn_sized_stack, 0
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.has_recursion, 0
	.set _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 1580
; TotalNumSgprs: 23
; NumVgprs: 9
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 156 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 23
; NumVGPRsForWavesPerEU: 9
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
	.protected	_ZN6stable12finish_earlyEPNS_5CacheEi ; -- Begin function _ZN6stable12finish_earlyEPNS_5CacheEi
	.globl	_ZN6stable12finish_earlyEPNS_5CacheEi
	.p2align	8
	.type	_ZN6stable12finish_earlyEPNS_5CacheEi,@function
_ZN6stable12finish_earlyEPNS_5CacheEi:  ; @_ZN6stable12finish_earlyEPNS_5CacheEi
; %bb.0:
	v_or_b32_e32 v0, s2, v0
	s_mov_b32 s2, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_eq_u32_e32 0, v0
	s_cbranch_execz .LBB5_3
; %bb.1:
	s_clause 0x1
	s_load_b64 s[2:3], s[0:1], 0x0
	s_load_b32 s0, s[0:1], 0x8
	s_waitcnt lgkmcnt(0)
	s_load_b32 s1, s[2:3], 0x437b8
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s1, s0
	s_cbranch_scc1 .LBB5_3
; %bb.2:
	s_load_b32 s4, s[2:3], 0x437bc
	s_add_u32 s0, s2, 0x437bc
	s_addc_u32 s1, s3, 0
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s4, 0
	s_cbranch_scc0 .LBB5_4
.LBB5_3:
	s_endpgm
.LBB5_4:
	v_dual_mov_b32 v0, 0 :: v_dual_mov_b32 v1, 1
	global_store_b32 v0, v1, s[0:1]
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN6stable12finish_earlyEPNS_5CacheEi
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 12
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
		.amdhsa_next_free_vgpr 2
		.amdhsa_next_free_sgpr 5
		.amdhsa_reserve_vcc 0
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
		.amdhsa_inst_pref_size 1
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end5:
	.size	_ZN6stable12finish_earlyEPNS_5CacheEi, .Lfunc_end5-_ZN6stable12finish_earlyEPNS_5CacheEi
                                        ; -- End function
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.num_vgpr, 2
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.num_agpr, 0
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.numbered_sgpr, 5
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.num_named_barrier, 0
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.private_seg_size, 0
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.uses_vcc, 0
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.uses_flat_scratch, 0
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.has_dyn_sized_stack, 0
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.has_recursion, 0
	.set _ZN6stable12finish_earlyEPNS_5CacheEi.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 120
; TotalNumSgprs: 5
; NumVgprs: 2
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 0
; NumSGPRsForWavesPerEU: 5
; NumVGPRsForWavesPerEU: 2
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
	s_cbranch_execz .LBB6_2
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
.LBB6_2:
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
.Lfunc_end6:
	.size	_Z8finish_oPKfPf, .Lfunc_end6-_Z8finish_oPKfPf
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
	s_cbranch_execz .LBB7_39
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
	s_cbranch_execz .LBB7_11
; %bb.2:
	v_mov_b32_e32 v38, 0
	s_mov_b32 s4, exec_lo
	v_cmpx_lt_u32_e32 0x3e5, v1
	s_cbranch_execz .LBB7_10
; %bb.3:
	v_mov_b32_e32 v38, 0x7c00
	s_mov_b32 s5, exec_lo
	v_cmpx_gt_u32_e32 0x40f, v1
	s_cbranch_execz .LBB7_9
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
.LBB7_9:                                ; %Flow146
	s_or_b32 exec_lo, exec_lo, s5
.LBB7_10:                               ; %Flow148
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s4
.LBB7_11:                               ; %Flow150
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
	s_branch .LBB7_15
.LBB7_14:                               ;   in Loop: Header=BB7_15 Depth=1
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
	s_cbranch_scc0 .LBB7_39
.LBB7_15:                               ; %.preheader
                                        ; =>This Inner Loop Header: Depth=1
	s_add_i32 m0, s2, -3
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v40, v2
	s_cbranch_vccnz .LBB7_17
; %bb.16:                               ;   in Loop: Header=BB7_15 Depth=1
	global_load_b32 v39, v[34:35], off offset:-8
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v40, v40, v39
.LBB7_17:                               ;   in Loop: Header=BB7_15 Depth=1
	v_mov_b32_e32 v39, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB7_19
; %bb.18:                               ;   in Loop: Header=BB7_15 Depth=1
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
.LBB7_19:                               ;   in Loop: Header=BB7_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB7_21
; %bb.20:                               ;   in Loop: Header=BB7_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v41, v39
	v_mul_f32_e32 v41, v38, v41
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v41, v41, v37
	v_sub_f32_e32 v40, v40, v41
	global_store_b32 v[34:35], v40, off offset:-8
.LBB7_21:                               ;   in Loop: Header=BB7_15 Depth=1
	s_add_i32 m0, s2, -2
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v41, v2
	s_cbranch_vccnz .LBB7_23
; %bb.22:                               ;   in Loop: Header=BB7_15 Depth=1
	global_load_b32 v40, v[34:35], off offset:-4
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v41, v41, v40
.LBB7_23:                               ;   in Loop: Header=BB7_15 Depth=1
	v_mov_b32_e32 v40, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB7_25
; %bb.24:                               ;   in Loop: Header=BB7_15 Depth=1
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
.LBB7_25:                               ;   in Loop: Header=BB7_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB7_27
; %bb.26:                               ;   in Loop: Header=BB7_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v43, v40
	v_mul_f32_e32 v43, v38, v43
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v43, v43, v37
	v_sub_f32_e32 v41, v41, v43
	global_store_b32 v[34:35], v41, off offset:-4
.LBB7_27:                               ;   in Loop: Header=BB7_15 Depth=1
	s_add_i32 m0, s2, -1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v43, v2
	s_cbranch_vccnz .LBB7_29
; %bb.28:                               ;   in Loop: Header=BB7_15 Depth=1
	global_load_b32 v41, v[34:35], off
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v43, v43, v41
.LBB7_29:                               ;   in Loop: Header=BB7_15 Depth=1
	v_mov_b32_e32 v41, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB7_31
; %bb.30:                               ;   in Loop: Header=BB7_15 Depth=1
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
.LBB7_31:                               ;   in Loop: Header=BB7_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB7_33
; %bb.32:                               ;   in Loop: Header=BB7_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v44, v41
	v_mul_f32_e32 v44, v38, v44
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v44, v44, v37
	v_sub_f32_e32 v43, v43, v44
	global_store_b32 v[34:35], v43, off
.LBB7_33:                               ;   in Loop: Header=BB7_15 Depth=1
	s_mov_b32 m0, s2
	s_and_not1_b32 vcc_lo, exec_lo, s1
	v_movrels_b32_e32 v43, v2
	s_cbranch_vccnz .LBB7_35
; %bb.34:                               ;   in Loop: Header=BB7_15 Depth=1
	global_load_b32 v44, v[34:35], off offset:4
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v43, v43, v44
.LBB7_35:                               ;   in Loop: Header=BB7_15 Depth=1
	v_mov_b32_e32 v44, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB7_37
; %bb.36:                               ;   in Loop: Header=BB7_15 Depth=1
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
.LBB7_37:                               ;   in Loop: Header=BB7_15 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB7_14
; %bb.38:                               ;   in Loop: Header=BB7_15 Depth=1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_u32_e32 v45, v44
	v_mul_f32_e32 v45, v38, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v45, v45, v37
	v_sub_f32_e32 v43, v43, v45
	global_store_b32 v[34:35], v43, off offset:4
	s_branch .LBB7_14
.LBB7_39:                               ; %.loopexit
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
.Lfunc_end7:
	.size	_Z7flush_vPKhPhPfii, .Lfunc_end7-_Z7flush_vPKhPhPfii
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
	.section	.text._Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,"axG",@progbits,_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,comdat
	.protected	_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf ; -- Begin function _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
	.globl	_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
	.p2align	8
	.type	_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,@function
_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf: ; @_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
; %bb.0:
	s_load_b32 s22, s[0:1], 0x10
	s_cmp_gt_i32 s2, 7
	s_cselect_b32 s3, -1, 0
	s_waitcnt lgkmcnt(0)
	s_add_i32 s4, s22, 0xfffffeff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_cmp_lt_u32 s4, 0xffffff00
	s_cselect_b32 s4, -1, 0
	s_or_b32 s3, s3, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB8_3
; %bb.1:
	s_load_b64 s[18:19], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[18:19], 0x437b8
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s3, s22
	s_cbranch_scc1 .LBB8_3
; %bb.2:
	s_load_b32 s3, s[18:19], 0x437bc
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s3, 0
	s_cbranch_scc0 .LBB8_4
.LBB8_3:                                ; %.loopexit
	s_endpgm
.LBB8_4:
	s_load_b32 s3, s[18:19], 0x437c8
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s3, 0
	s_cbranch_scc1 .LBB8_3
; %bb.5:                                ; %.preheader238
	s_clause 0x1
	s_load_b128 s[12:15], s[0:1], 0x18
	s_load_b64 s[10:11], s[0:1], 0x28
	s_add_i32 s3, s22, -1
	v_lshlrev_b32_e32 v1, 7, v0
	s_ashr_i32 s0, s3, 31
	s_mul_i32 s26, s2, 0x4a00
	s_lshr_b32 s0, s0, 27
	v_lshl_add_u32 v6, v0, 2, 0x800
	s_add_i32 s28, s3, s0
	v_and_b32_e32 v7, 0xf80, v1
	s_lshr_b32 s27, s28, 5
	v_cmp_gt_u32_e64 s0, s22, v0
	s_and_not1_b32 s28, s28, 31
	s_mul_hi_i32 s25, s2, 0x4a00
	s_mulk_i32 s27, 0x600
	s_add_u32 s23, s18, s26
	s_addc_u32 s24, s19, s25
	s_ashr_i32 s29, s27, 31
	s_lshl_b32 s16, s2, 8
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB8_13
; %bb.6:
	s_mov_b32 s3, exec_lo
                                        ; implicit-def: $vgpr2
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB8_9
; %bb.7:                                ; %.preheader236
	v_subrev_nc_u32_e32 v1, s28, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_waitcnt lgkmcnt(0)
	s_add_u32 s6, s12, s4
	s_addc_u32 s7, s13, s5
	s_add_u32 s4, s18, s27
	s_addc_u32 s5, s19, s29
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s4, s4, s26
	s_addc_u32 s5, s5, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s4, v3
	v_add_co_ci_u32_e64 v4, null, s5, v4, vcc_lo
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, vcc_lo, v1, 8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB8_8:                                ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[8:11], v[3:4], off offset:-8
	s_add_u32 s8, s6, s4
	s_addc_u32 s9, s7, s5
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[8:9], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_lg_i32 s4, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v5, 0xffff0000, v8
	v_lshlrev_b32_e32 v1, 16, v8
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc1 .LBB8_8
.LBB8_9:                                ; %Flow2045
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s3, s3
	s_cbranch_execz .LBB8_12
; %bb.10:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[16:17], 2
	s_mov_b32 s8, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s6, s23, v1
	v_add_co_ci_u32_e64 v3, null, s24, 0, s6
	s_waitcnt lgkmcnt(0)
	s_add_u32 s6, s12, s4
	s_addc_u32 s7, s13, s5
	s_mov_b64 s[4:5], 0
.LBB8_11:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s8, v7
	s_add_u32 s20, s6, s4
	s_addc_u32 s21, s7, s5
	s_add_i32 s8, s8, 4
	s_load_b128 s[36:39], s[20:21], 0x0
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	v_add_co_u32 v8, vcc_lo, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s5, v3, vcc_lo
	global_load_d16_u8 v4, v[4:5], off
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	global_load_b128 v[8:11], v[8:9], off offset:1024
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s36, v8
	v_fma_mix_f32 v8, v9, v12, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v5, v10, v5, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s37, v8
	v_fmac_f32_e32 v2, s38, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB8_11
.LBB8_12:                               ; %Flow2046
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1
.LBB8_13:                               ; %Flow2047
	s_or_b32 exec_lo, exec_lo, s1
	v_add_nc_u32_e32 v9, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_u32_e64 s1, s22, v9
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB8_21
; %bb.14:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s4, exec_lo
	v_cmpx_le_i32_e64 s28, v9
	s_xor_b32 s6, exec_lo, s4
	s_cbranch_execz .LBB8_17
; %bb.15:                               ; %.preheader236.1
	v_subrev_nc_u32_e32 v1, s28, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_waitcnt lgkmcnt(0)
	s_add_u32 s7, s12, s4
	s_addc_u32 s8, s13, s5
	s_add_u32 s4, s18, s27
	s_addc_u32 s5, s19, s29
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s4, s4, s26
	s_addc_u32 s5, s5, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s4, v3
	v_add_co_ci_u32_e64 v4, null, s5, v4, vcc_lo
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, vcc_lo, v1, 8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB8_16:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[10:13], v[3:4], off offset:-8
	s_add_u32 s20, s7, s4
	s_addc_u32 s21, s8, s5
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[20:21], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v5, 0xffff0000, v10
	v_lshlrev_b32_e32 v1, 16, v10
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc0 .LBB8_16
.LBB8_17:                               ; %Flow2040
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s6, s6
	s_cbranch_execz .LBB8_20
; %bb.18:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[16:17], 2
	s_mov_b32 s9, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s7, s23, v1
	v_add_co_ci_u32_e64 v3, null, s24, 0, s7
	s_waitcnt lgkmcnt(0)
	s_add_u32 s7, s12, s4
	s_addc_u32 s8, s13, s5
	s_mov_b64 s[4:5], 0
.LBB8_19:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s9, v7
	s_add_u32 s20, s7, s4
	s_addc_u32 s21, s8, s5
	s_add_i32 s9, s9, 4
	s_load_b128 s[36:39], s[20:21], 0x0
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	v_add_co_u32 v10, vcc_lo, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s5, v3, vcc_lo
	global_load_d16_u8 v4, v[4:5], off
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	global_load_b128 v[10:13], v[10:11], off offset:1024
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s36, v8
	v_fma_mix_f32 v8, v11, v10, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v5, v12, v5, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s37, v8
	v_fmac_f32_e32 v2, s38, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB8_19
.LBB8_20:                               ; %Flow2041
	s_or_b32 exec_lo, exec_lo, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:512
.LBB8_21:                               ; %Flow2042
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB8_23
; %bb.22:
	ds_load_b32 v1, v6
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB8_23:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB8_25
; %bb.24:
	ds_load_b32 v2, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB8_25:
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
	s_cbranch_execz .LBB8_27
; %bb.26:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_27:
	s_or_b32 exec_lo, exec_lo, s4
	v_cmp_gt_u32_e64 s4, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB8_29
; %bb.28:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_29:
	s_or_b32 exec_lo, exec_lo, s5
	v_cmp_gt_u32_e64 s5, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s5
	s_cbranch_execz .LBB8_31
; %bb.30:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_31:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB8_33
; %bb.32:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_33:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB8_35
; %bb.34:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_35:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_gt_u32_e64 s8, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB8_37
; %bb.36:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_37:
	s_or_b32 exec_lo, exec_lo, s9
	v_cmp_eq_u32_e64 s9, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s9
	s_cbranch_execz .LBB8_39
; %bb.38:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_39:
	s_or_b32 exec_lo, exec_lo, s17
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s17, s0
	s_cbranch_execz .LBB8_41
; %bb.40:
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
.LBB8_41:
	s_or_b32 exec_lo, exec_lo, s17
	s_and_saveexec_b32 s17, s1
	s_cbranch_execz .LBB8_43
; %bb.42:
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
.LBB8_43:
	s_or_b32 exec_lo, exec_lo, s17
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s3
	s_cbranch_execz .LBB8_45
; %bb.44:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_45:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s4
	s_cbranch_execz .LBB8_47
; %bb.46:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_47:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s5
	s_cbranch_execz .LBB8_49
; %bb.48:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_49:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s6
	s_cbranch_execz .LBB8_51
; %bb.50:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_51:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s7
	s_cbranch_execz .LBB8_53
; %bb.52:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_53:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s8
	s_cbranch_execz .LBB8_55
; %bb.54:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_55:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s9
	s_cbranch_execz .LBB8_57
; %bb.56:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_57:
	s_or_b32 exec_lo, exec_lo, s17
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s17, s0
	s_cbranch_execz .LBB8_59
; %bb.58:
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
.LBB8_59:
	s_or_b32 exec_lo, exec_lo, s17
	s_and_saveexec_b32 s17, s1
	s_cbranch_execz .LBB8_61
; %bb.60:
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
.LBB8_61:                               ; %.preheader238.1
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s30, s0
	s_cbranch_execz .LBB8_69
; %bb.62:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s17, exec_lo
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s31, exec_lo, s17
	s_cbranch_execz .LBB8_65
; %bb.63:                               ; %.preheader236.1278
	v_subrev_nc_u32_e32 v1, s28, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[20:21], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s17, s12, s20
	s_addc_u32 s33, s13, s21
	s_add_u32 s20, s18, s27
	s_addc_u32 s21, s19, s29
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s20, s20, s26
	s_addc_u32 s21, s21, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s20, v3
	v_add_co_ci_u32_e64 v4, null, s21, v4, vcc_lo
	s_mov_b64 s[20:21], 0
	v_add_co_u32 v3, vcc_lo, v1, 14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB8_64:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[10:13], v[3:4], off offset:-14
	s_add_u32 s34, s17, s20
	s_addc_u32 s35, s33, s21
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[34:35], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s20, s20, 32
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v1, 16, v10
	v_and_b32_e32 v10, 0xffff0000, v10
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc0 .LBB8_64
.LBB8_65:                               ; %Flow2035
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s31, s31
	s_cbranch_execz .LBB8_68
; %bb.66:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[20:21], s[16:17], 2
	s_mov_b32 s34, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s17, s23, v1
	v_add_co_ci_u32_e64 v3, null, s24, 0, s17
	s_add_u32 s17, s12, s20
	s_addc_u32 s33, s13, s21
	s_mov_b64 s[20:21], 0
.LBB8_67:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s34, v7
	s_add_u32 s36, s17, s20
	s_addc_u32 s37, s33, s21
	s_add_i32 s34, s34, 4
	s_load_b128 s[36:39], s[36:37], 0x200
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v11, null, 0, v3, vcc_lo
	global_load_d16_u8 v4, v[10:11], off
	v_add_co_u32 v10, vcc_lo, v1, s20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s21, v3, vcc_lo
	s_add_u32 s20, s20, 16
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	global_load_b128 v[10:13], v[10:11], off offset:1024
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s36, v10
	v_fma_mix_f32 v10, v11, v15, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v11, v12, v14, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s37, v10
	v_fmac_f32_e32 v2, s38, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB8_67
.LBB8_68:                               ; %Flow2036
	s_or_b32 exec_lo, exec_lo, s31
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1024
.LBB8_69:                               ; %Flow2037
	s_or_b32 exec_lo, exec_lo, s30
	s_and_saveexec_b32 s30, s1
	s_cbranch_execz .LBB8_78
; %bb.70:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s17, exec_lo
	v_cmpx_le_i32_e64 s28, v9
	s_xor_b32 s31, exec_lo, s17
	s_cbranch_execz .LBB8_74
; %bb.71:                               ; %.preheader236.1.1
	v_subrev_nc_u32_e32 v1, s28, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[20:21], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s17, s12, s20
	s_addc_u32 s28, s13, s21
	s_add_u32 s20, s18, s27
	s_addc_u32 s21, s19, s29
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s20, s20, s26
	s_addc_u32 s21, s21, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s20, v3
	v_add_co_ci_u32_e64 v4, null, s21, v4, vcc_lo
	s_mov_b64 s[20:21], 0
	v_add_co_u32 v3, vcc_lo, v1, 14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB8_72:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[9:12], v[3:4], off offset:-14
	s_add_u32 s26, s17, s20
	s_addc_u32 s27, s28, s21
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[26:27], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s20, s20, 32
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v1, 16, v9
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc0 .LBB8_72
; %bb.73:                               ; %Flow2028
	s_set_inst_prefetch_distance 0x2
                                        ; implicit-def: $vgpr7
                                        ; implicit-def: $vgpr9
.LBB8_74:                               ; %Flow2030
	s_and_not1_saveexec_b32 s20, s31
	s_cbranch_execz .LBB8_77
; %bb.75:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[26:27], s[16:17], 2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_u32_u24_e32 v1, 0x600, v1
	v_add_co_u32 v1, s17, s23, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s24, 0, s17
	s_add_u32 s17, s12, s26
	s_addc_u32 s21, s13, s27
	s_mov_b32 s23, 0
	s_mov_b64 s[12:13], 0
.LBB8_76:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s23, v7
	s_add_u32 s24, s17, s12
	s_addc_u32 s25, s21, s13
	s_add_i32 s23, s23, 4
	s_load_b128 s[24:27], s[24:25], 0x200
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v10, null, 0, v3, vcc_lo
	global_load_d16_u8 v4, v[9:10], off
	v_add_co_u32 v9, vcc_lo, v1, s12
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s13, v3, vcc_lo
	s_add_u32 s12, s12, 16
	s_addc_u32 s13, s13, 0
	s_cmpk_eq_i32 s12, 0x200
	global_load_b128 v[9:12], v[9:10], off offset:1024
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s24, v9
	v_fma_mix_f32 v9, v10, v14, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v10, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s25, v9
	v_fmac_f32_e32 v2, s26, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s27, v4
	s_cbranch_scc0 .LBB8_76
.LBB8_77:                               ; %Flow2031
	s_or_b32 exec_lo, exec_lo, s20
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1536
.LBB8_78:                               ; %Flow2032
	s_or_b32 exec_lo, exec_lo, s30
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB8_80
; %bb.79:
	ds_load_b32 v1, v6 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB8_80:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB8_82
; %bb.81:
	ds_load_b32 v2, v6 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB8_82:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB8_84
; %bb.83:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_84:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s4
	s_cbranch_execz .LBB8_86
; %bb.85:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_86:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s5
	s_cbranch_execz .LBB8_88
; %bb.87:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_88:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s6
	s_cbranch_execz .LBB8_90
; %bb.89:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_90:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s7
	s_cbranch_execz .LBB8_92
; %bb.91:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_92:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s8
	s_cbranch_execz .LBB8_94
; %bb.93:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_94:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s9
	s_cbranch_execz .LBB8_96
; %bb.95:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB8_96:
	s_or_b32 exec_lo, exec_lo, s12
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB8_98
; %bb.97:
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
.LBB8_98:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB8_100
; %bb.99:
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
.LBB8_100:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB8_102
; %bb.101:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_102:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s4
	s_cbranch_execz .LBB8_104
; %bb.103:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_104:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s5
	s_cbranch_execz .LBB8_106
; %bb.105:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_106:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s6
	s_cbranch_execz .LBB8_108
; %bb.107:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_108:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s7
	s_cbranch_execz .LBB8_110
; %bb.109:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_110:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s8
	s_cbranch_execz .LBB8_112
; %bb.111:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_112:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s9
	s_cbranch_execz .LBB8_114
; %bb.113:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB8_114:
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB8_116
; %bb.115:
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
.LBB8_116:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB8_118
; %bb.117:
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
.LBB8_118:                              ; %.preheader234
	s_or_b32 exec_lo, exec_lo, s0
	s_max_i32 s4, s22, 33
	v_lshlrev_b32_e32 v6, 1, v0
	s_sub_i32 s3, s4, 33
	v_lshrrev_b32_e32 v3, 3, v0
	s_cmp_gt_u32 s22, 33
	s_mul_i32 s0, s2, 48
	s_cselect_b32 s7, -1, 0
	s_ashr_i32 s1, s0, 31
	s_add_u32 s0, s18, s0
	s_addc_u32 s1, s19, s1
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 2, v0
	v_dual_mov_b32 v4, 0 :: v_dual_and_b32 v3, 0x7c, v3
	v_and_b32_e32 v2, 6, v6
	s_add_u32 s5, s0, 0x25000
	s_addc_u32 s6, s1, 0
	s_cmp_lt_u32 s22, 34
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB8_126
; %bb.119:                              ; %.lr.ph.preheader
	v_mov_b32_e32 v4, 0
	s_sub_i32 s0, s4, 34
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lt_u32 s0, 3
	s_cbranch_scc1 .LBB8_122
; %bb.120:                              ; %.lr.ph.preheader.new
	v_mov_b32_e32 v7, 0x43000
	s_and_b32 s8, s3, -4
	s_mov_b32 s9, 0
	s_mov_b64 s[0:1], 0
.LBB8_121:                              ; %.lr.ph
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s12, s18, s0
	s_addc_u32 s13, s19, s1
	s_add_u32 s0, s0, 4
	global_load_b32 v8, v7, s[12:13] offset:1536
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
	v_add_co_u32 v12, s12, s5, v9
	v_add_co_ci_u32_e64 v13, null, s6, 0, s12
	v_add_co_u32 v14, s12, s5, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, s6, 0, s12
	v_add_co_u32 v18, s12, s5, v8
	v_add_co_u32 v8, vcc_lo, v12, v1
	v_add_co_ci_u32_e64 v9, null, 0, v13, vcc_lo
	v_add_co_ci_u32_e64 v19, null, s6, 0, s12
	v_add_co_u32 v20, s12, s5, v10
	v_add_co_u32 v10, vcc_lo, v12, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, 0, v13, vcc_lo
	v_add_co_u32 v12, vcc_lo, v14, v1
	v_add_co_ci_u32_e64 v13, null, 0, v15, vcc_lo
	global_load_u8 v22, v[8:9], off
	v_add_co_u32 v14, vcc_lo, v14, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v15, null, 0, v15, vcc_lo
	v_add_co_u32 v16, vcc_lo, v18, v1
	global_load_u8 v12, v[12:13], off
	v_add_co_ci_u32_e64 v21, null, s6, 0, s12
	v_add_co_ci_u32_e64 v17, null, 0, v19, vcc_lo
	v_add_co_u32 v18, vcc_lo, v18, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v19, null, 0, v19, vcc_lo
	v_add_co_u32 v8, vcc_lo, v20, v1
	v_add_co_ci_u32_e64 v9, null, 0, v21, vcc_lo
	s_clause 0x4
	global_load_u8 v13, v[16:17], off
	global_load_b32 v16, v[10:11], off offset:32
	global_load_b32 v14, v[14:15], off offset:32
	global_load_u8 v15, v[8:9], off
	global_load_b32 v17, v[18:19], off offset:32
	v_add_co_u32 v8, vcc_lo, v20, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, 0, v21, vcc_lo
	global_load_b32 v18, v[8:9], off offset:32
	v_mov_b32_e32 v8, s9
	s_add_i32 s9, s9, 16
	s_cmp_eq_u32 s8, s0
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
	v_fmac_f32_e32 v4, v8, v16
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v8, v15
	s_waitcnt vmcnt(1)
	v_fma_mix_f32 v13, v17, v13, v17 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v4, v9, v12
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v18, v8, v18 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v10, v13
	v_fmac_f32_e32 v4, v11, v8
	s_cbranch_scc0 .LBB8_121
	s_branch .LBB8_123
.LBB8_122:
	s_mov_b32 s0, 0
.LBB8_123:                              ; %.preheader232.loopexit.unr-lcssa
	s_and_b32 s8, s3, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s8, 0
	s_cbranch_scc1 .LBB8_126
; %bb.124:                              ; %.lr.ph.epil.preheader
	s_lshl_b32 s9, s0, 2
	s_add_u32 s0, s18, s0
	v_mov_b32_e32 v7, 0
	s_addc_u32 s1, s19, 0
	s_add_u32 s0, s0, 0x43600
	s_addc_u32 s1, s1, 0
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB8_125:                              ; %.lr.ph.epil
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v8, v7, s[0:1]
	s_waitcnt vmcnt(0)
	v_mul_lo_u32 v8, 0x180, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, s12, s5, v8
	v_add_co_ci_u32_e64 v11, null, s6, 0, s12
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, v10, v1
	v_add_co_ci_u32_e64 v9, null, 0, v11, vcc_lo
	global_load_u8 v12, v[8:9], off
	v_add_co_u32 v8, vcc_lo, v10, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, 0, v11, vcc_lo
	global_load_b32 v8, v[8:9], off offset:32
	v_mov_b32_e32 v9, s9
	s_add_i32 s9, s9, 4
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_add_i32 s8, s8, -1
	ds_load_b32 v9, v9
	s_cmp_lg_u32 s8, 0
	s_waitcnt vmcnt(1)
	v_bfe_u32 v10, v12, v2, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v10, v10
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v8, v8, v10, v8 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v9, v8
	s_cbranch_scc1 .LBB8_125
.LBB8_126:                              ; %.preheader232
	s_set_inst_prefetch_distance 0x2
	s_sub_i32 s8, s22, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_gt_i32 s8, 0
	s_cselect_b32 s13, -1, 0
	s_add_u32 s9, s18, 0x436e0
	s_addc_u32 s12, s19, 0
	s_ashr_i32 s17, s16, 31
	s_add_u32 s0, s18, s16
	s_addc_u32 s1, s19, s17
	v_add_co_u32 v6, s0, s0, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v7, null, s1, 0, s0
	s_cmp_lt_i32 s8, 1
	v_add_co_u32 v6, vcc_lo, 0x32e00, v6
	v_add_co_ci_u32_e64 v7, null, 0, v7, vcc_lo
	s_mov_b32 s0, 0
	s_cbranch_scc1 .LBB8_133
; %bb.127:                              ; %.lr.ph258.preheader
	s_sub_i32 s1, s22, s4
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s1, s1, 32
	s_cmp_lt_u32 s1, 7
	s_cbranch_scc1 .LBB8_130
; %bb.128:                              ; %.lr.ph258.preheader.new
	v_mov_b32_e32 v8, 0
	s_lshl_b32 s1, s4, 2
	s_and_b32 s0, s8, 0x7ffffff8
	s_addk_i32 s1, 0xff7c
	s_mov_b32 s20, 0
.LBB8_129:                              ; %.lr.ph258
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s21, s4, s20
	s_sub_i32 s22, s21, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_hi_i32 s23, s22, 0x3e0f83e1
	s_lshr_b32 s24, s23, 31
	s_ashr_i32 s23, s23, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s23, s23, s24
	s_mul_i32 s23, s23, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s22, s22, s23
	s_ashr_i32 s23, s22, 31
	s_add_u32 s22, s9, s22
	s_addc_u32 s23, s12, s23
	s_sub_i32 s24, s21, 32
	global_load_u8 v9, v8, s[22:23]
	s_mul_hi_i32 s25, s24, 0x3e0f83e1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s22, s25, 31
	s_ashr_i32 s23, s25, 3
	s_add_i32 s22, s23, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s22, s22, 33
	s_sub_i32 s22, s24, s22
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s23, s22, 31
	s_add_u32 s22, s9, s22
	s_addc_u32 s23, s12, s23
	s_sub_i32 s24, s21, 31
	global_load_u8 v11, v8, s[22:23]
	s_mul_hi_i32 s25, s24, 0x3e0f83e1
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v9, 11, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	global_load_u16 v18, v[9:10], off
	s_lshr_b32 s22, s25, 31
	s_ashr_i32 s23, s25, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_add_i32 s22, s23, s22
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v9, 11, v11
	s_mul_i32 s22, s22, 33
	s_sub_i32 s22, s24, s22
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	s_ashr_i32 s23, s22, 31
	s_add_u32 s22, s9, s22
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	s_addc_u32 s23, s12, s23
	s_sub_i32 s24, s21, 30
	s_clause 0x1
	global_load_u8 v12, v8, s[22:23]
	global_load_u16 v19, v[9:10], off
	s_mul_hi_i32 s25, s24, 0x3e0f83e1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s22, s25, 31
	s_ashr_i32 s23, s25, 3
	s_add_i32 s22, s23, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s22, s22, 33
	s_sub_i32 s22, s24, s22
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s23, s22, 31
	s_add_u32 s22, s9, s22
	s_addc_u32 s23, s12, s23
	s_sub_i32 s24, s21, 29
	global_load_u8 v13, v8, s[22:23]
	s_mul_hi_i32 s25, s24, 0x3e0f83e1
	s_waitcnt vmcnt(3)
	v_lshlrev_b32_e32 v18, 16, v18
	s_waitcnt vmcnt(2)
	v_lshlrev_b32_e32 v9, 11, v12
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	global_load_u16 v20, v[9:10], off
	s_lshr_b32 s22, s25, 31
	s_ashr_i32 s23, s25, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(SALU_CYCLE_1)
	s_add_i32 s22, s23, s22
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v9, 11, v13
	s_mul_i32 s22, s22, 33
	s_sub_i32 s22, s24, s22
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	s_ashr_i32 s23, s22, 31
	s_add_u32 s22, s9, s22
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	s_addc_u32 s23, s12, s23
	s_sub_i32 s24, s21, 28
	s_clause 0x1
	global_load_u8 v14, v8, s[22:23]
	global_load_u16 v21, v[9:10], off
	s_mul_hi_i32 s25, s24, 0x3e0f83e1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s22, s25, 31
	s_ashr_i32 s23, s25, 3
	s_add_i32 s22, s23, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s22, s22, 33
	s_sub_i32 s22, s24, s22
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s23, s22, 31
	s_add_u32 s22, s9, s22
	s_addc_u32 s23, s12, s23
	s_sub_i32 s24, s21, 27
	global_load_u8 v15, v8, s[22:23]
	s_mul_hi_i32 s25, s24, 0x3e0f83e1
	s_waitcnt vmcnt(2)
	v_lshlrev_b32_e32 v9, 11, v14
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	global_load_u16 v22, v[9:10], off
	s_lshr_b32 s22, s25, 31
	s_ashr_i32 s23, s25, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_i32 s22, s23, s22
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v9, 11, v15
	s_mul_i32 s22, s22, 33
	v_mov_b32_e32 v15, s1
	s_sub_i32 s22, s24, s22
	s_delay_alu instid0(VALU_DEP_2)
	v_add_co_u32 v9, vcc_lo, v6, v9
	s_ashr_i32 s23, s22, 31
	s_add_u32 s22, s9, s22
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	s_addc_u32 s23, s12, s23
	s_sub_i32 s21, s21, 26
	s_clause 0x1
	global_load_u8 v16, v8, s[22:23]
	global_load_u16 v23, v[9:10], off
	s_mul_hi_i32 s24, s21, 0x3e0f83e1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s22, s24, 31
	s_ashr_i32 s23, s24, 3
	s_add_i32 s22, s23, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s22, s22, 33
	s_sub_i32 s21, s21, s22
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s23, s21, 31
	s_add_u32 s22, s9, s21
	s_addc_u32 s23, s12, s23
	s_add_i32 s20, s20, 8
	global_load_u8 v17, v8, s[22:23]
	s_add_i32 s1, s1, 32
	s_cmp_eq_u32 s0, s20
	s_waitcnt vmcnt(2)
	v_lshlrev_b32_e32 v9, 11, v16
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v11, 11, v17
	global_load_u16 v17, v[9:10], off
	v_add_co_u32 v9, vcc_lo, v6, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	global_load_u16 v24, v[9:10], off
	ds_load_2addr_b32 v[9:10], v15 offset1:1
	ds_load_2addr_b32 v[11:12], v15 offset0:2 offset1:3
	ds_load_2addr_b32 v[13:14], v15 offset0:4 offset1:5
	ds_load_2addr_b32 v[15:16], v15 offset0:6 offset1:7
	s_waitcnt lgkmcnt(3)
	v_dual_fmac_f32 v4, v9, v18 :: v_dual_lshlrev_b32 v9, 16, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v10, v9 :: v_dual_lshlrev_b32 v9, 16, v20
	s_waitcnt lgkmcnt(2)
	v_fmac_f32_e32 v4, v11, v9
	v_lshlrev_b32_e32 v9, 16, v21
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v4, v12, v9 :: v_dual_lshlrev_b32 v9, 16, v22
	s_waitcnt lgkmcnt(1)
	v_dual_fmac_f32 v4, v13, v9 :: v_dual_lshlrev_b32 v9, 16, v23
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v4, v14, v9
	s_waitcnt vmcnt(1)
	v_lshlrev_b32_e32 v9, 16, v17
	s_waitcnt vmcnt(0) lgkmcnt(0)
	v_dual_fmac_f32 v4, v15, v9 :: v_dual_lshlrev_b32 v9, 16, v24
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v16, v9
	s_cbranch_scc0 .LBB8_129
.LBB8_130:                              ; %._crit_edge.loopexit.unr-lcssa
	s_and_b32 s1, s8, 7
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc1 .LBB8_133
; %bb.131:                              ; %.lr.ph258.epil.preheader
	s_add_i32 s20, s0, s4
	v_mov_b32_e32 v8, 0
	s_lshl_b32 s0, s20, 2
	s_sub_i32 s20, s20, 33
	s_addk_i32 s0, 0xff7c
	.p2align	6
.LBB8_132:                              ; %.lr.ph258.epil
                                        ; =>This Inner Loop Header: Depth=1
	s_mul_hi_i32 s21, s20, 0x3e0f83e1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s22, s21, 31
	s_ashr_i32 s21, s21, 3
	s_add_i32 s21, s21, s22
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s21, s21, 33
	s_sub_i32 s21, s20, s21
	s_delay_alu instid0(SALU_CYCLE_1)
	s_ashr_i32 s23, s21, 31
	s_add_u32 s22, s9, s21
	s_addc_u32 s23, s12, s23
	s_add_i32 s1, s1, -1
	global_load_u8 v9, v8, s[22:23]
	s_add_i32 s20, s20, 1
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v9, 11, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v6, v9
	v_add_co_ci_u32_e64 v10, null, 0, v7, vcc_lo
	global_load_u16 v9, v[9:10], off
	v_mov_b32_e32 v10, s0
	s_add_i32 s0, s0, 4
	s_cmp_lg_u32 s1, 0
	ds_load_b32 v10, v10
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v9, 16, v9
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, v10, v9
	s_cbranch_scc1 .LBB8_132
.LBB8_133:                              ; %._crit_edge
	v_mov_b32_e32 v8, 0
	s_and_not1_b32 vcc_lo, exec_lo, s7
	ds_store_b32 v5, v4 offset:4096
	s_cbranch_vccnz .LBB8_136
; %bb.134:                              ; %.lr.ph.1.preheader
	v_mov_b32_e32 v4, 0
	v_mov_b32_e32 v8, 0
	s_add_u32 s0, s18, 0x43600
	s_addc_u32 s1, s19, 0
	s_movk_i32 s7, 0x400
	s_mov_b32 s18, s3
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB8_135:                              ; %.lr.ph.1
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v9, v4, s[0:1]
	s_add_i32 s18, s18, -1
	s_waitcnt vmcnt(0)
	v_mul_lo_u32 v9, 0x180, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, s19, s5, v9
	v_add_co_ci_u32_e64 v12, null, s6, 0, s19
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v11, v1
	v_add_co_ci_u32_e64 v10, null, 0, v12, vcc_lo
	global_load_u8 v13, v[9:10], off
	v_add_co_u32 v9, vcc_lo, v11, v3
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, 0, v12, vcc_lo
	global_load_b32 v9, v[9:10], off offset:32
	v_mov_b32_e32 v10, s7
	s_add_i32 s7, s7, 4
	s_add_u32 s0, s0, 1
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s18, 0
	ds_load_b32 v10, v10
	s_waitcnt vmcnt(1)
	v_bfe_u32 v11, v13, v2, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v11, v11
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v9, v9, v11, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, v10, v9
	s_cbranch_scc1 .LBB8_135
.LBB8_136:                              ; %Flow2017
	s_set_inst_prefetch_distance 0x2
	v_or_b32_e32 v1, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s13
	s_cbranch_vccnz .LBB8_139
; %bb.137:                              ; %.lr.ph258.1.preheader
	v_mov_b32_e32 v2, 0
	s_lshl_b32 s0, s4, 2
	s_mov_b32 s1, 0
	s_addk_i32 s0, 0x37c
	.p2align	6
.LBB8_138:                              ; %.lr.ph258.1
                                        ; =>This Inner Loop Header: Depth=1
	s_add_i32 s4, s3, s1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_hi_i32 s5, s4, 0x3e0f83e1
	s_lshr_b32 s6, s5, 31
	s_ashr_i32 s5, s5, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s5, s5, s6
	s_mul_i32 s5, s5, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s4, s4, s5
	s_ashr_i32 s5, s4, 31
	s_add_u32 s4, s9, s4
	s_addc_u32 s5, s12, s5
	s_add_i32 s1, s1, 1
	global_load_u8 v3, v2, s[4:5]
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v3, 11, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v3, vcc_lo, v6, v3
	v_add_co_ci_u32_e64 v4, null, 0, v7, vcc_lo
	global_load_u16 v3, v[3:4], off
	v_mov_b32_e32 v4, s0
	s_add_i32 s0, s0, 4
	s_cmp_lt_i32 s1, s8
	ds_load_b32 v4, v4
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v3, 16, v3
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v8, v4, v3
	s_cbranch_scc1 .LBB8_138
.LBB8_139:                              ; %._crit_edge.1
	v_lshlrev_b32_e32 v2, 12, v0
	ds_store_b32 v1, v8 offset:512
	v_mov_b32_e32 v1, 0
	s_mov_b64 s[4:5], 0
	s_movk_i32 s3, 0x1000
	v_add_co_u32 v3, s0, s14, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s15, 0, s0
	s_lshl_b64 s[0:1], s[16:17], 1
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v3, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v4, null, s1, v4, vcc_lo
	s_barrier
	buffer_gl0_inv
.LBB8_140:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB8_140
; %bb.141:                              ; %.preheader.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[4:5], 0
.LBB8_142:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_142
; %bb.143:                              ; %.preheader.1298
	s_lshl_b32 s2, s2, 10
	s_add_u32 s0, s14, s0
	v_or_b32_e32 v3, s2, v0
	s_addc_u32 s1, s15, s1
	v_add_co_u32 v2, s0, s0, v2
	s_movk_i32 s3, 0x1000
	v_ashrrev_i32_e32 v4, 31, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], 2, v[3:4]
	v_mov_b32_e32 v4, 0
	v_add_co_ci_u32_e64 v3, null, s1, 0, s0
	s_mov_b64 s[0:1], 0
	v_add_co_u32 v5, vcc_lo, s10, v5
	v_add_co_ci_u32_e64 v6, null, s11, v6, vcc_lo
	global_store_b32 v[5:6], v1, off
.LBB8_144:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_144
; %bb.145:                              ; %.preheader.1.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[0:1], 0
.LBB8_146:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_146
; %bb.147:                              ; %.preheader.2
	s_ashr_i32 s0, s2, 31
	v_add_co_u32 v0, s1, v0, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v1, null, 0, s0, s1
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s10, v0
	v_add_co_ci_u32_e64 v1, null, s11, v1, vcc_lo
	global_store_b32 v[0:1], v4, off offset:512
.LBB8_148:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_148
; %bb.149:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB8_150:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_150
; %bb.151:                              ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:1024
.LBB8_152:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_152
; %bb.153:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB8_154:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_154
; %bb.155:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:1536
.LBB8_156:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_156
; %bb.157:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB8_158:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_158
; %bb.159:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:2048
.LBB8_160:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_160
; %bb.161:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB8_162:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_162
; %bb.163:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:2560
.LBB8_164:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_164
; %bb.165:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB8_166:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_166
; %bb.167:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:3072
.LBB8_168:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_168
; %bb.169:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB8_170:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB8_170
; %bb.171:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
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
		.amdhsa_next_free_vgpr 25
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
	.section	.text._Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,"axG",@progbits,_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,comdat
.Lfunc_end8:
	.size	_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf, .Lfunc_end8-_Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
                                        ; -- End function
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.num_vgpr, 25
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.num_agpr, 0
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.numbered_sgpr, 44
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.num_named_barrier, 0
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.private_seg_size, 0
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.uses_vcc, 1
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.uses_flat_scratch, 0
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.has_dyn_sized_stack, 0
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.has_recursion, 0
	.set _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 14216
; TotalNumSgprs: 46
; NumVgprs: 25
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 5632 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 3
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 25
; Occupancy: 16
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,"axG",@progbits,_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,comdat
	.protected	_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf ; -- Begin function _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
	.globl	_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
	.p2align	8
	.type	_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,@function
_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf: ; @_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
; %bb.0:
	s_load_b32 s22, s[0:1], 0x10
	s_cmp_gt_i32 s2, 7
	s_cselect_b32 s3, -1, 0
	s_waitcnt lgkmcnt(0)
	s_add_i32 s4, s22, 0xfffffeff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_cmp_lt_u32 s4, 0xffffff00
	s_cselect_b32 s4, -1, 0
	s_or_b32 s3, s3, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB9_168
; %bb.1:                                ; %.preheader229
	s_clause 0x2
	s_load_b64 s[18:19], s[0:1], 0x8
	s_load_b128 s[12:15], s[0:1], 0x18
	s_load_b64 s[10:11], s[0:1], 0x28
	s_add_i32 s1, s22, -1
	v_lshlrev_b32_e32 v1, 7, v0
	s_ashr_i32 s3, s1, 31
	s_mul_i32 s26, s2, 0x4a00
	s_lshr_b32 s3, s3, 27
	v_cmp_gt_u32_e64 s0, s22, v0
	s_add_i32 s29, s1, s3
	v_lshl_add_u32 v6, v0, 2, 0x800
	s_lshr_b32 s27, s29, 5
	v_and_b32_e32 v7, 0xf80, v1
	s_mul_hi_i32 s25, s2, 0x4a00
	s_and_not1_b32 s29, s29, 31
	s_mulk_i32 s27, 0x600
	s_waitcnt lgkmcnt(0)
	s_add_u32 s23, s18, s26
	s_addc_u32 s24, s19, s25
	s_ashr_i32 s28, s27, 31
	s_lshl_b32 s16, s2, 8
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB9_9
; %bb.2:
	s_mov_b32 s3, exec_lo
                                        ; implicit-def: $vgpr2
	v_cmpx_le_i32_e64 s29, v0
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB9_5
; %bb.3:                                ; %.preheader227
	v_subrev_nc_u32_e32 v1, s29, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s6, s12, s4
	s_addc_u32 s7, s13, s5
	s_add_u32 s4, s18, s27
	s_addc_u32 s5, s19, s28
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s4, s4, s26
	s_addc_u32 s5, s5, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s4, v3
	v_add_co_ci_u32_e64 v4, null, s5, v4, vcc_lo
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, vcc_lo, v1, 8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB9_4:                                ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[8:11], v[3:4], off offset:-8
	s_add_u32 s8, s6, s4
	s_addc_u32 s9, s7, s5
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[8:9], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_lg_i32 s4, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v5, 0xffff0000, v8
	v_lshlrev_b32_e32 v1, 16, v8
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc1 .LBB9_4
.LBB9_5:                                ; %Flow2054
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s3, s3
	s_cbranch_execz .LBB9_8
; %bb.6:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[16:17], 2
	s_mov_b32 s8, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s6, s23, v1
	v_add_co_ci_u32_e64 v3, null, s24, 0, s6
	s_add_u32 s6, s12, s4
	s_addc_u32 s7, s13, s5
	s_mov_b64 s[4:5], 0
.LBB9_7:                                ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s8, v7
	s_add_u32 s20, s6, s4
	s_addc_u32 s21, s7, s5
	s_add_i32 s8, s8, 4
	s_load_b128 s[36:39], s[20:21], 0x0
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	v_add_co_u32 v8, vcc_lo, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v9, null, s5, v3, vcc_lo
	global_load_d16_u8 v4, v[4:5], off
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	global_load_b128 v[8:11], v[8:9], off offset:1024
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s36, v8
	v_fma_mix_f32 v8, v9, v12, v9 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v5, v10, v5, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s37, v8
	v_fmac_f32_e32 v2, s38, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB9_7
.LBB9_8:                                ; %Flow2055
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1
.LBB9_9:                                ; %Flow2056
	s_or_b32 exec_lo, exec_lo, s1
	v_add_nc_u32_e32 v9, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_u32_e64 s1, s22, v9
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB9_17
; %bb.10:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s4, exec_lo
	v_cmpx_le_i32_e64 s29, v9
	s_xor_b32 s6, exec_lo, s4
	s_cbranch_execz .LBB9_13
; %bb.11:                               ; %.preheader227.1
	v_subrev_nc_u32_e32 v1, s29, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s7, s12, s4
	s_addc_u32 s8, s13, s5
	s_add_u32 s4, s18, s27
	s_addc_u32 s5, s19, s28
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s4, s4, s26
	s_addc_u32 s5, s5, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s4, v3
	v_add_co_ci_u32_e64 v4, null, s5, v4, vcc_lo
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, vcc_lo, v1, 8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB9_12:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[10:13], v[3:4], off offset:-8
	s_add_u32 s20, s7, s4
	s_addc_u32 s21, s8, s5
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[20:21], 0x0
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s4, s4, 32
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v5, 0xffff0000, v10
	v_lshlrev_b32_e32 v1, 16, v10
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc0 .LBB9_12
.LBB9_13:                               ; %Flow2049
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s6, s6
	s_cbranch_execz .LBB9_16
; %bb.14:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[16:17], 2
	s_mov_b32 s9, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s7, s23, v1
	v_add_co_ci_u32_e64 v3, null, s24, 0, s7
	s_add_u32 s7, s12, s4
	s_addc_u32 s8, s13, s5
	s_mov_b64 s[4:5], 0
.LBB9_15:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s9, v7
	s_add_u32 s20, s7, s4
	s_addc_u32 s21, s8, s5
	s_add_i32 s9, s9, 4
	s_load_b128 s[36:39], s[20:21], 0x0
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v4, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v5, null, 0, v3, vcc_lo
	v_add_co_u32 v10, vcc_lo, v1, s4
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s5, v3, vcc_lo
	global_load_d16_u8 v4, v[4:5], off
	s_add_u32 s4, s4, 16
	s_addc_u32 s5, s5, 0
	global_load_b128 v[10:13], v[10:11], off offset:1024
	s_cmpk_eq_i32 s4, 0x200
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s36, v8
	v_fma_mix_f32 v8, v11, v10, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v5, v12, v5, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s37, v8
	v_fmac_f32_e32 v2, s38, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB9_15
.LBB9_16:                               ; %Flow2050
	s_or_b32 exec_lo, exec_lo, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:512
.LBB9_17:                               ; %Flow2051
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB9_19
; %bb.18:
	ds_load_b32 v1, v6
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB9_19:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB9_21
; %bb.20:
	ds_load_b32 v2, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB9_21:
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
	s_cbranch_execz .LBB9_23
; %bb.22:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_23:
	s_or_b32 exec_lo, exec_lo, s4
	v_cmp_gt_u32_e64 s4, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB9_25
; %bb.24:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_25:
	s_or_b32 exec_lo, exec_lo, s5
	v_cmp_gt_u32_e64 s5, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s5
	s_cbranch_execz .LBB9_27
; %bb.26:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_27:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB9_29
; %bb.28:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_29:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB9_31
; %bb.30:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_31:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_gt_u32_e64 s8, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB9_33
; %bb.32:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_33:
	s_or_b32 exec_lo, exec_lo, s9
	v_cmp_eq_u32_e64 s9, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s9
	s_cbranch_execz .LBB9_35
; %bb.34:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_35:
	s_or_b32 exec_lo, exec_lo, s17
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s17, s0
	s_cbranch_execz .LBB9_37
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
.LBB9_37:
	s_or_b32 exec_lo, exec_lo, s17
	s_and_saveexec_b32 s17, s1
	s_cbranch_execz .LBB9_39
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
.LBB9_39:
	s_or_b32 exec_lo, exec_lo, s17
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s3
	s_cbranch_execz .LBB9_41
; %bb.40:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_41:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s4
	s_cbranch_execz .LBB9_43
; %bb.42:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_43:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s5
	s_cbranch_execz .LBB9_45
; %bb.44:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_45:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s6
	s_cbranch_execz .LBB9_47
; %bb.46:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_47:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s7
	s_cbranch_execz .LBB9_49
; %bb.48:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_49:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s8
	s_cbranch_execz .LBB9_51
; %bb.50:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_51:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s9
	s_cbranch_execz .LBB9_53
; %bb.52:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_53:
	s_or_b32 exec_lo, exec_lo, s17
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s17, s0
	s_cbranch_execz .LBB9_55
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
.LBB9_55:
	s_or_b32 exec_lo, exec_lo, s17
	s_and_saveexec_b32 s17, s1
	s_cbranch_execz .LBB9_57
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
.LBB9_57:                               ; %.preheader229.1
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s30, s0
	s_cbranch_execz .LBB9_65
; %bb.58:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s17, exec_lo
	v_cmpx_le_i32_e64 s29, v0
	s_xor_b32 s31, exec_lo, s17
	s_cbranch_execz .LBB9_61
; %bb.59:                               ; %.preheader227.1265
	v_subrev_nc_u32_e32 v1, s29, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[20:21], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s17, s12, s20
	s_addc_u32 s33, s13, s21
	s_add_u32 s20, s18, s27
	s_addc_u32 s21, s19, s28
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s20, s20, s26
	s_addc_u32 s21, s21, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s20, v3
	v_add_co_ci_u32_e64 v4, null, s21, v4, vcc_lo
	s_mov_b64 s[20:21], 0
	v_add_co_u32 v3, vcc_lo, v1, 14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB9_60:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[10:13], v[3:4], off offset:-14
	s_add_u32 s34, s17, s20
	s_addc_u32 s35, s33, s21
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[34:35], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s20, s20, 32
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v1, 16, v10
	v_and_b32_e32 v10, 0xffff0000, v10
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc0 .LBB9_60
.LBB9_61:                               ; %Flow2044
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s31, s31
	s_cbranch_execz .LBB9_64
; %bb.62:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[20:21], s[16:17], 2
	s_mov_b32 s34, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s17, s23, v1
	v_add_co_ci_u32_e64 v3, null, s24, 0, s17
	s_add_u32 s17, s12, s20
	s_addc_u32 s33, s13, s21
	s_mov_b64 s[20:21], 0
.LBB9_63:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s34, v7
	s_add_u32 s36, s17, s20
	s_addc_u32 s37, s33, s21
	s_add_i32 s34, s34, 4
	s_load_b128 s[36:39], s[36:37], 0x200
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v11, null, 0, v3, vcc_lo
	global_load_d16_u8 v4, v[10:11], off
	v_add_co_u32 v10, vcc_lo, v1, s20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s21, v3, vcc_lo
	s_add_u32 s20, s20, 16
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	global_load_b128 v[10:13], v[10:11], off offset:1024
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s36, v10
	v_fma_mix_f32 v10, v11, v15, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v11, v12, v14, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s37, v10
	v_fmac_f32_e32 v2, s38, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s39, v4
	s_cbranch_scc0 .LBB9_63
.LBB9_64:                               ; %Flow2045
	s_or_b32 exec_lo, exec_lo, s31
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1024
.LBB9_65:                               ; %Flow2046
	s_or_b32 exec_lo, exec_lo, s30
	s_and_saveexec_b32 s30, s1
	s_cbranch_execz .LBB9_74
; %bb.66:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s17, exec_lo
	v_cmpx_le_i32_e64 s29, v9
	s_xor_b32 s31, exec_lo, s17
	s_cbranch_execz .LBB9_70
; %bb.67:                               ; %.preheader227.1.1
	v_subrev_nc_u32_e32 v1, s29, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s17, s16, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[20:21], s[16:17], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s17, s12, s20
	s_addc_u32 s29, s13, s21
	s_add_u32 s20, s18, s27
	s_addc_u32 s21, s19, s28
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s20, s20, s26
	s_addc_u32 s21, s21, s25
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s20, v3
	v_add_co_ci_u32_e64 v4, null, s21, v4, vcc_lo
	s_mov_b64 s[20:21], 0
	v_add_co_u32 v3, vcc_lo, v1, 14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB9_68:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[9:12], v[3:4], off offset:-14
	s_add_u32 s26, s17, s20
	s_addc_u32 s27, s29, s21
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[26:27], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s20, s20, 32
	s_addc_u32 s21, s21, 0
	s_cmpk_eq_i32 s20, 0x200
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v7, 0xffff0000, v9
	v_lshlrev_b32_e32 v1, 16, v9
	s_waitcnt lgkmcnt(0)
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
	s_cbranch_scc0 .LBB9_68
; %bb.69:                               ; %Flow2037
	s_set_inst_prefetch_distance 0x2
                                        ; implicit-def: $vgpr7
                                        ; implicit-def: $vgpr9
.LBB9_70:                               ; %Flow2039
	s_and_not1_saveexec_b32 s20, s31
	s_cbranch_execz .LBB9_73
; %bb.71:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s17, s16, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[26:27], s[16:17], 2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_u32_u24_e32 v1, 0x600, v1
	v_add_co_u32 v1, s17, s23, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s24, 0, s17
	s_add_u32 s17, s12, s26
	s_addc_u32 s21, s13, s27
	s_mov_b32 s23, 0
	s_mov_b64 s[12:13], 0
.LBB9_72:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s23, v7
	s_add_u32 s24, s17, s12
	s_addc_u32 s25, s21, s13
	s_add_i32 s23, s23, 4
	s_load_b128 s[24:27], s[24:25], 0x200
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v9, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v10, null, 0, v3, vcc_lo
	global_load_d16_u8 v4, v[9:10], off
	v_add_co_u32 v9, vcc_lo, v1, s12
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s13, v3, vcc_lo
	s_add_u32 s12, s12, 16
	s_addc_u32 s13, s13, 0
	s_cmpk_eq_i32 s12, 0x200
	global_load_b128 v[9:12], v[9:10], off offset:1024
	s_waitcnt vmcnt(1)
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
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v2, s24, v9
	v_fma_mix_f32 v9, v10, v14, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v10, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s25, v9
	v_fmac_f32_e32 v2, s26, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s27, v4
	s_cbranch_scc0 .LBB9_72
.LBB9_73:                               ; %Flow2040
	s_or_b32 exec_lo, exec_lo, s20
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1536
.LBB9_74:                               ; %Flow2041
	s_or_b32 exec_lo, exec_lo, s30
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB9_76
; %bb.75:
	ds_load_b32 v1, v6 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB9_76:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB9_78
; %bb.77:
	ds_load_b32 v2, v6 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB9_78:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB9_80
; %bb.79:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_80:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s4
	s_cbranch_execz .LBB9_82
; %bb.81:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_82:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s5
	s_cbranch_execz .LBB9_84
; %bb.83:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_84:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s6
	s_cbranch_execz .LBB9_86
; %bb.85:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_86:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s7
	s_cbranch_execz .LBB9_88
; %bb.87:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_88:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s8
	s_cbranch_execz .LBB9_90
; %bb.89:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_90:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s9
	s_cbranch_execz .LBB9_92
; %bb.91:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB9_92:
	s_or_b32 exec_lo, exec_lo, s12
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB9_94
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
.LBB9_94:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB9_96
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
.LBB9_96:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB9_98
; %bb.97:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_98:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s4
	s_cbranch_execz .LBB9_100
; %bb.99:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_100:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s5
	s_cbranch_execz .LBB9_102
; %bb.101:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_102:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s6
	s_cbranch_execz .LBB9_104
; %bb.103:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_104:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s7
	s_cbranch_execz .LBB9_106
; %bb.105:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_106:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s8
	s_cbranch_execz .LBB9_108
; %bb.107:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_108:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s9
	s_cbranch_execz .LBB9_110
; %bb.109:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB9_110:
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB9_112
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
.LBB9_112:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB9_114
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
.LBB9_114:                              ; %.preheader225
	s_or_b32 exec_lo, exec_lo, s0
	v_dual_mov_b32 v3, 0 :: v_dual_lshlrev_b32 v4, 1, v0
	v_lshrrev_b32_e32 v2, 3, v0
	s_max_i32 s4, s22, 33
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 2, v0
	s_sub_i32 s3, s4, 33
	v_and_b32_e32 v6, 6, v4
	v_and_b32_e32 v2, 0x7c, v2
	s_cmp_gt_u32 s22, 33
	s_cselect_b32 s5, -1, 0
	s_cmp_lt_u32 s22, 34
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB9_122
; %bb.115:                              ; %.lr.ph.preheader
	s_sub_i32 s0, s4, 34
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lt_u32 s0, 3
	s_cbranch_scc1 .LBB9_119
; %bb.116:                              ; %.lr.ph.preheader.new
	s_mul_i32 s1, s2, 0x2a00
	v_mov_b32_e32 v3, 0
	s_and_b32 s0, s3, -4
	s_mul_hi_i32 s6, s2, 0x2a00
	s_add_u32 s1, s18, s1
	s_addc_u32 s6, s19, s6
	s_mov_b32 s7, 0
	s_mov_b32 s8, 0
.LBB9_117:                              ; %.lr.ph
                                        ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v7, s9, s1, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v8, null, s6, 0, s9
	v_add_co_u32 v9, s9, s1, v2
	v_add_co_u32 v7, vcc_lo, 0x25000, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v8, null, 0, v8, vcc_lo
	v_add_co_ci_u32_e64 v10, null, s6, 0, s9
	v_add_co_u32 v9, vcc_lo, 0x25000, v9
	global_load_u8 v11, v[7:8], off
	v_add_co_ci_u32_e64 v10, null, 0, v10, vcc_lo
	s_clause 0x6
	global_load_u8 v12, v[7:8], off offset:48
	global_load_b32 v13, v[9:10], off offset:32
	global_load_u8 v14, v[7:8], off offset:96
	global_load_b32 v15, v[9:10], off offset:80
	global_load_b32 v16, v[9:10], off offset:128
	global_load_b32 v17, v[9:10], off offset:176
	global_load_u8 v18, v[7:8], off offset:144
	v_mov_b32_e32 v7, s7
	s_add_i32 s8, s8, 4
	s_add_u32 s1, s1, 0xc0
	s_addc_u32 s6, s6, 0
	s_add_i32 s7, s7, 16
	ds_load_b128 v[7:10], v7
	s_cmp_eq_u32 s0, s8
	s_waitcnt vmcnt(6)
	v_bfe_u32 v12, v12, v6, 2
	v_bfe_u32 v11, v11, v6, 2
	s_waitcnt vmcnt(4)
	v_bfe_u32 v14, v14, v6, 2
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v12, v12
	v_cvt_f32_ubyte0_e32 v11, v11
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v14, v14
	s_waitcnt vmcnt(3)
	v_fma_mix_f32 v12, v15, v12, v15 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_fma_mix_f32 v11, v13, v11, v13 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt vmcnt(0)
	v_bfe_u32 v13, v18, v6, 2
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v3, v7, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v7, v13
	v_fma_mix_f32 v11, v16, v14, v16 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v3, v8, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_fma_mix_f32 v7, v17, v7, v17 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fmac_f32_e32 v3, v9, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v3, v10, v7
	s_cbranch_scc0 .LBB9_117
; %bb.118:                              ; %.preheader223.loopexit.unr-lcssa
	s_and_b32 s1, s3, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc0 .LBB9_120
	s_branch .LBB9_122
.LBB9_119:
	v_mov_b32_e32 v3, 0
	s_mov_b32 s0, 0
	s_and_b32 s1, s3, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc1 .LBB9_122
.LBB9_120:                              ; %.lr.ph.epil.preheader
	s_lshl_b32 s6, s0, 2
	s_mul_i32 s0, s0, 48
	s_mul_i32 s7, s2, 0x2a00
	s_add_u32 s0, s18, s0
	s_addc_u32 s8, s19, 0
	s_mul_hi_i32 s1, s2, 0x2a00
	s_add_u32 s0, s0, s7
	s_addc_u32 s1, s8, s1
	v_add_co_u32 v7, s7, s0, v2
	v_add_co_u32 v9, s0, s0, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s1, 0, s0
	s_add_i32 s0, s4, -1
	v_add_co_u32 v9, vcc_lo, 0x25000, v9
	v_add_co_ci_u32_e64 v8, null, s1, 0, s7
	v_add_co_ci_u32_e64 v10, null, 0, v10, vcc_lo
	s_and_b32 s0, s0, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_mul_i32 s7, s0, 48
	s_mov_b64 s[0:1], 0
	.p2align	6
.LBB9_121:                              ; %.lr.ph.epil
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, vcc_lo, v9, s0
	v_add_co_ci_u32_e64 v12, null, s1, v10, vcc_lo
	v_add_co_u32 v13, vcc_lo, v7, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v14, null, s1, v8, vcc_lo
	global_load_u8 v15, v[11:12], off
	v_add_co_u32 v11, vcc_lo, 0x25000, v13
	v_add_co_ci_u32_e64 v12, null, 0, v14, vcc_lo
	global_load_b32 v11, v[11:12], off offset:32
	v_mov_b32_e32 v12, s6
	s_add_i32 s6, s6, 4
	s_add_u32 s0, s0, 48
	s_addc_u32 s1, s1, 0
	s_cmp_lg_u32 s7, s0
	ds_load_b32 v12, v12
	s_waitcnt vmcnt(1)
	v_bfe_u32 v13, v15, v6, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v13, v13
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v11, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v3, v12, v11
	s_cbranch_scc1 .LBB9_121
.LBB9_122:                              ; %.preheader223
	s_sub_i32 s0, s22, s3
	s_mul_i32 s7, s2, 0x2100
	s_cmp_gt_i32 s0, 0
	s_mul_hi_i32 s6, s2, 0x2100
	s_cselect_b32 s1, -1, 0
	s_add_u32 s7, s18, s7
	s_addc_u32 s6, s19, s6
	v_add_co_u32 v4, s7, s7, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v8, null, s6, 0, s7
	s_cmp_lt_i32 s0, 1
	v_add_co_u32 v7, vcc_lo, 0x3a000, v4
	v_add_co_ci_u32_e64 v8, null, 0, v8, vcc_lo
	s_mov_b32 s6, 0
	s_cbranch_scc1 .LBB9_129
; %bb.123:                              ; %.lr.ph247.preheader
	s_sub_i32 s7, s22, s4
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s7, s7, 32
	s_cmp_lt_u32 s7, 7
	s_cbranch_scc1 .LBB9_126
; %bb.124:                              ; %.lr.ph247.preheader.new
	s_lshl_b32 s7, s4, 2
	s_and_b32 s6, s0, 0x7ffffff8
	s_addk_i32 s7, 0xff7c
	s_mov_b32 s8, 0
.LBB9_125:                              ; %.lr.ph247
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_i32 s9, s4, s8
	s_add_i32 s8, s8, 8
	s_sub_i32 s12, s9, 33
	s_sub_i32 s13, s9, 32
	s_mul_hi_i32 s24, s12, 0x3e0f83e1
	s_mul_hi_i32 s25, s13, 0x3e0f83e1
	s_lshr_b32 s33, s24, 31
	s_lshr_b32 s24, s24, 3
	s_lshr_b32 s34, s25, 31
	s_add_i32 s24, s24, s33
	s_lshr_b32 s25, s25, 3
	s_mul_i32 s24, s24, 33
	s_add_i32 s25, s25, s34
	s_sub_i32 s12, s12, s24
	s_sub_i32 s17, s9, 31
	s_lshl_b32 s12, s12, 8
	s_mul_i32 s25, s25, 33
	s_ashr_i32 s24, s12, 31
	v_add_co_u32 v9, vcc_lo, v7, s12
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s24, v8, vcc_lo
	s_mul_hi_i32 s26, s17, 0x3e0f83e1
	s_sub_i32 s20, s9, 30
	s_sub_i32 s13, s13, s25
	global_load_u16 v4, v[9:10], off
	s_lshr_b32 s35, s26, 31
	s_lshr_b32 s26, s26, 3
	s_mul_hi_i32 s27, s20, 0x3e0f83e1
	s_lshl_b32 s13, s13, 8
	s_add_i32 s26, s26, s35
	s_lshr_b32 s36, s27, 31
	s_lshr_b32 s27, s27, 3
	s_ashr_i32 s25, s13, 31
	v_add_co_u32 v11, vcc_lo, v7, s13
	s_mul_i32 s26, s26, 33
	s_add_i32 s27, s27, s36
	v_add_co_ci_u32_e64 v12, null, s25, v8, vcc_lo
	s_sub_i32 s21, s9, 29
	s_sub_i32 s17, s17, s26
	s_mul_i32 s27, s27, 33
	s_mul_hi_i32 s28, s21, 0x3e0f83e1
	s_lshl_b32 s17, s17, 8
	s_sub_i32 s22, s9, 28
	s_sub_i32 s20, s20, s27
	s_lshr_b32 s37, s28, 31
	s_lshr_b32 s28, s28, 3
	s_ashr_i32 s26, s17, 31
	global_load_u16 v17, v[11:12], off
	v_add_co_u32 v9, vcc_lo, v7, s17
	s_mul_hi_i32 s29, s22, 0x3e0f83e1
	s_lshl_b32 s20, s20, 8
	s_add_i32 s28, s28, s37
	v_add_co_ci_u32_e64 v10, null, s26, v8, vcc_lo
	s_lshr_b32 s38, s29, 31
	s_lshr_b32 s29, s29, 3
	s_ashr_i32 s27, s20, 31
	v_add_co_u32 v11, vcc_lo, v7, s20
	s_mul_i32 s28, s28, 33
	s_add_i32 s29, s29, s38
	v_add_co_ci_u32_e64 v12, null, s27, v8, vcc_lo
	s_sub_i32 s23, s9, 27
	s_sub_i32 s21, s21, s28
	s_mul_i32 s29, s29, 33
	s_clause 0x1
	global_load_u16 v18, v[9:10], off
	global_load_u16 v19, v[11:12], off
	s_sub_i32 s9, s9, 26
	s_mul_hi_i32 s30, s23, 0x3e0f83e1
	s_lshl_b32 s21, s21, 8
	s_sub_i32 s22, s22, s29
	s_mul_hi_i32 s31, s9, 0x3e0f83e1
	s_lshr_b32 s39, s30, 31
	s_lshr_b32 s30, s30, 3
	s_ashr_i32 s28, s21, 31
	v_add_co_u32 v9, vcc_lo, v7, s21
	s_lshl_b32 s22, s22, 8
	s_lshr_b32 s40, s31, 31
	s_lshr_b32 s31, s31, 3
	s_add_i32 s30, s30, s39
	v_add_co_ci_u32_e64 v10, null, s28, v8, vcc_lo
	s_ashr_i32 s29, s22, 31
	v_add_co_u32 v11, vcc_lo, v7, s22
	s_add_i32 s31, s31, s40
	s_mul_i32 s30, s30, 33
	v_add_co_ci_u32_e64 v12, null, s29, v8, vcc_lo
	s_mul_i32 s31, s31, 33
	s_sub_i32 s23, s23, s30
	s_clause 0x1
	global_load_u16 v20, v[9:10], off
	global_load_u16 v21, v[11:12], off
	s_sub_i32 s9, s9, s31
	s_lshl_b32 s23, s23, 8
	s_lshl_b32 s9, s9, 8
	s_ashr_i32 s30, s23, 31
	v_add_co_u32 v9, vcc_lo, v7, s23
	s_ashr_i32 s31, s9, 31
	v_add_co_ci_u32_e64 v10, null, s30, v8, vcc_lo
	v_add_co_u32 v11, vcc_lo, v7, s9
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s31, v8, vcc_lo
	s_clause 0x1
	global_load_u16 v22, v[9:10], off
	global_load_u16 v23, v[11:12], off
	v_mov_b32_e32 v15, s7
	s_add_i32 s7, s7, 32
	s_cmp_eq_u32 s6, s8
	s_waitcnt vmcnt(7)
	v_lshlrev_b32_e32 v4, 16, v4
	ds_load_2addr_b32 v[9:10], v15 offset1:1
	ds_load_2addr_b32 v[11:12], v15 offset0:2 offset1:3
	ds_load_2addr_b32 v[13:14], v15 offset0:4 offset1:5
	ds_load_2addr_b32 v[15:16], v15 offset0:6 offset1:7
	s_waitcnt lgkmcnt(3)
	v_fmac_f32_e32 v3, v9, v4
	s_waitcnt vmcnt(6)
	v_lshlrev_b32_e32 v17, 16, v17
	s_waitcnt vmcnt(5)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v3, v10, v17 :: v_dual_lshlrev_b32 v4, 16, v18
	s_waitcnt vmcnt(4)
	v_lshlrev_b32_e32 v9, 16, v19
	s_waitcnt lgkmcnt(2)
	v_fmac_f32_e32 v3, v11, v4
	s_waitcnt vmcnt(3)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v3, v12, v9 :: v_dual_lshlrev_b32 v4, 16, v20
	s_waitcnt vmcnt(2)
	v_lshlrev_b32_e32 v9, 16, v21
	s_waitcnt lgkmcnt(1)
	v_fmac_f32_e32 v3, v13, v4
	s_waitcnt vmcnt(1)
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v3, v14, v9 :: v_dual_lshlrev_b32 v4, 16, v22
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v9, 16, v23
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v3, v15, v4
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v3, v16, v9
	s_cbranch_scc0 .LBB9_125
.LBB9_126:                              ; %._crit_edge.loopexit.unr-lcssa
	s_and_b32 s7, s0, 7
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s7, 0
	s_cbranch_scc1 .LBB9_129
; %bb.127:                              ; %.lr.ph247.epil.preheader
	s_add_i32 s8, s6, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_lshl_b32 s6, s8, 2
	s_sub_i32 s8, s8, 33
	s_addk_i32 s6, 0xff7c
	.p2align	6
.LBB9_128:                              ; %.lr.ph247.epil
                                        ; =>This Inner Loop Header: Depth=1
	s_mul_hi_i32 s9, s8, 0x3e0f83e1
	s_add_i32 s7, s7, -1
	s_lshr_b32 s12, s9, 31
	s_lshr_b32 s9, s9, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s9, s9, s12
	s_mul_i32 s9, s9, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_sub_i32 s9, s8, s9
	s_add_i32 s8, s8, 1
	s_lshl_b32 s9, s9, 8
	s_ashr_i32 s12, s9, 31
	v_add_co_u32 v9, vcc_lo, v7, s9
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s12, v8, vcc_lo
	global_load_u16 v4, v[9:10], off
	v_mov_b32_e32 v9, s6
	s_add_i32 s6, s6, 4
	s_cmp_lg_u32 s7, 0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v4, 16, v4
	ds_load_b32 v9, v9
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v3, v9, v4
	s_cbranch_scc1 .LBB9_128
.LBB9_129:                              ; %._crit_edge
	v_mov_b32_e32 v9, 0
	s_and_not1_b32 vcc_lo, exec_lo, s5
	ds_store_b32 v5, v3 offset:4096
	s_cbranch_vccnz .LBB9_132
; %bb.130:                              ; %.lr.ph.1.preheader
	s_mul_i32 s5, s2, 0x2a00
	s_mul_hi_i32 s6, s2, 0x2a00
	s_add_u32 s5, s18, s5
	s_addc_u32 s6, s19, s6
	v_add_co_u32 v2, s7, s5, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s6, 0, s7
	v_add_co_u32 v4, s5, s5, v1
	v_add_co_ci_u32_e64 v9, null, s6, 0, s5
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, 0x25022, v2
	v_add_co_ci_u32_e64 v2, null, 0, v3, vcc_lo
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v3, vcc_lo, 0x25000, v4
	v_add_co_ci_u32_e64 v4, null, 0, v9, vcc_lo
	v_mov_b32_e32 v9, 0
	s_movk_i32 s5, 0x400
	s_mov_b32 s6, s3
	.p2align	6
.LBB9_131:                              ; %.lr.ph.1
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u8 v10, v[3:4], off
	global_load_b32 v11, v[1:2], off offset:-2
	v_mov_b32_e32 v12, s5
	v_add_co_u32 v1, vcc_lo, v1, 48
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	ds_load_b32 v12, v12
	v_add_co_u32 v3, vcc_lo, v3, 48
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_i32 s6, s6, -1
	s_add_i32 s5, s5, 4
	s_cmp_lg_u32 s6, 0
	s_waitcnt vmcnt(1)
	v_bfe_u32 v10, v10, v6, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v10, v10
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v10, v11, v10, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v9, v12, v10
	s_cbranch_scc1 .LBB9_131
.LBB9_132:                              ; %Flow2026
	v_or_b32_e32 v1, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB9_135
; %bb.133:                              ; %.lr.ph247.1.preheader
	s_lshl_b32 s1, s4, 2
	s_mov_b32 s4, 0
	s_addk_i32 s1, 0x37c
	.p2align	6
.LBB9_134:                              ; %.lr.ph247.1
                                        ; =>This Inner Loop Header: Depth=1
	s_add_i32 s5, s3, s4
	s_add_i32 s4, s4, 1
	s_mul_hi_i32 s6, s5, 0x3e0f83e1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s7, s6, 31
	s_lshr_b32 s6, s6, 3
	s_add_i32 s6, s6, s7
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_i32 s6, s6, 33
	s_sub_i32 s5, s5, s6
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshl_b32 s5, s5, 8
	s_ashr_i32 s6, s5, 31
	v_add_co_u32 v2, vcc_lo, v7, s5
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s6, v8, vcc_lo
	global_load_u16 v2, v[2:3], off
	v_mov_b32_e32 v3, s1
	s_add_i32 s1, s1, 4
	s_cmp_lt_i32 s4, s0
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v2, 16, v2
	ds_load_b32 v3, v3
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v9, v3, v2
	s_cbranch_scc1 .LBB9_134
.LBB9_135:                              ; %._crit_edge.1
	v_lshlrev_b32_e32 v2, 12, v0
	ds_store_b32 v1, v9 offset:512
	v_mov_b32_e32 v1, 0
	s_ashr_i32 s17, s16, 31
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, s0, s14, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s15, 0, s0
	s_lshl_b64 s[0:1], s[16:17], 1
	s_movk_i32 s3, 0x1000
	v_add_co_u32 v3, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v4, null, s1, v4, vcc_lo
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
.LBB9_136:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB9_136
; %bb.137:                              ; %.preheader.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[4:5], 0
.LBB9_138:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_138
; %bb.139:                              ; %.preheader.1285
	s_lshl_b32 s2, s2, 10
	s_add_u32 s0, s14, s0
	v_or_b32_e32 v3, s2, v0
	s_addc_u32 s1, s15, s1
	v_add_co_u32 v2, s0, s0, v2
	s_movk_i32 s3, 0x1000
	v_ashrrev_i32_e32 v4, 31, v3
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[5:6], 2, v[3:4]
	v_mov_b32_e32 v4, 0
	v_add_co_ci_u32_e64 v3, null, s1, 0, s0
	s_mov_b64 s[0:1], 0
	v_add_co_u32 v5, vcc_lo, s10, v5
	v_add_co_ci_u32_e64 v6, null, s11, v6, vcc_lo
	global_store_b32 v[5:6], v1, off
.LBB9_140:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_140
; %bb.141:                              ; %.preheader.1.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[0:1], 0
.LBB9_142:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_142
; %bb.143:                              ; %.preheader.2
	s_ashr_i32 s0, s2, 31
	v_add_co_u32 v0, s1, v0, s2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_2)
	v_add_co_ci_u32_e64 v1, null, 0, s0, s1
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v0, vcc_lo, s10, v0
	v_add_co_ci_u32_e64 v1, null, s11, v1, vcc_lo
	global_store_b32 v[0:1], v4, off offset:512
.LBB9_144:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_144
; %bb.145:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB9_146:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_146
; %bb.147:                              ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:1024
.LBB9_148:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_148
; %bb.149:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB9_150:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_150
; %bb.151:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:1536
.LBB9_152:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_152
; %bb.153:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB9_154:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_154
; %bb.155:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:2048
.LBB9_156:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_156
; %bb.157:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB9_158:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_158
; %bb.159:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:2560
.LBB9_160:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_160
; %bb.161:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB9_162:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_162
; %bb.163:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:3072
.LBB9_164:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_164
; %bb.165:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB9_166:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB9_166
; %bb.167:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
.LBB9_168:                              ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
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
		.amdhsa_next_free_vgpr 24
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
	.section	.text._Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,"axG",@progbits,_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf,comdat
.Lfunc_end9:
	.size	_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf, .Lfunc_end9-_Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
                                        ; -- End function
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.num_vgpr, 24
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.num_agpr, 0
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.numbered_sgpr, 44
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.num_named_barrier, 0
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.private_seg_size, 0
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.uses_vcc, 1
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.uses_flat_scratch, 0
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.has_dyn_sized_stack, 0
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.has_recursion, 0
	.set _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 13692
; TotalNumSgprs: 46
; NumVgprs: 24
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 5632 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 2
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 24
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
	.type	__hip_cuid_effb0fc7bb40714c,@object ; @__hip_cuid_effb0fc7bb40714c
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_effb0fc7bb40714c
__hip_cuid_effb0fc7bb40714c:
	.byte	0                               ; 0x0
	.size	__hip_cuid_effb0fc7bb40714c, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __hip_cuid_effb0fc7bb40714c
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
    .name:           _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii
    .private_segment_fixed_size: 0
    .sgpr_count:     15
    .sgpr_spill_count: 0
    .symbol:         _ZN6stable10append_keyEPNS_5CacheEPNS_7ControlEPKhii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     7
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
    .group_segment_fixed_size: 44
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii
    .private_segment_fixed_size: 0
    .sgpr_count:     39
    .sgpr_spill_count: 0
    .symbol:         _ZN6stable13append_recentEPNS_5CacheEPNS_7ControlEPKhii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     19
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
      - .offset:         16
        .size:           4
        .value_kind:     by_value
      - .offset:         20
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 4608
    .kernarg_segment_align: 8
    .kernarg_segment_size: 24
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii
    .private_segment_fixed_size: 0
    .sgpr_count:     15
    .sgpr_spill_count: 0
    .symbol:         _ZN6stable9flush_keyEPNS_5CacheEPNS_7ControlEii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     51
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
    .group_segment_fixed_size: 144
    .kernarg_segment_align: 8
    .kernarg_segment_size: 32
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii
    .private_segment_fixed_size: 0
    .sgpr_count:     17
    .sgpr_spill_count: 0
    .symbol:         _ZN6stable11flush_valueEPNS_5CacheEPNS_7ControlEPNS_7ScratchEii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     51
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
      - .offset:         16
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 156
    .kernarg_segment_align: 8
    .kernarg_segment_size: 20
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi
    .private_segment_fixed_size: 0
    .sgpr_count:     23
    .sgpr_spill_count: 0
    .symbol:         _ZN6stable12finish_valueEPNS_5CacheEPNS_7ScratchEi.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     9
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
        .value_kind:     by_value
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 12
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN6stable12finish_earlyEPNS_5CacheEi
    .private_segment_fixed_size: 0
    .sgpr_count:     5
    .sgpr_spill_count: 0
    .symbol:         _ZN6stable12finish_earlyEPNS_5CacheEi.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     2
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
        .value_kind:     by_value
      - .address_space:  global
        .offset:         24
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         32
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         40
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 5632
    .kernarg_segment_align: 8
    .kernarg_segment_size: 48
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi1EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.kd
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
      - .offset:         16
        .size:           4
        .value_kind:     by_value
      - .address_space:  global
        .offset:         24
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         32
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         40
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 5632
    .kernarg_segment_align: 8
    .kernarg_segment_size: 48
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi0EEvPKN6stable5CacheEPKNS0_7ControlEiPKfPKtPf.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     24
    .vgpr_spill_count: 0
    .wavefront_size: 32
    .workgroup_processor_mode: 1
amdhsa.target:   amdgcn-amd-amdhsa--gfx1151
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
