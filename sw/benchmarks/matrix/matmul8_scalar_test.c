#include <stdint.h>

extern void putchar_uart(char c);

#define MAT_N 8

static volatile uint32_t *const DONE_MMIO       = (volatile uint32_t *)0xFFFF0000u;
static volatile uint32_t *const COMP_START_MMIO = (volatile uint32_t *)0xFFFF0004u;
static volatile uint32_t *const COMP_END_MMIO   = (volatile uint32_t *)0xFFFF0008u;

/*
 * These arrays are intentionally volatile.
 *
 * The Verilator testbench preloads .mat_a/.mat_bt/.mat_c before main() runs.
 * Without volatile, the compiler may legally assume static objects that are not
 * written by the C program still contain their zero-initialized values, then
 * constant-fold the whole benchmark into memset(mat_c, 0). Volatile forces real
 * loads/stores to be emitted for the benchmark memory locations.
 */
static volatile uint32_t mat_a[MAT_N * MAT_N]
    __attribute__((section(".mat_a"), used));
static volatile uint32_t mat_b[MAT_N * MAT_N]
    __attribute__((section(".mat_bt"), used));
static volatile uint32_t mat_c[MAT_N * MAT_N]
    __attribute__((section(".mat_c"), used));

static void print_u32_hex(uint32_t x) {
  const char *hex = "0123456789abcdef";
  for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
}

static void print_str(const char *s) {
  while (*s) putchar_uart(*s++);
}

int main(void) {
  *COMP_START_MMIO = 1u;

  for (int i = 0; i < MAT_N; ++i) {
    for (int j = 0; j < MAT_N; ++j) {
      /* Match the vector kernel's C += A*B behavior. The testbench preloads C=0. */
      uint32_t sum = mat_c[i * MAT_N + j];
      for (int k = 0; k < MAT_N; ++k) {
        const uint32_t a = mat_a[i * MAT_N + k];
        const uint32_t b = mat_b[k * MAT_N + j];
        sum += a * b;
      }
      mat_c[i * MAT_N + j] = sum;
    }
  }

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

  print_str("[matmul8_scalar] total=");
  print_u32_hex(total);
  print_str(" diag=");
  print_u32_hex(diag);
  print_str("\n");

  *DONE_MMIO = total;
  for (;;) {}

  return 0;
}
