	.file	"rgba2luma_min_planar.c"
	.option nopic
	.attribute arch, "rv32i2p1_m2p0_zmmul1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
# GNU C23 (g1b306039a) version 15.1.0 (riscv64-unknown-elf)
#	compiled by GNU C version Apple LLVM 17.0.0 (clang-1700.0.13.5), GMP version 6.3.0, MPFR version 4.2.2, MPC version 1.3.1, isl version isl-0.27-GMP

# GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072
# options passed: -mabi=ilp32 -misa-spec=20191213 -march=rv32im_zmmul -O2 -ffreestanding
	.text
	.section	.rodata.str1.4,"aMS",@progbits,1
	.align	2
.LC0:
	.string	"[rgb2luma_scalar_planar_packed] sum="
	.align	2
.LC1:
	.string	"0123456789abcdef"
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-128	#,,
	sw	s0,120(sp)	#,
	sw	s1,116(sp)	#,
	sw	s2,112(sp)	#,
	sw	s3,108(sp)	#,
	sw	ra,124(sp)	#,
# rgba2luma_min_planar.c:46:   *PERF_START_MMIO = 1u;
	li	a5,-65536		# tmp270,
	li	a4,1		# tmp186,
	lui	s1,%hi(in_r_packed)	# tmp250,
	lui	s0,%hi(in_g_packed)	# tmp260,
	lui	t2,%hi(in_b_packed)	# tmp248,
	lui	t4,%hi(out_luma32)	# tmp254,
# rgba2luma_min_planar.c:55:   for (uint32_t base = 0u; base < NWORDS; base += VLMAX_WORDS) {
	li	s3,249856		# tmp267,
# rgba2luma_min_planar.c:46:   *PERF_START_MMIO = 1u;
	sw	a4,4(a5)	# tmp186, MEM[(volatile uint32_t *)4294901764B]
	addi	s1,s1,%lo(in_r_packed)	# tmp259, tmp250,
	addi	s0,s0,%lo(in_g_packed)	# tmp252, tmp260,
	addi	t2,t2,%lo(in_b_packed)	# tmp257, tmp248,
	addi	t4,t4,%lo(out_luma32)	# tmp249, tmp254,
# rgba2luma_min_planar.c:55:   for (uint32_t base = 0u; base < NWORDS; base += VLMAX_WORDS) {
	addi	s3,s3,152	#, tmp267, tmp267
# rgba2luma_min_planar.c:46:   *PERF_START_MMIO = 1u;
	li	t0,8		# ivtmp.61,
# rgba2luma_min_planar.c:54:   uint32_t out_idx = 0u;
	li	t3,0		# _13,
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	li	t6,77		# tmp203,
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	li	t5,150		# tmp208,
# rgba2luma_min_planar.c:68:     for (uint32_t byte = 0u; byte < 4u; ++byte) {
	li	s2,32		# tmp223,
.L5:
	addi	a4,t0,-8	#, base, ivtmp.61
	mv	a1,sp	# ivtmp.54,
	addi	a2,sp,32	#, ivtmp.55,
	addi	a3,sp,64	#, ivtmp.56,
.L2:
# rgba2luma_min_planar.c:63:       rp[lane] = in_r_packed[base + lane];
	slli	a5,a4,2	#, tmp189, base
	add	a6,s1,a5	# tmp189, tmp190, tmp259
# rgba2luma_min_planar.c:64:       gp[lane] = in_g_packed[base + lane];
	add	a0,s0,a5	# tmp189, tmp194, tmp252
# rgba2luma_min_planar.c:65:       bp[lane] = in_b_packed[base + lane];
	add	a5,t2,a5	# tmp189, tmp198, tmp257
# rgba2luma_min_planar.c:63:       rp[lane] = in_r_packed[base + lane];
	lw	a6,0(a6)		# _3, in_r_packed[ivtmp.53_31]
# rgba2luma_min_planar.c:64:       gp[lane] = in_g_packed[base + lane];
	lw	a0,0(a0)		# _4, in_g_packed[ivtmp.53_31]
# rgba2luma_min_planar.c:65:       bp[lane] = in_b_packed[base + lane];
	lw	a5,0(a5)		# _5, in_b_packed[ivtmp.53_31]
# rgba2luma_min_planar.c:63:       rp[lane] = in_r_packed[base + lane];
	sw	a6,0(a1)	# _3, MEM[(long unsigned int *)_126]
# rgba2luma_min_planar.c:64:       gp[lane] = in_g_packed[base + lane];
	sw	a0,0(a2)	# _4, MEM[(long unsigned int *)_127]
# rgba2luma_min_planar.c:65:       bp[lane] = in_b_packed[base + lane];
	sw	a5,0(a3)	# _5, MEM[(long unsigned int *)_128]
