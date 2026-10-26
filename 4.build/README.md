# _openPCIE_ Build

The build process for the _openPCIE_ project consists of three steps:
- Compilation of the control and status registers (CSR) from their RDL
  specification into RTL for the hardware design and a hardware abstraction
  layer (HAL) for the software application
- Compilation of the software application for the RISC-V hardware target
- Compilation of SystemVerilog designs into a bitstream for the hardware target

Each step has its own `Makefile`; the SW and HW steps also have their own
directory and `README.md`. Run them in order - the software can pick up the
generated HAL, and the hardware build embeds the firmware image into the
bitstream.

## Build environment

Linux-native tools throughout; WSL works too. The one exception is WaveCrux, which we run on Windows: GUI apps are smoother there, thanks to better GPU drivers.

First, in this folder:

```sh
source set-env.sh       # bash, zsh
source set-env.csh      # tcsh, csh
```

[`set-env.sh`](./set-env.sh) finds each tool, checks it against the table below,
and exports it in the variable the Makefiles use (`YOSYS`, `RISCV_PREFIX`,
`PEAKRDL`, ...). It lists what is missing or too old and how to install it.
Windows `.exe` files on `PATH` count as missing.

- Report only: `bash set-env.sh`
- Pin a tool: `export YOSYS=/path/to/yosys` before sourcing, or `make YOSYS=...`
- Search roots: `OPENXC7_ROOT`, `XILINX_VIVADO`, `RISCV_ROOT`; else `~/opt`, `/opt`, `/tools/Xilinx`, `~/Xilinx`

| Step | Makefile / Directory | Produces |
|---|---|---|
| 1. CSR | [`MakefileCSR`](./MakefileCSR) | `csr_build/generated-files/` - `csr.sv`, `csr_pkg.sv`, `csr.h` |
| 2. SW | [`sw_build`](./sw_build) | `firmware.elf`, `firmware.bin`, `firmware.hex` |
| 3. HW | [`hw_build.openXC7`](./hw_build.openXC7) | `build_artifacts/top.x4g1.direct.bit` |

<p align="center"><img src="../0.doc/4.build/build-flow.drawio.png" width="100%" alt="Build flow: csr.rdl through PeakRDL into the register RTL and the firmware and co-sim headers; the firmware build into firmware.hex; the bitstream build through Vivado or openXC7 (slang or sv2v, yosys, nextpnr, fasm2frames and xc7frames2bit) into top.bit for the Acorn CLE-215+; co-simulation, lint and the formal equivalence check alongside"></p>

The diagram source is [`0.doc/4.build/build-flow.drawio`](../0.doc/4.build/build-flow.drawio).

## Tool versions

The versions the build was validated with. "Board" means the bitstream was tested on hardware; "builds" means it completes, but has not been on the board yet.

| Tool | Version | Used for | Status |
|---|---|---|---|
| openXC7 v1.0.0 (1) | Yosys 0.69, nextpnr 3e5c2cdd | bitstream, default (`read_slang`) | builds, x4 and x1 |
| openXC7 pre-v1.0.0 (2) | Yosys 0.38, nextpnr-xilinx 45a986b | `build_artifacts/pre-v1.0.0/`, flow removed after `54c5409` | board, x1 |
| sv2v | v0.0.13 | `FRONTEND=sv2v` | builds |
| AMD Vivado | 2026.1 | co-sim (`xsim`), `run-lint.sh` CDC phase, implementation | runs, checks |
| PeakRDL | 1.5.0 (3) | CSR RTL, headers, docs | generates |
| xPack RISC-V GCC | 15.2.0-1 | firmware | board |
| GCC, host | 10+ (4) | co-sim (VProc, pcievhost) | runs |
| Verilator | 5.052 | `run-lint.sh` | checks |
| Verible | v0.0-4296-g0f262651 | `run-format.sh`, `run-lint.sh` | formats, checks |
| ABC (`yosys-abc`) | 1.01, in openXC7's Yosys 0.69 | formal: eduBOS5 multicycle proof (`pdr`), bounded runs (`bmc3`) | proves |
| SymbiYosys (`sby`) | v0.69 | formal: riscv-formal on eduBOS5, with ABC `bmc3` | checks |
| Z3 | 5.3.1 (pip `z3-solver`) | formal: replays a riscv-formal failure | runs |
| WaveCrux Pro | 1.1.1 | waveforms, RISC-V decoding (built in) | runs |
| Ferrite wavecrux-decoders | pcie-v0.2.0, pcie-tlp-v0.1.0 (5) | PIPE, DLL and TLP decoding in WaveCrux | runs |
| Python | 3.12 | build scripts | runs |
| openFPGALoader | 1.1.1 | loading the bitstream over JTAG | not yet used on the board |
| usbipd-win | 5.3.0 | JTAG cable into WSL (Windows side) | not yet used on the board |
| usbutils (`lsusb`) | 017 | checking the cable in WSL | runs |

