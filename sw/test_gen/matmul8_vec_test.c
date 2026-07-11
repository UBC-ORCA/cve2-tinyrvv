
#include <stdint.h>

extern void putchar_uart(char c);
extern void matmul8_vec(const volatile uint32_t *a,
                        const volatile uint32_t *b,
                        volatile uint32_t *c,
                        volatile uint32_t *tmp_prod);

#define MAT_N 8
#define TT 8
#define BS 8
#define NVREG 32

static volatile uint32_t *const DONE_MMIO       = (volatile uint32_t *)0xFFFF0000u;
static volatile uint32_t *const COMP_START_MMIO = (volatile uint32_t *)0xFFFF0004u;
static volatile uint32_t *const COMP_END_MMIO   = (volatile uint32_t *)0xFFFF0008u;


static volatile uint32_t mat_a[TT * BS * NVREG]
    __attribute__((section(".mat_a"), used));
static volatile uint32_t mat_b[MAT_N * MAT_N]
    __attribute__((section(".mat_bt"), used));
static volatile uint32_t mat_c[MAT_N * MAT_N]
    __attribute__((section(".mat_c"), used));
static volatile uint32_t tmp_prod[MAT_N]
    __attribute__((section(".tmp_prod"), used));

static void print_u32_hex(uint32_t x) {
  const char *hex = "0123456789abcdef";
  for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
}

static void print_str(const char *s) {
  while (*s) putchar_uart(*s++);
}






/*

int main(void) {
  *COMP_START_MMIO = 1u;
  matmul8_vec(mat_a, mat_b, mat_c, tmp_prod);
  *COMP_END_MMIO = 1u;

  uint32_t total = 0;
  uint32_t diag  = 0;
  for (int i = 0; i < MAT_N; ++i) {
    for (int j = 0; j < MAT_N; ++j) {
      uint32_t v = mat_c[i * MAT_N + j];
      total += v;
      if (i == j) diag += v;
    }
  }

  print_str("[matmul8_vec] total=");
  print_u32_hex(total);
  print_str(" diag=");
  print_u32_hex(diag);
  print_str("\n");

  *DONE_MMIO = total;
  for (;;) {}

  return 0;
}

*/

// --- [stev] ---
//extern void load_v0(uint32_t *ptr);
//extern void load_v1(uint32_t *ptr);

uint32_t vec[8] = {
    0x11111111,
    0x22222222,
    0x33333333,
    0x44444444,
    0x55555555,
    0x66666666,
    0x77777777,
    0x88888888
};
// --- [end] ---

extern void mac_zz(void);
extern void mac_hw(uint32_t a, uint32_t b);
extern uint32_t mac_out_even(void);
extern uint32_t mac_out_odd(void);
extern uint32_t mac_out_pair(void);
extern void mac_max(int16_t threshold);
//extern void mac_add_row(uint32_t value);
extern void mac_add_row(uint32_t row, int16_t value);

extern void mac_ld2(void *base);
extern void mac_st2(void *base);


// Load vector registers
extern void load_v0(uint32_t *ptr);
extern void load_v1(uint32_t *ptr);
extern void load_v2(uint32_t *ptr);
extern void load_v3(uint32_t *ptr);
extern void load_v4(uint32_t *ptr);
extern void load_v5(uint32_t *ptr);
extern void load_v6(uint32_t *ptr);
extern void load_v7(uint32_t *ptr);
extern void load_v8(uint32_t *ptr);
extern void load_v9(uint32_t *ptr);
extern void load_v10(uint32_t *ptr);
extern void load_v11(uint32_t *ptr);
extern void load_v12(uint32_t *ptr);
extern void load_v13(uint32_t *ptr);
extern void load_v14(uint32_t *ptr);
extern void load_v15(uint32_t *ptr);
extern void load_v16(uint32_t *ptr);
extern void load_v17(uint32_t *ptr);
extern void load_v18(uint32_t *ptr);
extern void load_v19(uint32_t *ptr);
extern void load_v20(uint32_t *ptr);
extern void load_v21(uint32_t *ptr);
extern void load_v22(uint32_t *ptr);
extern void load_v23(uint32_t *ptr);
extern void load_v24(uint32_t *ptr);
extern void load_v25(uint32_t *ptr);
extern void load_v26(uint32_t *ptr);
extern void load_v27(uint32_t *ptr);
extern void load_v28(uint32_t *ptr);
extern void load_v29(uint32_t *ptr);
extern void load_v30(uint32_t *ptr);
extern void load_v31(uint32_t *ptr);

