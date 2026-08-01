# firmware build

Builds the firmware for the picorv32 core inside the opensource RC, in either of
its two variants - `RC-direct.opensource` or `RC-switched.opensource`.

| Stage | Tool | Input -> Output |
|---|---|---|
| 1. Compile + link | `riscv-none-elf-gcc` | `start.S` + `main.c` -> `firmware.elf` |
| 2. Raw image | `riscv-none-elf-objcopy` | `.elf` -> `firmware.bin` |
| 3. Hex for `$readmemh` | `python` | `.bin` -> `firmware.hex` |

Sources live in `3.sw/`, one subdirectory per variant - this folder only builds
them. All three outputs land here, next to the Makefile.

| `VARIANT` | Sources | Topology |
|---|---|---|
| `direct` (default) | `3.sw/RC-direct/` | one endpoint, straight RC-to-EP link |
| `switched` | `3.sw/RC-switched/` | ASM1184e switch with up to 4 endpoints |

---

## Prerequisites

**RISC-V toolchain.** [xPack GNU RISC-V Embedded GCC](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack),
prefix `riscv-none-elf-`. Override with `make CROSS=riscv64-unknown-elf-` if yours
differs.

**Python 3.** Any version; only `struct` is used.

## Building

**Run this on Windows** (`cmd` or PowerShell), not in WSL - the toolchain is a
Windows program:

```
cd 4.build\sw_build
make
```

> The two builds live on different sides: `hw_build.openXC7` runs **in WSL**
> because yosys/nextpnr/prjxray are Linux tools, while this one runs **on Windows**
> because the RISC-V toolchain and Python are Windows programs.

| Target | Purpose |
|---|---|
| `make` | build `firmware.elf`, `firmware.bin`, `firmware.hex` for RC-direct |
| `make VARIANT=switched` | the same three files, but for RC-switched |
| `make info` | print the resolved configuration |
| `make clean` | remove the three generated files |

Both variants write the same three output names, so switching between them needs
a `make clean` first - otherwise make sees the outputs as up to date and does
nothing.

## Outputs

| File | Used by |
|---|---|
| `firmware.elf` | debugging / `readelf`, `objdump` |
| `firmware.bin` | intermediate, raw image |
| **`firmware.hex`** | **the hardware build** - both Vivado and openXC7 |

`riscv_pcie_soc.sv` initialises its RAM with `$readmemh("firmware.hex", ram)`, so
the file must be one 32-bit little-endian word per line, 8 hex digits, no `0x`
prefix. That is exactly what step 3 emits.

Run this build **before** either hardware build - `firmware.hex` is a hard
dependency of both.

## Notes

`-march=rv32i -mabi=ilp32` only: picorv32 here is configured without the M and C
extensions. `-ffreestanding -nostdlib` because there is no libc and no crt0 -
`start.S` provides the reset vector, so it must stay first on the command line.

`firmware.elf` differs on every rebuild even when nothing changed. gcc embeds a
randomly named temporary object file for the `start.S` assembly pass, and that
name lands in the symbol table. `firmware.bin` and `firmware.hex` are stable, and
those are what matter.

-----------
#### End-of-Document