1. Yosys 0.69 (9f75ca1f9), nextpnr-himbaechel 1.0.0-41-g3e5c2cdd, fpga-as
2. Yosys, nextpnr-xilinx, prjxray
3. regblock 1.3.1, html 2.12.2, markdown 1.0.3, c-header 1.1.0; systemrdl-compiler 1.33.0
4. C++20; validated with 15.2.0
5. `pcie-tlp` is our TLP plugin, contributed to Ferrite's wavecrux-decoders

## CSR HAL Compilation

The CSR RTL and the firmware's register header come from one SystemRDL file,
`csr_build/csr.rdl`, through `peakrdl`. `make -f MakefileCSR` writes, to
`4.build/csr_build/generated-files`:

  * `csr.sv`      : the CSR RTL
  * `csr_pkg.sv`  : its `hwif_in` / `hwif_out` struct package
  * `csr.h`       : `peakrdl c-header` output: the register structs, field masks and positions
  * `csr_top.h`   : `CSR_TOP_T`, the address map's struct in `csr.h`
  * `openpcie.md` : the register map as markdown
  * `html/`       : the register map as a browsable HTML document

These files are checked in. An ordinary build never runs this step; only an edit
of `csr_build/csr.rdl` calls for it. Regeneration gives the same files, except
for the build timestamp in `html/index.html`. `make -f MakefileCSR tools` shows
which `peakrdl` was picked up.

The firmware includes [`csr_regs.h`](csr_build/csr_regs.h), next to `csr.rdl`,
the same file in openPCIE, openCologne-PCIE and WireGuard-FPGA. It takes the
layout and the CSR base address from `csr.h` and gives the accessors, for the
RISC-V cores and the co-simulation alike: `CSR_REG32()` for a whole register,
`CSR_GET()`, `CSR_SET()` and `CSR_RMW()` for one field:

```c
    PCIE_TX_HEADER0 = h0;                 // CSR_REG32(tx.header0)
    uint32_t hdr    = PCIE_RX_HEADER_INFO;
    uint8_t  tag    = RDL_FIELD(hdr, CSR__RX__HEADER_INFO__TAG);
```