// Memory-backed VMAC tests
extern void mac_mem_test_v0(uint32_t *ptr);
extern void mac_mem_test_v1(uint32_t *ptr);
extern void mac_mem_test_v2(uint32_t *ptr);
extern void mac_mem_test_v3(uint32_t *ptr);
extern void mac_mem_test_v4(uint32_t *ptr);
extern void mac_mem_test_v5(uint32_t *ptr);
extern void mac_mem_test_v6(uint32_t *ptr);
extern void mac_mem_test_v7(uint32_t *ptr);
extern void mac_mem_test_v8(uint32_t *ptr);
extern void mac_mem_test_v9(uint32_t *ptr);
extern void mac_mem_test_v10(uint32_t *ptr);
extern void mac_mem_test_v11(uint32_t *ptr);
extern void mac_mem_test_v12(uint32_t *ptr);
extern void mac_mem_test_v13(uint32_t *ptr);
extern void mac_mem_test_v14(uint32_t *ptr);
extern void mac_mem_test_v15(uint32_t *ptr);
extern void mac_mem_test_v16(uint32_t *ptr);
extern void mac_mem_test_v17(uint32_t *ptr);
extern void mac_mem_test_v18(uint32_t *ptr);
extern void mac_mem_test_v19(uint32_t *ptr);
extern void mac_mem_test_v20(uint32_t *ptr);
extern void mac_mem_test_v21(uint32_t *ptr);
extern void mac_mem_test_v22(uint32_t *ptr);
extern void mac_mem_test_v23(uint32_t *ptr);
extern void mac_mem_test_v24(uint32_t *ptr);
extern void mac_mem_test_v25(uint32_t *ptr);
extern void mac_mem_test_v26(uint32_t *ptr);
extern void mac_mem_test_v27(uint32_t *ptr);
extern void mac_mem_test_v28(uint32_t *ptr);
extern void mac_mem_test_v29(uint32_t *ptr);
extern void mac_mem_test_v30(uint32_t *ptr);
extern void mac_mem_test_v31(uint32_t *ptr);



//static volatile uint32_t mac_test_mem[8]
  //  __attribute__((section(".mat_a"), used));
//MEM_end


// mode:
//   0 = even
//   1 = odd
//   2 = pair
uint32_t mac_out(uint32_t row, uint32_t pair, uint32_t mode);

int main(void)
{

uint32_t a = 0x01234567;
uint32_t b = 0x76543210;

uint32_t data;

//MEM
//MEM

for (int i = 0; i < TT * BS * NVREG; i++)
{
    //mat_a[i] = 0x11111111 * (i + 1);
 	mat_a[i] = vec[i % 8];
}



//MEM_end
//MEM_end


  *COMP_START_MMIO = 1u;

    //mac_zz(); //[stev] - looks good

/*
     * Load v0 with 8 words.
     * VMAC64 will use v0 as the vector operand.
     */
    load_v1((uint32_t *)mat_a);

   /*
     * Run vector MAC.
     * Assembly:
     *   VMAC64(0,0,10)
     *   v0 x memory block 0
     */
    mac_mem_test_v1((uint32_t *)mat_a);

mac_zz(); //clear tile here

mac_hw(a, b); //[stev] - looks good

uint32_t chk = mac_out(4,1,2);

mac_zz(); //clear tile here

     load_v0((uint32_t *)mat_a);

    mac_mem_test_v0((uint32_t *)mat_a);


//v31
mac_zz(); //clear tile here

     load_v31((uint32_t *)mat_a);

    mac_mem_test_v31((uint32_t *)mat_a);


//MEM
   //  load_v0(vec);   // [stev] - fills v0
//	mac_hw(a, b); //[stev] - looks good
//MEM_end

//mac_mem_test((uint32_t *)mac_test_mem);

//uint32_t chk = mac_out_pair(); //[stev] - good
//uint32_t chk = mac_out_even(); //[stev] - good
//uint32_t chk = mac_out_odd(); //[stev] - good
//mac_max(96); //[stev] - looks good
//mac_add_row(7,0x00000010); //[stev] - looks good


//mac_ld2(&data); //[stev] - not good
//mac_st2(&data); //[stev] - not good

//mac_max(12); //[stev] - looks good
//chk = mac_out_pair(); //[stev] - good

//chk = mac_out(0,1,0); 
//chk = mac_out(6,3,1); 
//chk = mac_out(4,1,2); 


  *COMP_END_MMIO = 1u;

 // *DONE_MMIO = 0x22;
  *DONE_MMIO = chk;

  while (1) {}
}

/*
#define CUSTOM2 0x7b
#define MAC_ZZ  0x00
#define MAC_HW  0x02
#define MAC_MVO 0x04

#define MAC_INS(f7) ((CUSTOM2) | ((f7) << 25))

static inline void mac_zz(void) {
  asm volatile(".word %0" :: "i"(MAC_INS(MAC_ZZ)));
}

static inline void mac_hw(void) {
  asm volatile(".word %0" :: "i"(MAC_INS(MAC_HW)));
}

static inline uint32_t mac_out(void) {
  uint32_t v;
  asm volatile(
    ".word %1\n"
    "mv %0, x10"
    : "=r"(v)
    : "i"(MAC_INS(MAC_MVO))
    : "x10"
  );
  return v;
}

int main() {
  *COMP_START_MMIO = 1u;




  mac_zz();   // reset tile

  // deterministic accumulation test
  //mac_hw();
 // mac_hw();
  //mac_hw();

  *COMP_END_MMIO = 1u;



  //uint32_t result = mac_out();

  *DONE_MMIO = result;
  *DONE_MMIO = 1;
  while (1) {}
}
*/


