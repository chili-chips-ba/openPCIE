# Opensource RC-direct core

This is an opensource variant of what was first tested with the
[AMD-proprietary RC-direct IP stack](../../2.amd-rtl-with-Vivado-build/2.RC-direct.amd).

- [x] ✔️ Hardware FSM replaced with an opensource RISC-V based SOC
- [x] ✔️ PCIE IP core replaced with opensource RTL
- [x] ✔️ Builds and runs with a **fully opensource toolchain** - link up at Gen2
- [x] ✔️ Upgrade the current simple SOC to a version that uses PeakRDL for CSR generation

Together with our [openPCIE backplane](../../1.pcb) and Simon's unique
[end-to-end PCIE sim](../../5.sim) setup, this is **`one of the three pillars`**,
i.e. primary deliverables of this project.

The objectives of this dev track were to:
 - first design the opensource RC-direct core
 - then validate and showcase its operation in a direct RC-to-EP configuration.

Both are done. With the [RC-switched](../3.Bonus--RC-switched.opensource) use-case
as well, we have a nicely rounded set of opensource cores and examples -- a solid
foundation for the makers to build their future applications upon...

---

## Status

| | |
|---|---|
| Target device | `xc7a200tfbg484-3`, Acorn CLE-215P |
| Link | **PCIE Gen2 x4** by default, **x1** selectable; both trained RC-to-EP on hardware (x4 on the backplane's RC4 ⇔ EP4 island) |
| Note | x4 can only be tested in the **Direct** topology; [RC-switched](../3.Bonus--RC-switched.opensource) is x1 |
| Vivado build | works |
| Opensource build | works - see [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7) |

Link width is one define, `PCIE_LANES`, read by [`link_pkg.sv`](../0.common.opensource/src/pcie/link_pkg.sv): **4 by default**, 1 on request. x4 can only be tested in the **Direct** PCIE topology. Each build sets it, and picks the matching lane XDC and bitstream name:

| | x4 (default) | x1 |
|---|---|---|
| openXC7 | `make` -> `top.x4.direct.bit` | `make LANES=1` -> `top.x1.direct.bit` |
| Vivado | `RC-direct.opensource.tcl` | `set ::pcie_lanes 1` before sourcing it |
| `run-lint.sh`, `run-leq.sh` | default | `LANES=1` |

Link speed is set in `link_pkg.sv` as well (`PCIE_GEN`, 2 = Gen2).

---

## Structure

RC-direct and [RC-switched](../3.Bonus--RC-switched.opensource) are built from
the very same RTL, kept once in [`0.common.opensource`](../0.common.opensource).
They differ only in the GT lanes the link uses and in the firmware they run.

```
2.rtl/0.common.opensource/        shared by both root complexes
  src/
    RC_opensource.sv              top level: refclk buffer, PCIE bridge, SOC, LEDs
    riscv_pcie_soc.sv             picorv32 SOC, drives the AXI-Stream TLP interface
    soc_csr.sv                    wrapper for the PeakRDL-generated CSR block
    picorv32.CHILI.sv             the RISC-V core (Chili.CHIPS-improved picorv32)
    pcie/                         the opensource PCIE stack
  xdc/
    RC.x1g2.AcornCLE-215P.xdc  constraints, all but the GT lane (source of truth)
  RC.opensource.tcl               the Vivado project script behind both wrappers

2.rtl/2.RC-direct.opensource/     this folder
  xdc/
    RC-direct.x4g2.AcornCLE-215P.xdc   GT lanes of the x4 link (default): X0Y6, X0Y4, X0Y5, X0Y7
    RC-direct.x1g2.AcornCLE-215P.xdc   GT lane of the x1 link: GTPE2_CHANNEL_X0Y5
  RC-direct.opensource.tcl        regenerates the Vivado project from scratch
```

### The PCIE stack, by layer

The `PCIE_2_1` hard block is silicon and is instantiated directly. Everything
around it - what AMD ships as encrypted IP - is opensource RTL here.

| Layer | Files | Role |
|---|---|---|
| Transaction | `pcie_core.sv` | `PCIE_2_1` instance and its TLP-side plumbing |
| Buffering | `buffer_bank.sv` | RX/TX packet buffers (BRAM) |
| Streaming | `trn_bridge.sv`, `trn_tx.sv`, `trn_rx.sv`, `trn_tx_throttle.sv` | AXI-Stream TLP interface towards the SOC |
| Bridge | `pcie_top.sv` | ties the transaction and PHY sides together |
| PHY control | `phy_top.sv`, `gtp_wrapper.sv` | PIPE-level control, reset and rate sequencing |
| Bring-up FSMs | `init_ctrl.sv`, `phase_align.sv`, `lane_xcvr.sv` | GT reset sequence, TX phase alignment, per-lane status |
| Transceiver | `lane_xcvr.sv`, `gtp_wrapper.sv` | `GTPE2_CHANNEL` and `GTPE2_COMMON` instances |
| Clocking | `clk_rst_gen.sv` | MMCM: 125 / 250 / 62.5 MHz from the 100 MHz refclk |
| Tuning | `chan_retune.sv`, `speed_ctrl.sv`, `rx_eios_filter.sv` | RX data width (x16/x20) via DRP, Gen1/Gen2 rate change, EIOS filtering |
| Interfaces | `link_pkg.sv`, `axis_if.sv`, `trn_if.sv`, `pipe_if.sv`, `cfg_if.sv`, `mem_if.sv`, `mim_if.sv`, `gtp_if.sv` | package and SystemVerilog interfaces, see [SystemVerilog interfaces](../README.md#systemverilog-interfaces) |

### Clocking

```
refclk_p/n (100 MHz PCIE refclk)
   └─ IBUFDS_GTE2 ── GTREFCLK0 ─ GTPE2_COMMON ─ PLL0 (2.5 GHz)

GTPE2_CHANNEL.TXOUTCLK ─ BUFG ─ MMCM ─┬─ CLKOUT0  125 MHz  ─ clk125 (DRP,
                                      │                      and PLL0 power-up)
                                      ├─ CLKOUT1  250 MHz  ─┐
                                      └─ CLKOUT2  62.5 MHz ─ clk62m5 (USERCLK, SOC)
                                                             │
                              BUFGCTRL mux (125 | 250) ─ pipe_clk = pipe clock
```

The pipe clock is 125 MHz in Gen1 and 250 MHz in Gen2; the BUFGCTRL mux switches
it on rate change. It is the tightest timing domain in the design.

The PLL0 power-up delay in `init_ctrl` runs from `clk125` rather than from the refclk buffer - see [PLL0 power-up delay clocked from `clk125`](../../4.build/hw_build.openXC7/README.md#pll0-power-up-delay-clocked-from-clk125) for why.

---

### The CSR

The register window the firmware drives (`0x3000_0000` in the SOC address map)
is **generated**, not hand-written. The source of truth is a SystemRDL file,
[`4.build/csr_build/csr.rdl`](../../4.build/csr_build/csr.rdl), out of which
`peakrdl` produces:

| Product | Where it lands | Who consumes it |
|---|---|---|
| `csr_pkg.sv`, `csr.sv` | `4.build/csr_build/generated-files/` | `soc_csr.sv` in this design |
| `csr.h` | same | the firmware in `3.sw/` |
| `csr_hw.h`, `csr_cosim.h` | same | C++ / co-simulation code in `5.sim/` |
| `openpcie.md`, `html/` | same | the documentation of the map itself |

`soc_csr.sv` is the only hand-written piece: it bridges the picorv32 native
memory interface to the "passthrough" CPU interface of the generated block, and
launches exactly one request per CPU access.

Regenerate after every edit of `csr.rdl`:

```bash
cd ../../4.build && make -f MakefileCSR
```

Full description of the map and of the generation flow: [`4.build/README.md`](../../4.build/README.md#csr-hal-compilation).

### The CPU

`riscv_pcie_soc.sv` picks the CPU with `ifdef`s: eduBOS5 by default,
`SOC_CPU_PICORV32` for PicoRV32 ([eduBOS5 README](../0.common.opensource/src/CPU.eduBOS5/README.md)),
and `SOC_CPU_VPROC`. The last is **co-simulation only** -- nothing in either
bitstream flow defines it, so the synthesised design always contains a real
RTL core. Only
[`5.sim`](../../5.sim) sets it, to swap the core for a VProc virtual processor and
let a native C++ program or the rv32 ISS drive the identical bus:

```sh
cd ../../5.sim
make run              # the eduBOS5 RTL core -- the default, and the reference
make run CPU=vproc    # native C++
make run CPU=iss      # rv32 ISS on the real firmware.elf
```

All three reach the same result over the same PCIE link. Details and measured
run times: [The three CPU options](../../5.sim/README.md#the-three-cpu-options).

## Building

### Vivado

Regenerate the project from scratch with the tcl script:

```tcl
source RC-direct.opensource.tcl
```

It is a short wrapper around the shared
[`RC.opensource.tcl`](../0.common.opensource/RC.opensource.tcl), which collects
`src/` and `src/pcie/*.sv` from `0.common.opensource`, the shared XDC plus this
folder's lane XDC, sets
`XPM_LIBRARIES = XPM_CDC`, and registers `firmware.hex` from
`4.build/sw_build/` as the memory-init file. The generated project lands in
`xbuild.Vivado-v2024.2/`.

### Opensource

See [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7). Run the
[firmware build](../../4.build/sw_build) first - `firmware.hex` is a hard
dependency of both flows.

----
End-of-Document
