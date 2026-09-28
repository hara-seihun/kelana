	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.protected	_ZN8alphabet10append_keyEPNS_5CacheEPKhi ; -- Begin function _ZN8alphabet10append_keyEPNS_5CacheEPKhi
	.globl	_ZN8alphabet10append_keyEPNS_5CacheEPKhi
	.p2align	8
	.type	_ZN8alphabet10append_keyEPNS_5CacheEPKhi,@function
_ZN8alphabet10append_keyEPNS_5CacheEPKhi: ; @_ZN8alphabet10append_keyEPNS_5CacheEPKhi
; %bb.0:
	v_cmp_gt_u32_e32 vcc_lo, 0x80, v0
	s_cmp_lt_i32 s2, 8
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s3, s3, vcc_lo
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB0_8
; %bb.1:
	s_clause 0x1
	s_load_b32 s3, s[0:1], 0x10
	s_load_b128 s[4:7], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_add_i32 s0, s3, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_ashr_i32 s1, s0, 31
	s_lshr_b32 s1, s1, 27
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_add_i32 s1, s0, s1
	s_lshl_b32 s0, s0, 8
	s_lshr_b32 s1, s1, 5
	s_mulk_i32 s1, 0xe600
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_2) | instid1(SALU_CYCLE_1)
	s_add_i32 s0, s1, s0
	s_mov_b32 s1, -1
	s_addk_i32 s0, 0x100
	s_cmpk_gt_i32 s0, 0x4a00
	s_cbranch_scc1 .LBB0_5
; %bb.2:                                ; %.lr.ph
	v_lshl_add_u32 v1, s2, 8, v0
	s_mul_hi_i32 s3, s2, 0x4a00
	s_mulk_i32 s2, 0x4a00
	v_add_nc_u32_e32 v3, 0xffffff80, v0
	s_add_u32 s1, s4, s2
	v_ashrrev_i32_e32 v2, 31, v1
	v_add_co_u32 v1, vcc_lo, s6, v1
	s_addc_u32 s2, s5, s3
	s_mov_b32 s3, 0
	v_add_co_ci_u32_e64 v2, null, s7, v2, vcc_lo
	.p2align	6
.LBB0_3:                                ; =>This Inner Loop Header: Depth=1
	global_load_d16_u8 v4, v[1:2], off
	v_add3_u32 v5, s0, v3, 0xffffff80
	v_add_co_u32 v1, vcc_lo, 0x80, v1
	v_add_co_u32 v3, s6, 0x80, v3
	s_delay_alu instid0(VALU_DEP_3)
	v_ashrrev_i32_e32 v6, 31, v5
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	v_add_co_u32 v5, vcc_lo, s1, v5
	s_xor_b32 s6, s6, -1
	v_add_co_ci_u32_e64 v6, null, s2, v6, vcc_lo
	s_and_b32 s6, exec_lo, s6
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s3, s6, s3
	s_waitcnt vmcnt(0)
	global_store_b8 v[5:6], v4, off
	s_and_not1_b32 exec_lo, exec_lo, s3
	s_cbranch_execnz .LBB0_3
; %bb.4:                                ; %Flow
	s_or_b32 exec_lo, exec_lo, s3
	s_mov_b32 s1, 0
.LBB0_5:                                ; %Flow35
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccz .LBB0_8
; %bb.6:
	v_cmp_eq_u32_e32 vcc_lo, 0, v0
	s_and_b32 exec_lo, exec_lo, vcc_lo
	s_cbranch_execz .LBB0_8
; %bb.7:
	v_dual_mov_b32 v0, 0x4a000 :: v_dual_mov_b32 v1, 1
	global_store_b32 v0, v1, s[4:5] offset:2048
.LBB0_8:                                ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN8alphabet10append_keyEPNS_5CacheEPKhi
		.amdhsa_group_segment_fixed_size 0
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
		.amdhsa_next_free_vgpr 7
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
	.size	_ZN8alphabet10append_keyEPNS_5CacheEPKhi, .Lfunc_end0-_ZN8alphabet10append_keyEPNS_5CacheEPKhi
                                        ; -- End function
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.num_vgpr, 7
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.num_agpr, 0
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.numbered_sgpr, 8
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.num_named_barrier, 0
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.private_seg_size, 0
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.uses_vcc, 1
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.uses_flat_scratch, 0
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.has_dyn_sized_stack, 0
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.has_recursion, 0
	.set _ZN8alphabet10append_keyEPNS_5CacheEPKhi.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 344
; TotalNumSgprs: 10
; NumVgprs: 7
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 0
; NumSGPRsForWavesPerEU: 10
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
	.protected	_ZN8alphabet13append_recentEPNS_5CacheEPKhi ; -- Begin function _ZN8alphabet13append_recentEPNS_5CacheEPKhi
	.globl	_ZN8alphabet13append_recentEPNS_5CacheEPKhi
	.p2align	8
	.type	_ZN8alphabet13append_recentEPNS_5CacheEPKhi,@function
_ZN8alphabet13append_recentEPNS_5CacheEPKhi: ; @_ZN8alphabet13append_recentEPNS_5CacheEPKhi
; %bb.0:
	v_cmp_gt_u32_e32 vcc_lo, 0x80, v0
	s_cmp_lt_i32 s2, 8
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_and_b32 s3, s3, vcc_lo
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB1_3
; %bb.1:                                ; %.preheader
	s_clause 0x1
	s_load_b32 s3, s[0:1], 0x10
	s_load_b128 s[4:7], s[0:1], 0x0
	s_lshl_b32 s1, s2, 8
	s_mul_i32 s9, s2, 0x2100
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_add_i32 s3, s3, -1
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_hi_i32 s0, s3, 0x3e0f83e1
	s_lshr_b32 s8, s0, 31
	s_lshr_b32 s0, s0, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_4) | instid1(SALU_CYCLE_1)
	s_add_i32 s0, s0, s8
	s_mul_hi_i32 s8, s2, 0x2100
	s_mul_i32 s0, s0, 33
	s_ashr_i32 s2, s1, 31
	s_sub_i32 s0, s3, s0
	s_lshl_b32 s0, s0, 8
	s_add_u32 s1, s6, s1
	s_addc_u32 s2, s7, s2
	s_add_u32 s1, s1, 0x800
	s_addc_u32 s2, s2, 0
	s_ashr_i32 s3, s0, 31
	s_add_u32 s0, s9, s0
	s_addc_u32 s6, s8, s3
	s_add_u32 s3, s4, s0
	s_addc_u32 s4, s5, s6
	s_mov_b32 s5, 0
	.p2align	6
.LBB1_2:                                ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v2, vcc_lo, s1, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s2, v1, vcc_lo
	global_load_d16_u8 v2, v[2:3], off
	v_add_co_u32 v3, vcc_lo, s3, v0
	v_add_co_u32 v0, s0, 0x80, v0
	v_add_co_ci_u32_e64 v4, null, s4, v1, vcc_lo
	v_add_co_ci_u32_e64 v1, null, 0, v1, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_nc_u32_e32 v5, 0xffffff80, v0
	v_add_co_u32 v3, vcc_lo, 0x3a000, v3
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_lt_u32_e64 s0, 0x7f, v5
	s_or_b32 s5, s0, s5
	s_waitcnt vmcnt(0)
	global_store_b8 v[3:4], v2, off
	s_and_not1_b32 exec_lo, exec_lo, s5
	s_cbranch_execnz .LBB1_2
.LBB1_3:                                ; %.loopexit
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN8alphabet13append_recentEPNS_5CacheEPKhi
		.amdhsa_group_segment_fixed_size 0
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
		.amdhsa_next_free_vgpr 6
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
	.text
.Lfunc_end1:
	.size	_ZN8alphabet13append_recentEPNS_5CacheEPKhi, .Lfunc_end1-_ZN8alphabet13append_recentEPNS_5CacheEPKhi
                                        ; -- End function
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.num_vgpr, 6
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.num_agpr, 0
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.numbered_sgpr, 10
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.num_named_barrier, 0
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.private_seg_size, 0
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.uses_vcc, 1
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.uses_flat_scratch, 0
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.has_dyn_sized_stack, 0
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.has_recursion, 0
	.set _ZN8alphabet13append_recentEPNS_5CacheEPKhi.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 312
; TotalNumSgprs: 12
; NumVgprs: 6
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 0
; NumSGPRsForWavesPerEU: 12
; NumVGPRsForWavesPerEU: 6
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
	.protected	_ZN8alphabet9flush_keyEPNS_5CacheEi ; -- Begin function _ZN8alphabet9flush_keyEPNS_5CacheEi
	.globl	_ZN8alphabet9flush_keyEPNS_5CacheEi
	.p2align	8
	.type	_ZN8alphabet9flush_keyEPNS_5CacheEi,@function
_ZN8alphabet9flush_keyEPNS_5CacheEi:    ; @_ZN8alphabet9flush_keyEPNS_5CacheEi
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
	s_load_b64 s[4:5], s[0:1], 0x0
	s_load_b32 s0, s[0:1], 0x8
	s_mul_i32 s1, s2, 0x4a00
	s_mul_hi_i32 s2, s2, 0x4a00
	v_lshlrev_b32_e32 v3, 1, v0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s4, s4, s1
	s_addc_u32 s5, s5, s2
	s_ashr_i32 s1, s0, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_lshr_b32 s1, s1, 27
	s_add_i32 s0, s0, s1
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
.LBB2_5:                                ; %Flow215
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
.LBB2_9:                                ; %Flow214
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
.LBB2_13:                               ; %Flow213
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
.LBB2_17:                               ; %Flow212
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
.LBB2_21:                               ; %Flow211
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
.LBB2_25:                               ; %Flow210
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
.LBB2_29:                               ; %Flow209
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
.LBB2_33:                               ; %Flow208
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
.LBB2_37:                               ; %Flow207
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
.LBB2_41:                               ; %Flow206
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
.LBB2_45:                               ; %Flow205
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
.LBB2_49:                               ; %Flow204
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
.LBB2_53:                               ; %Flow203
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
.LBB2_57:                               ; %Flow202
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
.LBB2_61:                               ; %Flow201
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
; %bb.68:                               ; %Flow193
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
.LBB2_71:                               ; %Flow195
	s_or_b32 exec_lo, exec_lo, s10
.LBB2_72:                               ; %Flow197
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s9
                                        ; implicit-def: $vgpr1_vgpr2
.LBB2_73:                               ; %Flow199
	s_and_not1_saveexec_b32 s0, s8
; %bb.74:
	v_and_b32_e32 v2, 0xfffff, v2
	v_mov_b32_e32 v3, 0x7c00
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_eq_u64_e32 vcc_lo, 0, v[1:2]
	v_cndmask_b32_e32 v3, 0x7e00, v3, vcc_lo
