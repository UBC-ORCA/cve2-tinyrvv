	.file	"rgba2luma_min.c"
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
	.string	"[rgba2luma_scalar] sum="
	.align	2
.LC1:
	.string	"0123456789abcdef"
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-32	#,,
	sw	ra,28(sp)	#,
	sw	s0,24(sp)	#,
	sw	s1,20(sp)	#,
	sw	s2,16(sp)	#,
	sw	s3,12(sp)	#,
# rgba2luma_min.c:41:   *PERF_START_MMIO = 1u;
	li	a5,-65536		# tmp211,
	li	a4,1		# tmp167,
	li	a2,65536		# ivtmp.37,
# rgba2luma_min.c:42:   for (uint32_t i = 0; i < NPIX; i++) {
	li	a6,106496		# tmp185,
# rgba2luma_min.c:41:   *PERF_START_MMIO = 1u;
	sw	a4,4(a5)	# tmp167, MEM[(volatile uint32_t *)4294901764B]
# rgba2luma_min.c:43:     out_luma32[i] = rgba2luma_scalar_u32(in_pixels[i]);
	mv	t3,a2	# tmp168, ivtmp.37
# rgba2luma_min.c:42:   for (uint32_t i = 0; i < NPIX; i++) {
	addi	a6,a6,-960	#, tmp185, tmp185
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	li	t1,150		# tmp172,
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	li	a7,77		# tmp183,
.L2:
# rgba2luma_min.c:43:     out_luma32[i] = rgba2luma_scalar_u32(in_pixels[i]);
	lw	a4,0(a2)		# _3, *_2
# rgba2luma_min.c:43:     out_luma32[i] = rgba2luma_scalar_u32(in_pixels[i]);
	add	a0,a2,t3	# tmp168, _4, ivtmp.37
# rgba2luma_min.c:42:   for (uint32_t i = 0; i < NPIX; i++) {
	addi	a2,a2,4	#, ivtmp.37, ivtmp.37
# rgba2luma_min.c:34:   const uint32_t g = (p >> 8)  & 0xFFu;
	srli	a5,a4,8	#, _26, _3
# rgba2luma_min.c:33:   const uint32_t r = (p >> 0)  & 0xFFu;
	andi	a1,a4,255	#, r_25, _3
# rgba2luma_min.c:35:   const uint32_t b = (p >> 16) & 0xFFu;
	srli	a4,a4,16	#, _28, _3
# rgba2luma_min.c:35:   const uint32_t b = (p >> 16) & 0xFFu;
	andi	a4,a4,255	#, b_29, _28
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	slli	a3,a4,3	#, tmp176, b_29
	sub	a3,a3,a4	# tmp177, tmp176, b_29
# rgba2luma_min.c:34:   const uint32_t g = (p >> 8)  & 0xFFu;
	andi	a5,a5,255	#, g_27, _26
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	slli	a3,a3,2	#, tmp178, tmp177
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	mul	a5,a5,t1	# _31, g_27, tmp172
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	add	a4,a3,a4	# b_29, _33, tmp178
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	mul	a3,a1,a7	# _30, r_25, tmp183
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	add	a5,a5,a4	# _33, _62, _31
	add	a5,a5,a3	# _30, _34, _62
# rgba2luma_min.c:36:   const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
	srli	a5,a5,8	#, y, _34
# rgba2luma_min.c:43:     out_luma32[i] = rgba2luma_scalar_u32(in_pixels[i]);
	sw	a5,0(a0)	# y, *_4
# rgba2luma_min.c:42:   for (uint32_t i = 0; i < NPIX; i++) {
	bne	a2,a6,.L2	#, ivtmp.37, tmp185,
# rgba2luma_min.c:45:   *PERF_END_MMIO = 1u;
	li	a5,-65536		# tmp209,
	li	a4,1		# tmp189,
# rgba2luma_min.c:49:   for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);
	li	a3,172032		# tmp191,
# rgba2luma_min.c:45:   *PERF_END_MMIO = 1u;
	sw	a4,8(a5)	# tmp189, MEM[(volatile uint32_t *)4294901768B]
# rgba2luma_min.c:49:   for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);
	addi	a3,a3,-960	#, tmp191, tmp191
# rgba2luma_min.c:45:   *PERF_END_MMIO = 1u;
	li	a5,131072		# ivtmp.30,
# rgba2luma_min.c:48:   uint32_t sum = 0;
	li	s0,0		# sum,
.L3:
# rgba2luma_min.c:49:   for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);
	lw	a4,0(a5)		# _8, *_7
# rgba2luma_min.c:49:   for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);
	addi	a5,a5,4	#, ivtmp.30, ivtmp.30
# rgba2luma_min.c:49:   for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);
	andi	a4,a4,255	#, _20, _8
# rgba2luma_min.c:49:   for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);
	add	s0,s0,a4	# _20, sum, sum
# rgba2luma_min.c:49:   for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);
	bne	a5,a3,.L3	#, ivtmp.30, tmp191,
	lui	s1,%hi(.LC0)	# tmp164,
	lui	s2,%hi(.LC0+23)	# tmp206,
	addi	s1,s1,%lo(.LC0)	# s, tmp164,
	addi	s2,s2,%lo(.LC0+23)	# tmp204, tmp206,
# rgba2luma_min.c:28:   while (*s) putchar_uart(*s++);
	li	a0,91		# _49,
.L4:
# rgba2luma_min.c:28:   while (*s) putchar_uart(*s++);
	addi	s1,s1,1	#, s, s
# rgba2luma_min.c:28:   while (*s) putchar_uart(*s++);
	call	putchar_uart		#
# rgba2luma_min.c:28:   while (*s) putchar_uart(*s++);
	lbu	a0,0(s1)	# _49, MEM[(const char *)s_48]
	bne	s1,s2,.L4	#, s, tmp204,
	lui	s2,%hi(.LC1)	# tmp205,
	addi	s2,s2,%lo(.LC1)	# tmp203, tmp205,
	li	s1,28		# ivtmp.16,
# rgba2luma_min.c:24:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	li	s3,-4		# tmp201,
.L5:
# rgba2luma_min.c:24:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	srl	a5,s0,s1	# ivtmp.16, _42, sum
# rgba2luma_min.c:24:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	andi	a5,a5,15	#, _43, _42
# rgba2luma_min.c:24:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	add	a5,s2,a5	# _43, tmp197, tmp203
	lbu	a0,0(a5)	#, *_44
# rgba2luma_min.c:24:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	addi	s1,s1,-4	#, ivtmp.16, ivtmp.16
# rgba2luma_min.c:24:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	call	putchar_uart		#
# rgba2luma_min.c:24:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	bne	s1,s3,.L5	#, ivtmp.16, tmp201,
# rgba2luma_min.c:28:   while (*s) putchar_uart(*s++);
	li	a0,10		#,
	call	putchar_uart		#
# rgba2luma_min.c:55:   *DONE_MMIO = sum;
	li	a5,-65536		# tmp202,
	sw	s0,0(a5)	# sum, MEM[(volatile uint32_t *)4294901760B]
.L6:
	j	.L6		#
	.size	main, .-main
	.ident	"GCC: (g1b306039a) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
