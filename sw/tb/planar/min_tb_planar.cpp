#include "Vcve2_top.h"
#include "verilated.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

#ifndef DONE_MMIO_ADDR
#define DONE_MMIO_ADDR 0xFFFF0000u
#endif

#ifndef PERF_START_MMIO_ADDR
#define PERF_START_MMIO_ADDR 0xFFFF0004u
#endif

#ifndef PERF_END_MMIO_ADDR
#define PERF_END_MMIO_ADDR 0xFFFF0008u
#endif

#ifndef UART_MMIO_ADDR
#define UART_MMIO_ADDR 0x10000000u
#endif

static vluint64_t main_time = 0;
double sc_time_stamp() { return static_cast<double>(main_time); }

// -----------------------------
// Address map (single low-memory map for this benchmark)
// -----------------------------
static constexpr uint32_t IMEM_BASE = 0x00000000u;
static constexpr uint32_t DMEM_BASE = 0x00000000u;

// Must match the planar linker script sections.
static constexpr uint32_t PLANAR_NPIX   = 1000000u;
static constexpr uint32_t PLANAR_NWORDS = PLANAR_NPIX / 4u;
static constexpr uint32_t VLMAX_WORDS   = 8u;
static constexpr uint32_t IN_R_ADDR     = 0x00100000u;
static constexpr uint32_t IN_G_ADDR     = 0x00500000u;
static constexpr uint32_t IN_B_ADDR     = 0x00900000u;
static constexpr uint32_t OUT_Y_ADDR    = 0x00D00000u;

static constexpr uint32_t IMEM_BYTES = 32 * 1024 * 1024;
static constexpr uint32_t DMEM_BYTES = 32 * 1024 * 1024;
static std::vector<uint8_t> imem(IMEM_BYTES, 0);
static std::vector<uint8_t> dmem(DMEM_BYTES, 0);
static std::vector<uint32_t> golden_luma(PLANAR_NPIX, 0);
static uint32_t golden_sum = 0;

static inline bool imem_translate(uint32_t addr, uint32_t& off) {
  if (addr >= IMEM_BASE && addr < (IMEM_BASE + IMEM_BYTES)) {
    off = addr - IMEM_BASE;
    return true;
  }
  return false;
}

static inline bool dmem_translate(uint32_t addr, uint32_t& off) {
  if (addr >= DMEM_BASE && addr < (DMEM_BASE + DMEM_BYTES)) {
    off = addr - DMEM_BASE;
    return true;
  }
  return false;
}

static inline uint32_t load_le_u32(const std::vector<uint8_t>& mem, uint32_t off) {
  if (off + 3u >= mem.size()) return 0;
  return (uint32_t)mem[off + 0u] |
         ((uint32_t)mem[off + 1u] << 8) |
         ((uint32_t)mem[off + 2u] << 16) |
         ((uint32_t)mem[off + 3u] << 24);
}

static inline void store_le_u32(std::vector<uint8_t>& mem, uint32_t off, uint32_t wdata, uint8_t be) {
  if (off + 3u >= mem.size()) return;
  for (int i = 0; i < 4; i++) {
    if (be & (1u << i)) mem[off + (uint32_t)i] = (uint8_t)((wdata >> (8 * i)) & 0xFFu);
  }
}

static inline uint32_t data_load_u32(uint32_t addr) {
  uint32_t off = 0;
  if (addr < IMEM_BYTES && imem_translate(addr, off)) return load_le_u32(imem, off);
  if (dmem_translate(addr, off)) return load_le_u32(dmem, off);
  return 0;
}

static inline void data_store_u32(uint32_t addr, uint32_t wdata, uint8_t be) {
  uint32_t off = 0;
  if (addr < IMEM_BYTES && imem_translate(addr, off)) {
    store_le_u32(imem, off, wdata, be);
    return;
  }
  if (dmem_translate(addr, off)) store_le_u32(dmem, off, wdata, be);
}

static uint32_t next_lcg(uint32_t& state) {
  state = state * 1664525u + 1013904223u;
  return state;
}

static inline uint32_t rgb2luma_ref(uint32_t r, uint32_t g, uint32_t b) {
  r &= 0xFFu;
  g &= 0xFFu;
  b &= 0xFFu;
  return ((77u * r + 150u * g + 29u * b) >> 8) & 0xFFu;
}