With `make CPU=vproc` in [5.sim](../5.sim/README.md#the-three-cpu-options), the
same firmware is compiled for the host, and `CSR_REG32()` becomes a *VProc* read
or write on the same CPU bus. One firmware source, one register map.

On a RISC-V core, `CSR_REG32()` takes the register's address out of the generated struct
(`CSR_ADDR()`) and then performs one aligned 32-bit access at that address. Do
**not** dereference through the struct itself: `peakrdl c-header` marks every
struct `__attribute__((packed))`, which tells the compiler the members may be
unaligned, and on a target with no unaligned load/store -- rv32i, for one -- a
single register access then compiles into four byte accesses:

```
    lbu a4,12(a5)   /   sb a4,12(a5)   /   lbu a4,13(a5)   ...
```

That is wrong for a CSR: it writes a register in four bites. Here the write
strobe of `tx.data` starts a TLP transfer. So the packet leaves after the first
byte, with the other three not yet written. The compiler folds the bytes back
into a word only at `-O2` and above, and the firmware is built without
optimisation. On x86, where unaligned access is free, you never see it. It took
a run on the real ISA.

### The register map

`csr.rdl` describes the TLP transmit/receive window that the RISC-V firmware
uses in place of the AMD-proprietary hardware FSM. It sits at `0x3000_0000` in
the SOC address map:

| Offset | Register | Access | Meaning |
|---|---|---|---|
| `0x00` | `tx.header0` | W | TLP header DW0 - Fmt/Type, TC, attributes, Length |
| `0x04` | `tx.header1` | W | TLP header DW1 - Requester ID, Tag, byte enables |
| `0x08` | `tx.header2` | W | TLP header DW2 - address, or Bus/Device/Function |
| `0x0C` | `tx.data` | W | Payload DWORD - **writing it starts the transfer** |
| `0x10` | `rx.status` | R | Completion Status of the last Completion TLP |
| `0x14` | `rx.data` | R | Payload DWORD of the last Completion TLP |
| `0x18` | `rx.header_info` | R | `requester_id`, `tag`, `lower_addr` |
| `0x1C` | `status.err` | R | fatal-error message flag |
| `0x20` | `status.phy` | R | Tx FSM state + free hard-macro Tx buffers |
| `0x24` | `status.result` | RW | firmware result marker (`0x0000FACE` = PASS); sends nothing, drives the PASS LED |

The send trigger is the `swmod` strobe PeakRDL raises on `tx.data`: the
firmware writes the payload last.

The [co-simulation](../5.sim) runs the real firmware against a PCIE endpoint
model on this register block and ends with the memory read-back check passing.

## SW Compilation

Sources are in [`3.sw`](../3.sw): what both RC variants share in
[`common`](../3.sw/common) (`start.S`, `sections.lds`, the PCIE request layer
`pcie.c`/`.h`), and one `main.c` per variant in [`RC-direct`](../3.sw/RC-direct)
and [`RC-switched`](../3.sw/RC-switched). This step only builds them. A Makefile is
provided as `4.build/sw_build/Makefile`. Running `make` in that directory
produces the following files in `4.build/sw_build`:

  * `firmware.elf`  : The ELF file for the RISC-V hardware target
  * `firmware.bin`  : The raw binary image
  * `firmware.hex`  : The HEX programming file for the RISC-V hardware target

`firmware.hex` is the one the hardware build consumes - `riscv_pcie_soc.sv`
initialises its instruction memory with `$readmemh("firmware.hex", ram)`, so the
file is one 32-bit little-endian word per line, 8 hex digits, no `0x` prefix.

The toolchain is xPack GNU RISC-V Embedded GCC (`riscv-none-elf-` prefix), built
for `rv32i` only: eduBOS5 is RV32I, and PicoRV32 here is configured without the M and C extensions.

`make` builds the RC-direct firmware. For the switched topology:

```
make VARIANT=switched
```

Both variants write the same three file names. But every `make` rebuilds the
firmware (about a second), so switching needs no `make clean`.

The firmware takes its register map from the headers generated in step 1.

This step runs on Linux or WSL, like the others, with the Linux build of the
xPack toolchain; `set-env.sh` finds it and passes its full prefix in
`RISCV_PREFIX`.

See [`sw_build/README.md`](./sw_build/README.md) for details.

## HW Compilation

Two independent flows target the same device, `xc7a200tfbg484-3` on the Acorn
CLE-215P.

### Proprietary AMD flow

Hardware synthesis for the AMD project branch is supported through the Vivado GUI,
using the prepared project files in each of the corresponding design directories,
which are all located within `amd-rtl-with-Vivado-build`, e.g.
[2.RC-direct.amd/xbuild.Vivado-v2024.2](../2.amd-rtl-with-Vivado-build/2.RC-direct.amd/xbuild.Vivado-v2024.2).

The opensource RTL can also be built with Vivado, via the project-generation
scripts [`RC-direct.opensource.tcl`](../2.rtl/2.RC-direct.opensource/RC-direct.opensource.tcl)
and [`RC-switched.opensource.tcl`](../2.rtl/3.Bonus--RC-switched.opensource/RC-switched.opensource.tcl) -
two short wrappers around the shared
[`RC.opensource.tcl`](../2.rtl/0.common.opensource/RC.opensource.tcl).

### Opensource openXC7 flow

Descend to [`hw_build.openXC7`](./hw_build.openXC7) and follow the Makefile and README in it. No proprietary tool is used anywhere in the chain. The default is openXC7 v1.0.0:

| Build | Chain | Output |
|---|---|---|
| `make` | `yosys` (`read_slang`, no sv2v) -> `nextpnr-himbaechel` -> `fasm2frames` -> `xc7frames2bit` (1) | `build_artifacts/top.x4g1.direct.bit` |
| `make GEN=2` | same, x4 Gen2, 3-stage eduBOS5; misses 250 MHz here ([nextpnr#110](https://github.com/openXC7/nextpnr/issues/110)) | `build_artifacts/top.x4g2.direct.bit` |
| `make LANES=1` | same, x1 link | `build_artifacts/top.x1g2.direct.bit` |
| `make FRONTEND=sv2v` | `sv2v` -> `yosys` -> `nextpnr-himbaechel` -> `fasm2frames` -> `xc7frames2bit` (1) | `build_artifacts/work/x4g1.direct.sv2v/top.x4g1.direct.bit` |

1. `ASSEMBLER=fpga-as` for the one-step assembler. Not the default yet: it writes `RXCDR_CFG` wrong ([#41](https://github.com/chili-chips-ba/openPCIE/issues/41)).

Add `VARIANT=switched` for RC-switched: `build_artifacts/top.x1g2.switched.bit`. Each build has its own work folder, so they never overwrite each other. They do share `../sw_build/firmware.hex`, so build the matching firmware first. `make check-env` checks the tools.

**Verified on hardware:** the pre-v1.0.0 bitstream (`build_artifacts/pre-v1.0.0/`) brings the PCIE link up at **Gen2**, against a second Artix-7 board as endpoint. The Vivado bitstream from the same RTL gets the same. The v1.0.0 bitstreams build and meet timing, except x4 Gen2 (181 MHz of 250 MHz: nextpnr cannot apply the eduBOS5 multicycle paths, [nextpnr#110](https://github.com/openXC7/nextpnr/issues/110)), but have not met the board yet.

Two things to know before the first build. Details in
[`hw_build.openXC7/README.md`](./hw_build.openXC7/README.md):

- **Bitstreams are not compressed.** Each is 9.73 MB, as neither openXC7 assembler can compress yet ([lromor/fpga-assembler#59](https://github.com/lromor/fpga-assembler/issues/59)). The Vivado build compresses.
- **nextpnr's GT attribute defaults do not match the Xilinx library.** Where the
  RTL leaves an attribute out, Vivado fills it from `unisim`. nextpnr puts in its
  own default, almost always `0`. So `lane_xcvr.sv` sets 20 of them explicitly.
  This is why the design first failed on hardware. And it is silent: no warning,
  and the bitstream builds cleanly.

## Loading the bitstream

[openFPGALoader](https://github.com/trabucayre/openFPGALoader) (open source, v1.1.1+) loads a bitstream over JTAG:

```sh
openFPGALoader --detect                                    # cable and FPGA found?
openFPGALoader hw_build.openXC7/build_artifacts/top.x4g1.direct.bit
```

Ubuntu's own package is older, so build it from source. On WSL, attach the JTAG cable with usbipd-win first. `set-env.sh` checks both. Details: [Programming the board from WSL](./hw_build.openXC7/README.md#programming-the-board-from-wsl).

-----------
#### End-of-Document
