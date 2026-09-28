	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.amdhsa_code_object_version 6
	.text
	.protected	_Z6scalarPKfPfPKh       ; -- Begin function _Z6scalarPKfPfPKh
	.globl	_Z6scalarPKfPfPKh
	.p2align	8
	.type	_Z6scalarPKfPfPKh,@function
_Z6scalarPKfPfPKh:                      ; @_Z6scalarPKfPfPKh
; %bb.0:
	s_load_b64 s[8:9], s[0:1], 0x10
	v_lshlrev_b32_e32 v1, 3, v0
	v_lshrrev_b32_e32 v4, 2, v0
	s_mov_b32 s3, exec_lo
                                        ; implicit-def: $vgpr2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e64 v1, v1, -1
	v_not_b32_e32 v1, v1
	s_waitcnt lgkmcnt(0)
	s_load_b64 s[10:11], s[8:9], 0x0
	v_cmpx_gt_u32_e32 8, v0
	s_xor_b32 s3, exec_lo, s3
	s_cbranch_execz .LBB0_2
; %bb.1:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v2, s11, v1
	v_cmp_eq_u32_e32 vcc_lo, 1, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v2, v2, 0
	v_cndmask_b32_e32 v2, 0, v2, vcc_lo
.LBB0_2:                                ; %Flow670
	s_and_not1_saveexec_b32 s3, s3
	s_cbranch_execz .LBB0_4
; %bb.3:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s4, s11
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v2, s4
.LBB0_4:
	s_or_b32 exec_lo, exec_lo, s3
	s_load_b32 s3, s[8:9], 0x8
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr3
	v_cmpx_gt_u32_e32 12, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_6
; %bb.5:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v3, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 2, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v3, v3, 0
	v_cndmask_b32_e32 v3, 0, v3, vcc_lo
.LBB0_6:                                ; %Flow669
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_8
; %bb.7:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v3, s3
.LBB0_8:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0xc
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr6
	v_cmpx_gt_u32_e32 16, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_10
; %bb.9:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 3, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v6, 0, v5, vcc_lo
.LBB0_10:                               ; %Flow668
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_12
; %bb.11:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v6, s3
.LBB0_12:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x10
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr7
	v_cmpx_gt_u32_e32 20, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_14
; %bb.13:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 4, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v7, 0, v5, vcc_lo
.LBB0_14:                               ; %Flow667
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_16
; %bb.15:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v7, s3
.LBB0_16:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x14
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr8
	v_cmpx_gt_u32_e32 24, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_18
; %bb.17:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 5, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v8, 0, v5, vcc_lo
.LBB0_18:                               ; %Flow666
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_20
; %bb.19:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v8, s3
.LBB0_20:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x18
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr9
	v_cmpx_gt_u32_e32 28, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_22
; %bb.21:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 6, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v9, 0, v5, vcc_lo
.LBB0_22:                               ; %Flow665
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_24
; %bb.23:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v9, s3
.LBB0_24:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x1c
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr10
	v_cmpx_gt_u32_e32 32, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_26
; %bb.25:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 7, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v10, 0, v5, vcc_lo
.LBB0_26:                               ; %Flow664
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_28
; %bb.27:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v10, s3
.LBB0_28:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x20
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr11
	v_cmpx_gt_u32_e32 36, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_30
; %bb.29:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 8, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v11, 0, v5, vcc_lo
.LBB0_30:                               ; %Flow663
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_32
; %bb.31:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v11, s3
.LBB0_32:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x24
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr12
	v_cmpx_gt_u32_e32 40, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_34
; %bb.33:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 9, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v12, 0, v5, vcc_lo
.LBB0_34:                               ; %Flow662
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_36
; %bb.35:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v12, s3
.LBB0_36:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x28
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr13
	v_cmpx_gt_u32_e32 44, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_38
; %bb.37:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 10, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v13, 0, v5, vcc_lo
.LBB0_38:                               ; %Flow661
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_40
; %bb.39:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v13, s3
.LBB0_40:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x2c
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr14
	v_cmpx_gt_u32_e32 48, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_42
; %bb.41:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 11, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v14, 0, v5, vcc_lo
.LBB0_42:                               ; %Flow660
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_44
; %bb.43:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v14, s3
.LBB0_44:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x30
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr15
	v_cmpx_gt_u32_e32 52, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_46
; %bb.45:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 12, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v15, 0, v5, vcc_lo
.LBB0_46:                               ; %Flow659
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_48
; %bb.47:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v15, s3
.LBB0_48:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x34
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr16
	v_cmpx_gt_u32_e32 56, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_50
; %bb.49:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 13, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v16, 0, v5, vcc_lo
.LBB0_50:                               ; %Flow658
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_52
; %bb.51:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v16, s3
.LBB0_52:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x38
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr17
	v_cmpx_gt_u32_e32 60, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_54
; %bb.53:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 14, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v17, 0, v5, vcc_lo
.LBB0_54:                               ; %Flow657
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_56
; %bb.55:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v17, s3
.LBB0_56:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x3c
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr18
	v_cmpx_gt_u32_e32 64, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_58
; %bb.57:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 15, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v18, 0, v5, vcc_lo
.LBB0_58:                               ; %Flow656
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_60
; %bb.59:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v18, s3
.LBB0_60:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x40
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr19
	v_cmpx_gt_u32_e32 0x44, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_62
; %bb.61:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 16, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v19, 0, v5, vcc_lo
.LBB0_62:                               ; %Flow655
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_64
; %bb.63:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v19, s3
.LBB0_64:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x44
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr20
	v_cmpx_gt_u32_e32 0x48, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_66
; %bb.65:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 17, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v20, 0, v5, vcc_lo
.LBB0_66:                               ; %Flow654
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_68
; %bb.67:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v20, s3
.LBB0_68:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x48
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr21
	v_cmpx_gt_u32_e32 0x4c, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_70
; %bb.69:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 18, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v21, 0, v5, vcc_lo
.LBB0_70:                               ; %Flow653
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_72
; %bb.71:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v21, s3
.LBB0_72:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x4c
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr22
	v_cmpx_gt_u32_e32 0x50, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_74
; %bb.73:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 19, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v22, 0, v5, vcc_lo
.LBB0_74:                               ; %Flow652
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_76
; %bb.75:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v22, s3
.LBB0_76:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x50
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr23
	v_cmpx_gt_u32_e32 0x54, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_78
; %bb.77:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 20, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v23, 0, v5, vcc_lo
.LBB0_78:                               ; %Flow651
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_80
; %bb.79:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v23, s3
.LBB0_80:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x54
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr24
	v_cmpx_gt_u32_e32 0x58, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_82
; %bb.81:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 21, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v24, 0, v5, vcc_lo
.LBB0_82:                               ; %Flow650
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_84
; %bb.83:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v24, s3
.LBB0_84:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x58
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr25
	v_cmpx_gt_u32_e32 0x5c, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_86
; %bb.85:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 22, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v25, 0, v5, vcc_lo
.LBB0_86:                               ; %Flow649
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_88
; %bb.87:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v25, s3
.LBB0_88:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x5c
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr26
	v_cmpx_gt_u32_e32 0x60, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_90
; %bb.89:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 23, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v26, 0, v5, vcc_lo
.LBB0_90:                               ; %Flow648
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_92
; %bb.91:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v26, s3
.LBB0_92:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x60
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr27
	v_cmpx_gt_u32_e32 0x64, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_94
; %bb.93:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 24, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v27, 0, v5, vcc_lo
.LBB0_94:                               ; %Flow647
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_96
; %bb.95:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v27, s3
.LBB0_96:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x64
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr28
	v_cmpx_gt_u32_e32 0x68, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_98
; %bb.97:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 25, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v28, 0, v5, vcc_lo
.LBB0_98:                               ; %Flow646
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_100
; %bb.99:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v28, s3
.LBB0_100:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x68
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr29
	v_cmpx_gt_u32_e32 0x6c, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_102
; %bb.101:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 26, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v29, 0, v5, vcc_lo
.LBB0_102:                              ; %Flow645
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_104
; %bb.103:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v29, s3
.LBB0_104:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x6c
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr30
	v_cmpx_gt_u32_e32 0x70, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_106
; %bb.105:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 27, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v30, 0, v5, vcc_lo
.LBB0_106:                              ; %Flow644
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_108
; %bb.107:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v30, s3
.LBB0_108:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x70
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr31
	v_cmpx_gt_u32_e32 0x74, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_110
; %bb.109:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 28, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v31, 0, v5, vcc_lo
.LBB0_110:                              ; %Flow643
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_112
; %bb.111:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v31, s3
.LBB0_112:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x74
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr32
	v_cmpx_gt_u32_e32 0x78, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_114
; %bb.113:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 29, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v32, 0, v5, vcc_lo
.LBB0_114:                              ; %Flow642
	s_and_not1_saveexec_b32 s4, s4
	s_cbranch_execz .LBB0_116
; %bb.115:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s3, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v32, s3
.LBB0_116:
	s_or_b32 exec_lo, exec_lo, s4
	s_waitcnt lgkmcnt(0)
	s_load_b32 s3, s[8:9], 0x78
	s_mov_b32 s4, exec_lo
                                        ; implicit-def: $vgpr33
	v_cmpx_gt_u32_e32 0x7c, v0
	s_xor_b32 s4, exec_lo, s4
	s_cbranch_execz .LBB0_118
; %bb.117:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s3, v1
	v_cmp_eq_u32_e32 vcc_lo, 30, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v33, 0, v5, vcc_lo
.LBB0_118:                              ; %Flow641
	s_or_saveexec_b32 s11, s4
	s_load_b128 s[4:7], s[0:1], 0x0
	s_xor_b32 exec_lo, exec_lo, s11
	s_cbranch_execz .LBB0_120
; %bb.119:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s0, s3
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v33, s0
.LBB0_120:
	s_or_b32 exec_lo, exec_lo, s11
	s_load_b32 s0, s[8:9], 0x7c
	s_mov_b32 s1, exec_lo
                                        ; implicit-def: $vgpr34
	v_cmpx_gt_u32_e32 0x80, v0
	s_xor_b32 s1, exec_lo, s1
	s_cbranch_execz .LBB0_122
; %bb.121:
	s_waitcnt lgkmcnt(0)
	v_and_b32_e32 v5, s0, v1
	v_cmp_eq_u32_e32 vcc_lo, 31, v4
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_bcnt_u32_b32 v5, v5, 0
	v_cndmask_b32_e32 v34, 0, v5, vcc_lo
.LBB0_122:                              ; %Flow
	s_and_not1_saveexec_b32 s1, s1
	s_cbranch_execz .LBB0_124
; %bb.123:
	s_waitcnt lgkmcnt(0)
	s_bcnt1_i32_b32 s0, s0
	s_delay_alu instid0(SALU_CYCLE_1)
	v_mov_b32_e32 v34, s0
