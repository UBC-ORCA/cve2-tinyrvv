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

/*
 * Volatile is used for the same reason as in the scalar benchmark: these arrays
 * are preloaded by the testbench, not initialized by ordinary C code. Keeping
 * them volatile prevents the compiler from treating them as compile-time zeros.
 */
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