; %bb.75:                               ; %_ZN8alphabet7quant32EPKhiPhS2_.exit
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
	.amdhsa_kernel _ZN8alphabet9flush_keyEPNS_5CacheEi
		.amdhsa_group_segment_fixed_size 4608
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
	.size	_ZN8alphabet9flush_keyEPNS_5CacheEi, .Lfunc_end2-_ZN8alphabet9flush_keyEPNS_5CacheEi
                                        ; -- End function
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.num_vgpr, 51
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.num_agpr, 0
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.numbered_sgpr, 13
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.num_named_barrier, 0
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.private_seg_size, 0
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.uses_vcc, 1
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.uses_flat_scratch, 0
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.has_dyn_sized_stack, 0
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.has_recursion, 0
	.set _ZN8alphabet9flush_keyEPNS_5CacheEi.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 8280
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
	.protected	_ZN8alphabet11flush_valueEPNS_5CacheEPKfii ; -- Begin function _ZN8alphabet11flush_valueEPNS_5CacheEPKfii
	.globl	_ZN8alphabet11flush_valueEPNS_5CacheEPKfii
	.p2align	8
	.type	_ZN8alphabet11flush_valueEPNS_5CacheEPKfii,@function
_ZN8alphabet11flush_valueEPNS_5CacheEPKfii: ; @_ZN8alphabet11flush_valueEPNS_5CacheEPKfii
; %bb.0:
	v_and_b32_e32 v1, 0x39f, v0
	s_cmp_lt_i32 s2, 8
	s_cselect_b32 s3, -1, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_and_b32 s3, s3, vcc_lo
	s_and_saveexec_b32 s4, s3
	s_cbranch_execz .LBB3_41
; %bb.1:
	s_clause 0x1
	s_load_b128 s[4:7], s[0:1], 0x0
	s_load_b64 s[8:9], s[0:1], 0x10
	s_mul_i32 s0, s2, 0x2100
	s_mul_hi_i32 s1, s2, 0x2100
	v_lshlrev_b32_e32 v1, 1, v0
	s_waitcnt lgkmcnt(0)
	s_add_u32 s0, s4, s0
	s_addc_u32 s1, s5, s1
	s_sub_i32 s3, s8, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_mul_hi_i32 s8, s3, 0x3e0f83e1
	s_lshr_b32 s10, s8, 31
	s_lshr_b32 s8, s8, 3
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s8, s8, s10
	s_mul_i32 s8, s8, 33
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_sub_i32 s8, s3, s8
	s_lshl_b32 s8, s8, 8
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	s_ashr_i32 s10, s8, 31
	s_add_u32 s0, s0, s8
	s_addc_u32 s1, s1, s10
	v_add_co_u32 v1, s0, s0, v1
	v_add_co_ci_u32_e64 v2, null, s1, 0, s0
	s_mov_b32 s0, exec_lo
	v_add_co_u32 v1, vcc_lo, 0x3a000, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v2, vcc_lo
	s_clause 0x3
	global_load_b128 v[6:9], v[1:2], off
	global_load_b128 v[14:17], v[1:2], off offset:16
	global_load_b128 v[22:25], v[1:2], off offset:32
	global_load_b128 v[30:33], v[1:2], off offset:48
	v_mov_b16_e32 v1.l, 0
	s_delay_alu instid0(VALU_DEP_1)
	v_mov_b16_e32 v3.l, v1.l
	v_mov_b16_e32 v5.l, v1.l
	s_waitcnt vmcnt(3)
	v_and_b32_e32 v2, 0xffff0000, v6
	v_mov_b16_e32 v1.h, v6.l
	v_and_b32_e32 v4, 0xffff0000, v7
	v_mov_b16_e32 v3.h, v7.l
	v_and_b32_e32 v6, 0xffff0000, v8
	v_mov_b16_e32 v5.h, v8.l
	v_max3_f32 v7, v1, 0xff800000, v2
	v_min3_f32 v10, v1, 0x7f800000, v2
	v_and_b32_e32 v8, 0xffff0000, v9
	s_waitcnt vmcnt(2)
	v_mov_b16_e32 v9.h, v14.l
	v_max3_f32 v11, v7, v3, v4
	v_min3_f32 v10, v10, v3, v4
	v_mov_b16_e32 v7.l, v1.l
	v_mov_b16_e32 v7.h, v9.l
	v_mov_b16_e32 v9.l, v1.l
	v_max3_f32 v11, v11, v5, v6
	v_min3_f32 v12, v10, v5, v6
	v_and_b32_e32 v10, 0xffff0000, v14
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_max3_f32 v13, v11, v7, v8
	v_min3_f32 v14, v12, v7, v8
	v_mov_b16_e32 v11.l, v1.l
	v_and_b32_e32 v12, 0xffff0000, v15
	v_mov_b16_e32 v11.h, v15.l
	v_max3_f32 v15, v13, v9, v10
	v_min3_f32 v18, v14, v9, v10
	v_mov_b16_e32 v13.l, v1.l
	v_and_b32_e32 v14, 0xffff0000, v16
	v_mov_b16_e32 v13.h, v16.l
	v_max3_f32 v19, v15, v11, v12
	v_min3_f32 v18, v18, v11, v12
	v_mov_b16_e32 v15.l, v1.l
	v_and_b32_e32 v16, 0xffff0000, v17
	v_mov_b16_e32 v15.h, v17.l
	v_max3_f32 v19, v19, v13, v14
	v_min3_f32 v20, v18, v13, v14
	v_mov_b16_e32 v17.l, v1.l
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v18, 0xffff0000, v22
	v_mov_b16_e32 v17.h, v22.l
	v_max3_f32 v21, v19, v15, v16
	v_min3_f32 v22, v20, v15, v16
	v_mov_b16_e32 v19.l, v1.l
	v_and_b32_e32 v20, 0xffff0000, v23
	v_mov_b16_e32 v19.h, v23.l
	v_max3_f32 v23, v21, v17, v18
	v_min3_f32 v26, v22, v17, v18
	v_mov_b16_e32 v21.l, v1.l
	v_and_b32_e32 v22, 0xffff0000, v24
	v_mov_b16_e32 v21.h, v24.l
	v_max3_f32 v27, v23, v19, v20
	v_min3_f32 v26, v26, v19, v20
	v_mov_b16_e32 v23.l, v1.l
	v_and_b32_e32 v24, 0xffff0000, v25
	v_mov_b16_e32 v23.h, v25.l
	v_max3_f32 v27, v27, v21, v22
	v_min3_f32 v28, v26, v21, v22
	v_mov_b16_e32 v25.l, v1.l
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v26, 0xffff0000, v30
	v_mov_b16_e32 v25.h, v30.l
	v_max3_f32 v29, v27, v23, v24
	v_min3_f32 v30, v28, v23, v24
	v_mov_b16_e32 v27.l, v1.l
	v_and_b32_e32 v28, 0xffff0000, v31
	v_mov_b16_e32 v27.h, v31.l
	v_max3_f32 v31, v29, v25, v26
	v_min3_f32 v34, v30, v25, v26
	v_mov_b16_e32 v29.l, v1.l
	v_and_b32_e32 v30, 0xffff0000, v32
	v_mov_b16_e32 v29.h, v32.l
	v_max3_f32 v35, v31, v27, v28
	v_min3_f32 v34, v34, v27, v28
	v_mov_b16_e32 v31.l, v1.l
	v_and_b32_e32 v32, 0xffff0000, v33
	v_mov_b16_e32 v31.h, v33.l
	v_max3_f32 v33, v35, v29, v30
	v_min3_f32 v34, v34, v29, v30
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_max3_f32 v33, v33, v31, v32
	v_min3_f32 v43, v34, v31, v32
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f64_f32_e32 v[33:34], v33
	v_cvt_f64_f32_e32 v[35:36], v43
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f64 v[33:34], v[33:34], -v[35:36]
	v_div_scale_f64 v[35:36], null, 0x40080000, 0x40080000, v[33:34]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f64_e32 v[37:38], v[35:36]
	v_fma_f64 v[39:40], -v[35:36], v[37:38], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[37:38], v[37:38], v[39:40], v[37:38]
	v_fma_f64 v[39:40], -v[35:36], v[37:38], 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fma_f64 v[37:38], v[37:38], v[39:40], v[37:38]
	v_div_scale_f64 v[39:40], vcc_lo, v[33:34], 0x40080000, v[33:34]
	v_mul_f64 v[41:42], v[39:40], v[37:38]
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f64 v[35:36], -v[35:36], v[41:42], v[39:40]
	v_div_fmas_f64 v[35:36], v[35:36], v[37:38], v[41:42]
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_div_fixup_f64 v[33:34], v[35:36], 0x40080000, v[33:34]
	v_mov_b32_e32 v35, 0
	v_bfe_u32 v41, v34, 20, 11
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u32_e32 0x7ff, v41
	s_xor_b32 s8, exec_lo, s0
	s_cbranch_execz .LBB3_11
; %bb.2:
	s_mov_b32 s10, exec_lo
	v_cmpx_lt_u32_e32 0x3e5, v41
	s_cbranch_execz .LBB3_10
; %bb.3:
	v_mov_b32_e32 v35, 0x7c00
	s_mov_b32 s11, exec_lo
	v_cmpx_gt_u32_e32 0x40f, v41
	s_cbranch_execz .LBB3_9
; %bb.4:
	v_sub_nc_u32_e32 v35, 0x41b, v41
	v_cmp_gt_u32_e32 vcc_lo, 0x3f1, v41
	s_mov_b32 s0, 0xfffff
	s_mov_b32 s13, exec_lo
	v_and_or_b32 v45, v34, s0, 0x100000
	v_mov_b32_e32 v44, v33
	v_cndmask_b32_e32 v42, 42, v35, vcc_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_lshlrev_b64 v[35:36], v42, -1
	v_add_nc_u32_e32 v37, -1, v42
	v_lshlrev_b64 v[37:38], v37, 1
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_bfi_b32 v40, v36, 0, v45
	v_bfi_b32 v39, v35, 0, v33
	v_lshrrev_b64 v[35:36], v42, v[44:45]
	s_delay_alu instid0(VALU_DEP_2)
	v_cmp_gt_u64_e64 s12, v[39:40], v[37:38]
	v_cmpx_le_u64_e64 v[39:40], v[37:38]
; %bb.5:
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_and_b32_e32 v42, 1, v35
	v_cmp_eq_u64_e64 s0, v[39:40], v[37:38]
	v_cmp_eq_u32_e64 s1, 1, v42
	s_and_b32 s0, s0, s1
	s_and_not1_b32 s1, s12, exec_lo
	s_and_b32 s0, s0, exec_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 s12, s1, s0
; %bb.6:                                ; %Flow148
	s_or_b32 exec_lo, exec_lo, s13
	s_and_saveexec_b32 s1, s12
; %bb.7:
	v_add_co_u32 v35, s0, v35, 1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v36, null, 0, v36, s0
; %bb.8:
	s_or_b32 exec_lo, exec_lo, s1
	v_lshl_add_u32 v36, v41, 10, 0xfff03c00
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v36, v36, 0, vcc_lo
	v_add_nc_u32_e32 v35, v36, v35
.LBB3_9:                                ; %Flow150
	s_or_b32 exec_lo, exec_lo, s11
.LBB3_10:                               ; %Flow152
	s_delay_alu instid0(SALU_CYCLE_1)
	s_or_b32 exec_lo, exec_lo, s10
.LBB3_11:                               ; %Flow154
	s_and_not1_saveexec_b32 s0, s8
; %bb.12:
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_dual_mov_b32 v35, v33 :: v_dual_and_b32 v36, 0xfffff, v34
	v_mov_b32_e32 v37, 0x7c00
	v_cmp_eq_u64_e32 vcc_lo, 0, v[35:36]
	s_delay_alu instid0(VALU_DEP_2)
	v_cndmask_b32_e32 v35, 0x7e00, v37, vcc_lo
