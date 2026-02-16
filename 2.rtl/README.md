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

- WIP
