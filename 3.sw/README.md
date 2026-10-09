# RISC-V Bare-Metal PCIE Driver

This directory contains the C source code, startup assembly, and linker scripts required to build the **open-source driver** for the RISC-V Root Complex. This driver performs enumeration and memory transactions to act as the PCIE Host for the system.

## File Structure

What both Root Complex variants share is in [`common/`](common); each variant
folder holds only its own `main.c`:

| Directory | Contents |
| :--- | :--- |
| [`common/`](common) | `pcie.c` / `pcie.h`, `start.S`, `sections.lds` - used by both |
| [`RC-direct/`](RC-direct) | `main.c` for one Endpoint, straight RC-to-EP link |
| [`RC-switched/`](RC-switched) | `main.c` for the ASM1184e switch with up to 4 Endpoints behind it - see the [RC-switched README](../2.rtl/3.Bonus--RC-switched.opensource/README.md#2-firmware-the-bring-up-sequence) |

Both are built in [`4.build/sw_build`](../4.build/sw_build) (`make`, or `make VARIANT=switched`). The API and register map below are common to both; the enumeration sequence described further down is that of `RC-direct`.

*   **`common/pcie.c`, `common/pcie.h`**: the HAL and driver layer - register access, TLP send and Completion wait (with Completion Status and CRS retry), the configuration read/write helpers and BAR sizing.
*   **`main.c`**: the variant's application:
    *   **Enumeration:** device discovery, BAR placement, and the Command Register that enables the device. `RC-switched` also programs the switch's bus numbers and memory windows.
    *   **App:** a test that performs a Memory Write and Memory Read to the Endpoint and verifies the data integrity.
*   **`common/start.S`**: The assembly startup code. It initializes the Stack Pointer and jumps to the `main()` C function.
*   **`common/sections.lds`**: The Linker script. It maps the code and data to the FPGA's Block RAM (BRAM), starting at address `0x00000000` with a size of 8KB.

---

## **API Reference**

The driver exposes four high-level functions for interacting with the PCIE Endpoint. These functions abstract away the TLP packet construction and handshake logic.


### **1. Configuration Read**
**Reads a 32-bit value from the device's Configuration Space. Used primarily during enumeration to read Device IDs and Status registers.**

<div align="center">

| **Function Prototype** |
| :---: |
| `uint32_t pcie_cfg_read(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t *val);` |

</div>

*   **Parameters:**
    *   **bus, dev, func:** Target device topology (usually 1, 0, 0 for a direct connection).
    *   **reg:** The register offset (e.g., 0x00 for Vendor ID).
    *   **val:** **Receives the raw (byte-swapped) register value - written only on success.**
*   **Returns:** **The Completion Status: `CPL_STAT_SC` (0), `_UR` (1), `_CRS` (2, after 100 retries), `_CA` (4), or `CPL_TIMEOUT` (8).**
>*   **Example:** 
    > `if (pcie_cfg_read(1, 0, 0, 0x00, &id) == CPL_STAT_SC) ...`
*   **Note:** `main()` uses the wrappers `cfg_read32()` / `cfg_write32()`, which add the `bswap32()` and, for writes, stop with `0xBAD00002` on failure.

### **2. Configuration Write**
**Writes a 32-bit value to the Configuration Space. Used to configure BARs, enable Bus Mastering, and set Command registers.**


<div align="center">
  
| **Function Prototype** |
| :---: |
| `uint32_t pcie_cfg_write(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t val);` |

</div>


*   **Parameters:**
    *   **bus, dev, func:** Target device topology.
    *   **reg:** The register offset.
    *   **val:** **The 32-bit data to write.**
*   **Returns:** **The Completion Status, as for `pcie_cfg_read()`. A write answered with CRS is re-issued, like a read.**
>*   **Example:** 
   > `status = pcie_cfg_write(1, 0, 0, 0x10, 0xFFFFFFFF);`


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
   > `pcie_mem_write(0x80000000, 0x00000006);`


### **4. Memory Read (32-bit)**
**Performs a Memory Read transaction from the mapped BAR space.**

<div align="center">

| **Function Prototype** |
| :---: |
| `uint32_t pcie_mem_read(uint32_t addr, uint32_t *val);` |

</div>

*   **Parameters:**
    *   **addr:** **Target memory address.**
    *   **val:** **Receives the 32-bit data read from the Endpoint - written only on success.**
*   **Returns:** **The Completion Status, as for `pcie_cfg_read()`. All three non-posted calls share `pcie_request()`.**
>*   **Example:** 
    > `if (pcie_mem_read(0x80000000, &data) == CPL_STAT_SC) ...`

---

## Hardware Abstraction Layer (HAL)

The driver interacts with the custom PCIE Bridge RTL via **Memory Mapped I/O (MMIO)**. The C code writes to specific memory addresses that the hardware interprets as control registers.

### Register Map
The following addresses map directly to the RTL bridge inputs/outputs. With the default `CSR = peakrdl` (set in [`4.build/config.mk`](../4.build/config.mk)) `common/pcie.h` takes them from the generated `openpcie_regs.h`; with `CSR=legacy` it uses the same values hard-coded. Either way the map is the same - see [4.build/README.md](../4.build/README.md#the-register-map).

<div align="center">

| Register Name | Address | R/W | Description |
| :--- | :--- | :--- | :--- |
| `PCIE_TX_HEADER0` | `0x30000000` | W | TLP Header DW0 (Type, Fmt, Length). |
| `PCIE_TX_HEADER1` | `0x30000004` | W | TLP Header DW1 (Requester ID, Tag, Byte Enables). |
| `PCIE_TX_HEADER2` | `0x30000008` | W | TLP Header DW2 (Target Address or Bus/Dev/Func). |
| `PCIE_TX_DATA` | `0x3000000C` | W | **Write:** Data Payload. |
| `PCIE_RX_STATUS` | `0x30000010` | R | Completion Status (`0`=Success, `1`=UR, `2`=CRS, `4`=CA). |
| `PCIE_RX_DATA` | `0x30000014` | R | Data received from Memory Read Completions. |
| `PCIE_RX_HEADER_INFO`| `0x30000018` | R | **Completion Info:** Requester ID, Tag and Lower Address, for matching. |
| `PCIE_ERR_STATUS` | `0x3000001C` | R | **Error Status:** the hard macro's `cfg_status`, plus a flag for a received fatal-error Message. |
| `PCIE_PHY_STATUS` | `0x30000020` | R | Tx FSM state and the number of free hard-macro Tx buffers - polled before every send. |

</div>

---

## Driver Logic & Features

### 1. Robust TLP Transmission
Every non-posted request (config read, config write, memory read) goes through `pcie_request()`, which checks the **Completion Status** (SC / UR / CRS / CA) or reports a timeout, and passes read data back separately - so a genuine `0xFFFFFFFF` read is never mistaken for an error. A request answered with **CRS (Configuration Retry Status)** - read or write - is re-issued with a fresh tag up to 100 times. Any config request that fails after the device has been found stops the firmware with `0xBAD00002`.

### 2. Enumeration Sequence (in `main`)
The firmware performs a standard PCIE Bring-up sequence:
1.  **Wait:** Delays execution to allow the Physical Link to stabilize.
2.  **Discovery:** Reads the `Device ID` from Bus 1.
3.  **BAR Sizing:** With memory decoding off, writes `0xFFFFFFFF` to each of the six BARs and reads it back. `0` = BAR not implemented; bit 0 = I/O BAR (left unassigned, this RC has no I/O space); bits `[2:1] = 10` = 64-bit BAR, the next BAR is its upper half. Size = `~(readback & ~0xF) + 1`.
4.  **Assignment:** Places each memory BAR, aligned to its size, in the window `0x80000000 - 0xFFFFFFFF` (`RC-switched`: the 1 MB window of the endpoint's switch port). BAR0 lands at the window base - `0x80000000` for the AMD EP's 2 KB BAR0. A BAR that does not fit is parked out of the way (64-bit above 4 GB, 32-bit at 0); if that is BAR0, the firmware stops with `0xBAD00003`.
5.  **Enable:** Sets the **Bus Master** and **Memory Space** bits in the Command Register.

Configuration payloads travel big-endian on this RC (byte 0 of the register in bits `[31:24]`), so all config data goes through `bswap32()` and the values in the source read the way the spec prints them.

### 3. Self-Test & Debug Codes
The driver reports its execution status by writing specific "Magic Numbers" to the `PCIE_TX_DATA` register. These values serve as debug markers that can be monitored via the **Vivado ILA**.

<div align="center">

| Magic Number | Meaning |
| :--- | :--- |
| **`0x0000FACE`** | **PASS:** Data `0x6` was written and successfully read back. |
| **`0x0000DEAD`** | **FAIL:** Readback data did not match the written value, or the memory read was not completed with SC. |
| **`0xBAD00000`** | **ERROR:** Device ID read failed (Link down or device not found). In `RC-switched`: the switch upstream port did not answer. |
| **`0xBAD00001`** | **ERROR** (`RC-switched` only): the switch is up, but no Endpoint was found behind it. |
| **`0xBAD00002`** | **ERROR:** A config request to a device that had answered failed (UR, CA, timeout, or CRS after 100 retries). |
| **`0xBAD00003`** | **ERROR:** The Endpoint's BAR0 is not implemented, is an I/O BAR, or does not fit the window. |

</div>


----------------
#### End-of-Document