static void preload_planar_packed_inputs(void) {
  uint32_t state = 0x6c8e9cf5u;
  golden_sum = 0;

  // Fill all output words with zero before the benchmark runs.
  for (uint32_t i = 0; i < PLANAR_NPIX; ++i) {
    data_store_u32(OUT_Y_ADDR + 4u * i, 0u, 0xFu);
  }

  // Preload packed R/G/B planes.  Each 32-bit word holds four 8-bit samples.
  for (uint32_t w = 0; w < PLANAR_NWORDS; ++w) {
    uint32_t rp = 0u;
    uint32_t gp = 0u;
    uint32_t bp = 0u;

    for (uint32_t byte = 0; byte < 4u; ++byte) {
      const uint32_t rnd = next_lcg(state);
      const uint32_t r = (rnd >>  0) & 0xFFu;
      const uint32_t g = (rnd >>  8) & 0xFFu;
      const uint32_t b = (rnd >> 16) & 0xFFu;
      rp |= r << (8u * byte);
      gp |= g << (8u * byte);
      bp |= b << (8u * byte);
    }

    data_store_u32(IN_R_ADDR + 4u * w, rp, 0xFu);
    data_store_u32(IN_G_ADDR + 4u * w, gp, 0xFu);
    data_store_u32(IN_B_ADDR + 4u * w, bp, 0xFu);
  }

  // Build the expected output in the same stripmine layout used by the vector assembly:
  // for each chunk of up to 8 packed words, byte0 lanes, then byte1, byte2, byte3.
  uint32_t out_idx = 0u;
  for (uint32_t base = 0u; base < PLANAR_NWORDS; base += VLMAX_WORDS) {
    const uint32_t vl = std::min(VLMAX_WORDS, PLANAR_NWORDS - base);
    for (uint32_t byte = 0u; byte < 4u; ++byte) {
      const uint32_t sh = 8u * byte;
      for (uint32_t lane = 0u; lane < vl; ++lane) {
        const uint32_t rp = data_load_u32(IN_R_ADDR + 4u * (base + lane));
        const uint32_t gp = data_load_u32(IN_G_ADDR + 4u * (base + lane));
        const uint32_t bp = data_load_u32(IN_B_ADDR + 4u * (base + lane));
        const uint32_t y = rgb2luma_ref(rp >> sh, gp >> sh, bp >> sh);
        golden_luma[out_idx++] = y;
        golden_sum += y;
      }
    }
  }

  std::cout << "[TB] Preloaded packed-planar pseudo-random RGB inputs: NPIX=" << PLANAR_NPIX
            << " NWORDS=" << PLANAR_NWORDS
            << " R@0x" << std::hex << std::setw(8) << std::setfill('0') << IN_R_ADDR
            << " G@0x" << std::setw(8) << IN_G_ADDR
            << " B@0x" << std::setw(8) << IN_B_ADDR
            << " OUT@0x" << std::setw(8) << OUT_Y_ADDR
            << " golden_sum=0x" << std::setw(8) << golden_sum
            << std::dec << "\n";
}

static void check_planar_packed_outputs(uint32_t done_value) {
  bool ok = true;
  uint32_t got_sum = 0u;
  uint32_t mismatches = 0u;

  for (uint32_t i = 0; i < PLANAR_NPIX; ++i) {
    const uint32_t got = data_load_u32(OUT_Y_ADDR + 4u * i) & 0xFFu;
    got_sum += got;
    if (got != golden_luma[i]) {
      ok = false;
      if (mismatches < 16u) {
        std::printf("[TB] MISMATCH Y[%u]: got=0x%08x exp=0x%08x\n", i, got, golden_luma[i]);
      }
      ++mismatches;
    }
  }

  if (mismatches > 16u) {
    std::printf("[TB] ... plus %u additional mismatches\n", mismatches - 16u);
  }
  if (done_value != golden_sum) {
    ok = false;
    std::printf("[TB] DONE mismatch: got=0x%08x exp=0x%08x\n", done_value, golden_sum);
  }
  if (got_sum != golden_sum) {
    ok = false;
    std::printf("[TB] checksum mismatch from output memory: got=0x%08x exp=0x%08x\n", got_sum, golden_sum);
  }

  std::cout << (ok ? "[TB] planar packed rgba2luma output check PASS\n"
                   : "[TB] planar packed rgba2luma output check FAIL\n");
}

