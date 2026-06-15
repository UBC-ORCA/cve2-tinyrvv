# matmul8 Vector Test Build Instructions

This directory contains the build files for the `matmul8` vector test.

## Building the Test Program

To compile the firmware and generate the Verilog HEX image, run:

```bash
make -f matmul8.mk
```

This command will:

1. Compile and link the source files into:
   - `matmul8_vec.elf`

2. Generate a linker map file:
   - `matmul8.map`

3. Convert the ELF executable into a Verilog-compatible memory image:
   - `matmul8_vec.hex`

## Generated Files

| File | Description |
|--------|-------------|
| `matmul8_vec.elf` | RISC-V executable |
| `matmul8.map` | Linker memory map |
| `matmul8_vec.hex` | Verilog memory initialization file |

## Cleaning Build Artifacts

To remove all generated files, run:

```bash
make -f matmul8.mk clean
```

## Requirements

The following tools must be available in your PATH:

- `riscv32-unknown-elf-gcc`
- `riscv32-unknown-elf-objcopy`

These are typically provided by a RISC-V GCC toolchain installation.

## Source File Locations

The source files used by this build were obtained from the following locations:

### matmul8_vec.S

From:

:contentReference[oaicite:0]{index=0}

### matmul8_vec_test.c

From:

:contentReference[oaicite:1]{index=1}

### matmul8_shared_link.ld

From:

:contentReference[oaicite:2]{index=2}

### start.S and uart.c

From:

:contentReference[oaicite:3]{index=3}
