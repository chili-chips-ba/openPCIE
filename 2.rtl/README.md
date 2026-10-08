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
  the RISC-V SoC, the CSR wrapper, the opensource PCIe stack - plus the shared
  constraints and the Vivado project script. The two RC folders below hold only
  what really differs: the GT lane their x1 link uses (a one-line XDC) and a short
  wrapper that runs the shared script for them. The firmware differs too; it
  lives in [`3.sw`](../3.sw).

- **`1.EP.opensource`**
  Opensource PCIe EndPoints, used as the link partner when testing our Root
  Complex. Rather than duplicating them here, this directory points to the
  existing upstream projects - LiteFury PCIe EP, regymm's pcie_7x and LitePCIe -
  any of which can be built on the side and paired with our RC. The
  [`1.EP.amd`](../2.amd-rtl-with-Vivado-build/1.EP.amd) replica is also available
  for the same purpose.

- **`2.RC-direct.opensource`** — **implemented and working**
  
  A Root Complex design for **Direct (Point-to-Point)** connection, and the core
  of the project. It includes the full stack: the opensource PCIe logic around the
  `PCIE_2_1` and `GTPE2_CHANNEL` hard macros, a RISC-V SoC, and the software
  running on it.

  Verified on hardware: **PCIe Gen2 x1, link up and trained** in a direct RC-to-EP
  configuration. As a bonus, **Gen2 x4** has also been tested on hardware; x1
  remains the checked-in default. It builds both with Vivado and with a
  [fully opensource toolchain](../4.build/hw_build.openXC7) - sv2v, yosys,
  nextpnr-xilinx and prjxray, with no proprietary tool in the chain.

- **`3.Bonus--RC-switched.opensource`** — **implemented and working**
  
  A Root Complex design for a **Switched** topology (RC ⇔ Switch ⇔ EP).

  Verified on hardware through a standard PCIe switch (ASM1184e).


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

The hand-written register block that came first is still there, inside
`riscv_pcie_soc.sv` behind `` `ifdef SOC_CSR_LEGACY ``. Which one is built is set
once, in [`4.build/config.mk`](../4.build/config.mk), and read by every build
step - Vivado, openXC7 and the firmware - so the hardware and the software are
never built different ways. The two are functionally identical, down to the byte
offsets.

---

### Common Physical Constraints (XDC)

The **XDC file** is critical for mapping the logical PCIe signals to the specific physical pins on the `Acorn CLE-215+` board and the `openPCIE Backplane`. The following key elements are mandatory in all designs:

1.  **Clock Request (CRITICAL):**
    The backplane's clock generator will **NOT** output the 100 MHz reference clock unless the `CLKREQ#` pin (Pin **G1**) is actively driven **LOW**. If this is missing from the constraints, the FPGA will receive no clock, and the link will never establish.

2.  **Reference Clock & Reset:**
    - **REFCLK:** Configured for **100 MHz** via the differential pair (Pins **F6/E6**).
    - **PERST#:** The system reset (Pin **J1**) is active low.
3.  **Transceiver (GTP) Placement:**
    Defining `PACKAGE_PIN` constraints for RX/TX pairs alone is **insufficient**. The logical lane **must be explicitly locked** to the corresponding physical **GTP Channel Primitive** (e.g., `GTPE2_CHANNEL_X0Y...`). Without this, the design will not route correctly.

    The `LOC` alone is also **sufficient**: GT pads are dedicated, so each `GTPE2_CHANNEL` site fixes its own four RX/TX pins. The Vivado XDC files in this project therefore carry no `PACKAGE_PIN` constraints on the GT ports. (The openXC7 flow is the opposite case - nextpnr needs the pins and cannot take the `LOC`; see [`4.build/hw_build.openXC7`](../4.build/hw_build.openXC7/README.md#gt-channel).)

    **Procedure to identify the correct channel:**
    1.  **Schematic Check:** Consult the [NiteFury](https://github.com/RHSResearchLLC/NiteFury-and-LiteFury/tree/master) schematic to map the physical M.2 or PCIe connector pins to the specific FPGA **Package Pins**.
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
    Internal status signals—such as `user_lnk_up` or received data payloads—are mapped to the 4 onboard **User LEDs** (Pins **G3, H3, G4, H4**) to provide immediate visual feedback during testing.


----------
#### End-of-Document