static size_t load_objcopy_verilog_hex_bytes(const std::string& path,
                                             std::vector<uint8_t>& imem,
                                             std::vector<uint8_t>& dmem) {
  std::ifstream f(path);
  if (!f) return 0;

  std::string tok;
  uint32_t addr = 0;
  size_t written = 0;
  enum class Target { IMEM, DMEM, NONE } tgt = Target::IMEM;

  auto hex_to_u32 = [](const std::string& s) -> uint32_t {
    return (uint32_t)std::strtoul(s.c_str(), nullptr, 16);
  };

  while (f >> tok) {
    if (tok.empty()) continue;

    if (tok[0] == '@') {
      addr = hex_to_u32(tok.substr(1));
      uint32_t off = 0;
      if (imem_translate(addr, off)) { tgt = Target::IMEM; addr = off; }
      else if (dmem_translate(addr, off)) { tgt = Target::DMEM; addr = off; }
      else { tgt = Target::NONE; }
      continue;
    }

    uint32_t b = hex_to_u32(tok) & 0xFFu;
    if (tgt == Target::IMEM) {
      if (addr < imem.size()) { imem[addr] = (uint8_t)b; written++; }
    } else if (tgt == Target::DMEM) {
      if (addr < dmem.size()) { dmem[addr] = (uint8_t)b; written++; }
    }
    addr++;
  }

  return written;
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  if (argc < 2) {
    std::cerr << "Usage: " << argv[0]
              << " <prog.hex> [--max-cycles N] [--print-every N] [--trace-if] [--trace-d]\n";
    return 1;
  }

  std::string hex_path = argv[1];
  uint64_t max_cycles = 20000000;
  uint64_t print_every = 1000000;
  bool trace_if = false;
  bool trace_d = false;

  for (int i = 2; i < argc; i++) {
    std::string a = argv[i];
    if (a == "--max-cycles" && (i + 1) < argc) {
      max_cycles = std::stoull(argv[++i]);
    } else if (a == "--print-every" && (i + 1) < argc) {
      print_every = std::stoull(argv[++i]);
    } else if (a == "--trace-if") {
      trace_if = true;
    } else if (a == "--trace-d") {
      trace_d = true;
    } else {
      std::cerr << "Unknown arg: " << a << "\n";
      return 1;
    }
  }

  imem.assign(IMEM_BYTES, 0);
  dmem.assign(DMEM_BYTES, 0);
  size_t loaded = load_objcopy_verilog_hex_bytes(hex_path, imem, dmem);
  std::cout << "[TB] Loaded " << hex_path << " into memory (bytes=" << loaded << ")\n";
  preload_planar_packed_inputs();

  Vcve2_top* dut = new Vcve2_top();

  dut->clk_i = 0;
  dut->rst_ni = 0;
  dut->fetch_enable_i = 0;
  dut->hart_id_i = 0;
  dut->boot_addr_i = 0x00000000;

  dut->instr_gnt_i = 0;
  dut->instr_rvalid_i = 0;
  dut->instr_rdata_i = 0;
  dut->instr_err_i = 0;

  dut->data_gnt_i = 0;
  dut->data_rvalid_i = 0;
  dut->data_rdata_i = 0;
  dut->data_err_i = 0;

  for (int i = 0; i < 10; i++) {
    dut->clk_i = 0; dut->eval(); main_time++;
    dut->clk_i = 1; dut->eval(); main_time++;
  }
  dut->rst_ni = 1;
  for (int i = 0; i < 5; i++) {
    dut->clk_i = 0; dut->eval(); main_time++;
    dut->clk_i = 1; dut->eval(); main_time++;
  }
  dut->fetch_enable_i = 1;
  std::cout << "[TB] Reset released, fetch_enable_i=1, starting simulation loop...\n";

  bool if_resp_due = false;
  uint32_t if_resp_addr = 0;

  bool d_resp_due = false;
  uint32_t d_resp_addr = 0;
  bool d_resp_is_write = false;

  uint64_t uart_chars = 0;
  bool done_seen = false;
  uint32_t done_value = 0;
  uint64_t done_cycle = 0;
  bool perf_start_seen = false;
  bool perf_end_seen = false;
  uint64_t perf_start_cycle = 0;
  uint64_t perf_end_cycle = 0;

  for (uint64_t cyc = 0; cyc < max_cycles; cyc++) {
    dut->clk_i = 0;

    dut->instr_rvalid_i = if_resp_due ? 1 : 0;
    dut->instr_err_i = 0;
    uint32_t if_insn = 0;
    if (if_resp_due) {
      uint32_t off = 0;
      if (imem_translate(if_resp_addr, off)) if_insn = load_le_u32(imem, off);
      dut->instr_rdata_i = if_insn;
    } else {
      dut->instr_rdata_i = 0;
    }

    dut->data_rvalid_i = d_resp_due ? 1 : 0;
    dut->data_err_i = 0;
    uint32_t d_rdata = 0;
    if (d_resp_due) {
      d_rdata = d_resp_is_write ? 0 : data_load_u32(d_resp_addr);
      dut->data_rdata_i = d_rdata;
    } else {
      dut->data_rdata_i = 0;
    }

    dut->instr_gnt_i = (if_resp_due ? 0 : 1);
    dut->data_gnt_i  = (d_resp_due  ? 0 : 1);

    dut->eval();
    main_time++;

    if (trace_if && if_resp_due) {
      std::cout << "[IF] resp pc=0x" << std::hex << std::setw(8) << std::setfill('0')
                << if_resp_addr << " insn=0x" << std::setw(8) << if_insn << std::dec << "\n";
    }
    if (trace_d && d_resp_due) {
      std::cout << "[D ] resp  addr=0x" << std::hex << std::setw(8) << std::setfill('0')
                << d_resp_addr << " (" << (d_resp_is_write ? "WR" : "RD") << ") rdata=0x"
                << std::setw(8) << d_rdata << std::dec << "\n";
    }

    const bool if_fire = (dut->instr_req_o && dut->instr_gnt_i);
    const bool d_fire  = (dut->data_req_o  && dut->data_gnt_i);

    bool if_resp_due_next = false;
    uint32_t if_resp_addr_next = 0;
    bool d_resp_due_next = false;
    uint32_t d_resp_addr_next = 0;
    bool d_resp_is_write_next = false;

    if (if_fire) {
      if_resp_due_next = true;
      if_resp_addr_next = (uint32_t)dut->instr_addr_o;
      if (trace_if) {
        std::cout << "[IF] accept pc=0x" << std::hex << std::setw(8) << std::setfill('0')
                  << if_resp_addr_next << std::dec << "\n";
      }
    }

    if (d_fire) {
      const uint32_t addr = (uint32_t)dut->data_addr_o;
      const bool we = dut->data_we_o ? true : false;
      const uint32_t wdata = (uint32_t)dut->data_wdata_o;
      const uint8_t be = (uint8_t)dut->data_be_o;

      if (we) {
        if (addr == UART_MMIO_ADDR) {
          char c = (char)(wdata & 0xFFu);
          std::cout << c << std::flush;
          uart_chars++;
        } else if (addr == PERF_START_MMIO_ADDR) {
          perf_start_seen = true;
          perf_start_cycle = cyc;
        } else if (addr == PERF_END_MMIO_ADDR) {
          perf_end_seen = true;
          perf_end_cycle = cyc;
        } else if (addr == DONE_MMIO_ADDR) {
          done_seen = true;
          done_value = wdata;
          done_cycle = cyc;
        } else {
          data_store_u32(addr, wdata, be);
        }
      }

      d_resp_due_next = true;
      d_resp_addr_next = addr;
      d_resp_is_write_next = we;

      if (trace_d) {
        std::cout << "[D ] accept addr=0x" << std::hex << std::setw(8) << std::setfill('0')
                  << addr << " (" << (we ? "WR" : "RD") << ") wdata=0x" << std::setw(8) << wdata
                  << " be=0x" << std::setw(2) << (uint32_t)be << std::dec << "\n";
      }
    }

    if (print_every != 0 && ((cyc % print_every) == 0)) {
      std::cout << "[TB] cyc=" << std::dec << cyc
                << " instr_req=" << (int)dut->instr_req_o
                << " instr_addr=0x" << std::hex << std::setw(8) << std::setfill('0') << (uint32_t)dut->instr_addr_o
                << " instr_gnt=" << std::dec << (int)dut->instr_gnt_i
                << " instr_rvalid=" << (int)dut->instr_rvalid_i
                << " data_req=" << (int)dut->data_req_o
                << " data_we=" << (int)dut->data_we_o
                << " data_addr=0x" << std::hex << std::setw(8) << std::setfill('0') << (uint32_t)dut->data_addr_o
                << " data_gnt=" << std::dec << (int)dut->data_gnt_i
                << " data_rvalid=" << (int)dut->data_rvalid_i
                << " sleep=" << (int)dut->core_sleep_o
                << " uart_chars=" << uart_chars
                << std::dec << "\n";
    }

    dut->clk_i = 1;
    dut->eval();
    main_time++;

    if_resp_due = if_resp_due_next;
    if_resp_addr = if_resp_addr_next;
    d_resp_due = d_resp_due_next;
    d_resp_addr = d_resp_addr_next;
    d_resp_is_write = d_resp_is_write_next;

    if (done_seen && (cyc > (done_cycle + 4))) {
      std::cout << "[TB] DONE seen (addr=0x" << std::hex << DONE_MMIO_ADDR
                << ") value=0x" << std::setw(8) << std::setfill('0') << done_value
                << std::dec << " at cyc=" << done_cycle << "\n";
      break;
    }
  }

  if (perf_start_seen) std::cout << "[TB] PERF_START seen at cyc=" << perf_start_cycle << "\n";
  if (perf_end_seen) std::cout << "[TB] PERF_END   seen at cyc=" << perf_end_cycle << "\n";
  if (perf_start_seen && perf_end_seen && perf_end_cycle >= perf_start_cycle) {
    std::cout << "[TB] KERNEL_CYCLES=" << (perf_end_cycle - perf_start_cycle) << "\n";
  }

  if (done_seen) {
    check_planar_packed_outputs(done_value);
  } else {
    std::cout << "[TB] ERROR: DONE was not observed before max_cycles\n";
  }

  std::cout << "[TB] Finished\n";
  dut->final();
  delete dut;
  return done_seen ? 0 : 1;
}
