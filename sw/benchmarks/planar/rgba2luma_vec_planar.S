    .section .text
    .globl rgba2luma_vec_planar_packed_loop
    .align 2

 //rgba2luma_vec_planar_packed_loop(r=a0, g=a1, b=a2, out=a3, nwords=a4)
 //  r/g/b : planar packed input, 4 channel samples per 32-bit word
 //  out   : uint32_t luma output, one 32-bit word per pixel, low 8 bits used
 //  nwords: number of packed input words (pixels / 4)

#define OPV      0x57
#define LOADFP   0x07
#define STOREFP  0x27

#define RVV_VSETVLI(rd, rs1, vtypei) \
  .word (((vtypei) << 20) | ((rs1) << 15) | (7 << 12) | ((rd) << 7) | OPV)

#define RVV_VLE32(vd, rs1) \
  .word ((1 << 25) | ((rs1) << 15) | (6 << 12) | ((vd) << 7) | LOADFP)

#define RVV_VSE32(vs3, rs1) \
  .word ((1 << 25) | ((rs1) << 15) | (6 << 12) | ((vs3) << 7) | STOREFP)

#define F3_OPIVV 0
#define F3_OPIVX 4
#define F3_OPIVI 3

#define F6_VADD 0x00
#define F6_VMUL 0x25
#define F6_VAND 0x09
#define F6_VSRL 0x28

#define RVV_OPIVV(f6, vd, vs1, vs2) \
  .word (((f6) << 26) | (1 << 25) | ((vs2) << 20) | ((vs1) << 15) | (F3_OPIVV << 12) | ((vd) << 7) | OPV)

#define RVV_OPIVX(f6, vd, rs1, vs2) \
  .word (((f6) << 26) | (1 << 25) | ((vs2) << 20) | ((rs1) << 15) | (F3_OPIVX << 12) | ((vd) << 7) | OPV)

#define RVV_OPIVI(f6, vd, imm5, vs2) \
  .word (((f6) << 26) | (1 << 25) | ((vs2) << 20) | ((imm5) << 15) | (F3_OPIVI << 12) | ((vd) << 7) | OPV)

// Byte 0: no shift needed 
#define DO_BYTE0                          \
    RVV_OPIVX(F6_VAND, 4, 7, 1) ;         \
    RVV_OPIVX(F6_VAND, 5, 7, 2) ;         \
    RVV_OPIVX(F6_VAND, 6, 7, 3) ;         \
    RVV_OPIVX(F6_VMUL, 4, 28, 4) ;        \
    RVV_OPIVX(F6_VMUL, 5, 29, 5) ;        \
    RVV_OPIVX(F6_VMUL, 6, 30, 6) ;        \
    RVV_OPIVV(F6_VADD, 7, 4, 5) ;         \
    RVV_OPIVV(F6_VADD, 7, 7, 6) ;         \
    RVV_OPIVI(F6_VSRL, 7, 8, 7) ;         \
    RVV_VSE32(7, 13)

// Byte 1/2/3: shift first, then mask 
#define DO_SHIFTED_BYTE(SHIFTIMM)         \
    RVV_OPIVI(F6_VSRL, 4, SHIFTIMM, 1) ;  \
    RVV_OPIVX(F6_VAND, 4, 7, 4) ;         \
    RVV_OPIVI(F6_VSRL, 5, SHIFTIMM, 2) ;  \
    RVV_OPIVX(F6_VAND, 5, 7, 5) ;         \
    RVV_OPIVI(F6_VSRL, 6, SHIFTIMM, 3) ;  \
    RVV_OPIVX(F6_VAND, 6, 7, 6) ;         \
    RVV_OPIVX(F6_VMUL, 4, 28, 4) ;        \
    RVV_OPIVX(F6_VMUL, 5, 29, 5) ;        \
    RVV_OPIVX(F6_VMUL, 6, 30, 6) ;        \
    RVV_OPIVV(F6_VADD, 7, 4, 5) ;         \
    RVV_OPIVV(F6_VADD, 7, 7, 6) ;         \
    RVV_OPIVI(F6_VSRL, 7, 8, 7) ;         \
    RVV_VSE32(7, 13)

rgba2luma_vec_planar_packed_loop:
1:
    // vl = min(nwords, VLMAX) 
    RVV_VSETVLI(5, 14, 0x0D0)      // t0 = vl, rs1=a4 

    // Constants: keep these live for whole stripmine iteration 
    li  t2, 0xFF                   // mask 
    li  t3, 77
    li  t4, 150
    li  t5, 29

    // Packed input advance = vl //4 bytes 
    slli t1, t0, 2                 // t1 = bytes per packed plane chunk 

    // Load packed planar words once 
    RVV_VLE32(1, 10)               // v1 = packed R 
    RVV_VLE32(2, 11)               // v2 = packed G 
    RVV_VLE32(3, 12)               // v3 = packed B 

    // Save packed-plane advance 
    mv   t6, t1

    // ---- Byte 0 ---- 
    DO_BYTE0
    add  a3, a3, t6

    // ---- Byte 1 ---- 
    DO_SHIFTED_BYTE(8)
    add  a3, a3, t6

    // ---- Byte 2 ---- 
    DO_SHIFTED_BYTE(16)
    add  a3, a3, t6

    // ---- Byte 3 ---- 
    DO_SHIFTED_BYTE(24)
    add  a3, a3, t6

    // Advance packed input pointers once 
    add  a0, a0, t6
    add  a1, a1, t6
    add  a2, a2, t6

    // Remaining packed words 
    sub  a4, a4, t0
    bnez a4, 1b

    ret