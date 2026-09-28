	.file	"reader.hip"
	.text
	.globl	prepare_magnitudes              # -- Begin function prepare_magnitudes
	.p2align	4
	.type	prepare_magnitudes,@function
prepare_magnitudes:                     # @prepare_magnitudes
	.cfi_startproc
# %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	xorl	%r8d, %r8d
	leaq	.LJTI0_0(%rip), %r9
	xorl	%r10d, %r10d
	jmp	.LBB0_1
	.p2align	4
.LBB0_2:                                #   in Loop: Header=BB0_1 Depth=1
	movl	%r10d, %eax
	andl	$7, %eax
	movl	%r10d, %edx
	shrl	$3, %edx
	andl	$7, %edx
	movl	$1, %r11d
	movl	%eax, %ecx
	shll	%cl, %r11d
	movl	$1, %ebx
	movl	%edx, %ecx
	shll	%cl, %ebx
	cmpl	%edx, %eax
	cmovel	%r8d, %ebx
.LBB0_52:                               # %_Z5masksjPKhRj.exit.i
                                        #   in Loop: Header=BB0_1 Depth=1
	movl	%ebx, %eax
	shrl	$16, %eax
	xorl	%ebx, %eax
	movl	%ebx, %ecx
	andl	$1, %ecx
	addl	%ecx, %ecx
	movl	%r11d, %edx
	andl	$1, %edx
	leal	(%rcx,%rdx,4), %ecx
	movl	%ebx, %edx
	andl	$2, %edx
	movl	%r11d, %r14d
	andl	$2, %r14d
	leal	(%rdx,%r14,2), %edx
	shll	$4, %edx
	orl	%ecx, %edx
	movl	%ebx, %ecx
	shrl	%ecx
	andl	$2, %ecx
	movl	%r11d, %ebp
	andl	$4, %ebp
	orl	%ecx, %ebp
	shll	$8, %ebp
	orl	%edx, %ebp
	movl	%ebx, %ecx
	shrl	$2, %ecx
	andl	$2, %ecx
	movl	%r11d, %edx
	shrl	%edx
	andl	$4, %edx
	orl	%ecx, %edx
	shll	$12, %edx
	orl	%ebp, %edx
	movl	%ebx, %ebp
	shrl	$3, %ebp
	andl	$2, %ebp
	movl	%r11d, %ecx
	shrl	$2, %ecx
	andl	$4, %ecx
	orl	%ebp, %ecx
	shll	$16, %ecx
	orl	%edx, %ecx
	movl	%ebx, %edx
	shrl	$4, %edx
	andl	$2, %edx
	movl	%r11d, %ebp
	shrl	$3, %ebp
	andl	$4, %ebp
	orl	%edx, %ebp
	shll	$20, %ebp
	movl	%ebx, %r14d
	shrl	$5, %r14d
	andl	$2, %r14d
	movl	%r11d, %edx
	shrl	$4, %edx
	andl	$4, %edx
	orl	%r14d, %edx
	shll	$24, %edx
	orl	%ebp, %edx
	orl	%ecx, %edx
	shrl	$6, %ebx
	andl	$2, %ebx
	shrl	$5, %r11d
	andl	$4, %r11d
	orl	%ebx, %r11d
	shll	$28, %r11d
	movl	%r11d, %ecx
	orl	%edx, %ecx
	orl	$-1717986919, %ecx              # imm = 0x99999999
	xorl	$2040109465, %r11d              # imm = 0x79999999
	orl	%edx, %r11d
	xorb	%ah, %al
	cmovpl	%ecx, %r11d
	movl	%r11d, (%rsi,%r10,4)
	incq	%r10
	cmpq	$256, %r10                      # imm = 0x100
	je	.LBB0_53
.LBB0_1:                                # =>This Inner Loop Header: Depth=1
	cmpq	$192, %r10
	jae	.LBB0_2
# %bb.3:                                #   in Loop: Header=BB0_1 Depth=1
	cmpq	$163, %r10
	jb	.LBB0_5
# %bb.4:                                #   in Loop: Header=BB0_1 Depth=1
	movzbl	49135(%rdi,%r10), %ebx
.LBB0_51:                               # %_Z5masksjPKhRj.exit.i
                                        #   in Loop: Header=BB0_1 Depth=1
	xorl	%r11d, %r11d
	jmp	.LBB0_52
	.p2align	4
.LBB0_5:                                #   in Loop: Header=BB0_1 Depth=1
	movl	$35, %edx
	cmpq	$92, %r10
	jbe	.LBB0_7
# %bb.6:                                #   in Loop: Header=BB0_1 Depth=1
	movl	$4, %r11d
	movl	$-93, %ecx
	jmp	.LBB0_13
.LBB0_7:                                #   in Loop: Header=BB0_1 Depth=1
	cmpq	$36, %r10
	jbe	.LBB0_9
# %bb.8:                                #   in Loop: Header=BB0_1 Depth=1
	movl	$3, %r11d
	movl	$-37, %ecx
	jmp	.LBB0_13
.LBB0_9:                                #   in Loop: Header=BB0_1 Depth=1
	cmpq	$8, %r10
	jbe	.LBB0_11
# %bb.10:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$21, %edx
	movl	$2, %r11d
	movl	$-9, %ecx
	jmp	.LBB0_13
.LBB0_11:                               #   in Loop: Header=BB0_1 Depth=1
	testq	%r10, %r10
	je	.LBB0_54
# %bb.12:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$7, %edx
	movl	$1, %r11d
	movl	$-1, %ecx
	.p2align	4
.LBB0_13:                               # %_Z7choose8jj.exit.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	leal	(%r10,%rcx), %eax
	xorl	%ebx, %ebx
	cmpl	%eax, %edx
	setbe	%bl
	cmoval	%r8d, %edx
	movl	%ebx, %r14d
	shll	$7, %r14d
	subl	%ebx, %r11d
	je	.LBB0_14
# %bb.15:                               # %_Z7choose8jj.exit.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	cmpl	$1, %r11d
	je	.LBB0_16
# %bb.17:                               # %_Z7choose8jj.exit.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	cmpl	$3, %r11d
	jne	.LBB0_19
# %bb.18:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$20, %ebp
	jmp	.LBB0_20
.LBB0_16:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$6, %ebp
	jmp	.LBB0_20
.LBB0_14:                               #   in Loop: Header=BB0_1 Depth=1
	movl	%r14d, %ebx
	jmp	.LBB0_52
.LBB0_19:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$15, %ebp
.LBB0_20:                               # %_Z7choose8jj.exit.1.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	subl	%edx, %ecx
	leaq	(%r10,%rcx), %r15
	movl	%r14d, %ebx
	orl	$64, %ebx
	xorl	%r12d, %r12d
	cmpl	%r15d, %ebp
	cmoval	%r14d, %ebx
	setbe	%r12b
	cmoval	%r8d, %ebp
	subl	%r12d, %r11d
	leal	-2(%r11), %r14d
	cmpl	$2, %r14d
	jae	.LBB0_21
# %bb.22:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$10, %r14d
	jmp	.LBB0_23
.LBB0_21:                               # %_Z7choose8jj.exit.1.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	movl	$5, %r14d
	testl	%r11d, %r11d
	je	.LBB0_52
.LBB0_23:                               #   in Loop: Header=BB0_1 Depth=1
	subl	%ebp, %ecx
	leaq	(%r10,%rcx), %r15
	cmpl	%r15d, %r14d
	jbe	.LBB0_25
# %bb.24:                               #   in Loop: Header=BB0_1 Depth=1
	subl	%edx, %eax
	subl	%ebp, %eax
	cmpl	$3, %r11d
	ja	.LBB0_30
.LBB0_28:                               # %_Z7choose8jj.exit.2.thread.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	movl	$4, %edx
	movl	%r11d, %ecx
	movslq	(%r9,%rcx,4), %rcx
	addq	%r9, %rcx
	jmpq	*%rcx
.LBB0_29:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$6, %edx
.LBB0_31:                               #   in Loop: Header=BB0_1 Depth=1
	cmpl	%eax, %edx
	jbe	.LBB0_32
.LBB0_33:                               # %_Z7choose8jj.exit.3.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	xorl	%ecx, %ecx
	cmpl	$3, %r11d
	jbe	.LBB0_34
	jmp	.LBB0_38
.LBB0_25:                               # %_Z7choose8jj.exit.2.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	orl	$32, %ebx
	subl	%r14d, %ecx
	addq	%r10, %rcx
	decl	%r11d
	cmpl	$4, %r11d
	jbe	.LBB0_26
