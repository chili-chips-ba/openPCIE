# RISC-V Bare-Metal PCIe Driver

This directory contains the C source code, startup assembly, and linker scripts required to build the **open-source driver** for the RISC-V Root Complex. This driver performs enumeration and memory transactions to act as the PCIe Host for the system.

## File Structure

*   **`main.c`**: The core application logic. It contains:
    *   **HAL:** Low-level functions that interact with the hardware by reading and writing data to specific memory addresses.
    *   **Driver:** The enumeration sequence, including device discovery, probes BAR sizes, assigns memory addresses, and configures the Command Register to enable the device for communication.
    *   **App:** A test application that performs a Memory Write and Memory Read to the Endpoint and verifies the data integrity.
*   **`start.S`**: The assembly startup code. It initializes the Stack Pointer and jumps to the `main()` C function.
*   **`sections.lds`**: The Linker script. It maps the code and data to the FPGA's Block RAM (BRAM), starting at address `0x00000000` with a size of 8KB.

---

## **API Reference**

The driver exposes four high-level functions for interacting with the PCIe Endpoint. These functions abstract away the TLP packet construction and handshake logic.


### **1. Configuration Read**
**Reads a 32-bit value from the device's Configuration Space. Used primarily during enumeration to read Device IDs and Status registers.**

<div align="center">

| **Function Prototype** |
| :---: |
| `uint32_t pcie_cfg_read(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg);` |

</div>

*   **Parameters:**
    *   **bus, dev, func:** Target device topology (usually 1, 0, 0 for a direct connection).
    *   **reg:** The register offset (e.g., 0x00 for Vendor ID).
*   **Returns:** **The 32-bit register value, or 0xFFFFFFFF on failure.**
>*   **Example:** 
    > `uint32_t id = pcie_cfg_read(1, 0, 0, 0x00);

### **2. Configuration Write**
**Writes a 32-bit value to the Configuration Space. Used to configure BARs, enable Bus Mastering, and set Command registers.**


<div align="center">
  
| **Function Prototype** |
| :---: |
| `void pcie_cfg_write(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t val);` |

</div>


*   **Parameters:**
    *   **bus, dev, func:** Target device topology.
    *   **reg:** The register offset.
    *   **val:** **The 32-bit data to write.**
*   **Behavior:** **Blocks until a successful Completion TLP is received.**
>*   **Example:** 
   > `pcie_cfg_write(1, 0, 0, 0x10, 0xFFFFFFFF); 


### **3. Memory Write (32-bit)**
**Performs a Memory Write transaction to the mapped Base Address Register (BAR) space.**

<div align="center">
  
| **Function Prototype** |
| :---: |
| `void pcie_mem_write(uint32_t addr, uint32_t val);` |

</div>


*   **Parameters:**
    *   **addr:** **Target memory address (must be 4-byte aligned).**
    *   **val:** **The 32-bit data payload.**
*   **Note:** **This is a Posted Transaction, meaning the function sends the packet and returns immediately without waiting for a completion.**
>*   **Example:** 
   > `pcie_mem_write(0x80000000, 0x00000006);


### **4. Memory Read (32-bit)**
**Performs a Memory Read transaction from the mapped BAR space.**

<div align="center">

| **Function Prototype** |
| :---: |
| `uint32_t pcie_mem_read(uint32_t addr);` |

</div>

*   **Parameters:**
    *   **addr:** **Target memory address.**
*   **Returns:** **The 32-bit data read from the Endpoint.**
*   **Robustness:** **Includes a retry mechanism. If the endpoint responds with CRS (Configuration Retry Status), the driver waits and retries automatically.**
>*   **Example:** 
    > `uint32_t data = pcie_mem_read(0x80000000);

---

## Hardware Abstraction Layer (HAL)

The driver interacts with the custom PCIe Bridge RTL via **Memory Mapped I/O (MMIO)**. The C code writes to specific memory addresses that the hardware interprets as control registers.

### Register Map
The following addresses map directly to the RTL bridge inputs/outputs:

| Register Name | Address | R/W | Description |
| :--- | :--- | :--- | :--- |
| `PCIE_TX_HEADER0` | `0x30000000` | W | TLP Header DW0 (Type, Fmt, Length). |
| `PCIE_TX_HEADER1` | `0x30000004` | W | TLP Header DW1 (Requester ID, Tag, Byte Enables). |
| `PCIE_TX_HEADER2` | `0x30000008` | W | TLP Header DW2 (Target Address or Bus/Dev/Func). |
| `PCIE_TX_DATA` | `0x3000000C` | W | **Write:** Data Payload. |
| `PCIE_RX_STATUS` | `0x30000010` | R | Completion Status (`0`=Success, `1`=UR, `2`=CRS, `3`=CA). |
| `PCIE_RX_DATA` | `0x30000014` | R | Data received from Memory Read Completions. |
| `PCIE_RX_HEADER_INFO`| `0x30000018` | R | **Completion Info:** Contains Requester ID and Tag for matching. |
| `PCIE_ERR_STATUS` | `0x3000001C` | R | **Error Flags:** Physical layer errors.|
| `PCIE_PHY_STATUS` | `0x30000020` | R | Physical Link Status (used to check TX buffers). |

---

## Driver Logic & Features

### 1. Robust TLP Transmission
The `pcie_read()` function implements a retry mechanism to handle **CRS (Configuration Retry Status)**. If the Endpoint is busy, the driver waits and retries the transaction multiple times before timing out.

### 2. Enumeration Sequence (in `main`)
The firmware performs a standard PCIe Bring-up sequence:
1.  **Wait:** Delays execution to allow the Physical Link to stabilize.
2.  **Discovery:** Reads the `Device ID` from Bus 1.
3.  **BAR Sizing:** Writes `0xFFFFFFFF` to BAR0/BAR1 to determine memory requirements.
4.  **Assignment:** Assigns Base Address `0x80000000` to the Endpoint.
5.  **Enable:** Sets the **Bus Master** and **Memory Space** bits in the Command Register.

### 3. Self-Test & Debug Codes
The driver reports its execution status by writing specific "Magic Numbers" to the `PCIE_TX_DATA` register. These values serve as debug markers that can be monitored via the **Vivado ILA**.

| Magic Number | Meaning |
| :--- | :--- |
| **`0x0000FACE`** | **PASS:** Data `0x6` was written and successfully read back. |
| **`0x0000DEAD`** | **FAIL:** Readback data did not match the written value. |
| **`0xBAD00000`** | **ERROR:** Device ID read failed (Link down or device not found). |