.LBB0_124:
	s_or_b32 exec_lo, exec_lo, s1
	global_load_d16_i8 v5, v0, s[8:9]
	v_cmp_gt_u32_e32 vcc_lo, 4, v0
	s_mov_b32 s13, 0
	v_dual_mov_b32 v4, 0 :: v_dual_cndmask_b32 v1, -1, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_and_b32_e32 v1, s10, v1
	v_bcnt_u32_b32 v1, v1, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add3_u32 v1, v2, v1, v3
	v_mul_u32_u24_e32 v3, 0x1a0, v0
	v_add3_u32 v1, v6, v1, v7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v1, v8, v1, v9
	v_add3_u32 v1, v10, v1, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_add3_u32 v1, v12, v1, v13
	v_mov_b32_e32 v13, 0
	v_add3_u32 v1, v14, v1, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v1, v16, v1, v17
	v_add3_u32 v1, v18, v1, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v1, v20, v1, v21
	v_add3_u32 v1, v22, v1, v23
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v1, v24, v1, v25
	v_add3_u32 v1, v26, v1, v27
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v1, v28, v1, v29
	v_add3_u32 v1, v30, v1, v31
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add3_u32 v1, v32, v1, v33
	v_add_lshl_u32 v1, v34, v1, 4
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_sub_co_u32 v6, s0, v3, v1
	v_sub_co_ci_u32_e64 v7, null, 0, 0, s0
	s_lshl_b32 s0, s2, 10
	v_add_co_u32 v11, vcc_lo, s8, v6
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(SALU_CYCLE_1)
	v_add_co_ci_u32_e64 v12, null, s9, v7, vcc_lo
	s_ashr_i32 s1, s0, 31
	s_lshl_b64 s[0:1], s[0:1], 2
	s_delay_alu instid0(SALU_CYCLE_1)
	s_add_u32 s3, s4, s0
	s_addc_u32 s12, s5, s1
	s_mov_b64 s[0:1], 0
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v2, 1, v5
	v_and_b32_e32 v10, 0xff, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_xor_b32_e32 v9, 3, v2
	v_lshlrev_b32_e32 v8, 4, v9
	v_sub_nc_u32_e32 v14, 8, v9
	v_lshlrev_b32_e32 v16, 2, v9
	v_lshlrev_b32_e32 v17, 1, v9
	v_mul_u32_u24_e32 v18, 3, v9
	v_add_co_u32 v1, vcc_lo, v11, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v12, vcc_lo
	global_load_b32 v3, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v9, -1
	v_not_b32_e32 v15, v1
	s_branch .LBB0_126
.LBB0_125:                              ;   in Loop: Header=BB0_126 Depth=1
	s_or_b32 exec_lo, exec_lo, s15
	v_and_b32_e32 v1, 4, v13
	v_and_b32_e32 v2, 0xff, v20
	s_load_b32 s4, s[4:5], 0xc
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s13, s10
	s_add_u32 s0, s0, 16
	s_addc_u32 s1, s1, 0
	v_lshrrev_b32_e32 v1, v1, v2
	v_and_b32_e32 v2, v19, v15
	s_add_f32 s5, s5, s11
	s_cmpk_eq_i32 s0, 0x200
	v_add_nc_u32_e32 v13, v13, v16
	v_and_b32_e32 v1, v1, v15
	v_cvt_f32_ubyte0_e32 v2, v2
	s_add_f32 s5, s5, s14
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_dual_fmac_f32 v4, s10, v1 :: v_dual_and_b32 v19, v21, v15
	v_and_b32_e32 v1, v22, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v19, v19
	s_add_f32 s13, s5, s4
	v_fmac_f32_e32 v4, s11, v2
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_fmac_f32_e32 v4, s14, v19
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v4, s4, v1
	s_cbranch_scc1 .LBB0_132
.LBB0_126:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v21, v9, v13
	v_lshrrev_b32_e32 v19, 3, v13
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s10, exec_lo
	v_lshrrev_b32_e32 v1, 3, v21
	v_and_b32_e32 v21, 7, v21
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v11, v1
	v_add_co_ci_u32_e64 v2, null, 0, v12, vcc_lo
	v_add_co_u32 v19, vcc_lo, v11, v19
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v20, null, 0, v12, vcc_lo
	s_clause 0x1
	global_load_u8 v22, v[1:2], off offset:128
	global_load_d16_u8 v20, v[19:20], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v19, v21, v22
	v_cmpx_gt_u32_e64 v21, v14
	s_cbranch_execz .LBB0_128
; %bb.127:                              ;   in Loop: Header=BB0_126 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v21
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v19, v1, v2, v19
.LBB0_128:                              ;   in Loop: Header=BB0_126 Depth=1
	s_or_b32 exec_lo, exec_lo, s10
	v_add_nc_u32_e32 v21, v17, v13
	s_load_b64 s[10:11], s[4:5], 0x0
	s_mov_b32 s14, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v21
	v_and_b32_e32 v22, 6, v21
	v_add_co_u32 v1, vcc_lo, v11, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v12, vcc_lo
	global_load_u8 v23, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v21, v22, v23
	v_cmpx_gt_u32_e64 v22, v14
	s_cbranch_execz .LBB0_130
; %bb.129:                              ;   in Loop: Header=BB0_126 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v22
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v21, v1, v2, v21
.LBB0_130:                              ;   in Loop: Header=BB0_126 Depth=1
	s_or_b32 exec_lo, exec_lo, s14
	v_add_nc_u32_e32 v22, v18, v13
	s_load_b32 s14, s[4:5], 0x8
	s_mov_b32 s15, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v22
	v_and_b32_e32 v23, 7, v22
	v_add_co_u32 v1, vcc_lo, v11, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v12, vcc_lo
	global_load_u8 v24, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v22, v23, v24
	v_cmpx_gt_u32_e64 v23, v14
	s_cbranch_execz .LBB0_125
; %bb.131:                              ;   in Loop: Header=BB0_126 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v23
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v22, v1, v2, v22
	s_branch .LBB0_125
.LBB0_132:
	v_and_b32_e32 v1, 2, v10
	v_add_co_u32 v2, vcc_lo, v6, v8
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v6, null, 0, v7, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	v_mov_b32_e32 v7, 0
	s_mov_b32 s14, 0
	s_mov_b64 s[0:1], 0
	v_cndmask_b32_e64 v12, 2, 3, vcc_lo
	v_add_co_u32 v8, vcc_lo, v2, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v9, null, 0, v6, vcc_lo
	v_lshlrev_b32_e32 v11, 4, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v13, vcc_lo, s8, v8
	v_add_co_ci_u32_e64 v14, null, s9, v9, vcc_lo
	v_dual_mov_b32 v15, 0 :: v_dual_lshlrev_b32 v18, 2, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v13, v11
	v_add_co_ci_u32_e64 v2, null, 0, v14, vcc_lo
	v_sub_nc_u32_e32 v16, 8, v12
	v_lshlrev_b32_e32 v19, 1, v12
	v_mul_u32_u24_e32 v20, 3, v12
	global_load_b32 v6, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v12, -1
	s_delay_alu instid0(VALU_DEP_1)
	v_not_b32_e32 v17, v1
	s_branch .LBB0_134
.LBB0_133:                              ;   in Loop: Header=BB0_134 Depth=1
	s_or_b32 exec_lo, exec_lo, s16
	v_and_b32_e32 v1, 4, v15
	v_and_b32_e32 v2, 0xff, v22
	s_load_b32 s4, s[4:5], 0x20c
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s14, s10
	v_add_nc_u32_e32 v15, v15, v18
	s_add_u32 s0, s0, 16
	v_lshrrev_b32_e32 v1, v1, v2
	v_and_b32_e32 v2, v21, v17
	v_and_b32_e32 v21, v23, v17
	s_add_f32 s5, s5, s11
	s_addc_u32 s1, s1, 0
	v_and_b32_e32 v1, v1, v17
	v_cvt_f32_ubyte0_e32 v2, v2
	v_cvt_f32_ubyte0_e32 v21, v21
	s_add_f32 s5, s5, s15
	s_cmpk_lg_i32 s0, 0x200
	v_cvt_f32_ubyte0_e32 v1, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v7, s10, v1
	v_and_b32_e32 v1, v24, v17
	s_add_f32 s14, s5, s4
	v_fmac_f32_e32 v7, s11, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_fmac_f32_e32 v7, s15, v21
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v7, s4, v1
	s_cbranch_scc0 .LBB0_140
.LBB0_134:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v23, v12, v15
	v_lshrrev_b32_e32 v21, 3, v15
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s10, exec_lo
	v_lshrrev_b32_e32 v1, 3, v23
	v_and_b32_e32 v23, 7, v23
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v13, v1
	v_add_co_ci_u32_e64 v2, null, 0, v14, vcc_lo
	v_add_co_u32 v21, vcc_lo, v13, v21
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v22, null, 0, v14, vcc_lo
	s_clause 0x1
	global_load_u8 v24, v[1:2], off offset:128
	global_load_d16_u8 v22, v[21:22], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v21, v23, v24
	v_cmpx_gt_u32_e64 v23, v16
	s_cbranch_execz .LBB0_136
; %bb.135:                              ;   in Loop: Header=BB0_134 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v23
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v21, v1, v2, v21
.LBB0_136:                              ;   in Loop: Header=BB0_134 Depth=1
	s_or_b32 exec_lo, exec_lo, s10
	v_add_nc_u32_e32 v23, v19, v15
	s_load_b64 s[10:11], s[4:5], 0x200
	s_mov_b32 s15, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v23
	v_and_b32_e32 v24, 6, v23
	v_add_co_u32 v1, vcc_lo, v13, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v14, vcc_lo
	global_load_u8 v25, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v23, v24, v25
	v_cmpx_gt_u32_e64 v24, v16
	s_cbranch_execz .LBB0_138
; %bb.137:                              ;   in Loop: Header=BB0_134 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v24
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v23, v1, v2, v23
.LBB0_138:                              ;   in Loop: Header=BB0_134 Depth=1
	s_or_b32 exec_lo, exec_lo, s15
	v_add_nc_u32_e32 v24, v20, v15
	s_load_b32 s15, s[4:5], 0x208
	s_mov_b32 s16, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v24
	v_and_b32_e32 v25, 7, v24
	v_add_co_u32 v1, vcc_lo, v13, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v14, vcc_lo
	global_load_u8 v26, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v24, v25, v26
	v_cmpx_gt_u32_e64 v25, v16
	s_cbranch_execz .LBB0_133
; %bb.139:                              ;   in Loop: Header=BB0_134 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v25
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v24, v1, v2, v24
	s_branch .LBB0_133
.LBB0_140:
	v_and_b32_e32 v1, 4, v10
	v_add_co_u32 v2, vcc_lo, v8, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v8, null, 0, v9, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	v_mov_b32_e32 v9, 0
	s_mov_b32 s15, 0
	s_mov_b64 s[0:1], 0
	v_cndmask_b32_e64 v14, 2, 3, vcc_lo
	v_add_co_u32 v11, vcc_lo, v2, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v12, null, 0, v8, vcc_lo
	v_lshlrev_b32_e32 v13, 4, v14
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v15, vcc_lo, s8, v11
	v_add_co_ci_u32_e64 v16, null, s9, v12, vcc_lo
	v_dual_mov_b32 v17, 0 :: v_dual_lshlrev_b32 v20, 2, v14
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v15, v13
	v_add_co_ci_u32_e64 v2, null, 0, v16, vcc_lo
	v_sub_nc_u32_e32 v18, 8, v14
	v_lshlrev_b32_e32 v21, 1, v14
	v_mul_u32_u24_e32 v22, 3, v14
	global_load_b32 v8, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v14, -1
	s_delay_alu instid0(VALU_DEP_1)
	v_not_b32_e32 v19, v1
	s_branch .LBB0_142
