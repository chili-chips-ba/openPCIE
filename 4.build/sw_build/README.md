# firmware build

Builds the firmware for the RISC-V core (eduBOS5 or PicoRV32) inside the opensource RC, in either of
its two variants - `RC-direct.opensource` or `RC-switched.opensource`.

| Stage | Tool | Input -> Output |
|---|---|---|
| 1. Compile + link | `riscv-none-elf-gcc` | `start.S` + `pcie.c` + `main.c` -> `firmware.elf` |
| 2. Raw image | `riscv-none-elf-objcopy` | `.elf` -> `firmware.bin` |
| 3. Hex for `$readmemh` | `python` | `.bin` -> `firmware.hex` |

Sources live in `3.sw/` - this folder only builds them. `3.sw/common/` holds
what both variants share (`start.S`, `sections.lds`, the PCIE request layer
`pcie.c`/`.h`); the variant's own folder adds its `main.c`. All three outputs
land here, next to the Makefile.

| `VARIANT` | `main.c` from | Topology |
|---|---|---|
| `direct` (default) | `3.sw/RC-direct/` | one endpoint, straight RC-to-EP link |
| `switched` | `3.sw/RC-switched/` | ASM1184e switch with up to 4 endpoints |

The register map comes from `../csr_build/generated-files/` (`csr.h`, `csr_top.h`), generated from `csr.rdl`, and the accessors from `../csr_build/csr_regs.h` - see [`4.build/README.md`](../README.md#csr-hal-compilation).

---

## Prerequisites

**RISC-V toolchain.** [xPack GNU RISC-V Embedded GCC](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack),
prefix `riscv-none-elf-`, the `linux-x64` build, unpacked e.g. into `~/opt`.
[`../set-env.sh`](../set-env.sh) finds it and sets `RISCV_PREFIX` to its full
prefix. Override with `make CROSS=riscv64-unknown-elf-` if yours differs.

**Python 3.** Any version; only `struct` is used.

## Building

Run this on Linux or in WSL, like the hardware build:

```sh
cd 4.build
source set-env.sh        # tcsh: source set-env.csh
cd sw_build
make
```

| Target | Purpose |
|---|---|
| `make` | build `firmware.elf`, `firmware.bin`, `firmware.hex` for RC-direct |
| `make VARIANT=switched` | the same three files, but for RC-switched |
| `make SIM=1` | short start-up delay, for co-simulation (see below; `5.sim` does this itself) |
| `make OUT=<dir>` | write the three files to `<dir>` instead of this folder |
| `make info` | print the resolved configuration |
| `make clean` | remove the three generated files |

**Every `make` rebuilds the firmware from scratch** - it takes about a second.
Both variants write the same three output names, and `VARIANT` and `SIM`
leave no trace in the sources, so a date-based make would compare the same
inputs against the same outputs, report `Nothing to be done`, and leave the
**previous** image in place. File dates cannot be trusted either: a tree on a
network share, or copied off one, can carry timestamps from the future, which
make a stale `firmware.hex` look up to date. Always rebuilding sidesteps both.
**No `make clean` needed, ever.**

```sh
make                     # direct
make VARIANT=switched    # switched
make SIM=1               # direct, short start-up delay (5.sim builds this itself)
```

## Building for co-simulation

`main()` opens with `wait_cycles(STARTUP_DELAY)` - 100000 by default, set in
`3.sw/common/pcie.h` - which idles while the PCIE link
trains. On hardware that costs nothing. In [co-simulation](../../5.sim) it is
tens of milliseconds of simulated time before the firmware does anything at all
(about 37 ms on eduBOS5) -- the loop is compiled without optimisation, so each
iteration is seven instructions.

`make SIM=1` defines `STARTUP_DELAY=200` instead, and the whole run then fits in
under 0.7 ms of simulated time (0.4 ms on eduBOS5, 0.68 ms on PicoRV32). Nothing else changes, and the hardware build is
unaffected: without `SIM=1` the delay is the full 100000 as before.

You do not run it by hand: `make` in [`5.sim`](../../5.sim) builds its own copy, on every build, with `make SIM=1 OUT=5.sim/obj/fw`. The `firmware.hex` tracked in this folder is therefore always the board build.

`SIM=1` matters for the two co-simulation builds that execute this image --
`CPU=rtl` and `CPU=iss`. The `CPU=vproc` build compiles the same sources for
the host instead, where the start-up loop takes no simulated time at all.

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

`-march=rv32i -mabi=ilp32` only: eduBOS5 is RV32I, and PicoRV32 here is configured
without the M and C extensions. `-ffreestanding -nostdlib` because there is no libc and no crt0 -
`start.S` provides the reset vector, so it must stay first on the command line.

`firmware.elf` differs on every rebuild even when nothing changed. gcc embeds a
randomly named temporary object file for the `start.S` assembly pass, and that
name lands in the symbol table. `firmware.bin` and `firmware.hex` are stable, and
those are what matter.

-----------
#### End-of-Document
