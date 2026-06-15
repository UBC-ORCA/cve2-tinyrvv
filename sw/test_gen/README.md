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