# %bb.55:                               # %_Z7choose8jj.exit.2.i.i..thread51.3.i.i_crit_edge
                                        #   in Loop: Header=BB0_1 Depth=1
	xorl	%edx, %edx
	movl	$-1, %r11d
	movl	%ecx, %eax
	jmp	.LBB0_32
.LBB0_26:                               # %_Z7choose8jj.exit.2.i.i._Z7choose8jj.exit.2.thread.i.i_crit_edge
                                        #   in Loop: Header=BB0_1 Depth=1
	movl	%ecx, %eax
	cmpl	$3, %r11d
	jbe	.LBB0_28
.LBB0_30:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$1, %edx
	cmpl	%eax, %edx
	ja	.LBB0_33
.LBB0_32:                               # %.thread51.3.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	subl	%edx, %eax
	orl	$16, %ebx
	decl	%r11d
	xorl	%ecx, %ecx
	cmpl	$3, %r11d
	ja	.LBB0_38
.LBB0_34:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$3, %ecx
	leal	-1(%r11), %edx
	cmpl	$2, %edx
	jb	.LBB0_37
# %bb.35:                               #   in Loop: Header=BB0_1 Depth=1
	testl	%r11d, %r11d
	je	.LBB0_52
# %bb.36:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$1, %ecx
.LBB0_37:                               #   in Loop: Header=BB0_1 Depth=1
	cmpl	%eax, %ecx
	ja	.LBB0_39
.LBB0_38:                               # %.thread51.4.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	orl	$8, %ebx
	subl	%ecx, %eax
	decl	%r11d
.LBB0_39:                               # %_Z7choose8jj.exit.4.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	xorl	%ecx, %ecx
	cmpl	$2, %r11d
	ja	.LBB0_44
# %bb.40:                               #   in Loop: Header=BB0_1 Depth=1
	testl	%r11d, %r11d
	je	.LBB0_52
# %bb.41:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$2, %ecx
	cmpl	$1, %r11d
	jne	.LBB0_42
# %bb.43:                               #   in Loop: Header=BB0_1 Depth=1
	cmpl	%eax, %ecx
	jbe	.LBB0_44
.LBB0_45:                               # %_Z7choose8jj.exit.5.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	cmpl	$1, %r11d
	jbe	.LBB0_46
	jmp	.LBB0_49
.LBB0_42:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$1, %ecx
	cmpl	%eax, %ecx
	ja	.LBB0_45
.LBB0_44:                               # %.thread51.5.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	orl	$4, %ebx
	subl	%ecx, %eax
	decl	%r11d
	cmpl	$1, %r11d
	ja	.LBB0_49
.LBB0_46:                               #   in Loop: Header=BB0_1 Depth=1
	jne	.LBB0_51
# %bb.47:                               #   in Loop: Header=BB0_1 Depth=1
	testl	%eax, %eax
	je	.LBB0_48
.LBB0_49:                               # %.thread51.6.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	orl	$2, %ebx
	xorl	%eax, %eax
	cmpl	$1, %r11d
	setne	%al
.LBB0_50:                               # %_Z7choose8jj.exit.6.i.i
                                        #   in Loop: Header=BB0_1 Depth=1
	orl	%eax, %ebx
	jmp	.LBB0_51
.LBB0_54:                               #   in Loop: Header=BB0_1 Depth=1
	xorl	%r11d, %r11d
	xorl	%ebx, %ebx
	jmp	.LBB0_52
.LBB0_48:                               #   in Loop: Header=BB0_1 Depth=1
	movl	$1, %eax
	jmp	.LBB0_50
.LBB0_53:
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end0:
	.size	prepare_magnitudes, .Lfunc_end0-prepare_magnitudes
	.cfi_endproc
	.section	.rodata,"a",@progbits
	.p2align	2, 0x0
.LJTI0_0:
	.long	.LBB0_52-.LJTI0_0
	.long	.LBB0_31-.LJTI0_0
	.long	.LBB0_29-.LJTI0_0
	.long	.LBB0_31-.LJTI0_0
                                        # -- End function
	.text
	.globl	prepare_device_magnitudes       # -- Begin function prepare_device_magnitudes
	.p2align	4
	.type	prepare_device_magnitudes,@function
prepare_device_magnitudes:              # @prepare_device_magnitudes
	.cfi_startproc
# %bb.0:
	subq	$1048, %rsp                     # imm = 0x418
	.cfi_def_cfa_offset 1056
	movq	$0, 8(%rsp)
	leaq	16(%rsp), %rsi
	callq	prepare_magnitudes
	leaq	8(%rsp), %rdi
	movl	$1024, %esi                     # imm = 0x400
	callq	hipMalloc@PLT
	testl	%eax, %eax
	jne	.LBB1_3
# %bb.1:
	movq	8(%rsp), %rdi
	leaq	16(%rsp), %rsi
	movl	$1024, %edx                     # imm = 0x400
	movl	$1, %ecx
	callq	hipMemcpy@PLT
	movl	%eax, %ecx
	movq	8(%rsp), %rax
	testl	%ecx, %ecx
	je	.LBB1_4
# %bb.2:
	movq	%rax, %rdi
	callq	hipFree@PLT
.LBB1_3:
	xorl	%eax, %eax
.LBB1_4:
	addq	$1048, %rsp                     # imm = 0x418
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end1:
	.size	prepare_device_magnitudes, .Lfunc_end1-prepare_device_magnitudes
	.cfi_endproc
                                        # -- End function
	.globl	release_device_magnitudes       # -- Begin function release_device_magnitudes
	.p2align	4
	.type	release_device_magnitudes,@function
release_device_magnitudes:              # @release_device_magnitudes
	.cfi_startproc
# %bb.0:
	jmp	hipFree@PLT                     # TAILCALL
.Lfunc_end2:
	.size	release_device_magnitudes, .Lfunc_end2-release_device_magnitudes
	.cfi_endproc
                                        # -- End function
	.globl	launch_original                 # -- Begin function launch_original
	.p2align	4
	.type	launch_original,@function
launch_original:                        # @launch_original
	.cfi_startproc
# %bb.0:
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	subq	$112, %rsp
	.cfi_def_cfa_offset 144
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdx, %rbx
	movq	%rsi, %r14
	movq	%rdi, %r15
	movl	%ecx, %edi
	movabsq	$4294967296, %rdx               # imm = 0x100000000
	orq	%rdx, %rdi
	orq	$128, %rdx
	movl	$1, %esi
	movl	$1, %ecx
	xorl	%r8d, %r8d
	xorl	%r9d, %r9d
	callq	__hipPushCallConfiguration@PLT
	testl	%eax, %eax
	jne	.LBB3_2
