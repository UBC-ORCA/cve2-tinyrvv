#include <stdint.h>

extern void putchar_uart(char c);
extern void rgba2luma_vec(const volatile uint32_t *in,
                          volatile uint32_t *out,
                          uint32_t n);

#define NPIX 10000u
#define RGBA_IN_ADDR  0x00010000u
#define LUMA_OUT_ADDR 0x00020000u

static volatile uint32_t *const DONE_MMIO       = (volatile uint32_t *)0xFFFF0000u;
static volatile uint32_t *const PERF_START_MMIO = (volatile uint32_t *)0xFFFF0004u;
static volatile uint32_t *const PERF_END_MMIO   = (volatile uint32_t *)0xFFFF0008u;

/*
 * Same fixed-address volatile buffers as the scalar benchmark.
 * The testbench injects the exact same input pixels before main() runs.
 */
static volatile uint32_t *const in_pixels  = (volatile uint32_t *)RGBA_IN_ADDR;
static volatile uint32_t *const out_luma32 = (volatile uint32_t *)LUMA_OUT_ADDR;

static void print_u32_hex(uint32_t x) {
  const char *hex = "0123456789abcdef";
  for (int i = 7; i >= 0; --i) putchar_uart(hex[(x >> (i * 4)) & 0xFu]);
}

static void print_str(const char *s) {
  while (*s) putchar_uart(*s++);
}

int main(void) {
  *PERF_START_MMIO = 1u;
  rgba2luma_vec(in_pixels, out_luma32, NPIX);
  *PERF_END_MMIO = 1u;

  // checksum: low 8 bits only, exactly like scalar benchmark
  uint32_t sum = 0;
  for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);

  print_str("[rgba2luma_vec] sum=");
  print_u32_hex(sum);
  print_str("\n");

  *DONE_MMIO = sum;
  for (;;) {}

  return 0;
}