.LBB0_141:                              ;   in Loop: Header=BB0_142 Depth=1
	s_or_b32 exec_lo, exec_lo, s17
	v_and_b32_e32 v1, 4, v17
	v_and_b32_e32 v2, 0xff, v24
	s_load_b32 s4, s[4:5], 0x40c
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s15, s10
	v_add_nc_u32_e32 v17, v17, v20
	s_add_u32 s0, s0, 16
	v_lshrrev_b32_e32 v1, v1, v2
	s_add_f32 s5, s5, s11
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x200
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_and_b32_e32 v1, v1, v19
	s_add_f32 s5, s5, s16
	v_cvt_f32_ubyte0_e32 v1, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, s10, v1
	v_and_b32_e32 v1, v26, v19
	s_add_f32 s15, s5, s4
	v_cvt_f32_ubyte0_e32 v1, v1
	v_and_b32_e32 v2, v23, v19
	v_and_b32_e32 v23, v25, v19
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v2, v2
	v_cvt_f32_ubyte0_e32 v23, v23
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v9, s11, v2
	v_fmac_f32_e32 v9, s16, v23
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v9, s4, v1
	s_cbranch_scc0 .LBB0_148
.LBB0_142:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v25, v14, v17
	v_lshrrev_b32_e32 v23, 3, v17
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s10, exec_lo
	v_lshrrev_b32_e32 v1, 3, v25
	v_and_b32_e32 v25, 7, v25
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v15, v1
	v_add_co_ci_u32_e64 v2, null, 0, v16, vcc_lo
	v_add_co_u32 v23, vcc_lo, v15, v23
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v24, null, 0, v16, vcc_lo
	s_clause 0x1
	global_load_u8 v26, v[1:2], off offset:128
	global_load_d16_u8 v24, v[23:24], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v23, v25, v26
	v_cmpx_gt_u32_e64 v25, v18
	s_cbranch_execz .LBB0_144
; %bb.143:                              ;   in Loop: Header=BB0_142 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v25
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v23, v1, v2, v23
.LBB0_144:                              ;   in Loop: Header=BB0_142 Depth=1
	s_or_b32 exec_lo, exec_lo, s10
	v_add_nc_u32_e32 v25, v21, v17
	s_load_b64 s[10:11], s[4:5], 0x400
	s_mov_b32 s16, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v25
	v_and_b32_e32 v26, 6, v25
	v_add_co_u32 v1, vcc_lo, v15, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v16, vcc_lo
	global_load_u8 v27, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v25, v26, v27
	v_cmpx_gt_u32_e64 v26, v18
	s_cbranch_execz .LBB0_146
; %bb.145:                              ;   in Loop: Header=BB0_142 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v26
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v25, v1, v2, v25
.LBB0_146:                              ;   in Loop: Header=BB0_142 Depth=1
	s_or_b32 exec_lo, exec_lo, s16
	v_add_nc_u32_e32 v26, v22, v17
	s_load_b32 s16, s[4:5], 0x408
	s_mov_b32 s17, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v26
	v_and_b32_e32 v27, 7, v26
	v_add_co_u32 v1, vcc_lo, v15, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v16, vcc_lo
	global_load_u8 v28, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v26, v27, v28
	v_cmpx_gt_u32_e64 v27, v18
	s_cbranch_execz .LBB0_141
; %bb.147:                              ;   in Loop: Header=BB0_142 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v27
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v26, v1, v2, v26
	s_branch .LBB0_141
.LBB0_148:
	v_and_b32_e32 v1, 8, v10
	v_add_co_u32 v2, vcc_lo, v11, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v11, null, 0, v12, vcc_lo
	v_mov_b32_e32 v12, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_mov_b32 s16, 0
	s_mov_b64 s[0:1], 0
	v_cndmask_b32_e64 v16, 2, 3, vcc_lo
	v_add_co_u32 v13, vcc_lo, v2, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v14, null, 0, v11, vcc_lo
	v_lshlrev_b32_e32 v15, 4, v16
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v17, vcc_lo, s8, v13
	v_add_co_ci_u32_e64 v18, null, s9, v14, vcc_lo
	v_dual_mov_b32 v19, 0 :: v_dual_lshlrev_b32 v22, 2, v16
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v17, v15
	v_add_co_ci_u32_e64 v2, null, 0, v18, vcc_lo
	v_sub_nc_u32_e32 v20, 8, v16
	v_lshlrev_b32_e32 v23, 1, v16
	v_mul_u32_u24_e32 v24, 3, v16
	global_load_b32 v11, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v16, -1
	s_delay_alu instid0(VALU_DEP_1)
	v_not_b32_e32 v21, v1
	s_branch .LBB0_150
.LBB0_149:                              ;   in Loop: Header=BB0_150 Depth=1
	s_or_b32 exec_lo, exec_lo, s18
	v_and_b32_e32 v1, 4, v19
	v_and_b32_e32 v2, 0xff, v26
	s_load_b32 s4, s[4:5], 0x60c
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s16, s10
	s_add_u32 s0, s0, 16
	s_addc_u32 s1, s1, 0
	v_lshrrev_b32_e32 v1, v1, v2
	v_and_b32_e32 v2, v25, v21
	v_and_b32_e32 v25, v27, v21
	s_add_f32 s5, s5, s11
	s_cmpk_lg_i32 s0, 0x200
	v_and_b32_e32 v1, v1, v21
	v_cvt_f32_ubyte0_e32 v2, v2
	v_cvt_f32_ubyte0_e32 v25, v25
	s_add_f32 s5, s5, s17
	v_add_nc_u32_e32 v19, v19, v22
	v_cvt_f32_ubyte0_e32 v1, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v12, s10, v1
	v_and_b32_e32 v1, v28, v21
	s_add_f32 s16, s5, s4
	v_fmac_f32_e32 v12, s11, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_fmac_f32_e32 v12, s17, v25
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v12, s4, v1
	s_cbranch_scc0 .LBB0_156
.LBB0_150:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v27, v16, v19
	v_lshrrev_b32_e32 v25, 3, v19
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s10, exec_lo
	v_lshrrev_b32_e32 v1, 3, v27
	v_and_b32_e32 v27, 7, v27
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v17, v1
	v_add_co_ci_u32_e64 v2, null, 0, v18, vcc_lo
	v_add_co_u32 v25, vcc_lo, v17, v25
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v26, null, 0, v18, vcc_lo
	s_clause 0x1
	global_load_u8 v28, v[1:2], off offset:128
	global_load_d16_u8 v26, v[25:26], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v25, v27, v28
	v_cmpx_gt_u32_e64 v27, v20
	s_cbranch_execz .LBB0_152
; %bb.151:                              ;   in Loop: Header=BB0_150 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v27
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v25, v1, v2, v25
.LBB0_152:                              ;   in Loop: Header=BB0_150 Depth=1
	s_or_b32 exec_lo, exec_lo, s10
	v_add_nc_u32_e32 v27, v23, v19
	s_load_b64 s[10:11], s[4:5], 0x600
	s_mov_b32 s17, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v27
	v_and_b32_e32 v28, 6, v27
	v_add_co_u32 v1, vcc_lo, v17, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v18, vcc_lo
	global_load_u8 v29, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v27, v28, v29
	v_cmpx_gt_u32_e64 v28, v20
	s_cbranch_execz .LBB0_154
; %bb.153:                              ;   in Loop: Header=BB0_150 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v28
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v27, v1, v2, v27
.LBB0_154:                              ;   in Loop: Header=BB0_150 Depth=1
	s_or_b32 exec_lo, exec_lo, s17
	v_add_nc_u32_e32 v28, v24, v19
	s_load_b32 s17, s[4:5], 0x608
	s_mov_b32 s18, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v28
	v_and_b32_e32 v29, 7, v28
	v_add_co_u32 v1, vcc_lo, v17, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v18, vcc_lo
	global_load_u8 v30, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v28, v29, v30
	v_cmpx_gt_u32_e64 v29, v20
	s_cbranch_execz .LBB0_149
; %bb.155:                              ;   in Loop: Header=BB0_150 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v29
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v28, v1, v2, v28
	s_branch .LBB0_149
.LBB0_156:
	v_and_b32_e32 v1, 16, v10
	v_add_co_u32 v2, vcc_lo, v13, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v13, null, 0, v14, vcc_lo
	v_mov_b32_e32 v14, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_mov_b32 s17, 0
	s_mov_b64 s[0:1], 0
	v_cndmask_b32_e64 v18, 2, 3, vcc_lo
	v_add_co_u32 v15, vcc_lo, v2, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v16, null, 0, v13, vcc_lo
	v_lshlrev_b32_e32 v17, 4, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v19, vcc_lo, s8, v15
	v_add_co_ci_u32_e64 v20, null, s9, v16, vcc_lo
	v_dual_mov_b32 v21, 0 :: v_dual_lshlrev_b32 v24, 2, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v19, v17
	v_add_co_ci_u32_e64 v2, null, 0, v20, vcc_lo
	v_sub_nc_u32_e32 v22, 8, v18
	v_lshlrev_b32_e32 v25, 1, v18
	v_mul_u32_u24_e32 v26, 3, v18
	global_load_b32 v13, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v18, -1
	s_delay_alu instid0(VALU_DEP_1)
	v_not_b32_e32 v23, v1
	s_branch .LBB0_158
.LBB0_157:                              ;   in Loop: Header=BB0_158 Depth=1
	s_or_b32 exec_lo, exec_lo, s19
	v_and_b32_e32 v1, 4, v21
	v_and_b32_e32 v2, 0xff, v28
	s_load_b32 s4, s[4:5], 0x80c
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s17, s10
	s_add_u32 s0, s0, 16
	s_addc_u32 s1, s1, 0
	v_lshrrev_b32_e32 v1, v1, v2
	v_and_b32_e32 v2, v27, v23
	s_add_f32 s5, s5, s11
	s_cmpk_lg_i32 s0, 0x200
	v_add_nc_u32_e32 v21, v21, v24
	v_and_b32_e32 v1, v1, v23
	v_cvt_f32_ubyte0_e32 v2, v2
	s_add_f32 s5, s5, s18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_dual_fmac_f32 v14, s10, v1 :: v_dual_and_b32 v27, v29, v23
	v_and_b32_e32 v1, v30, v23
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cvt_f32_ubyte0_e32 v27, v27
	s_add_f32 s17, s5, s4
	v_fmac_f32_e32 v14, s11, v2
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_fmac_f32_e32 v14, s18, v27
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v14, s4, v1
	s_cbranch_scc0 .LBB0_164
.LBB0_158:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v29, v18, v21
	v_lshrrev_b32_e32 v27, 3, v21
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s10, exec_lo
	v_lshrrev_b32_e32 v1, 3, v29
	v_and_b32_e32 v29, 7, v29
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v19, v1
	v_add_co_ci_u32_e64 v2, null, 0, v20, vcc_lo
	v_add_co_u32 v27, vcc_lo, v19, v27
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v28, null, 0, v20, vcc_lo
	s_clause 0x1
	global_load_u8 v30, v[1:2], off offset:128
	global_load_d16_u8 v28, v[27:28], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v27, v29, v30
	v_cmpx_gt_u32_e64 v29, v22
	s_cbranch_execz .LBB0_160