; %bb.13:                               ; %_ZN8resident9step_bitsEy.exit
	s_or_b32 exec_lo, exec_lo, s0
	s_mul_i32 s3, s3, 48
	s_mul_i32 s8, s2, 0x2a00
	s_ashr_i32 s10, s3, 31
	s_mul_hi_i32 s2, s2, 0x2a00
	v_lshrrev_b32_e32 v37, 3, v0
	s_add_u32 s0, s4, s8
	s_addc_u32 s1, s5, s2
	s_add_u32 s0, s0, s3
	s_addc_u32 s1, s1, s10
	v_add_co_u32 v37, s0, s0, v37
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v38, null, s1, 0, s0
	v_cvt_f16_f32_e32 v40.l, v43
	v_add_co_u32 v41, vcc_lo, 0x25000, v37
	v_dual_mov_b32 v36, 0 :: v_dual_mov_b32 v37, 0
	v_mov_b16_e32 v40.h, v35.l
	v_add_co_ci_u32_e64 v42, null, 0, v38, vcc_lo
	v_dual_mov_b32 v38, 0 :: v_dual_mov_b32 v39, 0
	s_cmp_lg_u32 s9, 0
	global_store_b32 v[41:42], v40, off offset:32
	s_cselect_b32 s1, -1, 0
	s_cmp_eq_u32 s9, 0
	s_cbranch_scc1 .LBB3_15
; %bb.14:                               ; %.loopexit104.loopexit
	v_cvt_f32_f16_e32 v35, v35.l
	v_mov_b32_e32 v36, 0
	v_cvt_f32_f16_e32 v40, v40.l
	global_load_b128 v[36:39], v36, s[6:7]
	s_waitcnt vmcnt(0)
	v_mul_f32_e32 v37, v37, v35
	v_mul_f32_e32 v36, v36, v35
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_mul_f32 v38, v38, v35 :: v_dual_add_f32 v37, v37, v40
	v_dual_mul_f32 v35, v39, v35 :: v_dual_add_f32 v36, v36, v40
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_f32_e32 v39, v35, v40
	v_add_f32_e32 v38, v38, v40
.LBB3_15:                               ; %.loopexit104
	v_cvt_f32_f64_e32 v44, v[33:34]
	v_cmp_neq_f64_e64 s0, 0, v[33:34]
	v_cvt_f64_f32_e32 v[33:34], v36
	v_cvt_f64_f32_e32 v[35:36], v37
	v_cvt_f64_f32_e32 v[37:38], v38
	v_cvt_f64_f32_e32 v[39:40], v39
	v_lshrrev_b32_e32 v0, 2, v0
	s_add_u32 s3, s4, s3
	s_addc_u32 s4, s5, s10
	s_add_u32 s3, s3, s8
	s_addc_u32 s2, s4, s2
	v_add_co_u32 v0, s3, s3, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v42, null, s2, 0, s3
	s_mov_b64 s[2:3], 0
	v_add_co_u32 v41, vcc_lo, 0x25000, v0
	v_add_co_ci_u32_e64 v42, null, 0, v42, vcc_lo
	s_branch .LBB3_18
.LBB3_16:                               ; %Flow
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
.LBB3_17:                               ; %.loopexit.3
                                        ;   in Loop: Header=BB3_18 Depth=1
	v_lshl_or_b32 v0, v45, 2, v0
	s_add_u32 s2, s2, 4
	s_addc_u32 s3, s3, 0
	s_cmp_lg_u32 s2, 32
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshl_or_b32 v0, v46, 4, v0
	v_lshl_or_b32 v0, v47, 6, v0
	global_store_b8 v[41:42], v0, off
	v_add_co_u32 v41, vcc_lo, v41, 1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v42, null, 0, v42, vcc_lo
	s_cbranch_scc0 .LBB3_41
.LBB3_18:                               ; %.preheader102
                                        ; =>This Inner Loop Header: Depth=1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB3_26
; %bb.19:                               ; %.preheader
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_mov_b32 m0, s2
	v_movrels_b32_e32 v0, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f64_f32_e32 v[45:46], v0
	v_add_f64 v[47:48], v[45:46], -v[33:34]
	v_add_f64 v[49:50], v[45:46], -v[35:36]
	v_add_f64 v[51:52], v[45:46], -v[37:38]
	v_add_f64 v[45:46], v[45:46], -v[39:40]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[47:48], v[47:48], v[47:48]
	v_mul_f64 v[49:50], v[49:50], v[49:50]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[51:52], v[51:52], v[51:52]
	v_mul_f64 v[45:46], v[45:46], v[45:46]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_min_f64 v[47:48], 0x7ff00000, v[47:48]
	v_cmp_lt_f64_e32 vcc_lo, v[49:50], v[47:48]
	v_dual_cndmask_b32 v48, v48, v50 :: v_dual_cndmask_b32 v47, v47, v49
	v_cndmask_b32_e64 v0, 0, 1, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f64_e32 vcc_lo, v[51:52], v[47:48]
	v_dual_cndmask_b32 v48, v48, v52 :: v_dual_cndmask_b32 v47, v47, v51
	v_cndmask_b32_e64 v0, v0, 2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_nlt_f64_e32 vcc_lo, v[45:46], v[47:48]
	v_cndmask_b32_e32 v0, 3, v0, vcc_lo
	s_cbranch_execz .LBB3_27
; %bb.20:                               ; %.loopexit
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB3_30
.LBB3_21:                               ; %.preheader.1
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_add_i32 m0, s2, 1
	v_movrels_b32_e32 v45, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f64_f32_e32 v[45:46], v45
	v_add_f64 v[47:48], v[45:46], -v[33:34]
	v_add_f64 v[49:50], v[45:46], -v[35:36]
	v_add_f64 v[51:52], v[45:46], -v[37:38]
	v_add_f64 v[45:46], v[45:46], -v[39:40]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[47:48], v[47:48], v[47:48]
	v_mul_f64 v[49:50], v[49:50], v[49:50]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[51:52], v[51:52], v[51:52]
	v_mul_f64 v[45:46], v[45:46], v[45:46]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_min_f64 v[47:48], 0x7ff00000, v[47:48]
	v_cmp_lt_f64_e32 vcc_lo, v[49:50], v[47:48]
	v_dual_cndmask_b32 v48, v48, v50 :: v_dual_cndmask_b32 v47, v47, v49
	v_cndmask_b32_e64 v53, 0, 1, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f64_e32 vcc_lo, v[51:52], v[47:48]
	v_dual_cndmask_b32 v48, v48, v52 :: v_dual_cndmask_b32 v47, v47, v51
	v_cndmask_b32_e64 v49, v53, 2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_nlt_f64_e32 vcc_lo, v[45:46], v[47:48]
	v_cndmask_b32_e32 v45, 3, v49, vcc_lo
	s_cbranch_execz .LBB3_31
; %bb.22:                               ; %.loopexit.1
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB3_34
.LBB3_23:                               ; %.preheader.2
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_add_i32 m0, s2, 2
	v_movrels_b32_e32 v46, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f64_f32_e32 v[46:47], v46
	v_add_f64 v[48:49], v[46:47], -v[33:34]
	v_add_f64 v[50:51], v[46:47], -v[35:36]
	v_add_f64 v[52:53], v[46:47], -v[37:38]
	v_add_f64 v[46:47], v[46:47], -v[39:40]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[48:49], v[48:49], v[48:49]
	v_mul_f64 v[50:51], v[50:51], v[50:51]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[52:53], v[52:53], v[52:53]
	v_mul_f64 v[46:47], v[46:47], v[46:47]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_min_f64 v[48:49], 0x7ff00000, v[48:49]
	v_cmp_lt_f64_e32 vcc_lo, v[50:51], v[48:49]
	v_dual_cndmask_b32 v49, v49, v51 :: v_dual_cndmask_b32 v48, v48, v50
	v_cndmask_b32_e64 v54, 0, 1, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f64_e32 vcc_lo, v[52:53], v[48:49]
	v_dual_cndmask_b32 v49, v49, v53 :: v_dual_cndmask_b32 v48, v48, v52
	v_cndmask_b32_e64 v50, v54, 2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_nlt_f64_e32 vcc_lo, v[46:47], v[48:49]
	v_cndmask_b32_e32 v46, 3, v50, vcc_lo
	s_cbranch_execz .LBB3_35
; %bb.24:                               ; %.loopexit.2
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB3_38
.LBB3_25:                               ; %.preheader.3
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_add_i32 m0, s2, 3
	v_movrels_b32_e32 v47, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f64_f32_e32 v[47:48], v47
	v_add_f64 v[49:50], v[47:48], -v[33:34]
	v_add_f64 v[51:52], v[47:48], -v[35:36]
	v_add_f64 v[53:54], v[47:48], -v[37:38]
	v_add_f64 v[47:48], v[47:48], -v[39:40]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[49:50], v[49:50], v[49:50]
	v_mul_f64 v[51:52], v[51:52], v[51:52]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_mul_f64 v[53:54], v[53:54], v[53:54]
	v_mul_f64 v[47:48], v[47:48], v[47:48]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_min_f64 v[49:50], 0x7ff00000, v[49:50]
	v_cmp_lt_f64_e32 vcc_lo, v[51:52], v[49:50]
	v_dual_cndmask_b32 v50, v50, v52 :: v_dual_cndmask_b32 v49, v49, v51
	v_cndmask_b32_e64 v55, 0, 1, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_lt_f64_e32 vcc_lo, v[53:54], v[49:50]
	v_dual_cndmask_b32 v50, v50, v54 :: v_dual_cndmask_b32 v49, v49, v53
	v_cndmask_b32_e64 v51, v55, 2, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cmp_nlt_f64_e32 vcc_lo, v[47:48], v[49:50]
	v_cndmask_b32_e32 v47, 3, v51, vcc_lo
	s_cbranch_execnz .LBB3_17
	s_branch .LBB3_39
.LBB3_26:                               ;   in Loop: Header=BB3_18 Depth=1
                                        ; implicit-def: $vgpr0
.LBB3_27:                               ;   in Loop: Header=BB3_18 Depth=1
	v_mov_b32_e32 v0, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB3_29
; %bb.28:                               ;   in Loop: Header=BB3_18 Depth=1
	s_mov_b32 m0, s2
	v_movrels_b32_e32 v0, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v0, v0, v43
	v_div_scale_f32 v45, null, v44, v44, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v46, v45
	v_fma_f32 v47, -v45, v46, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v46, v47, v46
	v_div_scale_f32 v47, vcc_lo, v0, v44, v0
	v_mul_f32_e32 v48, v47, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v49, -v45, v48, v47
	v_fmac_f32_e32 v48, v49, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v45, -v45, v48, v47
	v_div_fmas_f32 v45, v45, v46, v48
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v0, v45, v44, v0
	v_rndne_f32_e32 v0, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v0, v0, 0, 0x40400000
	v_cvt_u32_f32_e32 v0, v0
.LBB3_29:                               ; %Flow145
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccz .LBB3_21
.LBB3_30:                               ;   in Loop: Header=BB3_18 Depth=1
                                        ; implicit-def: $vgpr45
