# RTL Implementation: Opensource designs

This directory contains the **opensource** FPGA designs for the project - those
that wrap the Artix-7 hard macros with open logic instead of using the proprietary
Vivado IP generator.

The AMD/Vivado-IP counterparts live in a separate tree,
[`2.amd-rtl-with-Vivado-build`](../2.amd-rtl-with-Vivado-build). Each opensource
design here has an `.amd` sibling there that was built and proven first, and which
serves as the reference the opensource variant is measured against.

### Directory Structure

- **`0.common.opensource`**
  The RTL both Root Complex designs are built from - one top (`RC_opensource`),
  the RISC-V SoC, the CSR wrapper, the opensource PCIE stack - plus the shared
  constraints and the Vivado project script. The two RC folders below hold only
  what really differs: the GT lanes their link uses (one XDC per link width) and a short
  wrapper that runs the shared script for them. The firmware differs too; it
  lives in [`3.sw`](../3.sw).

- **`1.EP.opensource`**
  Opensource PCIE EndPoints, used as the link partner when testing our Root
  Complex. Rather than duplicating them here, this directory points to the
  existing upstream projects - LiteFury PCIE EP, regymm's pcie_7x and LitePCIe -
  any of which can be built on the side and paired with our RC. The
  [`1.EP.amd`](../2.amd-rtl-with-Vivado-build/1.EP.amd) replica is also available
  for the same purpose.

- **`2.RC-direct.opensource`** — **implemented and working**
  
  A Root Complex design for **Direct (Point-to-Point)** connection, and the core
  of the project. It includes the full stack: the opensource PCIE logic around the
  `PCIE_2_1` and `GTPE2_CHANNEL` hard macros, a RISC-V SoC, and the software
  running on it.

  Verified on hardware: **PCIE Gen2 x4 and x1, link up and trained** in a direct RC-to-EP configuration. **x4 is the default**; x1 is one build option away (`PCIE_LANES`). x4 can only be tested in this Direct topology. It builds both with Vivado and with a
  [fully opensource toolchain](../4.build/hw_build.openXC7) - sv2v, yosys,
  nextpnr-xilinx and prjxray, with no proprietary tool in the chain.

- **`3.Bonus--RC-switched.opensource`** — **implemented and working**
  
  A Root Complex design for a **Switched** topology (RC ⇔ Switch ⇔ EP).

  Verified on hardware through a standard PCIE switch (ASM1184e).


---

### Common CSR

