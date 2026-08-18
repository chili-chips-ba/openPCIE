# Opensource RC-direct core

This is an opensource variant of what was first tested with the
[AMD-proprietary RC-direct IP stack](../../2.amd-rtl-with-Vivado-build/2.RC-direct.amd).

- [x] ✔️ Hardware FSM replaced with an opensource RISC-V based SOC
- [x] ✔️ PCIe IP core replaced with opensource RTL
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
| Link | **PCIe Gen2 x1, up and trained** (verified RC-to-EP on hardware) |
| Vivado build | works |
| Opensource build | works - see [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7) |

Link width and speed come from a single place, `src/pcie/link_pkg.sv`:

```systemverilog
localparam int PCIE_LANES = 1;   // 1, 2, 4 or 8
localparam int PCIE_GEN   = 2;   // 1 = Gen1, 2 = Gen2
```

---

## Structure

```
src/
  RC_direct_opensource.sv    top level: refclk buffer, PCIe bridge, SOC, LEDs
  riscv_pcie_soc.sv          picorv32 SOC, drives the AXI-Stream TLP interface
  soc_csr.sv                 wrapper for the PeakRDL-generated CSR block
  picorv32.v                 the RISC-V core itself
  pcie/                      the opensource PCIe stack
xdc/
  RC-direct.sv.x1g2.AcornCLE-215P.xdc    full constraints (source of truth)
RC-direct.opensource.tcl     regenerates the Vivado project from scratch
```

### The PCIe stack, by layer

The `PCIE_2_1` hard block is silicon and is instantiated directly. Everything
around it - what AMD ships as encrypted IP - is opensource RTL here.

| Layer | Files | Role |
|---|---|---|
| Transaction | `txn_engine.sv`, `silicon_core.sv` | `PCIE_2_1` instance and its TLP-side plumbing |
| Buffering | `buffer_bank.sv`, `buffer_tile.sv` | RX/TX packet buffers (BRAM) |
| Streaming | `stream_bridge.sv`, `stream_tx_path.sv`, `stream_rx_path.sv`, `stream_tx_gate.sv` | AXI-Stream TLP interface towards the SOC |
| Bridge | `host_bridge.sv` | ties the transaction and PHY sides together |
| PHY control | `serdes_front.sv`, `serdes_ctrl.sv` | PIPE-level control, reset and rate sequencing |
| Bring-up FSMs | `init_ctrl.sv`, `pll_init_ctrl.sv`, `phase_align.sv`, `wake_timer.sv`, `lane_keeper.sv` | GT reset sequence, QPLL sequence, TX/RX phase alignment |
| Transceiver | `lane_xcvr.sv`, `pll_bank.sv` | `GTPE2_CHANNEL` and `GTPE2_COMMON` instances |
| Clocking | `clk_synth.sv` | MMCM: 125 / 250 / 62.5 MHz from the 100 MHz refclk |
| Tuning | `chan_retune.sv`, `pll_retune.sv`, `speed_ctrl.sv`, `margin_tuner.sv`, `eios_squelch.sv` | DRP-based retuning on rate change, equalisation, electrical-idle detection |
| Interfaces | `link_pkg.sv`, `stream_if.sv`, `phy_lanes_if.sv` | package and SystemVerilog interfaces |
| Debug | `signal_probe.sv` | status/debug vector taps |

### Clocking

```
sys_clk_p/n (100 MHz PCIe refclk)
   └─ IBUFDS_GTE2 ─┬─ GTREFCLK0 ─ GTPE2_COMMON ─ QPLL (2.5 GHz)
                   └─ wake_timer (startup sequencer)

GTPE2_CHANNEL.TXOUTCLK ─ BUFG ─ MMCM ─┬─ CLKOUT0  125 MHz  ─ clk_dclk (DRP)
                                      ├─ CLKOUT1  250 MHz  ─┐
                                      └─ CLKOUT2  62.5 MHz ─ userclk1/2
                                                             │
                              BUFGCTRL mux (125 | 250) ─ pclk = pipe clock
```

The pipe clock is 125 MHz in Gen1 and 250 MHz in Gen2; the BUFGCTRL mux switches
it on rate change. It is the tightest timing domain in the design.

---

### The CSR

The register window the firmware drives (`0x3000_0000` in the SOC address map)
is **generated**, not hand-written. The source of truth is a SystemRDL file,
[`4.build/csr_build/csr.rdl`](../../4.build/csr_build/csr.rdl), out of which
`peakrdl` produces:

| Product | Where it lands | Who consumes it |
|---|---|---|
| `csr_pkg.sv`, `csr.sv` | `4.build/csr_build/generated-files/` | `soc_csr.sv` in this design |
| `csr.h` | same | the picorv32 firmware in `3.sw/` |
| `csr_hw.h`, `csr_cosim.h` | same | C++ / co-simulation code in `5.sim/` |
| `openpcie.md`, `html/` | same | the documentation of the map itself |

`src/soc_csr.sv` is the only hand-written piece: it bridges the picorv32 native
memory interface to the "passthrough" CPU interface of the generated block, and
launches exactly one request per CPU access.

Regenerate after every edit of `csr.rdl`:

```bash
cd ../../4.build && make -f MakefileCSR
```

The original hand-written register block is still in `riscv_pcie_soc.sv`, behind
`` `ifdef SOC_CSR_LEGACY ``. Which one gets built is set once, in
[`4.build/config.mk`](../../4.build/config.mk), and every build step reads it -
this project, the openXC7 bitstream and the firmware - so hardware and software
can never end up built different ways:

```makefile
CSR ?= peakrdl        # or: legacy
```

To override it for a single run without editing the file:

```bash
make CSR=legacy            # openXC7 or the firmware
set ::use_legacy_csr 1     # Vivado, before sourcing the tcl
```

The two are functionally identical, down to the byte offsets, so the firmware
never has to know which one is in the bitstream. Full description of the map and
of the generation flow: [`4.build/README.md`](../../4.build/README.md#csr-hal-compilation).

### The CPU

`riscv_pcie_soc.sv` has a second `ifdef` around the CPU instance, `SOC_CPU_VPROC`.
It is **co-simulation only** -- nothing in either bitstream flow defines it, so
the synthesised design always contains the real `picorv32`. Only
[`5.sim`](../../5.sim) sets it, to swap the core for a VProc virtual processor and
let a native C++ program or the rv32 ISS drive the identical bus:

```sh
cd ../../5.sim
make run              # the picorv32 RTL core -- the default, and the reference
make run CPU=vproc    # native C++
make run CPU=iss      # rv32 ISS on the real firmware.elf
```

All three reach the same result over the same PCIe link. Details and measured
run times: [The three CPU options](../../5.sim/README.md#the-three-cpu-options).

## Building

### Vivado

Regenerate the project from scratch with the tcl script:

```tcl
source RC-direct.opensource.tcl
```

It collects `src/`, `src/pcie/*.sv`, the XDC from `xdc/`, sets
`XPM_LIBRARIES = XPM_CDC`, and registers `firmware.hex` from
`4.build/sw_build/` as the memory-init file. The generated project lands in
`xbuild.Vivado-v2024.2/`.

### Opensource

See [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7). Run the
[firmware build](../../4.build/sw_build) first - `firmware.hex` is a hard
dependency of both flows.

----
End-of-Document
