# Root Complex (Direct Connection) - AMD IP Implementation

This project implements a PCIe Root Complex (RC) for a direct point-to-point connection using the proprietary Xilinx 7-Series Integrated Block for PCI Express. It is designed as a standalone hardware tester that automatically configures and verifies a connected Endpoint.

Unlike the open-source version, this implementation does not use a RISC-V CPU. Instead, it utilizes Xilinx's **Configurator** and **PIO Master** modules to manage the PCIe link and perform automated hardware testing.

## IP Core Configuration

The following table summarizes the key parameters configured in the Vivado IP Generator for this Root Port design:

<div align="center">

| Parameter | Value | Description |
| :--- | :--- | :--- |
| **Device Port Type** | **Root Port** | Acts as the PCIe Host. |
| **Link Speed** | **Gen2 (5.0 GT/s)** | High-speed data rate. |
| **Lane Width** | **x1** | Currently set to single-lane for verification. |
| **User Interface** | **AXI4-Stream** | 64-bit width @ 62.5 MHz. |
| **Vendor ID** | **`0x10EE`** | Xilinx, Inc. |
| **Device ID** | **`0x7121`** | 7-Series Root Port ID. |
| **Class Code** | **`0x060000`** | Bridge Device / Host Bridge. |
| **BAR0** | **2 KB** | Internal memory space for the Root Port. |
| **Ref Clock** | **100 MHz** | Provided by the openBackplane. |

</div>

---

## Design Architecture

The design is structured hierarchically to automate the PCIe enumeration and testing process:

### 1. Top Module (`RC_direct_amd.v`)
* Manages the AXI-Stream interface and instantiates the **Configurator** and **PIO Master** modules.

### 2. IP Core Support Layer (`pcie_7x_0_support.v`)
This wrapper manages the interface between the FPGA fabric and the dedicated PCIe Hard block.
*   **PCIe Hard Macro:** Handles the Transaction Layer (TLP), Data Link Layer, and Physical Layer (SerDes/GTP).
*   **PIPE Clock Module (`pcie_7x_0_pipe_clock.v`):** Manages the FPGA's MMCM/PLL.. It generates the `user_clk` and handles the **dynamic frequency switching** required when the link trains up from Gen1 (125 MHz internal clock) to Gen2 (250 MHz internal clock).


### 3. Configurator Layer (`cgator.v`)
Responsible for the initialization sequence required to perform enumeration and establish a functional connection (link).
*   **Controller:** Logic that reads a sequence of configuration commands from a binary ROM file (`cgator_cfg_rom.data`).
*   **Enumeration:** Automatically performs device discovery, probes BAR sizes, assigns memory addresses, and configures the Command Register to enable the device for communication.

### 4. PIO Master (`pio_master.v`)
An automated test engine that triggers immediately after enumeration finishes.
*   **Test Sequence:** Uses the `pio_master_controller` to send a **Memory Write**, followed by a **Memory Read** to verify the write.
*   **Verification:** The `pio_master_checker.v` compares the returned data with the original payload to confirm link integrity.

---

### Fully Automated Bring-up
*  No software or CPU intervention is required. Upon releasing the system reset button on the `openPCIE Backplane`, the hardware logic automatically trains the link and configures the Endpoint.

### Visual Status
*   **`led_link_up`:** This LED is connected directly to the PCIe core status signal. It lights up as soon as the physical link is established and the devices are ready to communicate.

---

## Usage Note
Since this design is strictly RTL-based, the test parameters are hard-coded. To change the target address or the data value used in the test, you must:
1.  Modify the **`cgator_cfg_rom.data`** file for enumeration changes.
2.  Update the `localparam` values in **`pio_master_controller.v`** for test data changes.

For a more flexible, software-driven approach with a RISC-V processor, refer to the [RC-direct.opensource](../2.RC-direct.opensource/) implementation.
