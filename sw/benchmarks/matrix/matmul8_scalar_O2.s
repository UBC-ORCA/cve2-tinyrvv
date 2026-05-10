	.file	"matmul8_scalar_test.c"
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
	.string	"0123456789abcdef"
	.text
	.align	2
	.type	print_u32_hex, @function
print_u32_hex:
	addi	sp,sp,-32	#,,
	sw	s1,20(sp)	#,
	lui	s1,%hi(.LC0)	# tmp148,
	sw	s0,24(sp)	#,
	sw	s2,16(sp)	#,
	sw	s3,12(sp)	#,
	sw	ra,28(sp)	#,
# matmul8_scalar_test.c:27: static void print_u32_hex(uint32_t x) {
	mv	s3,a0	# x, x
	addi	s1,s1,%lo(.LC0)	# tmp149, tmp148,
	li	s0,28		# ivtmp.12,
# matmul8_scalar_test.c:29:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	li	s2,-4		# tmp147,
.L2:
# matmul8_scalar_test.c:29:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	srl	a5,s3,s0	# ivtmp.12, _2, x
# matmul8_scalar_test.c:29:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	andi	a5,a5,15	#, _3, _2
# matmul8_scalar_test.c:29:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	add	a5,s1,a5	# _3, tmp143, tmp149
	lbu	a0,0(a5)	#, *_4
# matmul8_scalar_test.c:29:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	addi	s0,s0,-4	#, ivtmp.12, ivtmp.12
# matmul8_scalar_test.c:29:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	call	putchar_uart		#
# matmul8_scalar_test.c:29:   for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
	bne	s0,s2,.L2	#, ivtmp.12, tmp147,
# matmul8_scalar_test.c:30: }
	lw	ra,28(sp)		#,
	lw	s0,24(sp)		#,
	lw	s1,20(sp)		#,
	lw	s2,16(sp)		#,
	lw	s3,12(sp)		#,
	addi	sp,sp,32	#,,
	jr	ra		#
	.size	print_u32_hex, .-print_u32_hex
	.align	2
	.type	print_str, @function
print_str:
	addi	sp,sp,-16	#,,
	sw	s0,8(sp)	#,
	sw	ra,12(sp)	#,
# matmul8_scalar_test.c:32: static void print_str(const char *s) {
	mv	s0,a0	# s, s
# matmul8_scalar_test.c:33:   while (*s) putchar_uart(*s++);
	lbu	a0,0(a0)	# _1, *s_4(D)
	beq	a0,zero,.L6	#, _1,,
.L8:
# matmul8_scalar_test.c:33:   while (*s) putchar_uart(*s++);
	addi	s0,s0,1	#, s, s
# matmul8_scalar_test.c:33:   while (*s) putchar_uart(*s++);
	call	putchar_uart		#
# matmul8_scalar_test.c:33:   while (*s) putchar_uart(*s++);
	lbu	a0,0(s0)	# _1, MEM[(const char *)s_6]
	bne	a0,zero,.L8	#, _1,,
.L6:
# matmul8_scalar_test.c:34: }
	lw	ra,12(sp)		#,
	lw	s0,8(sp)		#,
	addi	sp,sp,16	#,,
	jr	ra		#
	.size	print_str, .-print_str
	.section	.rodata.str1.4
	.align	2
.LC1:
	.string	"[matmul8_scalar] total="
	.align	2
.LC2:
	.string	" diag="
	.align	2
.LC3:
	.string	"\n"
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-16	#,,
	sw	ra,12(sp)	#,
	sw	s0,8(sp)	#,
	sw	s1,4(sp)	#,
# matmul8_scalar_test.c:37:   *COMP_START_MMIO = 1u;
	li	a5,-65536		# tmp206,
	li	a4,1		# tmp159,
	lui	t3,%hi(.LANCHOR0)	# tmp193,
	lui	a7,%hi(.LANCHOR1)	# tmp194,
	lui	a6,%hi(.LANCHOR2)	# tmp195,
	sw	a4,4(a5)	# tmp159, MEM[(volatile uint32_t *)4294901764B]
	addi	t3,t3,%lo(.LANCHOR0)	# tmp197, tmp193,
	addi	a7,a7,%lo(.LANCHOR1)	# tmp198, tmp194,
	addi	a6,a6,%lo(.LANCHOR2)	# tmp200, tmp195,
	li	t4,0		# ivtmp.63,