; %bb.159:                              ;   in Loop: Header=BB0_158 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v29
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v27, v1, v2, v27
.LBB0_160:                              ;   in Loop: Header=BB0_158 Depth=1
	s_or_b32 exec_lo, exec_lo, s10
	v_add_nc_u32_e32 v29, v25, v21
	s_load_b64 s[10:11], s[4:5], 0x800
	s_mov_b32 s18, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v29
	v_and_b32_e32 v30, 6, v29
	v_add_co_u32 v1, vcc_lo, v19, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v20, vcc_lo
	global_load_u8 v31, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v29, v30, v31
	v_cmpx_gt_u32_e64 v30, v22
	s_cbranch_execz .LBB0_162
; %bb.161:                              ;   in Loop: Header=BB0_158 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v30
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v29, v1, v2, v29
.LBB0_162:                              ;   in Loop: Header=BB0_158 Depth=1
	s_or_b32 exec_lo, exec_lo, s18
	v_add_nc_u32_e32 v30, v26, v21
	s_load_b32 s18, s[4:5], 0x808
	s_mov_b32 s19, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v30
	v_and_b32_e32 v31, 7, v30
	v_add_co_u32 v1, vcc_lo, v19, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v20, vcc_lo
	global_load_u8 v32, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v30, v31, v32
	v_cmpx_gt_u32_e64 v31, v22
	s_cbranch_execz .LBB0_157
; %bb.163:                              ;   in Loop: Header=BB0_158 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v31
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v30, v1, v2, v30
	s_branch .LBB0_157
.LBB0_164:
	v_and_b32_e32 v1, 32, v10
	v_add_co_u32 v2, vcc_lo, v15, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v15, null, 0, v16, vcc_lo
	v_mov_b32_e32 v16, 0
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_mov_b32 s18, 0
	s_mov_b64 s[0:1], 0
	v_cndmask_b32_e64 v20, 2, 3, vcc_lo
	v_add_co_u32 v17, vcc_lo, v2, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v18, null, 0, v15, vcc_lo
	v_lshlrev_b32_e32 v19, 4, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v21, vcc_lo, s8, v17
	v_add_co_ci_u32_e64 v22, null, s9, v18, vcc_lo
	v_dual_mov_b32 v23, 0 :: v_dual_lshlrev_b32 v26, 2, v20
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v21, v19
	v_add_co_ci_u32_e64 v2, null, 0, v22, vcc_lo
	v_sub_nc_u32_e32 v24, 8, v20
	v_lshlrev_b32_e32 v27, 1, v20
	v_mul_u32_u24_e32 v28, 3, v20
	global_load_b32 v15, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v20, -1
	s_delay_alu instid0(VALU_DEP_1)
	v_not_b32_e32 v25, v1
	s_branch .LBB0_166
.LBB0_165:                              ;   in Loop: Header=BB0_166 Depth=1
	s_or_b32 exec_lo, exec_lo, s20
	v_and_b32_e32 v1, 4, v23
	v_and_b32_e32 v2, 0xff, v30
	s_load_b32 s4, s[4:5], 0xa0c
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s18, s10
	s_add_u32 s0, s0, 16
	s_addc_u32 s1, s1, 0
	v_lshrrev_b32_e32 v1, v1, v2
	v_and_b32_e32 v2, v29, v25
	v_and_b32_e32 v29, v31, v25
	s_add_f32 s5, s5, s11
	s_cmpk_lg_i32 s0, 0x200
	v_and_b32_e32 v1, v1, v25
	v_cvt_f32_ubyte0_e32 v2, v2
	v_cvt_f32_ubyte0_e32 v29, v29
	s_add_f32 s5, s5, s19
	v_add_nc_u32_e32 v23, v23, v26
	v_cvt_f32_ubyte0_e32 v1, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_2)
	v_fmac_f32_e32 v16, s10, v1
	v_and_b32_e32 v1, v32, v25
	s_add_f32 s18, s5, s4
	v_fmac_f32_e32 v16, s11, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_fmac_f32_e32 v16, s19, v29
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v16, s4, v1
	s_cbranch_scc0 .LBB0_172
.LBB0_166:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v31, v20, v23
	v_lshrrev_b32_e32 v29, 3, v23
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s10, exec_lo
	v_lshrrev_b32_e32 v1, 3, v31
	v_and_b32_e32 v31, 7, v31
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v21, v1
	v_add_co_ci_u32_e64 v2, null, 0, v22, vcc_lo
	v_add_co_u32 v29, vcc_lo, v21, v29
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v30, null, 0, v22, vcc_lo
	s_clause 0x1
	global_load_u8 v32, v[1:2], off offset:128
	global_load_d16_u8 v30, v[29:30], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v29, v31, v32
	v_cmpx_gt_u32_e64 v31, v24
	s_cbranch_execz .LBB0_168
; %bb.167:                              ;   in Loop: Header=BB0_166 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v31
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v29, v1, v2, v29
.LBB0_168:                              ;   in Loop: Header=BB0_166 Depth=1
	s_or_b32 exec_lo, exec_lo, s10
	v_add_nc_u32_e32 v31, v27, v23
	s_load_b64 s[10:11], s[4:5], 0xa00
	s_mov_b32 s19, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v31
	v_and_b32_e32 v32, 6, v31
	v_add_co_u32 v1, vcc_lo, v21, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v22, vcc_lo
	global_load_u8 v33, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v31, v32, v33
	v_cmpx_gt_u32_e64 v32, v24
	s_cbranch_execz .LBB0_170
; %bb.169:                              ;   in Loop: Header=BB0_166 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v32
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v31, v1, v2, v31
.LBB0_170:                              ;   in Loop: Header=BB0_166 Depth=1
	s_or_b32 exec_lo, exec_lo, s19
	v_add_nc_u32_e32 v32, v28, v23
	s_load_b32 s19, s[4:5], 0xa08
	s_mov_b32 s20, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v32
	v_and_b32_e32 v33, 7, v32
	v_add_co_u32 v1, vcc_lo, v21, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v22, vcc_lo
	global_load_u8 v34, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v32, v33, v34
	v_cmpx_gt_u32_e64 v33, v24
	s_cbranch_execz .LBB0_165
; %bb.171:                              ;   in Loop: Header=BB0_166 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v33
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v32, v1, v2, v32
	s_branch .LBB0_165
.LBB0_172:
	v_dual_mov_b32 v24, 0 :: v_dual_and_b32 v1, 64, v10
	v_add_co_u32 v2, vcc_lo, v17, v19
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v10, null, 0, v18, vcc_lo
	v_cmp_eq_u32_e32 vcc_lo, 0, v1
	s_mov_b32 s19, 0
	s_mov_b64 s[0:1], 0
	v_mov_b32_e32 v17, 0
	v_cndmask_b32_e64 v21, 2, 3, vcc_lo
	v_add_co_u32 v18, vcc_lo, v2, 4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v19, null, 0, v10, vcc_lo
	v_lshlrev_b32_e32 v20, 4, v21
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v22, vcc_lo, s8, v18
	v_add_co_ci_u32_e64 v23, null, s9, v19, vcc_lo
	v_sub_nc_u32_e32 v25, 8, v21
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v22, v20
	v_add_co_ci_u32_e64 v2, null, 0, v23, vcc_lo
	v_lshlrev_b32_e32 v27, 2, v21
	v_lshlrev_b32_e32 v28, 1, v21
	v_mul_u32_u24_e32 v29, 3, v21
	global_load_b32 v10, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v21, -1
	s_delay_alu instid0(VALU_DEP_1)
	v_not_b32_e32 v26, v1
	s_branch .LBB0_174
.LBB0_173:                              ;   in Loop: Header=BB0_174 Depth=1
	s_or_b32 exec_lo, exec_lo, s21
	v_and_b32_e32 v1, 4, v24
	v_and_b32_e32 v2, 0xff, v31
	s_load_b32 s4, s[4:5], 0xc0c
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s19, s10
	s_add_u32 s0, s0, 16
	s_addc_u32 s1, s1, 0
	v_lshrrev_b32_e32 v1, v1, v2
	s_add_f32 s5, s5, s11
	s_cmpk_lg_i32 s0, 0x200
	v_add_nc_u32_e32 v24, v24, v27
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_and_b32_e32 v1, v1, v26
	s_add_f32 s5, s5, s20
	v_cvt_f32_ubyte0_e32 v1, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, s10, v1
	v_and_b32_e32 v1, v33, v26
	s_add_f32 s19, s5, s4
	v_cvt_f32_ubyte0_e32 v1, v1
	v_and_b32_e32 v2, v30, v26
	v_and_b32_e32 v30, v32, v26
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v2, v2
	v_cvt_f32_ubyte0_e32 v30, v30
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v17, s11, v2
	v_fmac_f32_e32 v17, s20, v30
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v17, s4, v1
	s_cbranch_scc0 .LBB0_180
.LBB0_174:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v32, v21, v24
	v_lshrrev_b32_e32 v30, 3, v24
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s10, exec_lo
	v_lshrrev_b32_e32 v1, 3, v32
	v_and_b32_e32 v32, 7, v32
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v22, v1
	v_add_co_ci_u32_e64 v2, null, 0, v23, vcc_lo
	v_add_co_u32 v30, vcc_lo, v22, v30
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v31, null, 0, v23, vcc_lo
	s_clause 0x1
	global_load_u8 v33, v[1:2], off offset:128
	global_load_d16_u8 v31, v[30:31], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v30, v32, v33
	v_cmpx_gt_u32_e64 v32, v25
	s_cbranch_execz .LBB0_176
; %bb.175:                              ;   in Loop: Header=BB0_174 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v32
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v30, v1, v2, v30
.LBB0_176:                              ;   in Loop: Header=BB0_174 Depth=1
	s_or_b32 exec_lo, exec_lo, s10
	v_add_nc_u32_e32 v32, v28, v24
	s_load_b64 s[10:11], s[4:5], 0xc00
	s_mov_b32 s20, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v32
	v_and_b32_e32 v33, 6, v32
	v_add_co_u32 v1, vcc_lo, v22, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v23, vcc_lo
	global_load_u8 v34, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v32, v33, v34
	v_cmpx_gt_u32_e64 v33, v25
	s_cbranch_execz .LBB0_178
; %bb.177:                              ;   in Loop: Header=BB0_174 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v33
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v32, v1, v2, v32
.LBB0_178:                              ;   in Loop: Header=BB0_174 Depth=1
	s_or_b32 exec_lo, exec_lo, s20
	v_add_nc_u32_e32 v33, v29, v24
	s_load_b32 s20, s[4:5], 0xc08
	s_mov_b32 s21, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v33
	v_and_b32_e32 v34, 7, v33
	v_add_co_u32 v1, vcc_lo, v22, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v23, vcc_lo
	global_load_u8 v35, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v33, v34, v35
	v_cmpx_gt_u32_e64 v34, v25
	s_cbranch_execz .LBB0_173
; %bb.179:                              ;   in Loop: Header=BB0_174 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v34
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v33, v1, v2, v33
	s_branch .LBB0_173