.LBB3_31:                               ;   in Loop: Header=BB3_18 Depth=1
	v_mov_b32_e32 v45, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB3_33
; %bb.32:                               ;   in Loop: Header=BB3_18 Depth=1
	s_add_i32 m0, s2, 1
	v_movrels_b32_e32 v45, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v45, v45, v43
	v_div_scale_f32 v46, null, v44, v44, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v47, v46
	v_fma_f32 v48, -v46, v47, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v47, v48, v47
	v_div_scale_f32 v48, vcc_lo, v45, v44, v45
	v_mul_f32_e32 v49, v48, v47
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v50, -v46, v49, v48
	v_fmac_f32_e32 v49, v50, v47
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v46, -v46, v49, v48
	v_div_fmas_f32 v46, v46, v47, v49
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v45, v46, v44, v45
	v_rndne_f32_e32 v45, v45
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v45, v45, 0, 0x40400000
	v_cvt_u32_f32_e32 v45, v45
.LBB3_33:                               ; %Flow143
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccz .LBB3_23
.LBB3_34:                               ;   in Loop: Header=BB3_18 Depth=1
                                        ; implicit-def: $vgpr46
.LBB3_35:                               ;   in Loop: Header=BB3_18 Depth=1
	v_mov_b32_e32 v46, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB3_37
; %bb.36:                               ;   in Loop: Header=BB3_18 Depth=1
	s_add_i32 m0, s2, 2
	v_movrels_b32_e32 v46, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v46, v46, v43
	v_div_scale_f32 v47, null, v44, v44, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v48, v47
	v_fma_f32 v49, -v47, v48, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v48, v49, v48
	v_div_scale_f32 v49, vcc_lo, v46, v44, v46
	v_mul_f32_e32 v50, v49, v48
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v51, -v47, v50, v49
	v_fmac_f32_e32 v50, v51, v48
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v47, -v47, v50, v49
	v_div_fmas_f32 v47, v47, v48, v50
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v46, v47, v44, v46
	v_rndne_f32_e32 v46, v46
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v46, v46, 0, 0x40400000
	v_cvt_u32_f32_e32 v46, v46
.LBB3_37:                               ; %Flow141
                                        ;   in Loop: Header=BB3_18 Depth=1
	s_or_b32 exec_lo, exec_lo, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccz .LBB3_25
.LBB3_38:                               ;   in Loop: Header=BB3_18 Depth=1
                                        ; implicit-def: $vgpr47
.LBB3_39:                               ;   in Loop: Header=BB3_18 Depth=1
	v_mov_b32_e32 v47, 0
	s_and_saveexec_b32 s4, s0
	s_cbranch_execz .LBB3_16
; %bb.40:                               ;   in Loop: Header=BB3_18 Depth=1
	s_add_i32 m0, s2, 3
	v_movrels_b32_e32 v47, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_f32_e32 v47, v47, v43
	v_div_scale_f32 v48, null, v44, v44, v47
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v49, v48
	v_fma_f32 v50, -v48, v49, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v49, v50, v49
	v_div_scale_f32 v50, vcc_lo, v47, v44, v47
	v_mul_f32_e32 v51, v50, v49
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v52, -v48, v51, v50
	v_fmac_f32_e32 v51, v52, v49
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fma_f32 v48, -v48, v51, v50
	v_div_fmas_f32 v48, v48, v49, v51
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_div_fixup_f32 v47, v48, v44, v47
	v_rndne_f32_e32 v47, v47
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_maxmin_f32 v47, v47, 0, 0x40400000
	v_cvt_u32_f32_e32 v47, v47
	s_branch .LBB3_16
.LBB3_41:                               ; %.loopexit103
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _ZN8alphabet11flush_valueEPNS_5CacheEPKfii
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
		.amdhsa_next_free_vgpr 56
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
		.amdhsa_inst_pref_size 24
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
	.size	_ZN8alphabet11flush_valueEPNS_5CacheEPKfii, .Lfunc_end3-_ZN8alphabet11flush_valueEPNS_5CacheEPKfii
                                        ; -- End function
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.num_vgpr, 56
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.num_agpr, 0
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.numbered_sgpr, 14
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.num_named_barrier, 0
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.private_seg_size, 0
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.uses_vcc, 1
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.uses_flat_scratch, 0
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.has_dyn_sized_stack, 0
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.has_recursion, 0
	.set _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 2968
; TotalNumSgprs: 16
; NumVgprs: 56
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 6
; NumSGPRsForWavesPerEU: 16
; NumVGPRsForWavesPerEU: 56
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
	s_cbranch_execz .LBB4_2
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
.LBB4_2:
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
.Lfunc_end4:
	.size	_Z8finish_oPKfPf, .Lfunc_end4-_Z8finish_oPKfPf
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
	.section	.text._Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf,"axG",@progbits,_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf,comdat
	.protected	_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf ; -- Begin function _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf
	.globl	_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf
	.p2align	8
	.type	_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf,@function
_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf: ; @_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf
; %bb.0:
	s_load_b32 s24, s[0:1], 0x10
	s_cmp_gt_i32 s2, 7
	s_cselect_b32 s3, -1, 0
	s_waitcnt lgkmcnt(0)
	s_add_i32 s4, s24, 0xfffffeff
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	s_cmp_lt_u32 s4, 0xffffff00
	s_cselect_b32 s4, -1, 0
	s_or_b32 s3, s3, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_and_b32 vcc_lo, exec_lo, s3
	s_cbranch_vccnz .LBB5_2
; %bb.1:
	s_load_b128 s[16:19], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[16:17], 0x4a800
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s3, 0
	s_cbranch_scc0 .LBB5_3
.LBB5_2:                                ; %.loopexit
	s_endpgm
.LBB5_3:                                ; %.preheader234
	s_clause 0x1
	s_load_b128 s[12:15], s[0:1], 0x18
	s_load_b64 s[10:11], s[0:1], 0x28
	s_add_i32 s3, s24, -1
	v_lshlrev_b32_e32 v1, 7, v0
	s_ashr_i32 s0, s3, 31
	s_mul_i32 s28, s2, 0x4a00
	s_lshr_b32 s0, s0, 27
	v_lshl_add_u32 v6, v0, 2, 0x800
	s_add_i32 s30, s3, s0
	v_and_b32_e32 v7, 0xf80, v1
	s_lshr_b32 s29, s30, 5
	v_cmp_gt_u32_e64 s0, s24, v0
	s_and_not1_b32 s30, s30, 31
	s_mul_hi_i32 s27, s2, 0x4a00
	s_mulk_i32 s29, 0x600
	s_add_u32 s25, s16, s28
	s_addc_u32 s26, s17, s27
	s_ashr_i32 s31, s29, 31
	s_lshl_b32 s20, s2, 8
	s_and_saveexec_b32 s1, s0
	s_cbranch_execz .LBB5_11
; %bb.4:
	s_mov_b32 s3, exec_lo
                                        ; implicit-def: $vgpr2
	v_cmpx_le_i32_e64 s30, v0
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB5_7
; %bb.5:                                ; %.preheader232
	v_subrev_nc_u32_e32 v1, s30, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_waitcnt lgkmcnt(0)
	s_add_u32 s6, s12, s4
	s_addc_u32 s7, s13, s5
	s_add_u32 s4, s16, s29
	s_addc_u32 s5, s17, s31
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s4, s4, s28
	s_addc_u32 s5, s5, s27
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s4, v3
	v_add_co_ci_u32_e64 v4, null, s5, v4, vcc_lo
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, vcc_lo, v1, 8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB5_6:                                ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_6
.LBB5_7:                                ; %Flow2064
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s3, s3
	s_cbranch_execz .LBB5_10
; %bb.8:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[20:21], 2
	s_mov_b32 s8, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s6, s25, v1
	v_add_co_ci_u32_e64 v3, null, s26, 0, s6
	s_waitcnt lgkmcnt(0)
	s_add_u32 s6, s12, s4
	s_addc_u32 s7, s13, s5
	s_mov_b64 s[4:5], 0
.LBB5_9:                                ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s8, v7
	s_add_u32 s22, s6, s4
	s_addc_u32 s23, s7, s5
	s_add_i32 s8, s8, 4
	s_load_b128 s[36:39], s[22:23], 0x0
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
	s_cbranch_scc0 .LBB5_9
.LBB5_10:                               ; %Flow2065
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1
.LBB5_11:                               ; %Flow2066
	s_or_b32 exec_lo, exec_lo, s1
	v_add_nc_u32_e32 v9, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_u32_e64 s1, s24, v9
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB5_19
; %bb.12:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s4, exec_lo
	v_cmpx_le_i32_e64 s30, v9
	s_xor_b32 s6, exec_lo, s4
	s_cbranch_execz .LBB5_15
; %bb.13:                               ; %.preheader232.1
	v_subrev_nc_u32_e32 v1, s30, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[4:5], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_waitcnt lgkmcnt(0)
	s_add_u32 s7, s12, s4
	s_addc_u32 s8, s13, s5
	s_add_u32 s4, s16, s29
	s_addc_u32 s5, s17, s31
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s4, s4, s28
	s_addc_u32 s5, s5, s27
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s4, v3
	v_add_co_ci_u32_e64 v4, null, s5, v4, vcc_lo
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, vcc_lo, v1, 8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB5_14:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[10:13], v[3:4], off offset:-8
	s_add_u32 s22, s7, s4
	s_addc_u32 s23, s8, s5
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[22:23], 0x0
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
	s_cbranch_scc0 .LBB5_14
.LBB5_15:                               ; %Flow2059
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s6, s6
	s_cbranch_execz .LBB5_18
; %bb.16:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[4:5], s[20:21], 2
	s_mov_b32 s9, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s7, s25, v1
	v_add_co_ci_u32_e64 v3, null, s26, 0, s7
	s_waitcnt lgkmcnt(0)
	s_add_u32 s7, s12, s4
	s_addc_u32 s8, s13, s5
	s_mov_b64 s[4:5], 0
.LBB5_17:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s9, v7
	s_add_u32 s22, s7, s4
	s_addc_u32 s23, s8, s5
	s_add_i32 s9, s9, 4
	s_load_b128 s[36:39], s[22:23], 0x0
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
	s_cbranch_scc0 .LBB5_17
.LBB5_18:                               ; %Flow2060
	s_or_b32 exec_lo, exec_lo, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:512
.LBB5_19:                               ; %Flow2061
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB5_21
; %bb.20:
	ds_load_b32 v1, v6
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB5_21:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB5_23
; %bb.22:
	ds_load_b32 v2, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB5_23:
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
	s_cbranch_execz .LBB5_25
; %bb.24:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_25:
	s_or_b32 exec_lo, exec_lo, s4
	v_cmp_gt_u32_e64 s4, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB5_27
; %bb.26:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_27:
	s_or_b32 exec_lo, exec_lo, s5
	v_cmp_gt_u32_e64 s5, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s5
	s_cbranch_execz .LBB5_29
; %bb.28:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_29:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB5_31
; %bb.30:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_31:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB5_33
; %bb.32:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_33:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_gt_u32_e64 s8, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB5_35
; %bb.34:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_35:
	s_or_b32 exec_lo, exec_lo, s9
	v_cmp_eq_u32_e64 s9, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s9
	s_cbranch_execz .LBB5_37