# rgba2luma_min_planar.c:62:     for (uint32_t lane = 0u; lane < vl; ++lane) {
	addi	a4,a4,1	#, base, base
	addi	a1,a1,4	#, ivtmp.54, ivtmp.54
	addi	a2,a2,4	#, ivtmp.55, ivtmp.55
	addi	a3,a3,4	#, ivtmp.56, ivtmp.56
	bne	a4,t0,.L2	#, base, ivtmp.61,
	li	a0,0		# ivtmp.47,
.L4:
	mv	a1,t3	# out_idx, _13
	mv	t1,sp	# ivtmp.38,
	addi	t3,t3,8	#, _13, _13
	addi	a7,sp,32	#, ivtmp.39,
	addi	a6,sp,64	#, ivtmp.40,
.L3:
# rgba2luma_min_planar.c:71:         out_luma32[out_idx++] = rgb2luma_scalar_u32(rp[lane] >> sh,
	lw	a5,0(t1)		# MEM[(long unsigned int *)_16], MEM[(long unsigned int *)_16]
	lw	a3,0(a7)		# MEM[(long unsigned int *)_15], MEM[(long unsigned int *)_15]
	lw	a2,0(a6)		# MEM[(long unsigned int *)_14], MEM[(long unsigned int *)_14]
	srl	a5,a5,a0	# ivtmp.47, _7, MEM[(long unsigned int *)_16]
	srl	a3,a3,a0	# ivtmp.47, _9, MEM[(long unsigned int *)_15]
# rgba2luma_min_planar.c:39:   r &= 0xFFu;
	andi	a5,a5,255	#, r_45, _7
# rgba2luma_min_planar.c:40:   g &= 0xFFu;
	andi	a3,a3,255	#, g_52, _9
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	mul	a5,a5,t6	# _54, r_45, tmp203
# rgba2luma_min_planar.c:71:         out_luma32[out_idx++] = rgb2luma_scalar_u32(rp[lane] >> sh,
	srl	a2,a2,a0	# ivtmp.47, _11, MEM[(long unsigned int *)_14]
# rgba2luma_min_planar.c:41:   b &= 0xFFu;
	andi	a2,a2,255	#, b_53, _11
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	slli	a4,a2,3	#, tmp214, b_53
	sub	a4,a4,a2	# tmp215, tmp214, b_53
	slli	a4,a4,2	#, tmp216, tmp215
	add	a4,a4,a2	# b_53, _57, tmp216
# rgba2luma_min_planar.c:71:         out_luma32[out_idx++] = rgb2luma_scalar_u32(rp[lane] >> sh,
	slli	a2,a1,2	#, tmp221, out_idx
	add	a2,t4,a2	# tmp221, tmp222, tmp249
# rgba2luma_min_planar.c:71:         out_luma32[out_idx++] = rgb2luma_scalar_u32(rp[lane] >> sh,
	addi	a1,a1,1	#, out_idx, out_idx
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	mul	a3,a3,t5	# _55, g_52, tmp208
# rgba2luma_min_planar.c:70:       for (uint32_t lane = 0u; lane < vl; ++lane) {
	addi	a6,a6,4	#, ivtmp.40, ivtmp.40
	addi	t1,t1,4	#, ivtmp.38, ivtmp.38
	addi	a7,a7,4	#, ivtmp.39, ivtmp.39
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	add	a5,a5,a3	# _55, _56, _54
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	add	a5,a5,a4	# _57, _58, _56
# rgba2luma_min_planar.c:42:   return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
	srli	a5,a5,8	#, _59, _58
# rgba2luma_min_planar.c:71:         out_luma32[out_idx++] = rgb2luma_scalar_u32(rp[lane] >> sh,
	sw	a5,0(a2)	# _59, out_luma32[out_idx_111]
# rgba2luma_min_planar.c:70:       for (uint32_t lane = 0u; lane < vl; ++lane) {
	bne	t3,a1,.L3	#, _13, out_idx,
# rgba2luma_min_planar.c:68:     for (uint32_t byte = 0u; byte < 4u; ++byte) {
	addi	a0,a0,8	#, ivtmp.47, ivtmp.47
	bne	a0,s2,.L4	#, ivtmp.47, tmp223,
# rgba2luma_min_planar.c:55:   for (uint32_t base = 0u; base < NWORDS; base += VLMAX_WORDS) {
	addi	t0,t0,8	#, ivtmp.61, ivtmp.61
	bne	t0,s3,.L5	#, ivtmp.61, tmp267,
# rgba2luma_min_planar.c:78:   *PERF_END_MMIO = 1u;
	li	a5,-65536		# tmp268,
	li	a4,1		# tmp228,