.LBB0_180:
	v_add_co_u32 v1, vcc_lo, v18, v20
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v19, vcc_lo
	v_cmp_lt_i16_e32 vcc_lo, -1, v5.l
	s_mov_b32 s10, 0
	s_mov_b64 s[0:1], 0
	v_mov_b32_e32 v22, 0
	v_mov_b32_e32 v18, 0
	v_cndmask_b32_e64 v19, 2, 3, vcc_lo
	v_add_co_u32 v1, vcc_lo, s8, v1
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v2, null, s9, v2, vcc_lo
	v_lshlrev_b32_e32 v5, 4, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v20, vcc_lo, v1, 4
	v_add_co_ci_u32_e64 v21, null, 0, v2, vcc_lo
	v_sub_nc_u32_e32 v23, 8, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v20, v5
	v_add_co_ci_u32_e64 v2, null, 0, v21, vcc_lo
	v_lshlrev_b32_e32 v25, 2, v19
	v_lshlrev_b32_e32 v26, 1, v19
	v_mul_u32_u24_e32 v27, 3, v19
	global_load_b32 v5, v[1:2], off offset:128
	v_lshlrev_b32_e64 v1, v19, -1
	s_delay_alu instid0(VALU_DEP_1)
	v_not_b32_e32 v24, v1
	s_branch .LBB0_182
.LBB0_181:                              ;   in Loop: Header=BB0_182 Depth=1
	s_or_b32 exec_lo, exec_lo, s20
	v_and_b32_e32 v1, 4, v22
	v_and_b32_e32 v2, 0xff, v29
	s_load_b32 s4, s[4:5], 0xe0c
	s_waitcnt lgkmcnt(0)
	s_add_f32 s5, s10, s8
	v_add_nc_u32_e32 v22, v22, v25
	s_add_u32 s0, s0, 16
	v_lshrrev_b32_e32 v1, v1, v2
	v_and_b32_e32 v2, v28, v24
	v_and_b32_e32 v28, v30, v24
	s_add_f32 s5, s5, s9
	s_addc_u32 s1, s1, 0
	s_cmpk_lg_i32 s0, 0x200
	v_cvt_f32_ubyte0_e32 v2, v2
	v_and_b32_e32 v1, v1, v24
	v_cvt_f32_ubyte0_e32 v28, v28
	s_add_f32 s5, s5, s11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(SALU_CYCLE_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	s_add_f32 s10, s5, s4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_fmac_f32 v18, s8, v1 :: v_dual_and_b32 v1, v31, v24
	v_fmac_f32_e32 v18, s9, v2
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_cvt_f32_ubyte0_e32 v1, v1
	v_fmac_f32_e32 v18, s11, v28
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v18, s4, v1
	s_cbranch_scc0 .LBB0_188
.LBB0_182:                              ; =>This Inner Loop Header: Depth=1
	v_add_nc_u32_e32 v30, v19, v22
	v_lshrrev_b32_e32 v28, 3, v22
	s_add_u32 s4, s3, s0
	s_addc_u32 s5, s12, s1
	s_mov_b32 s8, exec_lo
	v_lshrrev_b32_e32 v1, 3, v30
	v_and_b32_e32 v30, 7, v30
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v1, vcc_lo, v20, v1
	v_add_co_ci_u32_e64 v2, null, 0, v21, vcc_lo
	v_add_co_u32 v28, vcc_lo, v20, v28
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v29, null, 0, v21, vcc_lo
	s_clause 0x1
	global_load_u8 v31, v[1:2], off offset:128
	global_load_d16_u8 v29, v[28:29], off offset:128
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v28, v30, v31
	v_cmpx_gt_u32_e64 v30, v23
	s_cbranch_execz .LBB0_184
; %bb.183:                              ;   in Loop: Header=BB0_182 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v30
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v28, v1, v2, v28
.LBB0_184:                              ;   in Loop: Header=BB0_182 Depth=1
	s_or_b32 exec_lo, exec_lo, s8
	v_add_nc_u32_e32 v30, v26, v22
	s_load_b64 s[8:9], s[4:5], 0xe00
	s_mov_b32 s11, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v30
	v_and_b32_e32 v31, 6, v30
	v_add_co_u32 v1, vcc_lo, v20, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v21, vcc_lo
	global_load_u8 v32, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v30, v31, v32
	v_cmpx_gt_u32_e64 v31, v23
	s_cbranch_execz .LBB0_186
; %bb.185:                              ;   in Loop: Header=BB0_182 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v31
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v30, v1, v2, v30
.LBB0_186:                              ;   in Loop: Header=BB0_182 Depth=1
	s_or_b32 exec_lo, exec_lo, s11
	v_add_nc_u32_e32 v31, v27, v22
	s_load_b32 s11, s[4:5], 0xe08
	s_mov_b32 s20, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_lshrrev_b32_e32 v1, 3, v31
	v_and_b32_e32 v32, 7, v31
	v_add_co_u32 v1, vcc_lo, v20, v1
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v2, null, 0, v21, vcc_lo
	global_load_u8 v33, v[1:2], off offset:128
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v31, v32, v33
	v_cmpx_gt_u32_e64 v32, v23
	s_cbranch_execz .LBB0_181
; %bb.187:                              ;   in Loop: Header=BB0_182 Depth=1
	global_load_u8 v1, v[1:2], off offset:129
	v_sub_nc_u32_e32 v2, 8, v32
	s_waitcnt vmcnt(0)
	s_delay_alu instid0(VALU_DEP_1)
	v_lshl_or_b32 v31, v1, v2, v31
	s_branch .LBB0_181
.LBB0_188:
	v_cvt_f32_f16_e32 v1, v3.h
	v_cvt_f32_f16_e32 v2, v6.h
	v_cvt_f32_f16_e32 v19, v8.h
	v_lshl_add_u32 v0, s2, 7, v0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v1, s13, v1 :: v_dual_mul_f32 v2, s14, v2
	v_fma_mix_f32 v1, v4, v3, v1 op_sel_hi:[0,1,0]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_mul_f32_e32 v4, s15, v19
	v_fma_mix_f32 v2, v7, v6, v2 op_sel_hi:[0,1,0]
	v_cvt_f32_f16_e32 v3, v11.h
	v_cvt_f32_f16_e32 v6, v13.h
	v_add_f32_e32 v1, 0, v1
	v_fma_mix_f32 v4, v9, v8, v4 op_sel_hi:[0,1,0]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_mul_f32 v3, s16, v3 :: v_dual_mul_f32 v6, s17, v6
	v_add_f32_e32 v1, v1, v2
	v_cvt_f32_f16_e32 v2, v15.h
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fma_mix_f32 v3, v12, v11, v3 op_sel_hi:[0,1,0]
	v_fma_mix_f32 v6, v14, v13, v6 op_sel_hi:[0,1,0]
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_dual_add_f32 v1, v1, v4 :: v_dual_mul_f32 v2, s18, v2
	v_cvt_f32_f16_e32 v4, v10.h
	v_fma_mix_f32 v2, v16, v15, v2 op_sel_hi:[0,1,0]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v4, s19, v4
	v_fma_mix_f32 v4, v17, v10, v4 op_sel_hi:[0,1,0]
	v_add_f32_e32 v1, v1, v3
	v_cvt_f32_f16_e32 v3, v5.h
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_mul_f32_e32 v3, s10, v3
	v_fma_mix_f32 v3, v18, v5, v3 op_sel_hi:[0,1,0]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v1, v1, v6
	v_add_f32_e32 v2, v1, v2
	v_ashrrev_i32_e32 v1, 31, v0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f32_e32 v2, v2, v4
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_add_f32_e32 v2, v2, v3
	v_add_co_u32 v0, vcc_lo, s6, v0
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s7, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z6scalarPKfPfPKh
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
		.amdhsa_next_free_vgpr 36
		.amdhsa_next_free_sgpr 22
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
.Lfunc_end0:
	.size	_Z6scalarPKfPfPKh, .Lfunc_end0-_Z6scalarPKfPfPKh
                                        ; -- End function
	.set _Z6scalarPKfPfPKh.num_vgpr, 36
	.set _Z6scalarPKfPfPKh.num_agpr, 0
	.set _Z6scalarPKfPfPKh.numbered_sgpr, 22
	.set _Z6scalarPKfPfPKh.num_named_barrier, 0
	.set _Z6scalarPKfPfPKh.private_seg_size, 0
	.set _Z6scalarPKfPfPKh.uses_vcc, 1
	.set _Z6scalarPKfPfPKh.uses_flat_scratch, 0
	.set _Z6scalarPKfPfPKh.has_dyn_sized_stack, 0
	.set _Z6scalarPKfPfPKh.has_recursion, 0
	.set _Z6scalarPKfPfPKh.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 8344
; TotalNumSgprs: 24
; NumVgprs: 36
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 0
; VGPRBlocks: 4
; NumSGPRsForWavesPerEU: 24
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
.Lfunc_end1:
	.size	_Z13transform1024Pfi, .Lfunc_end1-_Z13transform1024Pfi
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
	.section	.text._Z4quipILi0EEvPKfPfPKhPK6__half,"axG",@progbits,_Z4quipILi0EEvPKfPfPKhPK6__half,comdat
	.protected	_Z4quipILi0EEvPKfPfPKhPK6__half ; -- Begin function _Z4quipILi0EEvPKfPfPKhPK6__half
	.globl	_Z4quipILi0EEvPKfPfPKhPK6__half
	.p2align	8
	.type	_Z4quipILi0EEvPKfPfPKhPK6__half,@function
_Z4quipILi0EEvPKfPfPKhPK6__half:        ; @_Z4quipILi0EEvPKfPfPKhPK6__half
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
	s_add_u32 s4, s8, 0xc092
	s_addc_u32 s5, s9, 0
	s_getpc_b64 s[0:1]
	s_add_u32 s0, s0, _Z13transform1024Pfi@rel32@lo+4
	s_addc_u32 s1, s1, _Z13transform1024Pfi@rel32@hi+12
	v_lshlrev_b32_e64 v41, v1, 1
	s_waitcnt vmcnt(15)
	s_delay_alu instid0(VALU_DEP_1)
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
	v_dual_mov_b32 v5, 0 :: v_dual_lshlrev_b32 v0, 7, v39
	v_dual_mov_b32 v4, 0x3e800000 :: v_dual_lshlrev_b32 v1, 8, v39
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v2, s0, s8, v0
	v_add_co_ci_u32_e64 v3, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_u32 v0, s0, s8, v1
	v_add_co_u32 v2, vcc_lo, 0x8000, v2
	v_add_co_ci_u32_e64 v1, null, s9, 0, s0
	s_delay_alu instid0(VALU_DEP_4)
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
.LBB2_1:                                ; %.preheader
                                        ; =>This Inner Loop Header: Depth=1
	global_load_u16 v18, v[0:1], off
	global_load_u8 v6, v[2:3], off
	v_add_co_u32 v0, vcc_lo, v0, 2
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, 0, v1, vcc_lo
	v_add_co_u32 v2, vcc_lo, v2, 1
	v_add_co_ci_u32_e64 v3, null, 0, v3, vcc_lo
	v_mov_b32_e32 v14, s3
	s_add_i32 s3, s3, 32
	s_delay_alu instid0(SALU_CYCLE_1)
	s_cmpk_eq_i32 s3, 0x1000
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v7, 6, v18
	s_waitcnt vmcnt(0)
	v_lshlrev_b32_e32 v6, 4, v6
	v_and_b32_e32 v20, 0xff, v18
	v_and_b32_e32 v24, 4, v18
	v_and_b32_e32 v27, 0x80, v18
	v_and_b32_e32 v7, 0x3fc, v7
	global_load_b32 v19, v7, s[4:5]
	global_load_b128 v[6:9], v6, s[10:11]
	ds_load_b128 v[10:13], v14
	ds_load_b128 v[14:17], v14 offset:16
	v_bcnt_u32_b32 v20, v20, 0
	v_and_b32_e32 v26, 8, v18
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_and_b32_e32 v28, 1, v20
	v_cmp_eq_u32_e64 s0, 0, v28
	s_waitcnt vmcnt(1)
	v_and_b32_e32 v28, 15, v19
	s_waitcnt vmcnt(0) lgkmcnt(1)
	v_fma_mix_f32 v5, v6, v10, v5 op_sel_hi:[1,0,0]
	v_bfe_u32 v29, v19, 16, 4
	v_bfe_u32 v30, v19, 4, 4
	v_bfe_u32 v31, v19, 20, 4
	v_bfe_u32 v32, v19, 8, 4
	v_bfe_u32 v33, v19, 24, 4
	v_bfe_u32 v34, v19, 12, 4
	v_lshrrev_b32_e32 v19, 28, v19
	v_fma_mix_f32 v5, v6, v11, v5 op_sel:[1,0,0] op_sel_hi:[1,0,0]
	v_add_nc_u32_e32 v6, -8, v28
	v_add_nc_u32_e32 v28, -8, v29
	v_add_nc_u32_e32 v29, -8, v30
	v_add_nc_u32_e32 v30, -8, v31
	v_add_nc_u32_e32 v19, -8, v19
	v_cvt_f32_i32_e32 v6, v6
	v_add_nc_u32_e32 v31, -8, v32
	v_add_nc_u32_e32 v32, -8, v33
	v_add_nc_u32_e32 v33, -8, v34
	v_cvt_f32_i32_e32 v29, v29
	v_and_b32_e32 v21, 16, v18
	v_cvt_f32_i32_e32 v19, v19
	v_and_b32_e32 v22, 2, v18
	v_cvt_f32_i32_e32 v33, v33
	v_and_b32_e32 v25, 64, v18
	v_mul_f32_e32 v6, 0.5, v6
	v_cvt_f32_i32_e32 v31, v31
	v_and_b32_e32 v23, 32, v18
	v_xor_b32_e32 v18, v20, v18
	v_fma_mix_f32 v5, v7, v12, v5 op_sel_hi:[1,0,0]
	v_cvt_f32_i32_e32 v28, v28
	v_cndmask_b32_e64 v20, 0xbe800000, v4, s0
	v_cvt_f32_i32_e32 v30, v30
	v_and_b32_e32 v18, 1, v18
	v_fma_mix_f32 v5, v7, v13, v5 op_sel:[1,0,0] op_sel_hi:[1,0,0]
	v_dual_mul_f32 v7, 0.5, v28 :: v_dual_mul_f32 v28, 0.5, v29
	v_mul_f32_e32 v19, 0.5, v19
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_3) | instid1(VALU_DEP_4)
	v_cmp_eq_u32_e64 s1, 0, v18
	v_dual_mul_f32 v29, 0.5, v30 :: v_dual_mul_f32 v30, 0.5, v31
	v_cvt_f32_i32_e32 v32, v32
	v_cmp_eq_u32_e64 s0, 0, v27
	v_cndmask_b32_e64 v6, -v6, v6, s1
	v_cmp_eq_u32_e64 s1, 0, v21
	s_waitcnt lgkmcnt(0)
	v_fma_mix_f32 v5, v8, v14, v5 op_sel_hi:[1,0,0]
	v_dual_mul_f32 v31, 0.5, v32 :: v_dual_mul_f32 v32, 0.5, v33
	v_add_f32_e32 v6, v20, v6
	v_cndmask_b32_e64 v7, -v7, v7, s1
	v_cmp_eq_u32_e64 s1, 0, v22
	v_fma_mix_f32 v5, v8, v15, v5 op_sel:[1,0,0] op_sel_hi:[1,0,0]
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_fmac_f32_e32 v43, v6, v10
	v_add_f32_e32 v7, v20, v7
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_cndmask_b32_e64 v18, -v28, v28, s1
	v_cmp_eq_u32_e64 s1, 0, v23
	v_fma_mix_f32 v5, v9, v16, v5 op_sel_hi:[1,0,0]
	v_dual_fmac_f32 v43, v7, v11 :: v_dual_add_f32 v10, v20, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_cndmask_b32_e64 v6, -v29, v29, s1
	v_cmp_eq_u32_e64 s1, 0, v24
	v_fma_mix_f32 v5, v9, v17, v5 op_sel:[1,0,0] op_sel_hi:[1,0,0]
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_dual_fmac_f32 v43, v10, v12 :: v_dual_add_f32 v6, v20, v6
	v_cndmask_b32_e64 v7, -v30, v30, s1
	v_cmp_eq_u32_e64 s1, 0, v25
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v43, v6, v13
	v_add_f32_e32 v7, v20, v7
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cndmask_b32_e64 v10, -v31, v31, s1
	v_cmp_eq_u32_e64 s1, 0, v26
	v_fmac_f32_e32 v43, v7, v14
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_f32_e32 v10, v20, v10
	v_cndmask_b32_e64 v6, -v32, v32, s1
	v_cndmask_b32_e64 v7, -v19, v19, s0
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v43, v10, v15 :: v_dual_add_f32 v6, v20, v6
	v_add_f32_e32 v7, v20, v7
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v43, v6, v16
	v_fmac_f32_e32 v43, v7, v17
	s_cbranch_scc0 .LBB2_1
