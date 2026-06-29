
#include <stdint.h>

extern void putchar_uart(char c);
extern void matmul8_vec(const volatile uint32_t *a,
                        const volatile uint32_t *b,
                        volatile uint32_t *c,
                        volatile uint32_t *tmp_prod);

#define MAT_N 8

static volatile uint32_t *const DONE_MMIO       = (volatile uint32_t *)0xFFFF0000u;
static volatile uint32_t *const COMP_START_MMIO = (volatile uint32_t *)0xFFFF0004u;
static volatile uint32_t *const COMP_END_MMIO   = (volatile uint32_t *)0xFFFF0008u;


static volatile uint32_t mat_a[MAT_N * MAT_N]
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



extern void mac_zz(void);
extern void mac_hw(uint32_t a, uint32_t b);
extern uint32_t mac_out_even(void);
extern uint32_t mac_out_odd(void);
extern uint32_t mac_out_pair(void);
extern void mac_max(int16_t threshold);
extern void mac_add_row(uint32_t value);

extern void mac_ld2(void *base);
extern void mac_st2(void *base);

int main(void)
{

uint32_t a = 0x01234567;
uint32_t b = 0x76543210;

uint32_t data;

  *COMP_START_MMIO = 1u;

    //mac_zz(); //[stev] - looks good
    
	mac_hw(a, b); //[stev] - looks good
uint32_t chk = mac_out_pair(); //[stev] - not good
//uint32_t chk = mac_out_even(); //[stev] - not good
//uint32_t chk = mac_out_odd(); //[stev] - not good
//mac_max(96); //[stev] - looks good
//mac_add_row(0x00000010); //[stev] - looks good


//mac_ld2(&data); //[stev] - not good
//mac_st2(&data); //[stev] - not good


  *COMP_END_MMIO = 1u;

//  *DONE_MMIO = 0x22;
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


