#include <stdint.h>

extern void putchar_uart(char c);
extern void rgba2luma_vec_planar_packed_loop(uint32_t *r, uint32_t *g, uint32_t *b,
                                             uint32_t *out, uint32_t nwords);

static volatile uint32_t *const DONE_MMIO       = (volatile uint32_t *)0xFFFF0000u;
static volatile uint32_t *const PERF_START_MMIO = (volatile uint32_t *)0xFFFF0004u;
static volatile uint32_t *const PERF_END_MMIO   = (volatile uint32_t *)0xFFFF0008u;

static void print_u32_hex(uint32_t x) {
  const char *hex = "0123456789abcdef";
  for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
}

static void print_str(const char *s) {
  while (*s) putchar_uart(*s++);
}

#define NPIX   1000000u
#define NWORDS (NPIX / 4u)

/*
 * The testbench preloads these fixed sections with deterministic pseudo-random
 * packed-planar input data.  Keep them volatile/used so the compiler cannot
 * treat the benchmark as operating on known static zeros.
 */
static volatile uint32_t in_r_packed[NWORDS]
    __attribute__((section(".in_r"), used));
static volatile uint32_t in_g_packed[NWORDS]
    __attribute__((section(".in_g"), used));
static volatile uint32_t in_b_packed[NWORDS]
    __attribute__((section(".in_b"), used));
static volatile uint32_t out_luma32[NPIX]
    __attribute__((section(".out_luma32"), used));

int main(void) {
  *PERF_START_MMIO = 1u;
  rgba2luma_vec_planar_packed_loop((uint32_t *)in_r_packed,
                                   (uint32_t *)in_g_packed,
                                   (uint32_t *)in_b_packed,
                                   (uint32_t *)out_luma32,
                                   NWORDS);
  *PERF_END_MMIO = 1u;

  uint32_t sum = 0u;
  for (uint32_t i = 0u; i < NPIX; ++i) {
    sum += out_luma32[i] & 0xFFu;
  }

  print_str("[rgb2luma_vec_planar_packed_loop] sum=");
  print_u32_hex(sum);
  print_str("\n");

  *DONE_MMIO = sum;
  for (;;) {}
  return 0;
}
