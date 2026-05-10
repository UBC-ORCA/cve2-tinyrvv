    .section .text
    .globl matmul8_vec
    .align 2

#define OPV      0x57
#define LOADFP   0x07
#define STOREFP  0x27

/* vsetvli rd, rs1, e32,m1,ta,ma  -> vtypei = 0x0D0 */
#define RVV_VSETVLI(rd, rs1, vtypei) \
  .word (((vtypei) << 20) | ((rs1) << 15) | (7 << 12) | ((rd) << 7) | OPV)

/* vle32.v vd, (rs1) */
#define RVV_VLE32(vd, rs1) \
  .word ((1 << 25) | ((rs1) << 15) | (6 << 12) | ((vd) << 7) | LOADFP)

/* vse32.v vs3, (rs1) */
#define RVV_VSE32(vs3, rs1) \
  .word ((1 << 25) | ((rs1) << 15) | (6 << 12) | ((vs3) << 7) | STOREFP)

#define F3_OPIVV 0
#define F3_OPIVX 4
#define F6_VADD  0x00
#define F6_VMUL  0x25

/* opivv: vd = vs2 <op> vs1  (for vadd.vv, order does not matter) */
#define RVV_OPIVV(f6, vd, vs1, vs2) \
  .word (((f6) << 26) | (1 << 25) | ((vs2) << 20) | ((vs1) << 15) | (F3_OPIVV << 12) | ((vd) << 7) | OPV)

/* opivx: vd = vs2 <op> rs1 */
#define RVV_OPIVX(f6, vd, rs1, vs2) \
  .word (((f6) << 26) | (1 << 25) | ((vs2) << 20) | ((rs1) << 15) | (F3_OPIVX << 12) | ((vd) << 7) | OPV)

/*
 * matmul8_vec(a=a0, b=a1, c=a2, tmp=a3)
 *
 * A   is 8x8 row-major.
 * B   is 8x8 row-major.
 * C   is 8x8 row-major and is preloaded to zero by the testbench.
 * tmp is unused here, kept only to match the C prototype.
 *
 * Mathematical workload matches the scalar benchmark:
 *   C[i,j] = C[i,j] + sum_k A[i,k] * B[k,j]
 *
 * Implementation:
 *   preload all 8 rows of B into v0..v7 once,
 *   then for each output row i:
 *     acc = C[i,*]
 *     acc += A[i,0] * B[0,*]
 *     ...
 *     acc += A[i,7] * B[7,*]
 *     store acc to C[i,*]
 *
 * The vector unit is expected to handle vector instruction dependencies
 * through its busy/done handshake and synchronous-VRF read state.
 */

matmul8_vec:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0,  8(sp)
    sw   s1,  4(sp)
    sw   s2,  0(sp)

    mv   s0, a0              /* base A  */
    mv   s1, a1              /* base B  */
    mv   s2, a2              /* base C  */

    li   t0, 8
    RVV_VSETVLI(5, 5, 0x0D0) /* t0=x5 -> vl=8, e32,m1,ta,ma */

    /* Load all 8 rows of B one time: v0..v7 */
    RVV_VLE32(0, 9)          /* v0 <- B[0,*], rs1=s1=x9 */
    addi s1, s1, 32
    RVV_VLE32(1, 9)          /* v1 <- B[1,*] */
    addi s1, s1, 32
    RVV_VLE32(2, 9)          /* v2 <- B[2,*] */
    addi s1, s1, 32
    RVV_VLE32(3, 9)          /* v3 <- B[3,*] */
    addi s1, s1, 32
    RVV_VLE32(4, 9)          /* v4 <- B[4,*] */
    addi s1, s1, 32
    RVV_VLE32(5, 9)          /* v5 <- B[5,*] */
    addi s1, s1, 32
    RVV_VLE32(6, 9)          /* v6 <- B[6,*] */
    addi s1, s1, 32
    RVV_VLE32(7, 9)          /* v7 <- B[7,*] */

    li   t0, 8               /* outer loop count: 8 rows */

1:
    /* Load current C row into accumulator v8. C is preloaded to zero. */
    RVV_VLE32(8, 18)         /* v8 <- C[i,*], rs1=s2=x18 */

    lw      t1,  0(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 0)  /* v9 = v0 * t1, t1=x6 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)  /* v8 = v8 + v9 */

    lw      t1,  4(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 1)  /* v9 = v1 * t1 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)

    lw      t1,  8(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 2)  /* v9 = v2 * t1 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)

    lw      t1, 12(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 3)  /* v9 = v3 * t1 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)

    lw      t1, 16(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 4)  /* v9 = v4 * t1 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)

    lw      t1, 20(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 5)  /* v9 = v5 * t1 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)

    lw      t1, 24(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 6)  /* v9 = v6 * t1 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)

    lw      t1, 28(s0)
    RVV_OPIVX(F6_VMUL, 9, 6, 7)  /* v9 = v7 * t1 */
    RVV_OPIVV(F6_VADD, 8, 9, 8)

    RVV_VSE32(8, 18)         /* store C[i,*] */

    addi    s0, s0, 32       /* next row of A */
    addi    s2, s2, 32       /* next row of C */
    addi    t0, t0, -1
    bnez    t0, 1b

    lw   ra, 12(sp)
    lw   s0,  8(sp)
    lw   s1,  4(sp)
    lw   s2,  0(sp)
    addi sp, sp, 16
    ret