; %bb.2:
	v_div_scale_f32 v1, null, 0x40028f5c, 0x40028f5c, v5
	v_div_scale_f32 v4, vcc_lo, v5, 0x40028f5c, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v2, v1
	v_fma_f32 v3, -v1, v2, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v3, v2
	v_dual_mov_b32 v0, 0xc000 :: v_dual_mul_f32 v3, v4, v2
	global_load_d16_b16 v0, v0, s[8:9] offset:144
	v_fma_f32 v6, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v3, v6, v2
	v_fma_f32 v1, -v1, v3, v4
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_2) | instid1(VALU_DEP_3)
	v_div_fmas_f32 v1, v1, v2, v3
	v_and_b32_e32 v2, 0x3fe, v39
	v_or_b32_e32 v3, 0x1008, v42
	v_div_fixup_f32 v1, v1, 0x40028f5c, v5
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
	.amdhsa_kernel _Z4quipILi0EEvPKfPfPKhPK6__half
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
		.amdhsa_inst_pref_size 22
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z4quipILi0EEvPKfPfPKhPK6__half,"axG",@progbits,_Z4quipILi0EEvPKfPfPKhPK6__half,comdat
.Lfunc_end2:
	.size	_Z4quipILi0EEvPKfPfPKhPK6__half, .Lfunc_end2-_Z4quipILi0EEvPKfPfPKhPK6__half
                                        ; -- End function
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.num_vgpr, max(44, .L_Z13transform1024Pfi.num_vgpr)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.num_agpr, max(0, .L_Z13transform1024Pfi.num_agpr)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.numbered_sgpr, max(33, .L_Z13transform1024Pfi.numbered_sgpr)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.num_named_barrier, max(0, .L_Z13transform1024Pfi.num_named_barrier)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.private_seg_size, 0+max(.L_Z13transform1024Pfi.private_seg_size)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.uses_vcc, or(1, .L_Z13transform1024Pfi.uses_vcc)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.uses_flat_scratch, or(0, .L_Z13transform1024Pfi.uses_flat_scratch)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.has_dyn_sized_stack, or(0, .L_Z13transform1024Pfi.has_dyn_sized_stack)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.has_recursion, or(0, .L_Z13transform1024Pfi.has_recursion)
	.set _Z4quipILi0EEvPKfPfPKhPK6__half.has_indirect_call, or(0, .L_Z13transform1024Pfi.has_indirect_call)
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 2744
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
	.section	.text._Z4quipILi1EEvPKfPfPKhPK6__half,"axG",@progbits,_Z4quipILi1EEvPKfPfPKhPK6__half,comdat
	.protected	_Z4quipILi1EEvPKfPfPKhPK6__half ; -- Begin function _Z4quipILi1EEvPKfPfPKhPK6__half
	.globl	_Z4quipILi1EEvPKfPfPKhPK6__half
	.p2align	8
	.type	_Z4quipILi1EEvPKfPfPKhPK6__half,@function
_Z4quipILi1EEvPKfPfPKhPK6__half:        ; @_Z4quipILi1EEvPKfPfPKhPK6__half
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
	s_branch .LBB3_3
.LBB3_1:                                ; %Flow
                                        ;   in Loop: Header=BB3_3 Depth=1
	s_or_b32 exec_lo, exec_lo, s11
.LBB3_2:                                ;   in Loop: Header=BB3_3 Depth=1
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
	s_cbranch_scc1 .LBB3_8
.LBB3_3:                                ; =>This Inner Loop Header: Depth=1
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
.LBB3_5:                                ; %Flow155
                                        ;   in Loop: Header=BB3_3 Depth=1
	s_and_not1_saveexec_b32 s10, s10
	s_cbranch_execz .LBB3_2
; %bb.6:                                ;   in Loop: Header=BB3_3 Depth=1
	s_mov_b32 s11, exec_lo
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
	.amdhsa_kernel _Z4quipILi1EEvPKfPfPKhPK6__half
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
	.section	.text._Z4quipILi1EEvPKfPfPKhPK6__half,"axG",@progbits,_Z4quipILi1EEvPKfPfPKhPK6__half,comdat
.Lfunc_end3:
	.size	_Z4quipILi1EEvPKfPfPKhPK6__half, .Lfunc_end3-_Z4quipILi1EEvPKfPfPKhPK6__half
                                        ; -- End function
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.num_vgpr, max(44, .L_Z13transform1024Pfi.num_vgpr)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.num_agpr, max(0, .L_Z13transform1024Pfi.num_agpr)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.numbered_sgpr, max(33, .L_Z13transform1024Pfi.numbered_sgpr)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.num_named_barrier, max(0, .L_Z13transform1024Pfi.num_named_barrier)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.private_seg_size, 0+max(.L_Z13transform1024Pfi.private_seg_size)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.uses_vcc, or(1, .L_Z13transform1024Pfi.uses_vcc)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.uses_flat_scratch, or(0, .L_Z13transform1024Pfi.uses_flat_scratch)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.has_dyn_sized_stack, or(0, .L_Z13transform1024Pfi.has_dyn_sized_stack)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.has_recursion, or(0, .L_Z13transform1024Pfi.has_recursion)
	.set _Z4quipILi1EEvPKfPfPKhPK6__half.has_indirect_call, or(0, .L_Z13transform1024Pfi.has_indirect_call)
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
	.section	.text._Z4quipILi2EEvPKfPfPKhPK6__half,"axG",@progbits,_Z4quipILi2EEvPKfPfPKhPK6__half,comdat
	.protected	_Z4quipILi2EEvPKfPfPKhPK6__half ; -- Begin function _Z4quipILi2EEvPKfPfPKhPK6__half
	.globl	_Z4quipILi2EEvPKfPfPKhPK6__half
	.p2align	8
	.type	_Z4quipILi2EEvPKfPfPKhPK6__half,@function
