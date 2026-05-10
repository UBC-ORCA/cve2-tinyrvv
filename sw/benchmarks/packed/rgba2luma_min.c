#include <stdint.h>

extern void putchar_uart(char c);

#define NPIX 10000u
#define RGBA_IN_ADDR  0x00010000u
#define LUMA_OUT_ADDR 0x00020000u

static volatile uint32_t *const DONE_MMIO       = (volatile uint32_t *)0xFFFF0000u;
static volatile uint32_t *const PERF_START_MMIO = (volatile uint32_t *)0xFFFF0004u;
static volatile uint32_t *const PERF_END_MMIO   = (volatile uint32_t *)0xFFFF0008u;

/*
 * The input/output buffers are intentionally volatile fixed-address memory.
 * The Verilator testbench preloads RGBA_IN_ADDR with deterministic pseudo-random
 * pixels before main() runs and clears LUMA_OUT_ADDR. This prevents the compiler
 * from proving that the inputs are known constants or zero-initialized static data.
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

// 0xAABBGGRR -> Y in low 8 bits of a 32-bit word.
static inline uint32_t rgba2luma_scalar_u32(uint32_t p) {
  const uint32_t r = (p >> 0)  & 0xFFu;
  const uint32_t g = (p >> 8)  & 0xFFu;
  const uint32_t b = (p >> 16) & 0xFFu;
  const uint32_t y = (77u * r + 150u * g + 29u * b) >> 8;
  return y & 0xFFu;
}

int main(void) {
  *PERF_START_MMIO = 1u;
  for (uint32_t i = 0; i < NPIX; i++) {
    out_luma32[i] = rgba2luma_scalar_u32(in_pixels[i]);
  }
  *PERF_END_MMIO = 1u;

  // checksum: low 8 bits only, exactly like vector benchmark
  uint32_t sum = 0;
  for (uint32_t i = 0; i < NPIX; i++) sum += (out_luma32[i] & 0xFFu);

  print_str("[rgba2luma_scalar] sum=");
  print_u32_hex(sum);
  print_str("\n");

  *DONE_MMIO = sum;
  for (;;) {}

  return 0;
}