; %bb.36:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_37:
	s_or_b32 exec_lo, exec_lo, s21
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s21, s0
	s_cbranch_execz .LBB5_39
; %bb.38:
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
.LBB5_39:
	s_or_b32 exec_lo, exec_lo, s21
	s_and_saveexec_b32 s21, s1
	s_cbranch_execz .LBB5_41
; %bb.40:
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
.LBB5_41:
	s_or_b32 exec_lo, exec_lo, s21
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s3
	s_cbranch_execz .LBB5_43
; %bb.42:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_43:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s4
	s_cbranch_execz .LBB5_45
; %bb.44:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_45:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s5
	s_cbranch_execz .LBB5_47
; %bb.46:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_47:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s6
	s_cbranch_execz .LBB5_49
; %bb.48:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_49:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s7
	s_cbranch_execz .LBB5_51
; %bb.50:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_51:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s8
	s_cbranch_execz .LBB5_53
; %bb.52:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_53:
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s21, s9
	s_cbranch_execz .LBB5_55
; %bb.54:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_55:
	s_or_b32 exec_lo, exec_lo, s21
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s21, s0
	s_cbranch_execz .LBB5_57
; %bb.56:
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
.LBB5_57:
	s_or_b32 exec_lo, exec_lo, s21
	s_and_saveexec_b32 s21, s1
	s_cbranch_execz .LBB5_59
; %bb.58:
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
.LBB5_59:                               ; %.preheader234.1
	s_or_b32 exec_lo, exec_lo, s21
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s33, s0
	s_cbranch_execz .LBB5_67
; %bb.60:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s21, exec_lo
	v_cmpx_le_i32_e64 s30, v0
	s_xor_b32 s34, exec_lo, s21
	s_cbranch_execz .LBB5_63
; %bb.61:                               ; %.preheader232.1270
	v_subrev_nc_u32_e32 v1, s30, v0
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[22:23], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s21, s12, s22
	s_addc_u32 s35, s13, s23
	s_add_u32 s22, s16, s29
	s_addc_u32 s23, s17, s31
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s22, s22, s28
	s_addc_u32 s23, s23, s27
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s22, v3
	v_add_co_ci_u32_e64 v4, null, s23, v4, vcc_lo
	s_mov_b64 s[22:23], 0
	v_add_co_u32 v3, vcc_lo, v1, 14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB5_62:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[10:13], v[3:4], off offset:-14
	s_add_u32 s36, s21, s22
	s_addc_u32 s37, s35, s23
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[36:37], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s22, s22, 32
	s_addc_u32 s23, s23, 0
	s_cmpk_eq_i32 s22, 0x200
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
	s_cbranch_scc0 .LBB5_62
.LBB5_63:                               ; %Flow2054
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s34, s34
	s_cbranch_execz .LBB5_66
; %bb.64:
	v_lshrrev_b32_e32 v1, 5, v0
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[22:23], s[20:21], 2
	s_mov_b32 s36, 0
	v_mul_u32_u24_e32 v1, 0x600, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, s21, s25, v1
	v_add_co_ci_u32_e64 v3, null, s26, 0, s21
	s_add_u32 s21, s12, s22
	s_addc_u32 s35, s13, s23
	s_mov_b64 s[22:23], 0
.LBB5_65:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s36, v7
	s_add_u32 s38, s21, s22
	s_addc_u32 s39, s35, s23
	s_add_i32 s36, s36, 4
	s_load_b128 s[40:43], s[38:39], 0x200
	v_lshrrev_b32_e32 v4, 2, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v10, vcc_lo, v1, v4
	v_add_co_ci_u32_e64 v11, null, 0, v3, vcc_lo
	global_load_d16_u8 v4, v[10:11], off
	v_add_co_u32 v10, vcc_lo, v1, s22
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v11, null, s23, v3, vcc_lo
	s_add_u32 s22, s22, 16
	s_addc_u32 s23, s23, 0
	s_cmpk_eq_i32 s22, 0x200
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
	v_fmac_f32_e32 v2, s40, v10
	v_fma_mix_f32 v10, v11, v15, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v11, v12, v14, v12 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s41, v10
	v_fmac_f32_e32 v2, s42, v11
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s43, v4
	s_cbranch_scc0 .LBB5_65
.LBB5_66:                               ; %Flow2055
	s_or_b32 exec_lo, exec_lo, s34
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1024
.LBB5_67:                               ; %Flow2056
	s_or_b32 exec_lo, exec_lo, s33
	s_and_saveexec_b32 s33, s1
	s_cbranch_execz .LBB5_76
; %bb.68:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s21, exec_lo
	v_cmpx_le_i32_e64 s30, v9
	s_xor_b32 s34, exec_lo, s21
	s_cbranch_execz .LBB5_72
; %bb.69:                               ; %.preheader232.1.1
	v_subrev_nc_u32_e32 v1, s30, v9
	v_mov_b32_e32 v2, 0
	s_ashr_i32 s21, s20, 31
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(VALU_DEP_2)
	s_lshl_b64 s[22:23], s[20:21], 2
	v_lshlrev_b32_e32 v1, 7, v1
	s_add_u32 s21, s12, s22
	s_addc_u32 s30, s13, s23
	s_add_u32 s22, s16, s29
	s_addc_u32 s23, s17, s31
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	s_add_u32 s22, s22, s28
	s_addc_u32 s23, s23, s27
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, s22, v3
	v_add_co_ci_u32_e64 v4, null, s23, v4, vcc_lo
	s_mov_b64 s[22:23], 0
	v_add_co_u32 v3, vcc_lo, v1, 14
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB5_70:                               ; =>This Inner Loop Header: Depth=1
	global_load_b128 v[9:12], v[3:4], off offset:-14
	s_add_u32 s28, s21, s22
	s_addc_u32 s29, s30, s23
	v_add_co_u32 v3, vcc_lo, v3, 16
	s_load_b256 s[36:43], s[28:29], 0x200
	v_add_co_ci_u32_e64 v4, null, 0, v4, vcc_lo
	s_add_u32 s22, s22, 32
	s_addc_u32 s23, s23, 0
	s_cmpk_eq_i32 s22, 0x200
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
	s_cbranch_scc0 .LBB5_70
; %bb.71:                               ; %Flow2047
	s_set_inst_prefetch_distance 0x2
                                        ; implicit-def: $vgpr7
                                        ; implicit-def: $vgpr9
.LBB5_72:                               ; %Flow2049
	s_and_not1_saveexec_b32 s22, s34
	s_cbranch_execz .LBB5_75
; %bb.73:
	v_lshrrev_b32_e32 v1, 5, v9
	s_ashr_i32 s21, s20, 31
	v_mov_b32_e32 v2, 0
	s_lshl_b64 s[28:29], s[20:21], 2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_u32_u24_e32 v1, 0x600, v1
	v_add_co_u32 v1, s21, s25, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v3, null, s26, 0, s21
	s_add_u32 s21, s12, s28
	s_addc_u32 s23, s13, s29
	s_mov_b32 s25, 0
	s_mov_b64 s[12:13], 0
.LBB5_74:                               ; =>This Inner Loop Header: Depth=1
	v_or_b32_e32 v4, s25, v7
	s_add_u32 s26, s21, s12
	s_addc_u32 s27, s23, s13
	s_add_i32 s25, s25, 4
	s_load_b128 s[28:31], s[26:27], 0x200
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
	v_fmac_f32_e32 v2, s28, v9
	v_fma_mix_f32 v9, v10, v14, v10 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	v_fma_mix_f32 v10, v11, v13, v11 op_sel:[1,0,0] op_sel_hi:[1,0,1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, s29, v9
	v_fmac_f32_e32 v2, s30, v10
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v2, s31, v4
	s_cbranch_scc0 .LBB5_74
.LBB5_75:                               ; %Flow2050
	s_or_b32 exec_lo, exec_lo, s22
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1536
.LBB5_76:                               ; %Flow2051
	s_or_b32 exec_lo, exec_lo, s33
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB5_78
; %bb.77:
	ds_load_b32 v1, v6 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB5_78:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB5_80
; %bb.79:
	ds_load_b32 v2, v6 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB5_80:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB5_82
; %bb.81:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_82:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s4
	s_cbranch_execz .LBB5_84
; %bb.83:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_84:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s5
	s_cbranch_execz .LBB5_86
; %bb.85:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_86:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s6
	s_cbranch_execz .LBB5_88
; %bb.87:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_88:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s7
	s_cbranch_execz .LBB5_90
; %bb.89:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_90:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s8
	s_cbranch_execz .LBB5_92
; %bb.91:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_92:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s9
	s_cbranch_execz .LBB5_94
; %bb.93:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB5_94:
	s_or_b32 exec_lo, exec_lo, s12
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB5_96
; %bb.95:
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
.LBB5_96:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB5_98
; %bb.97:
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
.LBB5_98:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB5_100
; %bb.99:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_100:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s4
	s_cbranch_execz .LBB5_102
; %bb.101:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_102:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s5
	s_cbranch_execz .LBB5_104
; %bb.103:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_104:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s6
	s_cbranch_execz .LBB5_106
; %bb.105:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_106:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s7
	s_cbranch_execz .LBB5_108
; %bb.107:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_108:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s8
	s_cbranch_execz .LBB5_110
; %bb.109:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_110:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s9
	s_cbranch_execz .LBB5_112
; %bb.111:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB5_112:
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB5_114
; %bb.113:
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
.LBB5_114:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB5_116
; %bb.115:
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
.LBB5_116:                              ; %.preheader230
	s_or_b32 exec_lo, exec_lo, s0
	v_dual_mov_b32 v3, 0 :: v_dual_lshlrev_b32 v4, 1, v0
	v_lshrrev_b32_e32 v2, 3, v0
	s_max_i32 s4, s24, 33
	s_waitcnt lgkmcnt(0)
	v_lshrrev_b32_e32 v1, 2, v0
	s_sub_i32 s3, s4, 33
	v_and_b32_e32 v6, 6, v4
	v_and_b32_e32 v2, 0x7c, v2
	s_cmp_gt_u32 s24, 33
	s_cselect_b32 s5, -1, 0
	s_cmp_lt_u32 s24, 34
	s_barrier
	buffer_gl0_inv
	s_cbranch_scc1 .LBB5_124
; %bb.117:                              ; %.lr.ph.preheader
	s_sub_i32 s0, s4, 34
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lt_u32 s0, 3
	s_cbranch_scc1 .LBB5_120
; %bb.118:                              ; %.lr.ph.preheader.new
	s_mul_i32 s1, s2, 0x2a00
	v_mov_b32_e32 v3, 0
	s_and_b32 s0, s3, -4
	s_mul_hi_i32 s6, s2, 0x2a00
	s_add_u32 s1, s16, s1
	s_addc_u32 s6, s17, s6
	s_mov_b32 s7, 0
	s_mov_b32 s8, 0
.LBB5_119:                              ; %.lr.ph
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
	s_clause 0x1
	global_load_u8 v11, v[7:8], off
	global_load_u8 v12, v[7:8], off offset:48
	v_add_co_ci_u32_e64 v10, null, 0, v10, vcc_lo
	s_clause 0x5
	global_load_u8 v13, v[7:8], off offset:96
	global_load_b32 v14, v[9:10], off offset:80
	global_load_b32 v15, v[9:10], off offset:128
	global_load_b32 v16, v[9:10], off offset:176
	global_load_u8 v7, v[7:8], off offset:144
	global_load_b32 v17, v[9:10], off offset:32
	s_add_i32 s8, s8, 4
	s_add_u32 s1, s1, 0xc0
	s_addc_u32 s6, s6, 0
	s_waitcnt vmcnt(7)
	v_bfe_u32 v8, v11, v6, 2
	s_waitcnt vmcnt(6)
	v_bfe_u32 v9, v12, v6, 2
	s_waitcnt vmcnt(4)
	v_cvt_f32_f16_e32 v20, v14.h
	v_bfe_u32 v10, v13, v6, 2
	v_cvt_f32_f16_e32 v14, v14.l
	v_lshlrev_b32_e32 v8, 2, v8
	v_lshlrev_b32_e32 v9, 2, v9
	s_waitcnt vmcnt(1)
	v_bfe_u32 v7, v7, v6, 2
	s_waitcnt vmcnt(0)
	v_cvt_f32_f16_e32 v19, v17.h
	v_cvt_f32_f16_e32 v17, v17.l
	s_clause 0x1
	global_load_b32 v11, v8, s[18:19]
	global_load_b32 v12, v9, s[18:19]
	s_waitcnt vmcnt(1)
	v_dual_mul_f32 v11, v11, v19 :: v_dual_lshlrev_b32 v8, 2, v10
	s_waitcnt vmcnt(0)
	v_dual_mul_f32 v12, v12, v20 :: v_dual_lshlrev_b32 v7, 2, v7
	v_cvt_f32_f16_e32 v19, v15.h
	v_cvt_f32_f16_e32 v15, v15.l
	s_delay_alu instid0(VALU_DEP_3)
	v_dual_add_f32 v11, v11, v17 :: v_dual_add_f32 v12, v12, v14
	s_clause 0x1
	global_load_b32 v13, v8, s[18:19]
	global_load_b32 v18, v7, s[18:19]
	v_mov_b32_e32 v7, s7
	v_cvt_f32_f16_e32 v17, v16.h
	s_add_i32 s7, s7, 16
	s_cmp_eq_u32 s0, s8
	ds_load_b128 v[7:10], v7
	s_waitcnt lgkmcnt(0)
	v_fmac_f32_e32 v3, v7, v11
	v_cvt_f32_f16_e32 v7, v16.l
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_4) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v3, v8, v12
	s_waitcnt vmcnt(1)
	v_mul_f32_e32 v13, v13, v19
	s_waitcnt vmcnt(0)
	v_mul_f32_e32 v11, v18, v17
	v_add_f32_e32 v13, v13, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f32_e32 v7, v11, v7
	v_fmac_f32_e32 v3, v9, v13
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v3, v10, v7
	s_cbranch_scc0 .LBB5_119
	s_branch .LBB5_121
