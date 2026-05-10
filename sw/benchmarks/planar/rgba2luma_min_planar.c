#include <stdint.h>

extern void putchar_uart(char c);

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

#define NPIX       1000000u
#define NWORDS     (NPIX / 4u)
#define VLMAX_WORDS 8u

/*
 * These objects are intentionally volatile and placed in fixed linker sections.
 * The Verilator testbench preloads the sections with deterministic pseudo-random
 * packed-planar data before reset release.  Do not initialize these arrays in C:
 * doing so can let the compiler reason about the inputs and optimize the real
 * benchmark work away.
 */
static volatile uint32_t in_r_packed[NWORDS]
    __attribute__((section(".in_r"), used));
static volatile uint32_t in_g_packed[NWORDS]
    __attribute__((section(".in_g"), used));
static volatile uint32_t in_b_packed[NWORDS]
    __attribute__((section(".in_b"), used));
static volatile uint32_t out_luma32[NPIX]
    __attribute__((section(".out_luma32"), used));

static inline uint32_t rgb2luma_scalar_u32(uint32_t r, uint32_t g, uint32_t b) {
  r &= 0xFFu;
  g &= 0xFFu;
  b &= 0xFFu;
  return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
}

int main(void) {
  *PERF_START_MMIO = 1u;

  /*
   * Match rgba2luma_vec_planar_packed_loop's output layout exactly.
   * For each stripmine chunk of up to 8 packed words, the vector code writes:
   *   byte0 lumas for all lanes, then byte1, then byte2, then byte3.
   *
   * Keep the scalar baseline fair by loading each packed source word once, then
   * immediately computing its four byte results.  The four byte operations are
   * manually unrolled so the compiler does not need to reload rp/gp/bp across
   * a byte-major inner loop.  Stores still use byte-major offsets so the output
   * layout remains identical to the vector benchmark.
   */
  uint32_t out_base = 0u;
  for (uint32_t base = 0u; base < NWORDS; base += VLMAX_WORDS) {
    const uint32_t vl = ((NWORDS - base) < VLMAX_WORDS) ? (NWORDS - base) : VLMAX_WORDS;

    for (uint32_t lane = 0u; lane < vl; ++lane) {
      const uint32_t r = in_r_packed[base + lane];
      const uint32_t g = in_g_packed[base + lane];
      const uint32_t b = in_b_packed[base + lane];

      out_luma32[out_base + lane]          = rgb2luma_scalar_u32(r,        g,        b);
      out_luma32[out_base + vl + lane]     = rgb2luma_scalar_u32(r >> 8,   g >> 8,   b >> 8);
      out_luma32[out_base + 2u * vl + lane] = rgb2luma_scalar_u32(r >> 16,  g >> 16,  b >> 16);
      out_luma32[out_base + 3u * vl + lane] = rgb2luma_scalar_u32(r >> 24,  g >> 24,  b >> 24);
    }

    out_base += 4u * vl;
  }

  *PERF_END_MMIO = 1u;

  uint32_t sum = 0u;
  for (uint32_t i = 0u; i < NPIX; ++i) {
    sum += out_luma32[i] & 0xFFu;
  }

  print_str("[rgb2luma_scalar_planar_packed] sum=");
  print_u32_hex(sum);
  print_str("\n");

  *DONE_MMIO = sum;
  for (;;) {}
  return 0;
}