Both Root Complex designs take their register block from the **same** SystemRDL
specification, [`4.build/csr_build/csr.rdl`](../4.build/csr_build/csr.rdl).
`peakrdl` turns it into the register RTL (`csr_pkg.sv`, `csr.sv`) and into the
software headers, and the shared
[`soc_csr.sv`](0.common.opensource/src/soc_csr.sv) bridges that block to the
picorv32 memory interface. Regenerate with `make -f MakefileCSR` in
[`4.build`](../4.build); the details are in
[`4.build/README.md`](../4.build/README.md#csr-hal-compilation).

---

### SystemVerilog interfaces

The opensource RTL passes its buses as SystemVerilog interfaces, all in [`0.common.opensource/src/pcie/`](0.common.opensource/src/pcie). Each has two modports, one per side.

<p align="center"><img src="../0.doc/2.rtl/block-diagram.drawio.svg" width="100%" alt="SV interfaces between the RC blocks: axis_if from the SOC to trn_bridge, trn_if to the PCIE_2_1 hard block, mim_if to its packet buffers, pipe_if (pipe_mac, pipe_phy) down to the GTP, gtp_if per lane, cfg_if back to the SOC"></p>

| Interface | Between | Carries |
|---|---|---|
| `axis_if` | SOC ⇄ `pcie_top` ⇄ `trn_bridge` | TLPs as AXI-Stream (`tdata`, `tkeep`, `tuser`, `tlast`, `tvalid`, `tready`), one instance per direction |
| `mem_if` | picorv32 ⇄ RAM, CSR (in `riscv_pcie_soc`) | picorv32 native memory bus (`valid`, `addr`, `wdata`, `wstrb`, `ready`, `rdata`) |
| `cfg_if` | `pcie_top` → SOC | status sideband: ERR_FATAL received, free TX buffers |
| `trn_if` | `trn_bridge` ⇄ `PCIE_2_1` (in `pcie_core`) | TLPs on the TRN bus (below) |
| `mim_if` | `PCIE_2_1` ⇄ `tx_buf_bank` / `rx_buf_bank` | packet buffer RAM port (`MIMTX*`/`MIMRX*` pins): separate write and read ports, fixed latency, one instance per direction |
| `pipe_if` | `pcie_core` ⇄ `phy_top` ⇄ `gtp_wrapper` | PIPE, as two instances: `pipe_mac` (16 bits per lane, at the MAC) and `pipe_phy` (32 bits per lane, at the GTP); `phy_top` adapts between them |

**TRN** ("transaction") is Xilinx's name for the native TLP port of the 7-series PCIE hard block, the `TRNTD`/`TRNRD`/`TRNTSOF`/... pins of `PCIE_2_1`. It predates AXI: frames are marked by start/end-of-frame flags and a remainder bit instead of byte enables. `trn_bridge` converts between it and the AXI-Stream used everywhere else. We use the **64-bit** TRN interface; its signals, timing and TLP layout are described in AMD/Xilinx [UG477, 7 Series FPGAs Integrated Block for PCI Express](../0.doc/xilinx/ug477_7Series_IntBlock_PCIe.pdf) (chapters 2 and 5, the 64-bit parts). The TLP header fields and sideband bits used by the RTL are defined once, as packed structs, in [`pcie_pkg.sv`](0.common.opensource/src/pcie/pcie_pkg.sv).

The `PCIE_2_1` and `GTPE2` hard macros keep their flat pins; the unused ones are tied off right at the instance. The diagram source is [`0.doc/2.rtl/block-diagram.drawio`](../0.doc/2.rtl/block-diagram.drawio).

---

### Clocks and resets

[`clk_rst_gen.sv`](0.common.opensource/src/pcie/clk_rst_gen.sv) makes every clock and, next to it, a reset that is asserted asynchronously and released on that clock:

<p align="center"><img src="../0.doc/2.rtl/clk-rst.drawio.svg" width="100%" alt="clk_rst_gen: refclk passes through GTPE2 lane 0 TXOUTCLK into the MMCM, which makes clk125, pipe_clk (125 or 250 MHz through a BUFGCTRL) and clk62m5; PERST# and MMCM lock clear two FDCE with INIT 0 that make rst125_n, re-synchronised to pipe_rst_n and rst62m5_n"></p>

| Clock / reset | Frequency | Used by |
|---|---|---|
| `clk125` / `rst125_n` | 125 MHz | GT DRP, PLL0 power-up sequence; runs before PLL0 (refclk → MMCM only) |
| `pipe_clk` / `pipe_rst_n` | 125 MHz Gen1, 250 MHz Gen2 | `PCIE_2_1` PIPECLK, GTPE2 TXUSRCLK/RXUSRCLK, GT reset FSM (`init_ctrl`) |
| `clk62m5` / `rst62m5_n` | 62.5 MHz | `PCIE_2_1` USERCLK, `pcie_top` |
| `clk62m5` / `core_rst_n` | 62.5 MHz | `trn_bridge`, SOC: made in `pcie_top` as `rst62m5_n & trn_link_up`, so held in reset until the PCIE data link is up |

`pipe_clk` switches to 250 MHz when all lanes have voted for Gen2 (`pipe_clk_sel`, from `gtp_wrapper`). The one reset source is two `FDCE` with `INIT = 0`: they hold the reset after configuration (flash or JTAG, which can end after PERST# is released), and PERST# or a loss of MMCM lock asserts it any time after. The diagram source is [`0.doc/2.rtl/clk-rst.drawio`](../0.doc/2.rtl/clk-rst.drawio).

### Common Physical Constraints (XDC)

The **XDC file** is critical for mapping the logical PCIE signals to the specific physical pins on the `Acorn CLE-215+` board and the `openPCIE Backplane`. The following key elements are mandatory in all designs:

1.  **Clock Request (CRITICAL):**
    The backplane's clock generator will **NOT** output the 100 MHz reference clock unless the `CLKREQ#` pin (Pin **G1**) is actively driven **LOW**. If this is missing from the constraints, the FPGA will receive no clock, and the link will never establish.

2.  **Reference Clock & Reset:**
    - **REFCLK:** Configured for **100 MHz** via the differential pair (Pins **F6/E6**).
    - **PERST#:** The system reset (Pin **J1**) is active low.
3.  **Transceiver (GTP) Placement:**
    Defining `PACKAGE_PIN` constraints for RX/TX pairs alone is **insufficient**. The logical lane **must be explicitly locked** to the corresponding physical **GTP Channel Primitive** (e.g., `GTPE2_CHANNEL_X0Y...`). Without this, the design will not route correctly.

    The `LOC` alone is also **sufficient**: GT pads are dedicated, so each `GTPE2_CHANNEL` site fixes its own four RX/TX pins. The Vivado XDC files in this project therefore carry no `PACKAGE_PIN` constraints on the GT ports. (The openXC7 flow is the opposite case - nextpnr needs the pins and cannot take the `LOC`; see [`4.build/hw_build.openXC7`](../4.build/hw_build.openXC7/README.md#gt-channel).)

    **Procedure to identify the correct channel:**
    1.  **Schematic Check:** Consult the [NiteFury](https://github.com/RHSResearchLLC/NiteFury-and-LiteFury/tree/master) schematic to map the physical M.2 or PCIE connector pins to the specific FPGA **Package Pins**.
    2.  **Vivado Device View:** Open the **Device Window** in Vivado, locate those specific RX/TX package pins, and identify the **GTP Channel Primitive** associated with them.

    <div align="center">

    | Board Lane | RX pins (P / N) | TX pins (P / N) | GT Location | GTP channel in bank 216 (openXC7 numbering) | Used by |
    | :--- | :--- | :--- | :--- | :--- | :--- |
    | Lane 0 | B10 / A10 | B6 / A6 | X0Y6 | 2 | RC-switched |
    | Lane 1 | B8 / A8 | B4 / A4 | X0Y4 | 0 | |
    | Lane 2 | D11 / C11 | D5 / C5 | X0Y5 | 1 | RC-direct, EP |
    | Lane 3 | D9 / C9 | D7 / C7 | X0Y7 | 3 | |

    </div>

    Pin names are from AMD's package file [`xc7a200t-fbg484-package.txt`](../0.doc/xilinx/xc7a200t-fbg484-package.txt) ([source](https://www.xilinx.com/support/packagefiles/a7packages/xc7a200tfbg484pkg.txt)) (`MGTPRXP<n>_216` etc.). The checked-in designs are all x1: the four rows are the alternative physical positions for the single logical lane `[0]`.
    
> **Note:** The AMD XDC files in [`2.amd-rtl-with-Vivado-build`](../2.amd-rtl-with-Vivado-build) include a `LOC` block for all 4 positions; the one intended for the active topology is **uncommented**, the others stay **commented**. The opensource designs carry only the active `LOC`, as the one line of their variant XDC; all their other constraints are shared, in [`0.common.opensource/xdc`](0.common.opensource/xdc). Neither has GT pin constraints.
    
4.  **Visual Debug (LEDs):**
    Internal status signals—such as `trn_link_up` or received data payloads—are mapped to the 4 onboard **User LEDs** (Pins **G3, H3, G4, H4**) to provide immediate visual feedback during testing.


### Utilization and Timing Stats

From the **openXC7 v1.0.0** build (Yosys `read_slang` + nextpnr-himbaechel) of the opensource RC, part `xc7a200tfbg484-3`. The numbers are for the **x4 Gen2** build, the default (`make`); x1 Gen2 (`make LANES=1`) is shown for reference.

| Resource | x4 Gen2 (default) | x1 Gen2 |
|---|---|---|
| LUTs (`SLICE_LUTX`) | 2,641 | 2,246 |
| Flip-flops (`SLICE_FFX`) | 2,230 | 1,588 |
| `CARRY4` | 109 | 90 |
| `RAMB36E1` (BRAM) | 10 | 10 |
| `PCIE_2_1` | 1 | 1 |
| `GTPE2_CHANNEL` | 4 | 1 |
| `GTPE2_COMMON` | 1 | 1 |
| `MMCME2_ADV` | 1 | 1 |
| `BUFGCTRL` (BUFG + BUFGCTRL) | 4 | 4 |

| Clock | Target | Fmax, x4 Gen2 | Margin, x4 Gen2 | Fmax, x1 Gen2 |
|---|---|---|---|---|
| `pipe_clk` | 250 MHz (Gen2) | 311.24 MHz | +24% | 310.66 MHz |
| `clk125` | 125 MHz | 379.51 MHz | +204% | 382.85 MHz |
| `clk62m5` | 62.5 MHz | 170.01 MHz | +172% | 175.69 MHz |

All clocks pass at their target frequency. Fmax is nextpnr's estimate; the numbers change from build to build with placement.

### RTL coding rules

The RTL is written to the IEEE 1800-2009 SystemVerilog LRM.

For the opensource RTL and the simulation models that stand in for it:

- **One place for bit positions:** TLP header fields and sideband bits are packed structs in [`pcie_pkg.sv`](0.common.opensource/src/pcie/pcie_pkg.sv); code uses their members, never raw slices like `tdata[30:29]`. Reserved bits are named `rsvd0`, `rsvd1`, ... so each struct spans its full width.
- **Declare and size once, use many times:** widths, constants and types live in one well-known place, a `_pkg` (e.g. `TRN_DATA_W` in `pcie_pkg.sv`), and are used from there by interface instances and modules alike; no module redeclares them.
- **Fewer, richer ports:** pass interfaces and struct-typed ports rather than many scalar signals; group related internal signals the same way.
- **Packages:** `import` right after the module name, not a package prefix on every use.
- **Case:** lower case for signals and ports, UPPER CASE for constants (parameters, localparams, enum values, macros). Only the pins of vendor hard macros and primitives (`PCIE_2_1`, `GTPE2_CHANNEL`, `MMCME2_ADV`, ...) keep their vendor names.
- **Descriptor names:** a signal of a `pcie_pkg` header or sideband type is named `*_dw0` ... `*_dw3`, `*_hdr_*` or `*_tuser` (e.g. `rx_hdr_dw0`, `tx_cfg_dw2`). It reads only the fields the logic needs; `run-lint.sh` waives the unread fields by that name.
- **Procedural blocks:** `always_ff` for flip-flops, `always_comb` for combinational logic -- never a plain `always`. Always `unique case` for parallel mux functions whose items cover every value, `unique0 case` for parallel mux functions where no item may match, and `priority case` for priority encoders -- never a plain `case`. A `unique case` has no `default`.

  | Keyword | Several items match | No item matches | Synthesis meaning |
  |---|---|---|---|
  | `unique` | violation | violation, unless there is a `default` | `parallel_case` + `full_case` |
  | `unique0` | violation | allowed, nothing happens | `parallel_case` only |
  | `priority` | first one wins | violation, unless there is a `default` | ordered (priority) logic |

  `unique0` (IEEE 1800-2009) is the simulation-aware form of the `parallel_case` directive; the older work-around, `unique case` with an empty `default`, is not used.
- **`logic`, not `wire`:** declare signals and ports as `logic` -- every `input` and `output` carries a type (`input logic ...`), never left untyped, which would default to `wire`. Only an `inout` would be a `wire`, and this design has none. A `wire x = expr;` becomes `logic x;` plus `assign x = expr;` -- `logic x = expr;` would only be an initial value.
- **`initial` blocks:** not in RTL, except to load a memory's contents (`$readmemh` of the firmware into the SOC RAM). Simulation models and test benches (`5.sim`) may use `initial begin ... end` freely.
- **No `` `timescale `` in RTL:** the test bench sets it (`` `timescale `` in `5.sim/tb.sv` and `--timescale 1ps/1ps` for xelab in `5.sim/Makefile`). RTL has no `#` delays, so it needs none; a directive in some files and not in others is a lint finding (Verilator TIMESCALEMOD).
- **No initial values on registers:** a register gets its value from the reset branch of its `always_ff`, not from its declaration. The only exception is the design's one reset source, two `FDCE` primitive instances in `clk_rst_gen.sv` (`u_rst_sync0/1`), instantiated by name so the exception stands out: their `INIT` parameter asserts the reset at FPGA configuration (from flash or JTAG, which can end after PERST# is released), and PERST# asserts it any time after. Every other reset derives from it.
- **Arrays, not flat buses:** use arrays of lanes or structs instead of flat buses with index arithmetic.
- **`/*LINT:OK*/`:** marks an unused *output* pin of a hard macro, primitive or third-party core as reviewed: `.PIN (/*LINT:OK*/)`, with a `// reason` behind it when the reason is not obvious. Never on an input -- `run-lint.sh` flags that; unused inputs get tied off.
- **No-connects:** unused bits of a hard-macro or primitive output go to `NC_`-named signals: `{NC_x, used}` on a bus pin, or an `NC_` signal for an unused lane. `NC_` signals are never read.
- **Lint:** fix findings at the root, waive only as the last resort -- the steps are in [`run-lint-waivers.txt`](../4.build/hw_build.openXC7/run-lint-waivers.txt). If at all possible, do not mold the source around a tool quirk: legal, intended code that one tool flags (e.g. slang on `unique case` with a `default`, Verilator on unpacked-struct members written by separate processes) gets a reviewed waiver with the reason, not a rewrite.
- **Models follow the RTL:** a model keeps the ports, interfaces, structs, loops and names of the RTL it replaces.
- **Formatting:** the RTL is formatted in the project style by [`run-format.sh`](../4.build/hw_build.openXC7/run-format.sh): every `if`, `else`, `always`, `for` and `initial` body is a `begin` ... `end` block, also when it holds a single statement; then Verible (`verible-verilog-format`) at its defaults (lines of at most 100 columns; wrap longer ones by hand, the formatter does not) plus every alignment option set to `align`, `end` and `else` on separate lines, LF line endings (the flags are in the script). Run it last, after lint, before a commit; `run-format.sh --check` only lists what is not formatted, and the `format` GitHub Action runs that check.

### References

- IEEE Std 1800-2009, *IEEE Standard for SystemVerilog -- Unified Hardware Design, Specification, and Verification Language*.
- Clifford E. Cummings, [*SystemVerilog-2009 Enhancements: Priority/Unique/Unique0*](https://dvcon-proceedings.org/wp-content/uploads/systemverilog-2009-enhancements-priority-unique-unique.pdf), DVCon -- `unique`, `unique0` and `priority` versus the `full_case` / `parallel_case` directives.
- Xilinx UG477, [*7 Series FPGAs Integrated Block for PCI Express*](../0.doc/xilinx/ug477_7Series_IntBlock_PCIe.pdf) -- the `PCIE_2_1` hard block and its TRN interface.
- Xilinx UG482, [*7 Series FPGAs GTP Transceivers*](../0.doc/xilinx/ug482_7Series_GTP_Transceivers.pdf) -- `GTPE2_CHANNEL` / `GTPE2_COMMON`: PLL0, TXOUTCLK, DRP, the PIPE-side clocking and reset sequence.

----------
#### End-of-Document