.LBB5_120:
	v_mov_b32_e32 v3, 0
	s_mov_b32 s0, 0
.LBB5_121:                              ; %.preheader228.loopexit.unr-lcssa
	s_and_b32 s1, s3, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc1 .LBB5_124
; %bb.122:                              ; %.lr.ph.epil.preheader
	s_lshl_b32 s6, s0, 2
	s_mul_i32 s0, s0, 48
	s_mul_i32 s7, s2, 0x2a00
	s_add_u32 s0, s16, s0
	s_addc_u32 s8, s17, 0
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
	s_set_inst_prefetch_distance 0x1
	.p2align	6
.LBB5_123:                              ; %.lr.ph.epil
                                        ; =>This Inner Loop Header: Depth=1
	v_add_co_u32 v11, vcc_lo, v9, s0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s1, v10, vcc_lo
	global_load_u8 v13, v[11:12], off
	v_add_co_u32 v11, vcc_lo, v7, s0
	v_add_co_ci_u32_e64 v12, null, s1, v8, vcc_lo
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, vcc_lo, 0x25000, v11
	v_add_co_ci_u32_e64 v12, null, 0, v12, vcc_lo
	global_load_b32 v11, v[11:12], off offset:32
	s_waitcnt vmcnt(1)
	v_bfe_u32 v12, v13, v6, 2
	v_mov_b32_e32 v13, s6
	s_add_i32 s6, s6, 4
	s_add_u32 s0, s0, 48
	s_addc_u32 s1, s1, 0
	v_lshlrev_b32_e32 v12, 2, v12
	s_cmp_lg_u32 s7, s0
	ds_load_b32 v13, v13
	global_load_b32 v12, v12, s[18:19]
	s_waitcnt vmcnt(1)
	v_cvt_f32_f16_e32 v14, v11.h
	v_cvt_f32_f16_e32 v11, v11.l
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v12, v12, v14
	v_add_f32_e32 v11, v12, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v3, v13, v11
	s_cbranch_scc1 .LBB5_123
.LBB5_124:                              ; %.preheader228
	s_set_inst_prefetch_distance 0x2
	s_sub_i32 s0, s24, s3
	s_mul_i32 s7, s2, 0x2100
	s_cmp_gt_i32 s0, 0
	s_mul_hi_i32 s6, s2, 0x2100
	s_cselect_b32 s1, -1, 0
	s_add_u32 s7, s16, s7
	s_addc_u32 s6, s17, s6
	v_add_co_u32 v4, s7, s7, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v8, null, s6, 0, s7
	s_cmp_lt_i32 s0, 1
	v_add_co_u32 v7, vcc_lo, 0x3a000, v4
	v_add_co_ci_u32_e64 v8, null, 0, v8, vcc_lo
	s_mov_b32 s6, 0
	s_cbranch_scc1 .LBB5_131
; %bb.125:                              ; %.lr.ph252.preheader
	s_sub_i32 s7, s24, s4
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s7, s7, 32
	s_cmp_lt_u32 s7, 7
	s_cbranch_scc1 .LBB5_128
; %bb.126:                              ; %.lr.ph252.preheader.new
	s_lshl_b32 s7, s4, 2
	s_and_b32 s6, s0, 0x7ffffff8
	s_addk_i32 s7, 0xff7c
	s_mov_b32 s8, 0
.LBB5_127:                              ; %.lr.ph252
                                        ; =>This Inner Loop Header: Depth=1
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_i32 s9, s4, s8
	s_add_i32 s8, s8, 8
	s_sub_i32 s12, s9, 33
	s_sub_i32 s13, s9, 32
	s_mul_hi_i32 s26, s12, 0x3e0f83e1
	s_mul_hi_i32 s27, s13, 0x3e0f83e1
	s_lshr_b32 s35, s26, 31
	s_lshr_b32 s26, s26, 3
	s_lshr_b32 s36, s27, 31
	s_add_i32 s26, s26, s35
	s_lshr_b32 s27, s27, 3
	s_mul_i32 s26, s26, 33
	s_add_i32 s27, s27, s36
	s_sub_i32 s12, s12, s26
	s_sub_i32 s21, s9, 31
	s_lshl_b32 s12, s12, 8
	s_mul_i32 s27, s27, 33
	s_ashr_i32 s26, s12, 31
	v_add_co_u32 v9, vcc_lo, v7, s12
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s26, v8, vcc_lo
	s_mul_hi_i32 s28, s21, 0x3e0f83e1
	s_sub_i32 s22, s9, 30
	s_sub_i32 s13, s13, s27
	global_load_u16 v4, v[9:10], off
	s_lshr_b32 s37, s28, 31
	s_lshr_b32 s28, s28, 3
	s_mul_hi_i32 s29, s22, 0x3e0f83e1
	s_lshl_b32 s13, s13, 8
	s_add_i32 s28, s28, s37
	s_lshr_b32 s38, s29, 31
	s_lshr_b32 s29, s29, 3
	s_ashr_i32 s27, s13, 31
	v_add_co_u32 v11, vcc_lo, v7, s13
	s_mul_i32 s28, s28, 33
	s_add_i32 s29, s29, s38
	v_add_co_ci_u32_e64 v12, null, s27, v8, vcc_lo
	s_sub_i32 s23, s9, 29
	s_sub_i32 s21, s21, s28
	s_mul_i32 s29, s29, 33
	s_mul_hi_i32 s30, s23, 0x3e0f83e1
	s_lshl_b32 s21, s21, 8
	s_sub_i32 s24, s9, 28
	s_sub_i32 s22, s22, s29
	s_lshr_b32 s39, s30, 31
	s_lshr_b32 s30, s30, 3
	s_ashr_i32 s28, s21, 31
	global_load_u16 v17, v[11:12], off
	v_add_co_u32 v9, vcc_lo, v7, s21
	s_mul_hi_i32 s31, s24, 0x3e0f83e1
	s_lshl_b32 s22, s22, 8
	s_add_i32 s30, s30, s39
	v_add_co_ci_u32_e64 v10, null, s28, v8, vcc_lo
	s_lshr_b32 s40, s31, 31
	s_lshr_b32 s31, s31, 3
	s_ashr_i32 s29, s22, 31
	v_add_co_u32 v11, vcc_lo, v7, s22
	s_mul_i32 s30, s30, 33
	s_add_i32 s31, s31, s40
	v_add_co_ci_u32_e64 v12, null, s29, v8, vcc_lo
	s_sub_i32 s25, s9, 27
	s_sub_i32 s23, s23, s30
	s_mul_i32 s31, s31, 33
	s_clause 0x1
	global_load_u16 v18, v[9:10], off
	global_load_u16 v19, v[11:12], off
	s_sub_i32 s9, s9, 26
	s_mul_hi_i32 s33, s25, 0x3e0f83e1
	s_lshl_b32 s23, s23, 8
	s_sub_i32 s24, s24, s31
	s_mul_hi_i32 s34, s9, 0x3e0f83e1
	s_lshr_b32 s41, s33, 31
	s_lshr_b32 s33, s33, 3
	s_ashr_i32 s30, s23, 31
	v_add_co_u32 v9, vcc_lo, v7, s23
	s_lshl_b32 s24, s24, 8
	s_lshr_b32 s42, s34, 31
	s_lshr_b32 s34, s34, 3
	s_add_i32 s33, s33, s41
	v_add_co_ci_u32_e64 v10, null, s30, v8, vcc_lo
	s_ashr_i32 s31, s24, 31
	v_add_co_u32 v11, vcc_lo, v7, s24
	s_add_i32 s34, s34, s42
	s_mul_i32 s33, s33, 33
	v_add_co_ci_u32_e64 v12, null, s31, v8, vcc_lo
	s_mul_i32 s34, s34, 33
	s_sub_i32 s25, s25, s33
	s_clause 0x1
	global_load_u16 v20, v[9:10], off
	global_load_u16 v21, v[11:12], off
	s_sub_i32 s9, s9, s34
	s_lshl_b32 s25, s25, 8
	s_lshl_b32 s9, s9, 8
	s_ashr_i32 s33, s25, 31
	v_add_co_u32 v9, vcc_lo, v7, s25
	s_ashr_i32 s34, s9, 31
	v_add_co_ci_u32_e64 v10, null, s33, v8, vcc_lo
	v_add_co_u32 v11, vcc_lo, v7, s9
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v12, null, s34, v8, vcc_lo
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
	s_cbranch_scc0 .LBB5_127