# %bb.1:
	movq	%r15, 72(%rsp)
	movq	%r14, 64(%rsp)
	movq	%rbx, 56(%rsp)
	movq	$0, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 80(%rsp)
	leaq	64(%rsp), %rax
	movq	%rax, 88(%rsp)
	leaq	56(%rsp), %rax
	movq	%rax, 96(%rsp)
	leaq	48(%rsp), %rax
	movq	%rax, 104(%rsp)
	leaq	32(%rsp), %rdi
	leaq	16(%rsp), %rsi
	leaq	8(%rsp), %rdx
	movq	%rsp, %rcx
	callq	__hipPopCallConfiguration@PLT
	movq	32(%rsp), %rsi
	movl	40(%rsp), %edx
	movq	16(%rsp), %rcx
	movl	24(%rsp), %r8d
	movq	_Z4quipILi0EEvPKfPfPKhPKj@GOTPCREL(%rip), %rdi
	leaq	80(%rsp), %r9
	pushq	(%rsp)
	.cfi_adjust_cfa_offset 8
	pushq	16(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	hipLaunchKernel@PLT
	addq	$16, %rsp
	.cfi_adjust_cfa_offset -16
.LBB3_2:
	addq	$112, %rsp
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end3:
	.size	launch_original, .Lfunc_end3-launch_original
	.cfi_endproc
                                        # -- End function
	.section	.text._Z19__device_stub__quipILi0EEvPKfPfPKhPKj,"axG",@progbits,_Z19__device_stub__quipILi0EEvPKfPfPKhPKj,comdat
	.weak	_Z19__device_stub__quipILi0EEvPKfPfPKhPKj # -- Begin function _Z19__device_stub__quipILi0EEvPKfPfPKhPKj
	.p2align	4
	.type	_Z19__device_stub__quipILi0EEvPKfPfPKhPKj,@function
_Z19__device_stub__quipILi0EEvPKfPfPKhPKj: # @_Z19__device_stub__quipILi0EEvPKfPfPKhPKj
	.cfi_startproc
# %bb.0:
	subq	$120, %rsp
	.cfi_def_cfa_offset 128
	movq	%rdi, 72(%rsp)
	movq	%rsi, 64(%rsp)
	movq	%rdx, 56(%rsp)
	movq	%rcx, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 80(%rsp)
	leaq	64(%rsp), %rax
	movq	%rax, 88(%rsp)
	leaq	56(%rsp), %rax
	movq	%rax, 96(%rsp)
	leaq	48(%rsp), %rax
	movq	%rax, 104(%rsp)
	leaq	32(%rsp), %rdi
	leaq	16(%rsp), %rsi
	leaq	8(%rsp), %rdx
	movq	%rsp, %rcx
	callq	__hipPopCallConfiguration@PLT
	movq	32(%rsp), %rsi
	movl	40(%rsp), %edx
	movq	16(%rsp), %rcx
	movl	24(%rsp), %r8d
	movq	_Z4quipILi0EEvPKfPfPKhPKj@GOTPCREL(%rip), %rdi
	leaq	80(%rsp), %r9
	pushq	(%rsp)
	.cfi_adjust_cfa_offset 8
	pushq	16(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	hipLaunchKernel@PLT
	addq	$136, %rsp
	.cfi_adjust_cfa_offset -136
	retq
.Lfunc_end4:
	.size	_Z19__device_stub__quipILi0EEvPKfPfPKhPKj, .Lfunc_end4-_Z19__device_stub__quipILi0EEvPKfPfPKhPKj
	.cfi_endproc
                                        # -- End function
	.text
	.globl	launch_direct                   # -- Begin function launch_direct
	.p2align	4
	.type	launch_direct,@function
launch_direct:                          # @launch_direct
	.cfi_startproc
# %bb.0:
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	subq	$112, %rsp
	.cfi_def_cfa_offset 144
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdx, %rbx
	movq	%rsi, %r14
	movq	%rdi, %r15
	movl	%ecx, %edi
	movabsq	$4294967296, %rdx               # imm = 0x100000000
	orq	%rdx, %rdi
	orq	$128, %rdx
	movl	$1, %esi
	movl	$1, %ecx
	xorl	%r8d, %r8d
	xorl	%r9d, %r9d
	callq	__hipPushCallConfiguration@PLT
	testl	%eax, %eax
	jne	.LBB5_2
# %bb.1:
	movq	%r15, 72(%rsp)
	movq	%r14, 64(%rsp)
	movq	%rbx, 56(%rsp)
	movq	$0, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 80(%rsp)
	leaq	64(%rsp), %rax
	movq	%rax, 88(%rsp)
	leaq	56(%rsp), %rax
	movq	%rax, 96(%rsp)
	leaq	48(%rsp), %rax
	movq	%rax, 104(%rsp)
	leaq	32(%rsp), %rdi
	leaq	16(%rsp), %rsi
	leaq	8(%rsp), %rdx
	movq	%rsp, %rcx
	callq	__hipPopCallConfiguration@PLT
	movq	32(%rsp), %rsi
	movl	40(%rsp), %edx
	movq	16(%rsp), %rcx
	movl	24(%rsp), %r8d
	movq	_Z4quipILi1EEvPKfPfPKhPKj@GOTPCREL(%rip), %rdi
	leaq	80(%rsp), %r9
	pushq	(%rsp)
	.cfi_adjust_cfa_offset 8
	pushq	16(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	hipLaunchKernel@PLT
	addq	$16, %rsp
	.cfi_adjust_cfa_offset -16
.LBB5_2:
	addq	$112, %rsp
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end5:
	.size	launch_direct, .Lfunc_end5-launch_direct
	.cfi_endproc
                                        # -- End function
	.section	.text._Z19__device_stub__quipILi1EEvPKfPfPKhPKj,"axG",@progbits,_Z19__device_stub__quipILi1EEvPKfPfPKhPKj,comdat
	.weak	_Z19__device_stub__quipILi1EEvPKfPfPKhPKj # -- Begin function _Z19__device_stub__quipILi1EEvPKfPfPKhPKj
	.p2align	4
	.type	_Z19__device_stub__quipILi1EEvPKfPfPKhPKj,@function
_Z19__device_stub__quipILi1EEvPKfPfPKhPKj: # @_Z19__device_stub__quipILi1EEvPKfPfPKhPKj
	.cfi_startproc
# %bb.0:
	subq	$120, %rsp
	.cfi_def_cfa_offset 128
	movq	%rdi, 72(%rsp)
	movq	%rsi, 64(%rsp)
	movq	%rdx, 56(%rsp)
	movq	%rcx, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 80(%rsp)
	leaq	64(%rsp), %rax
	movq	%rax, 88(%rsp)
	leaq	56(%rsp), %rax
	movq	%rax, 96(%rsp)
	leaq	48(%rsp), %rax
	movq	%rax, 104(%rsp)
	leaq	32(%rsp), %rdi
	leaq	16(%rsp), %rsi
	leaq	8(%rsp), %rdx
	movq	%rsp, %rcx
	callq	__hipPopCallConfiguration@PLT
	movq	32(%rsp), %rsi
	movl	40(%rsp), %edx
	movq	16(%rsp), %rcx
	movl	24(%rsp), %r8d
	movq	_Z4quipILi1EEvPKfPfPKhPKj@GOTPCREL(%rip), %rdi
	leaq	80(%rsp), %r9
	pushq	(%rsp)
	.cfi_adjust_cfa_offset 8
	pushq	16(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	hipLaunchKernel@PLT
	addq	$136, %rsp
	.cfi_adjust_cfa_offset -136
	retq
.Lfunc_end6:
	.size	_Z19__device_stub__quipILi1EEvPKfPfPKhPKj, .Lfunc_end6-_Z19__device_stub__quipILi1EEvPKfPfPKhPKj
	.cfi_endproc
                                        # -- End function
	.text
	.globl	launch_prepared                 # -- Begin function launch_prepared
	.p2align	4
	.type	launch_prepared,@function
launch_prepared:                        # @launch_prepared
	.cfi_startproc
# %bb.0:
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r12
	.cfi_def_cfa_offset 32
	pushq	%rbx
	.cfi_def_cfa_offset 40
	subq	$120, %rsp
	.cfi_def_cfa_offset 160
	.cfi_offset %rbx, -40
	.cfi_offset %r12, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rcx, %rbx
	movq	%rdx, %r14
	movq	%rsi, %r15
	movq	%rdi, %r12
	movl	%r8d, %edi
	movabsq	$4294967296, %rdx               # imm = 0x100000000
	orq	%rdx, %rdi
	orq	$128, %rdx
	movl	$1, %esi
	movl	$1, %ecx
	xorl	%r8d, %r8d
	xorl	%r9d, %r9d
	callq	__hipPushCallConfiguration@PLT
	testl	%eax, %eax
	jne	.LBB7_2
# %bb.1:
	movq	%r12, 72(%rsp)
	movq	%r15, 64(%rsp)
	movq	%r14, 56(%rsp)
	movq	%rbx, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 80(%rsp)
	leaq	64(%rsp), %rax
	movq	%rax, 88(%rsp)
	leaq	56(%rsp), %rax
	movq	%rax, 96(%rsp)
	leaq	48(%rsp), %rax
	movq	%rax, 104(%rsp)
	leaq	32(%rsp), %rdi
	leaq	16(%rsp), %rsi
	leaq	8(%rsp), %rdx
	movq	%rsp, %rcx
	callq	__hipPopCallConfiguration@PLT
	movq	32(%rsp), %rsi
	movl	40(%rsp), %edx
	movq	16(%rsp), %rcx
	movl	24(%rsp), %r8d
	movq	_Z4quipILi2EEvPKfPfPKhPKj@GOTPCREL(%rip), %rdi
	leaq	80(%rsp), %r9
	pushq	(%rsp)
	.cfi_adjust_cfa_offset 8
	pushq	16(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	hipLaunchKernel@PLT
	addq	$16, %rsp
	.cfi_adjust_cfa_offset -16
.LBB7_2:
	addq	$120, %rsp
	.cfi_def_cfa_offset 40
	popq	%rbx
	.cfi_def_cfa_offset 32
	popq	%r12
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end7:
	.size	launch_prepared, .Lfunc_end7-launch_prepared
	.cfi_endproc
                                        # -- End function
	.section	.text._Z19__device_stub__quipILi2EEvPKfPfPKhPKj,"axG",@progbits,_Z19__device_stub__quipILi2EEvPKfPfPKhPKj,comdat
	.weak	_Z19__device_stub__quipILi2EEvPKfPfPKhPKj # -- Begin function _Z19__device_stub__quipILi2EEvPKfPfPKhPKj
	.p2align	4
	.type	_Z19__device_stub__quipILi2EEvPKfPfPKhPKj,@function
_Z19__device_stub__quipILi2EEvPKfPfPKhPKj: # @_Z19__device_stub__quipILi2EEvPKfPfPKhPKj
	.cfi_startproc
# %bb.0:
	subq	$120, %rsp
	.cfi_def_cfa_offset 128
	movq	%rdi, 72(%rsp)
	movq	%rsi, 64(%rsp)
	movq	%rdx, 56(%rsp)
	movq	%rcx, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 80(%rsp)
	leaq	64(%rsp), %rax
	movq	%rax, 88(%rsp)
	leaq	56(%rsp), %rax
	movq	%rax, 96(%rsp)
	leaq	48(%rsp), %rax
	movq	%rax, 104(%rsp)
	leaq	32(%rsp), %rdi
	leaq	16(%rsp), %rsi
	leaq	8(%rsp), %rdx
	movq	%rsp, %rcx
	callq	__hipPopCallConfiguration@PLT
	movq	32(%rsp), %rsi
	movl	40(%rsp), %edx
	movq	16(%rsp), %rcx
	movl	24(%rsp), %r8d
	movq	_Z4quipILi2EEvPKfPfPKhPKj@GOTPCREL(%rip), %rdi
	leaq	80(%rsp), %r9
	pushq	(%rsp)
	.cfi_adjust_cfa_offset 8
	pushq	16(%rsp)
	.cfi_adjust_cfa_offset 8
	callq	hipLaunchKernel@PLT
	addq	$136, %rsp
	.cfi_adjust_cfa_offset -136
	retq
.Lfunc_end8:
	.size	_Z19__device_stub__quipILi2EEvPKfPfPKhPKj, .Lfunc_end8-_Z19__device_stub__quipILi2EEvPKfPfPKhPKj
	.cfi_endproc
                                        # -- End function
	.text
	.p2align	4                               # -- Begin function __hip_module_ctor
	.type	__hip_module_ctor,@function
__hip_module_ctor:                      # @__hip_module_ctor
	.cfi_startproc
# %bb.0:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	subq	$32, %rsp
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -16
	movq	__hip_gpubin_handle_c2f152ab948e02ee(%rip), %rbx
	testq	%rbx, %rbx
	jne	.LBB9_2
# %bb.1:
	leaq	__hip_fatbin_wrapper(%rip), %rdi
	callq	__hipRegisterFatBinary@PLT
	movq	%rax, %rbx
	movq	%rax, __hip_gpubin_handle_c2f152ab948e02ee(%rip)
.LBB9_2:
	xorps	%xmm0, %xmm0
	movups	%xmm0, 16(%rsp)
	movups	%xmm0, (%rsp)
	movq	_Z4quipILi0EEvPKfPfPKhPKj@GOTPCREL(%rip), %rsi
	leaq	.L__unnamed_1(%rip), %rcx
	movq	%rbx, %rdi
	movq	%rcx, %rdx
	movl	$-1, %r8d
	xorl	%r9d, %r9d
	callq	__hipRegisterFunction@PLT
	xorps	%xmm0, %xmm0
	movups	%xmm0, 16(%rsp)
	movups	%xmm0, (%rsp)
	movq	_Z4quipILi1EEvPKfPfPKhPKj@GOTPCREL(%rip), %rsi
	leaq	.L__unnamed_2(%rip), %rcx
	movq	%rbx, %rdi
	movq	%rcx, %rdx
	movl	$-1, %r8d
	xorl	%r9d, %r9d
	callq	__hipRegisterFunction@PLT
	xorps	%xmm0, %xmm0
	movups	%xmm0, 16(%rsp)
	movups	%xmm0, (%rsp)
	movq	_Z4quipILi2EEvPKfPfPKhPKj@GOTPCREL(%rip), %rsi
	leaq	.L__unnamed_3(%rip), %rcx
	movq	%rbx, %rdi
	movq	%rcx, %rdx
	movl	$-1, %r8d
	xorl	%r9d, %r9d
	callq	__hipRegisterFunction@PLT
	leaq	__hip_module_dtor(%rip), %rdi
	addq	$32, %rsp
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	jmp	atexit@PLT                      # TAILCALL
.Lfunc_end9:
	.size	__hip_module_ctor, .Lfunc_end9-__hip_module_ctor
	.cfi_endproc
                                        # -- End function
	.p2align	4                               # -- Begin function __hip_module_dtor
	.type	__hip_module_dtor,@function
__hip_module_dtor:                      # @__hip_module_dtor
	.cfi_startproc
# %bb.0:
	movq	__hip_gpubin_handle_c2f152ab948e02ee(%rip), %rdi
	testq	%rdi, %rdi
	je	.LBB10_2
# %bb.1:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	__hipUnregisterFatBinary@PLT
	movq	$0, __hip_gpubin_handle_c2f152ab948e02ee(%rip)
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
.LBB10_2:
	retq
.Lfunc_end10:
	.size	__hip_module_dtor, .Lfunc_end10-__hip_module_dtor
	.cfi_endproc
                                        # -- End function
	.type	_Z4quipILi0EEvPKfPfPKhPKj,@object # @_Z4quipILi0EEvPKfPfPKhPKj
	.section	.data.rel.ro._Z4quipILi0EEvPKfPfPKhPKj,"awG",@progbits,_Z4quipILi0EEvPKfPfPKhPKj,comdat
	.weak	_Z4quipILi0EEvPKfPfPKhPKj
	.p2align	3, 0x0
_Z4quipILi0EEvPKfPfPKhPKj:
	.quad	_Z19__device_stub__quipILi0EEvPKfPfPKhPKj
	.size	_Z4quipILi0EEvPKfPfPKhPKj, 8

	.type	_Z4quipILi1EEvPKfPfPKhPKj,@object # @_Z4quipILi1EEvPKfPfPKhPKj
	.section	.data.rel.ro._Z4quipILi1EEvPKfPfPKhPKj,"awG",@progbits,_Z4quipILi1EEvPKfPfPKhPKj,comdat
	.weak	_Z4quipILi1EEvPKfPfPKhPKj
	.p2align	3, 0x0
_Z4quipILi1EEvPKfPfPKhPKj:
	.quad	_Z19__device_stub__quipILi1EEvPKfPfPKhPKj
	.size	_Z4quipILi1EEvPKfPfPKhPKj, 8

	.type	_Z4quipILi2EEvPKfPfPKhPKj,@object # @_Z4quipILi2EEvPKfPfPKhPKj
	.section	.data.rel.ro._Z4quipILi2EEvPKfPfPKhPKj,"awG",@progbits,_Z4quipILi2EEvPKfPfPKhPKj,comdat
	.weak	_Z4quipILi2EEvPKfPfPKhPKj
	.p2align	3, 0x0
_Z4quipILi2EEvPKfPfPKhPKj:
	.quad	_Z19__device_stub__quipILi2EEvPKfPfPKhPKj
	.size	_Z4quipILi2EEvPKfPfPKhPKj, 8

	.type	.L__unnamed_1,@object           # @0
	.section	.rodata.str1.1,"aMS",@progbits,1
.L__unnamed_1:
	.asciz	"_Z4quipILi0EEvPKfPfPKhPKj"
	.size	.L__unnamed_1, 26

	.type	.L__unnamed_2,@object           # @1
.L__unnamed_2:
	.asciz	"_Z4quipILi1EEvPKfPfPKhPKj"
	.size	.L__unnamed_2, 26

	.type	.L__unnamed_3,@object           # @2
.L__unnamed_3:
	.asciz	"_Z4quipILi2EEvPKfPfPKhPKj"
	.size	.L__unnamed_3, 26

	.type	.L__unnamed_4,@object           # @3
	.section	.hip_fatbin,"a",@progbits
	.p2align	12, 0x0
.L__unnamed_4:
	.ascii	"CCOB\003\000\001\000\321\037\000\000\000\000\000\000\300\204\000\000\000\000\000\0008\310\033Tpg\323\371(\265/\375`\300\203=\375\000\212\226=U_@P\331Uc\206.\013M\351\241\236\261<\340*s\000\030\220\347\242\210x\236\221\t\254\322,\006`)\312u\234A\016\256u\3335M\255\r\273\205\265|\373P\341\215\023T|2p\342n\325\207J\312\303\316\2152\303\327Ev\2646\264\246\03511l\347\211\305\262\254\337\373\\\377\373\373\373K\231\002V\005'\005\375\004\2724\247\310\0313\212\230\335\376\007\215\371\022b\342\t\236\316\024>\313\320\350\214+\223N\347^\316h\276h+SN\357\366*L\314\3172G\276g\206\211&pLF\2213\362x<!\215\351\022\256L9=\333-\376\261\207S\254\237\025\204\036\317\365bb\2461K\341s\211#\337\223\376\251\t\213l%\026\002U\201\245\220\320^I\024\377\257\032I\242\370\263\213\316h\346F\270\255L:-KW\b\241h\344\214+SNc\"\312n1\220\037\3263\263\021Mh9\342\327\314\024&j\377+\027\313\241\273\305>N\356JO\325x\304\317\252\212\361\252 \364V\224\257I\023\263\362\254\262[\f\202g\227\233\350\263\213\266\341/I\236i\306#\376\313F|a;\342\243\230\275\022\"L\024/!h4\233\312\323\311B{\246\341\214G\374\021\0331\000,G\374\231\215\330B=\342\237\330\210%N\216\370\251\215\370\222\036\361Q\033\361D\312\021\037\366\214\323>0\340\177v\271\3124C\3142\356E\376\257\335\342\037\317)\370\250\256&6\242\t\224#>\311e\377\377\303\006\376}\202\337\004\353\277\207S\254\325]\321\317e\313\355\177%\223\277\355\037I&\377\332_c\371YV\376\025U\004\t\254\fB\351\250\030i\252qeRu\236\315\214\230\310\202\217\352\n\333\355q\f\335\355}\360TU\210\211)\273\305>\236Q~V\021\025\232\276P8\\\222d\025*F\0323\r\342\023+\223\212\316)fF\032S\026\\\231fz\267\371\004\214\244\005\037\325\365\365l;\362=#+/S\bE\203f\3245\251\354]\231h:\273\2404&\032<\016\317!^)(<\025S\210\216\354\3667\374\252\327\310\312\227\306\254\0053Nf\\\231d\372\344?I&\377\020?I2\371\247\177\232L\376*\277I2\371\247\374\262d\362\247\375\261d\362G\371\321d\362\237\375\260d\362w\231\2642\314\2375\311Y\276P\016\240\031W&\232NOS\bE\003e\267\307$\273\315\261W\355u\355\026\337\300\243\321\2044&,H\203\275\273\3057L4\301\272\006V\276\331%5\256L\251\336-\316\341\3148\324\2702\241'\256W\220\227\232BL\f\201\217\352\332z\275\317)\030E\276\301\214+\023Lg55\276v\233q+S\252\317\347\224#\337\303\332\355e\2401]A\036\315\024\346\025\324\370\343\327\274\312\367g\025\351\231\256weB\365nq\n0\261\004\037\325u\344\231\344\310\367\270v\373\037\230\230\365Q][\317\261#\337s\356\3662<\233B\244\212\233<\364%\334-v\377\374\232Z\371\322\230e\360\277.\313\362\205R\257\177U\221\336\253|\367\360_\341y\206\000X\234\036\370\352\307\372\377?\202\226\375~3\274\037\r\n\021h\370f\000 Sc&\007G\207\207(\007'\210\307\006\316\214\214\316\215\235\352\254\263\204\222\212\0230|z\326\034h\260\202\322\r\002NX\001\323\220\203\031\330h\341\222\242\001\005\b\326\376c\365\177\322\355\370<3\206\241\313\377W\301\330\365\330\177\035H>\034\t\302\003\324\244\202l\205\033\232\227\276\251\212\375\017A\344?K%\373\217\177\3144\364\333\021\362\rq`fFF\006\377t\200|p\204\200\200\300_\016\220P\320\216\004@B5~9|\020\330y\000\210.\307N\003(\270\221\343\033\002\342\344\360\370\370~X\320\301\001\376\200D;\020`\034\037!\240\032<?D\273\021\350\334\330\231\000\007\020\r\037\026\200;\f\034\007\016\236  \220\226\241\037\"\240\034\034\241\240\035\340N\003\377\r\371r\360\b\005\355J\3203\200\0316\0060\243\306\214\032\003\230\221\243\204\022x<2\004\020\304C\364\000\024\013\300!\301\317\307\367\263[z\311\202_\013<7\204\200 \2003\344\303Q\003G\207\317g7\202g\031~\200x\200B\277\0348@^\2502^\374\374\202R\310\300o\307G\264\363\343\303\261\333A\375\265\300\003\f\301\371\263\303\203\303\267#\344\023\301e,\370\265\300\003\304\321\371\351\340\251\2013\364\363\363\331\371\001q\202\210\200\204vv$\240\241\247\320\257F\r\"\0328\034\320\371\341\271\201\363#\302\341\313\261\323\300\371k\201\007\270[\372\320\017X\243\006\320\016\0038|4\200p\354\350\360\313\361\005\001q\200\300\237\220\216\216o\327\201\"\027\270#\344\333-\311>\203\037@\034\277\037\241\337\215]\007z\374\007\230a\002\f\024Z\234,\377Y'\n\232\362\246\316\220\r\b\2403d\003\025\362\004f\374f\214\250/\372A\347\207\377\346M\020\330\377\257\376c\022\026\307?\361\017\312\377\346K\036;\213\267Ns\026\377k\036\244\317\342\370?\\\365\222\005\3069\206\214\022x\310\000@FFG\215\235\230\030\037\320\206\216\217/F\307\307\027\363\223\263\243\343\343\213A\221#\210G\035j\212!\372\331\211\321A\364\303\203#\346\007\002@?7~\210bP\364pz4:b\206\200@6^;\372\214\203S\202\f\0306\007p\201\003\243E\n2b\304H\001\307\004\233\0262^\340\340\004\253\013\3236\"\013\354\210_\356!\212\324\352\276\264\215\030\202\344\210\257\332\303\020R\253\353\312{(B\212g\000\033\341\352\236\332F\\\345#>\336\303\026\251^\232\362\262\207$\244z2\224\227=,!\325CO^\366\320\204T\017f\362\262\207'\244z\257\330\313\036\206 \325s\225\274\354a\000\244z'\311\313\036\222 \265\272Y\367\362\313\313n\357c\017_H\035\253\360\221\366\227\367}_!~\361\373\276@\205\376\373\2426\341\302\225n\375M2\350\362={\331\246\315\255/\203\264p}\330c\257\243\256\227\234\207\231')\257Z\377 *\344\347\3659\210\n\254\327z\331\310z\324\265\036\326Z\377:\327\273\202\270\370Y\353\317 .~s\275\031\304\305\277]\270\211\2110&./\362=2\\\354\366\"\337\203\342\267\324\023\371\233\354\366?d\317\267\023\371\307v{wF\305\365\300DU\037\325\265\244\366\"\337\003\233\271\255\240\351\3722\210\213\377\271v\"\377\222\335\336\207\225\025\022\225W\215\006S9\221Y\327\320l^L\244\351l\233\275\310\367\270fT\322\036\273\305?\216\337\232\235\310\247iK\366\376\230\231\241=\\\262\023\371\2436/&\242\372\250\256\254\327\213|\217\211\211y\365\322\245\361[o\372\363\371\"\337Sb\242\271:\252\253\352\371u\"\177\363\271,\221\357\311\255\243\272\256\236]'\362/\367p\2125\363:{\2609\377\371B\244\212\347\335>\00632X\017\366&\353b\217k\024\3715\340l^\230\315;\343\262\351\361_\327\2346/\315mTE\245\353\027^\203\252\b\003\276A\221\n\206\314\332\250\376\203\377@\234\370?\370Q \312\374\355\302\361\256\341/\352\023j,sU\2522\376\b\377M\023\366:\365\360z\367p\2125\302\377\262t\275N=\234\357\036N\221\030\341\177\316\346\353\324C\371\356\341\224\t#\374u\352\341\357\036N\355\260\314\030\n\303\177\f\243,\230I\262z\345\021\363\270\334\355\261\215\210\177\304(\253\233\242\261\023\231\266\021cfG\374\323\314\"\360\352\242\272E\211Y\256Jv\213elD\000\250\034\361\363:C\371\376\1772Y\242\244\234\374-\267\337\226L\032W\246\353|\352\214f\013\037\325\025\263\216|\317]\325n\237\003O\307\023\346\023t,W\372>\341JD\374ye\322i\223\2263>\311HX\324\314\332\303)\226L\366\246\262\226\231)\204\242\2413>\303F\250\035\361\315=\234\"a\272FB\354\366%\214\234\361\371\245f\021V\216\370\253\325\353\"\327CQUD\215e%\204JI\276Y{_`C~\315\204\275P:0\254\202|\026\363\265z\237\177\002g\227\366\241\346\315W)]/\224\216+\327R\b\315\\\211\024\313\376\325\253\242\271\336'\034\353\266\272,\264\271;A\333-\236Y\335\025:\345\307o/E\371\262H_S\305\013uuS\230:\023\263\037\177\245&Ss\n\364\315\270\034\243\205\232\333\334\002{\237O\210qB/F\371\216\300\245#h\251\371\342\233\257\371\342\233/>\215Y\2764\224\031\013-U!|\272\211\220\322\262[,Ss\t\267#\376\212\251\213Q\237_\224Z\371>\341dP\236i\264\0175\377\352\252\320j\236\321\240,\265\364}\302\221P\333\355U\317:\355C\215\333\002\366\256\256N\237\374'-\277\313\b\\\013\212\356\351\312WF:\202\226\276P:\262\227\007\372\362\250\275<`/\217\327\313\343/\217\036\317\365\376\3274f\371\362hj\332M\273i7\355\246\335\264\233v\323VR\022\242$DI\210\222\020%!JB\224\204(\tIJ\032\2224$iH\322\220\244!IC\222\206$\r12\2222\2222\2222\2222\2222\2222\312\270\030K\312\3104Y\267\335\276D\221Ia\231\231\230=\235/\324\335b\367WI\025\311HG\320R\231\fF\316Hc\242E<\236\211\276\3074f\255\210\227S\325\336\227\343\220U\350\214\260\242\335\346\226\225I\247\177V\020,4\330\013\245\2233\322\230\257\242\225)7;\301\323\231\302\335>\207 V\246\234\2461]E<\036O\270\333\334\"\210\036\317\365\322\230e\221\ne\306\262\022B\205\007\243B\250JK\244O'\3536\233\311\244<\235&f6\"Ku\304W\331\2102\264#>\r\345d\017\247L\370UA\364T\224\257ICB\315\005wK&\1773\305\013UE%\000+Og\b*\273\305?lD\022D\034\361E\330\366p\312\004\226=\234jm\304\020B\034\361C\354\341\024\006VW\247\372U#Z\222\311\277\247+\205\031&g\376He\2445\262\023b\310R\031T\310\343\231\302\347\2304\303@_\034\236_\322\232\220\2273\205\266?\205&\"\204J2\371\347\031\036\317\2702\361t^a\002\317Rv{\033h<\036O\270\333\273\265\027\023K\300\336\347\227\335f\\V\2413\322\2300\341\312\024\302\"\322\331\342\321u1x\275\227.b\207\320\324\273}\016\036\261gYS\225w\373|\304b\366\277f\237\337\232\2624\312\310-\374\334\302>\264\340l1x\226}\326{\351#;h0\263\3761\206R\257\317\334\026\203<|4\001$\366\305\262g\306\241xt{\355\366-\244\327\353HX\006\321\035\302R\2379\230\237\212A\036\306;\bW\267\f\"a\314\356\240\241\024\026\203g\367\322[E\315\373\021\213Y6\377\344\260\303\250,*\006\317\276\357\213\003\233\363\273\227n\"\375\354\016a),\352\263\273=\005\216\330\263\271\314=\376\0219g\341n\361\355o}\325Q{\361\016Y\037\361\361\377w\025\252\275?\003\3302\027\355\245\003\001i\344\354\217\303w\350\250\275E}v\3465\243\275\204K\220\\g\377\246\357\230\241\366\356!K\352\\\377 -\374E}\266d}+H\215\312\352\255\027\362=\373\206\374\000\363FD\211\233\032\306%7O\362\335\336\207\371\221\233o==^\265\220\357i\025\365\373$\273au\2636\277\372nq\354W\203O8\325\201\024\tWz\245\313`i\376\372\210=f\267\322E`b~.\213EX\257\320?\273\222_^ic4\242w{\274\333\333\260\202\0236\017\377\026\301U[\377_\363\203\364\374\230\230Y&\362=\337\355e\260\021Wy\212\205\"\277\206\335\336Gi\001X\216\212\361\347\021BP\362\000\375\337$j\036\343\3255\365n\261\254g\026 \327\024\373V\322B\222X\f1R\245\212P4\b\214\376\275\322F\370\227\302\247\033.m\336\325-u\257\264\t\342?'\223h2\371\303$Q\240\377\321\222&\033\340E\2171{\224\357\241J\n\347R\370tS\225\330\355\201\340(\022\307?z\322\230\006xK\233\267\204\255pT\b\307\273\305@\360\215\271Z\355\366>p2\026\2162\371\352\347\037D\370\244U\te\376\275)W\252\335\336G\013\324\nG\231\\\305\226\007\300\273\3152\274\256\250\251\236\222E\226\300\n\345K\2217jj\305[\351\205\231\251\315\265\333c\324Tm:nM-\210$L\206S(\351\237\232\374&3\214@O\262B\243b<=\311J\026\025\343&m&a\241K/\211\377<v\264p{\2131\234\335K\257\256\b\003\317u\223\252DL\265%f\252\266\230\t\272\272\252\216\311p\301'\234\254\247\252M6\242\n\037\361M\216q\212\254]f\336F\304v\213\177\254\256\213\376\317\243\227S_\331\036N\261\314\333Kluq\332F,a\035\361\323\236\213\252d\336H\304v\213_\254nN\367pj\222\211y\033\021[]\027\335\313\251F\262\325\305\351\335bcL\246\n\237p7\275\2727\275\333\177\240\347\242\026\365njp/\275\207\344r\261;l\334\364\321\362\277\f\246~\366YUR\376AT\370o\357\036\252\244~\325T\357\345;S\256\274\260\207,\251\330\372\007a\377\"\fg1\221\206_\360\343\021\344{\016[\177\006\251\371\367\r\017\272\271a}\267\307\3461\212\211\262\233\233\025\336mn9^\235\310\367\234y\004\275\271Q\225\356K\243?\221\335b\327<[\350k\345\265\021I\314#\376\212\375\b\353\346\006\257\334\232\336-\306\301Fl\225G\374\322t\215\240\275\332\212\321\352\326\264\2158\262j1\220\225\371\"\342\324\203\213H\r\f\346\264[\234\262\257\021\223u\215\254J\330J\223S\rN\"\273\315\270\031X\255\0025/\234\323\352\3364{\216\230\273\305\356\315MIY\242+EO\270\026t\267\377\221c)5/\234S\354\346\206\244\334m\226\255\256\2136\317\026\272[,Ke+JN5\200!b+k\\7\247\325u\3211\231\233\233\021Y\216\305J\242\320\307z.+B\026f\344d\267y\246\204l\004\352t\266b{8\205R\003\003\343d#\216\220\035\361e\346\255\005\335-v\261\272.\261\325\325\351\242\376\263\252\362\256\256\252w\213o\350\351t\301\236\252\006S\350X\320\335b\3331F\221\265\243)z#\342\324C\216\310n\261\354\377\333SW^\3666\022Cq8\"\273\315i\317e%\211\315\215\2445\267\233\023\213\033\221\001\321\327A\225\222\252&\227s\022b\215kp8'\375\340s\354\245$\n\375I\216\265J\242\320\247\275[M\0029f+\211B/\333C\225\324\021\353bw\373\326\021;\302n\245\013\213\032\353\326\353o.\317\335b\027?\377D\376\337\355\177\260i\326\274\322\306h\205\376In\323B\335\376\026/ \200\237\305\226*\022\377G\240\320\353\237\005\223T\001{\335\\\301$U\270\316\227*\230\244\n\263|\3060I\025\371{\310\222Z\335T\333\210-\261\021)\033Z\"\265\272\250\266\021E\224\230H\005\253\031\330\340\003S\240\347lq\377\321\032\347\201w\340\345\360\2510\001\024\356\342\301\205\031+~\256T\000\200\231 \201/\242\314?!\005\350}}\360\277\004\277\211\225\361_\b\000\205\0266\n\200\201#\024\264\003\364\021\005\355\350\370\370ffffffffddddddddp\340\360\345\340\f\345\374\204xt~x\210r~B:>\0336r\206|B9\300\234\234\034?\036!!\037\r\034\235\237\217\357\007\210\243\363\023\372\321\360\t\005\355\344\300\361!\372\341\361\324\230\201b\206'\343#\004T\003\370\343\023\032:!\263\000\234\013\r\001m\000w\247\341\033\362a\001\270\373\320\317\317\307\007(gw\240\017\221\017\217\016\237\017\216P\320\0160g\267;\020Hc\367\235\037\036\035\035_\020\016\220\020\216\237\320\3569<>\276!\035\277\241\335}C>\035 \241\335\205\206\200?,\350\334\006\320gcG\364\263\263\273\017\013\300\037\026tv\377\r\001\375\354\276\"\301\252\002+\341\352\267\032\300j\267J\317\374\177u|u\200\003\022\311\r\024\375\246\204\301%\353Ax\260\031\375t*\027\252Y\016\336\344\342\007<\307\260\355\300\005\272\rh\234\000\fS\004\313\200\207\027\375\266W\007+\374\257\016D\320\275:8\214\016\226\211\337Oh\310\204\272\363\343\303\221\243\302@\241E\fp\347F\220\016\236\237\277\234\330\315\354B\210\361\311\001\022R\207r~=@BA1>9p\3400\341\363\"\005\025L\370\000\345\354h\020\331\030\342\3311a\"\0050hh\310FN\345\355x\273\231\031\025\206\f\031j\n\241\337\215\037\036\031\177\320\b\357\377\201\336\"=8\n>\002\232+\310t\241\210W\226\245\253\250\\\221\344\227\227\017\310\330\355\361n\363\361[\273\305>v\233m.\f\306\202\301\240\330\343\032E~\r3\262W\217\027^\303inS\302\264Q\272.\036\341\033\024\375\205cb\336\221\230\")l\035\212\244p\204_\370\314\301\325-\203{\251\310MQ\363\036\003f\361n\337z\001\211}\025\217n\257\0300\333\263\272e\017\241R\021\024\266\016EP8\372\353/\266\307\307\331\263f\016\2564\234z/\0251@\fg\217t#\273\303\350,*\036\031\267R\020,`\316b#-\261[\013\032\213\235d\025\273\335bA\020\001\372\376\177\237\321\027I\343\347^\n\302.j\336of(\021\264\345\264\021KXh\313\211\213\365p.\301\335\342\226\233\311\211\336\232\236p$\316\325\305\231\334^\023}9w\213_\340nJ\251\211\2168W\027F\313N\331-\351\tG\342\334-\23619\323\233\321\023\016\3250\272\207\273\025\235\250\356\241\267\240\354?e\360\203\377LoB(\334\007\366\322E\260\201\3237\364eq\"\304v\213mE}6\333\360\031\025{\354\210=\213[\321b\022e\362\222\335\036\263\267\226X6[dQ\t\360\321\303\341\212z\267\333\f\016\347\302\314\355\366\202\233\013\356\366e\256\211\230\225+\\\\\030]\222\346\202N8\022(\273\3052\030\334\233k1'\3078\206\254\231\254n\r\245\\\300U\275\034\316hu]\364\215\256Dz=\223\335^(\035\022\263\325\335\351\023\243\037\265\332\333\203\251\0315\255\356\256\227\2735\231\314jMN\270\022\351n\261\255huw'0&\351\255\310\t\027\323\203\251\025e\027\022'\275\035Niuw\263\325\325i\033\030 \242L~\222\273)\231\314jJN\270\022iv!1\353\355p\302\325\335\235\254.\214\336\355}HK\033\035\020Q&\237\255n\356G\017\246&\274q\21191IoB(\035\022\351n\357\366v\270\244\325\335\351Yi\223\003\"\312\344\351\352\352\364I\316/&Q&7\331-\376\300\352\302\3504\247K\264\227s\005Ih\372\361\016?\274)\\\"\320\335\342\226\242>\333\333\341\202\030\257\220\265\243\377K\031L\375=]-\251\007sK\352\271\334\202\273}\376[\226\265\027\nw\325\255\334C\225l\245\001\343c\325\217\264\347\335bY&\301\231\004\245$\n=\022{\226\305e]\3247\327\021{\326E\311\020\314\303\237\377\257\336\3021\374\275t\222\242\346\215\320\334V\337\355\3631\336\355\363q\216\241\247\007\037\275\3474\371\302\232\343\3473\350\003\n\377\352\276\216ZE\317\255\3634{\340\035\312\3225\203{\351%l\231\365JFf\031=\263\262)\303:\203\253\b\357`\006\217\370\252b\360\354:\203\253\307^zIQ\253\030\t\033\177\254Z!\361\363nK\033\\\252\234\364\334re\315\232Y\037\261EE\255\342#\366\354\326\001\023\213\232\367\255\003\276\200>[\f\226\252\362<\21522K\351\231uj}\344B1\250^\007\274\001$\026\263\254\231a(\006ox\353\200\227\316\340n\217\213\301\263E}}\252T\273=>b1[c\232F\031y\205i\376\246\347Uk\007\r\246.\363\013\305#\025\037\261/\326\007f1[f\t \275H\212H\352\213-\263{\304\222\260G/X\f0\266\247\030<\353\343\305\276V\032\314`\021\211G\022\303\213}\301X\244\227\221\335\341\232=\212\0210\356\245\263\220HH\330\035B3\204\332\250\343c\305Y\024\3040\245\024R\310\f\315\b\3214\007\203\026\200`(,\"\022\347\201\034\314=\023@\203\n)5B\214\343\020\212\243\020\242\bA\210\020B\210\200\020B\f!\210\214\f\331\250\322\001P\303\006\"v\b\373\230\215qu\357/Ai \224k\247\235A\026\375\200]\tK,p\0136\377z\234s\004\276\315X\273>4Npd\201\3568\033\017t\016~\2764\nj\361Nv$\216\320@|b(\347\304\277\031\032\204\301X\357N\306bX=\211;\257S\276U2\200\277\035\277v.<8y\337!1\264x\216\\\276\373\313l\336\003\037\201\206<\261\252Z\240-\222\301\232\206G\256\372_R5\304Y\210\2737\305+D\235\203\314!Z\352o\231:\346\325\264\255\020\315 \376\202^\333\250m%\016\273\313\275\235\222\276\231&\031\1776\277\377\021\352@r\023\004\3620b3kP\277,\241$\t\266\f\321\311\232\304\r\253\241\fa\303g\244.\201m\206\304A-\342\220\305\fd\n\031\023\177i\305\242\227tFR\261x\250\363b>\\\247\263W\273\267\034\367\351`\326p\n\340<\202]\341\206\305\013\210:=?z\034\007\235\206\360\376\306t\307\351\022\326scD\322\354\331\305\002\326\354\257\006\332\221\023\227\241\205H\263\261\331\211fk{;u\333\233\223\264\247\320(\r3\263\\W\032z\362\335\271\t\305\007\"3\227\207fr%D\240\341G\372u6>\f\302\307\310\031\362\245\315\237:)\212\364mr!P7\206\300\000\017L2B\263|\342\0052\030\215^E\262\256!i\201>'v\221\207\265U\352\275\323\242nB1\253\035Lr\311F\247\264\310|/\246\355F\203\031\326\035\314\224a\311\257\320\306\3666\230Y\247\027\037\0351\214U\265x\367U`^\373\356\026w\225l\235\341\335-\207\251\357\276\202\306\273\333\362\274/\277\335&\337}x\361\306\256\346e\345]\264\004\352_`\377\221\177\347(\306\277S0\357{\232\325\017}\345\277\327\342\314\277K\321\276\363\017L\262y\337\357\354\267\357G\241N\035\2328\367\335\230\372\370\203\347G\325\323\236X4\216\377\215\343\336\223\026\211\263\230\3357\341B\241e\t\274\311\321\017\313u\264\356^>lW\b\353\2130\341\350\024\360j\331'\362k[\333\254\364h`\216zu\2545\236\370\310\312\315\031\265Pn\234\272w\2030`\306\230\233\227\270\256\006\343,\000\347j\232\311\314i\360ld\210\013Rv\300}\214\006\216\256CTVP\312K\323\362\027)y\026Z\341N\262\177S\343\372,\241\003.\310-\2412>'E\357h\315\366=\234]:\353\345\253Y\213\331&\356\373\335nB\f\375#\3417b\253\214\f\317\201\253P\273\364\327O \347\261\372\025\376\037\277\320\022\030<d\321x\000\264y(\227c\352\033\220p\300\250v}\333SS\310\307|\277|*~\215\260^~%<s\242~\361\353\351\236w\261=\252\376\3410\355\245\236$\34277\243\377V\372\013\320On\371\354\243;e\005\006\233eKn=\024\366\035\030\203\254\033\354\324{\310\316\r\352\316\3310v^7\315\234\372\260\025\013\026e~!Z\007\262\353b\233\303\354@O\321\023\346\016\335\274\035:\255\250\235G\266\335_p\337-\020\342\202\013G\224\032\341\025\322k\360\f\226\005\020\356\246\251\013\217\2555V\345\224\354\272\237&j\307\371\342][6Xo\274\345\177\022f\356M.n\250M\217\n\322o\332|\203 \177&\004\317\027\203\221\2073/{d\241\347\255\241\333\314|Q\330M\243n\235{\275\326A\356\363R\036\211\347\232\242\251)\256\374Es\313\364\362\355~\266a\346\017\243\377y\332Ms\375x\370V\377\317\002\324\347\367'v\260\331\337\242\354\357\347%\2145@~\001\204b27\275\233\207hd\337L\325\316\307/\037\003|~\311c\254\017\3009o\351_\345\271\220\310\207\016\b\370\321 \221\017\035\224\250\023x\335D6uO\227\207]W\236\245\302\345\nwC\235\225\3761\3028B\234\204hU\227\026\275\236\362\244\237\370\357\243#\013.\336\215\365F\225nM\373\357\211\313\n\177\240=L\3143\024\177\301\001\217\274\\\211\"\017O\273}\024\340U\0236a\002\374\300\277\204\202?p\2652\031\243\363`\211.p\331'b{\270S\307/\305s\315}\236s\361\262\221\353\243\200\34152\360\365\223\330>\r\325~N\356\242\316\024X\037\323\202\207\263X\201\026\003j\002\357UO\227\272\222\353\305\230w\305\002=\t,\265\270\273R]\201\227\213\307\005F[zlo\223\277$\255\313\363V\375~\320\305\262\245\364\206\245\332\370\244\304vJ\276x\344\005\021\217\276\325\303k\177\265\022\326?\370u\361T\254u#\2666\243|\227|\336\306\214\256\376\273t\005\270[\275a\277\026D\341\373\"Q\355E\333U\245^\226\300\201\206\304Pr\347\3134\323z\342\334\207B\225\266\027\351\236q\b<\034)\207X\370\217\236m\204\301}0Hu;xz\236\272\323>\257\271\372\n|\351N\367|\343\001O\202\226L\244\323\227\335s\325\260\026\271\211\337\360w\301\344\305\334DL\231\252\374\304^K@\021\202\321^I\316\222z\240\306[\214\224\332\357\024\255\366Oy\321\334\207\316\261>o\no\030\305\354\256\000\256\025\237\033\312>\034!&\237\030\2727\321\373P\005\357F\270\267\204\221\001\301\347\373\036\030\021\217a\377w\026\265`\300\003u\206\034y\244\316\017\245mM\261\336\213\233\303Q\366A\013\033id\331\213x^E`\027\\>b\321\347);\031\024\326\033;\272\254Q\214z#C\003\227\013\240\374e\020>\007\300\270\025>\t\216w)\347\001t\257O\261s\306\370\331\350\267_\362%\\-\201I\356\371\367\327n\005\027&89\347\030\324\270\2205`\376\223\354/\027\276y\304M&\1775\371\257F\236v\002f\214>\003-\026\370\357\331\233\330\275\341\020#\350\227\034\004\322\367\326x\253Q=\006\311\004\312\317\271\020\367\207\207\327'\352\333~?\274\370\337\322Kd\317\343\276\035V\031\"\315H\325M k\2064\217m\030\336]\2619=?\257X\224\344\340\233e\274\373\3261\\\017\210\333P98\251\324\370!\375\237u\202\375V\000e\344\362-\254\305w\b~\246\257a\335WO\230N\317$\257g^\335\214\361\371\333\321\340\031:B\200\217q\363\365\022~o,yt\276\352gt\377\017\360\303S\336\315\353^\271\220\365\3405\304\273\341s30G_\216&9\035\361\265\211\250\305)\260\245?\316\223\023\354q\320[\234\003\337%x\334\207#\331\303Frpz\376l\006\317\315\315\207\256K\033\030\221\313c\007\344Ft\t,\026\244\004\346|\206\316E\037\362\340/\t\013\260\b\210\004\273\000\242\021\321\003\212\004(\203\031\237\240s\350\213,\370A\306\n-\201\242\204n\000\024\002t\200\302\240\212pFgh.\370!\007\177\222\267\000\013@\004\250\023\020\205\020=\260(D\t\230\3219\236\203>\311\300/R,\300V9\377\n\003s\307kv\3560\372~\212\323K\375\233\361\036\372\377^\266\3238\257\372>\334\362\373\267\365\235\371\200\201\013h\037\300>\301\270\027\204\227\277_\313\353Z\377\374\372\232\344J{\303\025\251\305\"8_7]\007\260\267\214\366\2426\335\200\313\303\034\300\223\331\221\004x\337\3706c}\245\273\305p<\263\346\027\377\266_\376\263\311Ix\316\222s\347e\367\357\366}\314\037\317\004\370i9\377\312\262)\264\321\240\351}\361\373\372\n\232ofU\340\304\371Vy\312L\233\253\346'\306\373\2355\317\247\222\234\013\327\273\327A\3170I\fB\376N\030\363\276\361h\016\246\202\016\362kr\324\353*\265\232\254:\213\213J\266\354`h\203\r\\\327_8\270\335\311\305\006\\f\321\347\212~\352\354>c1\327u\352h\036\276\371E\325\343\333\235\313\024\223\211\322`%\016\344\247\341\317Q\276\216\f\233\241\177\232p\021\032\023\356,\274lzU\360\343\233\341hU\347\235\223\345\236hD`h\332q6\341S\343\254\3107|0U42\370S\036\376d;dd]\2728\276\t\003\332x\206g\244\257\246\255 ^\340\177\007K\327\265n\331\276\222\363\266!\275\274#\374\031Wn\347}#Z\233\301\020\327\2571\274L\233l\263\274!\356\207\346\226\331\037{\230{\235[\215\372\353\222S\003\217J\262k\361i\226\022O\307\207\261\367\256\314\343\311\257654\244\343\314\323\357\254\340,k\322\233l\371\370\364\331\324\3548=\340\0160i\342ip\274\343\223\341u\203\250f\003\260?(\235\336\365\363\3004\340c\035\315\257\f\336\222\343?\307\347\324\347\342I\253^\235\366\2139\b7Vg\210\266\036\2642\3524\332n\fx\314\366,\341\320:j\206\202\353\324\2205\264Z\3051\201\330v\303J[?\342\315\032\317\306\321\250}/\"\354Y\305f\322\365\236\r\343\351n\310\256g\023\2035-\346\222\020\322|\nYn\tZ\213!\216d\312\33676\245\353\033}i@\337G\3149C>n\0024\233\377qxryK4\312\352\211\351\341\345[\n\356\257\006\030\367n\221\t\215\bh\326\007Q\3022\213@\350\345Z\036\260[\244Q\t\253\3422\313\344\337\266\037\021\377\342$\325\276n\351)\226\004\270\312a\022]:\260qw\310Z\201G\026\265\033}\3444\024\327= \177\250\270\323\372\225\027\025nh\357w\317|8\023\333q\303N\333Y\023\025\351v\265\354\003_1\347H\354&\366\217b*N@\027%\204TY\005\277\206\316\251\332\225U\005z>M\021\006\027L\275}\375A\203\323\256\361,\004;0\327\nf\177\r\241\344\n"
	.size	.L__unnamed_4, 8145

	.type	__hip_fatbin_wrapper,@object    # @__hip_fatbin_wrapper
	.section	.hipFatBinSegment,"aw",@progbits
	.p2align	3, 0x0
__hip_fatbin_wrapper:
	.long	1212764230                      # 0x48495046
	.long	1                               # 0x1
	.quad	.L__unnamed_4
	.quad	0
	.size	__hip_fatbin_wrapper, 24

	.type	__hip_gpubin_handle_c2f152ab948e02ee,@object # @__hip_gpubin_handle_c2f152ab948e02ee
	.local	__hip_gpubin_handle_c2f152ab948e02ee
	.comm	__hip_gpubin_handle_c2f152ab948e02ee,8,8
	.section	.init_array,"aw",@init_array
	.p2align	3, 0x0
	.quad	__hip_module_ctor
	.type	__hip_cuid_c2f152ab948e02ee,@object # @__hip_cuid_c2f152ab948e02ee
	.bss
	.globl	__hip_cuid_c2f152ab948e02ee
__hip_cuid_c2f152ab948e02ee:
	.byte	0                               # 0x0
	.size	__hip_cuid_c2f152ab948e02ee, 1

	.ident	"nixpkgs-AMD clang version 22.0.0 (https://github.com/ROCm/llvm-project/tree/rocm-7.2.3 rocm-7.2.3)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym _Z19__device_stub__quipILi0EEvPKfPfPKhPKj
	.addrsig_sym _Z19__device_stub__quipILi1EEvPKfPfPKhPKj
	.addrsig_sym _Z19__device_stub__quipILi2EEvPKfPfPKhPKj
	.addrsig_sym __hip_module_ctor
	.addrsig_sym __hip_module_dtor
	.addrsig_sym _Z4quipILi0EEvPKfPfPKhPKj
	.addrsig_sym _Z4quipILi1EEvPKfPfPKhPKj
	.addrsig_sym _Z4quipILi2EEvPKfPfPKhPKj
	.addrsig_sym .L__unnamed_4
	.addrsig_sym __hip_fatbin_wrapper
	.addrsig_sym __hip_cuid_c2f152ab948e02ee
