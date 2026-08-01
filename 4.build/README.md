# _openpcie2-rc_ Build

The build process for the _openpcie2-rc_ project consists of two steps:
- Compilation of the software application for the RISC-V hardware target
- Compilation of SystemVerilog designs into a bitstream for the hardware target

Each step has its own directory with a `Makefile` and a `README.md`. Run the SW
step first - the hardware build embeds the firmware image into the bitstream.

| Step | Directory | Produces |
|---|---|---|
| 1. SW | [`sw_build`](./sw_build) | `firmware.elf`, `firmware.bin`, `firmware.hex` |
| 2. HW | [`hw_build.openXC7`](./hw_build.openXC7) | `build_artifacts/top.bit` |

## SW Compilation

Sources are in [`3.sw`](../3.sw) (`start.S`, `main.c`, `sections.lds`), one
subdirectory per RC variant - [`RC-direct`](../3.sw/RC-direct) and
[`RC-switched`](../3.sw/RC-switched). This step only builds them. A Makefile is
provided as `4.build/sw_build/Makefile`. Running `make` in that directory
produces the following files in `4.build/sw_build`:

  * `firmware.elf`  : The ELF file for the RISC-V hardware target
  * `firmware.bin`  : The raw binary image
  * `firmware.hex`  : The HEX programming file for the RISC-V hardware target

`firmware.hex` is the one the hardware build consumes - `riscv_pcie_soc.sv`
initialises its instruction memory with `$readmemh("firmware.hex", ram)`, so the
file is one 32-bit little-endian word per line, 8 hex digits, no `0x` prefix.

The toolchain is xPack GNU RISC-V Embedded GCC (`riscv-none-elf-` prefix), built
for `rv32i` only - picorv32 here is configured without the M and C extensions.

`make` builds the RC-direct firmware. For the switched topology:

```
make clean && make VARIANT=switched
```

Both variants write the same three output names, hence the `clean`.

> **Run this step on Windows** (`cmd` or PowerShell). The RISC-V toolchain and
> Python are Windows programs, whereas the openXC7 step below runs in WSL because
> yosys, nextpnr and prjxray are Linux tools.

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
and [`RC-switched.opensource.tcl`](../2.rtl/3.Bonus--RC-switched.opensource/RC-switched.opensource.tcl).

### Opensource openXC7 flow

Descend to [`hw_build.openXC7`](./hw_build.openXC7) and follow the Makefile and
README in it. The chain is `sv2v` -> `yosys` -> `nextpnr-xilinx` -> `prjxray`, with
no proprietary tool anywhere in it:

```bash
cd hw_build.openXC7
make check-env         # verifies the tools, and warns on a wrong nextpnr version
make                   # -> build_artifacts/top.bit
make VARIANT=switched  # -> build_artifacts.switched/top.bit
```

The two variants keep separate output directories, so they never overwrite each
other. They do share `../sw_build/firmware.hex`, so build the matching firmware
first.

**Verified on hardware:** the resulting bitstream brings the PCIe link up at
**Gen2** against a second Artix-7 board acting as endpoint - the same state the
Vivado bitstream reaches from identical RTL.

Two things are worth knowing before the first build, both covered in detail in
[`hw_build.openXC7/README.md`](./hw_build.openXC7/README.md):

- **The nextpnr-xilinx version is critical.** Only commit `45a986b` works; the
  version from the official installer is too old and current master has a router
  regression.
- **nextpnr's GT attribute defaults do not match the Xilinx library.** Where the
  RTL omits an attribute, Vivado fills it from `unisim` while nextpnr substitutes
  its own default - almost always `0`. `lane_xcvr.sv` therefore sets 17 of them
  explicitly. This was the root cause of the design not working on hardware, and
  it is silent: no warning, and the bitstream builds cleanly.

-----------
#### End-of-Document