.LBB5_128:                              ; %._crit_edge.loopexit.unr-lcssa
	s_and_b32 s7, s0, 7
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s7, 0
	s_cbranch_scc1 .LBB5_131
; %bb.129:                              ; %.lr.ph252.epil.preheader
	s_add_i32 s8, s6, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_lshl_b32 s6, s8, 2
	s_sub_i32 s8, s8, 33
	s_addk_i32 s6, 0xff7c
	.p2align	6
.LBB5_130:                              ; %.lr.ph252.epil
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
	s_cbranch_scc1 .LBB5_130
.LBB5_131:                              ; %._crit_edge
	v_mov_b32_e32 v9, 0
	s_and_not1_b32 vcc_lo, exec_lo, s5
	ds_store_b32 v5, v3 offset:4096
	s_cbranch_vccnz .LBB5_134
; %bb.132:                              ; %.lr.ph.1.preheader
	s_mul_i32 s5, s2, 0x2a00
	s_mul_hi_i32 s6, s2, 0x2a00
	s_add_u32 s5, s16, s5
	s_addc_u32 s6, s17, s6
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
.LBB5_133:                              ; %.lr.ph.1
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
	s_waitcnt vmcnt(0)
	v_cvt_f32_f16_e32 v13, v11.h
	v_cvt_f32_f16_e32 v11, v11.l
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v10, 2, v10
	global_load_b32 v10, v10, s[18:19]
	s_waitcnt vmcnt(0)
	v_mul_f32_e32 v10, v10, v13
	v_add_f32_e32 v10, v10, v11
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v9, v12, v10
	s_cbranch_scc1 .LBB5_133
.LBB5_134:                              ; %Flow2036
	v_or_b32_e32 v1, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB5_137
; %bb.135:                              ; %.lr.ph252.1.preheader
	s_lshl_b32 s1, s4, 2
	s_mov_b32 s4, 0
	s_addk_i32 s1, 0x37c
	.p2align	6
.LBB5_136:                              ; %.lr.ph252.1
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
	s_cbranch_scc1 .LBB5_136
.LBB5_137:                              ; %._crit_edge.1
	v_lshlrev_b32_e32 v2, 12, v0
	ds_store_b32 v1, v9 offset:512
	v_mov_b32_e32 v1, 0
	s_ashr_i32 s21, s20, 31
	s_mov_b64 s[4:5], 0
	v_add_co_u32 v3, s0, s14, v2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v4, null, s15, 0, s0
	s_lshl_b64 s[0:1], s[20:21], 1
	s_movk_i32 s3, 0x1000
	v_add_co_u32 v3, vcc_lo, v3, s0
	v_add_co_ci_u32_e64 v4, null, s1, v4, vcc_lo
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
.LBB5_138:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB5_138
; %bb.139:                              ; %.preheader.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[4:5], 0
.LBB5_140:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_140
; %bb.141:                              ; %.preheader.1290
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
.LBB5_142:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_142
; %bb.143:                              ; %.preheader.1.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[0:1], 0
.LBB5_144:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_144
; %bb.145:                              ; %.preheader.2
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
.LBB5_146:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_146
; %bb.147:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB5_148:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_148
; %bb.149:                              ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:1024
.LBB5_150:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_150
; %bb.151:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB5_152:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_152
; %bb.153:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:1536
.LBB5_154:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_154
; %bb.155:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB5_156:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_156
; %bb.157:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:2048
.LBB5_158:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_158
; %bb.159:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB5_160:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_160
; %bb.161:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:2560
.LBB5_162:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_162
; %bb.163:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB5_164:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_164
; %bb.165:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:3072
.LBB5_166:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_166
; %bb.167:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB5_168:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB5_168
; %bb.169:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf
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
	.section	.text._Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf,"axG",@progbits,_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf,comdat
.Lfunc_end5:
	.size	_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf, .Lfunc_end5-_Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf
                                        ; -- End function
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.num_vgpr, 24
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.num_agpr, 0
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.numbered_sgpr, 44
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.num_named_barrier, 0
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.private_seg_size, 0
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.uses_vcc, 1
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.uses_flat_scratch, 0
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.has_dyn_sized_stack, 0
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.has_recursion, 0
	.set _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 13852
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
; WaveLimiterHint : 1
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 2
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.section	.text._Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf,"axG",@progbits,_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf,comdat
	.protected	_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf ; -- Begin function _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf
	.globl	_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf
	.p2align	8
	.type	_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf,@function
_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf: ; @_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf
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
	s_cbranch_vccnz .LBB6_2
; %bb.1:
	s_load_b64 s[18:19], s[0:1], 0x0
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[18:19], 0x4a800
	s_waitcnt lgkmcnt(0)
	s_cmp_lg_u32 s3, 0
	s_cbranch_scc0 .LBB6_3
.LBB6_2:                                ; %.loopexit
	s_endpgm
.LBB6_3:                                ; %.preheader232
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
	s_cbranch_execz .LBB6_11
; %bb.4:
	s_mov_b32 s3, exec_lo
                                        ; implicit-def: $vgpr2
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB6_7
; %bb.5:                                ; %.preheader230
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
.LBB6_6:                                ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_6
.LBB6_7:                                ; %Flow2058
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s3, s3
	s_cbranch_execz .LBB6_10
; %bb.8:
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
.LBB6_9:                                ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_9
.LBB6_10:                               ; %Flow2059
	s_or_b32 exec_lo, exec_lo, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1
.LBB6_11:                               ; %Flow2060
	s_or_b32 exec_lo, exec_lo, s1
	v_add_nc_u32_e32 v9, 0x80, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_cmp_gt_u32_e64 s1, s22, v9
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB6_19
; %bb.12:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s4, exec_lo
	v_cmpx_le_i32_e64 s28, v9
	s_xor_b32 s6, exec_lo, s4
	s_cbranch_execz .LBB6_15
; %bb.13:                               ; %.preheader230.1
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
.LBB6_14:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_14
.LBB6_15:                               ; %Flow2053
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s6, s6
	s_cbranch_execz .LBB6_18
; %bb.16:
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
.LBB6_17:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_17
.LBB6_18:                               ; %Flow2054
	s_or_b32 exec_lo, exec_lo, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:512
.LBB6_19:                               ; %Flow2055
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB6_21
; %bb.20:
	ds_load_b32 v1, v6
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB6_21:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s3, s1
	s_cbranch_execz .LBB6_23
; %bb.22:
	ds_load_b32 v2, v6 offset:512
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB6_23:
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
	s_cbranch_execz .LBB6_25
; %bb.24:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_25:
	s_or_b32 exec_lo, exec_lo, s4
	v_cmp_gt_u32_e64 s4, 32, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s5, s4
	s_cbranch_execz .LBB6_27
; %bb.26:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_27:
	s_or_b32 exec_lo, exec_lo, s5
	v_cmp_gt_u32_e64 s5, 16, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s6, s5
	s_cbranch_execz .LBB6_29
; %bb.28:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_29:
	s_or_b32 exec_lo, exec_lo, s6
	v_cmp_gt_u32_e64 s6, 8, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s7, s6
	s_cbranch_execz .LBB6_31
; %bb.30:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_31:
	s_or_b32 exec_lo, exec_lo, s7
	v_cmp_gt_u32_e64 s7, 4, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s8, s7
	s_cbranch_execz .LBB6_33
; %bb.32:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_33:
	s_or_b32 exec_lo, exec_lo, s8
	v_cmp_gt_u32_e64 s8, 2, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s9, s8
	s_cbranch_execz .LBB6_35
; %bb.34:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_35:
	s_or_b32 exec_lo, exec_lo, s9
	v_cmp_eq_u32_e64 s9, 0, v0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s9
	s_cbranch_execz .LBB6_37
; %bb.36:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_37:
	s_or_b32 exec_lo, exec_lo, s17
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s17, s0
	s_cbranch_execz .LBB6_39
; %bb.38:
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
.LBB6_39:
	s_or_b32 exec_lo, exec_lo, s17
	s_and_saveexec_b32 s17, s1
	s_cbranch_execz .LBB6_41
; %bb.40:
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
.LBB6_41:
	s_or_b32 exec_lo, exec_lo, s17
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s3
	s_cbranch_execz .LBB6_43
; %bb.42:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_43:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s4
	s_cbranch_execz .LBB6_45
; %bb.44:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_45:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s5
	s_cbranch_execz .LBB6_47
; %bb.46:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_47:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s6
	s_cbranch_execz .LBB6_49
; %bb.48:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_49:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s7
	s_cbranch_execz .LBB6_51
; %bb.50:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_51:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s8
	s_cbranch_execz .LBB6_53
; %bb.52:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_53:
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s17, s9
	s_cbranch_execz .LBB6_55
; %bb.54:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_55:
	s_or_b32 exec_lo, exec_lo, s17
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s17, s0
	s_cbranch_execz .LBB6_57
; %bb.56:
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
.LBB6_57:
	s_or_b32 exec_lo, exec_lo, s17
	s_and_saveexec_b32 s17, s1
	s_cbranch_execz .LBB6_59
; %bb.58:
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
.LBB6_59:                               ; %.preheader232.1
	s_or_b32 exec_lo, exec_lo, s17
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s30, s0
	s_cbranch_execz .LBB6_67
; %bb.60:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s17, exec_lo
	v_cmpx_le_i32_e64 s28, v0
	s_xor_b32 s31, exec_lo, s17
	s_cbranch_execz .LBB6_63
; %bb.61:                               ; %.preheader230.1268
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
.LBB6_62:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_62
.LBB6_63:                               ; %Flow2048
	s_set_inst_prefetch_distance 0x2
	s_and_not1_saveexec_b32 s31, s31
	s_cbranch_execz .LBB6_66
; %bb.64:
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
.LBB6_65:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_65
.LBB6_66:                               ; %Flow2049
	s_or_b32 exec_lo, exec_lo, s31
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1024
.LBB6_67:                               ; %Flow2050
	s_or_b32 exec_lo, exec_lo, s30
	s_and_saveexec_b32 s30, s1
	s_cbranch_execz .LBB6_76
; %bb.68:
                                        ; implicit-def: $vgpr2
	s_mov_b32 s17, exec_lo
	v_cmpx_le_i32_e64 s28, v9
	s_xor_b32 s31, exec_lo, s17
	s_cbranch_execz .LBB6_72
; %bb.69:                               ; %.preheader230.1.1
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
.LBB6_70:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_70
; %bb.71:                               ; %Flow2041
	s_set_inst_prefetch_distance 0x2
                                        ; implicit-def: $vgpr7
                                        ; implicit-def: $vgpr9
.LBB6_72:                               ; %Flow2043
	s_and_not1_saveexec_b32 s20, s31
	s_cbranch_execz .LBB6_75
; %bb.73:
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
.LBB6_74:                               ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_74
.LBB6_75:                               ; %Flow2044
	s_or_b32 exec_lo, exec_lo, s20
	s_delay_alu instid0(VALU_DEP_1)
	v_mul_f32_e32 v1, 0x3db504f3, v2
	ds_store_b32 v6, v1 offset:1536