_Z4quipILi2EEvPKfPfPKhPK6__half:        ; @_Z4quipILi2EEvPKfPfPKhPK6__half
; %bb.0:
	s_clause 0x1
	s_load_b64 s[12:13], s[0:1], 0x10
	s_load_b128 s[8:11], s[0:1], 0x0
	v_mov_b32_e32 v39, v0
	s_lshl_b32 s3, s2, 10
	s_mov_b64 s[4:5], src_shared_base
	s_ashr_i32 s0, s3, 31
	s_mov_b32 s32, 0
	v_or_b32_e32 v0, s3, v39
	v_add_nc_u32_e32 v4, 0x80, v39
	v_lshrrev_b32_e32 v5, 3, v39
	v_add_nc_u32_e32 v7, 0x100, v39
	v_add_nc_u32_e32 v18, 0x380, v39
	v_ashrrev_i32_e32 v1, 31, v0
	v_mov_b32_e32 v43, 0
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshrrev_b32_e32 v9, 3, v7
	v_lshlrev_b64 v[2:3], 2, v[0:1]
	v_mov_b32_e32 v1, s0
	v_lshrrev_b32_e32 v6, 3, v4
	s_waitcnt lgkmcnt(0)
	v_add_co_u32 v4, s0, s12, v5
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v5, null, s13, 0, s0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	v_add_co_u32 v2, vcc_lo, s8, v2
	v_add_co_u32 v6, s0, s12, v6
	v_add_co_ci_u32_e64 v3, null, s9, v3, vcc_lo
	v_add_co_u32 v4, vcc_lo, 0xc000, v4
	v_add_co_ci_u32_e64 v8, null, s13, 0, s0
	v_add_co_ci_u32_e64 v5, null, 0, v5, vcc_lo
	v_add_co_u32 v0, vcc_lo, s8, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_co_ci_u32_e64 v1, null, s9, v1, vcc_lo
	v_add_co_u32 v6, vcc_lo, 0xc000, v6
	v_add_co_ci_u32_e64 v7, null, 0, v8, vcc_lo
	v_add_nc_u32_e32 v8, 0x180, v39
	v_add_co_u32 v9, s0, s12, v9
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v10, null, s13, 0, s0
	v_lshrrev_b32_e32 v11, 3, v8
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v8, vcc_lo, 0xc000, v9
	v_add_co_ci_u32_e64 v9, null, 0, v10, vcc_lo
	v_add_nc_u32_e32 v10, 0x200, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v11, s0, s12, v11
	v_add_co_ci_u32_e64 v12, null, s13, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshrrev_b32_e32 v13, 3, v10
	v_add_co_u32 v10, vcc_lo, 0xc000, v11
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_4)
	v_add_co_ci_u32_e64 v11, null, 0, v12, vcc_lo
	v_add_nc_u32_e32 v12, 0x280, v39
	v_add_co_u32 v13, s0, s12, v13
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v14, null, s13, 0, s0
	v_lshrrev_b32_e32 v15, 3, v12
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, vcc_lo, 0xc000, v13
	v_add_co_ci_u32_e64 v13, null, 0, v14, vcc_lo
	v_add_nc_u32_e32 v14, 0x300, v39
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_add_co_u32 v15, s0, s12, v15
	global_load_u8 v20, v[4:5], off
	v_add_co_ci_u32_e64 v16, null, s13, 0, s0
	v_lshrrev_b32_e32 v17, 3, v14
	v_add_co_u32 v14, vcc_lo, 0xc000, v15
	v_add_co_ci_u32_e64 v15, null, 0, v16, vcc_lo
	v_lshrrev_b32_e32 v16, 3, v18
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v17, s0, s12, v17
	v_add_co_ci_u32_e64 v18, null, s13, 0, s0
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v19, s0, s12, v16
	v_add_co_ci_u32_e64 v21, null, s13, 0, s0
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
	s_add_u32 s14, s12, 0xc092
	s_addc_u32 s15, s13, 0
	s_getpc_b64 s[0:1]
	s_add_u32 s0, s0, _Z13transform1024Pfi@rel32@lo+4
	s_addc_u32 s1, s1, _Z13transform1024Pfi@rel32@hi+12
	s_mov_b32 s9, 0
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
	v_dual_mov_b32 v0, 0 :: v_dual_mov_b32 v1, s5
	v_mov_b32_e32 v2, v39
	s_waitcnt vmcnt(0) lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	s_swappc_b64 s[30:31], s[0:1]
	v_dual_mov_b32 v11, 0 :: v_dual_and_b32 v0, 31, v39
	v_dual_mov_b32 v14, 0x3e800000 :: v_dual_and_b32 v1, 1, v39
	v_and_b32_e32 v2, 2, v39
	s_delay_alu instid0(VALU_DEP_3)
	v_cmp_lt_u32_e32 vcc_lo, 7, v0
	v_cmp_lt_u32_e64 s4, 15, v0
	v_cmp_gt_u32_e64 s5, 18, v0
	v_cmp_eq_u32_e64 s6, 16, v0
	v_lshlrev_b32_e32 v0, 7, v39
	v_cmp_eq_u32_e64 s3, 0, v1
	v_cmp_eq_u32_e64 s1, 0, v2
	v_lshlrev_b32_e32 v2, 8, v39
	v_and_b32_e32 v3, 4, v39
	v_add_co_u32 v0, s7, s12, v0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_co_ci_u32_e64 v1, null, s13, 0, s7
	v_cmp_eq_u32_e64 s0, 0, v3
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_co_u32 v12, s7, 0x8000, v0
	v_add_co_ci_u32_e64 v13, null, 0, v1, s7
	v_add_co_u32 v9, s7, s12, v2
	s_delay_alu instid0(VALU_DEP_1)
	v_add_co_ci_u32_e64 v10, null, s13, 0, s7
	s_mov_b64 s[16:17], 0
	s_branch .LBB4_2
.LBB4_1:                                ;   in Loop: Header=BB4_2 Depth=1
	s_or_b32 exec_lo, exec_lo, s8
	s_waitcnt lgkmcnt(2)
	v_bfe_u32 v18, v16, 16, 4
	v_bfe_u32 v20, v16, 4, 4
	v_bfe_u32 v21, v16, 20, 4
	s_add_u32 s16, s16, 1
	s_addc_u32 s17, s17, 0
	v_add_nc_u32_e32 v18, -8, v18
	v_add_nc_u32_e32 v20, -8, v20
	s_add_i32 s9, s9, 32
	s_cmpk_eq_i32 s16, 0x80
	s_delay_alu instid0(VALU_DEP_2) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_cvt_f32_i32_e32 v18, v18
	v_and_b32_e32 v17, 15, v16
	v_cvt_f32_i32_e32 v20, v20
	s_waitcnt lgkmcnt(1)
	v_dual_mul_f32 v18, 0.5, v18 :: v_dual_and_b32 v19, 16, v15
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v20, 0.5, v20 :: v_dual_add_nc_u32 v17, -8, v17
	v_cvt_f32_i32_e32 v17, v17
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_mul_f32 v17, 0.5, v17 :: v_dual_and_b32 v8, 0xff, v15
	v_bcnt_u32_b32 v8, v8, 0
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_xor_b32_e32 v22, v8, v15
	v_and_b32_e32 v8, 1, v8
	v_and_b32_e32 v22, 1, v22
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s7, 0, v8
	v_cndmask_b32_e64 v8, 0xbe800000, v14, s7
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s7, 0, v22
	v_cndmask_b32_e64 v17, -v17, v17, s7
	v_cmp_eq_u32_e64 s7, 0, v19
	v_and_b32_e32 v19, 2, v15
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_add_f32_e32 v17, v8, v17
	v_cndmask_b32_e64 v18, -v18, v18, s7
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e64 s7, 0, v19
	v_and_b32_e32 v19, 32, v15
	v_dual_fmac_f32 v43, v17, v4 :: v_dual_add_f32 v18, v8, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_3) | instid1(VALU_DEP_4)
	v_cndmask_b32_e64 v4, -v20, v20, s7
	v_add_nc_u32_e32 v21, -8, v21
	v_bfe_u32 v17, v16, 8, 4
	v_cmp_eq_u32_e64 s7, 0, v19
	v_dual_fmac_f32 v43, v18, v5 :: v_dual_add_f32 v4, v8, v4
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_4)
	v_cvt_f32_i32_e32 v21, v21
	v_add_nc_u32_e32 v5, -8, v17
	v_bfe_u32 v18, v16, 24, 4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v43, v4, v6 :: v_dual_mul_f32 v20, 0.5, v21
	v_add_nc_u32_e32 v6, -8, v18
	v_bfe_u32 v18, v16, 12, 4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cndmask_b32_e64 v17, -v20, v20, s7
	v_add_f32_e32 v4, v8, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_3) | instid1(VALU_DEP_3)
	v_fmac_f32_e32 v43, v4, v7
	v_cvt_f32_i32_e32 v4, v6
	v_add_nc_u32_e32 v6, -8, v18
	v_lshrrev_b32_e32 v7, 28, v16
	v_mul_f32_e32 v4, 0.5, v4
	v_cvt_f32_i32_e32 v5, v5
	s_delay_alu instid0(VALU_DEP_4) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_cvt_f32_i32_e32 v6, v6
	v_and_b32_e32 v17, 4, v15
	v_dual_mul_f32 v5, 0.5, v5 :: v_dual_mul_f32 v6, 0.5, v6
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s7, 0, v17
	v_cndmask_b32_e64 v5, -v5, v5, s7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_dual_add_f32 v5, v8, v5 :: v_dual_and_b32 v16, 64, v15
	v_cmp_eq_u32_e64 s7, 0, v16
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v43, v5, v0 :: v_dual_and_b32 v16, 8, v15
	v_cndmask_b32_e64 v4, -v4, v4, s7
	v_add_nc_u32_e32 v7, -8, v7
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cmp_eq_u32_e64 s7, 0, v16
	v_add_f32_e32 v4, v8, v4
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_cvt_f32_i32_e32 v0, v7
	v_cndmask_b32_e64 v5, -v6, v6, s7
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_2)
	v_dual_fmac_f32 v43, v4, v1 :: v_dual_and_b32 v6, 0x80, v15
	v_dual_mul_f32 v0, 0.5, v0 :: v_dual_add_f32 v1, v8, v5
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cmp_eq_u32_e64 s7, 0, v6
	v_cndmask_b32_e64 v0, -v0, v0, s7
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v43, v1, v2
	v_add_co_u32 v9, s7, v9, 2
	v_add_co_ci_u32_e64 v10, null, 0, v10, s7
	s_delay_alu instid0(VALU_DEP_4) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v0, v8, v0
	v_fmac_f32_e32 v43, v0, v3
	s_cbranch_scc1 .LBB4_18