# matmul8_scalar_test.c:40:     for (int j = 0; j < MAT_N; ++j) {
	li	t6,72		# tmp178,
# matmul8_scalar_test.c:39:   for (int i = 0; i < MAT_N; ++i) {
	li	t0,64		# tmp204,
.L15:
# matmul8_scalar_test.c:36: int main(void) {
	li	a0,64		# ivtmp.57,
	addi	t5,t4,-64	#, _72, ivtmp.63
.L17:
# matmul8_scalar_test.c:42:       uint32_t sum = mat_c[i * MAT_N + j];
	add	t1,t5,a0	# ivtmp.57, _2, _72
# matmul8_scalar_test.c:42:       uint32_t sum = mat_c[i * MAT_N + j];
	slli	t1,t1,2	#, tmp196, _2
	add	a5,t3,t1	# tmp196, tmp164, tmp197
	lw	a1,0(a5)		# sum, mat_c[_2]
	mv	a2,t4	# ivtmp.49, ivtmp.63
	addi	a5,a0,-64	#, ivtmp.50, ivtmp.57
.L16:
# matmul8_scalar_test.c:44:         const uint32_t a = mat_a[i * MAT_N + k];
	slli	a4,a2,2	#, tmp167, ivtmp.49
# matmul8_scalar_test.c:45:         const uint32_t b = mat_b[k * MAT_N + j];
	slli	a3,a5,2	#, tmp171, ivtmp.50
# matmul8_scalar_test.c:44:         const uint32_t a = mat_a[i * MAT_N + k];
	add	a4,a7,a4	# tmp167, tmp168, tmp198
# matmul8_scalar_test.c:45:         const uint32_t b = mat_b[k * MAT_N + j];
	add	a3,a6,a3	# tmp171, tmp172, tmp200
# matmul8_scalar_test.c:44:         const uint32_t a = mat_a[i * MAT_N + k];
	lw	a4,0(a4)		# a, mat_a[_3]
# matmul8_scalar_test.c:45:         const uint32_t b = mat_b[k * MAT_N + j];
	lw	a3,0(a3)		# b, mat_b[_5]
# matmul8_scalar_test.c:43:       for (int k = 0; k < MAT_N; ++k) {
	addi	a5,a5,8	#, ivtmp.50, ivtmp.50
	addi	a2,a2,1	#, ivtmp.49, ivtmp.49
# matmul8_scalar_test.c:46:         sum += a * b;
	mul	a4,a4,a3	# _6, a, b
# matmul8_scalar_test.c:46:         sum += a * b;
	add	a1,a1,a4	# _6, sum, sum
# matmul8_scalar_test.c:43:       for (int k = 0; k < MAT_N; ++k) {
	bne	a0,a5,.L16	#, ivtmp.57, ivtmp.50,
# matmul8_scalar_test.c:48:       mat_c[i * MAT_N + j] = sum;
	add	t1,t3,t1	# tmp196, tmp177, tmp197
	sw	a1,0(t1)	# sum, mat_c[_2]
# matmul8_scalar_test.c:40:     for (int j = 0; j < MAT_N; ++j) {
	addi	a0,a0,1	#, ivtmp.57, ivtmp.57
	bne	a0,t6,.L17	#, ivtmp.57, tmp178,
# matmul8_scalar_test.c:39:   for (int i = 0; i < MAT_N; ++i) {
	addi	t4,t4,8	#, ivtmp.63, ivtmp.63
	bne	t4,t0,.L15	#, ivtmp.63, tmp204,
# matmul8_scalar_test.c:52:   *COMP_END_MMIO = 1u;
	li	a5,-65536		# tmp205,
	li	a4,1		# tmp182,
	sw	a4,8(a5)	# tmp182, MEM[(volatile uint32_t *)4294901768B]
	li	a2,0		# ivtmp.43,
# matmul8_scalar_test.c:56:   for (int i = 0; i < MAT_N; ++i) {
	li	a3,0		# i,
