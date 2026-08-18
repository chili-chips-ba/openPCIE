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

Where the register map comes from is **not** set here - it comes from
[`4.build/config.mk`](../config.mk), which the hardware builds read as well, so
firmware and bitstream always match:

| `CSR` | Register map |
|---|---|
| `peakrdl` (default) | `../csr_build/generated-files/csr.h`, generated from `csr.rdl` |
| `legacy` | addresses hard-coded in `main.c` |

`make CSR=legacy` overrides it for one build. Either way the image is
byte-identical, because both describe the same map. See
[`4.build/README.md`](../README.md#csr-hal-compilation).

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
| `make SIM=1` | short start-up delay, for co-simulation (see below) |
| `make info` | print the resolved configuration |
| `make clean` | remove the three generated files and `.build-config` |

The register map is deliberately **not** in that table -- it is set once in
[`config.mk`](../config.mk), for the firmware and the hardware together, as
described at the top of this file.

Both variants write the same three output names, and `VARIANT`, `CSR` and `SIM`
leave no trace in the sources, so on its own make would compare the same inputs
against the same outputs, report `Nothing to be done`, and leave the **previous**
image in place. The make file records the configuration in `.build-config` and
treats it -- and `../config.mk` -- as prerequisites, so changing any of them
rebuilds by itself. **No `make clean` needed to switch.**

```sh
make                     # direct
make VARIANT=switched    # rebuilds, no clean
make SIM=1               # rebuilds, no clean
```

`make clean` is still the right move when you want to be certain of a from-scratch
build, and it removes `.build-config` along with the three outputs.

## Building for co-simulation

`main()` opens with `wait_cycles(100000)`, which idles while the PCIe link
trains. On hardware that costs nothing. In [co-simulation](../../5.sim) it is
about 80 ms of simulated time before the firmware does anything at all -- the
loop is compiled without optimisation, so each iteration is a dozen bus cycles.

`make SIM=1` defines `STARTUP_DELAY=200` instead, and the whole run then fits in
3 ms of simulated time. Nothing else changes, and the hardware build is
unaffected: without `SIM=1` the delay is the full 100000 as before.

```
make SIM=1          # firmware for the simulator
make                # firmware for the board
```

`SIM=1` matters for the two co-simulation builds that execute this firmware --
`CPU=rtl` and `CPU=iss`. The `CPU=vproc` build does not use it at all: that one
replaces the firmware with a native C++ program, which waits on the CSR instead
of counting instructions, and so pays no start-up delay in the first place.

## Outputs

| File | Used by |
|---|---|
| `firmware.elf` | debugging / `readelf`, `objdump`, **and the rv32 ISS** in co-simulation - `make CPU=iss` in [`5.sim`](../../5.sim/README.md#the-three-cpu-options) loads it directly |
| `firmware.bin` | intermediate, raw image |
| **`firmware.hex`** | **the hardware build** - both Vivado and openXC7, and the RTL core in co-simulation |

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
