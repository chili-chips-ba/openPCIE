# PCIe EndPoint (EP) - AMD IP Implementation

This project implements a **Programmed I/O (PIO)** PCIe Endpoint using the proprietary **Xilinx 7-Series Integrated Block for PCI Express**. It serves as the "Target" device for verification, allowing the Root Complex (RC) to perform Memory Read and Memory Write transactions.

## IP Core Configuration

The following table summarizes the key parameters configured in the Vivado IP Generator for this design:

<div align="center">

| Parameter | Value | Description |
| :--- | :--- | :--- |
| **Device Port Type** | **Endpoint** | Acts as a peripheral device. |
| **Link Speed** | **Gen2 (5.0 GT/s)** | Backwards compatible with Gen1. |
| **Lane Width** | **x1** | Configured for single-lane operation. |
| **User Interface** | **AXI4-Stream** | 64-bit width running at 62.5 MHz. |
| **Vendor ID** | **`0x10EE`** | Xilinx, Inc. |
| **Device ID** | **`0x7021`** | 7-Series Integrated Block for PCIe. |
| **Class Code** | **`0x058000`** | Memory Controller. |
| **BAR0** | **2 KB** | 32-bit Memory-Mapped I/O space. |
| **Ref Clock** | **100 MHz** | Provided by the openBackplane. |

</div>

---

## Design Architecture

The structure follows the standard Xilinx PIO example design with modifications for the specific hardware platform.

### 1. IP Core Support Layer (`pcie_7x_0_support.v`)
This wrapper manages the interface between the FPGA fabric and the dedicated PCIe Hard block.
*   **PCIe Hard Macro:** Handles the Transaction Layer (TLP), Data Link Layer, and Physical Layer (SerDes/GTP).
*   **PIPE Clock Module (`pcie_7x_0_pipe_clock.v`):** Manages the FPGA's MMCM/PLL.. It generates the `user_clk` and handles the **dynamic frequency switching** required when the link trains up from Gen1 (125 MHz internal clock) to Gen2 (250 MHz internal clock).

### 2. App Wrapper (`pcie_app_7x.v`)
*   Manages the AXI-Stream interface and instantiates the PIO engine.
  
### 3. PIO Engine (`PIO_EP.v`)
*   **RX Engine:** Decodes incoming TLPs (MemWr, MemRd).
*   **TX Engine:** Generates Completion TLPs (CplD) to return data to the Host during read requests.
*   **Memory Access:** The actual storage logic where data is read from or written to, utilizing internal Block RAM as the device memory.

---

### Visual Status
*   **led_data_payload:** These LEDs display the lower 4 bits of the received data payload to visually confirm successful Memory Write transactions.

----
#### End-of-Document