.LBB6_76:                               ; %Flow2045
	s_or_b32 exec_lo, exec_lo, s30
	v_mov_b32_e32 v1, 0xff800000
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB6_78
; %bb.77:
	ds_load_b32 v1, v6 offset:1024
	s_waitcnt lgkmcnt(0)
	v_max_f32_e32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, 0xff800000, v1
.LBB6_78:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB6_80
; %bb.79:
	ds_load_b32 v2, v6 offset:1536
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v1, v1, v1 :: v_dual_max_f32 v2, v2, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
.LBB6_80:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB6_82
; %bb.81:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_82:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s4
	s_cbranch_execz .LBB6_84
; %bb.83:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_84:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s5
	s_cbranch_execz .LBB6_86
; %bb.85:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_86:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s6
	s_cbranch_execz .LBB6_88
; %bb.87:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_88:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s7
	s_cbranch_execz .LBB6_90
; %bb.89:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_90:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s8
	s_cbranch_execz .LBB6_92
; %bb.91:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_92:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s9
	s_cbranch_execz .LBB6_94
; %bb.93:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_dual_max_f32 v2, v2, v2 :: v_dual_max_f32 v1, v1, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_max_f32_e32 v1, v1, v2
	ds_store_b32 v8, v1
.LBB6_94:
	s_or_b32 exec_lo, exec_lo, s12
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v2, v1 offset:5120
	s_and_saveexec_b32 s12, s0
	s_cbranch_execz .LBB6_96
; %bb.95:
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
.LBB6_96:
	s_or_b32 exec_lo, exec_lo, s12
	s_and_saveexec_b32 s12, s1
	s_cbranch_execz .LBB6_98
; %bb.97:
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
.LBB6_98:
	s_or_b32 exec_lo, exec_lo, s12
	ds_store_b32 v8, v1
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s12, s3
	s_cbranch_execz .LBB6_100
; %bb.99:
	ds_load_2addr_stride64_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_100:
	s_or_b32 exec_lo, exec_lo, s12
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s4
	s_cbranch_execz .LBB6_102
; %bb.101:
	ds_load_2addr_b32 v[1:2], v8 offset1:32
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_102:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s5
	s_cbranch_execz .LBB6_104
; %bb.103:
	ds_load_2addr_b32 v[1:2], v8 offset1:16
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_104:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s6
	s_cbranch_execz .LBB6_106
; %bb.105:
	ds_load_2addr_b32 v[1:2], v8 offset1:8
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_106:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s7
	s_cbranch_execz .LBB6_108
; %bb.107:
	ds_load_2addr_b32 v[1:2], v8 offset1:4
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_108:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s8
	s_cbranch_execz .LBB6_110
; %bb.109:
	ds_load_2addr_b32 v[1:2], v8 offset1:2
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_110:
	s_or_b32 exec_lo, exec_lo, s3
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_and_saveexec_b32 s3, s9
	s_cbranch_execz .LBB6_112
; %bb.111:
	ds_load_2addr_b32 v[1:2], v8 offset1:1
	s_waitcnt lgkmcnt(0)
	v_add_f32_e32 v1, v2, v1
	ds_store_b32 v8, v1
.LBB6_112:
	s_or_b32 exec_lo, exec_lo, s3
	v_mov_b32_e32 v1, 0
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v1, v1 offset:5120
	s_and_saveexec_b32 s3, s0
	s_cbranch_execz .LBB6_114
; %bb.113:
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
.LBB6_114:
	s_or_b32 exec_lo, exec_lo, s3
	s_and_saveexec_b32 s0, s1
	s_cbranch_execz .LBB6_116
; %bb.115:
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
.LBB6_116:                              ; %.preheader228
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
	s_cbranch_scc1 .LBB6_124
; %bb.117:                              ; %.lr.ph.preheader
	s_sub_i32 s0, s4, 34
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_lt_u32 s0, 3
	s_cbranch_scc1 .LBB6_120
; %bb.118:                              ; %.lr.ph.preheader.new
	s_mul_i32 s1, s2, 0x2a00
	v_mov_b32_e32 v3, 0
	s_and_b32 s0, s3, -4
	s_mul_hi_i32 s6, s2, 0x2a00
	s_add_u32 s1, s18, s1
	s_addc_u32 s6, s19, s6
	s_mov_b32 s7, 0
	s_mov_b32 s8, 0
.LBB6_119:                              ; %.lr.ph
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
	s_cbranch_scc0 .LBB6_119
	s_branch .LBB6_121
.LBB6_120:
	v_mov_b32_e32 v3, 0
	s_mov_b32 s0, 0
.LBB6_121:                              ; %.preheader226.loopexit.unr-lcssa
	s_and_b32 s1, s3, 3
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s1, 0
	s_cbranch_scc1 .LBB6_124
; %bb.122:                              ; %.lr.ph.epil.preheader
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
.LBB6_123:                              ; %.lr.ph.epil
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
	s_cbranch_scc1 .LBB6_123
.LBB6_124:                              ; %.preheader226
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
	s_cbranch_scc1 .LBB6_131
; %bb.125:                              ; %.lr.ph250.preheader
	s_sub_i32 s7, s22, s4
	s_delay_alu instid0(SALU_CYCLE_1) | instskip(NEXT) | instid1(SALU_CYCLE_1)
	s_add_i32 s7, s7, 32
	s_cmp_lt_u32 s7, 7
	s_cbranch_scc1 .LBB6_128
; %bb.126:                              ; %.lr.ph250.preheader.new
	s_lshl_b32 s7, s4, 2
	s_and_b32 s6, s0, 0x7ffffff8
	s_addk_i32 s7, 0xff7c
	s_mov_b32 s8, 0
.LBB6_127:                              ; %.lr.ph250
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
	s_cbranch_scc0 .LBB6_127
.LBB6_128:                              ; %._crit_edge.loopexit.unr-lcssa
	s_and_b32 s7, s0, 7
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmp_eq_u32 s7, 0
	s_cbranch_scc1 .LBB6_131
; %bb.129:                              ; %.lr.ph250.epil.preheader
	s_add_i32 s8, s6, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_lshl_b32 s6, s8, 2
	s_sub_i32 s8, s8, 33
	s_addk_i32 s6, 0xff7c
	.p2align	6
.LBB6_130:                              ; %.lr.ph250.epil
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
	s_cbranch_scc1 .LBB6_130
.LBB6_131:                              ; %._crit_edge
	v_mov_b32_e32 v9, 0
	s_and_not1_b32 vcc_lo, exec_lo, s5
	ds_store_b32 v5, v3 offset:4096
	s_cbranch_vccnz .LBB6_134
; %bb.132:                              ; %.lr.ph.1.preheader
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
.LBB6_133:                              ; %.lr.ph.1
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
	s_cbranch_scc1 .LBB6_133
.LBB6_134:                              ; %Flow2030
	v_or_b32_e32 v1, 0x1000, v5
	s_and_not1_b32 vcc_lo, exec_lo, s1
	s_cbranch_vccnz .LBB6_137
; %bb.135:                              ; %.lr.ph250.1.preheader
	s_lshl_b32 s1, s4, 2
	s_mov_b32 s4, 0
	s_addk_i32 s1, 0x37c
	.p2align	6
.LBB6_136:                              ; %.lr.ph250.1
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
	s_cbranch_scc1 .LBB6_136
.LBB6_137:                              ; %._crit_edge.1
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
.LBB6_138:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc0 .LBB6_138
; %bb.139:                              ; %.preheader.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[4:5], 0
.LBB6_140:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_140
; %bb.141:                              ; %.preheader.1288
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
.LBB6_142:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_142
; %bb.143:                              ; %.preheader.1.1
	s_movk_i32 s3, 0x1200
	s_mov_b64 s[0:1], 0
.LBB6_144:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_144
; %bb.145:                              ; %.preheader.2
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
.LBB6_146:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_146
; %bb.147:                              ; %.preheader.1.2
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB6_148:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_148
; %bb.149:                              ; %.preheader.3
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:1024
.LBB6_150:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_150
; %bb.151:                              ; %.preheader.1.3
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB6_152:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_152
; %bb.153:                              ; %.preheader.4
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:1536
.LBB6_154:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_154
; %bb.155:                              ; %.preheader.1.4
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB6_156:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_156
; %bb.157:                              ; %.preheader.5
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:2048
.LBB6_158:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_158
; %bb.159:                              ; %.preheader.1.5
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB6_160:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_160
; %bb.161:                              ; %.preheader.6
	v_mov_b32_e32 v5, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v4, off offset:2560
.LBB6_162:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_162
; %bb.163:                              ; %.preheader.1.6
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB6_164:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_164
; %bb.165:                              ; %.preheader.7
	v_mov_b32_e32 v4, 0
	s_mov_b64 s[0:1], 0
	s_movk_i32 s2, 0x1000
	global_store_b32 v[0:1], v5, off offset:3072
.LBB6_166:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_166
; %bb.167:                              ; %.preheader.1.7
	s_movk_i32 s2, 0x1200
	s_mov_b64 s[0:1], 0
.LBB6_168:                              ; =>This Inner Loop Header: Depth=1
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
	s_cbranch_scc1 .LBB6_168
; %bb.169:                              ; %.loopexit.loopexit
	global_store_b32 v[0:1], v4, off offset:3584
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf
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
	.section	.text._Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf,"axG",@progbits,_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf,comdat
.Lfunc_end6:
	.size	_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf, .Lfunc_end6-_Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf
                                        ; -- End function
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.num_vgpr, 24
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.num_agpr, 0
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.numbered_sgpr, 44
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.num_named_barrier, 0
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.private_seg_size, 0
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.uses_vcc, 1
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.uses_flat_scratch, 0
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.has_dyn_sized_stack, 0
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.has_recursion, 0
	.set _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 13716
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
      - .offset:         16
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 20
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN8alphabet10append_keyEPNS_5CacheEPKhi
    .private_segment_fixed_size: 0
    .sgpr_count:     10
    .sgpr_spill_count: 0
    .symbol:         _ZN8alphabet10append_keyEPNS_5CacheEPKhi.kd
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
      - .offset:         16
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 20
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN8alphabet13append_recentEPNS_5CacheEPKhi
    .private_segment_fixed_size: 0
    .sgpr_count:     12
    .sgpr_spill_count: 0
    .symbol:         _ZN8alphabet13append_recentEPNS_5CacheEPKhi.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     6
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
    .group_segment_fixed_size: 4608
    .kernarg_segment_align: 8
    .kernarg_segment_size: 12
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN8alphabet9flush_keyEPNS_5CacheEi
    .private_segment_fixed_size: 0
    .sgpr_count:     15
    .sgpr_spill_count: 0
    .symbol:         _ZN8alphabet9flush_keyEPNS_5CacheEi.kd
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
      - .offset:         20
        .size:           4
        .value_kind:     by_value
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 24
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _ZN8alphabet11flush_valueEPNS_5CacheEPKfii
    .private_segment_fixed_size: 0
    .sgpr_count:     16
    .sgpr_spill_count: 0
    .symbol:         _ZN8alphabet11flush_valueEPNS_5CacheEPKfii.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     56
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
    .name:           _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi1EEvPKN8alphabet5CacheEPKfiS5_PKtPf.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     24
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
    .name:           _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         _Z11query_groupILi0EEvPKN8alphabet5CacheEPKfiS5_PKtPf.kd
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