# matmul8_scalar_test.c:55:   uint32_t diag  = 0;
	li	s1,0		# diag,
# matmul8_scalar_test.c:54:   uint32_t total = 0;
	li	s0,0		# total,
# matmul8_scalar_test.c:57:     for (int j = 0; j < MAT_N; ++j) {
	li	a1,8		# tmp187,
.L21:
# matmul8_scalar_test.c:57:     for (int j = 0; j < MAT_N; ++j) {
	li	a4,0		# j,
	j	.L20		#
.L19:
# matmul8_scalar_test.c:57:     for (int j = 0; j < MAT_N; ++j) {
	addi	a4,a4,1	#, j, j
# matmul8_scalar_test.c:57:     for (int j = 0; j < MAT_N; ++j) {
	beq	a4,a1,.L28	#, j, tmp187,
.L20:
# matmul8_scalar_test.c:58:       uint32_t v = mat_c[i * MAT_N + j];
	add	a5,a4,a2	# ivtmp.43, _93, j
# matmul8_scalar_test.c:58:       uint32_t v = mat_c[i * MAT_N + j];
	slli	a5,a5,2	#, tmp185, _93
	add	a5,t3,a5	# tmp185, tmp186, tmp197
	lw	a5,0(a5)		# v, mat_c[_93]
# matmul8_scalar_test.c:59:       total += v;
	add	s0,s0,a5	# v, total, total
# matmul8_scalar_test.c:60:       if (i == j) diag += v;
	bne	a3,a4,.L19	#, i, j,
# matmul8_scalar_test.c:57:     for (int j = 0; j < MAT_N; ++j) {
	addi	a4,a4,1	#, j, j
# matmul8_scalar_test.c:60:       if (i == j) diag += v;
	add	s1,s1,a5	# v, diag, diag
# matmul8_scalar_test.c:57:     for (int j = 0; j < MAT_N; ++j) {
	bne	a4,a1,.L20	#, j, tmp187,
.L28:
# matmul8_scalar_test.c:56:   for (int i = 0; i < MAT_N; ++i) {
	addi	a3,a3,1	#, i, i
# matmul8_scalar_test.c:56:   for (int i = 0; i < MAT_N; ++i) {
	addi	a2,a2,8	#, ivtmp.43, ivtmp.43
	bne	a3,a4,.L21	#, i, j,
# matmul8_scalar_test.c:64:   print_str("[matmul8_scalar] total=");
	lui	a0,%hi(.LC1)	# tmp189,
	addi	a0,a0,%lo(.LC1)	#, tmp189,
	call	print_str		#
# matmul8_scalar_test.c:65:   print_u32_hex(total);
	mv	a0,s0	#, total
	call	print_u32_hex		#
# matmul8_scalar_test.c:66:   print_str(" diag=");
	lui	a0,%hi(.LC2)	# tmp190,
	addi	a0,a0,%lo(.LC2)	#, tmp190,
	call	print_str		#
# matmul8_scalar_test.c:67:   print_u32_hex(diag);
	mv	a0,s1	#, diag
	call	print_u32_hex		#
# matmul8_scalar_test.c:68:   print_str("\n");
	lui	a0,%hi(.LC3)	# tmp191,
	addi	a0,a0,%lo(.LC3)	#, tmp191,
	call	print_str		#
# matmul8_scalar_test.c:70:   *DONE_MMIO = total;
	li	a5,-65536		# tmp192,
	sw	s0,0(a5)	# total, MEM[(volatile uint32_t *)4294901760B]
.L22:
	j	.L22		#
	.size	main, .-main
	.section	.mat_a,"aw"
	.align	2
	.set	.LANCHOR1,. + 0
	.type	mat_a, @object
	.size	mat_a, 256
mat_a:
	.zero	256
	.section	.mat_bt,"aw"
	.align	2
	.set	.LANCHOR2,. + 0
	.type	mat_b, @object
	.size	mat_b, 256
mat_b:
	.zero	256
	.section	.mat_c,"aw"
	.align	2
	.set	.LANCHOR0,. + 0
	.type	mat_c, @object
	.size	mat_c, 256
mat_c:
	.zero	256
	.ident	"GCC: (g1b306039a) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