# rgba2luma_min_planar.c:81:   for (uint32_t i = 0u; i < NPIX; ++i) {
	li	a3,999424		# tmp234,
# rgba2luma_min_planar.c:78:   *PERF_END_MMIO = 1u;
	sw	a4,8(a5)	# tmp228, MEM[(volatile uint32_t *)4294901768B]
# rgba2luma_min_planar.c:81:   for (uint32_t i = 0u; i < NPIX; ++i) {
	addi	a3,a3,576	#, tmp234, tmp234
# rgba2luma_min_planar.c:81:   for (uint32_t i = 0u; i < NPIX; ++i) {
	li	a5,0		# i,
# rgba2luma_min_planar.c:80:   uint32_t sum = 0u;
	li	s0,0		# sum,
.L6:
# rgba2luma_min_planar.c:82:     sum += out_luma32[i] & 0xFFu;
	slli	a4,a5,2	#, tmp231, i
	add	a4,t4,a4	# tmp231, tmp232, tmp249
	lw	a4,0(a4)		# _12, out_luma32[i_105]
# rgba2luma_min_planar.c:81:   for (uint32_t i = 0u; i < NPIX; ++i) {
	addi	a5,a5,1	#, i, i
# rgba2luma_min_planar.c:82:     sum += out_luma32[i] & 0xFFu;
	andi	a4,a4,255	#, _34, _12
# rgba2luma_min_planar.c:82:     sum += out_luma32[i] & 0xFFu;
	add	s0,s0,a4	# _34, sum, sum
# rgba2luma_min_planar.c:81:   for (uint32_t i = 0u; i < NPIX; ++i) {
	bne	a5,a3,.L6	#, i, tmp234,
	lui	s1,%hi(.LC0)	# tmp183,
	lui	s2,%hi(.LC0+36)	# tmp246,
	addi	s1,s1,%lo(.LC0)	# s, tmp183,
	addi	s2,s2,%lo(.LC0+36)	# tmp253, tmp246,
# rgba2luma_min_planar.c:15:   while (*s) putchar_uart(*s++);
	li	a0,91		# _72,
.L7:
# rgba2luma_min_planar.c:15:   while (*s) putchar_uart(*s++);
	addi	s1,s1,1	#, s, s
# rgba2luma_min_planar.c:15:   while (*s) putchar_uart(*s++);
	call	putchar_uart		#
# rgba2luma_min_planar.c:15:   while (*s) putchar_uart(*s++);
	lbu	a0,0(s1)	# _72, MEM[(const char *)s_71]
	bne	s1,s2,.L7	#, s, tmp253,
	lui	s2,%hi(.LC1)	# tmp247,
	addi	s2,s2,%lo(.LC1)	# tmp256, tmp247,
	li	s1,28		# ivtmp.20,
# rgba2luma_min_planar.c:11:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	li	s3,-4		# tmp244,
.L8:
# rgba2luma_min_planar.c:11:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	srl	a5,s0,s1	# ivtmp.20, _65, sum
# rgba2luma_min_planar.c:11:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	andi	a5,a5,15	#, _66, _65
# rgba2luma_min_planar.c:11:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	add	a5,s2,a5	# _66, tmp240, tmp256
	lbu	a0,0(a5)	#, *_67
# rgba2luma_min_planar.c:11:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	addi	s1,s1,-4	#, ivtmp.20, ivtmp.20
# rgba2luma_min_planar.c:11:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	call	putchar_uart		#
# rgba2luma_min_planar.c:11:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	bne	s1,s3,.L8	#, ivtmp.20, tmp244,
# rgba2luma_min_planar.c:15:   while (*s) putchar_uart(*s++);
	li	a0,10		#,
	call	putchar_uart		#
# rgba2luma_min_planar.c:89:   *DONE_MMIO = sum;
	li	a5,-65536		# tmp245,
	sw	s0,0(a5)	# sum, MEM[(volatile uint32_t *)4294901760B]
.L9:
	j	.L9		#
	.size	main, .-main
	.section	.in_b,"aw"
	.align	2
	.type	in_b_packed, @object
	.size	in_b_packed, 1000000
in_b_packed:
	.zero	1000000
	.section	.in_g,"aw"
	.align	2
	.type	in_g_packed, @object
	.size	in_g_packed, 1000000
in_g_packed:
	.zero	1000000
	.section	.in_r,"aw"
	.align	2
	.type	in_r_packed, @object
	.size	in_r_packed, 1000000
in_r_packed:
	.zero	1000000
	.section	.out_luma32,"aw"
	.align	2
	.type	out_luma32, @object
	.size	out_luma32, 4000000
out_luma32:
	.zero	4000000
	.ident	"GCC: (g1b306039a) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