.LBB4_2:                                ; =>This Inner Loop Header: Depth=1
	global_load_u16 v15, v[9:10], off
                                        ; implicit-def: $vgpr8
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v0, 6, v15
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_and_b32_e32 v2, 0x3fc, v0
	v_add_co_u32 v0, s7, v12, s16
	v_add_co_ci_u32_e64 v1, null, s17, v13, s7
	s_clause 0x1
	global_load_b32 v16, v2, s[14:15]
	global_load_d16_u8 v17, v[0:1], off
	v_mov_b32_e32 v0, s9
	ds_load_b128 v[4:7], v0
	ds_load_b128 v[0:3], v0 offset:16
	s_and_saveexec_b32 s7, vcc_lo
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s7, exec_lo, s7
	s_cbranch_execz .LBB4_10
; %bb.3:                                ;   in Loop: Header=BB4_2 Depth=1
                                        ; implicit-def: $vgpr8
	s_and_saveexec_b32 s8, s4
	s_delay_alu instid0(SALU_CYCLE_1)
	s_xor_b32 s8, exec_lo, s8
	s_cbranch_execz .LBB4_7
; %bb.4:                                ;   in Loop: Header=BB4_2 Depth=1
	v_mov_b32_e32 v8, 0
	s_and_saveexec_b32 s18, s5
	s_cbranch_execz .LBB4_6
; %bb.5:                                ;   in Loop: Header=BB4_2 Depth=1
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v8, -v3, v3, s6
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v8, v2, v8
.LBB4_6:                                ; %Flow201
                                        ;   in Loop: Header=BB4_2 Depth=1
	s_or_b32 exec_lo, exec_lo, s18
.LBB4_7:                                ; %Flow202
                                        ;   in Loop: Header=BB4_2 Depth=1
	s_and_not1_saveexec_b32 s8, s8
	s_cbranch_execz .LBB4_9
; %bb.8:                                ;   in Loop: Header=BB4_2 Depth=1
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v8, -v7, v7, s3
	s_waitcnt lgkmcnt(0)
	v_cndmask_b32_e64 v18, -v0, v0, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v8, v8, v18
	v_cndmask_b32_e64 v18, -v1, v1, s0
	v_add_f32_e32 v8, v8, v18
.LBB4_9:                                ; %Flow203
                                        ;   in Loop: Header=BB4_2 Depth=1
	s_or_b32 exec_lo, exec_lo, s8
.LBB4_10:                               ; %Flow204
                                        ;   in Loop: Header=BB4_2 Depth=1
	s_and_not1_saveexec_b32 s7, s7
	s_cbranch_execz .LBB4_12
; %bb.11:                               ;   in Loop: Header=BB4_2 Depth=1
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v8, -v4, v4, s3
	v_cndmask_b32_e64 v18, -v5, v5, s1
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_1)
	v_add_f32_e32 v8, v8, v18
	v_cndmask_b32_e64 v18, -v6, v6, s0
	v_add_f32_e32 v8, v8, v18
.LBB4_12:                               ;   in Loop: Header=BB4_2 Depth=1
	s_or_b32 exec_lo, exec_lo, s7
	s_waitcnt vmcnt(0)
	v_and_b32_e32 v18, 0x7f, v17
	s_mov_b32 s18, exec_lo
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_cmp_gt_u32_e64 s7, 64, v18
	v_cndmask_b32_e64 v19, 0x7f, 0, s7
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_xor_b32_e32 v18, v19, v18
	v_lshrrev_b32_e32 v19, 3, v18
	v_bcnt_u32_b32 v20, v18, 0
	v_and_b32_e32 v18, 7, v18
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_or_b32_e32 v19, 8, v19
	v_and_or_b32 v20, v20, 1, 16
	s_delay_alu instid0(VALU_DEP_3) | instskip(NEXT) | instid1(VALU_DEP_3)
	v_lshlrev_b32_e32 v18, 2, v18
	v_lshlrev_b32_e32 v19, 2, v19
	s_delay_alu instid0(VALU_DEP_3) | instskip(SKIP_4) | instid1(VALU_DEP_1)
	v_lshlrev_b32_e32 v20, 2, v20
	ds_bpermute_b32 v18, v18, v8
	ds_bpermute_b32 v19, v19, v8
	ds_bpermute_b32 v8, v20, v8
	v_bfe_i32 v20, v17, 0, 8
	v_cmpx_lt_i16_e32 -1, v20.l
	s_xor_b32 s18, exec_lo, s18
	s_cbranch_execz .LBB4_16
; %bb.13:                               ;   in Loop: Header=BB4_2 Depth=1
	s_waitcnt lgkmcnt(0)
	v_and_b16 v8.l, 0xff, v17.l
	s_mov_b32 s19, exec_lo
	s_delay_alu instid0(VALU_DEP_1)
	v_cmpx_ne_u16_e32 0x7f, v8.l
	s_cbranch_execz .LBB4_15
; %bb.14:                               ;   in Loop: Header=BB4_2 Depth=1
	v_and_b32_e32 v17, 0xff, v17
	s_delay_alu instid0(VALU_DEP_1) | instskip(SKIP_1) | instid1(VALU_DEP_2)
	v_bfe_u32 v18, v17, 3, 3
	v_and_b32_e32 v17, 7, v17
	v_lshl_add_u32 v19, v18, 2, s9
	s_delay_alu instid0(VALU_DEP_2)
	v_lshl_add_u32 v20, v17, 2, s9
	v_cmp_gt_u32_e64 s8, v17, v18
	ds_load_b32 v19, v19
	ds_load_b32 v20, v20
	s_waitcnt lgkmcnt(1)
	v_cndmask_b32_e64 v17, v19, -v19, s8
	v_cmp_gt_u16_e64 s8, 64, v8.l
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v17, v20, v17
	v_cndmask_b32_e64 v8, -v17, v17, s8
	s_delay_alu instid0(VALU_DEP_1)
	v_add_f32_e32 v11, v11, v8
.LBB4_15:                               ; %Flow
                                        ;   in Loop: Header=BB4_2 Depth=1
	s_or_b32 exec_lo, exec_lo, s19
                                        ; implicit-def: $vgpr18
                                        ; implicit-def: $vgpr19
                                        ; implicit-def: $vgpr8
.LBB4_16:                               ; %Flow200
                                        ;   in Loop: Header=BB4_2 Depth=1
	s_and_not1_saveexec_b32 s8, s18
	s_cbranch_execz .LBB4_1
; %bb.17:                               ;   in Loop: Header=BB4_2 Depth=1
	s_waitcnt lgkmcnt(1)
	v_add_f32_e32 v17, v18, v19
	s_waitcnt lgkmcnt(0)
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_add_f32_e32 v8, v17, v8
	v_cndmask_b32_e64 v8, -v8, v8, s7
	s_delay_alu instid0(VALU_DEP_1)
	v_fmac_f32_e32 v11, 0.5, v8
	s_branch .LBB4_1
.LBB4_18:
	v_div_scale_f32 v1, null, 0x40028f5c, 0x40028f5c, v11
	v_div_scale_f32 v4, vcc_lo, v11, 0x40028f5c, v11
	s_delay_alu instid0(VALU_DEP_2) | instskip(NEXT) | instid1(TRANS32_DEP_1)
	v_rcp_f32_e32 v2, v1
	v_fma_f32 v3, -v1, v2, 1.0
	s_delay_alu instid0(VALU_DEP_1) | instskip(NEXT) | instid1(VALU_DEP_1)
	v_fmac_f32_e32 v2, v3, v2
	v_dual_mov_b32 v0, 0xc000 :: v_dual_mul_f32 v3, v4, v2
	global_load_d16_b16 v0, v0, s[12:13] offset:144
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
	v_and_b32_e32 v2, 0x3fd, v39
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s3
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 0x3fb, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_or_b32_e32 v3, 0x1010, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s1
	s_delay_alu instid0(VALU_DEP_1)
	v_dual_add_f32 v0, v1, v0 :: v_dual_lshlrev_b32 v1, 2, v2
	v_and_b32_e32 v2, 0x3f7, v39
	ds_store_b32 v42, v0 offset:4096
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	ds_load_b32 v0, v3
	ds_load_b32 v1, v1 offset:4096
	v_or_b32_e32 v3, 0x1020, v42
	s_waitcnt lgkmcnt(0)
	s_barrier
	buffer_gl0_inv
	v_cndmask_b32_e64 v0, -v0, v0, s0
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
	v_add_co_u32 v0, vcc_lo, s10, v0
	v_add_co_ci_u32_e64 v1, null, s11, v1, vcc_lo
	global_store_b32 v[0:1], v2, off
	s_nop 0
	s_sendmsg sendmsg(MSG_DEALLOC_VGPRS)
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z4quipILi2EEvPKfPfPKhPK6__half
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
		.amdhsa_inst_pref_size 26
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.section	.text._Z4quipILi2EEvPKfPfPKhPK6__half,"axG",@progbits,_Z4quipILi2EEvPKfPfPKhPK6__half,comdat
.Lfunc_end4:
	.size	_Z4quipILi2EEvPKfPfPKhPK6__half, .Lfunc_end4-_Z4quipILi2EEvPKfPfPKhPK6__half
                                        ; -- End function
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.num_vgpr, max(44, .L_Z13transform1024Pfi.num_vgpr)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.num_agpr, max(0, .L_Z13transform1024Pfi.num_agpr)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.numbered_sgpr, max(33, .L_Z13transform1024Pfi.numbered_sgpr)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.num_named_barrier, max(0, .L_Z13transform1024Pfi.num_named_barrier)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.private_seg_size, 0+max(.L_Z13transform1024Pfi.private_seg_size)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.uses_vcc, or(1, .L_Z13transform1024Pfi.uses_vcc)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.uses_flat_scratch, or(0, .L_Z13transform1024Pfi.uses_flat_scratch)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.has_dyn_sized_stack, or(0, .L_Z13transform1024Pfi.has_dyn_sized_stack)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.has_recursion, or(0, .L_Z13transform1024Pfi.has_recursion)
	.set _Z4quipILi2EEvPKfPfPKhPK6__half.has_indirect_call, or(0, .L_Z13transform1024Pfi.has_indirect_call)
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 3316
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
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 24
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z6scalarPKfPfPKh
    .private_segment_fixed_size: 0
    .sgpr_count:     24
    .sgpr_spill_count: 0
    .symbol:         _Z6scalarPKfPfPKh.kd
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
    .name:           _Z4quipILi0EEvPKfPfPKhPK6__half
    .private_segment_fixed_size: 0
    .sgpr_count:     35
    .sgpr_spill_count: 0
    .symbol:         _Z4quipILi0EEvPKfPfPKhPK6__half.kd
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
    .name:           _Z4quipILi1EEvPKfPfPKhPK6__half
    .private_segment_fixed_size: 0
    .sgpr_count:     35
    .sgpr_spill_count: 0
    .symbol:         _Z4quipILi1EEvPKfPfPKhPK6__half.kd
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
    .name:           _Z4quipILi2EEvPKfPfPKhPK6__half
    .private_segment_fixed_size: 0
    .sgpr_count:     35
    .sgpr_spill_count: 0
    .symbol:         _Z4quipILi2EEvPKfPfPKhPK6__half.kd
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
