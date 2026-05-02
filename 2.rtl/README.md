# RTL Implementation: Root Complex & EndPoint

This directory contains the FPGA design files (**RTL**) for the project. The designs cover both the **Root Complex (RC)** and the **EndPoint (EP)** roles, implemented on Xilinx Artix-7 FPGAs.

### Directory Structure

The projects are organized into subfolders based on the role and the implementation method:

- **`1.EP.amd`**  
  The PCIe EndPoint design. This design is consistent across all test scenarios (whether connected directly to an RC or via a Switch).

  [Detailed EP.amd Documentation](./1.EP.amd/)

- **`2.RC-direct.amd`**  
  A Root Complex design for **Direct (Point-to-Point)** connection.  
  - **`.amd` suffix:** Indicates that this implementation relies primarily on the proprietary Xilinx/AMD Vivado IP Generator. It uses the "Integrated Block for PCI Express" with a thin wrapper, focusing on XDC constraints and IP configuration.
  
  [Detailed RC-direct.amd Documentation](./2.RC-direct.amd/)

- **`2.RC-direct.opensource`**  
  A Root Complex design for **Direct** connection.  
  - **`.opensource` suffix:** This is the core of the project. It includes the full stack: a RISC-V SoC, a software driver, and a test application. It wraps the hard macros with open-source logic to create a functional system.

  [Detailed RC-direct.opensource Documentation](./2.RC-direct.opensource/)

- **`3.Bonus--RC-switched.amd`**  
  A Root Complex design configured for a **Switched** topology (RC ⇔ Switch ⇔ EP).  
  - While not strictly required for the initial project scope, this was added to prove the system works with standard PCIe Switches (ASM1184e).

  [Detailed RC-Switched Documentation](./3.Bonus--RC-switched.amd/)



> **Note:** Regardless of whether you use the `.amd` or `.opensource` version of the Root Complex, the physical testing procedure and the end results remain the same.

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

    **Procedure to identify the correct channel:**
    1.  **Schematic Check:** Consult the [NiteFury](https://github.com/RHSResearchLLC/NiteFury-and-LiteFury/tree/master) schematic to map the physical M.2 or PCIe connector pins to the specific FPGA **Package Pins**.
    2.  **Vivado Device View:** Open the **Device Window** in Vivado, locate those specific RX/TX package pins, and identify the **GTP Channel Primitive** associated with them.

    <div align="center">

    | Logical Lane | Physical Pin (RX) | Physical Pin (TX) | GT Location |
    | :--- | :--- | :--- | :--- |
    | Lane 0 | B10 / A10 | B6 / A6 | X0Y6 |
    | Lane 1 | B8 / A8 | B4 / A4 | X0Y4 |
    | Lane 2 | D11 / C11 | D5 / C5 | X0Y5 |
    | Lane 3 | D9 / C9 | D7 / C7 | X0Y7 |

    </div>
    
> **Note:** The provided XDC file includes configuration blocks for all 4 potential lanes. The specific lane(s) intended for the active topology must be **uncommented**, while the unused lanes should remain **commented**
    
5.  **Visual Debug (LEDs):**
    Internal status signals—such as `user_lnk_up` or received data payloads—are mapped to the 4 onboard **User LEDs** (Pins **G3, H3, G4, H4**) to provide immediate visual feedback during testing.


----------
#### End-of-Document